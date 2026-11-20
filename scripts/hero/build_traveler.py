"""Rebuild the articulated traveler, sunsteel blade and folded shrine fittings.

    blender -b -P scripts/hero/build_traveler.py

Garments are authored in rest-pose world coordinates (Blender Z up, the
traveler faces +Y, the right hand is +X) and parented to the joint empty that
animates them. scripts/hero/traveler_visual.gd poses those empties in Godot.
Shapes follow art/concept/03_traveler_shrine_sheet.png: a tall pointed hood
around a faceless void, a jagged shoulder capelet, a long split coat with
ochre-lined tails and a half-sun emblem, a leather harness with a brass
medallion, bracers, gloves, gathered charcoal trousers and buckled boots.
"""
import bpy
import math
import random
from collections import defaultdict
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
TAU = math.tau
UP = Vector((0.0, 0.0, 1.0))
rng = random.Random(70211)


def reset() -> None:
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.meshes, bpy.data.materials):
        for item in list(collection):
            if item.users == 0:
                collection.remove(item)


def srgb(code: str) -> tuple:
    return tuple(((int(code[i:i + 2], 16) / 255 + .055) / 1.055) ** 2.4 for i in (0, 2, 4))


MATERIALS = {}
SURFACE_TILES = {}


def surface_tile(kind):
    """Render subdued, repeatable material masks for embedding in the GLB."""
    if kind in SURFACE_TILES:
        return SURFACE_TILES[kind]
    size = 128
    grain = random.Random(11283)
    image = bpy.data.images.new(kind, width=size, height=size, alpha=False)
    image.colorspace_settings.name = 'Non-Color'
    pixels = []
    for y in range(size):
        v = y / size * TAU
        for x in range(size):
            u = x / size * TAU
            mottling = math.sin(3 * u + 2 * v + math.sin(2 * v)) * math.cos(2 * v - u)
            dust = grain.uniform(-.036, .036)
            if kind == 'Brushed wool':
                weave = math.cos(27 * u) * math.sin(24 * v + math.sin(u))
                stroke = math.sin(4 * u - 9 * v + math.sin(3 * v))
                value = .88 + mottling * .080 + weave * .035 + stroke * .042 + dust
            elif kind == 'Oiled leather':
                crease = abs(math.sin(4 * u + v + .8 * math.sin(3 * v)))
                value = .89 + mottling * .073 - crease ** 9 * .115 + dust
            else:
                hammer = math.sin(9 * u - 3 * v) * math.sin(11 * v + 4 * u)
                value = .91 + mottling * .066 + hammer * .038 + dust
            value = min(1.0, value)
            pixels.extend((value, value, value, 1.0))
    image.pixels.foreach_set(pixels)
    image.pack()
    SURFACE_TILES[kind] = image
    return image


def material(name, code, metallic=0.0, rough=.8, glow=0.0, tile=None):
    value = bpy.data.materials.new(name)
    color = srgb(code) + (1.0,)
    value.diffuse_color = color
    shader = value.node_tree.nodes['Principled BSDF']
    shader.inputs['Base Color'].default_value = color
    shader.inputs['Metallic'].default_value = metallic
    shader.inputs['Roughness'].default_value = rough
    if tile:
        nodes = value.node_tree.nodes
        links = value.node_tree.links
        raster = nodes.new('ShaderNodeTexImage')
        raster.image = surface_tile(tile)
        tint = nodes.new('ShaderNodeMix')
        tint.data_type = 'RGBA'
        tint.blend_type = 'MULTIPLY'
        tint.inputs[0].default_value = 1.0
        tint.inputs[6].default_value = color
        links.new(raster.outputs['Color'], tint.inputs[7])
        links.new(tint.outputs[2], shader.inputs['Base Color'])
    if glow > 0.0:
        shader.inputs['Emission Color'].default_value = color
        shader.inputs['Emission Strength'].default_value = glow
    # Garment interiors are visible while the camera orbits or a panel lifts.
    value.use_backface_culling = False
    MATERIALS[name] = value
    return name


class Part:
    """Faces collected for one joint; joined into a single multi-material mesh."""

    def __init__(self):
        self.points = []
        self.faces = []
        self.slots = []

    def face(self, corners, slot, out=None):
        pts = []
        for corner in corners:
            corner = Vector(corner)
            if not pts or (corner - pts[-1]).length > 1e-6:
                pts.append(corner)
        if len(pts) > 2 and (pts[0] - pts[-1]).length < 1e-6:
            pts.pop()
        if len(pts) < 3:
            return
        if out is not None:
            normal = (pts[1] - pts[0]).cross(pts[2] - pts[0])
            if normal.length > 1e-9 and normal.dot(Vector(out)) < 0.0:
                pts.reverse()
        base = len(self.points)
        self.points.extend(pts)
        self.faces.append(tuple(range(base, base + len(pts))))
        self.slots.append(slot)


PARTS = defaultdict(Part)
JOINTS = {}


def joint(name, location, parent=None, basis=None):
    empty = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(empty)
    world = Matrix.Translation(Vector(location))
    if basis is not None:
        world = world @ basis.to_4x4()
    if parent is not None:
        bpy.context.view_layer.update()
        empty.parent = JOINTS[parent]
        empty.matrix_basis = JOINTS[parent].matrix_world.inverted() @ world
    else:
        empty.matrix_basis = world
    JOINTS[name] = empty
    return empty


