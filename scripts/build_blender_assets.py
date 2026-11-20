"""Cindertrail editable low-poly starter asset builder (Blender 4.3+).

Run from the package root:
  blender --background --python scripts/build_blender_assets.py -- --output art/models --render
  blender --background --python scripts/build_blender_assets.py -- --assets bolt_turret mortar

Produces static GLB assets with embedded material colours and an editable .blend
library. These are authored starter models, not meshes extracted from concept art.
The crawler/brute are unrigged. Use them for look development before animation.
"""
from pathlib import Path
from math import sin, cos, pi
import argparse
import json
import math
import random
import sys
import bpy
from mathutils import Vector, Euler

ROOT = Path(__file__).resolve().parents[1]
COLORS = json.loads((ROOT / "art/materials/palette.json").read_text())["colors"]
COLORS["brute_armor"] = {"srgb": [.26, .225, .31]}
COLORS["crawler_armor"] = {"srgb": [.15, .225, .265]}
MATS = {}
CURRENT = []
TEXTURED = {"stone_cream", "stone_shadow", "stone_light", "wood", "bronze_dark",
            "bronze", "brass", "enemy_charcoal", "cloth_shadow", "leaves_gold",
            "leaves_orange", "foliage_light", "foliage_teal", "brute_armor", "crawler_armor"}

def linear(v):
    return v / 12.92 if v < .04045 else ((v + .055)/1.055)**2.4

def painted_surface(name, base):
    """Small repeating brush grain. Geometry and palette provide the main value changes."""
    size = 64
    image = bpy.data.images.new(name + "_painted", size, size, alpha=False)
    pixels = []
    for row in range(size):
        y = 2 * pi * row / size
        for col in range(size):
            x = 2 * pi * col / size
            stroke = sin(3 * x + 2 * y + 0.65 * sin(3 * y))
            grain = sin(16 * x - 3 * y + 1.3 * sin(x + 2 * y))
            if name == "wood":
                grain = sin(18 * x + 1.3 * sin(2 * y + 3 * x)) * 0.7
            variation = 1 + .086 * stroke + .045 * grain + .062 * sin(x - y)
            pixels.extend([min(channel * variation, 1.) for channel in base] + [1.])
    image.pixels.foreach_set(pixels)
    image.pack()
    return image

def material(name):
    if name in MATS:
        return MATS[name]
    c = tuple(linear(v) for v in COLORS[name]["srgb"])
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*c, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*c, 1)
    metal = "bronze" in name or name == "brass"
    p.inputs["Roughness"].default_value = .56 if metal else .84
    p.inputs["Metallic"].default_value = .52 if metal else 0
    if name in TEXTURED:
        layer = m.node_tree.nodes.new("ShaderNodeTexImage")
        layer.image = painted_surface(name, COLORS[name]["srgb"])
        m.node_tree.links.new(layer.outputs["Color"], p.inputs["Base Color"])
    if name in ("sun_amber", "field_cyan", "brute_violet"):
        p.inputs["Emission Color"].default_value = (*c, 1)
        p.inputs["Emission Strength"].default_value = 2 if name == "sun_amber" else .8
    MATS[name] = m
    return m

def assign(obj, name, mat):
    obj.name = name
    obj.data.materials.append(material(mat))
    for p in obj.data.polygons:
        p.use_smooth = False
    if mat in TEXTURED:
        uv = obj.data.uv_layers.active or obj.data.uv_layers.new(name="UVMap")
        for face in obj.data.polygons:
            dominant = max(range(3), key=lambda axis: abs(face.normal[axis]))
            axes = [axis for axis in range(3) if axis != dominant]
            for loop_id in face.loop_indices:
                point = obj.data.vertices[obj.data.loops[loop_id].vertex_index].co
                uv.uv[loop_id].vector = tuple(point[axis] * 2.05 for axis in axes)
    CURRENT.append(obj)
    return obj

