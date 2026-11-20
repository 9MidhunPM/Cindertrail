# Material and model pipeline: matching the concept art

## The important distinction

The images are art-direction targets. Their look comes from large faceted shapes, a limited palette, composition, camera placement, local warm light, cool distance and restrained detail. Downloading a high-resolution stone texture will not create that result. Adding noisy photoreal PBR textures everywhere can actively make this project look less like its references.

Start by matching a single exploration frame (`art/concept/14_grove_crossing.png`) and one defense frame (`art/concept/05_grove_defense.png`) in-engine. They should represent the same physical location. Inspect screenshots from both cameras before expanding the world.

## Files already included

The material kit contains twenty named Godot colour/material resources, a technical palette atlas, vertex-colour and atlas materials, a simple water shader, a radial slowing-field shader and an editable Blender generator. `art/models/` contains static exported starter GLBs and an editable `.blend` library in `art/source/` when the generation step has run. Read `models_manifest.json` for actual asset names/counts and vertex counts.

These meshes establish shapes and scale. They still need intentional arrangement, collisions, interaction, animation and iteration against the reference art. Crawler and brute starters are unrigged; there is no final traveler model or finished game scene in this kit.

## Stage 1: palette and shape, before image textures

1. Import a cream stone arch, pillar, tree and folded shrine into Godot.
2. Build a small ground plane/causeway using chunky cream blocks and larger rocks. Keep walkable edges readable.
3. Use `cloth_teal`, `foliage_teal`, `foliage_light`, `leaves_orange`, `bronze` and `brass` consistently. Avoid adding new bright colours.
4. Give individual stone faces or blocks slight controlled colour variation, not random rainbow faces. Keep foliage colour concentrated in two teal values plus sparse orange leaves.
5. Set real face normals to flat or carefully mark hard edges. Keep silhouettes faceted; bevel only edges that catch useful light. Vertex normals, not polygon count alone, create the faceted look.
6. Keep brass moderately rough. Use metallic response on metal only; stone and cloth remain non-metallic.

### Option A: named solid materials

Fastest for bespoke props. Assign a small set of the supplied materials to faces in Blender, then export GLB. The shrine/tower starter meshes use this approach. Many small material slots create extra draw calls, so consolidate repeated pieces later.

### Option B: one palette atlas

Use the 5 × 4 `palette_atlas.png` as an albedo texture. UV a face or small face group to the centre of the desired swatch from `palette.json`. Sample inside the swatch, not at its boundary. Keep nearest filtering and repeat off. All faces of a mesh can then share the same atlas material. Separate metal/emissive parts if their physical material response differs.

### Option C: vertex colours

Paint broad vertex-colour regions in Blender, export the colour attribute through glTF, and use a material that enables vertex colour as albedo. Vertex colours work well for rocks, foliage and terrain. Keep enough vertices to express the transitions you actually need. Use real lighting for shading; do not bake strong highlights and deep directional shadows into every base colour.

## Stage 2: the camera and lighting recipe

Exploration uses a shoulder-height third-person camera behind the traveler. The traveler should occupy roughly 15–25% of frame height with reachable ground and distant landmarks visible. Defense raises and tilts that camera into a stable angled view, revealing sockets, approach lanes and escape routes.

Begin with:

- A cool moon/key light with restrained shadow softness.
- Low blue ambient/environment contribution that preserves darker silhouettes.
- One small warm core light and emissive core material. Limit its range and shadow cost.
- Layered background meshes and modest distance fog/atmosphere to separate near/mid/far terrain.
- Rough surfaces with simple readable highlights, not wet-looking stone everywhere.
- A restrained glow/halo treatment chosen and tested for the installed renderer/version.

Match exposure and colour grading before increasing texture resolution. Do not count on emission alone to light surrounding geometry. Place an actual local light with the shrine.

## Stage 3: optional tileable texture detail

Use subtle image texture detail only where close exploration cameras need it: cream limestone, dark wood, teal cloth and broad ground variation. A 512–1024-pixel tile is a sensible starting point; increase resolution only when a close camera demonstrates the need.

Obtain CC0 materials from the verified sources listed in the tools/asset research documents. For a PBR set, understand its channels: **base colour** supplies surface colour; **roughness** controls highlight width; **normal** adds small shading detail; **AO** adds local occlusion. Prefer an OpenGL normal map for Godot, or verify/flip the green channel if supplied as DirectX. Confirm the actual downloaded asset's license and keep its original source record.

To stylize a source texture:

1. Remove strong colour casts, baked highlights and high-frequency photographic contrast.
2. Tint toward the project palette and reduce saturation variation.
3. Use the material at low strength; retain large readable colour shapes.
4. Keep normal strength low. Avoid making small stones look like melted or deeply carved rock.
5. Use a shared trim sheet for brass edges/stone accents when repetition warrants it. Build one good trim rather than collecting inconsistent packs.

The included atlas is a palette texture, not a substitute for these optional PBR channels. The `.glb` starter models require no external texture downloads to display their colours.

## Blender → Godot transfer

The project uses meters, ground-aligned pivots and predictable object names. Export glTF binary (`.glb`) with materials, normals and any needed vertex-colour attributes. The builder exports Y-up GLBs, and Godot imports them into its coordinate system. Keep portable shrine variants as alternate visuals of **one gameplay core**, never two simultaneous items.

Do not assume arbitrary Blender procedural node networks transfer through GLB. Bake complex colour/roughness/normal results to images first, or recreate the effect in a Godot shader. The starter GLBs use simple portable Principled materials.

Add collisions and behavior in inherited Godot scenes rather than editing the generated GLB import. Author simple collision shapes: convex/block shapes for architecture, capsule for traveler, separate small hit areas for towers/enemies. Cosmetic orbital rings should not be physics obstacles.

## Asset priorities

| Priority | Asset | Required visual decisions |
| --- | --- | --- |
| 1 | Traveler | Teal hooded silhouette, readable cloak, clear carry harness, walk/run animations. |
| 1 | Single sun core | Broken/deployed, compact carried and restored variants with matching geometry. |
| 1 | Grove look-development slice | Cream causeway, turquoise water, teal tree canopy and orange accent leaves. |
| 2 | Three tower modules | Brass bolt prongs; squat cyan mushroom; open cream mortar cup. |
| 2 | Crawlers/brutes | Low fast turquoise-cracked shape versus heavy violet-cracked silhouette. |
| 3 | Quarry/relay modular kits | Reuse stone/bronze palette while making lane layouts and silhouettes distinct. |

## Technical validation used for this kit

The generation environment contains Blender 4.3.2 and Godot 4.7.2 stable. The package's validation notes record the actual checks completed; reproducing them on another Godot minor version is still necessary. Optional renderer features change between versions. Web export should be a separate profile and visual check, not an assumed pixel-identical copy of native rendering.

## The visual acceptance gate

A successful first slice should look recognizably like Cindertrail with the HUD hidden: teal traveler, one golden shrine, cream ruins, blue distance, restrained orange foliage and readable paths. Compare screenshots against the selected references. If the scene is only gray blocks or unrelated stock assets, continue the art pass before adding more gameplay content.