def realize(name, part):
    mesh = bpy.data.meshes.new(name + 'Geometry')
    mesh.from_pydata([tuple(p) for p in part.points], [], part.faces)
    order = list(dict.fromkeys(part.slots))
    for slot in order:
        mesh.materials.append(bpy.data.materials[slot])
    for polygon, slot in zip(mesh.polygons, part.slots):
        polygon.material_index = order.index(slot)
    mesh.shade_flat()
    mesh.update()
    # These parts move as rigid layers. Project each facet in its rest-pose
    # coordinates so the fabric pattern stays with the garment as it moves.
    uvs = mesh.uv_layers.new(name='Surface')
    for polygon in mesh.polygons:
        normal = polygon.normal
        drop = max(range(3), key=lambda axis: abs(normal[axis]))
        u, v = ((1, 2), (0, 2), (0, 1))[drop]
        for loop in polygon.loop_indices:
            point = mesh.vertices[mesh.loops[loop].vertex_index].co
            uvs.uv[loop].vector = (point[u] * 2.1, point[v] * 2.1)
    item = bpy.data.objects.new(name + 'Geometry', mesh)
    bpy.context.collection.objects.link(item)
    bpy.context.view_layer.update()
    item.parent = JOINTS[name]
    item.matrix_parent_inverse = JOINTS[name].matrix_world.inverted()


# ---------------------------------------------------------------- helpers

def ellipse(z, rx, ry, cy=0.0, cx=0.0, count=16, start=0.0, end=TAU, closed=True):
    """Angle 0 faces the front (+Y) and increases toward the right hand (+X)."""
    steps = count if closed else count + 1
    return [Vector((cx + math.sin(start + (end - start) * k / count) * rx,
                    cy + math.cos(start + (end - start) * k / count) * ry, z)) for k in range(steps)]


def loft(part, rings, pick, closed=True, axis=None):
    """Join consecutive rings with quads. pick(i, j, center) returns a material or None."""
    for i in range(len(rings) - 1):
        low, high = rings[i], rings[i + 1]
        span = len(low) if closed else len(low) - 1
        for j in range(span):
            corners = [low[j], low[(j + 1) % len(low)], high[(j + 1) % len(high)], high[j]]
            center = sum(corners, Vector()) / 4.0
            slot = pick(i, j, center)
            if slot is None:
                continue
            pivot = Vector((0.0, 0.0, center.z)) if axis is None else axis(center)
            part.face(corners, slot, center - pivot)


def fan(part, ring_points, apex, slot, out):
    for j in range(len(ring_points)):
        part.face([ring_points[j], ring_points[(j + 1) % len(ring_points)], apex], slot, out)


def frame(direction):
    axis = Vector(direction).normalized()
    side = axis.cross(UP if abs(axis.z) < .95 else Vector((1.0, 0.0, 0.0))).normalized()
    return axis, side, axis.cross(side).normalized()


def limb(part, a, b, profile, slot, count=10, cap_start=False, cap_end=False, twist=0.0):
    """Lofted tube from a to b. profile is a list of (t, radius) or (t, rx, ry)."""
    a, b = Vector(a), Vector(b)
    axis, side, other = frame(b - a)
    rings = []
    for entry in profile:
        t, rx = entry[0], entry[1]
        ry = entry[2] if len(entry) > 2 else rx
        center = a.lerp(b, t)
        rings.append([center + side * math.cos(twist + TAU * k / count) * rx +
                      other * math.sin(twist + TAU * k / count) * ry for k in range(count)])
    pick = slot if callable(slot) else (lambda i, j, c: slot)
    loft(part, rings, pick, True, lambda c: a + axis * (c - a).dot(axis))
    if cap_start:
        fan(part, rings[0], a.lerp(b, profile[0][0]) - axis * .004, pick(0, 0, a), -axis)
    if cap_end:
        fan(part, rings[-1], a.lerp(b, profile[-1][0]) + axis * .004, pick(0, 0, b), axis)


def blob(part, center, radii, slot, count=10, bands=5, out_scale=1.0):
    center = Vector(center)
    rings = []
    for band in range(1, bands):
        lat = -math.pi / 2 + math.pi * band / bands
        rings.append([center + Vector((math.cos(lat) * math.sin(TAU * k / count) * radii[0],
                                       math.cos(lat) * math.cos(TAU * k / count) * radii[1],
                                       math.sin(lat) * radii[2])) for k in range(count)])
    loft(part, rings, lambda i, j, c: slot, True, lambda c: center)
    fan(part, rings[0], center - Vector((0, 0, radii[2])), slot, -UP)
    fan(part, rings[-1], center + Vector((0, 0, radii[2])), slot, UP)


def box(part, center, half, slot, axes=None):
    center = Vector(center)
    ax = axes or (Vector((1, 0, 0)), Vector((0, 1, 0)), UP)
    dx, dy, dz = (Vector(ax[i]) * half[i] for i in range(3))
    for n, u, v in ((dx, dy, dz), (-dx, dy, dz), (dy, dx, dz), (-dy, dx, dz), (dz, dx, dy), (-dz, dx, dy)):
        face_center = center + n
        part.face([face_center - u - v, face_center + u - v, face_center + u + v, face_center - u + v], slot, n)


