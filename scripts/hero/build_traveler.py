"""Rebuild the articulated traveler and folded shrine fittings with blender -b -P scripts/hero/build_traveler.py."""
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


teal = mat('Petrol wool','327079')
fold = mat('Shadow fold','244e5d')
highlight = mat('Worn teal','498389')
ochre = mat('Ochre lining','ca8835')
leather = mat('Russet harness','66452e')
glove = mat('Oiled leather','584537')
black = mat('Dark indigo','292c34')
slate = mat('Shale gray','414049')
brass = mat('Antique brass','c79349',.43)
deep = mat('Inside hood','131d27')


def pivot(name, loc, parent=None):
    o = bpy.data.objects.new(name,None)
    bpy.context.collection.objects.link(o)
    if parent is not None:
        bpy.context.view_layer.update()
        o.parent = parent
        o.location = parent.matrix_world.inverted() @ Vector(loc)
    else:
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


hips=pivot('Pelvis',(0,0,.84))
body=pivot('UpperBody',(0,0,.94),hips)
coat=pivot('CoatHem',(0,0,.94),hips)
for side, tag in ((-1,'L'),(1,'R')):
    x=side*.124
    leg=pivot('Leg'+tag,(x,0,.84),hips)
    knee=pivot('Knee'+tag,(x,0,.445),leg)
    foot=pivot('Foot'+tag,(x,0,.09),knee)
    tube('Pleated trouser',(x,0,.41),(x*1.08,0,.84),.096,.130,slate,leg,9)
    ico('Knee fold',(x,.013,.443),(.109,.112,.112),slate,knee)
    tube('Boot shaft',(x,-.008,.088),(x,0,.432),.081,.096,glove,knee,9)
    ico('Toe',(x,.055,.079),(.094,.153,.081),glove,foot,2)
    ico('Welt',(x,.052,.037),(.097,.155,.032),black,foot,2)
    for z in (.17,.24,.32):
        tube('Winding',(x,0,z),(x,0,z+.023),.089,.092,leather,knee,9)
    ico('Boot clasp',(x, .084,.251),(.030,.016,.027),brass,knee)
oval('Divided traveling coat',[(.51,.33,.226,-.055),(.77,.262,.178,-.022),(.998,.179,.135,0),(1.28,.204,.145,0)],teal,coat,16,True)
# Unequal trailing rear panels with visible ochre undersides.
for side,tag in ((-1,'L'),(1,'R')):
    x=side
    panel=pivot('Tail'+tag,(.105*x,-.161,.965),coat)
    tail_length = .14 if side < 0 else -.025
    pts=[(.025*x,-.144,.99),(.191*x,-.098,.975),(.302*x,-.257,.64),(.39*x,-.345,.49-tail_length),(.086*x,-.241,.65)]
    poly('Tail lining',pts,[(0,1,2),(0,2,4),(4,2,3)],ochre,panel)
    pts=[(a,b-.009,c+.055 if c<.64 else c) for a,b,c in pts]
    poly('Cloak tail',pts,[(0,1,2),(0,2,4),(4,2,3)],teal,panel)
    # Narrow blade of faded ochre sewn along each weathered panel edge.
    a,b=Vector(pts[2]),Vector(pts[3])
    poly('Frayed gold hem',[a,b,(b.x*.8,b.y+.004,b.z+.06),(a.x*.94,a.y-.003,a.z+.016)],[(0,1,2,3)],ochre,panel)
    arm=pivot('Arm'+tag,(side*.217,0,1.31),body)
    shoulder=(side*.219,.006,1.31); elbow=(side*.282,-.018,1.085); wrist=(side*.304,.024,.90)
    forearm=pivot('Elbow'+tag,elbow,arm)
    tube('Folded undersleeve',elbow,shoulder,.087,.105,slate,arm,9)
    tube('Sleeve cuff',wrist,elbow,.063,.085,black,forearm)
    tube('Beveled vambrace',(wrist[0],.022,.915),(wrist[0],.002,1.05),.065,.079,leather,forearm,9)
    tube('Cuff embroidery',(wrist[0],.021,.928),(wrist[0],.021,.936),.068,.068,brass,forearm,8)
    ico('Mitten',(wrist[0],.047,.875),(.057,.061,.083),glove,forearm,2)
oval('Shoulder cape',[(1.152,.36,.202,-.008),(1.248,.309,.188,-.009),(1.376,.211,.158,0),(1.435,.14,.116,0)],teal,body,14,True)
# Overlapping bias-cut mantle gives the shoulders a broken silhouette.
for side in [-1,1]:
    x=side
    mantle=[(.07*x,.143,1.40),(.20*x,.105,1.395),(.35*x,.068,1.235),
            (.374*x,-.035,1.15),(.26*x,-.165,1.225),(.083*x,-.154,1.38)]
    poly('Mantle bias panels',mantle,[(0,1,2),(0,2,5),(5,2,4),(4,2,3)],highlight,body)
    tube('Worn mantle edge',mantle[2],mantle[3],.010,.006,ochre,body,4)
