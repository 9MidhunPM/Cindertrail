"""Produce the homepage shrine from the project's authored Godot model."""
from math import cos, pi, sin
from pathlib import Path
from subprocess import run
from tempfile import TemporaryDirectory

import bpy
from mathutils import Euler, Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = HERE.parent / "public" / "shrine"
OUT.mkdir(parents=True, exist_ok=True)
MODEL = HERE.parent / "src" / "assets" / "shrine.glb"
MODEL.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / "art/models/sun_shrine_deployed.glb"))
parts = {obj.name: obj for obj in bpy.context.selected_objects}
sun = parts["Sun"]
base = parts["Shrine_base"]
trim = parts["Shrine_trim"]
legs = sorted((obj for name, obj in parts.items() if name.startswith("Folding_leg")), key=lambda obj: obj.name)
feet = sorted((obj for name, obj in parts.items() if name.startswith("Foot")), key=lambda obj: obj.name)
for i in range(3):
    bpy.data.objects.remove(parts[f"Orbit_ring_{i}"], do_unlink=True)
for obj in [sun, base, trim, *legs, *feet]:
    world = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = world

def material(name, color, metallic, roughness, emission=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Emission Color"].default_value = (*color, 1)
    shader.inputs["Emission Strength"].default_value = emission
    return mat

gold = material("Hand-worked brass", (.46, .23, .065), .58, .39)
bronze = material("Weathered bronze", (.19, .077, .026), .54, .51)
dark = material("Patinated bronze", (.052, .031, .022), .45, .54)
copper = material("Copper filigree", (.32, .105, .036), .58, .45)
patina = material("Verdigris inlay", (.033, .11, .094), .38, .48)
ember = material("Amber channel", (.96, .24, .023), .2, .42, .85)
solar = material("Miniature sun", (1, .36, .029), .06, .52, 2.1)
stone = material("Grove limestone", (.18, .20, .17), .02, .91)

def recolor(obj, palette):
    for i, src in enumerate(obj.data.materials):
        obj.data.materials[i] = next((mat for key, mat in palette if key in src.name.lower()), bronze)

for obj in [base, trim, *legs, *feet]:
    recolor(obj, [("brass", gold), ("dark", dark)])
sun.data.materials.clear()
sun.data.materials.append(solar)

def pivot(name, location, children):
    joint = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(joint)
    joint.location = location
    bpy.context.view_layer.update()
    for child in children:
        world = child.matrix_world.copy()
        child.parent = joint
        child.matrix_world = world
    return joint

def cylinder(name, vertices, radius, depth, location, mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj

def mesh_object(name, vertices, faces, material_slots):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], [face for face, _ in faces])
    mesh.update()
    for mat in material_slots:
        mesh.materials.append(mat)
    for polygon, (_, index) in zip(mesh.polygons, faces):
        polygon.material_index = index
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def ring_rail(name, radius, start, sweep, basis, segments, section, materials, facets):
    width = len(section)
    vertices = []
    faces = []
    for i in range(segments):
        theta = start + sweep*i/segments
        for radial, depth in section:
            r = radius + radial
            vertices.append(basis @ Vector((r*cos(theta), r*sin(theta), depth)))
        following = (i+1)%segments
        for j, material_index in enumerate(facets):
            k = (j+1)%width
            faces.append(((i*width+j, following*width+j, following*width+k, i*width+k),
                          material_index))
    return mesh_object(name, vertices, faces, materials)


def plate_template():
    # Five cross-sections form each curved, raised armor petal.
    vertices = []
    profiles = [(0, .00, .088), (.055, .10, .126), (.077, .24, .124),
                (.056, .36, .092), (-.025, .468, .055), (-.104, .531, .028)]
    for radial, height, width in profiles:
        vertices.extend([(radial-.020,-width,height), (radial,-width,height),
                         (radial+.020,-width*.65,height), (radial+.030,0,height),
                         (radial+.020,width*.65,height), (radial,width,height),
                         (radial-.020,width,height)])
    faces = [(tuple(reversed(range(7))), 0)]
    for level in range(len(profiles)-1):
        for j, mat in enumerate((1, 2, 0, 0, 2, 1, 0)):
            a = level*7+j
            b = level*7+(j+1)%7
            faces.append(((a, b, b+7, a+7), mat))
    faces.append((tuple(range(len(vertices)-7, len(vertices))), 1))
    body = mesh_object("Armor casting", vertices, faces, [dark, gold, bronze])

    crest = mesh_object("Inset sun crest", [
        (.096,-.005,.133), (.108,-.061,.239), (.111,-.014,.318),
        (.109,0,.352), (.111,.014,.318), (.108,.061,.239),
        (.099,0,.257), (.094,0,.171),
    ], [((0,1,6,7),1), ((1,2,3,6),0), ((3,4,5,6),0), ((5,0,7,6),1)], [patina, copper])
    spine = mesh_object("Inlaid amber seam", [
        (.103,-.008,.172), (.108,-.008,.258), (.110,.008,.258), (.103,.008,.172),
        (.107,-.009,.272), (.105,0,.323), (.107,.009,.272),
    ], [((0,1,2,3),0), ((4,5,6),0)], [ember])
    return [body, crest, spine]