def band(part, points, width, thickness, slot, outward):
    """A leather strap or trim lying on a surface. outward(p) gives the surface normal."""
    points = [Vector(p) for p in points]
    sides, normals = [], []
    for i, p in enumerate(points):
        tangent = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        normal = Vector(outward(p)).normalized()
        sides.append(tangent.cross(normal).normalized() * width * .5)
        normals.append(normal)
    for i in range(len(points) - 1):
        a, b = points[i], points[i + 1]
        sa, sb = sides[i], sides[i + 1]
        ta, tb = normals[i] * thickness, normals[i + 1] * thickness
        part.face([a - sa + ta, a + sa + ta, b + sb + tb, b - sb + tb], slot, normals[i])
        part.face([a + sa, b + sb, b + sb + tb, a + sa + ta], slot, sa)
        part.face([a - sa, b - sb, b - sb + tb, a - sa + ta], slot, -sa)


def ring_frame(part, center, normal, up, half_w, half_h, bar, depth, slot):
    """Rectangular buckle frame lying on a surface."""
    normal = Vector(normal).normalized()
    up = (Vector(up) - normal * Vector(up).dot(normal)).normalized()
    right = up.cross(normal).normalized()
    center = Vector(center) + normal * depth * .5
    axes = (right, up, normal)
    for sign in (-1, 1):
        box(part, center + up * sign * (half_h - bar * .5), (half_w, bar * .5, depth * .5), slot, axes)
        box(part, center + right * sign * (half_w - bar * .5), (bar * .5, half_h - bar, depth * .5), slot, axes)


def interpolate(table, z):
    """Linear lookup of (z, rx, ry, cy) rows sorted by descending z."""
    if z >= table[0][0]:
        return table[0][1:]
    for upper, lower in zip(table, table[1:]):
        if lower[0] <= z <= upper[0]:
            t = (upper[0] - z) / (upper[0] - lower[0])
            return tuple(u + (l - u) * t for u, l in zip(upper[1:], lower[1:]))
    return table[-1][1:]


def on_surface(table, angle, z, lift=0.0):
    rx, ry, cy = interpolate(table, z)
    point = Vector((math.sin(angle) * rx, cy + math.cos(angle) * ry, z))
    normal = Vector((math.sin(angle) / rx, math.cos(angle) / ry, 0.0)).normalized()
    return point + normal * lift, normal


# ---------------------------------------------------------------- palette

reset()
TEAL = material('Petrol wool', '2b6f76', tile='Brushed wool')
FOLD = material('Shadow fold', '1f4f59', tile='Brushed wool')
WORN = material('Worn teal', '458a8e', tile='Brushed wool')
OCHRE = material('Ochre lining', 'd9922f', tile='Brushed wool')
EMBLEM = material('Emblem gold', 'ddb56b')
HARNESS = material('Russet harness', '6e4a30', tile='Oiled leather')
DARK_LEATHER = material('Dark leather', '4c3323', tile='Oiled leather')
GLOVE = material('Oiled leather', '5d4231', tile='Oiled leather')
CUFF = material('Boot cuff', '7b5739', tile='Oiled leather')
SOLE = material('Boot sole', '2a2421', tile='Oiled leather')
TROUSER = material('Charcoal wool', '3a3940', tile='Brushed wool')
SLEEVE = material('Charcoal sleeve', '33333c', tile='Brushed wool')
BRASS = material('Antique brass', 'c79349', .55, .42, tile='Hammered bronze')
VOID = material('Inside hood', '0a0f15', 0.0, 1.0)
STEEL = material('Sunsteel', 'c08d4d', .7, .3, tile='Hammered bronze')
EMBER = material('Ember inlay', 'ffb347', 0.0, .5, 4.0)
GRIP = material('Grip wrap', '3b291c', tile='Oiled leather')

# ---------------------------------------------------------------- skeleton

joint('Pelvis', (0, 0, .84))
joint('UpperBody', (0, 0, .94), 'Pelvis')
joint('Hood', (0, 0, 1.44), 'UpperBody')
joint('CoatHem', (0, 0, .94), 'Pelvis')
for side, tag in ((-1, 'L'), (1, 'R')):
    joint('Leg' + tag, (side * .124, 0, .84), 'Pelvis')
    joint('Knee' + tag, (side * .124, 0, .445), 'Leg' + tag)
    joint('Foot' + tag, (side * .124, 0, .09), 'Knee' + tag)
    joint('Arm' + tag, (side * .217, 0, 1.31), 'UpperBody')
    joint('Elbow' + tag, (side * .282, -.018, 1.085), 'Arm' + tag)
    joint('Hand' + tag, (side * .304, .024, .90), 'Elbow' + tag)
    joint('Mantle' + tag, (side * .13, -.01, 1.40), 'UpperBody')
    joint('Skirt' + tag, (side * .09, .10, .99), 'CoatHem')
    joint('Tail' + tag, (side * .105, -.161, .965), 'CoatHem')
GRIP_CENTER = Vector((.306, .046, .838))
joint('Weapon', GRIP_CENTER, 'HandR')
SHEATH_AXIS = Vector((-1.0, -.06, -.10)).normalized()
SHEATH_WIDTH = (UP - SHEATH_AXIS * UP.dot(SHEATH_AXIS)).normalized()
SHEATH_BASIS = Matrix((SHEATH_AXIS.cross(SHEATH_WIDTH), SHEATH_AXIS, SHEATH_WIDTH)).transposed()
SHEATH_GRIP = Vector((.205, -.236, .905))
joint('Sheath', SHEATH_GRIP, 'Pelvis', SHEATH_BASIS)

