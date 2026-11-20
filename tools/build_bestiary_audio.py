"""Render the valley's creature calls and the shrine's seamless extraction hum."""

from array import array
from math import cos, exp, pi, sin, tau
from pathlib import Path
from random import Random
import sys
import wave

RATE = 32000
OUTPUT = Path(__file__).resolve().parents[1] / "art" / "audio" / "valley"


def strike(t, hz, decay, rise=0.012):
    if t < 0:
        return 0.0
    return (1 - exp(-t / rise)) * exp(-t / decay) * sin(tau * hz * t)


def sweep(t, hz, hz_per_second):
    return sin(tau * (hz * t + 0.5 * hz_per_second * t * t))


def skimmer(t, air):
    value = 0.0
    for start, pitch in ((0, 550), (0.15, 670), (0.26, 860)):
        a = t - start
        if a > 0:
            value += (sweep(a, pitch, 1350) * 0.26 + air * 0.6) * exp(-a / 0.07)
    return value


def ram(t, air):
    value = 0.0
    for start, pitch in ((0, 87), (0.29, 72)):
        a = t - start
        if a > 0:
            value += strike(a, pitch, 0.12) + strike(a, pitch * 2.67, 0.055) * 0.33
            value += air * exp(-a / 0.09)
    return value


def splinter(t, air):
    value = 0.0
    for start, pitch in ((0, 1190), (0.14, 1480), (0.235, 1740), (0.31, 1585)):
        a = t - start
        if a > 0:
            value += strike(a, pitch, 0.07, 0.003) * 0.4
            value += strike(a, 0.54 * pitch, 0.11) * 0.23 + air * exp(-a / 0.038)
    return value


def warden(t, _air):
    return (strike(t, 329.6, 0.42) * 0.58 + strike(t, 733.4, 0.28) * 0.29
            + strike(t, 1184, 0.14) * 0.13 + strike(t - 0.18, 493.9, 0.42) * 0.36)


def vesper_call(t, air):
    breath = (1 - exp(-t / 0.19)) * exp(-t / 0.55)
    return breath * (sweep(t, 108, -18) + 0.35 * sweep(t, 161, -21) + 0.21 * air)


def vesper_charge(t, air):
    breath = min(t / 0.5, 1.0) * exp(-max(0, t - 0.51) / 0.11)
    return breath * (0.43 * sweep(t, 96, 160) + 0.3 * sweep(t, 143, 245) + 0.4 * air)


def vesper_pulse(t, air):
    return (strike(t, 61, 0.28) + strike(t, 148, 0.12) * 0.38
            + strike(t - 0.16, 88, 0.32) * 0.39 + exp(-t / 0.12) * air)


def vesper_exposed(t, _air):
    return sum(strike(t - j * 0.092, hz, 0.32) * (0.56 - j * 0.11)
               for j, hz in enumerate((392.0, 493.88, 587.33)))


def extraction(t, _air):
    # Integer cycles across four seconds keep the body and the moving shimmer seamless.
    swell = (1 - cos(tau * t / 4)) * 0.5
    return ((sin(tau * 110 * t) * 0.27 + sin(tau * 164.75 * t) * 0.2)
            * (0.77 + 0.23 * swell)
            + sin(tau * 329.5 * t + 0.85 * sin(pi * t)) * 0.14 * swell
            + sin(tau * 440 * t) * 0.06)


def write(name, duration, voice, seed):
    rng = Random(seed)
    pcm = array("h")
    air = 0.0
    for index in range(round(duration * RATE)):
        time = index / RATE
        air += (rng.uniform(-1, 1) - air) * 0.34
        fade = 1 if name == "extraction" else min(1, time / 0.004, (duration - time) / 0.04)
        pcm.append(round(24000 * max(-1, min(1, fade * voice(time, air)))))
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(OUTPUT / f"{name}.wav"), "wb") as track:
        track.setparams((1, 2, RATE, len(pcm), "NONE", "not compressed"))
        track.writeframes(pcm.tobytes())


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    sounds = [
        ("skimmer_wake", 0.62, skimmer), ("ram_stamp", 0.78, ram),
        ("splinter_rattle", 0.69, splinter), ("warden_chime", 1.38, warden),
        ("vesper_call", 2.16, vesper_call), ("vesper_charge", 0.92, vesper_charge),
        ("vesper_pulse", 1.03, vesper_pulse), ("vesper_exposed", 1.43, vesper_exposed),
        ("extraction", 4.0, extraction),
    ]
    for seed, (name, duration, voice) in enumerate(sounds):
        write(name, duration, voice, seed)
