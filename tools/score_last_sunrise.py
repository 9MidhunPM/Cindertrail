"""Render Cindertrail's original 26-second beacon score. Requires NumPy and FFmpeg."""

from pathlib import Path
import re
import subprocess

import numpy as np

RATE = 32000
END = 26.0
TAU = 2.0 * np.pi
TARGET = Path(__file__).resolve().parents[1] / "art/audio/valley/last_sunrise.ogg"
RING_LOCK = 1.25
PITCH = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
PCM = np.zeros((round(END * RATE), 2))
RNG = np.random.default_rng(845022)


def frequency(note):
    letter, sharp, octave = re.fullmatch(r"([A-G])(#?)(\d)", note).groups()
    midi = 12 * (int(octave) + 1) + PITCH[letter] + len(sharp)
    return 440.0 * 2 ** ((midi - 69) / 12)


def voice(start, duration, samples, gain, pan):
    """Equal-power placement in the small chamber ensemble."""
    first = round(start * RATE)
    frames = min(round(duration * RATE), len(samples), len(PCM) - first)
    angle = (pan + 1.0) * np.pi / 4.0
    PCM[first:first + frames] += gain * samples[:frames, None] * [np.cos(angle), np.sin(angle)]


def timebase(length):
    return np.arange(round(length * RATE)) / RATE


def ease(x):
    x = np.clip(x, 0, 1)
    return x * x * (3.0 - 2.0 * x)


def bowed(start, duration, note, gain, pan):
    t = timebase(duration)
    hz = frequency(note)
    entry = 0.42 if hz > 150 else 0.62
    env = ease(t / entry) * ease((duration - t) / min(.62, duration * .28))
    env *= .83 + .17 * np.sin(np.pi * t / duration)
    # Two players bow at slightly different rates and pitches.
    for player, cents in enumerate((-3.1, 2.1)):
        speed = 4.55 + .38 * player
        f = hz * 2 ** (cents / 1200)
        phase = TAU * f * t + .0028 * f / speed * np.sin(TAU * speed * t + player)
        tone = np.zeros_like(t)
        for partial, weight in enumerate((1., .38, .30, .085, .12, .042, .045, .024), 1):
            tone += weight * np.sin(partial * phase + partial * .23 * player)
        voice(start, duration, env * tone, gain * .52, pan + (player - .5) * .16)


def horn(start, duration, note, gain, pan=-.08):
    t = timebase(duration)
    hz = frequency(note)
    phase = TAU * hz * t + .14 * np.sin(TAU * 4.85 * t) * ease((t - .17) / .48)
    breath = ease(t / .11) * ease((duration - t) / .33)
    bloom = ease(t / .37) * ease((duration - t) / .48)
    tone = np.sin(phase) + .33 * bloom * np.sin(2 * phase) + .17 * bloom * np.sin(3 * phase)
    voice(start, duration, breath * tone, gain, pan)


def pluck(start, note, gain, pan):
    t = timebase(1.95)
    hz = frequency(note)
    tone = np.zeros_like(t)
    for ratio, weight, decay in ((1., 1., .48), (2.005, .41, .30), (3.014, .21, .21), (4.03, .10, .13)):
        tone += weight * np.sin(TAU * hz * ratio * t) * np.exp(-t / decay)
    voice(start, 1.95, tone * ease(t / .004) * ease((1.95 - t) / .08), gain, pan)


def bronze(start, note, gain, pan):
    t = timebase(2.7)
    hz = frequency(note)
    partials = ((1., .82, .68), (2.01, .35, .61), (2.39, .26, .48), (3.97, .17, .21))
    tone = sum(w * np.sin(TAU * hz * r * t) * np.exp(-t / d) for r, w, d in partials)
    voice(start, 2.7, tone * ease(t / .007) * ease((2.7 - t) / .12), gain, pan)


