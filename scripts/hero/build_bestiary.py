"""Build all or selected articulated creatures with Blender's GLB exporter."""
import argparse
import json
import struct
from pathlib import Path
from math import sin, cos, pi
import sys
import bpy
import bmesh
import numpy as np
from mathutils import Vector

DEST = Path(__file__).resolve().parents[2] / 'art/models'
TAU = 2 * pi

# Palette strips run across the sheet. Each column contains its own irregular
# mineral veins, chips, dark recess and rubbed edge, sampled in plate-local UVs.
PALETTES = {
    'crawler_static': ['233744', '394e5b', '56707a', '172c33', '38d7cf'],
    'brute_static': ['463a52', '635468', '817188', '292535', 'b26aef'],
    'ford_skimmer': ['185055', '397278', '74a9a4', '173d49', '60e4d6'],
    'quarry_ram': ['584536', '94734f', 'c4a074', '362d30', 'f2b653'],
    'splinterback': ['3e3850', '615476', '947eac', '2b2b44', 'c5a1ef'],
    'bell_warden': ['284b4c', '697665', 'b69a65', '293e42', '85ddd1'],
    'vesper_colossus': ['30354b', '58546d', '97876c', '242537', 'ffc978'],
}


def atlas(material_colors, guardian=False):
    size = 1024
    y, x = np.mgrid[:size, :size].astype(np.float32) / size
    rng = np.random.default_rng(123)
    pixels = np.ones((size, size, 4), dtype=np.float32)
    tile = np.minimum((x * 4).astype(int), 3)
    u = (x * 4) % 1
    light = .83 + .20 * y + .035 * np.sin(17 * y + 9 * u)
    for freq, amount in [(9, .034), (39, .024), (127, .012)]:
        light += amount * np.sin(freq * y + 2.5 * np.sin(u * freq * .5 + .4))
    for _ in range(40):
        angle = rng.uniform(-.8, .8)
        center = rng.uniform(0, 1)
        cut = y - center - angle * (u - .5) + .008*np.sin(21*u + center)
        taper = np.exp(-((u-rng.random())/rng.uniform(.04,.25))**4)
        light += (.1*np.exp(-((cut+.003)/.003)**2) - .16*np.exp(-(cut/.004)**2))*taper
    light += .085 * np.exp(-((y-.84)/.025)**2)
    for k, color in enumerate(material_colors[:4]):
        rgb = np.array([int(color[j:j+2],16) / 255 for j in (0,2,4)])
        pixels[:,:,:3] += ((light[:,:,None] * rgb - 1) * (tile == k)[:,:,None])
    im = bpy.data.images.new('MineralPaint',size,size,alpha=False)
    im.pixels.foreach_set(pixels.flatten())
    im.file_format='PNG'
    im.pack()
    mat = bpy.data.materials.new('Painted mineral armor')
    mat.use_nodes=True
    bs=mat.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Roughness'].default_value=.77
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image=im
    mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    vein=bpy.data.materials.new('Luminous seam')
    vein.use_nodes=True
    bs=vein.node_tree.nodes.get('Principled BSDF')
    rgb=[(int(material_colors[-1][j:j+2],16)/255)**2.2 for j in (0,2,4)]+[1]
    bs.inputs['Base Color'].default_value=rgb
    bs.inputs['Emission Color'].default_value=rgb
    bs.inputs['Emission Strength'].default_value=.85
    if guardian:
        dusk=vein.copy()
        dusk.name='Violet crystal slit'
        dusk_bs=dusk.node_tree.nodes.get('Principled BSDF')
        for socket in ['Base Color','Emission Color']:
            dusk_bs.inputs[socket].default_value=(.35,.075,.53,1)
        return [mat,vein,dusk]
    return [mat,vein]


def world(p):
    return Vector((p[0],-p[2],p[1]))


