"""Cindertrail editable low-poly starter asset builder (Blender 4.3+).

Run from the package root:
  blender --background --python scripts/build_blender_assets.py -- --output art/models --render

Produces static GLB assets with embedded material colours and an editable .blend
library. These are authored starter models, not meshes extracted from concept art.
The crawler/brute are unrigged. Use them for look development before animation.
"""
from pathlib import Path
from math import sin, cos, pi
import argparse
import json
import math
import sys
import bpy
from mathutils import Vector, Euler

ROOT = Path(__file__).resolve().parents[1]
COLORS = json.loads((ROOT / "art/materials/palette.json").read_text())["colors"]
MATS = {}
CURRENT = []

def linear(v):
    return v / 12.92 if v < .04045 else ((v + .055)/1.055)**2.4

def material(name):
    if name in MATS:
        return MATS[name]
    c = tuple(linear(v) for v in COLORS[name]["srgb"])
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*c, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*c, 1)
    p.inputs["Roughness"].default_value = .52 if "bronze" in name or name == "brass" else .82
    p.inputs["Metallic"].default_value = .65 if "bronze" in name or name == "brass" else 0
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

def shrine(folded=False, restored=False):
    center = (0,0,.55 if folded else 1.08)
    radius = .34 if folded else .53
    if not folded:
        legs(.72,.46)
        cyl("Shrine_base",(0,0,.69),.40,.15,"bronze_dark",12)
        cyl("Shrine_trim",(0,0,.78),.43,.07,"brass",12)
    else:
        cyl("Lantern_base",(0,0,.15),.27,.14,"bronze_dark",10)
        for i in range(3):
            a=i*2*pi/3
            beam("Folded_leg",(.29*cos(a),.29*sin(a),.18),(.29*cos(a),.29*sin(a),.75),.035,"bronze",4)
        arc("Carry_handle",(0,0,.93),.13,.025,"bronze",(pi/2,0,0),0,pi,12)
    ico("Sun",center,(.23,.23,.23),"sun_amber",2)
    for i, rot in enumerate([(pi/2,0,0),(.2,pi/2,.25),(1.0,.5,1.1)]):
        arc("Orbit_ring_"+str(i),center,radius*(1+i*.055),.035,"brass",rot,
            0 if restored or folded else -.6, 2*pi if restored or folded else 4.3, 28)

def bolt():
    legs(.42,.30)
    cyl("Turret_base",(0,0,.35),.29,.19,"bronze_dark",10)
    cyl("Turret_rotor",(0,0,.54),.21,.17,"bronze",10)
    ico("Amber_crystal",(0,0,.86),(.12,.12,.30),"sun_amber",1)
    for x in (-.19,0,.19):
        beam("Bolt_prong",(x,.06,.72),(x,-.52,.75),.055,"brass",4)
        beam("Rear_prong",(x,.05,.72),(x,.23,.94),.05,"bronze",4)

def slowing():
    cyl("Stone_base",(0,0,.1),.36,.20,"stone_cream",10)
    cyl("Bronze_trim",(0,0,.23),.32,.07,"bronze",10)
    cyl("Luminous_stalk",(0,0,.43),.10,.32,"field_cyan",8)
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=.46, radius2=.26, depth=.15, location=(0,0,.66))
    assign(bpy.context.object,"Cyan_cap","field_cyan")
    arc("Cap_rim",(0,0,.585),.45,.028,"bronze",steps=24)
    for i in range(6):
        a=i*2*pi/6
        beam("Cap_rib",(.25*cos(a),.25*sin(a),.74),(.46*cos(a),.46*sin(a),.59),.018,"brass",4)

def mortar():
    legs(.38,.3)
    cyl("Mortar_base",(0,0,.33),.24,.20,"bronze_dark",10)
    cyl("Amber_chamber",(0,0,.47),.19,.21,"sun_amber",10)
    # Open low-poly stone bowl: outer wall, inner wall and visible rim.
    n=12
    verts=[]
    for r,z in [(.23,.53),(.39,.91),(.30,.91),(.17,.61)]:
        verts += [(r*cos(i*2*pi/n),r*sin(i*2*pi/n),z) for i in range(n)]
    faces=[]
    for band in range(3):
        for i in range(n):
            j=(i+1)%n
            faces.append((band*n+i,band*n+j,(band+1)*n+j,(band+1)*n+i))
    mesh=bpy.data.meshes.new("Mortar_bowl")
    mesh.from_pydata(verts,[],faces); mesh.update()
    o=bpy.data.objects.new("Mortar_bowl",mesh); bpy.context.collection.objects.link(o)
    assign(o,"Mortar_bowl","stone_cream")
    cyl("Bowl_glow",(0,0,.63),.16,.02,"sun_amber",12)

def block():
    cube("Stone_block",(0,0,.25),(1,.55,.5),"stone_cream",.045)

def pillar():
    cube("Plinth",(0,0,.12),(.68,.68,.24),"stone_shadow")
    for i in range(4):
        o=cube("Pillar_section",(0,0,.49+i*.51),(.46,.46,.49),"stone_cream",.025)
        o.rotation_euler[2]=(-.015 if i%2 else .015)
    cube("Capital",(0,0,2.42),(.66,.66,.22),"stone_light")
    cube("Bronze_inlay",(0,-.245,1.25),(.06,.035,1.1),"bronze",0)