# ---------------------------------------------------------------- hood

# z, rx, ry, cy, half-width of the face opening in degrees.
HOOD = [
    (1.385, .210, .192, -.012, 0), (1.425, .172, .162, -.010, 0), (1.462, .166, .170, -.016, 30),
    (1.505, .171, .182, -.022, 50), (1.552, .178, .192, -.028, 56), (1.600, .179, .194, -.034, 54),
    (1.648, .171, .186, -.040, 45), (1.690, .157, .172, -.045, 31), (1.722, .143, .158, -.048, 15),
    (1.748, .129, .143, -.049, 0), (1.792, .097, .110, -.046, 0), (1.832, .058, .069, -.038, 0),
]
HOOD_TIP = Vector((0, -.018, 1.884))
HOOD_SEGMENTS = 26
hood = PARTS['Hood']
outer, inner = [], []
for z, rx, ry, cy, opening in HOOD:
    half = math.radians(opening)
    outer.append(ellipse(z, rx, ry, cy, 0, HOOD_SEGMENTS, half, TAU - half, False))
    inner.append(ellipse(z - .006, rx * .84, ry * .84, cy + .006, 0, HOOD_SEGMENTS, half, TAU - half, False))


def hood_cloth(i, j, center):
    if i == 0:
        return FOLD
    if j in (4, 9, 17, 22) and 2 <= i <= 8:
        return FOLD
    if center.z > 1.70 and j in (12, 13, 14):
        return WORN
    return TEAL


loft(hood, outer, hood_cloth, False, lambda c: Vector((0, -.03, c.z)))
fan(hood, outer[-1], HOOD_TIP, WORN, UP)
loft(hood, inner[1:], lambda i, j, c: VOID, False, lambda c: Vector((0, -.03, c.z)))
fan(hood, inner[-1], HOOD_TIP - Vector((0, 0, .03)), VOID, UP)
for i in range(1, len(HOOD) - 1):
    if HOOD[i][4] == 0 and HOOD[i + 1][4] == 0:
        continue
    for k in (0, -1):
        # A thick turned rim frames the void around the face.
        hood.face([outer[i][k], outer[i + 1][k], inner[i + 1][k], inner[i][k]], FOLD,
                  Vector((0, 1, 0)))

# ---------------------------------------------------------------- capelet

CAPE = [(1.425, .182, .158, -.012), (1.375, .250, .196, -.016), (1.305, .318, .228, -.020),
        (1.225, .352, .246, -.022)]
CAPE_SEGMENTS = 28


def cape_rings(scale=1.0):
    rings = [ellipse(z, rx * scale, ry * scale, cy, 0, CAPE_SEGMENTS) for z, rx, ry, cy in CAPE]
    hem = []
    for k in range(CAPE_SEGMENTS):
        angle = TAU * k / CAPE_SEGMENTS
        jag = -.046 if k % 2 else 0.0
        z = 1.118 + .018 * math.cos(angle) + jag + rng.uniform(-.010, .010)
        hem.append(Vector((math.sin(angle) * .370 * scale, -.022 + math.cos(angle) * .260 * scale, z)))
    rings.append(hem)
    return rings


def angle_of(center):
    return math.atan2(center.x, center.y) % TAU


body_cape = cape_rings()
rng.seed(70211)
flap_cape = cape_rings(1.035)


def cape_body(i, j, center):
    a = math.degrees(angle_of(center))
    if 68 < a < 115 or 245 < a < 292:
        return None
    if i == 3 and j % 4 == 1:
        return FOLD
    return WORN if i == 0 and j % 5 == 2 else TEAL


loft(PARTS['UpperBody'], body_cape, cape_body)
for tag, low, high in (('R', 55, 128), ('L', 232, 305)):
    loft(PARTS['Mantle' + tag], flap_cape,
         lambda i, j, c, low=low, high=high: (FOLD if i == 3 and j % 2 else TEAL)
         if low <= math.degrees(angle_of(c)) <= high else None)

# ---------------------------------------------------------------- torso, belt and harness

TORSO = [(1.415, .125, .105, 0), (1.35, .165, .128, 0), (1.26, .198, .146, 0), (1.16, .206, .152, .004),
         (1.07, .198, .150, 0), (.985, .192, .146, 0)]
body = PARTS['UpperBody']
loft(body, [ellipse(z, rx, ry, cy, 0, 16) for z, rx, ry, cy in reversed(TORSO)],
     lambda i, j, c: FOLD if j in (0, 15) else TEAL)
BELT_TOP, BELT_LOW = 1.064, .992
loft(body, [ellipse(BELT_LOW, .209, .164, 0, 0, 20), ellipse(BELT_TOP, .209, .164, 0, 0, 20)],
     lambda i, j, c: HARNESS)
for z, sign in ((BELT_TOP, 1), (BELT_LOW, -1)):
    loft(body, [ellipse(z, .196, .152, 0, 0, 20), ellipse(z, .209, .164, 0, 0, 20)],
         lambda i, j, c: DARK_LEATHER, True, lambda c, s=sign: c - UP * s)
