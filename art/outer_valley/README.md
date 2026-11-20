# Outer Valley art

`outer_land.glb` contains original Cindertrail geometry for Lanternwood, Sunken Aqueduct, Sunwatch Observatory and the roads between them. The limestone arcades, copper survey instrument, staggered tree crowns, trail paving, sluice pools and layered cliffs are authored variations on the supplied valley, side path, crossing and relay ascent illustrations.

Regenerate the mesh with `python3 tools/build_outer_valley.py` from a checkout with NumPy installed. The baker reads the trail graph and landmark coordinates from `data/outer_valley` and uses a fixed seed for small scenery. Godot imports the named terrain, bridge footings, architecture and tree trunks as static collision. Instantiating `scenes/world/outer_valley.tscn` applies the vertex pigments and supplied Grove shallows shader, installs both drawbridges, places the waymarks and creates the three defense sites. The project’s existing limestone, bronze and timber materials supply the moving bridge parts.
