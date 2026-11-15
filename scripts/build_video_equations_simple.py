#!/usr/bin/env python3
"""Build an independent, number-free landscape equation sheet for the video team."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from branding import brand
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
PDF = ROOT / "docs/media/KOMAKU-Video-Equations-Simple.pdf"
PROVENANCE = ROOT / "docs/media/video-equations-simple-provenance.json"
SOURCES = [
    "game/data/brand.json",
    "scripts/branding.py",
    "docs/VIDEO-EQUATIONS-SIMPLE.md",
    "scripts/build_video_equations_simple.py",
    "game/licenses/DejaVu-Font-License.txt",
]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check() -> int:
    """Verify the built sheet using only Python's standard library."""
    try:
        data = json.loads(PROVENANCE.read_text())
    except (OSError, ValueError) as error:
        print(f"Simple equation-sheet provenance is unavailable: {error}", file=sys.stderr)
        return 1
    errors = []
    if data.get("schema_version") != 1:
        errors.append("unsupported provenance schema")
    if set(data.get("sources", {})) != set(SOURCES):
        errors.append("source inventory changed")
    for name, expected in data.get("sources", {}).items():
        source = ROOT / name
        if not source.is_file() or sha(source) != expected:
            errors.append(name)
    if not PDF.is_file() or sha(PDF) != data.get("pdf_sha256"):
        errors.append(str(PDF.relative_to(ROOT)))
    if data.get("pages") != 1 or data.get("orientation") != "landscape":
        errors.append("expected one landscape page")
    if data.get("page_size_points") != [1200, 675]:
        errors.append("page dimensions changed")
    if data.get("number_free_visible_page") is not True or data.get("all_eight_bubble_labels") is not True:
        errors.append("number-free page or bubble-label validation missing")
    if errors:
        print("Simple equation sheet is stale: " + ", ".join(errors), file=sys.stderr)
        return 1
    print(f"Simple equation sheet verified: one landscape page and {len(SOURCES)} source fingerprints.")
    return 0


