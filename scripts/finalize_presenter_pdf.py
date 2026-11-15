"""Attach narration and clickable video to the exported five-page PDF."""
from pathlib import Path
import fitz,json
R=Path(__file__).resolve().parents[1];O=R/'docs/submission/demo-pack';p=O/'KOMAKU-Presenter-Deck.pdf';d=fitz.open(p)
assert len(d)==5
notes=json.loads((O/'presenter-notes.json').read_text())
for page,note in zip(d,notes):
 a=page.add_text_annot((page.rect.width-28,page.rect.height-48),note,icon='Note');a.set_info(title='KŌMAKU presenter notes',subject='Narration, evidence and scope');a.update()
video=fitz.Rect(.55*72,2.15*72,8.75*72,6.7625*72)
# Explicit poster makes the PDF independent of office-suite video export behavior.
d[1].insert_image(video,filename=str(R/'docs/media/journey-0.11/mission-desktop.png'),keep_proportion=True)
d[1].insert_link({'kind':fitz.LINK_URI,'from':video,'uri':'https://www.youtube.com/watch?v=eIkaDw6MwKA'})
d.embfile_add('Presenter Notes.txt','\n\n'.join(notes).encode(),filename='Presenter Notes.txt',desc='Slide narration, citations and integration boundaries')
tmp=O/'presenter-final.pdf';d.save(tmp,garbage=4,deflate=True);d.close();tmp.replace(p)
print('PDF: 5 pages, clickable video poster, 5 note annotations and embedded narration attachment')