class Joint:
    """A joint and one batched mesh for all its moving plates."""
    def __init__(self,name,origin=(0,0,0),parent=None):
        self.name=name
        self.origin=Vector(origin)
        self.obj=bpy.data.objects.new(name,None)
        bpy.context.collection.objects.link(self.obj)
        self.obj.parent=parent.obj if parent else None
        self.obj.location=world(self.origin-(parent.origin if parent else Vector((0,0,0))))
        self.vertices=[]; self.faces=[]; self.paint=[]; self.uv=[]
        JOINTS.append(self)

    def shell(self,center,scale,ink=0,n=12,rows=7,lean=0,tilt=0):
        """A bevelled convex plate with offset crest and a tapered leading edge."""
        cx,cy,cz=center
        ax,ay,az=scale
        rings=[]
        for j in range(rows+1):
            t=j/rows
            v=-1+2*t
            r=max(.012,(1-v*v)**.61)
            ring=[]
            for i in range(n):
                a=TAU*i/n
                x=r*cos(a); z=r*sin(a)
                ring.append((cx+ax*x+tilt*v,cy+ay*v+lean*z,cz+az*z))
            rings.append(ring)
        self.loft(rings,ink)

    def limb(self,points,radii,ink=0,n=8):
        """Tapering swept limb or tine following an anatomical centerline."""
        rings=[]
        for j,p in enumerate(points):
            v=(Vector(points[min(len(points)-1,j+1)])-Vector(points[max(j-1,0)])).normalized()
            ref=Vector((1,0,0)) if abs(v.x)<.85 else Vector((0,0,1))
            a=v.cross(ref).normalized()
            b=v.cross(a)
            ra,rb=radii[j] if isinstance(radii[j],tuple) else (radii[j],radii[j])
            rings.append([Vector(p)+ra*a*cos(TAU*i/n)+rb*b*sin(TAU*i/n) for i in range(n)])
        self.loft(rings,ink)

    def loft(self,rings,ink):
        start=len(self.vertices); n=len(rings[0]); rows=len(rings)-1
        for row in rings:
            self.vertices.extend([world(Vector(p)-self.origin) for p in row])
        def face(ids,coords):
            self.faces.append(tuple(start+i for i in ids))
            self.paint.append(max(0,ink-3))
            column=min(ink,3)
            self.uv.append([((column+.015+.97*u)/4,.014+.972*v) for u,v in coords])
        for j in range(rows):
            for i in range(n):
                k=(i+1)%n
                face((j*n+i,j*n+k,(j+1)*n+k,(j+1)*n+i),[(i/n,j/rows),((i+1)/n,j/rows),((i+1)/n,(j+1)/rows),(i/n,(j+1)/rows)])
        for j in [0,rows]:
            face(tuple(j*n+i for i in range(n)),[(.5+.45*cos(TAU*i/n),.5+.45*sin(TAU*i/n)) for i in range(n)])

    def finish(self,mats):
        if not self.faces: return
        mesh=bpy.data.meshes.new(self.name+' armor')
        mesh.from_pydata(self.vertices,[],self.faces)
        obj=bpy.data.objects.new(self.name+'Plates',mesh)
        bpy.context.collection.objects.link(obj)
        obj.parent=self.obj
        for m in mats: mesh.materials.append(m)
        uv=mesh.uv_layers.new(name='Paint')
        for f,coords,ink in zip(mesh.polygons,self.uv,self.paint):
            f.material_index=ink
            for i,c in zip(f.loop_indices,coords): uv.data[i].uv=c
        bm=bmesh.new(); bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
        bm.to_mesh(mesh); bm.free()


