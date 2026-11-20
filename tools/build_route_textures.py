"""Build seamless paint masks for CinderTrail's carved trail props.

Run with Python, NumPy and Pillow. The fields wrap in both directions.
"""
from pathlib import Path

import numpy as np
from PIL import Image


SIZE = 256
OUTPUT = Path(__file__).resolve().parents[1] / "art/textures/stylized/route_paint.png"
random = np.random.default_rng(81355)
x, y = np.meshgrid(np.linspace(0, 1, SIZE, endpoint=False), np.linspace(0, 1, SIZE, endpoint=False))


def field(horizontal, vertical):
    grid = random.random((vertical, horizontal))
    u, v = x * horizontal, y * vertical
    i, j = np.floor(u).astype(int), np.floor(v).astype(int)
    u, v = u - i, v - j
    u, v = u * u * (3 - 2 * u), v * v * (3 - 2 * v)
    a = grid[j, i] * (1 - u) + grid[j, (i + 1) % horizontal] * u
    b = grid[(j + 1) % vertical, i] * (1 - u) + grid[(j + 1) % vertical, (i + 1) % horizontal] * u
    return a * (1 - v) + b * v


def ramp(lo, hi, value):
    t = np.clip((value - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


def main():
    broad = field(7, 6)
    flecks = field(68, 61)
    light_chips = ramp(0.61, 0.78, field(27, 29) * 0.62 + flecks * 0.38)
    pale_seams = 1 - ramp(0.028, 0.096, abs(np.sin(2 * np.pi * (y * 3 + broad * 0.28))))
    limestone = 0.33 + 0.29 * broad + 0.16 * light_chips + 0.09 * pale_seams + 0.12 * flecks
    grain = field(37, 4)
    dark_split = ramp(0.75, 0.95, field(54, 3))
    bark = 0.26 + 0.40 * grain + 0.16 * field(13, 3) + 0.13 * flecks - 0.12 * dark_split
    moss = 0.16 + 0.68 * ramp(0.37, 0.68, field(12, 10) * 0.42 + broad * 0.38 + flecks * 0.20)
    patina = 0.16 + 0.61 * ramp(0.4, 0.68, field(9, 8) * 0.50 + field(25, 22) * 0.35 + flecks * 0.15)
    channels = np.clip(np.stack((limestone, bark, moss, patina), axis=-1), 0.04, 0.95)
    Image.fromarray(np.rint(channels * 255).astype(np.uint8)).save(OUTPUT, optimize=True)


if __name__ == "__main__":
    main()