def stairs():
    for i in range(6):
        cube("Step",(0,i*.38,(i+1)*.13),(1.8,.40,(i+1)*.26),"stone_cream",.025)

def arch():
    r, h = 1.0,1.3
    for side in (-1,1):
        for i in range(3):
            cube("Pier_stone",(side*1.18,0,(i+.5)*h/3),(.38,.48,h/3-.025),"stone_cream")
    for i in range(11):
        a=i*pi/11+.018; b=(i+1)*pi/11-.018
        verts=[]
        for y in (-.24,.24):
            for rad,t in [(r,a),(r,b),(r+.36,b),(r+.36,a)]:
                verts.append((rad*cos(t),y,h+rad*sin(t)))
        mesh=bpy.data.meshes.new("Arch_stone")
        mesh.from_pydata(verts,[],[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)])
        mesh.update();o=bpy.data.objects.new("Arch_stone",mesh);bpy.context.collection.objects.link(o)
        assign(o,"Arch_stone","stone_light" if i==5 else "stone_cream")

def tree(orange=False):
    beam("Trunk",(0,0,0),(.05,.05,2.1),.16,"wood",6)
    points=[(-.45,.10,2.0),(.45,.1,2.2),(.1,-.4,2.4),(-.1,.2,2.7)]
    for i,p in enumerate(points):
        beam("Branch",(0,0,1.4),p,.07,"wood",5)
        mat=("leaves_orange" if i%2 else "leaves_gold") if orange else ("foliage_teal" if i%2 else "foliage_light")
        ico("Foliage",p,(.75,.64,.48),mat,1)

def crate():
    cube("Crate_body",(0,0,.36),(.8,.6,.72),"wood",.02)
    for x in (-.34,.34):
        cube("Crate_band",(x,0,.36),(.07,.66,.78),"bronze_dark",.01)
    cube("Clasp",(0,-.33,.42),(.14,.05,.18),"brass",.01)

def crawler():
    ico("Crawler_shell",(0,0,.42),(.34,.45,.25),"enemy_charcoal",1)
    ico("Inner_glow",(0,0,.42),(.30,.40,.23),"field_cyan",1)
    ico("Head",(0,-.42,.33),(.23,.2,.17),"enemy_charcoal",1)
    for side in (-1,1):
        for i in range(3):
            y=(i-1)*.27
            knee=(side*.56,y-.08,.36)
            beam("Leg_upper",(side*.22,y,.42),knee,.055,"enemy_charcoal",4)
            beam("Leg_lower",knee,(side*.70,y-.18,.03),.04,"enemy_charcoal",4)
    for y in (-.2,.04,.25):
        beam("Cyan_fissure",(-.22,y,.55),(.08,y+.06,.64),.018,"field_cyan",4)

def brute():
    ico("Torso",(0,0,1.18),(.60,.40,.68),"enemy_charcoal",1)
    for side in (-1,1):
        cube("Shin",(side*.3,0,.35),(.35,.4,.65),"enemy_charcoal",.065)
        cube("Foot",(side*.3,-.16,.1),(.43,.62,.2),"enemy_charcoal",.04)
        ico("Shoulder",(side*.58,0,1.55),(.36,.40,.35),"stone_shadow",1)
        beam("Arm",(side*.58,0,1.45),(side*.85,-.18,.55),.22,"enemy_charcoal",5)
        ico("Fist",(side*.85,-.18,.45),(.24,.25,.28),"enemy_charcoal",1)
        cube("Chest_plate",(side*.23,-.32,1.35),(.45,.19,.49),"stone_shadow",.04)
        beam("Violet_fissure",(side*.10,-.43,1.03),(side*.28,-.43,1.40),.025,"brute_violet",4)
    ico("Head",(0,-.31,1.8),(.24,.26,.22),"enemy_charcoal",1)

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
    argv=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    args=parser.parse_args(argv)
    out=Path(args.output).resolve();out.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action="SELECT");bpy.ops.object.delete(use_global=False)
    manifest=[]
    for index,(name,build) in enumerate(BUILDERS.items()):
        CURRENT.clear();build()
        root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root)
        for o in CURRENT:
            o.parent=root
        bpy.ops.object.select_all(action="DESELECT")
        root.select_set(True)
        for o in CURRENT:o.select_set(True)
        bpy.context.view_layer.objects.active=root
        bpy.ops.export_scene.gltf(filepath=str(out/(name+".glb")),export_format="GLB",use_selection=True,
                                  export_apply=True,export_yup=True,export_animations=False)
        manifest.append({"file":name+".glb","static":True,"rigged":False,
                         "vertices":sum(len(o.data.vertices) for o in CURRENT if o.type=="MESH")})
        col,row=index%5,index//5
        root.location=((col-2)*3.5,(row-1)*4,0)
        text_obj(name,(root.location.x,root.location.y-1.15,.05))
    (out/"models_manifest.json").write_text(json.dumps({"generator":"build_blender_assets.py","units":"meters","up_axis_in_glb":"Y","assets":manifest},indent=2)+"\n")
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
    print("CINDERTRAIL_ASSETS_COMPLETE "+str(len(manifest)))

if __name__=="__main__":main()