ring_frame(body, (0, .166, 1.028), (0, 1, 0), UP, .036, .030, .011, .012, BRASS)
box(body, (0, .181, 1.028), (.004, .003, .022), BRASS)
box(body, (.058, .168, 1.028), (.009, .006, .037), DARK_LEATHER, (Vector((1, -.32, 0)).normalized(), Vector((.32, 1, 0)).normalized(), UP))
for center, half, yaw in (((.196, .062, .958), (.034, .026, .046), .32), ((-.168, -.118, .968), (.030, .024, .038), -2.2)):
    axes = (Vector((math.cos(yaw), -math.sin(yaw), 0)), Vector((math.sin(yaw), math.cos(yaw), 0)), UP)
    box(body, center, half, HARNESS, axes)
    box(body, Vector(center) + UP * (half[2] - .006) + axes[1] * .004, (half[0] + .004, half[1] + .006, .012), DARK_LEATHER, axes)
    blob(body, Vector(center) + axes[1] * (half[1] + .010) + UP * (half[2] - .016), (.007, .005, .007), BRASS, 6, 3)


def cape_normal(point):
    return Vector((point.x, point.y + .016, max(0.0, point.z - 1.36) * 1.8)).normalized()


def cape_strap(angles):
    return [on_surface(CAPE + [(1.12, .370, .260, -.022)], math.radians(a), z, .012)[0] for a, z in angles]


for sign in (-1, 1):
    shoulder = cape_strap([(sign * a, z) for a, z in
                           ((25, 1.25), (38, 1.33), (62, 1.395), (90, 1.424), (118, 1.395), (142, 1.33), (158, 1.262), (167, 1.20))])
    band(body, shoulder, .044, .010, HARNESS, cape_normal)
    for a, z in ((38, 1.33), (142, 1.33)):
        point, normal = on_surface(CAPE, math.radians(sign * a), z, .022)
        ring_frame(body, point, normal, UP, .022, .020, .007, .007, BRASS)
yoke = cape_strap([(-40, 1.318), (-20, 1.326), (0, 1.33), (20, 1.326), (40, 1.318)])
band(body, yoke, .036, .009, HARNESS, cape_normal)
baldric = cape_strap([(-32, 1.30), (-12, 1.255), (10, 1.205), (30, 1.158), (44, 1.128)])
for a, z in ((56, 1.085), (68, 1.05)):
    baldric.append(on_surface(TORSO, math.radians(a), z, .012)[0])
band(body, baldric, .040, .010, HARNESS, lambda p: Vector((p.x, p.y, 0)).normalized())
medallion, medallion_normal = on_surface(CAPE, math.radians(-32), 1.318, .024)
_, med_side, med_up = frame(medallion_normal)
limb(body, medallion - medallion_normal * .010, medallion + medallion_normal * .006,
     [(0, .044), (1, .042)], BRASS, 14, False, True)
limb(body, medallion + medallion_normal * .006, medallion + medallion_normal * .013,
     [(0, .026), (1, .021)], EMBLEM, 10, False, True)
for k in range(8):
    angle = TAU * k / 8
    radial = med_side * math.cos(angle) + med_up * math.sin(angle)
    box(body, medallion + medallion_normal * .008 + radial * .034, (.004, .004, .004), BRASS,
        (radial, radial.cross(medallion_normal), medallion_normal))
# The empty brass dock stays visible on the harness once the sun is deployed.
dock_top, dock_low = Vector((0, -.226, 1.445)), Vector((0, -.214, 1.318))
limb(body, dock_low, dock_top, [(0, .016), (1, .016)], BRASS, 8, True, True)
limb(body, Vector((-.085, -.214, 1.326)), Vector((.085, -.214, 1.326)), [(0, .013), (1, .013)], BRASS, 8, True, True)
for x in (-.085, .085):
    blob(body, (x, -.214, 1.326), (.019, .019, .019), BRASS, 8, 4)
for k in range(12):
    a, b = TAU * k / 12, TAU * (k + 1) / 12
    pa = dock_top + Vector((math.sin(a) * .036, 0, math.cos(a) * .036 + .030))
    pb = dock_top + Vector((math.sin(b) * .036, 0, math.cos(b) * .036 + .030))
    limb(body, pa, pb, [(0, .007), (1, .007)], BRASS, 5)

# ---------------------------------------------------------------- arms and gloves

for side, tag in ((-1, 'L'), (1, 'R')):
    shoulder = Vector((side * .219, .006, 1.31))
    elbow = Vector((side * .282, -.018, 1.085))
    wrist = Vector((side * .304, .024, .90))
    arm = PARTS['Arm' + tag]
    blob(arm, shoulder, (.086, .088, .084), SLEEVE, 10, 5)
    limb(arm, shoulder, elbow, [(0, .076), (.32, .089), (.64, .093), (1.0, .084)], SLEEVE, 11)
    fore = PARTS['Elbow' + tag]
    blob(fore, elbow, (.084, .086, .084), SLEEVE, 10, 5)
    limb(fore, elbow, wrist, [(0, .084), (.22, .081), (.38, .074)], SLEEVE, 11)
    limb(fore, elbow, wrist, [(.36, .076), (.42, .080), (.86, .073), (.92, .068)],
         lambda i, j, c: DARK_LEATHER if j in (2, 3) else HARNESS, 11)
    for t in (.48, .80):
        limb(fore, elbow, wrist, [(t - .022, .084), (t + .022, .083)], BRASS, 11)
    limb(fore, elbow, wrist, [(.90, .076), (1.0, .074), (1.03, .066)], GLOVE, 11)
    hand = PARTS['Hand' + tag]
    knuckle = wrist + Vector((side * .002, .022, -.052))
    blob(hand, knuckle, (.036, .050, .052), GLOVE, 10, 5)
    blob(hand, knuckle + Vector((side * .004, .038, -.018)), (.033, .022, .036), GLOVE, 8, 4)
    thumb_root = wrist + Vector((-side * .026, .030, -.030))
    limb(hand, thumb_root, thumb_root + Vector((-side * .006, .040, -.026)), [(0, .016), (1, .012)], GLOVE, 7, False, True)
    for k in range(3):
        box(hand, knuckle + Vector((side * .036, .006 + k * .02 - .02, -.034)), (.004, .008, .006), DARK_LEATHER)

