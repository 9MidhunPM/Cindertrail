#!/usr/bin/env python3
"""Regenerate exact project colour data, Godot materials and a technical palette atlas.

Run with Python 3 and Pillow: python scripts/make_palette.py
This builds deterministic colour swatches, not AI image textures.
"""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art" / "materials"
COLORS = {
    "stone_cream": "D9C8A4", "stone_light": "F1DFC0", "stone_shadow": "9EABAA",
    "bronze_dark": "6E4B2B", "bronze": "A77838", "brass": "C99848",
    "cloth_teal": "16566B", "cloth_shadow": "103A4B", "foliage_teal": "158878",
    "foliage_light": "3AB49D", "leaves_orange": "C96B27", "leaves_gold": "E5A145",
    "enemy_charcoal": "172732", "night_blue": "173E66", "sun_amber": "FFB632",
    "field_cyan": "45DED9", "water_teal": "178E99", "brute_violet": "9256C9",
    "wood": "745139", "soil": "6E7464",
}

def rgb(code):
    return tuple(int(code[i:i+2], 16) / 255 for i in (0, 2, 4))

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    swatch = 64
    columns, rows = 5, 4
    atlas = Image.new("RGB", (columns * swatch, rows * swatch))
    data = {"atlas": "palette_atlas.png", "columns": columns, "rows": rows,
            "swatch_pixels": swatch, "usage": "Sample UV at swatch centers; use nearest filtering and disable repeat.", "colors": {}}
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="1100" height="520" viewBox="0 0 1100 520">',
           '<rect width="1100" height="520" fill="#f4ead8"/>',
           '<text x="24" y="32" font-family="sans-serif" font-size="22" fill="#103a4b">CINDERTRAIL — MATERIAL PALETTE</text>']
    for n, (name, code) in enumerate(COLORS.items()):
        x, y = n % columns, n // columns
        atlas.paste(tuple(int(code[i:i+2], 16) for i in (0, 2, 4)), (x*swatch, y*swatch, (x+1)*swatch, (y+1)*swatch))
        color = rgb(code)
        data["colors"][name] = {"hex": "#" + code, "srgb": color,
                              "atlas_uv_center": [(x + .5)/columns, (y + .5)/rows]}
        metallic = .65 if name.startswith(("bronze", "brass")) else 0
        roughness = .5 if metallic else .88
        extra = ""
        if name in ("sun_amber", "field_cyan", "brute_violet"):
            extra = f'\nemission_enabled = true\nemission = Color({color[0]:.6f}, {color[1]:.6f}, {color[2]:.6f}, 1)\nemission_energy_multiplier = {2.0 if name == "sun_amber" else 1.2}'
        text = f'''[gd_resource type="StandardMaterial3D" format=3]

[resource]
resource_name = "{name}"
albedo_color = Color({color[0]:.6f}, {color[1]:.6f}, {color[2]:.6f}, 1)
metallic = {metallic}
roughness = {roughness}{extra}
'''
        (OUT / (name + ".tres")).write_text(text)
        sx, sy = 24 + x * 215, 58 + y * 114
        svg += [f'<rect x="{sx}" y="{sy}" width="190" height="64" rx="5" fill="#{code}"/>',
                f'<text x="{sx}" y="{sy+82}" font-family="monospace" font-size="13" fill="#103a4b">{name}</text>',
                f'<text x="{sx}" y="{sy+99}" font-family="monospace" font-size="12" fill="#40505a">#{code}</text>']
    svg.append('</svg>')
    atlas.save(OUT / "palette_atlas.png")
    (OUT / "palette.json").write_text(json.dumps(data, indent=2) + "\n")
    (OUT / "palette_reference.svg").write_text("\n".join(svg))
    print(f"Created {len(COLORS)} Godot materials, palette atlas, JSON and SVG in {OUT}")

if __name__ == "__main__":
    main()
