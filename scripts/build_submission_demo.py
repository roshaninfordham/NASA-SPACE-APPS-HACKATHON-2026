#!/usr/bin/env python3
"""Rebuild the 29.5-second demo from committed actual captures and narration."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json, subprocess, shutil, hashlib
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/'docs/media/submission-demo'; OUT.mkdir(exist_ok=True,parents=True)
W,H=1920,1080
fontdir=ROOT/'game/assets/fonts/journey'
def font(n,body=False):return ImageFont.truetype(str(fontdir/('IBMPlexSans-Variable.ttf' if body else 'Jost-Variable.ttf')),n)
# Original evidence card: typeset research attribution, no invented NASA graphics.
im=Image.new('RGB',(W,H),'#0b141b'); d=ImageDraw.Draw(im)
for y in range(H):
 t=y/H; d.line((0,y,W,y),fill=(int(32-20*t),int(23+5*t),int(34+3*t)))
d.text((120,82),'SCIENCE BEHIND THE MISSION',font=font(26),fill='#4fe8f5')
d.text((120,130),'Grounded in NASA’s open research',font=font(66),fill='#fbf1ee')
for x,title,lines,source in [(120,'Curiosity · RAD',['Historical radiation measurements','from the surface of Mars.'],'NASA NTRS · 20180007641'),(990,'Pathfinder · solar cells',['Settled dust reduces the light','reaching solar cells.'],'NASA NTRS · 20020031145')]:
 d.rounded_rectangle((x,295,x+805,700),radius=30,fill='#142833',outline='#497579',width=2)
 d.rectangle((x+34,337,x+41,386),fill='#4fe8f5')
 d.text((x+65,330),title,font=font(46),fill='#fbf1ee')
 for i,line in enumerate(lines):d.text((x+40,440+i*60),line,font=font(34,True),fill='#d6e1e2')
 d.text((x+40,625),source,font=font(24,True),fill='#8fc5ca')
d.text((120,770),'Storm timing, cleaning pace and fatigue are teaching scenarios.',font=font(31,True),fill='#b5c5ca')
d.text((120,823),'The solar observation viewer is separate from the Mars model.',font=font(27,True),fill='#93abb3')
im.save(OUT/'nasa-research.png')
# All visual inputs are whole native engine screens, apart from this research card.
stills=OUT/'sources'
movie=OUT/'sources/gameplay.mp4'
inputs=[stills/'story.png',movie,OUT/'nasa-research.png',stills/'debrief.png',stills/'science.png']
durations=[2.5,14,5,3.5,4.5]
cmd=['ffmpeg','-y','-hide_banner','-loglevel','warning']
for p,dur in zip(inputs,durations):
 if p.suffix=='.png':cmd += ['-loop','1','-framerate','24','-t',str(dur),'-i',str(p)]
 else:cmd += ['-i',str(p)]
cmd += ['-i',str(OUT/'komaku-demo-narration.mp3'),'-stream_loop','-1','-i',str(ROOT/'game/assets/audio/journey/orbit.ogg')]
filters=[]
for i,dur in enumerate(durations):
 # Preserve all HUD controls and keep captions outside the captured game area.
 filters.append(f'[{i}:v]scale=1664:936:force_original_aspect_ratio=decrease:flags=lanczos,pad=1920:1080:(ow-iw)/2:18:color=0x0b141b,setsar=1,fps=24,trim=duration={dur},setpts=PTS-STARTPTS[v{i}]')
filters.append(''.join(f'[v{i}]' for i in range(5))+'concat=n=5:v=1:a=0[cut]')
filters.append(f"[cut]fps=24,subtitles={OUT/'komaku-demo-narration.srt'}:fontsdir={fontdir}:force_style='FontName=IBM Plex Sans,FontSize=20,PrimaryColour=&H00FFFFFF,OutlineColour=&H001B140B,BorderStyle=3,Outline=1,Shadow=0,Alignment=2,MarginV=6'[video]")
filters.append('[5:a]aresample=48000,volume=0.95,apad,atrim=duration=29.5[voice]')
filters.append('[6:a]aresample=48000,volume=0.045,atrim=duration=29.5,afade=t=in:d=1,afade=t=out:st=27.5:d=2[music]')
filters.append('[voice][music]amix=inputs=2:duration=first:normalize=0,alimiter=limit=0.92[audio]')
cmd += ['-filter_complex_threads','2','-filter_complex',';'.join(filters),'-map','[video]','-map','[audio]','-c:v','libx264','-preset','fast','-crf','18','-threads','2','-pix_fmt','yuv420p','-r','24','-c:a','aac','-b:a','192k','-t','29.5','-movflags','+faststart',str(OUT/'KOMAKU-30-second-demo.mp4')]
subprocess.run(cmd,check=True)
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration,size:stream=codec_name,width,height,avg_frame_rate,sample_rate','-of','json',str(OUT/'KOMAKU-30-second-demo.mp4')]))
assert float(probe['format']['duration'])<=30.0
record={'kind':'edited-submission-demo','duration_seconds':float(probe['format']['duration']),'narration':'AI-generated Indian English male narration, Microsoft en-IN-PrabhatNeural','gameplay_capture':'Actual Godot main scene, MovieWriter fixed24fps; automated normal HUD commands. Not a human playtest or device-performance recording.','edit':'Actual whole-screen captures plus original typeset NASA source card; chronological mission footage followed by research/results/science. Results use a documented later fixture, not completion in14real seconds.','music':'Original project procedural orbit.ogg; no supplied third-party track used.','inputs':[{'file':str(p),'duration_seconds':dur,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p,dur in zip(inputs,durations)],'ffprobe':probe,'video_sha256':hashlib.sha256((OUT/'KOMAKU-30-second-demo.mp4').read_bytes()).hexdigest()}
(OUT/'demo-provenance.json').write_text(json.dumps(record,indent=2,ensure_ascii=False)+'\n')
print(json.dumps(probe,indent=2))
