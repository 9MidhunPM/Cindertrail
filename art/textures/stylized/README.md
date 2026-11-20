# Valley paint

These original seamless textures and trims were authored for Cindertrail using the
seeded NumPy/Pillow drawing in `tools/build_route_textures.py`. Run
`python tools/build_route_textures.py` to regenerate all three images.

| Image | Size | Contents |
| --- | --- | --- |
| route_paint.png | 1024 × 1024 | Linear RGBA masks for fissured limestone, timber grain, lichen clusters, and beaten copper patina |
| valley_brush.png | 1024 × 1024 | Linear RGBA masks for clustered two-tone leaves, chipped gravel, water caustics, and quarry haul marks |
| workshop_trim.png | 2048 × 768 | Six sRGB strips with hammered copper, chased brass, timber, carved stone, twisted rope, and enamel |

The Grove, upland, outer-valley, and frontier shaders project the family tiles in
world space. Rigid shrine, module, and ruin components have model-space paint so
their surfaces follow moving joints. The Godot import settings bind named glTF
material slots to the painted resources. Sun and lens slots retain their animated
emission. The atlas and all masks are drawn from seeded shapes and periodic
fields. No source illustration or external photograph is embedded in the paint.