def cube(name, pos, size, mat, bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    o = bpy.context.object
    o.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = o.modifiers.new("Facet_edges", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return assign(o, name, mat)

def cyl(name, pos, radius, depth, mat, vertices=10):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=pos)
    return assign(bpy.context.object, name, mat)

def ico(name, pos, scale, mat, subdivisions=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1, location=pos)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return assign(o, name, mat)

def beam(name, a, b, radius, mat, vertices=6):
    a, b = Vector(a), Vector(b)
    o = cyl(name, (a+b)/2, radius, (b-a).length, mat, vertices)
    o.rotation_euler = (b-a).to_track_quat("Z", "Y").to_euler()
    return o

def tapered_link(name, a, b, hip, tip, mat):
    """A carved joint with a broad heel and an angular, narrow tip."""
    a, b = Vector(a), Vector(b)
    length = (b - a).length
    profile = [(-.5, hip), (-.25, hip * 1.12), (.38, tip * 1.2), (.5, tip)]
    part = radial_shape(name, (a + b) / 2, [(r, z * length) for z, r in profile], mat, 5)
    part.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    return part

def radial_shape(name, location, rings, mat, slices=12, closed=True, offset=0.0):
    vertices = [(r * cos(i * 2 * pi / slices + offset),
                 r * sin(i * 2 * pi / slices + offset), z)
                for r, z in rings for i in range(slices)]
    faces = []
    for band in range(len(rings) - 1):
        for i in range(slices):
            nxt = (i + 1) % slices
            faces.append((band * slices + i, band * slices + nxt,
                          (band + 1) * slices + nxt, (band + 1) * slices + i))
    if closed:
        faces.append(tuple(reversed(range(slices))))
        faces.append(tuple(range(len(vertices) - slices, len(vertices))))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = location
    bpy.context.collection.objects.link(obj)
    return assign(obj, name, mat)

def fuse(parts, name):
    """Batch fixed detail while retaining the first object's animation origin."""
    root = parts[0]
    if len(parts) > 1:
        bpy.ops.object.select_all(action="DESELECT")
        for obj in parts:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = root
        for obj in parts[1:]:
            CURRENT.remove(obj)
        bpy.ops.object.join()
    root.name = name
    return root

def arc(name, center, radius, tube, mat, rotation=(0,0,0), start=0, end=2*pi, steps=30):
    # Faceted tube along an arc, originally in XY; rotated around its own center.
    verts, faces = [], []
    r = Euler(rotation).to_matrix()
    for i in range(steps+1):
        theta = start+(end-start)*i/steps
        for j in range(4):
            a = 2*pi*j/4
            v = Vector(((radius+tube*cos(a))*cos(theta), (radius+tube*cos(a))*sin(theta), tube*sin(a)))
            verts.append(tuple(r@v + Vector(center)))
    for i in range(steps):
        for j in range(4):
            faces.append((4*i+j, 4*i+(j+1)%4, 4*(i+1)+(j+1)%4, 4*(i+1)+j))
    faces += [(3,2,1,0), tuple(range(4*steps,4*steps+4))]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    return assign(o, name, mat)

def legs(z=.65, radius=.44, count=3):
    for i in range(count):
        a = i*2*pi/count
        beam("Folding_leg", (radius*.55*cos(a),radius*.55*sin(a),z), (radius*1.2*cos(a),radius*1.2*sin(a),.07), .065, "bronze", 4)
        cube("Foot", (radius*1.2*cos(a),radius*1.2*sin(a),.05),(.22,.18,.1),"bronze_dark", .015)

def shrine_leg(start, end, folded):
    width = .035 if folded else .065
    axis = Vector(end) - Vector(start)
    shoulder = Vector(start) + axis * .43
    sleeve = beam("Leg_collar", shoulder - axis * .072, shoulder + axis * .072,
                  width * 1.30, "bronze_dark", 6)
    pin = ico("Hinge_pin", shoulder, (width * 1.15, width * 1.15, width * 1.15), "brass", 1)
    name = "Folded_leg" if folded else "Folding_leg"
    strut = beam(name, start, end, width, "bronze", 4)
    fuse([strut, sleeve, pin], name)

def shrine(folded=False, restored=False):
    center = (0,0,.55 if folded else 1.08)
    radius = .34 if folded else .53
    if not folded:
        for i in range(3):
            angle = i * 2 * pi / 3
            x, y = cos(angle), sin(angle)
            shrine_leg((.253*x,.253*y,.72), (.552*x,.552*y,.07), False)
            cube("Foot", (.552*x,.552*y,.05), (.22,.18,.10), "bronze_dark", .015)
        base = len(CURRENT)
        radial_shape("Shrine_base", (0,0,.69), [(.31,-.12),(.36,-.09),(.39,-.03),(.39,.06),(.37,.077)],
                     "bronze_dark", 12)
        for i in range(3):
            angle = i * 2 * pi / 3 + pi / 2
            radial = Vector((cos(angle), sin(angle), 0))
            tangent = Vector((-sin(angle), cos(angle), 0))
            face = radial * .371 + Vector((0, 0, .683))
            plaque = cube("Sunset_cartouche", face, (.19,.047,.093), "bronze", .012)
            plaque.rotation_euler.z = angle - pi / 2
            crest = face + radial * .027
            for j in range(5):
                ray = j * pi / 4
                direction = tangent * cos(ray) + Vector((0, 0, sin(ray)))
                beam("Sun_rune", crest + direction * .016, crest + direction * .033, .0035, "brass", 4)
            ico("Sun_rune_centre", crest, (.010,.010,.010), "brass", 1)
        fuse(CURRENT[base:], "Shrine_base")
        radial_shape("Shrine_trim", (0,0,.78), [(.395,-.035),(.434,-.016),(.431,.013),(.404,.035)],
                     "brass", 12)
    else:
        radial_shape("Lantern_base", (0,0,.15), [(.204,-.07),(.25,-.037),(.27,.031),(.233,.065)],
                     "bronze_dark", 12)
        for i in range(3):
            a=i*2*pi/3
            shrine_leg((.29*cos(a),.29*sin(a),.18),(.29*cos(a),.29*sin(a),.75), True)
        handle = len(CURRENT)
        arc("Carry_handle",(0,0,.93),.13,.025,"bronze",(pi/2,0,0),0,pi,12)
        for x in [-.13, .13]:
            ico("Handle_eye", (x,0,.93), (.039,.035,.038), "brass", 1)
        fuse(CURRENT[handle:], "Carry_handle")
    ico("Sun",center,(.23,.23,.23),"sun_amber",2)
    for i, rot in enumerate([(pi/2,0,0),(.2,pi/2,.25),(1.0,.5,1.1)]):
        arc("Orbit_ring_"+str(i),center,radius*(1+i*.055),.035,"brass",rot,
            0 if restored or folded else -.6, 2*pi if restored or folded else 4.3, 28)

def bolt():
    frame = len(CURRENT)
    legs(.42, .37)
    radial_shape("Turret_base", (0,0,0), [(.25,.28),(.32,.35),(.30,.42),(.21,.49)], "bronze_dark", 10)
    for i in range(3):
        angle = i * 2 * pi / 3
        x, y = cos(angle), sin(angle)
        tapered_link("Buttress", (.19*x,.19*y,.40), (.43*x,.43*y,.07), .084, .105, "bronze_dark")
        cap = cube("Heel_plate", (.44*x,.44*y,.09), (.17,.19,.13), "brass", .024)
        cap.rotation_euler[2] = angle
        cyl("Heel_rivet", (.45*x,.45*y,.165), .03, .028, "bronze", 7)
    gear = cyl("Ratchet_hub", (0,-.246,.35), .101, .062, "brass", 10)
    gear.rotation_euler.x = pi / 2
    for i in range(9):
        angle = i * 2 * pi / 9
        tooth = cube("Ratchet_tooth", (.113*cos(angle),-.253,.35+.113*sin(angle)),
                     (.052,.057,.038), "bronze", .006)
        tooth.rotation_euler.y = -angle
    fuse(CURRENT[frame:], "Turret_frame")
    rotor = len(CURRENT)
    cyl("Turret_rotor", (0,0,.54), .22, .135, "bronze", 12)
    cyl("Bearing_collar", (0,0,.478), .237, .048, "brass", 12)
    fuse(CURRENT[rotor:], "Turret_rotor")
    radial_shape("Amber_crystal", (0,0,.78), [(.065,-.11),(.138,.02),(.106,.165),(.013,.275)], "sun_amber", 6)
    fork = len(CURRENT)
    cyl("Crystal_socket", (0,0,.675), .232, .10, "bronze_dark", 10)
    for side in (-1, 1):
        elbow = (side*.26,-.095,.741)
        tapered_link("Spring_arm", (side*.14,.08,.69), elbow, .077, .095, "bronze")
        tapered_link("Arrowhead", elbow, (side*.39,-.48,.83), .105, .012, "brass")
        beam("Copper_conductor", (side*.115,-.058,.727), (side*.14,-.39,.764), .025, "brass", 5)
    tapered_link("Rear_balance", (0,.105,.69), (0,.35,.94), .094, .032, "bronze")
    fuse(CURRENT[fork:], "Bolt_prong_frame")

def slowing():
    frame = len(CURRENT)
    radial_shape("Stone_base", (0,0,0),
                 [(.37,.01),(.40,.07),(.36,.14),(.27,.30)], "stone_cream", 12, offset=pi/12)
    cyl("Bronze_trim", (0,0,.30), .264, .066, "bronze", 12)
    cyl("Luminous_stalk", (0,0,.412), .144, .19, "field_cyan", 8)
    arc("Cap_rim", (0,0,.54), .451, .027, "bronze_dark", steps=24)
    for i in range(4):
        angle = i * pi / 2 + pi / 4
        x, y = cos(angle), sin(angle)
        tapered_link("Brace", (.22*x,.22*y,.32), (.413*x,.413*y,.045), .067, .075, "bronze_dark")
        tapered_link("Cap_rib", (.188*x,.188*y,.767), (.44*x,.44*y,.556), .032, .033, "brass")
    arc("Sigil", (0,-.324,.122), .105, .012, "bronze", (pi/2,0,0), 0, pi, 12)
    cyl("Upper_cap", (0,0,.769), .199, .060, "bronze", 12)
    cyl("Upper_inlay", (0,0,.804), .143, .014, "brass", 12)
    fuse(CURRENT[frame:], "Emitter_frame")
    radial_shape("Cyan_cap", (0,0,0),
                 [(.306,.50),(.451,.545),(.427,.606),(.326,.703),(.174,.765)],
                 "field_cyan", 16)
    radial_shape("Canopy_glass", (0,0,0), [(.427,.608),(.329,.707),(.18,.769)],
                 "cloth_teal", 16, closed=False)

def mortar():
    base = len(CURRENT)
    legs(.38,.33)
    radial_shape("Mortar_base", (0,0,0), [(.31,.04),(.367,.1),(.307,.25),(.25,.35)], "stone_cream")
    cyl("Seat", (0,0,.35), .267, .105, "bronze_dark", 12)
    for side in (-1, 1):
        tapered_link("Trunnion_buttress", (side*.379,.035,.091), (side*.334,.015,.635),
                     .09, .108, "bronze_dark")
        beam("Bearing", (side*.289,.015,.644),(side*.418,.015,.644), .139, "bronze", 12)
        beam("Axle_hub", (side*.397,.015,.644),(side*.429,.015,.644), .091, "brass", 10)
    fuse(CURRENT[base:], "Mortar_frame")
    cyl("Amber_chamber", (0,0,.453), .183, .169, "sun_amber", 10)
    bowl = len(CURRENT)
    radial_shape("Mortar_bowl", (0,0,0),
                 [(.205,.515),(.296,.56),(.384,.783),(.392,.939),(.304,.945),(.234,.786),(.145,.599)],
                 "stone_cream", 14, closed=False)
    radial_shape("Breech_liner", (0,0,0), [(.306,.926),(.241,.778),(.148,.60)], "bronze_dark", 14, closed=False)
    arc("Hoop", (0,0,.614), .321, .024, "bronze", steps=24)
    arc("Rim_INLAY", (0,0,.901), .366, .021, "brass", steps=26)
    arc("Sun_emblem", (0,-.358,.751), .084, .014, "brass", (pi/2,0,0), 0, pi, 12)
    for i in range(7):
        angle = 2 * pi * i / 7
        # Veins follow the bowl's inclination and break up the broad cream facets.
        x, y = cos(angle), sin(angle)
        beam("Stone_seam", (.387*x,.387*y,.897),(.378*x,.378*y,.789),.008,"stone_shadow",4)
    fuse(CURRENT[bowl:], "Mortar_bowl")
    cyl("Bowl_glow", (0,0,.626), .148, .031, "sun_amber", 12)

def block():
    cube("Stone_block",(0,0,.25),(1,.55,.5),"stone_cream",.045)

def pillar():
    cube("Plinth",(0,0,.12),(.68,.68,.24),"stone_shadow")
    cube("Lower_molding",(0,0,.239),(.57,.57,.08),"stone_light",.023)
    for i in range(4):
        o=cube("Pillar_section",(0,0,.49+i*.51),(.46,.46,.49),"stone_cream",.025)
        o.rotation_euler[2]=(-.015 if i%2 else .015)
        if i < 3:
            cube("Settled_joint", (.017,-.006,.745+i*.51), (.445,.445,.026), "stone_shadow", .014)
    cube("Capital",(0,0,2.42),(.66,.66,.22),"stone_light")
    cube("Capital_molding",(0,0,2.266),(.55,.55,.12),"stone_cream",.034)
    cube("Bronze_inlay",(0,-.24,1.21),(.052,.032,.78),"bronze",.009)
    for z in (.81,1.59):
        stud = cube("Inlay_stud",(0,-.256,z),(.098,.029,.084),"brass",.009)
        stud.rotation_euler.y = pi/4

def stairs():
    for i in range(6):
        cube("Step",(0,i*.38,(i+1)*.13),(1.8,.40,(i+1)*.26),"stone_cream",.025)

def arch():
    r, h = 1.0,1.3
    for side in (-1,1):
        for i in range(3):
            stone = cube("Pier_stone",(side*(1.18+i*.006),0,(i+.5)*h/3),
                         (.38-(i%2)*.024,.48,h/3-.019),"stone_cream", .032)
            stone.rotation_euler.z = side * (i-1) * .026
        cube("Pier_foot",(side*1.195,0,.125),(.473,.548,.235),"stone_shadow",.038)
        cube("Spring_molding",(side*1.18,0,1.295),(.422,.509,.081),"stone_light",.023)
    for i in range(11):
        a=i*pi/11+.018; b=(i+1)*pi/11-.018
        verts=[]
        for y in (-.244 - .009 * (i % 3), .236):
            rim = .405 if i == 5 else .355 + .026 * sin(2.1*i)
            for rad,t in [(r,a),(r,b),(r+rim,b),(r+rim,a)]:
                verts.append((rad*cos(t),y,h+rad*sin(t)))
        mesh=bpy.data.meshes.new("Arch_stone")
        mesh.from_pydata(verts,[],[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)])
        mesh.update();o=bpy.data.objects.new("Arch_stone",mesh);bpy.context.collection.objects.link(o)
        assign(o,"Arch_stone","stone_light" if i==5 else "stone_cream")
    arch_front = (0,-.264,1.3)
    for left,right in ((0.17,0.83),(1.03,1.48),(1.71,2.03),(2.36,2.96)):
        arc("Carved_rim", arch_front, 1.087, .018, "stone_light", (pi/2,0,0), left,right,8)

