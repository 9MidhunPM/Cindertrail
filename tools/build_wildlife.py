"""Bake Cindertrail's eight original, articulated animals to metre-scale vertex-painted glTF."""
import json
import math
from pathlib import Path
import struct

import numpy as np

OUT = Path(__file__).resolve().parents[1] / "art/wildlife"
UP = np.array([0., 1., 0.])
DARK = "232e39"
CREAM = "e4cf9f"
SLATE = "435d63"
OCHRE = "bf7850"


def unit(v):
    return v / max(np.linalg.norm(v), 1e-9)


def paint(hex_color):
    srgb = np.array(bytes.fromhex(hex_color) and list(bytes.fromhex(hex_color))) / 255.
    return np.where(srgb < .04045, srgb / 12.92, ((srgb + .055) / 1.055) ** 2.4)


class Part:
    def __init__(self, name, origin=(0, 0, 0)):
        self.name = name
        self.origin = origin
        self.vertices, self.normals, self.colors = [], [], []

    def tri(self, a, b, c, color, outside):
        a, b, c = map(np.asarray, (a, b, c))
        normal = np.cross(b-a, c-a)
        if np.dot(normal, outside) < 0:
            b, c = c, b
            normal = -normal
        if np.linalg.norm(normal) < 1e-10:
            return
        normal = unit(normal)
        dye = paint(color) * (1 + .032*math.sin(len(self.vertices)*1.618))
        for p in (a, b, c):
            self.vertices.append(p)
            self.normals.append(normal)
            self.colors.append(np.clip(dye, 0, 1))

    def body(self, sections, color, belly=None, sides=12):
        """Cross contours (axial z, centre y, width, depth, centre x)."""
        rings = []
        for z, y, w, h, *x in sections:
            rings.append([np.array([(x[0] if x else 0) + w*math.cos(a),
                                     y+h*math.sin(a), z]) for a in np.arange(sides)*math.tau/sides])
        for idx, (left, right) in enumerate(zip(rings, rings[1:])):
            for i in range(sides):
                j = (i+1) % sides
                a,b,c,d = left[i],left[j],right[j],right[i]
                axis = (a+b+c+d)/4 - (np.mean(left,axis=0)+np.mean(right,axis=0))/2
                dye = belly if belly and axis[1] < -.20*max(sections[idx][3],.001) else color
                self.tri(a,b,c,dye,axis)
                self.tri(a,c,d,dye,axis)
        for ring, direction in [(rings[0],-1),(rings[-1],1)]:
            for i in range(sides):
                self.tri(np.mean(ring,axis=0),ring[i],ring[(i+1)%sides],color,(0,0,direction))

    def oval(self, xyz, radius, color, sides=10):
        x,y,z = xyz
        w,h,l = radius
        self.body([(z+l*math.sin(a),y,w*math.cos(a),h*math.cos(a),x)
                   for a in np.linspace(-1.57,1.57,7)],color,sides=sides)

    def taper(self, points, color, sides=7):
        rings = []
        for i,(x,y,z,radius) in enumerate(points):
            centre = np.array([x,y,z])
            axis = unit(np.array(points[min(len(points)-1,i+1)][:3]) -
                        np.array(points[max(0,i-1)][:3]))
            tangent = unit(np.cross(axis, UP if abs(axis[1]) < .85 else (1,0,0)))
            bitangent = np.cross(axis, tangent)
            rings.append([centre+radius*(math.cos(a)*tangent+math.sin(a)*bitangent)
                          for a in np.arange(sides)*math.tau/sides])
        for start,end in zip(rings,rings[1:]):
            center = (np.mean(start,axis=0)+np.mean(end,axis=0))*.5
            for i in range(sides):
                j=(i+1)%sides
                a,b,c,d=start[i],start[j],end[j],end[i]
                self.tri(a,b,c,color,a-center)
                self.tri(a,c,d,color,c-center)

    def blade(self, root, tip, width, color, side=(0,0,1)):
        """Faceted feather, pinna, or fin with a folded ridge."""
        a,b = np.array(root),np.array(tip)
        span = unit(np.array(side,dtype=float))
        normal = unit(np.cross(b-a,span))
        middle=a*.57+b*.43
        rim=[a,middle+span*width,b,middle-span*width]
        for i in range(4):
            self.tri(middle+normal*width*.22,rim[i],rim[(i+1)%4],color,normal)
            self.tri(middle-normal*width*.20,rim[i],rim[(i+1)%4],color,-normal)