oval('Gathered cowl',[(1.365,.183,.140,0),(1.419,.173,.130,0),(1.471,.145,.118,0),(1.512,.145,.113,0)],fold,body)
oval('Travel belt',[(.995,.191,.145,0),(1.051,.187,.146,0)],leather,body)
ico('Brass belt buckle',(0,.146,1.026),(.056,.013,.034),brass,body)
# A broad bias-cut leather baldrick crosses the front of the cloak.
strap = [(-.141,.102,1.37),(-.040,.177,1.27),(.064,.187,1.175),(.141,.12,1.067)]
for a,b in zip(strap,strap[1:]):
    x,y,z=a; xx,yy,zz=b
    poly('Cross belt',[(x-.022,y+.011,z-.022),(x+.022,y+.011,z+.022),
         (xx+.022,yy+.011,zz+.022),(xx-.022,yy+.011,zz-.022)],[(0,1,2,3)],leather,body)
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
 [(.019,-.219,1.685),(.094,-.178,1.725),(.127,-.219,1.586),(.129,-.217,1.492),(0,-.16,1.50)],
 [(0,-.068,1.818),(.147,-.088,1.738),(.183,-.102,1.597),(.20,-.127,1.486),(0,-.104,1.453)],
 [(0,.053,1.807),(.152,.055,1.731),(.170,.041,1.597),(.170,.022,1.468),(0,.053,1.449)],
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
head=pivot('Hood',(0,0,1.44),body)
hood=poly('Angular open hood',vertices,faces,teal,head)
hood.data.materials.append(highlight)
hood.data.materials.append(fold)
for i,p in enumerate(hood.data.polygons):
    p.material_index=1 if i%13==5 else 2 if i%11==2 else 0
rim=vertices[-8:]
poly('Recessed face',rim+[(0,.081,1.618)],[(i,(i+1)%8,8) for i in range(8)],deep,head)
# Double folds frame the ear and splay into the lower cowl.
for side in [-1,1]:
    x=side
    pts=[(.162*x,-.076,1.705),(.183*x,.034,1.600),(.181*x,.020,1.478),
         (.204*x,-.127,1.480),(.184*x,-.164,1.562)]
    poly('Hood tuck',pts,[(0,1,4),(1,2,3),(1,3,4)],teal,head)
for i in (0,1,6,7):
    tube('Hood piping',rim[i],rim[(i+1)%8],.006,.006,ochre,head,5)
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


# The carry sheet shows a folded cage with fluted cheek straps and riveted
# latches. This detachable metalwork augments the starter folded shrine.
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bronze = mat('Worked bronze','a1713d',.45)
sun_brass = mat('Polished edges','d3a259',.42)
dark_bronze = mat('Recessed plate','6f4c32',.37)
for side in [-1,1]:
    rings=[]
    for i in range(17):
        angle=-1.26+i*(2.52/16)
        width=.021+.016*math.cos(angle)**2
        # Two bowed metal bands fold close around the recessed miniature sun.
        x=side*(.063*.36+.143*math.cos(angle))
        y=-.335*math.cos(angle)
        z=.55+.368*math.sin(angle)
        rings.extend([(x-width,y,z),(x-width*.76,y-.012,z),
                      (x+width*.76,y-.012,z),(x+width,y,z)])
    faces=[]
    for j in range(16):
        for h in range(3):
            k=4*j+h
            faces.append((k,k+1,k+5,k+4))
    cheek=poly('Bow stay',rings,faces,bronze)
    cheek.data.materials.append(sun_brass)
    for j,f in enumerate(cheek.data.polygons):
        f.material_index=int(j%3==0)
# Stamped escutcheon over the outermost buckle.
for y,size,material in [(-.367,.093,bronze),(-.379,.062,sun_brass),(-.386,.037,dark_bronze)]:
    poly('Buckle diamond',[(0,y,.55+size),(size*.82,y,.55),(0,y,.55-size),(-size*.82,y,.55)],[(0,1,2,3)],material)
for i in range(12):
    a=i*math.tau/12
    ico('Rivet',(.343*math.sin(a),.343*math.cos(a),.55),(.015,.015,.015),sun_brass)
for m in (bronze,sun_brass,dark_bronze):
    m.use_backface_culling=False
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active=bpy.context.selected_objects[0]
bpy.ops.object.join()
bpy.context.object.name='FoldedFittings'
bpy.ops.export_scene.gltf(filepath=str(dest.with_name('folded_fittings.glb')),export_format='GLB',export_yup=True)
