"""Rebuild the original traveler mesh with blender -b -P scripts/hero/build_traveler.py."""
import bpy
import math
from pathlib import Path
from mathutils import Vector

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
materials = {}


def mat(name, color, metallic=0):
    value = bpy.data.materials.new(name)
    value.diffuse_color = tuple(((int(color[i:i+2], 16)/255+.055)/1.055)**2.4 for i in (0,2,4)) + (1,)
    value.use_nodes = True
    shader = value.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = value.diffuse_color
    shader.inputs['Roughness'].default_value = .74
    shader.inputs['Metallic'].default_value = metallic
    materials[name] = value
    return value


teal = mat('Petrol wool','164d51')
fold = mat('Shadow fold','113a42')
highlight = mat('Worn teal','286462')
ochre = mat('Ochre lining','ca8835')
leather = mat('Russet harness','66452e')
glove = mat('Oiled leather','453a33')
black = mat('Dark indigo','292c34')
slate = mat('Shale gray','414049')
brass = mat('Antique brass','c79349',.43)
deep = mat('Inside hood','131d27')


def pivot(name, loc):
    o = bpy.data.objects.new(name,None)
    bpy.context.collection.objects.link(o)
    o.location = loc
    return o


def finish(o, name, material, parent=None):
    o.name = name
    o.data.materials.append(material)
    if parent:
        bpy.context.view_layer.update()
        o.parent = parent
        o.matrix_parent_inverse = parent.matrix_world.inverted()
    return o


def poly(name, points, faces, material, parent=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points, [], faces)
    mesh.update()
    o = bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(o)
    return finish(o,name,material,parent)


def tube(name, a, b, r1, r2, material, parent=None, n=7):
    a,b = Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=r1,radius2=r2,depth=(b-a).length,location=(a+b)/2)
    obj = bpy.context.object
    obj.rotation_euler = (b-a).to_track_quat('Z','Y').to_euler()
    return finish(obj,name,material,parent)


def ico(name,p,s,material,parent=None,sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,location=p)
    o=bpy.context.object
    o.scale=s
    return finish(o,name,material,parent)


def oval(name, profiles, material, parent=None, n=14, fabric=False):
    # Hand-shaped stacked loops, with alternating pleats and a swept coat hem.
    points=[]
    for z,rx,ry,cy in profiles:
        for i in range(n):
            a=2*math.pi*i/n
            pleat=1+.055*(-1)**i if fabric else 1
            x=rx*math.cos(a)*pleat
            y=ry*math.sin(a)*pleat+cy
            h=z
            if fabric and z<.75:
                h+=.045*math.cos(3*a)+.075*math.cos(a)+.025*(-1)**i
            points.append((x,y,h))
    faces=[tuple(reversed(range(n)))]
    for j in range(len(profiles)-1):
        for i in range(n):
            k=j*n+i
            m=j*n+(i+1)%n
            faces.extend([(k,m,m+n),(k,m+n,k+n)])
    faces.append(tuple(range(len(points)-n,len(points))))
    o=poly(name,points,faces,material,parent)
    if fabric:
        o.data.materials.append(fold)
        o.data.materials.append(highlight)
        for i,f in enumerate(o.data.polygons):
            f.material_index = 1 if i%12 in (3,4) else 2 if i%16==11 else 0
    return o


for side, tag in ((-1,'L'),(1,'R')):
    x=side*.124
    leg=pivot('Leg'+tag,(x,0,.84))
    tube('Pleated trouser',(x,0,.40),(x*1.12,0,.78),.094,.132,slate,leg,8)
    ico('Knee fold',(x,.013,.41),(.109,.112,.133),slate,leg)
    tube('Boot shaft',(x,-.008,.10),(x,0,.37),.081,.091,glove,leg)
    ico('Toe',(x,.05,.082),(.094,.154,.082),glove,leg,2)
    tube('Boot cuff',(x,0,.219),(x,0,.256),.089,.091,leather,leg,8)
    ico('Boot clasp',(x, .085,.235),(.044,.01,.021),brass,leg)
body=pivot('UpperBody',(0,0,.89))
coat=pivot('CoatHem',(0,0,.94))
oval('Divided traveling coat',[(.51,.33,.226,-.055),(.77,.262,.178,-.022),(.998,.179,.135,0),(1.28,.204,.145,0)],teal,coat,16,True)
# Unequal trailing rear panels with visible ochre undersides.
for side in (-1,1):
    x=side
    tail_length = .16 if side < 0 else .02
    pts=[(.04*x,-.138,.98),(.178*x,-.092,.98),(.282*x,-.24,.62),(.345*x,-.31,.46-tail_length),(.09*x,-.218,.62)]
    poly('Tail lining',pts,[(0,1,2),(0,2,4),(4,2,3)],ochre,coat)
    pts=[(a,b-.006,c+.045 if c<.64 else c) for a,b,c in pts]
    poly('Cloak tail',pts,[(0,1,2),(0,2,4),(4,2,3)],teal,coat)