def eyes(part, width, y, z, size):
    for sign in (-1,1):
        part.oval((sign*width,y,z),(size*.62,size,size*.88),DARK,8)
        part.oval((sign*(width+size*.43),y+size*.25,z-size*.32),(size*.19,)*3,CREAM,6)


def hoofed(goat):
    coat, belly = ("b89971","ded5b5") if goat else ("a85e36","d8ad78")
    body=Part("Body")
    body.body([(-.61,.90,.09,.15),(-.45,.87,.27,.34),(-.16,.88,.32,.34),
               (.20,.90,.28,.28),(.49,.89,.29,.32),(.62,.89,.11,.16)],coat,belly)
    if not goat:
        for side in [-1,1]:
            for i in range(9):
                z=-.15+i*.073
                y=.98+.055*math.sin(i*2.2)
                body.oval((side*(.292-.04*abs(z)),y,z),(.022,.033,.045),CREAM,7)
    head=Part("Head",(0,1.03,-.40))
    head.body([(-.55,.34,.072,.07),(-.43,.37,.13,.105),(-.28,.41,.16,.17),
               (-.16,.34,.15,.16),(-.06,.15,.16,.20),(.09,-.04,.14,.13)],coat,belly)
    head.oval((0,.36,-.54),(.080,.060,.047),DARK)
    eyes(head,.141,.445,-.32,.028)
    for s in [-1,1]:
        head.blade((s*.09,.46,-.23),(s*.34,.58,-.12),.072,coat,(0,1,0))
        head.blade((s*.15,.49,-.244),(s*.30,.564,-.156),.039,"8e6657",(0,1,0))
        if goat:
            head.taper([(s*.087,.50,-.24,.056),(s*.11,.68,-.19,.044),
                        (s*.15,.78,-.07,.028),(s*.18,.73,.02,.004)],"655344")
        else:
            head.taper([(s*.075,.53,-.21,.025),(s*.12,.67,-.12,.020),
                        (s*.17,.78,-.04,.013),(s*.24,.82,-.05,.002)],"cab18c")
            head.taper([(s*.13,.69,-.11,.015),(s*.11,.76,-.19,.003)],"cab18c")
    if goat:
        head.blade((0,.26,-.36),(0,.08,-.32),.068,belly,(1,0,0))
    tail=Part("Tail",(0,.99,.48))
    tail.body([(0,0,.06,.06),(.14,.06,.072,.087),(.23,.13,.025,.022)],belly)
    legs=[]
    for i in range(4):
        hind=i>=2
        leg=Part("Leg%d"%i,((.19 if i%2 else -.19),.79,.40 if hind else -.36))
        knee=.081 if hind else -.032
        leg.taper([(0,0,0,.092),(0,-.27,knee-.05,.066),(0,-.46,knee+.025,.048),
                   (0,-.73,-.012,.026)],coat)
        leg.oval((0,-.74,-.037),(.042,.047,.068),DARK,8)
        legs.append(leg)
    return [body,head,tail,*legs]


