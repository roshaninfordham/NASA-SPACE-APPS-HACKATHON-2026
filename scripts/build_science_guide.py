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
    "game/scripts/pace_mission.gd",
    "game/data/mission-concepts.json",
    "docs/SCIENCE-JOURNEY-SOURCES.md",
    "docs/design-specs/FINAL-WORKFLOW.md",
    "docs/TRAINING-MODEL.md",
    "docs/VIDEO-EQUATIONS.md",
    "docs/SOURCE-INDEX.md",
    "docs/LIVE-DATA.md",
    "game/live/solar_feed.gd",
    "game/assets/nasa/sdo-aia-193-provenance.json",
    "game/licenses/DejaVu-Font-License.txt",
]
# The current guide covers the final pace workflow, not retained legacy engines.
FIGURES = ["journey", "dose", "energy", "plans"]
PAGE_COUNT = 16


def pace_defaults() -> dict:
    """Read authoritative numeric settings without executing GDScript."""
    source = (ROOT / "game/scripts/pace_mission.gd").read_text()
    block = re.search(r"const DEFAULTS := (\{.*?\n\})", source, flags=re.S)
    if not block:
        raise AssertionError("Pace-model defaults could not be found")
    values = json.loads(re.sub(r",\s*}", "}", block.group(1)))
    expected = {
        "warning_seconds": 1800.0, "time_scale": 6.0,
        "base_cleaning_rate_sections_per_minute": 0.125, "max_sections": 4,
        "initial_fatigue": 0.0, "fatigue_max": 0.9,
        "fatigue_growth_per_minute": 0.08, "fatigue_recovery_per_minute": 0.12,
        "clear_solar_power_kw": 8.0, "minimum_solar_transmission": 0.25,
        "habitat_load_kw": 1.0, "initial_battery_kwh": 0.5,
        "battery_capacity_kwh": 6.0, "background_dose_ugy_per_day": 210.0,
        "dose_reference_day_seconds": 86400.0, "radiation_ramp_multiplier": 3.0,
        "win_clean_fraction": 0.8, "pass_clean_fraction": 0.4,
    }
    multipliers = re.search(r"const CLEANING_MULTIPLIERS := (\[[^\]]+\])", source)
    if not multipliers or json.loads(multipliers.group(1)) != [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75]:
        raise AssertionError("Pace choices changed; review the guide comparisons")
    if values != expected:
        raise AssertionError("Pace defaults changed; update worked examples before rebuilding")
    return values


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
    pace_defaults()
    print(f"Science guide provenance verified: {len(SOURCES)} sources, PDF and {len(FIGURES)} figures.")
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
    wine, teal, rose, gold = "#172f46", "#087b85", "#ab4662", "#b77a25"
    model = pace_defaults()

    def save(fig, name):
        fig.savefig(media / f"science-guide-{name}.png", dpi=170, bbox_inches="tight",
                    facecolor="#fffdfb", metadata={"Software": "KOMAKU science guide"})
        plt.close(fig)

    fig, ax = plt.subplots(figsize=(8, 2.45))
    ax.set(xlim=(0, 12), ylim=(0, 3)); ax.axis("off")
    nodes = [(0.1, "STORY", "Year 2059\nA reason to help", wine),
             (3.1, "PREFLIGHT", "Explore if you want\nSet pace → START", teal),
             (6.1, "CHOOSE PACE", "Watch work + effort\nAutomatic entry", wine),
             (9.1, "CONNECT", "Your run → equations\nExplain + try again", teal)]
    for x, title, label, colour in nodes:
        ax.add_patch(FancyBboxPatch((x, 1.05), 2.65, 1.5, boxstyle="round,pad=0.08", fc=colour, ec="none"))
        ax.text(x + 1.325, 2.16, title, color="white", ha="center", weight="bold", fontsize=9)
        ax.text(x + 1.325, 1.58, label, color="white", ha="center", va="center", fontsize=8.5)
    for x in [2.83, 5.83, 8.83]:
        ax.add_patch(FancyArrowPatch((x, 1.8), (x + 0.23, 1.8), arrowstyle="->", mutation_scale=11, color=gold, lw=1.5))
    ax.text(6, 0.42, "Eight optional science ideas. Reading pauses the mission; review never gates Start.", ha="center", fontsize=9)
    save(fig, "journey")

    deadline = model["warning_seconds"] / 60
    minutes = [i / 10 for i in range(int(deadline * 10) + 1)]
    day_minutes = model["dose_reference_day_seconds"] / 60
    baseline = model["background_dose_ugy_per_day"]
    ramp = model["radiation_ramp_multiplier"]
    def dose(t):
        return baseline / day_minutes * (t + ramp * t*t / (2*deadline))
    fig, ax = plt.subplots(figsize=(8, 2.7))
    ax.plot(minutes, [dose(t) for t in minutes], color=teal, lw=2.5)
    ax.scatter([deadline], [dose(deadline)], color=rose, s=45, zorder=4)
    ax.annotate(f"All completed rounds: {dose(deadline):.4f} µGy", (deadline, dose(deadline)),
                xytext=(3, 9.8), arrowprops={"arrowstyle":"->", "color":rose}, color=wine)
    ax.set(xlabel="Simulated minutes outside", ylabel="Absorbed model dose (µGy)",
           xlim=(0,30.8), ylim=(0,12), title="Historical baseline + authored rising rate; no health threshold")
    ax.grid(alpha=.17); fig.tight_layout(); save(fig, "dose")

    initial_power = model["clear_solar_power_kw"] * model["minimum_solar_transmission"]
    slope = model["clear_solar_power_kw"] * (1-model["minimum_solar_transmission"]) / model["max_sections"]
    def constant_pace(t, u):
        # Exact independent constant-pace solution, with a split at F_max.
        # None of these seven default constant plans reaches the work cap by T.
        k = model["base_cleaning_rate_sections_per_minute"] * u
        growth = model["fatigue_growth_per_minute"] * max(u-1, 0)
        active = min(t, model["fatigue_max"] / growth) if growth else t
        rest = t-active
        f = growth*active
        w_at_bound = k*(active - growth*active*active/2)
        work = w_at_bound + k*(1-f)*rest
        integral_work = k*(active*active/2 - growth*active**3/6) + w_at_bound*rest + k*(1-f)*rest*rest/2
        if work > model["max_sections"] + 1e-8:
            raise AssertionError("Guide constant plan reached a new work boundary; revise plot integrator")
        energy = model["initial_battery_kwh"] + ((initial_power-model["habitat_load_kw"])*t+slope*integral_work)/60
        return work, min(model["battery_capacity_kwh"],max(0,energy)), f
    choices = [0.25,0.5,0.75,1,1.25,1.5,1.75]
    expected = [(0.9375,1.3515625),(1.875,1.703125),(2.8125,2.0546875),(3.75,2.40625),(3.28125,2.40625),(2.4609375,2.27880859375),(2.1328125,2.1689453125)]
    for u, (work, energy) in zip(choices,expected):
        actual = constant_pace(deadline,u)
        if abs(actual[0]-work)>1e-10 or abs(actual[1]-energy)>1e-10:
            raise AssertionError("Guide's independent constant-pace comparison changed")

    fig, ax = plt.subplots(figsize=(8, 2.9))
    for u, colour, dash in [(1,teal,"-"),(1.25,gold,"--"),(1.75,rose,"-.")]:
        ax.plot(minutes,[constant_pace(t,u)[1] for t in minutes],color=colour,ls=dash,lw=2.2,label=f"Constant pace {u:g}×")
    ax.set(xlabel="Mission minutes",ylabel="Actually stored energy (kWh)",xlim=(0,30),ylim=(0.4,2.65),title="Integrate the whole power history; these are not forecasts")
    ax.legend(frameon=False,fontsize=8,loc="upper left"); ax.grid(alpha=.17)
    fig.tight_layout(); save(fig,"energy")

    fig, ax = plt.subplots(figsize=(8, 3.1))
    clean = [100*constant_pace(deadline,u)[0]/model["max_sections"] for u in choices]
    colours = [teal if c>=80 else gold if c>=40 else rose for c in clean]
    positions=list(range(len(choices)))
    ax.barh(positions,clean,color=colours,height=.63)
    ax.axvline(40,color=wine,ls=":",lw=1.4,label="PASS boundary: 40%")
    ax.axvline(80,color=wine,ls="--",lw=1.4,label="WIN boundary: 80%")
    ax.set(yticks=positions,yticklabels=[f"Pace {u:g}×" for u in choices],xlabel="Panel cleaned after the same 30-minute round (%)",xlim=(0,100))
    ax.invert_yaxis(); ax.legend(frameon=False,fontsize=8,loc="lower left",bbox_to_anchor=(0,1.01),ncol=2)
    fig.tight_layout(); save(fig,"plans")

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
    if len(pages) != PAGE_COUNT: raise AssertionError(f"Expected {PAGE_COUNT} designed pages, found {len(pages)}")
    pdf = canvas.Canvas(str(PDF), pagesize=(width, height), invariant=1, pageCompression=1, pdfVersion=(1, 7))
    pdf.setTitle("KŌMAKU: Shield Protocol — The science inside the game")
    pdf.setAuthor("Team Roshan Xingbo")
    pdf.setSubject("0.8 science journey with retained legacy appendix. Source fingerprint " + fingerprint + "; source hashes " + json.dumps(source_hashes, sort_keys=True))
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
                style=styles["small"] if page_no in (12,16) else styles["body"]
                y=draw(Paragraph(inline(" ".join(paragraph)),style),y,8)
        pdf.setStrokeColor(colors.HexColor("#ded1d6"));pdf.setLineWidth(.5);pdf.line(left,58,width-right,58)
        pdf.setFont("Guide",6.8);pdf.setFillColor(colors.HexColor("#66515a"))
        pdf.drawString(left,45,"made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC")
        pdf.setFont("GuideMono",6.8);pdf.drawString(left,32,"GUIDE REVIEW 2026-11-15  ·  " + fingerprint[:12])
        pdf.setFont("GuideBold",8);pdf.drawRightString(width-right,32,f"{page_no:02d} / {PAGE_COUNT}")
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
    if len(document)!=PAGE_COUNT: raise AssertionError(f"Unexpected PDF page count: {len(document)}")
    for number,page in enumerate(document,1):
        text=page.get_text()
        if "KŌMAKU" not in text: raise AssertionError(f"Brand glyph missing on page {number}")
        if "\ufffd" in text or "\x00" in text: raise AssertionError(f"Invalid glyph on page {number}")
        for block in page.get_text("dict")["blocks"]:
            x0,y0,x1,y1=block["bbox"]
            if x0< -0.5 or y0< -0.5 or x1>width+.5 or y1>height+.5:
                raise AssertionError(f"Out-of-page block on page {number}: {block['bbox']}")
        if not re.search(rf"{number:02d} / {PAGE_COUNT}",text): raise AssertionError("Page footer missing")
    if document.embfile_names() != [notice_name]: raise AssertionError("Font notice attachment missing")
    if document.embfile_get(notice_name) != notice: raise AssertionError("Font notice bytes differ from upstream notice")
    document.close()
    artifacts={str(PDF.relative_to(ROOT)):sha(PDF)}
    artifacts.update({f"docs/media/science-guide-{name}.png":sha(media/f"science-guide-{name}.png") for name in FIGURES})
    versions={name:importlib.metadata.version(name) for name in ["reportlab","matplotlib","Pillow","PyMuPDF"]}
    provenance={"schema":1,"reviewed_on":"2026-11-15","pages":PAGE_COUNT,
        "scope":"Final 0.8 pace/fatigue workflow only, with a historical radiation baseline and authored ramp. No medical, physiological, engineering, learning-efficacy, or NASA endorsement claim.",
        "source_fingerprint":fingerprint,"sources":source_hashes,"artifacts":artifacts,
        "build":{"command":"python3 scripts/build_science_guide.py","dependencies":versions,
            "fonts":"DejaVu Sans, DejaVu Sans Bold, DejaVu Sans Mono (embedded TrueType)",
            "deterministic_pdf":True,"network_requests":False},
        "validation":{"page_count":PAGE_COUNT,"text_and_image_bounds":"passed","searchable_macron_each_page":"passed",
            "font_notice_attachment":"DejaVu-Font-License.txt extracted and matched byte-for-byte to the source notice.",
            "visual_review":"Required separately after regeneration; automated checks do not assess visual quality."}}
    PROVENANCE.write_text(json.dumps(provenance,indent=2,ensure_ascii=False)+"\n")
    print(f"Built {PDF.relative_to(ROOT)} ({PDF.stat().st_size:,} bytes), {PAGE_COUNT} pages; layout/glyph checks passed.")


if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check",action="store_true",help="Verify hashes using only the Python standard library")
    args=parser.parse_args()
    if args.check: raise SystemExit(check())
    build()
