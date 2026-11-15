"""Five slides: one sentence each, numeric evidence, embedded video and notes."""
from pathlib import Path
from pptx import Presentation
from pptx.util import Inches,Pt
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from PIL import Image
import json,zipfile,io
from lxml import etree
R=Path(__file__).resolve().parents[1];O=R/'docs/submission/demo-pack'
P=Presentation();P.slide_width=Inches(13.333);P.slide_height=Inches(7.5)
COL={'bg':'101A22','panel':'1B303A','fg':'F4F6F0','dim':'BED0D4','mint':'A8DED5','gold':'E9BA80','pink':'EFAFAA'}
YOUTUBE='https://www.youtube.com/watch?v=eIkaDw6MwKA';LIVE='https://komaku-mission-lab.roshan-cloudmail.workers.dev';REPO='https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026'
notes=[]
def rect(s,x,y,w,h,color='panel'):
 z=s.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE,Inches(x),Inches(y),Inches(w),Inches(h));z.fill.solid();z.fill.fore_color.rgb=RGBColor.from_string(COL[color]);z.line.fill.background();return z

def txt(s,x,y,w,h,t,size=22,color='fg',bold=False,link=None):
 z=s.shapes.add_textbox(Inches(x),Inches(y),Inches(w),Inches(h));f=z.text_frame;f.clear();f.word_wrap=True
 for i,line in enumerate(t.split('\n')):
  p=f.paragraphs[0] if i==0 else f.add_paragraph();p.text=line;p.font.name='Aptos';p.font.size=Pt(size);p.font.bold=bold;p.font.color.rgb=RGBColor.from_string(COL[color]);p.space_after=Pt(6)
  if link:
   for run in p.runs:run.hyperlink.address=link
 return z

def pic(s,path,x,y,w,h):
 iw,ih=Image.open(path).size;scale=min(w/iw,h/ih);pw,ph=iw*scale,ih*scale
 return s.shapes.add_picture(str(path),Inches(x+(w-pw)/2),Inches(y+(h-ph)/2),width=Inches(pw),height=Inches(ph))

def slide(i,label,sentence):
 s=P.slides.add_slide(P.slide_layouts[6]);s.background.fill.solid();s.background.fill.fore_color.rgb=RGBColor.from_string(COL['bg'])
 txt(s,.5,.25,12,.35,'KŌMAKU: DUST & RADIATION   /   '+label,12,'mint',True)
 txt(s,.5,.85,12.3,1.2,sentence,30,'fg',True)
 txt(s,.5,7.12,11.8,.23,'TEAM ROSHAN XINGBO  ·  Prototype captures  ·  SI-generated story art  ·  AI-assisted development',9,'dim')
 txt(s,12.1,7.12,.7,.23,str(i)+' / 5',9,'dim')
 return s

def note(s,t):notes.append(t);s.notes_slide.notes_text_frame.text=t

s=slide(1,'THE REAL PROBLEM','NASA evidence turns invisible dust and radiation hazards into a mission for ages 7–12.')
for x,n,unit,label,source in [(.55,'210 ± 40','µGy / Earth day','Curiosity RAD · historical absorbed-dose rate', 'https://ntrs.nasa.gov/citations/20180007641'),(6.85,'0.28%','per day','Pathfinder · solar-cell short-circuit-current decline','https://ntrs.nasa.gov/citations/20020031145')]:
 rect(s,x,2.3,5.95,3.3);txt(s,x+.25,2.65,5.4,.9,n,58,'gold',True);txt(s,x+.25,3.7,5.4,.5,unit,25,'mint');txt(s,x+.25,4.55,5.4,.8,label,19)
 txt(s,x+.25,5.15,5.4,.25,'NASA research source',12,'mint',link=source)
txt(s,.7,5.95,11.9,.7,'Published observations ≠ current Mars forecast\nDetector measurement · experiment-specific current loss · not universal game coefficients',15,'dim')
note(s,'SAY (~12 seconds): On Mars, dust steals power while radiation exposure adds up. NASA measured both: our challenge is helping a young learner connect these invisible quantities.\n\nEVIDENCE: Curiosity RAD historical tissue-like detector value: 210 ± 40 microgray per Earth day, Gale Crater, August 2012–June 2013; not a human-risk limit. https://ntrs.nasa.gov/citations/20180007641 and primary manuscript https://authors.library.caltech.edu/records/kdt88-3aw98 . Pathfinder paper reports 0.28% per day decrease in short-circuit current; not a universal solar-power or per-sol coefficient. https://ntrs.nasa.gov/citations/20020031145 . Ages 7–12 are the intended audience, not a validated learning-outcome sample.')

s=slide(2,'THE PLAYABLE EXPERIENCE','A 90-second mission connects eight science concepts to visible cleaning, resource monitoring and replay.')
poster=R/'docs/media/journey-0.11/mission-desktop.png';video=O/'KOMAKU-Hackathon-Demo-29s.mp4'
pic(s,poster,.55,2.15,8.2,4.6125)
s.shapes.add_movie(str(video),Inches(.55),Inches(2.15),Inches(8.2),Inches(4.6125),poster_frame_image=str(poster),mime_type='video/mp4')
for y,n,label in [(2.4,'90 s','Active-play round'),(3.72,'8','Science concepts'),(5.04,'29.5 s','Embedded demo video')]:
 txt(s,9.1,y,3.6,.65,n,40,'gold',True);txt(s,9.1,y+.7,3.6,.35,label,18)