def build() -> None:
    import fitz
    from reportlab.lib import colors
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    from reportlab.pdfgen import canvas
    from reportlab.platypus import Paragraph

    fonts = Path("/usr/share/fonts/truetype/dejavu")
    for face, name in [("Simple", "DejaVuSans.ttf"), ("SimpleBold", "DejaVuSans-Bold.ttf")]:
        pdfmetrics.registerFont(TTFont(face, str(fonts / name)))
    pdfmetrics.registerFontFamily("Simple", normal="Simple", bold="SimpleBold")
    width, height = 1200, 675
    navy, teal, muted = "#173047", "#087c84", "#526776"
    PDF.parent.mkdir(parents=True, exist_ok=True)
    out = canvas.Canvas(str(PDF), pagesize=(width, height), invariant=1, pageCompression=1)
    out.setTitle(brand()["display_name"] + " — Simple Video Equations")
    out.setAuthor("Team Roshan Xingbo")
    out.setFillColor(colors.HexColor("#f7fafb")); out.rect(0, 0, width, height, stroke=0, fill=1)
    out.setFont("SimpleBold", 16); out.setFillColor(colors.HexColor(teal))
    out.drawString(48, 631, brand()["display_name"].upper())
    out.setFont("SimpleBold", 29); out.setFillColor(colors.HexColor(navy))
    out.drawString(48, 588, "How your mission connects")
    out.setFont("Simple", 14); out.setFillColor(colors.HexColor(muted))
    out.drawString(48, 560, "Bring the bubbles together. Reveal the ideas behind the result.")

    def paragraph(value: str, x: float, top: float, space: float, size: float, leading: float, color: str, bold=False) -> float:
        style = ParagraphStyle("simple", fontName="SimpleBold" if bold else "Simple", fontSize=size, leading=leading, textColor=colors.HexColor(color))
        p = Paragraph(value, style); _, h = p.wrap(space, height)
        p.drawOn(out, x, top-h)
        return top-h

    def card(x: float, top: float, label: str, equation: str, note: str) -> None:
        w, h = 540, 169
        out.setFillColor(colors.white); out.setStrokeColor(colors.HexColor("#d6e5e8"))
        out.roundRect(x, top-h, w, h, 12, stroke=1, fill=1)
        out.setFillColor(colors.HexColor(teal)); out.roundRect(x+20, top-37, w-40, 24, 6, stroke=0, fill=1)
        paragraph(label, x+32, top-18, w-64, 11.8, 15, "#ffffff", True)
        end = paragraph(equation, x+24, top-57, w-48, 19, 26, navy, True)
        end = paragraph(note, x+24, end-10, w-48, 11.5, 15, muted)
        if end < top-h+11:
            raise AssertionError(f"Card text overflow: {label}")

    card(48, 537, "SPEED + TIME → LESS DUST",
         "Panel cleaned = average cleaning speed × cleaning time",
         "In this game, tiredness can reduce effective cleaning speed.")
    card(612, 537, "DUST → POWER",
         "Solar power = clear-panel power × sunlight getting through dust",
         "Sunlight through dust means the fraction that gets through.")
    card(48, 350, "POWER + TIME → STORED ENERGY",
         "Energy stored = starting energy + energy collected − energy used",
         "Power is a rate; energy builds up over time. The battery has a capacity limit.")
    card(612, 350, "RADIATION + TIME → DOSE",
         "Absorbed dose = average radiation strength × time outside",
         "Use the average across the outside time, not only the final rate.")

    out.setStrokeColor(colors.HexColor("#cddde2")); out.line(48, 157, 1152, 157)
    paragraph("SHELTER", 48, 140, 480, 12.5, 17, teal, True)
    paragraph("Getting inside ends the outside-time count for this mission.", 48, 117, 510, 13, 18, navy)
    paragraph("SIEVERT · A SEPARATE IDEA", 612, 140, 530, 12.5, 17, teal, True)
    paragraph("Radiation type and body tissue matter. This game does not calculate a personal health score.", 612, 117, 540, 13, 18, navy)
    out.setFont("Simple", 9); out.setFillColor(colors.HexColor(muted))
    out.drawString(48, 33, "Team Roshan Xingbo · NASA Space Apps Hackathon")
    out.drawRightString(1152, 33, "A learning model · the live solar image is not an equation input")
    out.showPage(); out.save()

    notice = (ROOT / "game/licenses/DejaVu-Font-License.txt").read_bytes()
    document = fitz.open(PDF)
    xref = document.embfile_add("DejaVu-Font-License.txt", notice, filename="DejaVu-Font-License.txt", desc="Complete license notice for embedded DejaVu fonts")
    for key in ("Params/CreationDate", "Params/ModDate"):
        document.xref_set_key(xref, key, "(D:20261115000000Z)")
    attached = PDF.with_suffix(".attached.pdf"); document.save(attached, no_new_id=True); document.close(); attached.replace(PDF)
    document = fitz.open(PDF)
    assert len(document) == 1
    text = document[0].get_text()
    assert "KŌMAKU" in text and "\ufffd" not in text
    assert not re.search(r"\d", text), "A numeric value appeared on the video page"
    for bubble in ("SPEED", "TIME", "DUST", "POWER", "RADIATION", "DOSE", "SHELTER", "SIEVERT"):
        assert bubble in text, bubble
    for block in document[0].get_text("dict")["blocks"]:
        x0,y0,x1,y1 = block["bbox"]
        assert x0 >= 0 and y0 >= 0 and x1 <= width and y1 <= height
    assert document.embfile_get("DejaVu-Font-License.txt") == notice
    PROVENANCE.write_text(json.dumps({"schema_version":1,"pages":1,"orientation":"landscape","page_size_points":[width,height],"sources":{p:sha(ROOT/p) for p in SOURCES},"pdf_sha256":sha(PDF),"number_free_visible_page":True,"all_eight_bubble_labels":True,"embedded_font_notice":"DejaVu-Font-License.txt","build":"python3 scripts/build_video_equations_simple.py","network_requests":False},indent=2)+"\n")
    print(f"Built {PDF.relative_to(ROOT)} ({PDF.stat().st_size:,} bytes): one number-free landscape page.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify source and PDF fingerprints without optional build libraries.")
    arguments = parser.parse_args()
    if arguments.check:
        raise SystemExit(check())
    build()
