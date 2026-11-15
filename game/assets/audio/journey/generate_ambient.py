#!/usr/bin/env python3
"""Reproduce KŌMAKU's original ambient fallback loops; no samples are used.

Requires Python's standard library and ffmpeg with libvorbis. The PCM score is
deterministic; Vorbis container serials can vary between encoder builds.
"""
from array import array
import math
from pathlib import Path
import subprocess
import tempfile
import wave

ROOT = Path(__file__).resolve().parent
RATE = 22050
SECONDS = 16
SCORES = {
    "orbit": (110.0, 146.8125, 220.0, 293.625),
    "surface": (98.0, 146.8125, 196.0, 261.625),
    "reflection": (130.8125, 196.0, 261.625, 329.625),
}


def render(name, notes, target):
    samples = array("h")
    for index in range(RATE * SECONDS):
        t = index / RATE
        seam = min(1.0, t / 0.20, (SECONDS - t) / 0.20)
        breathe = 0.65 + 0.12 * math.sin(math.tau * t / SECONDS)
        left = right = 0.0
        for voice, frequency in enumerate(notes[:3]):
            # Frequencies fit the 16-second loop to avoid a waveform jump.
            frequency = round(frequency * SECONDS) / SECONDS
            amp = 0.085 / (1 + voice * 0.45)
            phase = math.tau * frequency * t
            harmonic = math.sin(phase) + 0.15 * math.sin(phase * 2)
            left += amp * harmonic * breathe
            right += amp * math.sin(phase + voice * 0.24) * breathe
        # Sparse, soft bells make a small original score rather than a drone.
        for step, note in enumerate((0, 2, 1, 3)):
            onset = 1.0 + step * 3.5
            age = t - onset
            if 0 <= age < 3.0:
                envelope = (1 - math.exp(-age * 18)) * math.exp(-age * 1.7)
                bell = 0.060 * envelope * math.sin(math.tau * notes[note] * 2 * age)
                left += bell * (0.85 if step % 2 else 1)
                right += bell * (1 if step % 2 else 0.85)
        samples.append(round(max(-0.9, min(0.9, left * seam * 1.8)) * 32767))
        samples.append(round(max(-0.9, min(0.9, right * seam * 1.8)) * 32767))
    if __import__("sys").byteorder != "little":
        samples.byteswap()
    with wave.open(str(target), "wb") as stream:
        stream.setnchannels(2)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(samples.tobytes())


def main():
    with tempfile.TemporaryDirectory(prefix="komaku-original-audio-") as temp:
        for name, notes in SCORES.items():
            wav = Path(temp) / (name + ".wav")
            render(name, notes, wav)
            subprocess.run([
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                "-i", str(wav), "-c:a", "libvorbis", "-q:a", "4",
                "-metadata", "title=KOMAKU original ambient " + name,
                "-metadata", "comment=Procedural project score; no external samples",
                str(ROOT / (name + ".ogg")),
            ], check=True)
            print(name, (ROOT / (name + ".ogg")).stat().st_size, "bytes")


if __name__ == "__main__":
    main()