def arthropod(kind):
    slim=kind=='ford_skimmer'; crystals=kind=='splinterback'
    root=Joint('Carapace')
    length=1.2 if slim else 1
    root.shell((0,.40,-.05),(.35,.20,.50*length),3)
    for j in range(5):
        z=(j-2)*.17*length
        w=.27+.07*cos((j-2)*.7)
        root.shell((0,.48,z-.02),(w,.145,.17),4,n=8,rows=4)
        root.shell((0,.515,z),(w+.015,.15,.19),j%2,n=12,rows=5,lean=.044)
    for side,s in [('L',-1),('R',1)]:
        for j in range(3):
            z=(j-1)*.31*length
            hip=(s*.23,.42,z)
            knee=(s*(.68+.08*cos(j)),.50,z+(j-1)*.18)
            ankle=(s*.89,.16,z+(j-1)*.28)
            toe=(s*.94,.012,z+(j-1)*.36+.02)
            leg=Joint('Hip_'+side+str(j),hip,root)
            leg.limb([hip,knee,ankle,toe],[.082,.075,.04,.009],3)
            middle=(s*.48,.485,z+(j-1)*.09)
            leg.limb([hip,middle,knee],[.055,(.105,.13),.066],1,10)
            leg.shell(knee,(.078,.069,.073),4,n=9,rows=4)
            leg.limb([knee,ankle,toe],[.092,(.051,.073),.003],0,9)
            if slim:
                leg.limb([knee,(s*.74,.47,z-.28),(s*.78,.45,z-.47)],[(.035,.10),(.018,.095),.003],2)
        if crystals or slim:
            fan=Joint('Fan_'+side,(s*.19,.51,-.17),root)
            for j in range(5):
                z=-.45+j*.13
                end=(s*(.46+.10*sin(j)), .88+.14*sin(j*.85) if crystals else .54, z-.28)
                fan.limb([(s*.20,.49,z),(s*.31,.61,z-.08),end],[.07,(.065,.10),.002],2,7)
    # Separate fluted lateral scutes frame the luminous midline. The
    # overhanging eaves shield the soft joints without hiding the feet.
    for s in [-1, 1]:
        for j in range(5):
            z=(j-2)*.165*length
            root.shell((s*.255,.465,z),(.112,.067,.14),1 if j%2 else 2,11,5,lean=.029,tilt=-s*.045)
            if kind=='crawler_static':
                root.limb([(s*.22,.55,z+.035),(s*.29,.53,z),(s*.36,.474,z-.075)],
                          [.008,.014,.005],4,7)
                root.shell((s*.21,.58,z),(.079,.063,.11),0,10,4,lean=.033)
    if kind=='crawler_static':
        # Fault line runs through the dorsal plates, then forks above the eyes.
        # Its taper keeps the irregular split legible against the slate shell.
        root.limb([(0,.64,-.48),(.047,.669,-.33),(-.029,.676,-.22),
                   (.048,.674,-.09),(-.012,.674,.02),(.021,.672,.13)],
                  [.006,.022,.025,.025,.021,.026],4,7)
        for s in [-1,1]:
            root.limb([(.021,.672,.13),(s*.099,.667,.209),(s*.119,.658,.258),
                       (s*.21,.638,.307),(s*.247,.61,.394)],
                      [.026,.022,.017,.025,.006],4,7)
    head=Joint('HeadPivot',(0,.42,.37),root)
    head.shell((0,.415,.48*length),(.236,.147,.20),0)
    for s in [-1,1]:
        for i in range(3):
            head.shell((s*(.056+i*.049),.45-i*.016,.655*length-i*.017),(.022,.025,.019),4,7,3)
        head.limb([(s*.125,.385,.58*length),(s*.15,.29,.68*length),(s*.078,.274,.75*length)],[.046,.036,.002],2)