# ---------------------------------------------------------------- trousers and boots

for side, tag in ((-1, 'L'), (1, 'R')):
    x = side * .124
    limb(PARTS['Leg' + tag], (x, 0, .87), (side * .128, .005, .468),
         [(0, .118), (.45, .132), (1.0, .118)], lambda i, j, c: FOLD if j % 6 == 3 else TROUSER, 12)
    knee = PARTS['Knee' + tag]
    blob(knee, (side * .126, .010, .445), (.118, .120, .070), TROUSER, 12, 5)
    limb(knee, (side * .126, .008, .452), (x, 0, .300), [(0, .118), (.45, .128), (1.0, .100)],
         lambda i, j, c: FOLD if j % 5 == 1 else TROUSER, 12)
    limb(knee, (x, 0, .348), (x, 0, .292), [(0, .102), (1, .100)], CUFF, 14)
    loft(knee, [ellipse(.348, .086, .086, 0, x, 14), ellipse(.348, .102, .102, 0, x, 14)],
         lambda i, j, c: DARK_LEATHER, True, lambda c: c - UP)
    limb(knee, (x, 0, .300), (x, .006, .100), [(0, .089), (.6, .084), (1, .081)], GLOVE, 14)
    limb(knee, (x, 0, .254), (x, 0, .216), [(0, .094), (1, .093)], DARK_LEATHER, 14)
    ring_frame(knee, (x + side * .052, .074, .235), (side * .55, .83, 0), UP, .019, .020, .006, .006, BRASS)
    foot = PARTS['Foot' + tag]
    # y offset, half width, top, bottom: a broad rounded toe and a squared heel.
    sections = [(-.078, .072, .122, .026), (-.040, .083, .128, .024), (.010, .090, .114, .024),
                (.066, .088, .092, .024), (.112, .078, .076, .026), (.142, .058, .060, .030), (.156, .030, .047, .034)]
    rings = []
    for y, w, top, low in sections:
        mid = (top + low) * .5
        rings.append([Vector((x + dx * w, y, z)) for dx, z in
                      ((-1, low), (-1.02, mid), (-.72, top), (0, top + .008), (.72, top), (1.02, mid), (1, low), (0, low - .004))])
    loft(foot, rings, lambda i, j, c: GLOVE, True, lambda c: Vector((x, c.y, .07)))
    fan(foot, rings[0], Vector((x, -.082, .074)), GLOVE, Vector((0, -1, 0)))
    fan(foot, rings[-1], Vector((x, .160, .042)), GLOVE, Vector((0, 1, 0)))
    soles = [[Vector((x + dx * (w + .006), y, z)) for dx, z in ((-1, 0.0), (-1, .026), (1, .026), (1, 0.0))]
             for y, w, _, _ in sections[:-1]]
    loft(foot, soles, lambda i, j, c: SOLE, True, lambda c: Vector((x, c.y, .013)))
    box(foot, (x, -.058, .016), (.077, .026, .017), SOLE)

# ---------------------------------------------------------------- coat skirt, tails and emblem

SKIRT = [(1.005, .208, .163, .000), (.905, .232, .186, -.005), (.785, .262, .210, -.012),
         (.665, .290, .232, -.019), (.565, .314, .251, -.026)]
SPLIT = math.radians(11)
SKIRT_SEGMENTS = 30


def skirt_rings(scale):
    rings = [ellipse(z, rx * scale, ry * scale, cy, 0, SKIRT_SEGMENTS, SPLIT, TAU - SPLIT, False)
             for z, rx, ry, cy in SKIRT]
    hem = []
    for k in range(SKIRT_SEGMENTS + 1):
        angle = SPLIT + (TAU - 2 * SPLIT) * k / SKIRT_SEGMENTS
        z = .486 + .020 * math.cos(angle) + (-.040 if k % 2 else 0.0) + rng.uniform(-.008, .008)
        hem.append(Vector((math.sin(angle) * .334 * scale, -.030 + math.cos(angle) * .268 * scale, z)))
    rings.append(hem)
    return rings


rng.seed(1907)
back_skirt = skirt_rings(1.0)
rng.seed(1907)
front_skirt = skirt_rings(1.022)


def skirt_cloth(i, j, center):
    return FOLD if j % 5 == 2 and i >= 2 else TEAL


loft(PARTS['CoatHem'], back_skirt, lambda i, j, c: skirt_cloth(i, j, c)
     if 70 <= math.degrees(angle_of(c)) <= 290 else None, False)
