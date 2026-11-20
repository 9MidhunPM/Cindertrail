# Route paint masks

`route_paint.png` is an original seamless 256×256 channel-packed texture. Red holds limestone
layers and chipped flecks, green holds elongated bark and timber grain, blue holds moss clusters,
and alpha holds bronze oxidation. The channels carry grayscale masks. The shaders supply the
color palette. Regenerate the PNG with `python tools/build_route_textures.py` using NumPy and Pillow.