def tree(orange=False):
    start = len(CURRENT)
    fork = Vector((-.083,.035,1.48))
    tapered_link("Trunk",(0,0,-.04),fork,.195,.092,"wood")
    for i in range(4):
        a = i * pi / 2 + .47
        tapered_link("Root",(0,0,.23),(.48*cos(a),.42*sin(a),.028),.086,.012,"wood")
    rng = random.Random(91 if orange else 44)
    for i, center in enumerate([(-.61,.15,2.39),(.62,.33,2.18),(.13,-.55,2.54),(-.13,.36,2.86)]):
        crown = Vector(center)
        branch = fork.lerp(crown, .62) + Vector((0,0,-.1))
        tapered_link("Bough",fork,branch,.086,.041,"wood")
        for n in range(4):
            a = rng.uniform(0, 2 * pi)
            p = crown + Vector((rng.uniform(.28,.55)*cos(a),rng.uniform(.23,.48)*sin(a),rng.uniform(-.15,.15)))
            tapered_link("Twig",branch,p,.032,.009,"wood")
            mat = ("leaves_orange" if (i+n)%3 else "leaves_gold") if orange else ("foliage_teal" if (i+n)%3 else "foliage_light")
            ico("Leaf_cluster",p,(rng.uniform(.40,.70),rng.uniform(.35,.59),rng.uniform(.19,.35)),mat,2)
    fuse(CURRENT[start:], "Branching_tree")