def small_mammal(otter):
    coat,belly=("815138","cea475") if otter else ("bd8558","dcc5a0")
    body=Part("Body")
    if otter:
        body.body([(-.42,.24,.09,.10),(-.26,.23,.18,.14),(.03,.22,.205,.15),
                   (.34,.205,.18,.13),(.48,.21,.09,.085)],coat,belly)
    else:
        body.body([(-.20,.20,.075,.08),(-.12,.20,.14,.16),(.06,.20,.185,.20),
                   (.17,.17,.15,.15),(.24,.16,.06,.09)],coat,belly)
    head=Part("Head",(0,.25,-.34) if otter else (0,.24,-.16))
    head.body([(-.245,.045,.060,.052),(-.175,.06,.134,.094),(-.09,.082,.148,.121),
               (.02,.072,.12,.095),(.08,.045,.065,.060)],coat,belly)
    head.oval((0,.078,-.234),(.040,.029,.026),DARK)
    eyes(head,.122,.109,-.158,.023)
    for s in [-1,1]:
        head.oval((s*.104,.156,-.030),(.053,.038 if otter else .095,.038),coat)
        head.oval((s*.108,.168,-.053),(.032,.021 if otter else .054,.022),"876851")
        for k in range(3):
            head.taper([(s*.083,.041+k*.014,-.193,.004),(s*(.21-k*.014),.041+k*.028,-.212,.0015)],CREAM,4)
    tail=Part("Tail",(0,.19,.39 if otter else .18))
    if otter:
        tail.body([(-.01,0,.095,.075),(.14,-.008,.079,.060),(.33,-.037,.056,.045),
                   (.52,-.065,.023,.021),(.60,-.080,.004,.004)],coat)
    else:
        tail.oval((0,.025,.046),(.052,.053,.065),belly)
    legs=[]
    for i in range(4):
        leg=Part("Leg%d"%i,((.12 if i%2 else -.12),.145,(.28 if i>=2 else -.20) if otter else (.14 if i>=2 else -.09)))
        leg.oval((0,-.059,.006),(.043,.064,.049),coat)
        leg.oval((0,-.118,-.023),(.052,.026,.079),belly)
        legs.append(leg)
    return [body,head,tail,*legs]


def fish():
    body=Part("Body")
    body.body([(-.27,0,.014,.030),(-.19,.008,.066,.089),(-.065,.016,.089,.119),
               (.092,0,.066,.093),(.205,-.006,.024,.035)],"51918d","ded6a1")
    for s in [-1,1]:
        for i in range(4):
            z=-.105+i*.071
            body.oval((s*(.082-i*.006),.018,z),(.005,.018,.034),"cd9e58",6)
        body.blade((s*.066,-.010,-.088),(s*.165,-.063,-.002),.031,"c49464")
    body.blade((0,.091,-.065),(0,.18,.048),.07,"926c4e")
    eyes(body,.063,.036,-.188,.016)
    tail=Part("Tail",(0,0,.189))
    for s in [-1,1]:
        tail.blade((0,0,0),(0,s*.105,.145),.055,"bb825c")
    return [body,tail]


def frog():
    moss,belly="688b53","b8b877"
    body=Part("Body")
    body.body([(-.095,.095,.09,.057),(-.025,.094,.106,.078),(.095,.07,.105,.063),
               (.17,.065,.052,.039)],moss,belly)
    for s in [-1,1]:
        for i in range(3):
            body.oval((s*.045,.163-i*.01,.018+i*.035),(.018,.012,.019),"918c4b")
    head=Part("Head",(0,.082,-.07))
    head.body([(-.120,.015,.060,.028),(-.077,.03,.108,.055),
               (.005,.045,.112,.064),(.07,.023,.068,.035)],moss,belly)
    for s in [-1,1]:
        head.oval((s*.074,.084,-.038),(.041,.041,.044),"b4a564")
    eyes(head,.092,.091,-.059,.023)
    legs=[]
    for i in range(4):
        s=1 if i%2 else -1
        leg=Part("Leg%d"%i,(s*.078,.078,.078 if i>=2 else -.064))
        leg.taper([(0,0,0,.039),(s*.065,-.031,.082,.032),(s*.082,-.058,-.022,.021)],moss)
        for j in range(3):
            leg.taper([(s*.082,-.058,-.022,.012),(s*(.115+j*.01),-.063,-.055+j*.017,.002)],belly)
        legs.append(leg)
    return [body,head,*legs]


