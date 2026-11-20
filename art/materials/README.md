# Cindertrail material starter kit

These are real reusable resources, distinct from the AI concept art. They establish a shared palette and material response; they do not recreate the entire illustrated game by themselves.

- `palette.json`: 20 named colour choices, hexadecimal/sRGB values and atlas UV centres.
- `palette_atlas.png`: exact 5 × 4 colour atlas, 320 × 256 pixels, each swatch 64 × 64. This is a technical colour texture, not a seamless stone/cloth/PBR texture.
- `palette_reference.svg`: labelled palette for art direction.
- Twenty named `StandardMaterial3D` resources: cream stone, aged bronze/brass, teal cloth/foliage, orange vegetation, amber sun and cyan/violet emissive accents.
- `palette_atlas_material.tres`: one shared atlas material; UV faces to the swatch centres listed in JSON. Nearest filtering; repeat disabled.
- `vertex_palette_material.tres`: white material using vertex colour as albedo.
- `stylized_water.gdshader` and `water_material.tres`: restrained transparent teal water with low-amplitude vertex waves. Use a subdivided plane; this does not simulate water or reproduce screen-space reflections.
- `slowing_field.gdshader` and `slowing_field_material.tres`: low-cost cyan radial rings for a ground-aligned plane. Use it for visual feedback; slowing gameplay is separate code.
- `starter_asset_preview.png`: a real Blender render of the delivered starter meshes, if the builder was run with `--render`.

## Import

Preserve `art/materials/` under the Godot project root, because the resources use `res://art/materials/...`. Copy `art/models/` as well for the GLBs. If using a nested game project, copy these folders into that project's `art/` directory.

The GLBs already include colour/material assignments. The `.tres` files are optional reusable overrides. Broad colour grouping and roughness matter more to this style than photoreal surface noise.

## Rebuild

```bash
python3 scripts/make_palette.py
blender --background --python scripts/build_blender_assets.py -- --output art/models --render
```

The palette script requires Pillow. The asset builder runs inside Blender and reads the generated palette JSON. It overwrites its own named GLBs, `art/source/` `.blend` library and preview; commit your edited versions under new filenames first.

## Rendering profiles

Use the installed stable Godot version as the source of truth for renderer support. Validate native and web separately. Begin with ordinary materials, a directional moon light, warm local core light, restrained fog/atmosphere and modest shadows. Enable optional glow only after testing it on the selected renderer/version. The kit does not require volumetric fog, SSR or high-end global illumination. A transparent emissive halo mesh is a useful fallback for the core's glow.

## Ownership and scope

The palette, scripts, shaders and simple generated meshes in this kit were authored for this project and are provided for the user's use and modification. No external asset files are bundled in this material kit. Do not treat the AI concept images or the uploaded video as CC0 stock assets. The two creature models are static unrigged visual starters, not animation-ready production characters.