def ring_contact(start):
    t = timebase(.15)
    noise = RNG.uniform(-1., 1., len(t))
    # Clasp contact and a short bronze after-tick, dry and close to the listener.
    click = np.diff(noise, prepend=0) * np.exp(-t / .009)
    click += .35 * np.sin(TAU * 1780 * t) * np.exp(-t / .026)
    voice(start, .15, click * ease(t / .0011), .17, -.03)
    bronze(start + .028, "A4", .094, .04)


def arrange():
    # Handoff, arch, ford, village, and the real summit share the rising F#–A–D figure.
    pads = [
        (.10, 4.50, ("B2", "F#3", "A3", "D4"), .105),
        (3.95, 5.57, ("G2", "D3", "B3", "A4"), .120),
        (8.93, 3.20, ("D2", "A3", "F#4", "B4"), .119),
        (11.70, 3.79, ("E2", "B3", "G4", "D5"), .108),
        (14.85, 3.72, ("G2", "D3", "B3", "F#4"), .133),
        (18.05, 2.12, ("A2", "E3", "D4", "G4"), .124),
        (19.77, 1.78, ("A2", "E3", "C#4", "A4"), .122),
        (20.92, 5.06, ("D2", "A3", "F#4", "E5"), .142),
    ]
    for at, duration, harmony, gain in pads:
        for i, note in enumerate(harmony):
            bowed(at + .037 * i, duration - .037 * i, note, gain * (1.0 if i < 3 else .61),
                  (-.15, .34, -.43, .51)[i])
    # A lone harp at the handoff grows into an answered phrase as the light travels.
    harp = [
        (.42, "F#4"), (.90, "A4"), (2.04, "D5"),
        (4.04, "D4"), (4.51, "G4"), (5.05, "A4"), (6.31, "B4"), (7.92, "D5"),
        (9.08, "A3"), (9.53, "D4"), (10.14, "F#4"), (11.05, "A4"),
        (12.01, "B3"), (12.64, "E4"), (13.29, "G4"), (14.06, "B4"),
        (15.30, "G3"), (16.02, "D4"), (16.74, "G4"), (17.44, "A4"),
        (18.26, "E4"), (19.04, "A4"), (20.12, "C#5"),
        (21.11, "D4"), (21.80, "A4"), (22.45, "D5"), (23.37, "F#5"),
    ]
    for i, (at, note) in enumerate(harp):
        pluck(at, note, .118 if at >= 4 else .093, -.46 if i % 2 else .37)
    for at, duration, note in [
        (4.27, 1.16, "F#4"), (5.30, 1.32, "A4"), (6.51, 2.21, "D5"),
        (9.08, 1.49, "A4"), (10.46, 1.42, "F#4"), (11.80, 1.52, "E4"), (13.24, 1.55, "G4"),
        (15.12, 1.35, "B4"), (16.33, 1.39, "A4"), (17.60, 1.51, "D5"), (19.03, 1.99, "C#5"),
        (21.01, 2.07, "D5"), (22.91, 2.65, "A4"),
    ]:
        horn(at, duration, note, .19 if at < 15 else .225)
    ring_contact(RING_LOCK)
    bronze(8.98, "D5", .083, .48)
    bronze(15.16, "G4", .088, -.45)
    bronze(21.18, "D5", .098, .16)
    bronze(23.55, "A5", .052, .39)


def render():
    arrange()
    dry = PCM.copy()
    # Fixed early reflections and a short stereo tail leave the clasp transient clear.
    for delay, level in ((.041, .13), (.071, .10), (.119, .077), (.213, .063),
                         (.317, .043), (.469, .029), (.613, .017), (.809, .012)):
        frames = round(RATE * delay)
        PCM[frames:] += level * dry[:-frames, ::-1]
    t = timebase(END)
    PCM[:] *= (ease(t / .04) * ease((END - t) / .97))[:, None]
    normalized = .84 * PCM / np.max(np.abs(PCM))
    subprocess.run([
        "ffmpeg", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", "2",
        "-i", "pipe:0", "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact",
        "-c:a", "libvorbis", "-q:a", "4", str(TARGET),
    ], input=normalized.astype("<f4").tobytes(), check=True)


if __name__ == "__main__":
    render()
