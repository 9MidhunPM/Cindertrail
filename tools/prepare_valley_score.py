#!/usr/bin/env python3
"""Prepare Cindertrail's seamless music loops from Scott Buckley's source mixes.

Pass the directory containing the six MP3s identified in art/audio/score/README.md.
The MP3s can remain outside the project. Requires NumPy and FFmpeg.
"""

import argparse
import json
import math
from pathlib import Path
import subprocess
import tempfile
import wave

import numpy as np


RATE = 48_000
CHANNELS = 2
TARGET_LUFS = -18.0
PEAK_LIMIT_DB = -2.0
ROOT = Path(__file__).resolve().parents[1]

# Filename, start seconds, excluded tail seconds, join seconds.
TRACKS = {
    "exploration": ("MemoriesOfStone.mp3", 1.0, 7.0, 3.8),
    "exploration_alt": ("sb_hiraeth.mp3", 1.0, 7.0, 4.2),
    "defense": ("sb_terminus.mp3", 35.0, 13.0, 2.2),
    "defense_alt": ("sb_legionnaire2022.mp3", 8.0, 9.0, 2.8),
    "pursuit": ("sb_hunted.mp3", 5.0, 6.0, 1.7),
    "vesper": ("SongOfTheForge.mp3", 29.0, 12.0, 3.1),
}


def ffmpeg(*args, capture_stderr=False):
    return subprocess.run(
        ["ffmpeg", "-nostdin", "-hide_banner", *map(str, args)],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE if capture_stderr else None,
    )


def make_loop(source, opening, tail, join):
    result = ffmpeg("-loglevel", "error", "-i", source, "-f", "f32le",
                    "-ac", CHANNELS, "-ar", RATE, "-")
    samples = np.frombuffer(result.stdout, dtype="<f4").reshape(-1, CHANNELS)
    samples = samples[round(opening * RATE):len(samples) - round(tail * RATE)]
    overlap = round(join * RATE)
    if len(samples) <= overlap * 2:
        raise ValueError(f"{source.name} does not contain enough audio for its loop")

    # The blend opens on the last phrase and lands on the opening phrase. The
    # start and end of the resulting file then sit on consecutive source samples.
    weight = np.linspace(0.0, math.pi / 2, overlap, dtype=np.float32)[:, None]
    blended = samples[-overlap:] * np.cos(weight) + samples[:overlap] * np.sin(weight)
    loop = np.concatenate((blended, samples[overlap:-overlap]))
    # Vorbis encodes the leading and trailing blocks independently. A short
    # shared zero crossing removes the small step the encoder can leave there.
    ramp_frames = round(.012 * RATE)
    ramp = np.sin(np.linspace(0.0, math.pi / 2, ramp_frames, dtype=np.float32))[:, None]
    loop[:ramp_frames] *= ramp
    loop[-ramp_frames:] *= ramp[::-1]
    return loop


def pack_wav(samples, path):
    with wave.open(str(path), "wb") as output:
        output.setnchannels(CHANNELS)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes((np.clip(samples, -1.0, 1.0) * 32767).astype("<i2"))


def get_levels(path):
    result = ffmpeg("-i", path, "-af", "loudnorm=print_format=json",
                    "-f", "null", "-", capture_stderr=True)
    report = result.stderr.decode()
    return json.loads(report[report.rindex("{"):report.rindex("}") + 1])


def encode(source_dir, key, destination):
    filename, opening, tail, join = TRACKS[key]
    source = source_dir / filename
    samples = make_loop(source, opening, tail, join)
    with tempfile.TemporaryDirectory(prefix="cinder-score-") as scratch:
        wav = Path(scratch) / "loop.wav"
        peak = float(np.abs(samples).max())
        headroom = min(1.0, .97 / peak)
        pack_wav(samples * headroom, wav)
        levels = get_levels(wav)
        gain = min(TARGET_LUFS - float(levels["input_i"]),
                   PEAK_LIMIT_DB - float(levels["input_tp"]))
        output = destination / f"{key}.ogg"
        ffmpeg("-loglevel", "error", "-y", "-i", wav, "-map_metadata", "-1",
               "-af", f"volume={gain:.3f}dB", "-c:a", "libvorbis", "-q:a", "6", output)
    result = get_levels(output)
    print(f"{key} {len(samples) / RATE:.1f}s | {result['input_i']} LUFS | "
          f"{result['input_tp']} dBTP | {output.stat().st_size:,} bytes")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Directory containing the original MP3 files")
    parser.add_argument("--only", action="append", choices=TRACKS, help="Prepare only these cues")
    parser.add_argument("--output", type=Path, default=ROOT / "art/audio/score")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    for key in args.only or TRACKS:
        encode(args.source, key, args.output)


if __name__ == "__main__":
    main()