for side,tag in ((-1,'L'),(1,'R')):
    arm=pivot('Arm'+tag,(side*.217,0,1.31))
    p=(side*.219,.006,1.31); elbow=(side*.278,-.006,1.095); wrist=(side*.301,.035,.901)
    tube('Folded sleeve',elbow,p,.09,.104,slate,arm)
    tube('Sleeve cuff',wrist,elbow,.063,.089,black,arm)
    tube('Leather bracer',(wrist[0],.033,.917),(wrist[0],.026,.991),.062,.069,leather,arm)
    ico('Mitten',(wrist[0],.045,.878),(.055,.059,.081),glove,arm)
oval('Shoulder cape',[(1.152,.36,.202,-.008),(1.248,.309,.188,-.009),(1.376,.211,.158,0),(1.435,.14,.116,0)],teal,body,14,True)
oval('Gathered cowl',[(1.372,.159,.126,0),(1.419,.161,.116,0),(1.466,.117,.105,0),(1.499,.119,.102,0)],fold,body)
oval('Travel belt',[(.995,.191,.145,0),(1.051,.187,.146,0)],leather,body)
ico('Brass belt buckle',(0,.146,1.026),(.056,.013,.034),brass,body)
# Wrap two raised leather shoulder straps from front to back.
for side in (-1,1):
    for a,b in [((side*.065,.151,1.245),(side*.18,.064,1.374)),((side*.18,.064,1.374),(side*.182,-.07,1.374)),((side*.182,-.07,1.374),(side*.082,-.163,1.15))]:
        tube('Harness webbing',a,b,.036,.038,leather,body,4)
ico('Mantle brooch',(0,.171,1.248),(.059,.021,.062),brass,body,2)
ico('Harness dock',(0,-.148,1.154),(.122,.046,.18),leather,body,2)
# Sewn half-sun on the lowest rear panel.
for i in range(13):
    a=i*math.pi/12
    x,z=.118*math.cos(a),.603+.101*math.sin(a)
    y=-.262+abs(x)*.22
    if i<12:
        b=(i+1)*math.pi/12
        xx=.118*math.cos(b)
        tube('Embroidered arc',(x,y,z),(xx,-.262+abs(xx)*.22,.603+.101*math.sin(b)),.010,.010,ochre,coat,4)
    if i%2==0:
        tube('Sun stitch',(x*1.14,y,.603+(z-.603)*1.14),(x*1.32,y,.603+(z-.603)*1.34),.007,.007,ochre,coat,4)
# Hood opening follows a pentagonal arch around a recessed featureless face.
# Rings progress from the deep back of the head towards the face opening.
loops=[
 [(.019,-.219,1.685),(.094,-.178,1.725),(.119,-.194,1.589),(.092,-.19,1.50),(0,-.16,1.50)],
 [(0,-.068,1.818),(.147,-.088,1.738),(.183,-.102,1.597),(.177,-.112,1.486),(0,-.104,1.453)],
 [(0,.053,1.807),(.152,.055,1.731),(.170,.041,1.597),(.152,.025,1.476),(0,.053,1.449)],
 [(0,.172,1.748),(.097,.147,1.684),(.137,.141,1.579),(.129,.137,1.519),(0,.158,1.473)]]
vertices=[]
for half in loops:
    vertices.extend(half+[(-x,y,z) for x,y,z in half[-2:0:-1]])
n=8
faces=[(1,0,7),(2,1,7),(2,7,6),(2,6,5),(2,5,3),(3,5,4)]
for k in range(3):
    for i in range(n):
        a=k*n+i;b=k*n+(i+1)%n
        faces.extend([(a,b,a+n),(b,b+n,a+n)])
hood=poly('Angular open hood',vertices,faces,teal,body)
hood.data.materials.append(highlight)
hood.data.materials.append(fold)
for i,p in enumerate(hood.data.polygons):
    p.material_index=1 if i%13==5 else 2 if i%11==2 else 0
rim=vertices[-8:]
poly('Recessed face',rim+[(0,.081,1.618)],[(i,(i+1)%8,8) for i in range(8)],deep,body)
for i in (0,1,6,7):
    tube('Hood piping',rim[i],rim[(i+1)%8],.006,.006,ochre,body,5)
# Garment and hood interiors can be viewed from below while orbiting.
for m in materials.values():
    m.use_backface_culling=False
# Batch rigid cloth and accessories by moving body part to reduce draw calls.
for joint in [o for o in bpy.context.scene.objects if o.type == 'EMPTY']:
    pieces = [o for o in joint.children if o.type == 'MESH']
    if len(pieces) < 2:
        continue
    bpy.ops.object.select_all(action='DESELECT')
    for part in pieces:
        part.select_set(True)
    bpy.context.view_layer.objects.active = pieces[0]
    bpy.ops.object.join()
    bpy.context.object.name = joint.name + 'Geometry'
dest=Path(__file__).resolve().parents[2]/'art/models/traveler.glb'
bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',export_yup=True)