for tag, low, high in (('R', 0, 82), ('L', 278, 360)):
    loft(PARTS['Skirt' + tag], front_skirt, lambda i, j, c, low=low, high=high: skirt_cloth(i, j, c)
         if low <= math.degrees(angle_of(c)) <= high else None, False)
# Ochre facings line the split so the panels flash gold as they swing.
for tag, k in (('R', 0), ('L', -1)):
    edge = [ring[k] for ring in front_skirt]
    inward = Vector((0, -1, 0))
    band(PARTS['Skirt' + tag], edge, .030, .004, OCHRE, lambda p: Vector((-p.x, -p.y, 0)).normalized())


def coat_point(angle, z, lift):
    return on_surface(SKIRT + [(.48, .334, .268, -.030)], angle, z, lift)


def sail(part, top_angles, top_z, tips, flare, lining_gap=.007):
    """Long pointed coat tail: teal outside, ochre inside, with a frayed gold hem."""
    a0, a1 = (math.radians(a) for a in top_angles)
    columns = 5
    rows = 7
    outer = []
    for r in range(rows + 1):
        row = []
        for c in range(columns + 1):
            u = c / columns
            angle = a0 + (a1 - a0) * u
            bottom = tips[0] + (tips[1] - tips[0]) * u
            bottom += -.07 * math.sin(math.pi * u * 2) ** 2 * (1 if c % 2 else .4)
            z = top_z + (bottom - top_z) * (r / rows)
            point, normal = coat_point(angle, max(z, .49), .016)
            if z < .49:
                point.z = z
                point += normal * ((.49 - z) * .32)
            point += normal * flare * (r / rows) ** 2 * (0.6 + 0.4 * u)
            row.append((point, normal))
        outer.append(row)
    for r in range(rows):
        for c in range(columns):
            quad = [outer[r][c][0], outer[r][c + 1][0], outer[r + 1][c + 1][0], outer[r + 1][c][0]]
            normal = outer[r][c][1]
            part.face(quad, FOLD if c == 2 and r > 2 else TEAL, normal)
            part.face([p - normal * lining_gap for p in quad], OCHRE, -normal)
    hem = [outer[-1][c][0] + outer[-1][c][1] * .002 for c in range(columns + 1)]
    band(part, hem, .026, .004, OCHRE, lambda p: (p - Vector((0, -.03, p.z))).normalized())


sail(PARTS['TailL'], (196, 238), .93, (.36, .25), .11)
sail(PARTS['TailR'], (122, 160), .93, (.42, .36), .05)
sail(PARTS['SkirtR'], (52, 80), .62, (.34, .30), .05)


def emblem(part, angle, z, scale, lift=.006):
    """Half-sun sewn in pale gold, conformed to the coat surface."""
    rx, ry, _ = interpolate(SKIRT, z)
    radius = (rx + ry) * .5

    def at(u, v):
        return coat_point(angle + u * scale / radius, z + v * scale, lift)

    for k in range(12):
        p0, p1 = k / 12 * math.pi, (k + 1) / 12 * math.pi
        quad = [at(.068 * math.cos(p0), .068 * math.sin(p0)), at(.088 * math.cos(p0), .088 * math.sin(p0)),
                at(.088 * math.cos(p1), .088 * math.sin(p1)), at(.068 * math.cos(p1), .068 * math.sin(p1))]
        part.face([q[0] for q in quad], EMBLEM, quad[0][1])
        wedge = [at(0, 0), at(.046 * math.cos(p0), .046 * math.sin(p0)), at(.046 * math.cos(p1), .046 * math.sin(p1))]
        part.face([q[0] for q in wedge], EMBLEM, wedge[0][1])
    for k in range(7):
        phi = math.radians(18 + k * 24)
        d = (math.cos(phi), math.sin(phi))
        n = (-d[1], d[0])
        length = .128 if k % 2 == 0 else .114
        spoke = [at(d[0] * .098 - n[0] * .007, d[1] * .098 - n[1] * .007), at(d[0] * .098 + n[0] * .007, d[1] * .098 + n[1] * .007),
                 at(d[0] * length, d[1] * length)]
        part.face([q[0] for q in spoke], EMBLEM, spoke[0][1])
    base = [at(-.112, -.016), at(.112, -.016), at(.112, -.004), at(-.112, -.004)]
    part.face([q[0] for q in base], EMBLEM, base[0][1])


emblem(PARTS['CoatHem'], math.pi, .64, 1.0)
emblem(PARTS['SkirtR'], math.radians(40), .66, .58, .029)

# ---------------------------------------------------------------- sunsteel blade and scabbard

blade = PARTS['Weapon']
g = GRIP_CENTER
along = Vector((0, 1, 0))
blob(blade, g - along * .072, (.021, .021, .021), BRASS, 8, 4)
limb(blade, g - along * .056, g + along * .052, [(0, .016), (.5, .018), (1, .016)],
     lambda i, j, c: GRIP, 8)
for t in (-.03, .03):
    limb(blade, g + along * (t - .005), g + along * (t + .005), [(0, .019), (1, .019)], BRASS, 8)
box(blade, g + along * .062, (.012, .010, .068), BRASS)
for k in range(5):
    phi = math.radians(-60 + k * 30)
    tip = g + along * (.062 + .028 * math.cos(phi)) + UP * (.028 * math.sin(phi) * 1.4)
    limb(blade, g + along * .062, tip, [(0, .007), (1, .003)], BRASS, 5)