def ratchet(name, location, axis):
    segments = 40
    vertices = []
    for z in (-.018,.018):
        for j in range(segments):
            theta = j*2*pi/segments
            radius = .098 if j%4 in (1,2) else .081
            vertices.append((radius*cos(theta),radius*sin(theta),z))
    faces = [(tuple(reversed(range(segments))), 0),
             (tuple(range(segments, segments*2)), 0)]
    for j in range(segments):
        k = (j+1)%segments
        faces.append(((j,k,k+segments,j+segments), 1 if j%4 == 1 else 0))
    obj = mesh_object(name, vertices, faces, [bronze, gold])
    obj.location = location
    obj.rotation_euler = axis.to_track_quat('Z', 'Y').to_euler()
    return obj


rivet_band = []
for i in range(12):
    angle = (i + .5) * 2*pi/12
    radial = Vector((cos(angle), sin(angle), 0))
    rivet = cylinder("Cage band rivet", 8, .017, .027,
                     radial * .378 + Vector((0, 0, .70)), gold)
    rivet.rotation_euler = radial.to_track_quat('Z', 'Y').to_euler()
    rivet_band.append(rivet)
carrier = pivot("Core carriage", (0, 0, .72), [sun, base, trim, *rivet_band])
solar_center = Vector((0, 0, 1.08))
petals = []
castings = plate_template()
for i in range(6):
    angle = (i+.5)*2*pi/6
    radial = Vector((cos(angle),sin(angle),0))
    joint = pivot(f"Armor latch {i+1}", (0,0,0), [])
    joint.parent = carrier
    joint.location = radial*.369 + Vector((0,0,.078))
    joint.rotation_euler.z = angle
    hinge = pivot(f"Armor petal {i+1}", (0,0,0), [])
    hinge.parent = joint
    for template in castings:
        copy = template.copy()
        bpy.context.collection.objects.link(copy)
        copy.parent = hinge
    socket = cylinder("Petal pivot barrel", 10, .035, .196, (0,0,0), bronze)
    socket.parent = joint
    socket.rotation_euler.x = pi/2
    petals.append(hinge)
for template in castings:
    bpy.data.objects.remove(template, do_unlink=True)

gimbals = []
for i, rotations in enumerate([(pi/2,0,0),(.2,pi/2,.25),(1.0,.5,1.1)]):
    basis = Euler(rotations, 'XYZ').to_matrix()
    radius = .535 + i*.058
    start = -.54 + i*.42
    sweep = 2*pi
    gimbal = pivot(f"Orbital ring {i+1}", (0,0,0), [])
    gimbal.parent = carrier
    gimbal.location = solar_center - carrier.location
    rail = ring_rail("Forged orbital rail", radius, start, sweep, basis, 64,
                     [(-.026,-.015),(-.018,-.026),(.015,-.026),(.026,-.015),
                      (.026,.015),(.015,.026),(-.018,.026),(-.026,.015)],
                     [bronze,gold,dark], [0,1,0,2,0,1,0,2])
    rail.parent = gimbal
    channel = ring_rail("Amber passage", radius+.027, start, sweep, basis, 64,
                        [(0,-.006),(.003,-.006),(.003,.006),(0,.006)], [ember], [0]*4)
    channel.parent = gimbal
    runner = ring_rail("Floating copper runner", radius-.057, start, sweep, basis, 64,
                       [(-.009,-.006),(.009,-.006),(.009,.006),(-.009,.006)],
                       [patina,copper], [0,1,0,1])
    runner.parent = gimbal
    marks = []
    mark_faces = []
    for side in (-1, 1):
        for j in range(1, 25):
            theta = start + sweep*j/25
            radial = Vector((cos(theta), sin(theta), 0))
            tangent = Vector((-sin(theta), cos(theta), 0))
            width = .008 if j%4 == 0 else .004
            length = .026 if j%4 == 0 else .013
            mark = len(marks)
            position = radial*radius + Vector((0, 0, side*.0264))
            marks.extend(basis @ (position + radial*along + tangent*across)
                         for along, across in ((0,-width),(length,-width),(length,width),(0,width)))
            mark_faces.append(((mark,mark+1,mark+2,mark+3), int(j%4 == 0)))
    etching = mesh_object("Radial calibration etching", marks, mark_faces, [dark,patina])
    etching.parent = gimbal
    gimbals.append(gimbal)