def crate():
    base = len(CURRENT)
    cube("Crate_shadow",(0,0,.322),(.754,.558,.64),"bronze_dark",.040)
    for i in range(4):
        x = (i - 1.5) * .193
        for y in (-.279,.279):
            cube("Box_stave",(x,y,.322),(.18,.044,.628),"wood",.013)
        cube("Lid_board",(x,0,.672),(.181,.60,.079),"wood",.015)
    for x in (-.357,.357):
        for z in (.23,.444):
            cube("End_board",(x,0,z),(.082,.574,.205),"wood",.014)
    for x in (-.34,.34):
        for y in (-.309,.309):
            cube("Crate_strap",(x,y,.325),(.073,.037,.64),"bronze_dark",.01)
            for z in (.108,.571):
                beam("Strap_rivet",(x,y,z),(x,y+math.copysign(.029,y),z),.026,"brass",8)
        for z in (.042,.703):
            cube("Banded_edge",(x,0,z),(.079,.663,.048),"bronze",.013)
    cube("Clasp",(0,-.327,.555),(.142,.059,.177),"brass",.021)
    beam("Latch_window",(0,-.352,.555),(0,-.364,.555),.044,"bronze_dark",8)
    arc("Sun_stamp",(0,-.312,.236),.101,.010,"bronze",(pi/2,0,0),0,pi,9)
    fuse(CURRENT[base:], "Supply_chest")