def hulking(kind):
    boss=kind=='vesper_colossus'; bell=kind=='bell_warden'
    root=Joint('Spine')
    root.shell((0,.93,-.14),(.40,.43,.35),3,14,7)
    root.shell((0,1.28,.08),(.53,.46,.40),0,14,8)
    for j in range(4):
        z=-.40+j*.15
        root.shell((0,1.35+.085*j,z),(.37+.031*j,.22,.19),1,12,6,lean=.06)
    for side,s in [('L',-1),('R',1)]:
        hip=(s*.24,.84,-.15)
        leg=Joint('Leg'+side if boss else 'Hip_'+side+'0',hip,root)
        knee=(s*.38,.46,-.06); heel=(s*.41,.15,-.33)
        leg.limb([hip,knee,heel],[.19,.15,.12],3,12)
        leg.shell((s*.325,.64,-.10),(.202,.265,.204),1)
        leg.shell(knee,(.16,.14,.17),2,10,6)
        leg.shell(heel,(.16,.13,.17),0)
        leg.shell((s*.41,.089,-.22),(.19,.085,.25),1)
        for j in range(3):
            x=s*(.31+j*.09)
            leg.limb([(x,.10,-.12),(x,.08,-.01),(x,.035,.064)],[.067,.06,.003],2)
        shoulder=(s*.47,1.49,.16)
        arm=Joint('Arm'+side if boss else 'Shoulder_'+side,shoulder,root)
        elbow=(s*.72,1.01,.24); wrist=(s*.76,.38,.46)
        arm.limb([shoulder,elbow,wrist],[.24,.17,.19],3,14)
        for j in range(3):
            arm.shell((s*(.49+.075*j),1.47-.12*j,.16),(.272-.024*j,.235,.26-.013*j),j%2,13,7,tilt=-s*.06)
        arm.shell(elbow,(.21,.205,.17),4,10,4)
        arm.shell((s*.746,.77,.32),(.216,.31,.204),1)
        arm.shell((s*.76,.51,.44),(.23,.22,.195),0)
        arm.shell((s*.78,.295,.50),(.24,.195,.225),1)
        for j in range(4):
            x=s*(.61+j*.096)
            arm.limb([(x,.32,.52),(x,.205,.61),(x,.115,.56)],[.066,.078,.043],2,9)
        rib=Joint('Chest'+side if boss else ('Bell_'+side if bell else 'Pectoral'+side),(s*.36,1.34,.27),root)
        for j in range(3):
            rib.shell((s*(.252-.024*j),1.36-.104*j,.35-.015*j),(.205,.103,.11),2 if bell or boss else 1,11,5,tilt=s*.084)
        if bell or boss:
            for j in range(3):
                x=s*(.33+j*.068)
                rib.limb([(x,1.54,.13),(x+s*.095,1.22,.31),(x+s*.14,.90-j*.10,.26)],[.050,.071,.022],2)
    # Laminar vertebrae and a chain of damaged plates down the neck.
    for j in range(5):
        root.shell((0,1.495+j*.051,-.32+j*.102),(.086,.071,.10),2,11,5,lean=.031)
    if boss:
        # A broken pronged crown silhouettes the guardian on the distant ridge.
        for s in [-1,1]:
            for j in range(4):
                x=s*(.27+.095*j)
                root.limb([(x,1.45,-.16),(x+s*.055,1.70,-.22),(x+s*.12,1.86-j*.064,-.28)],
                          [.10,.074,.006],2 if j%2==0 else 1,9)
            for j in range(3):
                root.limb([(s*.055,1.10+j*.11,.415),(s*.13,1.16+j*.11,.435),(s*.19,1.16+j*.10,.39)],
                          [.012,.019,.009],4,7)
    if boss:
        # A shattered crescent hangs off one shoulder, open above the sternum.
        # The second short stump makes the missing arc clear in silhouette.
        rack=[(-.52,1.49,-.09),(-.81,1.56,-.14),(-.99,1.81,-.15),
              (-1.01,2.04,-.12),(-.89,2.24,-.08),(-.69,2.33,-.04),(-.57,2.32,-.015)]
        root.limb(rack,[.129,.128,.108,.095,.081,.059,.009],1,8)
        inner=[(x+.037,y-.018,z+.067) for x,y,z in rack]
        root.limb(inner,[.046,.048,.041,.032,.024,.016,.003],2,7)
        for j in [1,2,3,4]:
            x,y,z=rack[j]
            root.limb([(x-.052,y-.027,z+.06),(x-.011,y+.008,z+.086),
                       (x+.029,y+.032,z+.061)], [.002,.014,.003],5,7)
        root.limb([(.48,1.49,-.15),(.67,1.63,-.15),(.71,1.76,-.16)],
                  [.103,.072,.043],2,7)
    if bell:
        # Flared bell-skirt hanging in overlapping oxidized lames.
        for j in range(12):
            a=TAU*j/12
            top=(.34*cos(a),1.15,-.03+.28*sin(a))
            lip=(.59*cos(a),.75,-.03+.49*sin(a))
            root.limb([top,lip,(lip[0],.715,lip[2])],[(.07,.10),(.075,.13),(.037,.124)],2 if j%3==0 else 1,8)
    root.shell((0,1.27,.419),(.15,.239,.067),4)
    head=Joint('HeadPivot',(0,1.51,.24),root)
    head.shell((0,1.505,.405),(.225,.213,.212),3)
    head.shell((0,1.634,.40),(.238,.138,.22),1,14,7,lean=-.052)
    for s in [-1,1]:
        head.shell((s*.078,1.516,.601),(.068,.021,.028),4,9,5,tilt=-s*.026)
        head.shell((s*.163,1.46,.48),(.074,.14,.09),1,10,6)
        if boss or bell:
            head.limb([(s*.16,1.68,.35),(s*.27,1.87,.25),(s*.36,1.98,.30),(s*.37,2.04,.40)],[.072,.055,.034,.002],2,10)
    if boss:
        root.obj.scale=(1.52,1.52,1.43)
    if bell:
        root.obj.scale=(.80,.80,1.04)