hinges = []
for i, (leg, foot) in enumerate(zip(legs, feet)):
    angle = i * 2 * pi / 3
    axis = Vector((-sin(angle), cos(angle), 0))
    anchor = Vector((.253 * cos(angle), .253 * sin(angle), .72))
    pin = cylinder(f"Riveted hinge {i+1}", 12, .065, .15, anchor, gold)
    pin.rotation_euler = axis.to_track_quat('Z', 'Y').to_euler()
    strut = Vector((.299 * cos(angle), .299 * sin(angle), -.65))
    outward = Vector((cos(angle), sin(angle), 0))
    fittings = []
    for sign in (-1, 1):
        stud = cylinder("Hinge pin cap", 8, .033, .027, anchor + axis * sign * .078, bronze)
        stud.rotation_euler = axis.to_track_quat('Z', 'Y').to_euler()
        fittings.append(stud)
    inlay = cylinder("Brass strut inlay", 6, .014, .28,
                     anchor + strut * .60 + outward * .058, gold)
    inlay.rotation_euler = strut.to_track_quat('Z', 'Y').to_euler()
    fittings.append(inlay)
    for along in (.38, .78):
        rivet = cylinder("Strut rivet", 8, .021, .021,
                         anchor + strut * along + outward * .067, gold)
        rivet.rotation_euler = outward.to_track_quat('Z', 'Y').to_euler()
        fittings.append(rivet)
    gear_location = anchor + axis*.087
    crown = ratchet(f"Drive crown {i+1}", gear_location, axis)
    gear = pivot(f"Ratchet drive {i+1}", gear_location, [crown])
    gear.rotation_mode = 'AXIS_ANGLE'
    foot_anchor = Vector((.552*cos(angle),.552*sin(angle),.09))
    ankle = pivot(f"Foot rocker {i+1}", foot_anchor, [foot])
    ankle.rotation_mode = 'AXIS_ANGLE'
    hinge = pivot(f"Leg hinge {i+1}", anchor, [leg, ankle, gear, pin, *fittings])
    hinge.parent = carrier
    hinge.location = anchor - carrier.location
    hinge.rotation_mode = 'AXIS_ANGLE'
    hinges.append((hinge, ankle, gear, axis))

handle = []
for i in range(12):
    a = pi * i / 12
    b = pi * (i+1) / 12
    start = Vector((.16*cos(a), 0, 1.50 + .16*sin(a)))
    end = Vector((.16*cos(b), 0, 1.50 + .16*sin(b)))
    bar = cylinder("Cast carry handle", 8, .024, (end-start).length + .019, (start+end)/2, gold)
    bar.rotation_euler = (end-start).to_track_quat('Z', 'Y').to_euler()
    handle.append(bar)
handle_joint = pivot("Carry loop hinge", (0, 0, 1.50), handle)
handle_joint.parent = carrier
handle_joint.location = (0, 0, .78)

scene = bpy.context.scene
scene.name = "ShrineCycle"
scene.render.fps = 30
scene.frame_start = 1
scene.frame_end = 211

def animate(obj, prop, value, frame):
    setattr(obj, prop, value)
    obj.keyframe_insert(data_path=prop, frame=frame, group=obj.name)

def unit_interval(value):
    return min(1, max(0, value))


sun_home = sun.location.copy()
for frame, legs_open, shield_open, ring_open, turn, lift, handle_turn in [
    (1, 0, 0, 0, 0, -.43, 0),
    (16, 0, .07, 0, .03, -.41, .34),
    (31, .06, .32, .03, .09, -.35, .91),
    (51, .63, .72, .11, .25, -.14, 1.42),
    (71, .94, .93, .50, .64, -.02, 1.57),
    (86, 1, 1, .70, 1.18, 0, 1.57),
    (102, 1, 1, 1, 2.05, 0, 1.57),
    (141, 1, 1, 1, 4.28, 0, 1.57),
    (156, 1, 1, .91, 5.04, 0, 1.57),
    (172, .84, .83, .57, 5.60, -.05, 1.57),
    (192, .22, .34, .10, 6.20, -.32, .80),
    (211, 0, 0, 0, 2*pi, -.43, 0),
]:
    animate(carrier, "location", (0, 0, .72+lift), frame)
    animate(handle_joint, "rotation_euler", (-handle_turn, 0, 0), frame)
    animate(sun, "location", sun_home + Vector((0,0,ring_open*.085)), frame)
    animate(sun, "rotation_euler", (0,turn*.17,turn), frame)

    for i, (hinge, ankle, gear, axis) in enumerate(hinges):
        opened = unit_interval(legs_open*(1+i*.07) - sin(legs_open*pi)*i*.15)
        animate(hinge, "rotation_axis_angle", ((1-opened)*-2.86, *axis), frame)
        animate(ankle, "rotation_axis_angle", ((1-opened)*.66, *axis), frame)
        animate(gear, "rotation_axis_angle", (opened*4.4, *axis), frame)
    for i, hinge in enumerate(petals):
        spread = unit_interval(shield_open - sin(shield_open*pi)*(i%3)*.11)
        animate(hinge, "rotation_euler", (0, spread*2.32, spread*.05*(-1)**i), frame)
    for i, gimbal in enumerate(gimbals):
        compact = .64 + i*.012
        expansion = compact + (1-compact)*ring_open
        animate(gimbal, "scale", (expansion,)*3, frame)
        animate(gimbal, "location", (0,0,.36+ring_open*.085), frame)
        animate(gimbal, "rotation_euler",
                ((.43-i*.37)*(1-ring_open) + ring_open*sin(turn+i*.83)*.77,
                 ring_open*cos(turn*.86+i*.51)*.91, turn), frame)