def crawler():
    body = len(CURRENT)
    ico("Crawler_core",(0,0,.392),(.335,.452,.240),"cloth_shadow",2)
    nose = ico("Head",(0,-.418,.308),(.236,.193,.158),"enemy_charcoal",2)
    nose.rotation_euler.x = .3
    for x,y,z,sx,sy,sz,a in [
            (0,.231,.517,.267,.205,.129,.13),
            (-.159,-.031,.519,.190,.242,.147,-.22),
            (.152,-.108,.535,.197,.232,.134,.35),
            (0,-.355,.426,.181,.141,.130,0.0),
            (-.239,.196,.458,.144,.169,.112,-.52),
            (.237,.161,.468,.131,.188,.115,.57)]:
        plate = ico("Overlapping_shell_plate",(x,y,z),(sx,sy,sz),"crawler_armor",2)
        plate.rotation_euler.z = a
    fuse(CURRENT[body:], "Carapace")
    marks = len(CURRENT)
    for points in [
            [(-.27,.167,.543),(-.108,.152,.638),(-.035,.01,.647),(.158,.084,.591)],
            [(-.035,.01,.647),(-.002,-.186,.615),(-.122,-.322,.524),(-.190,-.467,.355)],
            [(.158,.084,.591),(.278,.170,.498),(.334,.128,.455)],
            [(.095,-.505,.356),(.170,-.517,.319)],
            [(-.084,-.516,.347),(-.154,-.537,.307)]]:
        for first,last in zip(points, points[1:]):
            tapered_link("Line",first,last,.013,.011,"field_cyan")
    fuse(CURRENT[marks:], "Cyan_fissure")
    for side in (-1,1):
        for i in range(3):
            y = (i-1)*.282
            knee = (side * (.546 if i == 1 else .493),y*.99-.07,.375)
            toe = (side * (.758 if i == 1 else .713), y*1.39-.145,.018)
            tapered_link("Leg_upper",(side*.22,y,.414),knee,.074,.065,"enemy_charcoal")
            tapered_link("Leg_lower",knee,toe,.081,.008,"enemy_charcoal")