def bird(owl):
    upper,lower=("8a7765","cfb697") if owl else ("875f45","d0a56e")
    body=Part("Body")
    if owl:
        body.body([(-.13,.28,.09,.14),(-.05,.27,.19,.23),(.10,.26,.18,.21),
                   (.23,.16,.105,.102)],upper,lower)
    else:
        body.body([(-.32,.04,.04,.045),(-.19,.039,.105,.106),(.01,.01,.125,.101),
                   (.19,-.01,.068,.060),(.26,-.016,.037,.026)],upper,lower)
    head=Part("Head",(0,.44,-.085) if owl else (0,.060,-.22))
    head.oval((0,0,0),(.175,.15,.138) if owl else (.094,.085,.125),upper)
    if owl:
        for s in [-1,1]:
            head.oval((s*.068,.012,-.103),(.076,.094,.046),lower)
            head.oval((s*.065,.028,-.142),(.038,.040,.020),"cba25e")
            head.oval((s*.065,.028,-.159),(.018,.025,.013),DARK)
            head.blade((s*.105,.097,.02),(s*.138,.178,.055),.039,upper,(1,0,0))
        for s in [-1,1]:
            body.taper([(s*.077,.11,-.04,.019),(s*.077,.035,-.07,.015),(s*.077,.025,-.12,.005)],OCHRE)
    else:
        eyes(head,.071,.020,-.050,.017)
    head.taper([(0,-.007,-.12,.028),(0,-.022,-.17,.017),(0,-.046,-.174,.002)],"aa8252")
    tail=Part("Tail",(0,.12,.17) if owl else (0,-.014,.20))
    length=.23 if owl else .40
    for i in range(-3,4):
        tail.blade((i*.014,0,0),(i*.041,-.060,length+abs(i)*.024),
                   .038,upper if i%2 else DARK,(1,0,0))
    wings=[]
    reach=.68 if owl else .92
    for s in [-1,1]:
        wing=Part("WingL" if s<0 else "WingR",(s*.09,.32,.00) if owl else (s*.08,.055,.003))
        wing.body([(-.12,.013,.11,.028,s*.14),(-.052,.024,.22,.050,s*.23),
                   (.053,.012,.23,.048,s*.25),(.155,-.015,.13,.025,s*.18)],upper,lower)
        for k in range(8):
            u=k/7.
            tip=(s*reach*(1.-.56*u),-.05+u*.025,-.09+.44*u)
            root=(s*(.31-.14*u),.025,-.081+.19*u)
            wing.blade(root,tip,.051 if owl else .063,upper if k in [2,3,5] else SLATE)
            cover=(s*abs(tip[0])*.75,.028,tip[2]*.76)
            wing.blade(root,cover,.043,lower if k in [1,4,6] else upper)
        wings.append(wing)
    return [body,head,tail,*wings]


def export(name, parts):
    document={"asset":{"version":"2.0","generator":"Cindertrail wildlife painter"},
              "scene":0,"scenes":[{"nodes":[0]}],"nodes":[{"name":name,"children":[]}],
              "meshes":[],"bufferViews":[],"accessors":[],"materials":[
                  {"name":"Painted feathers, hide and scales","pbrMetallicRoughness":
                   {"metallicFactor":0,"roughnessFactor":.83}}]}
    binary=bytearray()
    def floats(rows, bounds=False):
        data=np.asarray(rows,dtype="<f4")
        view=len(document["bufferViews"])
        document["bufferViews"].append({"buffer":0,"byteOffset":len(binary),"byteLength":data.nbytes,"target":34962})
        binary.extend(data.tobytes())
        access={"bufferView":view,"componentType":5126,"count":len(data),"type":"VEC3"}
        if bounds:
            access.update(min=data.min(0).tolist(),max=data.max(0).tolist())
        document["accessors"].append(access)
        return len(document["accessors"])-1
    for part in parts:
        attrs={"POSITION":floats(part.vertices,True),"NORMAL":floats(part.normals),"COLOR_0":floats(part.colors)}
        document["nodes"][0]["children"].append(len(document["nodes"]))
        document["nodes"].append({"name":part.name,"mesh":len(document["meshes"]),"translation":part.origin})
        document["meshes"].append({"name":part.name,"primitives":[{"attributes":attrs,"material":0}]})
    document["buffers"]=[{"byteLength":len(binary)}]
    header=json.dumps(document,separators=(",",":")).encode()
    header+=b" "*((-len(header))%4)
    with (OUT/(name+".glb")).open("wb") as stream:
        stream.write(struct.pack("<4sII",b"glTF",2,28+len(header)+len(binary)))
        stream.write(struct.pack("<I4s",len(header),b"JSON")+header)
        stream.write(struct.pack("<I4s",len(binary),b"BIN\0")+binary)


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    for species,parts in {"fish":fish(),"frog":frog(),"pika":small_mammal(False),
                          "goat":hoofed(True),"deer":hoofed(False),"otter":small_mammal(True),
                          "kite":bird(False),"owl":bird(True)}.items():
        export(species,parts)
