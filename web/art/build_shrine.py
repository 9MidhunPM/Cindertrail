"""Produce the homepage shrine from the project's authored Godot model."""
from math import cos, pi, sin
from pathlib import Path
from subprocess import run
from tempfile import TemporaryDirectory

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = HERE.parent / "public" / "shrine"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / "art/models/sun_shrine_deployed.glb"))
parts = {obj.name: obj for obj in bpy.context.selected_objects}
sun = parts["Sun"]
base = parts["Shrine_base"]
trim = parts["Shrine_trim"]
legs = sorted((obj for name, obj in parts.items() if name.startswith("Folding_leg")), key=lambda obj: obj.name)
feet = sorted((obj for name, obj in parts.items() if name.startswith("Foot")), key=lambda obj: obj.name)
rings = [parts[f"Orbit_ring_{i}"] for i in range(3)]
for obj in [sun, base, trim, *legs, *feet, *rings]:
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

gold = material("Hand-worked brass", (.65, .32, .085), .63, .37)
bronze = material("Weathered bronze", (.26, .11, .033), .47, .52)
dark = material("Patinated bronze", (.052, .038, .024), .4, .54)
solar = material("Miniature sun", (1, .36, .029), .06, .52, 2.1)
stone = material("Grove limestone", (.18, .20, .17), .02, .91)

def recolor(obj, palette):
    for i, src in enumerate(obj.data.materials):
        obj.data.materials[i] = next((mat for key, mat in palette if key in src.name.lower()), bronze)

for obj in [base, trim, *legs, *feet, *rings]:
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
gimbals = []
for i, ring in enumerate(rings):
    gimbal = pivot(f"Orbital ring {i+1}", solar_center, [ring])
    gimbal.parent = carrier
    gimbal.location = solar_center - carrier.location
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
    hinge = pivot(f"Leg hinge {i+1}", anchor, [leg, foot, pin, *fittings])
    hinge.parent = carrier
    hinge.location = anchor - carrier.location
    hinge.rotation_mode = 'AXIS_ANGLE'
    hinges.append((hinge, axis))

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
scene.frame_end = 121

def animate(obj, prop, value, frame):
    setattr(obj, prop, value)
    obj.keyframe_insert(data_path=prop, frame=frame, group=obj.name)

for frame, opened, turn, raised in [
    (1, 0, 0, -.43), (13, 0, 0, -.38), (41, .77, .20, -.03),
    (53, 1, .32, 0), (81, 1, 1.05, 0), (96, 1, 1.40, 0), (121, 0, 0, -.43)
]:
    animate(carrier, "location", (0, 0, .72 + raised), frame)
    animate(handle_joint, "rotation_euler", (-opened*1.37, 0, 0), frame)
    for i, (hinge, axis) in enumerate(hinges):
        angle = (1-opened) * -2.86
        animate(hinge, "rotation_axis_angle", (angle, *axis), frame)
    for i, gimbal in enumerate(gimbals):
        compact = .68 + i*.018
        expansion = compact + (1-compact)*(opened**3)
        animate(gimbal, "scale", (expansion,)*3, frame)
        animate(gimbal, "rotation_euler",
                ((.35-i*.24)*(1-opened) + turn*(.7-i*.12), turn*(i*.23-.18), turn*(.38+i*.16)), frame)

# glTF scene-mode sampling packs independent mechanical pivots into one clip.
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
carrier.select_set(True)
for obj in carrier.children_recursive:
    obj.select_set(True)
scene.frame_set(1)
bpy.ops.export_scene.gltf(filepath=str(OUT / "shrine.glb"), export_format='GLB',
                          use_selection=True, export_animation_mode='SCENE',
                          export_anim_scene_split_object=False, export_frame_range=True,
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
light("Sun bounce", 'POINT', (0,-.12,1.08), (1,.36,.06), 18, .16)
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
        ("carry", 1, .48, 1.93), ("unfold", 41, .70, 2.05),
        ("restore", 81, .93, 2.30), ("relocate", 121, 1.25, 2.20)
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
