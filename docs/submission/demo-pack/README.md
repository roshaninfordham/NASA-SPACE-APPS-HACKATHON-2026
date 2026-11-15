# KŌMAKU demo package — November 15, 2026

- [Five-slide PowerPoint with speaker notes](KOMAKU-5-Slide-Demo.pptx)
- [Five-page PDF](KOMAKU-5-Slide-Demo.pdf)
- [29.5-second H.264/AAC gameplay MP4](KOMAKU-Hackathon-Demo-29s.mp4)
- [60-second pitch and slide-by-slide narration](PRESENTER-NOTES.md)
- [Alternative 30-second narration script](NARRATION-30-SECONDS.txt)
- [Live companion demonstration](https://komaku-mission-lab.roshan-cloudmail.workers.dev)

The slides emphasize the radiation/dust learning problem, player decisions, equations and learning opportunity. They distinguish implemented features from intentions and contain actual prototype screenshots. No measured learning improvement or unprecedented scientific discovery is claimed.

## Current integration claims

**Cloudflare:** live, tested public companion site and NASA cache. **OpenSpace:** pinned MIT-licensed Mars globe rendering reference used by the live scale card; no claim to run the OpenSpace engine or derive radiation from it. **TimescaleDB / Tiger Data:** real local Apache-core database demonstration; live page displays an explicitly labelled exported audit snapshot, not a managed cloud connection. **Gemini:** API integration implemented, but the existing project's free-tier generation returns 403. The button reliably returns a prewritten, source-based explanation labelled **Built-in guide**. It is not Gemini output.

## Video provenance and narration

The new edit is 29.5 seconds, 1920×1080, H.264/AAC. It reuses the [documented actual game capture and synthetic Indian-English male narration](../../media/submission-demo/README.md), adding a captured live-companion screen for the final two seconds and a visible SI disclosure. The narration is **Microsoft en-IN-PrabhatNeural**, generated with edge-tts in the previous verified recording. It is not a human team-member recording.

A fresh speech-service request failed; no new generated voice is claimed. `NARRATION-30-SECONDS.txt` is an alternative script to record yourself, not the audio in this MP4. The actual MP4 transcript is [the original caption file](../../media/submission-demo/komaku-demo-narration.srt).

Music is the project's original procedural ambience. The two supplied YouTube tracks are not used. Video metadata and its on-screen disclosure identify AI narration and SI-generated story artwork. The game capture is not footage of a real child, a playtest or proof of measured educational outcomes. The results use the documented completed-model fixture, not a claim that a full mission ends within the shortened gameplay segment. The final live-companion segment is a screenshot, not moving browser footage. [Checksums and export details](video-provenance.json).

## Rebuild

```sh
python scripts/build_demo_deck.py
soffice --headless --convert-to pdf --outdir docs/submission/demo-pack docs/submission/demo-pack/KOMAKU-5-Slide-Demo.pptx
python scripts/build_demo_pack_video.py
```

PowerPoint includes editable text, actual screenshots, and per-slide speaker notes. The 120-word pitch is intended for about 60 seconds; rehearse it rather than relying on a word-count guarantee. The five slides satisfy the supplied seven-slide maximum; the MP4 satisfies the supplied 30-second maximum. Confirm access to whichever public link you submit. No submission has been made on your behalf.