def ram():
    root=Joint('Withers')
    root.shell((0,.77,-.05),(.34,.36,.66),3,14,8)
    for j in range(5):
        z=-.51+j*.22
        root.shell((0,.83+.038*j,z),(.33+.018*j,.28,.24),j%2,n=14,rows=7,lean=.056)
    for side,s in [('L',-1),('R',1)]:
        for j in range(2):
            z=-.40+j*.77; hip=(s*.24,.79,z)
            leg=Joint('Hip_'+side+str(j),hip,root)
            knee=(s*.31,.43,z+.09)
            ankle=(s*.32,.14,z-.05)
            leg.limb([hip,knee,ankle],[.13,.096,.065],3,10)
            leg.shell((s*.28,.60,z+.045),(.127,.22,.15),1)
            leg.shell(knee,(.11,.123,.12),2,10,5)
            leg.shell((s*.32,.085,z),(.108,.081,.135),0)
    head=Joint('HeadPivot',(0,.96,.43),root)
    head.shell((0,.97,.63),(.30,.26,.225),1)
    head.shell((0,.81,.80),(.168,.155,.22),0)
    for s in [-1,1]:
        head.shell((s*.212,.965,.792),(.047,.029,.042),4)
        points=[(s*.20,1.08,.61),(s*.37,1.21,.54),(s*.48,1.18,.39),(s*.52,1.02,.35),(s*.53,.926,.48),(s*.51,.996,.61)]
        head.limb(points,[.142,.123,.100,.084,.052,.004],2,14)
        for j in range(1,4):
            head.shell(points[j],(.095,.09,.085),1,10,5)


def glb_vertex_count(path):
    """Count the POSITION values the engine receives, including split UVs and normals."""
    with path.open("rb") as glb:
        glb.seek(12)
        length, tag = struct.unpack("<I4s", glb.read(8))
        if tag != b"JSON":
            raise ValueError(f"Expected a GLB JSON chunk in {path}")
        model = json.loads(glb.read(length))
    return sum(
        model["accessors"][primitive["attributes"]["POSITION"]]["count"]
        for mesh in model["meshes"] for primitive in mesh["primitives"]
    )


def export_assets(output, species_names):
    global JOINTS
    records = []
    for species in species_names:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        JOINTS = []
        materials = atlas(PALETTES[species], species == "vesper_colossus")
        if species in ("brute_static", "vesper_colossus", "bell_warden"):
            hulking(species)
        elif species == "quarry_ram":
            ram()
        else:
            arthropod(species)
        for joint in JOINTS:
            joint.finish(materials)
        path = output / (species + ".glb")
        bpy.ops.export_scene.gltf(
            filepath=str(path), export_format="GLB", export_animations=False,
            export_cameras=False, export_lights=False,
        )
        records.append({"file": path.name, "static": False, "rigged": True,
                        "rig": "articulated node pivots", "skinned": False, "baked_clips": False,
                        "vertices": glb_vertex_count(path),
                        "generator": "scripts/hero/build_bestiary.py"})
    return records


def update_manifest(output, records):
    path = output / "models_manifest.json"
    manifest = {"generator": "build_blender_assets.py", "units": "meters",
                "up_axis_in_glb": "Y", "assets": []}
    if path.exists():
        manifest = json.loads(path.read_text())
    by_filename = {entry["file"]: entry for entry in manifest["assets"]}
    by_filename.update({entry["file"]: entry for entry in records})
    manifest["assets"] = list(by_filename.values())
    path.write_text(json.dumps(manifest, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEST)
    parser.add_argument("species", nargs="*", metavar="SPECIES")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    names = args.species or list(PALETTES)
    for name in names:
        if name not in PALETTES:
            parser.error(f"Unknown creature {name!r}. Choose from {', '.join(PALETTES)}.")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    update_manifest(output, export_assets(output, names))


if __name__ == "__main__":
    main()
