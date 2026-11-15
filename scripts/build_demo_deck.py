"""Build a five-slide, editable PowerPoint with notes from verified screenshots."""
from pathlib import Path
from pptx import Presentation
from pptx.util import Inches,Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from pptx.enum.shapes import MSO_SHAPE
from PIL import Image
import json
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/submission/demo-pack';OUT.mkdir(parents=True,exist_ok=True)
prs=Presentation();prs.slide_width=Inches(13.333);prs.slide_height=Inches(7.5)
C={'bg':'101A22','panel':'1A2B35','white':'F2F5F1','muted':'B5C7CD','teal':'A8DED5','gold':'E5B57C','red':'ECA69B'}
def box(sl,x,y,w,h,color,radius=False):
 sh=sl.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE if radius else MSO_SHAPE.RECTANGLE,Inches(x),Inches(y),Inches(w),Inches(h));sh.fill.solid();sh.fill.fore_color.rgb=RGBColor.from_string(C.get(color,color));sh.line.fill.background();return sh

def text(sl,x,y,w,h,txt,size=22,color='white',bold=False):
 tf=sl.shapes.add_textbox(Inches(x),Inches(y),Inches(w),Inches(h)).text_frame;tf.clear();tf.word_wrap=True
 for i,line in enumerate(txt.split('\n')):
  p=tf.paragraphs[0] if i==0 else tf.add_paragraph();p.text=line;p.font.name='Aptos';p.font.size=Pt(size);p.font.bold=bold;p.font.color.rgb=RGBColor.from_string(C.get(color,color));p.space_after=Pt(8)
 return tf

def pic(sl,path,x,y,w,h):
 im=Image.open(path);iw,ih=im.size;scale=min(w/iw,h/ih);pw,ph=iw*scale,ih*scale
 return sl.shapes.add_picture(str(path),Inches(x+(w-pw)/2),Inches(y+(h-ph)/2),width=Inches(pw),height=Inches(ph))

def slide(n,kicker,title):
 sl=prs.slides.add_slide(prs.slide_layouts[6]);sl.background.fill.solid();sl.background.fill.fore_color.rgb=RGBColor.from_string(C['bg'])
 text(sl,.5,.3,11,.3,kicker,11,'teal',True);text(sl,.5,.82,12.3,1.1,title,33,'white',True)
 box(sl,.5,7.02,12.3,.012,'muted');text(sl,.5,7.1,11.5,.25,'Team Roshan Xingbo / Prototype capture / SI-generated story art / AI-assisted development',10,'muted');text(sl,12,7.1,.8,.25,f'{n} / 5',10,'muted')
 return sl
notes=[]
s=slide(1,'THE PROBLEM / JUNIOR ASTRONAUT MISSION TRAINER','On Mars, dust steals the power.\nRadiation limits the time to fix it.')
pic(s,ROOT/'docs/media/journey-0.11/focused-window-desktop.png',5.75,2.25,7.05,4.4)
text(s,.55,2.65,4.9,2.5,'For a young learner, the hard part is connecting what they cannot see.\n\nLess light. Less power. Exposure that adds up.',24)
text(s,.55,5.35,4.85,1,'A real engineering challenge.\nAn approachable learning mission.',20,'gold',True)
text(s,6,6.55,6.4,.25,'Actual prototype capture; game settings are authored.',11,'muted')
notes.append('On Mars, dust steals power, and radiation limits the time to fix it. For young learners, the challenge is understanding how invisible quantities connect. We turn that problem into a mission they can see and influence. This is an educational simulation, not astronaut certification.')
s=slide(2,'THE EXPERIENCE / AGES 7–12','One window. One teammate. A decision to explore.')
pic(s,ROOT/'docs/media/journey-0.11/mission-desktop.png',.55,2,8.35,4.6)
text(s,9.2,2.2,3.5,3.9,'01  Choose a cleaning pace\n\n02  Watch dust and energy change\n\n03  Explain the result\n\n04  Try another plan',21,'white',True)
text(s,.6,6.55,11.8,.28,'90 active seconds • Pause to learn • Replay to compare • Source-linked science',14,'teal')
notes.append('From mission control, players guide Ren’s panel-cleaning pace. They see dust clear, energy change, and the mission end. The short round supports prediction, observation, explanation, and another attempt. The current pace choice changes cleaning and energy; completed rounds share outside exposure time and dose.')
s=slide(3,'THE SCIENCE / ESTABLISHED RELATIONSHIPS, VISIBLE FEEDBACK','From a game action to a scientific explanation.')
for y,title,body in [(2.1,'DUST → SOLAR OUTPUT','Less dust lets more sunlight reach the cells.'),(3.35,'POWER → STORED ENERGY','Energy change = (generation − use) × time*'),(4.6,'RADIATION RATE → DOSE','Absorbed dose = dose rate × time*')]:
 box(s,.55,y,6.4,1.1,'panel',True);text(s,.75,y+.08,6,.28,title,13,'teal',True);text(s,.75,y+.43,6,.55,body,20)