def brute():
    body = len(CURRENT)
    ico("Torso",(0,.056,1.19),(.578,.391,.668),"enemy_charcoal",2)
    for side in (-1,1):
        plate = ico("Raised_back_shard",(side*.29,.237,1.575),(.389,.364,.296),"brute_armor",1)
        plate.rotation_euler.y = side * -.39
        chest = ico("Chest_plate",(side*.265,-.27,1.325),(.385,.275,.410),"brute_armor",1)
        chest.rotation_euler.y = side * -.28
    brow = ico("Brow",(0,-.314,1.66),(.257,.293,.222),"enemy_charcoal",2)
    brow.rotation_euler.x = -.18
    ico("Jaw",(0,-.408,1.506),(.202,.170,.176),"enemy_charcoal",1)
    fuse(CURRENT[body:], "Brute_shell")
    marks = len(CURRENT)
    for side in (-1, 1):
        for points in [
                [(side*.041,-.612,1.552),(side*.121,-.599,1.527),(side*.158,-.560,1.531)],
                [(side*.083,-.475,1.18),(side*.208,-.505,1.133),(side*.278,-.510,1.178),(side*.344,-.471,1.230)],
                [(side*.06,-.338,1.06),(side*.244,-.332,1.007),(side*.374,-.259,1.022)],
                [(side*.109,.062,1.812),(side*.154,.234,1.848),(side*.136,.403,1.757)]]:
            for first, last in zip(points,points[1:]):
                tapered_link("Line",first,last,.018,.012,"brute_violet")
    fuse(CURRENT[marks:], "Violet_fissure")
    for side in (-1,1):
        shin = len(CURRENT)
        tapered_link("Shin",(side*.288,.079,.67),(side*.371,.055,.128),.184,.153,"enemy_charcoal")
        ico("Knee_cover",(side*.355,-.058,.520),(.243,.172,.218),"brute_armor",1)
        fuse(CURRENT[shin:], "Shin")
        foot = ico("Foot",(side*.372,-.13,.128),(.248,.323,.153),"enemy_charcoal",2)
        for v in foot.data.vertices:
            v.co.z = max(v.co.z, -.125)
        arm = len(CURRENT)
        tapered_link("Arm",(side*.558,.025,1.461),(side*.833,-.201,.491),.234,.204,"enemy_charcoal")
        shoulder = ico("Shoulder_plate",(side*.598,.023,1.520),(.449,.434,.382),"brute_armor",1)
        shoulder.rotation_euler.y = side * -.23
        ico("Elbow_plate",(side*.799,-.158,.883),(.292,.285,.288),"brute_armor",1)
        fuse(CURRENT[arm:], "Arm")
        fist = len(CURRENT)
        ico("Fist",(side*.848,-.228,.456),(.298,.267,.283),"enemy_charcoal",2)
        for z in (.378,.488):
            ico("Knuckle",(side*.848,-.393,z),(.204,.14,.092),"enemy_charcoal",1)
        fuse(CURRENT[fist:], "Fist")

