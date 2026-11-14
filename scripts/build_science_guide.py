#!/usr/bin/env python3
"""Build the illustrated science guide, or verify its checked-in provenance.

Build dependencies (tested): reportlab==4.4.9 matplotlib==3.10.8
Pillow==13.0.0 PyMuPDF==1.26.6. DejaVu Sans fonts must be installed.
`--check` uses only Python's standard library and performs no network access.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/SCIENCE-GUIDE.md"
PDF = ROOT / "docs/media/KOMAKU-Science-Guide.pdf"
PROVENANCE = ROOT / "docs/media/science-guide-provenance.json"
SOURCES = [
    "docs/SCIENCE-GUIDE.md",
    "scripts/build_science_guide.py",
    "game/scripts/mission.gd",
    "game/scripts/companion_rescue.gd",
    "game/scripts/player.gd",
    "game/scripts/game.gd",
    "game/scripts/suit_experiments.gd",
    "game/scripts/suit_lab.gd",
    "game/scripts/learning.gd",
    "game/scripts/mission_adviser.gd",
    "game/scripts/mission_planner.gd",
    "game/data/nasa-observations.json",
    "game/data/lessons.json",
    "game/licenses/DejaVu-Font-License.txt",
    "docs/SCIENCE.md",
    "docs/LEARNING-DESIGN.md",
    "docs/evidence/challenge-source-check.json",
]
FIGURES = ["systems", "dust", "loads", "weather"]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check() -> int:
    """Reject stale or missing PDFs/sources without loading any PDF libraries."""
    if not PROVENANCE.is_file():
        print("Science guide provenance is missing; rebuild the guide.", file=sys.stderr)
        return 1
    data = json.loads(PROVENANCE.read_text())
    failures = []
    if data.get("schema") != 1:
        failures.append("unsupported provenance schema")
    if set(data.get("sources", {})) != set(SOURCES):
        failures.append("source inventory differs from the build script")
    expected_artifacts = {str(PDF.relative_to(ROOT))} | {
        f"docs/media/science-guide-{name}.png" for name in FIGURES
    }
    if set(data.get("artifacts", {})) != expected_artifacts:
        failures.append("artifact inventory differs from the build script")
    for group in ("sources", "artifacts"):
        for name, expected in data.get(group, {}).items():
            path = ROOT / name
            if not path.is_file() or sha(path) != expected:
                failures.append(f"{group}: {name} is missing or changed")
    if failures:
        print("Science guide is stale:\n- " + "\n- ".join(failures), file=sys.stderr)
        print("Run python3 scripts/build_science_guide.py and review the PDF.", file=sys.stderr)
        return 1
    print(f"Science guide provenance verified: {len(SOURCES)} sources, PDF and 4 figures.")
    return 0


def build() -> None:
    # Keep optional libraries below --check so regular CI needs only stdlib.
    import importlib.metadata
    import math
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
    import fitz
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    from reportlab.pdfgen import canvas
    from reportlab.lib import colors
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.platypus import Paragraph, Table, TableStyle, Image, Preformatted

    media = PDF.parent
    media.mkdir(parents=True, exist_ok=True)
    font_root = Path("/usr/share/fonts/truetype/dejavu")
    for name, filename in [("Guide", "DejaVuSans.ttf"), ("GuideBold", "DejaVuSans-Bold.ttf"), ("GuideMono", "DejaVuSansMono.ttf")]:
        path = font_root / filename
        if not path.is_file():
            raise RuntimeError(f"Missing required font: {path}")
        pdfmetrics.registerFont(TTFont(name, str(path)))
    pdfmetrics.registerFontFamily("Guide", normal="Guide", bold="GuideBold", italic="Guide", boldItalic="GuideBold")
    plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10,
                         "axes.spines.top": False, "axes.spines.right": False,
                         "axes.labelcolor": "#352633", "text.color": "#352633",
                         "xtick.color": "#57424a", "ytick.color": "#57424a"})
    wine, teal, rose, gold = "#59283e", "#177b85", "#bd647b", "#d29a53"

    def save(fig, name):
        fig.savefig(media / f"science-guide-{name}.png", dpi=170, bbox_inches="tight",
                    facecolor="#fffdfb", metadata={"Software": "KOMAKU science guide"})
        plt.close(fig)

    fig, ax = plt.subplots(figsize=(8, 2.7))
    ax.set(xlim=(0, 10), ylim=(0, 3)); ax.axis("off")
    nodes = [(0.3, 1.5, "HABITAT", "Solar → habitat battery\nClean panels · save power", wine),
             (3.7, 1.5, "CREWMATE", "Suit battery → life support\nReturn · cycle · enter", teal),
             (7.1, 1.5, "VISOR", "Suit battery → cleaner\nInspection benefit in EVA", wine)]
    for x, y, title, text, colour in nodes:
        ax.add_patch(FancyBboxPatch((x, y - 0.6), 2.6, 1.3, boxstyle="round,pad=0.12", fc=colour, ec="none"))
        ax.text(x + 1.3, y + 0.35, title, color="white", ha="center", weight="bold", fontsize=11)
        ax.text(x + 1.3, y - 0.13, text, color="white", ha="center", va="center", fontsize=9)
    for x in [3.0, 6.4]:
        ax.add_patch(FancyArrowPatch((x, 1.5), (x + 0.55, 1.5), arrowstyle="<->", mutation_scale=18, color=gold, lw=2))
    ax.text(5, 0.25, "One decision changes another. The two batteries remain separate.", ha="center", fontsize=11)
    save(fig, "systems")

    fig, axes = plt.subplots(1, 2, figsize=(8, 2.8))
    ts = [i / 100 for i in range(401)]
    axes[0].plot(ts, [math.exp(-x / 0.8) * 100 for x in ts], color=teal, lw=2.5)
    axes[0].set(xlabel="Air opacity τ (μ fixed at 0.8)", ylabel="Direct transmission (%)", ylim=(0, 105), title="Airborne dust")
    ds = [i / 100 for i in range(96)]
    axes[1].plot(ds, [(1 - x) * 100 for x in ds], color=rose, lw=2.5)
    axes[1].set(xlabel="Deposited panel dust fraction", ylabel="Surface factor (%)", ylim=(0, 105), title="Surface dust")
    for ax in axes: ax.grid(alpha=0.16)
    fig.tight_layout(); save(fig, "dust")

    fig, ax = plt.subplots(figsize=(8, 2.5))
    loads = [1.30, 2.20, 0.67, 1.57]
    bars = ax.barh(["Normal / off", "Normal / on", "Save / off", "Save / on"], loads, color=[wine, rose, teal, gold])
    solar = 4.8 * .75 * math.exp(-.25 / .65) * .72
    ax.axvline(solar, color=teal, ls="--", lw=1.5, label=f"Initial solar ≈ {solar:.3f} kW")
    for bar, value in zip(bars, loads): ax.text(value + .04, bar.get_y() + bar.get_height()/2, f"{value:.2f}", va="center", fontsize=9)
    ax.set(xlabel="Electrical load (kW)", xlim=(0, 2.75)); ax.invert_yaxis(); ax.legend(frameon=False, loc="lower right", fontsize=9)
    fig.tight_layout(); save(fig, "loads")

    fig, ax = plt.subplots(figsize=(8, 2.7))
    times = [i / 50 for i in range(601)]
    storm = [math.sin(math.pi * min(1, max(0, (t - 1)/10))) ** 2 for t in times]
    ax.plot(times, storm, color=wine, lw=2.5, label="Synthetic dust strength s")
    ax.axvspan(4, 7, color=gold, alpha=.25, label="Independent particle event")
    ax.set(xlabel="Simulated hours (12 h = 4 real min at normal speed)", ylabel="Storm strength", xlim=(0,12), ylim=(0,1.13))
    ax.legend(loc="upper left", frameon=False, fontsize=9); ax.grid(alpha=.15)
    fig.tight_layout(); save(fig, "weather")

    source_hashes = {name: sha(ROOT / name) for name in SOURCES}
    fingerprint = hashlib.sha256(json.dumps(source_hashes, sort_keys=True).encode()).hexdigest()
    width, height = 595.276, 841.89
    left, right, bottom = 45, 45, 71
    available = width - left - right
    ink = colors.HexColor("#302633")
    styles = {
        "body": ParagraphStyle("body", fontName="Guide", fontSize=10.7, leading=15.4, textColor=ink, spaceAfter=8),
        "small": ParagraphStyle("small", fontName="Guide", fontSize=9.0, leading=12.7, textColor=ink),
        "heading": ParagraphStyle("heading", fontName="GuideBold", fontSize=12.4, leading=17, textColor=colors.HexColor(teal), spaceAfter=8),
        "table": ParagraphStyle("table", fontName="Guide", fontSize=8.8, leading=12.1, textColor=ink),
        "thead": ParagraphStyle("thead", fontName="GuideBold", fontSize=8.8, leading=12.1, textColor=colors.white),
        "code": ParagraphStyle("code", fontName="GuideMono", fontSize=9.0, leading=13.5, textColor=ink, backColor=colors.HexColor("#f5eef1"), borderPadding=8),
    }

    def inline(text):
        text = html.escape(text)
        text = re.sub(r"\[([^\]]+)\]\((https?://[^)]+)\)", r'<link href="\2" color="#177b85"><u>\1</u></link>', text)
        text = re.sub(r"`([^`]+)`", r'<font name="GuideMono" size="8.7">\1</font>', text)
        text = re.sub(r"\*\*([^*]+)\*\*", r'<b>\1</b>', text)
        text = re.sub(r"\*([^*]+)\*", r'<i>\1</i>', text)
        text = re.sub(r"(?<!\w)_([^_]+)_(?!\w)", r'<i>\1</i>', text)
        return text

    content = SOURCE.read_text()
    pieces = re.split(r"^## (.+)$", content, flags=re.M)
    pages = [(pieces[i], pieces[i+1]) for i in range(1, len(pieces), 2)]
    if len(pages) != 16: raise AssertionError(f"Expected 16 designed pages, found {len(pages)}")
    pdf = canvas.Canvas(str(PDF), pagesize=(width, height), invariant=1, pageCompression=1, pdfVersion=(1, 7))
    pdf.setTitle("KŌMAKU: Shield Protocol — The science inside the game")
    pdf.setAuthor("Team Roshan Xingbo")
    pdf.setSubject("Native teaching model. Source fingerprint " + fingerprint + "; source hashes " + json.dumps(source_hashes, sort_keys=True))
    pdf.setKeywords("KOMAKU, Mars, science, energy, learning, teaching model")

    def draw(flow, y, gap=8):
        _, h = flow.wrap(available, height)
        if y - h < bottom:
            raise AssertionError(f"Page {page_no} overflows by {bottom-(y-h):.1f} pt: {getattr(flow, 'text', str(flow))[:110]}")
        flow.drawOn(pdf, left, y-h)
        return y-h-gap

    for page_no, (title, body) in enumerate(pages, 1):
        pdf.setFillColor(colors.HexColor("#fffdfb")); pdf.rect(0, 0, width, height, fill=1, stroke=0)
        pdf.setFillColor(colors.HexColor(wine)); pdf.rect(0, height-39, width, 39, fill=1, stroke=0)
        pdf.setFillColor(colors.white); pdf.setFont("GuideBold", 9.5)
        pdf.drawString(left, height-24, "KŌMAKU: SHIELD PROTOCOL")
        pdf.setFont("Guide", 8); pdf.drawRightString(width-right, height-24, "THE SCIENCE INSIDE THE GAME")
        heading = Paragraph(inline(title), ParagraphStyle("title", fontName="GuideBold", fontSize=20, leading=25, textColor=colors.HexColor(wine)))
        _, h = heading.wrap(available, 60); heading.drawOn(pdf, left, height-58-h)
        accent_y = height-58-h-19
        pdf.setStrokeColor(colors.HexColor(gold)); pdf.setLineWidth(2); pdf.line(left, accent_y, left+42, accent_y)
        y = accent_y-15
        lines = body.strip().splitlines(); i = 0
        while i < len(lines):
            line = lines[i].strip()
            if not line: i += 1; continue
            if line.startswith("### "):
                y = draw(Paragraph(inline(line[4:]), styles["heading"]), y, 7); i += 1
            elif line.startswith("!["):
                target = re.search(r"\]\(([^)]+)\)", line).group(1)
                image_path = ROOT / "docs" / target
                from PIL import Image as PILImage
                with PILImage.open(image_path) as im: w, h = im.size
                display_h = min(170, available*h/w)
                y = draw(Image(str(image_path), width=display_h*w/h, height=display_h, hAlign="CENTER"), y, 10); i += 1
            elif line.startswith("```"):
                i += 1; block=[]
                while i < len(lines) and not lines[i].startswith("```"): block.append(lines[i]); i += 1
                # Wrap long formulas explicitly so no glyph can run outside the page.
                for equation in block:
                    if pdfmetrics.stringWidth(equation, "GuideMono", styles["code"].fontSize) > available-16:
                        raise AssertionError(f"Formula too long on page {page_no}: {equation}")
                y = draw(Preformatted("\n".join(block), styles["code"]), y-3, 14); i += 1
            elif line.startswith("|"):
                rows=[]
                while i < len(lines) and lines[i].strip().startswith("|"):
                    cells=[c.strip() for c in lines[i].strip().strip("|").split("|")]
                    if not all(re.fullmatch(r":?-+:?", c) for c in cells): rows.append(cells)
                    i += 1
                n=len(rows[0]); fractions=[.33,.29,.38] if n==3 else [.39,.61]
                table_data=[[Paragraph(inline(c), styles["thead"] if r==0 else styles["table"]) for c in row] for r,row in enumerate(rows)]
                table=Table(table_data,colWidths=[available*f for f in fractions],hAlign="LEFT")
                table.setStyle(TableStyle([("BACKGROUND",(0,0),(-1,0),colors.HexColor(wine)),
                    ("ROWBACKGROUNDS",(0,1),(-1,-1),[colors.HexColor("#f3edf0"),colors.HexColor("#fffdfb")]),
                    ("VALIGN",(0,0),(-1,-1),"TOP"),("LEFTPADDING",(0,0),(-1,-1),7),("RIGHTPADDING",(0,0),(-1,-1),7),
                    ("TOPPADDING",(0,0),(-1,-1),6),("BOTTOMPADDING",(0,0),(-1,-1),6),
                    ("LINEBELOW",(0,0),(-1,0),.6,colors.HexColor(gold))]))
                y=draw(table,y,12)
            else:
                paragraph=[line]; i+=1
                while i<len(lines) and lines[i].strip() and not lines[i].startswith(("### ","|","```","![")):
                    if re.match(r"\d+\. ",lines[i]): break
                    paragraph.append(lines[i].strip());i+=1
                style=styles["small"] if page_no==16 else styles["body"]
                y=draw(Paragraph(inline(" ".join(paragraph)),style),y,8)
        pdf.setStrokeColor(colors.HexColor("#ded1d6"));pdf.setLineWidth(.5);pdf.line(left,58,width-right,58)
        pdf.setFont("Guide",6.8);pdf.setFillColor(colors.HexColor("#66515a"))
        pdf.drawString(left,45,"made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC")
        pdf.setFont("GuideMono",6.8);pdf.drawString(left,32,"MODEL REVIEW 2026-11-14  ·  " + fingerprint[:12])
        pdf.setFont("GuideBold",8);pdf.drawRightString(width-right,32,f"{page_no:02d} / 16")
        pdf.showPage()
    pdf.save()

    # A standalone PDF distributes embedded font subsets. Keep their complete
    # upstream notice attached to the PDF itself, not only beside game archives.
    notice_name = "DejaVu-Font-License.txt"
    notice = (ROOT / "game/licenses" / notice_name).read_bytes()
    attached = fitz.open(PDF)
    notice_xref = attached.embfile_add(notice_name, notice, filename=notice_name,
                                      ufilename=notice_name,
                                      desc="Copyright, trademark and permission notice for embedded DejaVu fonts")
    # PyMuPDF otherwise stamps wall-clock attachment dates, breaking invariance.
    for key in ("Params/CreationDate", "Params/ModDate"):
        attached.xref_set_key(notice_xref, key, "(D:20261114000000Z)")
    attached.xref_set_key(notice_xref, "Subtype", "/text#2Fplain")
    attached.xref_set_key(attached.pdf_catalog(), "PageMode", "/UseAttachments")
    attached_path = PDF.with_suffix(".attached.pdf")
    attached.save(attached_path, no_new_id=True)
    attached.close()
    attached_path.replace(PDF)

    # Validate final page count, searchable macron, and every text/image bounding box.
    document=fitz.open(PDF)
    if len(document)!=16: raise AssertionError(f"Unexpected PDF page count: {len(document)}")
    for number,page in enumerate(document,1):
        text=page.get_text()
        if "KŌMAKU" not in text: raise AssertionError(f"Brand glyph missing on page {number}")
        if "\ufffd" in text or "\x00" in text: raise AssertionError(f"Invalid glyph on page {number}")
        for block in page.get_text("dict")["blocks"]:
            x0,y0,x1,y1=block["bbox"]
            if x0< -0.5 or y0< -0.5 or x1>width+.5 or y1>height+.5:
                raise AssertionError(f"Out-of-page block on page {number}: {block['bbox']}")
        if not re.search(rf"{number:02d} / 16",text): raise AssertionError("Page footer missing")
    if document.embfile_names() != [notice_name]: raise AssertionError("Font notice attachment missing")
    if document.embfile_get(notice_name) != notice: raise AssertionError("Font notice bytes differ from upstream notice")
    document.close()
    artifacts={str(PDF.relative_to(ROOT)):sha(PDF)}
    artifacts.update({f"docs/media/science-guide-{name}.png":sha(media/f"science-guide-{name}.png") for name in FIGURES})
    versions={name:importlib.metadata.version(name) for name in ["reportlab","matplotlib","Pillow","PyMuPDF"]}
    provenance={"schema":1,"reviewed_on":"2026-11-14","pages":16,
        "scope":"Native indoor operator/EVA teaching model and planner source; not NASA endorsement or validated engineering/learning outcomes.",
        "source_fingerprint":fingerprint,"sources":source_hashes,"artifacts":artifacts,
        "build":{"command":"python3 scripts/build_science_guide.py","dependencies":versions,
            "fonts":"DejaVu Sans, DejaVu Sans Bold, DejaVu Sans Mono (embedded TrueType)",
            "deterministic_pdf":True,"network_requests":False},
        "validation":{"page_count":16,"text_and_image_bounds":"passed","searchable_macron_each_page":"passed",
            "font_notice_attachment":"DejaVu-Font-License.txt extracted and matched byte-for-byte to the source notice.",
            "visual_review":"Required separately after regeneration; automated checks do not assess visual quality."}}
    PROVENANCE.write_text(json.dumps(provenance,indent=2,ensure_ascii=False)+"\n")
    print(f"Built {PDF.relative_to(ROOT)} ({PDF.stat().st_size:,} bytes), 16 pages; layout/glyph checks passed.")


if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check",action="store_true",help="Verify hashes using only the Python standard library")
    args=parser.parse_args()
    if args.check: raise SystemExit(check())
    build()