blob(blade, g + along * .068, (.014, .016, .020), EMBER, 8, 4)
# Leaf-shaped blade with a diamond section; width runs vertically at rest.
profile = [(.072, .024), (.20, .028), (.33, .027), (.44, .021), (.52, .011), (.56, .0)]
sections = []
for y, w in profile:
    c = g + along * y
    t = .0065 if w > 0 else 0
    sections.append([c + UP * w, c + Vector((t, 0, 0)), c - UP * w, c - Vector((t, 0, 0))])
loft(blade, sections, lambda i, j, c: STEEL, True, lambda c: Vector((g.x, c.y, g.z)))
for sign in (-1, 1):
    seam = [g + along * y + Vector((sign * .0072, 0, 0)) for y in (.09, .30, .47)]
    band(blade, seam, .007, .0012, EMBER, lambda p, s=sign: Vector((s, 0, 0)))

sheath = PARTS['Pelvis']
mouth = SHEATH_GRIP + SHEATH_AXIS * .060
tip = SHEATH_GRIP + SHEATH_AXIS * .590
thickness = SHEATH_AXIS.cross(SHEATH_WIDTH).normalized()
sheath_rings = []
for t, w in ((0.0, .034), (.82, .031), (1.0, .018)):
    center = mouth.lerp(tip, t)
    sheath_rings.append([center + SHEATH_WIDTH * math.sin(TAU * k / 10) * w +
                         thickness * math.cos(TAU * k / 10) * .016 for k in range(10)])
loft(sheath, sheath_rings, lambda i, j, c: HARNESS, True, lambda c: mouth + SHEATH_AXIS * (c - mouth).dot(SHEATH_AXIS))
fan(sheath, sheath_rings[-1], tip + SHEATH_AXIS * .012, BRASS, SHEATH_AXIS)
for t0, t1 in ((0.0, .05), (.86, .95)):
    rings = []
    for t in (t0, t1):
        center = mouth.lerp(tip, t)
        w = .036 if t < .5 else .030
        rings.append([center + SHEATH_WIDTH * math.sin(TAU * k / 10) * w +
                      thickness * math.cos(TAU * k / 10) * .019 for k in range(10)])
    loft(sheath, rings, lambda i, j, c: BRASS, True, lambda c: mouth + SHEATH_AXIS * (c - mouth).dot(SHEATH_AXIS))
for t in (.18, .55):
    hang = mouth.lerp(tip, t)
    band(sheath, [hang + SHEATH_WIDTH * .03, Vector((hang.x, hang.y + .028, .995))], .022, .006, DARK_LEATHER,
         lambda p: Vector((0, -1, 0)))

for name, part in PARTS.items():
    realize(name, part)

destination = ROOT / 'art/models/traveler.glb'
bpy.ops.export_scene.gltf(filepath=str(destination), export_format='GLB', export_yup=True)


# ---------------------------------------------------------------- folded shrine fittings

# The carry sheet shows a folded cage with fluted cheek straps and riveted
# latches. This detachable metalwork augments the starter folded shrine.
def legacy_poly(name, points, faces, slot):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points, [], faces)
    mesh.materials.append(bpy.data.materials[slot])
    mesh.update()
    item = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(item)
    return item


bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bronze = material('Worked bronze', 'a1713d', .45, .74)
sun_brass = material('Polished edges', 'd3a259', .42, .74)
dark_bronze = material('Recessed plate', '6f4c32', .37, .74)
for side in [-1, 1]:
    strips = []
    for i in range(17):
        angle = -1.26 + i * (2.52 / 16)
        width = .021 + .016 * math.cos(angle) ** 2
        # Two bowed metal bands fold close around the recessed miniature sun.
        x = side * (.063 * .36 + .143 * math.cos(angle))
        y = -.335 * math.cos(angle)
        z = .55 + .368 * math.sin(angle)
        strips.extend([(x - width, y, z), (x - width * .76, y - .012, z),
                       (x + width * .76, y - .012, z), (x + width, y, z)])
    faces = []
    for j in range(16):
        for h in range(3):
            k = 4 * j + h
            faces.append((k, k + 1, k + 5, k + 4))
    cheek = legacy_poly('Bow stay', strips, faces, bronze)
    cheek.data.materials.append(bpy.data.materials[sun_brass])
    for j, f in enumerate(cheek.data.polygons):
        f.material_index = int(j % 3 == 0)
# Stamped escutcheon over the outermost buckle.
for y, size, slot in [(-.367, .093, bronze), (-.379, .062, sun_brass), (-.386, .037, dark_bronze)]:
    legacy_poly('Buckle diamond', [(0, y, .55 + size), (size * .82, y, .55), (0, y, .55 - size), (-size * .82, y, .55)],
                [(0, 1, 2, 3)], slot)
for i in range(12):
    a = i * math.tau / 12
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, location=(.343 * math.sin(a), .343 * math.cos(a), .55))
    rivet = bpy.context.object
    rivet.scale = (.015, .015, .015)
    rivet.data.materials.append(bpy.data.materials[sun_brass])
for slot in (bronze, sun_brass, dark_bronze):
    bpy.data.materials[slot].use_backface_culling = False
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
bpy.ops.object.join()
bpy.context.object.name = 'FoldedFittings'
bpy.ops.export_scene.gltf(filepath=str(destination.with_name('folded_fittings.glb')), export_format='GLB', export_yup=True)
