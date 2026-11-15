#!/usr/bin/env python3
"""Build/check the concise equation-video handoff; no network access required."""
from __future__ import annotations

import argparse
import hashlib
import html
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
PDF = ROOT / "docs/media/KOMAKU-Video-Equations.pdf"
PROVENANCE = ROOT / "docs/media/video-equations-provenance.json"
SOURCES = [
    "docs/VIDEO-EQUATIONS.md",
    "docs/design-specs/FINAL-WORKFLOW.md",
    "scripts/build_video_equations.py",
    "game/scripts/pace_mission.gd",
    "game/licenses/DejaVu-Font-License.txt",
]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check() -> int:
    if not PROVENANCE.is_file():
        print("Equation-sheet provenance is missing.", file=sys.stderr)
        return 1
    data = json.loads(PROVENANCE.read_text())
    errors = []
    if set(data.get("sources", {})) != set(SOURCES):
        errors.append("source inventory changed")
    for name, expected in data.get("sources", {}).items():
        if not (ROOT / name).is_file() or digest(ROOT / name) != expected:
            errors.append(name)
    if not PDF.is_file() or digest(PDF) != data.get("pdf_sha256"):
        errors.append(str(PDF.relative_to(ROOT)))
    if errors:
        print("Equation sheet is stale: " + ", ".join(errors), file=sys.stderr)
        return 1
    print(f"Equation sheet verified: 2 pages and {len(SOURCES)} source fingerprints.")
    return 0