txt(s,.7,6.82,4,.22,'Click video · desktop PowerPoint',11,'dim');txt(s,4.8,6.82,3.7,.22,'Watch on YouTube',12,'mint',link=YOUTUBE);txt(s,9.15,6.82,3.5,.22,'Mission implementation',11,'mint',link=REPO+'/blob/main/docs/TRAINING-MODEL.md')
note(s,'SAY (~11 seconds): Players guide Ren’s cleaning pace, watch energy change, and connect results to eight science concepts; a short round makes another attempt easy.\n\nVIDEO: Click the embedded video in desktop PowerPoint; the clip is 29.5 seconds. The separate YouTube link opens the team video online: '+YOUTUBE+' . Playing the clip adds 29.5 seconds to the spoken pitch. The PDF links the thumbnail to YouTube because ordinary PDF viewers cannot reliably run online video.\n\nPROVENANCE: Actual Godot prototype captures; original completed-result fixture documented in docs/media/submission-demo; synthetic Indian-English male narration, Microsoft en-IN-PrabhatNeural. The final companion shot is a screenshot. The current source and deck are not a new native-game release. Eight concepts and the 90-second round are implemented game settings, not research findings. Source: '+REPO+'/blob/main/docs/TRAINING-MODEL.md')

s=slide(3,'THE MATH / CONNECTED FEEDBACK','Four linked relationships explain how cleaning affects power, stored energy and accumulated dose.')
rows=[('01 / CLEANING','Work = effective cleaning rate × time*','Pace + authored fatigue → effective rate'),('02 / SOLAR POWER','Solar power = clear-panel power × transmission','Dust → light reaching solar cells'),('03 / STORED ENERGY','Energy change = (generation − use) × time*','kW × hours = kWh · battery-capacity bounds'),('04 / ABSORBED DOSE','Dose = dose rate × time*','µGy/hour × hours = µGy')]
for i,(head,formula,label) in enumerate(rows):
 x=.55+(i%2)*6.3;y=2.25+(i//2)*1.82;rect(s,x,y,5.95,1.6);txt(s,x+.18,y+.12,5.6,.25,head,12,'mint',True);txt(s,x+.18,y+.48,5.6,.8,formula,20,'fg',True);txt(s,x+.18,y+1.32,5.6,.24,label,12,'dim')
txt(s,.7,6.1,12,.65,'*Constant-rate form; changing rates integrated over time\nCompleted rounds: same exposure duration and dose · storm, fatigue and hardware: game settings',14,'dim')
txt(s,.7,6.8,5,.23,'NASA rover-power research',11,'mint',link='https://ntrs.nasa.gov/citations/20230007029');txt(s,6.9,6.8,5.5,.23,'Model equations + assumptions',11,'mint',link=REPO+'/blob/main/docs/SCIENCE-JOURNEY-SOURCES.md')
note(s,'SAY (~12 seconds): Four linked relationships explain the result: cleaning changes dust, dust changes solar output, net power changes stored energy, and radiation rate accumulates into dose.\n\nDETAIL: Multiplication assumes a constant rate over the interval; the game accumulates changing values through time. Cleaning pace and fatigue change cleaning and energy. Completed default rounds share the same outside duration and accumulated dose; the current player does not optimize final radiation dose. Gray and sievert are not interchangeable. The innovation is connecting established science through immediate feedback, not a new physical law. Rover-power research: https://ntrs.nasa.gov/citations/20230007029 ; implemented assumptions: '+REPO+'/blob/main/docs/SCIENCE-JOURNEY-SOURCES.md')

s=slide(4,'THE TECHNOLOGY / ACTUAL CONTRIBUTIONS','Four technologies connect NASA observations, Mars context, retrieval history and reliable explanations.')
items=[('CLOUDFLARE · LIVE','15 min','NASA cache refresh','Latest SDO imagery + provenance',LIVE),('OPENSPACE · USED','3,396.19 km','Configured Mars-globe radius','Pinned MIT-licensed reference',REPO+'/blob/main/services/mission-lab/data/openspace.json'),('TIMESCALEDB / TIGER DATA · LOCAL','2 checks / 1 image','Real retrieval audit snapshot','Apache-core mode · not Tiger Cloud',REPO+'/blob/main/services/observation-history/README.md'),('GEMINI · BLOCKED','3 topics','Working built-in guide fallback','Existing project: free-tier HTTP 403',REPO+'/blob/main/services/mission-lab/README.md')]
for i,(head,n,label,scope,url) in enumerate(items):
 x=.55+(i%2)*6.3;y=2.25+(i//2)*1.95;rect(s,x,y,5.95,1.75);txt(s,x+.18,y+.12,5.6,.28,head,13,'mint' if i<2 else 'gold',True);txt(s,x+.18,y+.5,5.6,.6,n,32,'fg',True);txt(s,x+.18,y+1.13,5.6,.27,label,17);txt(s,x+.18,y+1.46,5.6,.2,scope,11,'dim',link=url)
txt(s,.7,6.5,12,.3,'LIVE DEMO  '+LIVE,15,'mint',link=LIVE)
note(s,'SAY (~15 seconds): Cloudflare makes NASA imagery available with provenance. OpenSpace adds a scale reference. TimescaleDB distinguishes repeated checks from new images. Gemini is blocked, so the clearly labelled built-in guide keeps explanations available.\n\nCLOUDFLARE: Public Worker, 15-minute cache refresh policy; this is our configured interval, not NASA acquisition cadence. Published Workers Free limits: 100,000 requests/day and 10 ms CPU/request, subject to account eligibility: https://developers.cloudflare.com/workers/platform/limits/ .\nOPENSPACE: Pinned spherical rendering configuration, not mean Mars radius, terrain simulation or live data; source commit 5ac175a7154e57909085131bcd9d9366670c2a4f. Source: https://github.com/OpenSpace/OpenSpace/blob/5ac175a7154e57909085131bcd9d9366670c2a4f/data/assets/scene/solarsystem/planets/mars/globe.asset .\nTIMESCALEDB: Two real metadata checks, one distinct image hash; dated local TimescaleDB 2.32.0 audit exported to the public page, not a live hosted database. Apache-core license mode; other distribution features have different terms. https://github.com/timescale/timescaledb .\nGEMINI: Integration is implemented; the existing project rejects free-tier generation with 403. Three fixed topics use a prewritten fallback labelled Built-in guide, not Gemini output. Future activation needs eligible project access; no paid billing enabled. https://ai.google.dev/gemini-api/docs/pricing .')

s=slide(5,'THE VALUE / WHAT WE CAN DEFEND','Our innovation connects scientific decisions to visible results through a repeatable predict–act–explain loop.')
for x,n,label in [(.55,'26','Passing service tests'),(4.75,'30','Recent runs retained locally'),(8.95,'4','Reasoning skills to practise')]:
 rect(s,x,2.25,3.85,1.75);txt(s,x+.2,2.45,3.4,.75,n,46,'gold',True);txt(s,x+.2,3.35,3.4,.5,label,17)
txt(s,.65,4.4,12,1,'PREDICT    →    MONITOR    →    COMPARE    →    EXPLAIN',24,'mint',True)
txt(s,.65,5.3,12,.5,'NEXT  /  Learner evaluation · varied crews · new resource constraints',20)
txt(s,.65,5.95,12,.5,'Measured learning gains: not yet established · clinical / flight qualification: not claimed',14,'dim')
txt(s,.65,6.55,5.9,.3,'Source code + downloads',15,'mint',link=REPO);txt(s,6.9,6.55,5.8,.3,'Live companion demonstration',15,'mint',link=LIVE)
note(s,'SAY (~10 seconds): The value is scientific reasoning: predict, monitor, compare, and explain. Next, we will test understanding with children and educators before claiming improved learning.\n\nNUMBERS: 26 service tests passed: 9 coach tests plus 17 NASA-cache tests; this is software verification, not a learning study. The current-source local training journal retains up to 30 detailed attempts plus cumulative counters; it is activity tracking, not mastery assessment. Four reasoning skills are our instructional goals, not measured gains. Source: '+REPO+'/blob/main/docs/VISUAL-LEARNING-UPDATE.md .\n\nFUTURE: Evaluate learner predictions, explanations and delayed recall; then explore varied crews and resource constraints. OpenSpace’s engine is not integrated, Tiger Cloud is not used, and Gemini generation is not currently successful. Do not claim the best tool, proven learning impact, or an unprecedented scientific discovery without comparative evidence.\n\nPRESENTATION: The five SAY sections total approximately 60 seconds with pauses. Use Presenter View in PowerPoint to read notes without changing files. The embedded demo adds 29.5 seconds if played in full.')

out=O/'KOMAKU-Presenter-Deck.pptx';P.save(out)
# Readable hyperlink theme on dark backgrounds.
buf=io.BytesIO()
with zipfile.ZipFile(out) as src,zipfile.ZipFile(buf,'w',zipfile.ZIP_DEFLATED) as dst:
 for name in src.namelist():
  data=src.read(name)
  if name.startswith('ppt/theme/') and name.endswith('.xml'):
   t=etree.fromstring(data);ns={'a':'http://schemas.openxmlformats.org/drawingml/2006/main'}
   for tag in ['hlink','folHlink']:
    for v in t.xpath('//a:clrScheme/a:'+tag+'/a:srgbClr',namespaces=ns):v.set('val','A8DED5')
   data=etree.tostring(t,xml_declaration=True,encoding='UTF-8',standalone=True)
  dst.writestr(name,data)
out.write_bytes(buf.getvalue())
(O/'presenter-notes.json').write_text(json.dumps(notes,indent=2,ensure_ascii=False)+'\n')
print('Built 5 slides with one headline sentence each, embedded MP4, links and speaker notes')
