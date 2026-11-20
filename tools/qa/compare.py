#!/usr/bin/env python3
"""Compose actual Grove captures next to the corresponding concept boards."""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


PAIRS = [
    ("14_grove_crossing.png", "grove-exploration.png", "Exploration"),
    ("05_grove_defense.png", "grove-tactical.png", "Tactical view"),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("revised", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    concept_dir = Path(__file__).resolve().parents[2] / "art" / "concept"
    cell_width, cell_height = 600, 337
    gap, padding, heading = 16, 26, 36
    width = cell_width * 3 + gap * 2 + padding * 2
    height = (cell_height + heading + gap) * 2 + padding * 2 - gap
    board = Image.new("RGB", (width, height), "#0a1622")
    draw = ImageDraw.Draw(board)
    font = ImageFont.load_default(size=20)
    for row, (concept, capture, label) in enumerate(PAIRS):
        items = [
            (concept_dir / concept, "Concept"),
            (args.baseline / capture, "First runtime pass"),
            (args.revised / capture, "Revised runtime pass"),
        ]
        top = padding + row * (cell_height + heading + gap)
        for column, (path, title) in enumerate(items):
            left = padding + column * (cell_width + gap)
            with Image.open(path) as source:
                frame = source.convert("RGB")
            frame.thumbnail((cell_width, cell_height), Image.Resampling.LANCZOS)
            board.paste(frame, (left + (cell_width - frame.width) // 2, top + heading))
            draw.text((left, top), f"{label} | {title}", font=font, fill="#efe3c6")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    board.save(args.output)


if __name__ == "__main__":
    main()