# glTF scene-mode sampling packs independent mechanical pivots into one clip.
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
carrier.select_set(True)
for obj in carrier.children_recursive:
    obj.select_set(True)
scene.frame_set(1)
bpy.ops.export_scene.gltf(filepath=str(MODEL), export_format='GLB',
                          use_selection=True, export_animation_mode='SCENE',
                          export_anim_scene_split_object=False, export_frame_range=True, export_frame_step=2,
                          export_anim_single_armature=False)

# The poster uses the same surface pattern as the browser's solar material.
nodes = solar.node_tree.nodes
links = solar.node_tree.links
noise = nodes.new("ShaderNodeTexNoise")
noise.inputs["Scale"].default_value = 4.8
noise.inputs["Detail"].default_value = 2.8
ramp = nodes.new("ShaderNodeValToRGB")
ramp.color_ramp.elements[0].position = .24
ramp.color_ramp.elements[0].color = (.9, .20, .011, 1)
ramp.color_ramp.elements[1].position = .76
ramp.color_ramp.elements[1].color = (1, .66, .18, 1)
links.new(noise.outputs["Fac"], ramp.inputs[0])
links.new(ramp.outputs[0], nodes.get("Principled BSDF").inputs["Emission Color"])
nodes.get("Principled BSDF").inputs["Emission Strength"].default_value = 1.65

floor = cylinder("Limestone display plinth", 12, .87, .075, (0, 0, -.048), stone)
bevel = floor.modifiers.new("Worn rim", 'BEVEL')
bevel.width = .034
bevel.segments = 2

def light(name, kind, location, color, power, size):
    data = bpy.data.lights.new(name, kind)
    data.energy = power
    data.color = color
    if kind == 'AREA':
        data.shape = 'DISK'
        data.size = size
    else:
        data.shadow_soft_size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector((0, 0, .8))-obj.location).to_track_quat('-Z', 'Y').to_euler()

light("Amber key", 'AREA', (2,-3,3.5), (1,.65,.36), 450, 3)
light("Teal edge", 'AREA', (-1,2,2.7), (.22,.69,1), 450, 2)
light("Soft sky", 'AREA', (-3,-3,3.8), (.55,.74,1), 230, 3)
light("Sun bounce", 'POINT', (0,-.12,1.08), (1,.36,.06), 14, .16)
scene.world = bpy.data.worlds.new("Night air")
scene.world.color = (.12,.12,.12)
camera = bpy.data.objects.new("Poster camera", bpy.data.cameras.new("Poster camera"))
bpy.context.collection.objects.link(camera)
camera.data.type = 'ORTHO'
scene.camera = camera
scene.render.engine = 'CYCLES'
scene.cycles.samples = 12
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.render.resolution_x = 750
scene.render.resolution_y = 750
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.view_settings.view_transform = 'AgX'
camera.location = (2.6,-4.0,2.4)
camera.rotation_euler = (Vector((0, 0, .84))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale = 2.35
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "sun_shrine_homepage.blend"))

with TemporaryDirectory(prefix="cindertrail-shrine-") as scratch:
    for name, frame, angle, scale in [
        ("carry", 1, .48, 1.93), ("unfold", 71, .70, 2.05),
        ("restore", 141, .93, 2.40), ("relocate", 211, 1.25, 2.20)
    ]:
        scene.frame_set(frame)
        camera.location = (4*sin(angle), -4*cos(angle), 2.25)
        camera.rotation_euler = (Vector((0,0,.69 if name in ("carry", "relocate") else .87))-camera.location).to_track_quat('-Z','Y').to_euler()
        camera.data.ortho_scale = scale
        png = Path(scratch) / f"{name}.png"
        scene.render.filepath = str(png)
        bpy.ops.render.render(write_still=True)
        run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(png),
             "-c:v", "libwebp", "-quality", "82", str(OUT / f"{name}.webp")], check=True)