pic(s,ROOT/'docs/media/submission-demo/sources/science.png',7.2,2.1,5.6,3.35)
text(s,7.3,5.6,5.3,.95,'Curiosity RAD · Pathfinder dust\nMars rover power research',17,'gold',True)
text(s,.65,6.3,12,.55,'*Constant-rate form; changing rates accumulate over time. Storm timing, fatigue and hardware are game settings.',13,'muted')
notes.append('NASA’s Curiosity radiation measurements, Pathfinder dust experiment, and rover-power research ground the lesson. Dust affects solar output. Generation minus consumption changes stored energy. Dose accumulates over time. Our contribution is connecting these relationships through feedback, not discovering a new physical law. The game’s storm and equipment values are teaching assumptions.')
s=slide(4,'THE DEMO STACK / WHAT WORKS TODAY','Real observations. Clear provenance. Honest fallbacks.')
pic(s,ROOT/'services/mission-lab/evidence/lab-panels.png',.6,1.95,5,4.65)
items=[('CLOUDFLARE · LIVE','Hosts the lab and caches NASA imagery.','teal'),('OPENSPACE · INTEGRATED REFERENCE','Pinned Mars-globe radius + source attribution.','teal'),('TIMESCALEDB / TIGER DATA · LOCAL','Real retrieval history; published audit snapshot.','gold'),('GEMINI · BLOCKED / BUILT-IN GUIDE WORKS','Existing project rejects free-tier generation.','red')]
for i,(title,body,col) in enumerate(items):
 y=2.05+i*1.12;box(s,5.85,y,6.85,.98,'panel',True);text(s,6.03,y+.08,6.5,.25,title,13,col,True);text(s,6.03,y+.4,6.4,.5,body,17)
tf=text(s,.65,6.6,12,.28,'Live companion: https://komaku-mission-lab.roshan-cloudmail.workers.dev',14,'teal');tf.paragraphs[0].runs[0].hyperlink.address='https://komaku-mission-lab.roshan-cloudmail.workers.dev'
notes.append('The companion lab is live on Cloudflare and retrieves NASA’s latest available solar image. OpenSpace provides an attributed Mars scale reference. We used self-hosted TimescaleDB’s Apache-licensed core to record actual retrieval checks; its displayed audit is a snapshot, not a hosted Tiger Data service. Gemini integration is implemented, but this key’s project rejects free-tier generation. The working fallback is explicitly labelled Built-in guide. We do not pretend it is AI output.')
s=slide(5,'THE VALUE / SCIENTIFIC REASONING THROUGH PLAY','Today: a mission. Tomorrow: a way of thinking.')
text(s,.6,2.1,6.1,1.2,'Predict. Monitor.\nCompare. Explain.',29,'white',True)
text(s,.6,3.55,6.1,1.0,'Make connected science something children can investigate.',23,'white',True)
text(s,.6,4.7,6.05,1.25,'Opportunity: more missions, classrooms, and different resource constraints.\nNext: evaluate understanding with children and educators.',18,'muted')
pic(s,ROOT/'docs/media/submission-demo/sources/debrief.png',7.05,2.15,5.7,3.4)
text(s,7.2,5.65,5.2,.8,'Learning gains are not yet measured.\nActivity history is not proof of mastery.',15,'gold')
tf=text(s,.65,6.5,12,.3,'Code + downloads: github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026',13,'teal');tf.paragraphs[0].runs[0].hyperlink.address='https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026'
notes.append('The value is practising a way of thinking: predict, monitor, compare, and explain. Offline missions and visible equations make that practice inspectable and repeatable. We have not yet measured learning gains. Next we want to test understanding with children and educators, then extend the experience to different crews and constraints. Tomorrow, that child could be the one making these calls on Mars.')
for sl,n in zip(prs.slides,notes):sl.notes_slide.notes_text_frame.text=n
prs.save(OUT/'KOMAKU-5-Slide-Demo.pptx')
# Keep clickable URLs readable against the dark slide background.
import zipfile,io
from lxml import etree
ppt=OUT/'KOMAKU-5-Slide-Demo.pptx';buf=io.BytesIO()
with zipfile.ZipFile(ppt) as source,zipfile.ZipFile(buf,'w',zipfile.ZIP_DEFLATED) as target:
 for name in source.namelist():
  data=source.read(name)
  if name.startswith('ppt/theme/') and name.endswith('.xml'):
   tree=etree.fromstring(data);ns={'a':'http://schemas.openxmlformats.org/drawingml/2006/main'}
   for tag in ['hlink','folHlink']:
    for color in tree.xpath('//a:clrScheme/a:'+tag+'/a:srgbClr',namespaces=ns):color.set('val','A8DED5')
   data=etree.tostring(tree,xml_declaration=True,encoding='UTF-8',standalone=True)
  target.writestr(name,data)
ppt.write_bytes(buf.getvalue())
pitch='''On Mars, dust steals power, and radiation limits the time to fix it. We’re Team Roshan Xingbo, building KŌMAKU: Dust & Radiation for young explorers.

From mission control, players guide solar-panel cleaning, watch energy change, and discover why their choices matter. NASA’s Curiosity radiation measurements and Pathfinder dust research ground the lesson. Simple equations connect actions to outcomes.

Our live Cloudflare lab brings NASA observations to the screen. OpenSpace adds a Mars scale reference; TimescaleDB records observation checks. A built-in guide keeps explanations available while our Gemini project’s free-tier access is blocked.

The goal is scientific reasoning: predict, monitor, compare, and explain. Next, we’ll test learning with children and educators. Tomorrow, that child could be making these calls on Mars.'''
(OUT/'PRESENTER-NOTES.md').write_text('# KŌMAKU presentation notes\n\n## 60-second pitch\n\n'+pitch+'\n\n'+ '\n\n'.join('## Slide '+str(i+1)+'\n\n'+n for i,n in enumerate(notes))+'\n\nThe pitch is '+str(len(pitch.split()))+' words. Rehearse to 60 seconds; slide notes are optional longer talking points, not additional words to squeeze into that minute.\n')
print('Built 5 slides; pitch words:',len(pitch.split()))