BUILDERS = {
    "stone_block":block,"ruin_pillar":pillar,"ruin_arch":arch,"stone_stairs":stairs,
    "teal_tree":lambda:tree(False),"orange_tree":lambda:tree(True),"supply_crate":crate,
    "sun_shrine_deployed":lambda:shrine(False,False),"sun_shrine_restored":lambda:shrine(False,True),
    "sun_shrine_folded":lambda:shrine(True,False),"bolt_turret":bolt,"slowing_emitter":slowing,
    "mortar":mortar,"crawler_static":crawler,"brute_static":brute,
}

def text_obj(text, pos):
    curve=bpy.data.curves.new(text,"FONT");curve.body=text.replace("_"," ");curve.size=.18;curve.align_x="CENTER"
    obj=bpy.data.objects.new("Label_"+text,curve);bpy.context.collection.objects.link(obj)
    obj.location=pos;obj.rotation_euler=(math.radians(60),0,0);obj.data.materials.append(material("stone_light"))

def look_at(obj, point):
    obj.rotation_euler=(Vector(point)-obj.location).to_track_quat("-Z","Y").to_euler()

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--output", default=str(ROOT/"art/models"))
    parser.add_argument("--render",action="store_true")
    parser.add_argument("--assets", nargs="+", choices=BUILDERS,
                        help="Export selected assets and preserve the full editable library.")
    argv=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    args=parser.parse_args(argv)
    if args.assets and args.render:
        parser.error("--render requires the complete asset library.")
    out=Path(args.output).resolve();out.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action="SELECT");bpy.ops.object.delete(use_global=False)
    manifest_path = out / "models_manifest.json"
    manifest = {}
    if args.assets and manifest_path.exists():
        for entry in json.loads(manifest_path.read_text())["assets"]:
            manifest[entry["file"]] = entry
    selected = args.assets or BUILDERS
    for index,name in enumerate(selected):
        CURRENT.clear()
        BUILDERS[name]()
        root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root)
        for o in CURRENT:
            o.parent=root
        bpy.ops.object.select_all(action="DESELECT")
        root.select_set(True)
        for o in CURRENT:o.select_set(True)
        bpy.context.view_layer.objects.active=root
        bpy.ops.export_scene.gltf(filepath=str(out/(name+".glb")),export_format="GLB",use_selection=True,
                                  export_apply=True,export_yup=True,export_animations=False)
        filename = name + ".glb"
        manifest[filename] = {"file":filename,"static":True,"rigged":False,
                              "vertices":sum(len(o.data.vertices) for o in CURRENT if o.type=="MESH")}
        col,row=index%5,index//5
        root.location=((col-2)*3.5,(row-1)*4,0)
        if not args.assets:
            text_obj(name,(root.location.x,root.location.y-1.15,.05))
    manifest_path.write_text(json.dumps({"generator":"build_blender_assets.py","units":"meters",
                                         "up_axis_in_glb":"Y","assets":list(manifest.values())},indent=2)+"\n")
    print("CINDERTRAIL_ASSETS_COMPLETE " + str(len(selected)))
    if args.assets:
        return
    # Real 3D preview of the delivered starter assets, not an AI image.
    CURRENT.clear();cube("Preview_floor",(0,0,-.20),(19,14,.25),"cloth_shadow",.05)
    for loc,energy,color,size in [((-5,-7,10),1800,(1.0,.78,.48),8),((7,4,9),2300,(.45,.75,1.0),7)]:
        bpy.ops.object.light_add(type="AREA",location=loc)
        l=bpy.context.object;l.data.energy=energy;l.data.color=color;l.data.shape="DISK";l.data.size=size;look_at(l,(0,0,0))
    bpy.ops.object.camera_add(location=(11,-17,15))
    camera=bpy.context.object;look_at(camera,(0,0,.6));camera.data.type="ORTHO";camera.data.ortho_scale=22
    scene=bpy.context.scene;scene.camera=camera
    scene.world.color=(.12,.16,.22)
    scene.render.engine="CYCLES";scene.cycles.samples=40;scene.cycles.use_denoising=False
    scene.render.resolution_x=1600;scene.render.resolution_y=1050;scene.render.resolution_percentage=100
    scene.view_settings.view_transform="AgX"
    source=ROOT/"art/source"
    source.mkdir(parents=True,exist_ok=True)
    (source/".gdignore").touch()
    bpy.ops.wm.save_as_mainfile(filepath=str(source/"cindertrail_starter_library.blend"))
    if args.render:
        scene.render.filepath=str(ROOT/"art/materials/starter_asset_preview.png")
        bpy.ops.render.render(write_still=True)
if __name__=="__main__":main()
