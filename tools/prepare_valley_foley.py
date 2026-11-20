#!/usr/bin/env python3
"""Assemble the game's recorded foley from two Kenney archives and the Rubberduck pack."""

import argparse
from pathlib import Path
import subprocess
import wave
from zipfile import ZipFile

import numpy as np


RATE = 48_000
ROOT = Path(__file__).resolve().parents[1]


def decode(content, rate=RATE):
    result = subprocess.run(
        ["ffmpeg", "-nostdin", "-loglevel", "error", "-i", "pipe:0", "-ac", "1",
         "-ar", str(rate), "-f", "f32le", "pipe:1"],
        input=content, stdout=subprocess.PIPE, check=True,
    )
    return np.frombuffer(result.stdout, dtype="<f4").copy()


def sample(archive, stem):
    return decode(archive.read(f"Audio/{stem}.ogg"))


def aligned(sound, threshold=0.025):
    nonzero = np.flatnonzero(np.abs(sound) > np.abs(sound).max() * threshold)
    if not nonzero.size:
        return sound
    return sound[max(0, int(nonzero[0]) - 120):]


def mix(parts):
    samples = np.zeros(max(len(track) + round(delay * RATE) for track, _, delay in parts),
                       dtype=np.float32)
    for track, gain, delay in parts:
        start = round(delay * RATE)
        samples[start:start + len(track)] += track * gain
    return samples


def write(samples, path, peak, seamless=False):
    if seamless:
        overlap = min(RATE, len(samples) // 5)
        gain = np.linspace(0.0, 1.0, overlap)
        joined = samples[-overlap:] * (1.0 - gain) + samples[:overlap] * gain
        samples = np.concatenate((joined, samples[overlap:-overlap]))
    else:
        samples = aligned(samples)
        release = min(len(samples), 480)
        samples[-release:] *= np.linspace(1.0, 0.0, release)
    samples = samples * (10.0 ** (peak / 20.0) / max(0.0001, np.abs(samples).max()))
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes((samples * 32767).astype("<i2"))


def combat_and_steps(source, destination):
    count = 0
    with ZipFile(source / "kenney_rpg-audio.zip") as rpg, ZipFile(source / "kenney_impact-sounds.zip") as impacts:
        for take in range(4):
            def hit(kind):
                return aligned(sample(impacts, f"{kind}_{take:03d}"))

            def prop(stem):
                return aligned(sample(rpg, stem))

            slice_name = "knifeSlice2" if take % 2 else "knifeSlice"
            cloth = prop(f"cloth{take + 1}")
            knife = prop(slice_name)
            steel = hit("impactMetal_medium")
            thump = hit("impactPunch_heavy")
            stone = hit("impactMining")
            shell = hit("impactPlate_heavy")
            steps = [
                hit("footstep_concrete"),
                prop(f"footstep{take + 1:02d}"),
            ]
            grooves = {
                "slash": ([(cloth, .25, 0.0), (knife, .8, .015)], -13.0),
                "impact": ([(steel, .75, 0.0), (thump, .6, .009)], -10.0),
                "slam": ([(shell, .7, .005), (thump, .8, 0.0), (stone, .28, .027)], -8.5),
                "spin": ([(cloth, .65, 0.0), (knife, .65, .033),
                          (knife[::-1].copy(), .26, .16)], -12.5),
                "mortar": ([(stone, .7, 0.0), (thump, .75, .015), (shell, .25, .028)], -11.0),
                "deploy": ([(prop("metalLatch"), .65, .035), (shell, .27, .108),
                            (cloth, .45, 0.0)], -12.0),
                "pack": ([(cloth, .65, .0), (prop("clothBelt"), .55, .075),
                          (prop("metalClick"), .35, .16)], -14.0),
                "hurt": ([(thump, .65, .0), (cloth, .22, .011)], -13.0),
                "collect": ([(prop("handleCoins2" if take % 2 else "handleCoins"), .67, 0.0),
                             (prop("metalClick"), .35, .05)], -15.0),
                "build": ([(stone, .61, .018), (prop("metalClick"), .55, .0)], -14.0),
                "footstep": ([(steps[take % 2], .78, 0.0), (cloth, .15, .016)], -23.0),
            }
            for cue, (layers, peak) in grooves.items():
                write(mix(layers), destination / cue / f"take_{take + 1}.wav", peak)
                count += 1
    return count


def ambience(source, destination):
    pack = source / "sfx_100_v2.zip"
    if not pack.exists():
        return 0
    with ZipFile(pack) as archive:
        def recorded(stem):
            return decode(archive.read(f"sfx100v2_{stem}.ogg"))

        air = recorded("air_01")
        diffuse_air = np.convolve(air, np.ones(17) / 17, mode="same")
        background = recorded("loop_ambient_01")
        wind = mix([(background, .48, 0), (diffuse_air, .28, 1.2),
                    (diffuse_air[::-1], .20, 5.3)])
        write(recorded("loop_water_02"), destination / "water" / "bed.wav", -16.5, seamless=True)
        write(wind, destination / "wind" / "bed.wav", -22.0, seamless=True)
        write(background, destination / "woodland" / "bed.wav", -20.0, seamless=True)
        for take in range(1, 4):
            write(recorded(f"footstep_wet_{take:02d}"),
                  destination / "footstep_wet" / f"take_{take}.wav", -22.0)
        return 6


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / "art/audio/foley")
    options = parser.parse_args()
    clips = combat_and_steps(options.source, options.output)
    field_recordings = ambience(options.source, options.output)
    print(f"Prepared {clips} layered cues and {field_recordings} edited field recordings")


if __name__ == "__main__":
    main()