def build() -> None:
    import fitz
    from reportlab.lib import colors
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    from reportlab.pdfgen import canvas
    from reportlab.platypus import Paragraph, Table, TableStyle

    fonts = Path("/usr/share/fonts/truetype/dejavu")
    for face, filename in [("Video", "DejaVuSans.ttf"), ("VideoBold", "DejaVuSans-Bold.ttf"), ("VideoMono", "DejaVuSansMono.ttf")]:
        pdfmetrics.registerFont(TTFont(face, str(fonts / filename)))
    pdfmetrics.registerFontFamily("Video", normal="Video", bold="VideoBold")
    source = (ROOT / SOURCES[0]).read_text()
    sections = re.split(r"\n## ", source)
    groups = [next(s for s in sections if s.startswith(f"{n}. ")) for n in range(1, 5)]
    blocks = [re.findall(r"```text\n(.*?)\n```", group, flags=re.S) for group in groups]
    assert len(blocks[0]) == 2 and all(len(b) == 1 for b in blocks[1:])
    sources = {p: digest(ROOT / p) for p in SOURCES}
    fingerprint = hashlib.sha256(json.dumps(sources, sort_keys=True).encode()).hexdigest()
    width, height = 595.276, 841.89
    margin, available = 42, width - 84
    ink, teal, amber = "#183047", "#007e87", "#aa640f"
    style = ParagraphStyle("body", fontName="Video", fontSize=9.3, leading=13.0, textColor=ink)
    small = ParagraphStyle("small", parent=style, fontSize=8.1, leading=10.8)
    heading = ParagraphStyle("heading", parent=style, fontName="VideoBold", fontSize=12.3, leading=16.5, textColor=teal)
    PDF.parent.mkdir(parents=True, exist_ok=True)
    out = canvas.Canvas(str(PDF), pagesize=(width, height), invariant=1, pageCompression=1, pdfVersion=(1, 7))
    out.setTitle("KŌMAKU: Shield Protocol — Video Equations")
    out.setAuthor("Team Roshan Xingbo")

    def text(value: str, y: float, use=style, gap=6) -> float:
        p = Paragraph(value, use)
        _, h = p.wrap(available, height)
        if y - h < 63:
            raise AssertionError(f"Equation sheet overflows: {value[:60]}")
        p.drawOn(out, margin, y - h)
        return y - h - gap

    def formula(value: str, y: float, size=9.1) -> float:
        lines = value.splitlines()
        h = len(lines) * 14 + 12
        if y - h < 63:
            raise AssertionError("Equation block overflows")
        out.setFillColor(colors.HexColor("#edf7f7"))
        out.roundRect(margin, y - h, available, h, 5, stroke=0, fill=1)
        out.setFillColor(colors.HexColor(ink)); out.setFont("VideoMono", size)
        for i, line in enumerate(lines):
            if pdfmetrics.stringWidth(line, "VideoMono", size) > available - 18:
                raise AssertionError(f"Equation line too wide: {line}")
            out.drawString(margin + 9, y - 16 - i * 14, line)
        return y - h - 7

    def header(number: int, title: str, subtitle: str) -> float:
        out.setFillColor(colors.HexColor(ink)); out.rect(0, height - 40, width, 40, stroke=0, fill=1)
        out.setFont("VideoBold", 10); out.setFillColor(colors.white)
        out.drawString(margin, height - 25, "KŌMAKU: SHIELD PROTOCOL")
        out.setFont("Video", 8); out.drawRightString(width - margin, height - 25, "EQUATION VIDEO HANDOFF")
        out.setFont("VideoBold", 20); out.setFillColor(colors.HexColor(ink))
        out.drawString(margin, height - 76, title)
        return text(subtitle, height - 91, small, 12)

    def footer(number: int) -> None:
        out.setStrokeColor(colors.HexColor("#ccd9df")); out.line(margin, 54, width - margin, 54)
        out.setFillColor(colors.HexColor("#61707c")); out.setFont("Video", 6.4)
        out.drawString(margin, 42, "made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC")
        out.setFont("VideoMono", 6.3); out.drawString(margin, 30, "2026-11-15 · " + fingerprint[:12])
        out.setFont("VideoBold", 8); out.drawRightString(width - margin, 30, f"{number} / 2")
        out.showPage()

    y = header(1, "Four relationships to reveal", "t = simulated minutes · 30-minute mission · substitute the player's actual run, not a prerecorded example.")
    y = text("1 · Pace + effort + time → cleaning", y, heading)
    y = formula(blocks[0][0], y)
    y = text("<b>Effort subline:</b> a = 1 only during active cleaning, otherwise 0. u is the chosen pace (0.25–1.75); F is an authored slowdown, not measured physiology. At full cleaning, work and F freeze.", y, small)
    y = formula(blocks[0][1], y, 8.0)
    y = text("2 · Cleaner panel → more solar power", y, heading)
    y = formula(blocks[1][0], y)
    y = text("3 · Solar power − habitat need → stored energy", y, heading)
    y = formula(blocks[2][0], y, 8.5)
    y = text("kW is power; kWh is stored energy. The factor 1/60 converts minutes into hours. All panel, load, battery, pace, and effort settings are fictional mission choices.", y, small)
    y = text("4 · Radiation rate over outside time → model dose", y, heading)
    y = formula(blocks[3][0], y, 8.8)
    y = text("<b>Historical reference:</b> 210 ± 40 µGy/day, Curiosity RAD's tissue-like detector, 2012–2013. <b>Fictional addition:</b> the rising multiplier. A solar image does not supply this rate. All completed rounds have the same outside time and dose.", y, small)
    footer(1)

    y = header(2, "Show the result honestly", "One exact worked example, the outcome bands, and the separate meaning of sievert.")
    y = text("Example: normal pace for the whole round", y, heading)
    y = text("With u = 1, F stays zero. Cleaning rate is 0.125 sections/min. This example is illustrative; use the player's recorded values for their reveal.", y)
    rows = [["Quantity", "End of the 30-minute example"], ["Work / clean panel", "3.75 sections / 93.75%"], ["Dust remaining", "6.25%"], ["Solar power", "7.625 kW"], ["Stored energy", "2.40625 kWh"], ["Absorbed model dose", "10.9375 µGy"], ["Outcome", "WIN (clean fraction ≥ 80%)"]]
    table = Table([[Paragraph(html.escape(cell), small) for cell in row] for row in rows], colWidths=[available * .4, available * .6])
    table.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#dcebed")), ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.HexColor("#f5f8fa"), colors.white]), ("VALIGN", (0, 0), (-1, -1), "TOP"), ("TOPPADDING", (0, 0), (-1, -1), 5), ("BOTTOMPADDING", (0, 0), (-1, -1), 5)]))
    _, h = table.wrap(available, height); table.drawOn(out, margin, y - h); y -= h + 10
    y = formula("E = 0.5 + [(2 + 7.625)/2 − 1] × (30/60)\n  = 2.40625 kWh", y)
    y = text("Use the full power history: multiplying final power by all 30 minutes would overestimate energy. <b>WIN:</b> clean ≥80%; <b>PASS:</b> clean ≥40% and &lt;80%; <b>LOSE:</b> clean &lt;40%. These are authored game goals.", y)
    y = text("Sievert needs additional information", y, heading)
    y = formula("Equivalent dose: H_T = Σ_R w_R × D_(T,R)      Sv\nEffective dose:  E_eff = Σ_T w_T × H_T         Sv", y, 9.0)
    y = text("These definitions are <b>not evaluated in the game</b>. D_(T,R) is tissue-specific absorbed dose in Gy; radiation and tissue weighting need information our aggregate µGy counter does not provide. E_eff is unrelated to battery energy E. Do not show a numeric personal Sv or health reading.", y, small)
    y = text("No lower-dose stars in this workflow", y, heading)
    y = text("Ren enters shelter automatically at 30 minutes. Every completed round therefore has 10.9375 µGy model dose, regardless of cleaning pace. Pauses freeze the clock. The warning bar is fictional time progress, not storm distance or a medical safety scale.", y, small)
    y = text("Sources and exact handoff", y, heading)
    y = text('<link href="https://ntrs.nasa.gov/citations/20180007641" color="#007e87">Hassler et al. / NASA archive</link> · <link href="https://authors.library.caltech.edu/records/kdt88-3aw98" color="#007e87">Primary Table 1</link> · <link href="https://www.epa.gov/radiation/radiation-terms-and-units" color="#007e87">EPA quantities</link> · <link href="https://ntrs.nasa.gov/citations/20020031145" color="#007e87">NASA dust experiment</link>', y, small)
    y = text("Full formulas, controls, constants, animation order, and scientific corrections: docs/VIDEO-EQUATIONS.md and docs/design-specs/FINAL-WORKFLOW.md. This is an educational scenario, not clinical advice, NASA endorsement, or validated astronaut physiology.", y, small)
    footer(2)
    out.save()
    notice = (ROOT / "game/licenses/DejaVu-Font-License.txt").read_bytes()
    document = fitz.open(PDF)
    xref = document.embfile_add("DejaVu-Font-License.txt", notice, filename="DejaVu-Font-License.txt", desc="Complete license notice for embedded DejaVu fonts")
    for key in ("Params/CreationDate", "Params/ModDate"):
        document.xref_set_key(xref, key, "(D:20261115000000Z)")
    temporary = PDF.with_suffix(".attached.pdf"); document.save(temporary, no_new_id=True); document.close(); temporary.replace(PDF)
    document = fitz.open(PDF)
    assert len(document) == 2
    for page in document:
        assert "KŌMAKU" in page.get_text() and "\ufffd" not in page.get_text()
        for block in page.get_text("dict")["blocks"]:
            x0, y0, x1, y1 = block["bbox"]
            assert x0 >= 0 and y0 >= 0 and x1 <= width + .5 and y1 <= height + .5
    assert document.embfile_get("DejaVu-Font-License.txt") == notice
    PROVENANCE.write_text(json.dumps({"schema_version": 1, "reviewed_on": "2026-11-15", "pages": 2, "sources": sources, "pdf_sha256": digest(PDF), "source_fingerprint": fingerprint, "embedded_license": "DejaVu-Font-License.txt", "scope": "Agreed final-workflow equation handoff. Historical dose reference plus explicitly authored pace/effort/storm model.", "build": "python3 scripts/build_video_equations.py", "network_requests": False}, indent=2) + "\n")
    print(f"Built {PDF.relative_to(ROOT)} ({PDF.stat().st_size:,} bytes), 2 pages.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.check:
        raise SystemExit(check())
    build()
