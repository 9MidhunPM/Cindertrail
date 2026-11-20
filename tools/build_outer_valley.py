#!/usr/bin/env python3
"""Bake the authored outer valley into spatially culled, flat-shaded glTF chunks.

Run from any directory with Python and NumPy. Godot imports -col terrain into
static physics alongside its visible mesh. The route graph, encounters and
winch bridges share their dimensions with the GDScript loader.
"""
from __future__ import annotations

import json
import math
import random
import struct
from collections import defaultdict
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data/outer_valley"
TRAILS = json.loads((DATA / "trails.json").read_text())
MARKS = json.loads((DATA / "landmarks.json").read_text())
NODES = {k: np.array(v, float) for k, v in TRAILS["nodes"].items()}
ROADS = {name: np.array([NODES[a], *pts, NODES[b]]) for name, a, pts, b in TRAILS["trails"]}
SITES = [NODES[s["node"]] for s in MARKS["sites"]]
rng = random.Random(346701)
UP = np.array([0., 1., 0.])
X = np.array([1., 0., 0.])
Z = np.array([0., 0., 1.])
START = np.concatenate([p[:-1] for p in ROADS.values()])
END = np.concatenate([p[1:] for p in ROADS.values()])
SEG = END - START
L2 = np.sum(SEG[:, [0, 2]] ** 2, axis=1)
GATES = []
for desc in MARKS["gates"]:
    a, b = ROADS[desc["trail"]][desc["section"]:desc["section"] + 2]
    forward = (b - a).copy()
    forward[1] = 0
    forward /= np.linalg.norm(forward)
    GATES.append(((a+b)*.5, forward, np.cross(UP, forward)))
STONE = ["#d8c39c", "#c0af92", "#b4a387", "#d3be99", "#bda98c"]
ROOTS = "#594f43"
TEAL = ["#1d625a", "#2b7664", "#397e6a", "#275e5b"]
COPPER = ["#b05d2d", "#d17e32", "#be632b", "#df9139"]
BRASS = "#ab8153"

def pal(rgb, gain=1.0):
    if isinstance(rgb, str):
        rgb = [int(rgb[i:i+2],16) / 255 for i in (1,3,5)]
    # glTF COLOR_0 is linear, including when compact integer attributes are used.
    v = np.clip(np.asarray(rgb) * gain,0,1)
    return np.where(v <= .04045,v/12.92,((v+.055)/1.055)**2.4)

def terrain_colors(vertices):
    """Continuous pigment at shared hill vertices keeps the cell lattice invisible."""
    x, y, z = vertices.T
    chunksize=1000
    ds=[]
    for i in range(0,len(x),chunksize):
        ds.append(surface(x[i:i+chunksize],z[i:i+chunksize])[1])
    d=np.concatenate(ds)
    moss=(np.sin(x*.092+z*.074)+np.cos(z*.101-x*.048)+2)*.25
    soil=pal("#305653")*(1-moss[:,None])+pal("#637554")*moss[:,None]
    for origin, low, high in zip(SITES, ["#203c3f","#426761","#3e4859"],
                                 ["#4c6547","#627e68","#6e7882"]):
        weight=(1-np.clip(np.hypot(x-origin[0],z-origin[2])/54,0,1))[:,None]
        local=pal(low)*(1-moss[:,None])+pal(high)*moss[:,None]
        soil=soil*(1-weight)+local*weight
    # An earth verge drifts into the moss in either direction from the flags.
    wear=(1-np.clip((d-1.3)/3.6,0,1))**1.55
    return soil*(1-wear[:,None])+pal("#a59477")*wear[:,None]

def surface(x, z):
    """Piecewise-authored trail beds feather into a folded plateau between them."""
    px, pz = np.broadcast_arrays(x, z)
    sx = px[...,None] - START[:,0]
    sz = pz[...,None] - START[:,2]
    t = np.clip((sx*SEG[:,0] + sz*SEG[:,2])/L2,0,1)
    dsq = (sx - t*SEG[:,0])**2 + (sz - t*SEG[:,2])**2
    idx = np.argmin(dsq, axis=-1)
    d = np.sqrt(np.take_along_axis(dsq,idx[...,None],axis=-1)[...,0])
    yy = START[:,1] + t*SEG[:,1]
    bed = np.take_along_axis(yy,idx[...,None],axis=-1)[...,0]
    weights = 1/(dsq+14)**1.65
    blend = np.clip((d-4)/10,0,1)
    blend = blend*blend*(3-2*blend)
    y = ((1-blend)*bed + blend*np.sum(weights*yy,axis=-1)/np.sum(weights,axis=-1))
    folds = np.sin(px*.075+np.cos(pz*.044))*2.4 + np.cos(pz*.064-px*.025)*2.3
    folds += np.sin(px*.191+pz*.071)*.65+np.cos(pz*.159-px*.082)*.75
    y += blend*(folds - np.maximum(0,d-13)*.17)
    for s in SITES:
        r = np.hypot(px-s[0],pz-s[2])
        f = np.clip((r-18)/8,0,1)
        y = y*f + s[1]*(1-f)
    # A flooded sluice basin sits beneath two raised limestone routes.
    sx,pz0 = px-SITES[1][0], pz-SITES[1][2]
    bowl = np.clip(1-((sx+4)/12)**4-((pz0+4)/13)**4,0,1)
    # Recessed water gardens sit between the causeways. Their approach beds
    # meet the fan pavement continuously in both directions.
    apron = np.clip((np.hypot(sx,pz0)-7.8)/1.6,0,1)
    dry = np.minimum(d, np.minimum(np.where(sx<0, abs(pz0), 100.),
                                   np.where(pz0<0, abs(sx-2.),100.)))
    y -= 1.65*bowl*apron*np.clip((dry-2.)/1.35,0,1)
    for c,axis,side in GATES:
        dx,dz = px-c[0],pz-c[2]
        u,v = abs(dx*axis[0]+dz*axis[2]),abs(dx*side[0]+dz*side[2])
        y -= 4.2*np.clip((4.2-u)/2.5,0,1)*np.clip((14.-v)/3.,0,1)
    for s in SITES:
        r = np.hypot(px-s[0],pz-s[2])
        y += .08*np.clip((12.-r)/3.,0,1)
    return y-.09, d

# Chunks limit overdraw, shadow cost and physics broadphase bounds.
chunks = defaultdict(lambda: [[], []])

def triangle(a,b,c,color,group="Detail",out=None):
    a,b,c = np.asarray(a),np.asarray(b),np.asarray(c)
    if out is not None and np.dot(np.cross(b-a,c-a),out) < 0:
        b,c = c,b
    key = (math.floor(a[0]/36), math.floor(a[2]/36),group)
    chunks[key][0].extend((a,b,c))
    chunks[key][1].append(color)

def panel(a,b,c,d,color,group="Detail",out=None):
    triangle(a,b,c,color,group,out)
    triangle(a,c,d,color,group,out)

def block(a, half, shade, axes=(X,UP,Z), group="Masonry"):
    """A weathered structural course in arbitrary orientation."""
    a = np.asarray(a)
    dx,dy,dz = (axes[i]*half[i] for i in range(3))
    for n,u,v in [(dx,dy,dz),(-dx,dy,dz),(dy,dx,dz),(-dy,dx,dz),(dz,dx,dy),(-dz,dx,dy)]:
        face = a+n
        panel(face-u-v,face+u-v,face+u+v,face-u+v,shade,group,n)

def beam(a,b,r1,r2,shade,sides=7,group="Detail"):
    a,b = np.asarray(a),np.asarray(b)
    axis=b-a
    unit=axis/np.linalg.norm(axis)
    side = np.cross(unit,UP if abs(unit[1])<.94 else X)
    side/=np.linalg.norm(side)
    other=np.cross(unit,side)
    circle=[math.cos(i*math.tau/sides)*side+math.sin(i*math.tau/sides)*other for i in range(sides)]
    for i,n in enumerate(circle):
        nn=circle[(i+1)%sides]
        panel(a+n*r1,a+nn*r1,b+nn*r2,b+n*r2,shade,group,n+nn)
        triangle(b,b+nn*r2,b+n*r2,shade,group,axis)

def ellipsoid(c,r,color,n=7,group="Detail"):
    """Two uneven rings plus offset crown give a broad, broken silhouette."""
    phase = rng.random()*math.tau
    upper=[]; lower=[]
    for i in range(n):
        ang=i*math.tau/n+phase
        reach=rng.uniform(.84,1.12)
        v=np.array([math.cos(ang)*r[0],0,math.sin(ang)*r[2]])*reach
        upper.append(c+v+UP*r[1]*rng.uniform(.03,.27))
        lower.append(c+v*.80-UP*r[1]*rng.uniform(.32,.64))
    top=c+UP*r[1]*.95+X*r[0]*.14
    base=c-UP*r[1]*.83
    for i in range(n):
        j=(i+1)%n
        shade=pal(color,rng.uniform(.90,1.12))
        triangle(upper[i],upper[j],top,shade,group,UP)
        panel(lower[i],lower[j],upper[j],upper[i],pal(color,rng.uniform(.76,.95)),group,upper[i]-c)
        triangle(lower[i],lower[j],base,pal(color,.72),group,-UP)

def tree(origin,scale,autumn):
    phase=rng.uniform(0,math.tau)
    twig=origin + np.array([math.cos(phase)*.5,2.9,math.sin(phase)*.5])*scale
    beam(origin,twig,.38*scale,.20*scale,pal(ROOTS),7,"Trunks")
    leaves=COPPER if autumn else TEAL
    for i in range(4):
        ang=phase+i*math.tau/3+rng.uniform(-.27,.27)
        sway=rng.uniform(1.1,2.05) if i<3 else .20
        tip=twig+np.array([math.cos(ang)*sway,1.75+i*.24,math.sin(ang)*sway])*scale
        beam(twig-UP*.55*scale,tip,.18*scale,.085*scale,pal(ROOTS,1.08),5)
        ellipsoid(tip,np.array([1.68,.86,1.54])*scale,rng.choice(leaves),8)
        # Broad, staggered leaf shelves fracture the outline along the fork.
        v=np.array([math.cos(ang+.52),0,math.sin(ang+.52)])
        ellipsoid(tip+v*.95*scale+UP*.25*scale,np.array([1.12,.53,1.16])*scale,rng.choice(leaves),7)
        if i%2==0:
            ellipsoid(tip-v*.66*scale+UP*.68*scale,np.array([1.12,.58,1.03])*scale,rng.choice(leaves),7)

def arch(center,axis,span,rise,depth):
    """Segmental barrel arch with projecting imposts and a deeper keystone."""
    axis=np.asarray(axis)
    side=np.cross(UP,axis)
    seat=rise-span*.5
    for sign in (-1,1):
        foot=center+axis*sign*(span*.5+.36)
        rows=max(2,math.ceil(seat/.83))
        for j in range(rows):
            h=seat/rows
            block(foot+UP*(j+.5)*h,(.39,h*.488,depth*.5),pal(rng.choice(STONE)),(axis,UP,side))
        block(foot+UP*seat,(.56,.14,depth*.62),pal(STONE[0]),(axis,UP,side))
    for i in range(13):
        a,b=i*math.pi/13+.006,(i+1)*math.pi/13-.006
        t=span*.5
        outer=t+.71+(.19 if i==6 else 0)
        raw=[center+UP*seat+radius*(axis*math.cos(ang)+UP*math.sin(ang)) for radius,ang in [(t,a),(outer,a),(outer,b),(t,b)]]
        z=side*depth*(.55 if i==6 else .50)
        col=pal(rng.choice(STONE))
        panel(*(p+z for p in raw),col,"Masonry",out=side)
        panel(*(p-z for p in raw),col,"Masonry",out=-side)
        for j in range(4):
            k=(j+1)%4
            n=(raw[j]+raw[k])*.5-sum(raw)*.25
            panel(raw[j]+z,raw[k]+z,raw[k]-z,raw[j]-z,col,"Masonry",out=n)

def lantern(p,scale=1):
    beam(p,p+UP*1.65*scale,.13*scale,.09*scale,pal(BRASS),6)
    block(p+UP*1.76*scale,(.22*scale,.10*scale,.22*scale),pal(ROOTS))
    block(p+UP*2.02*scale,(.15*scale,.20*scale,.15*scale),pal("#ffbe66"),group="Lantern")
    block(p+UP*2.26*scale,(.25*scale,.065*scale,.25*scale),pal(BRASS))

def terrain():
    step=3.
    xs,zs=np.meshgrid(np.arange(-204,220,step),np.arange(-109,246,step))
    y,d=surface(xs,zs)
    y=np.round(y,2)
    p=np.stack((xs,y,zs),axis=-1)
    filled=set()
    for k in range(len(zs)-1):
        for j in range(xs.shape[1]-1):
            x,z=xs[k,j]+step*.5,zs[k,j]+step*.5
            # Preserve the three original districts, exposing only the joining exit beds.
            if z<27.5 and x>-25 and x<27 and z<24.5: continue
            if z<25 and x<26 and x>-27 and (z<22.3 or abs(x+1)>6.):continue
            if x<=-27 and z<9 and (abs(x+36)>4 or z<5.5):continue
            if x>25 and x<43 and z<-24 and (abs(z+51.4)>7 and x<34):continue
            if d[k,j]>43:continue
            filled.add((k,j))
            pts=[p[k,j],p[k,j+1],p[k+1,j+1],p[k+1,j]]
            grass = (math.sin(x*.088+z*.105)+math.cos(z*.066))*.5
            tone = "#526b55" if grass>.3 else ("#68745c" if grass>-.44 else "#727563")
            if d[k,j]<3.0:tone="#aa9678"
            elif d[k,j]<6.5:tone="#84826b"
            panel(*pts,pal(tone,rng.uniform(.94,1.05)),"Ground",UP)

    for k,j in sorted(filled):
        ring=[p[k,j],p[k,j+1],p[k+1,j+1],p[k+1,j]]
        center=sum(ring)*.25
        # The original Grove, Relay and Quarry close these inner seams.
        if abs(center[0]) < 79 and center[2] < 29:continue
        for i,(kk,jj) in enumerate([(-1,0),(0,1),(1,0),(0,-1)]):
            if (k+kk,j+jj) in filled:continue
            a,b=ring[i],ring[(i+1)%4]
            out=(a+b)*.5-center;out/=np.linalg.norm(out)
            def lower(q,dist,drop):
                # Constant boundary points give neighboring slices common seams.
                f=.3*math.sin(q[0]*.121)+.5*math.cos(q[2]*.144)
                return q+out*(dist+f)-UP*drop
            a1,b1=lower(a,.65,1.7),lower(b,.65,1.7)
            a2,b2=lower(a,2.7,7.2),lower(b,2.7,7.2)
            a3,b3=lower(a,6.2,16.4),lower(b,6.2,16.4)
            panel(a,b,b1,a1,pal("#707b72"),"Detail",out)
            panel(a1,b1,b2,a2,pal("#596777"),"Detail",out)
            panel(a2,b2,b3,a3,pal("#44586b"),"Detail",out)

def roads():
    for name,points in ROADS.items():
        for i,(a,b) in enumerate(zip(points[:-1],points[1:])):
            v=b-a
            length=np.linalg.norm(v)
            axis=v/length
            side=np.cross(UP,axis);side/=np.linalg.norm(side)
            n=math.ceil(length/2.5)
            for j in range(n):
                mid=a+v*((j+.5)/n)
                if any(np.linalg.norm((mid-c)[[0,2]])<6 for c,_,_ in GATES):continue
                if any(np.linalg.norm((mid-s)[[0,2]])<10 for s in SITES):continue
                if name=="Grove causeway" and mid[2]<26.0:continue
                # Three broken paving bands with interlocking joints and narrow seams.
                for k in range(3):
                    if rng.random()<.14:continue
                    start,end = j/n,(j+1)/n
                    half=1.8+.24*math.sin(mid[0]*.18+mid[2]*.10)
                    off0=(k/3*2-1)*half+rng.uniform(.04,.15)
                    off1=((k+1)/3*2-1)*half-rng.uniform(.04,.15)
                    left=a+v*start;right=a+v*end
                    corners=[left+side*off0+axis*.04,left+side*off1+axis*.03,right+side*off1-axis*.08,right+side*off0-axis*.05]
                    for c in corners:
                        # Paving sits on the smoothed trail collision.
                        c[1]=float(surface(c[0],c[2])[0])+.045
                    panel(*corners,pal(rng.choice(STONE),rng.uniform(.79,.94)),"Detail",UP)
                if j%6==0:
                    foot=mid+side*rng.choice([-1,1])*rng.uniform(2.8,4.5)
                    foot[1]=surface(foot[0],foot[2])[0]
                    ellipsoid(foot,(.72,.48,.67),"#898470",6)
    # Shape the visible courts independently while keeping their surveyed bed elevations.
    for si,s in enumerate(SITES):
        if si < 2:
            size = 1.35 if si == 0 else 1.65
            for row in range(-5,6):
                for col in range(-5,6):
                    if si==0 and (abs(row)+abs(col)>7 or ((row+col)%5==0 and abs(row)+abs(col)>4)):
                        continue
                    if si==1 and (abs(row)>2 and abs(col)>2):
                        continue
                    x,z=col*size,row*size
                    p=s+np.array([x,.015,z])
                    corners=[p+np.array([dx*size*rng.uniform(.42,.47),0,dz*size*rng.uniform(.42,.47)])
                             for dx,dz in [(-1,-1),(1,-1),(1,1),(-1,1)]]
                    shades=["#716852","#87846c","#857954","#586554"] if si==0 else STONE
                    panel(*corners,pal(rng.choice(shades)),"Detail",UP)
            if si==1:
                for dx,dz in [(-11,0),(1,-9),(4,-12)]:
                    block(s+np.array([dx,-.20,dz]),(4.7,.19,2.05) if dx<0 else (2.65,.19,4.6),pal(STONE[2]),group="Deck")
            continue
        for ring in range(6):
            r0=ring*1.30+.02;r1=(ring+1)*1.30-.03
            count=7+ring*4; offset=(ring%2)*.45
            for i in range(count):
                if ring>3 and (i+si*3)%13==0:
                    continue
                aa,bb=(i+offset+.012)*math.tau/count,(i+offset+.985)*math.tau/count
                pts=[s+np.array([math.cos(a)*r,.015,math.sin(a)*r]) for a,r in [(aa,r0),(aa,r1),(bb,r1),(bb,r0)]]
                shade=rng.choice(["#243750","#374459","#3e5065","#49596f"])
                if ring in (1,4) and i%3==0:shade="#b08a60"
                panel(*pts,pal(shade,rng.uniform(.94,1.04)),"Detail",UP)

def vegetation():
    trees=[]
    for _ in range(1950):
        x,z=rng.uniform(-192,209),rng.uniform(-97,231)
        h,d=surface(x,z)
        if d<5.6 or d>35 or (z<27 and -72<x<36):continue
        if any(math.hypot(x-s[0],z-s[2])<19 for s in SITES):continue
        if any(math.hypot(x-a,z-b)<7.4 for a,b in trees):continue
        p=np.array([x,h,z]); trees.append((x,z))
        if rng.random()<.72:
            tree(p,rng.uniform(.73,1.65),rng.random()<(.32 if x<-45 else .13))
        else:
            ellipsoid(p,np.array([2.1,1.57,1.65])*rng.uniform(.9,1.75),"#737877",7)
    for name,points in ROADS.items():
        for a,b in zip(points[:-1],points[1:]):
            axis=(b-a)/np.linalg.norm(b-a);side=np.cross(UP,axis)
            for _ in range(math.ceil(np.linalg.norm(b-a)/3.)):
                mid=a+(b-a)*rng.random()+side*rng.choice([-1,1])*rng.uniform(2.5,5.2)
                if any(math.hypot(mid[0]-s[0],mid[2]-s[2])<8.7 for s in SITES):continue
                mid[1]=surface(mid[0],mid[2])[0]-.07
                for blade in range(10):
                    ang=rng.uniform(0,math.tau)
                    n=np.array([math.cos(ang),0,math.sin(ang)])
                    tangent=np.cross(UP,n)
                    base=mid+n*rng.uniform(0,.27)
                    tip=base+UP*rng.uniform(.23,.69)+n*rng.uniform(.08,.38)
                    shades=["#ba9a55","#b98b4c","#dfad61"]
                    if name in ("High orchard","Western arcade","Masons’ walk"):
                        shades=["#618255","#a69b52","#ab6e38"]
                    elif name in ("Pilgrim stair","Tanners’ road","Spice road"):
                        shades=["#3e8d73","#76a17a","#a4ab65"]
                    triangle(base-tangent*.057,base+tangent*.057,tip,pal(rng.choice(shades)),"Leaves",n)
                if rng.random()<.62:
                    fern(mid,.38+rng.random()*.9,rng.choice(["#527b56","#72924f","#b19450"]))
    # Denser grove flanks create a roof over paths without covering the tactical court.
    s=SITES[0]
    for i in range(15):
        angle=i*math.tau/15
        p=s+np.array([math.cos(angle)*rng.uniform(15,21),0,math.sin(angle)*rng.uniform(17,22)])
        h,d=surface(p[0],p[2])
        if d<3.9 or p[2]>s[2]+9:continue
        p[1]=h
        tree(p,rng.uniform(1.64,2.38),i%4==0)

def fern(base,scale,shade):
    """Alternating pointed pinnae make the leaf silhouette read from ground level."""
    for leaf in range(5):
        angle = leaf*math.tau/5+rng.uniform(-.22,.22)
        axis=X*math.cos(angle)+Z*math.sin(angle)
        side=np.cross(UP,axis)
        for i in range(1,6):
            t=i/6
            p=base+scale*(axis*t+UP*math.sin(t*2.2)*.63)
            next_point=base+scale*(axis*(t+.15)+UP*math.sin((t+.15)*2.2)*.63)
            width=scale*math.sin(math.pi*t)*.22
            for sign in (-1,1):
                tip=p+side*sign*width+axis*.09*scale
                triangle(p,tip,next_point,pal(shade,rng.uniform(.83,1.13)),"Leaves",UP)

def landmarks():
    wood,sluice,summit=SITES
    # Four grand trunks and splayed buttress roots frame the woodland canopy.
    for dx,dz,scale in [(-12,-11,2.8),(-2,-14,3.15),(11,-9,2.6),(14,2,2.16),(-12,10,1.98)]:
        p=wood+np.array([dx,-.12,dz])
        tree(p,scale,dx>10)
        for i in range(8):
            a=i*math.tau/8+rng.uniform(-.17,.17)
            axis=X*math.cos(a)+Z*math.sin(a)
            tip=p+axis*rng.uniform(2.2,4.7)
            mid=p+axis*1.6+UP*rng.uniform(.16,.39)
            beam(p+UP*rng.uniform(.42,.73),mid,.54,.23,pal(ROOTS),6)
            beam(mid,tip,.23,.03,pal(ROOTS,.9),6)
        for i in range(11):
            fern(p+X*rng.uniform(-2.5,2.5)+Z*rng.uniform(-2.5,2.5),rng.uniform(.75,1.45),rng.choice(TEAL))
    for dx,dz in [(-8,4),(-7,8),(5,-7),(7,2),(-2,-6)]:
        lantern(wood+X*dx+Z*dz,1.12)
    arch(wood+np.array([-14,0,1.5]),Z,5.,4.8,1.25)
    left=wood+X*-11+Z*-10+UP*5.8
    right=wood+X*10+Z*-8+UP*5.2
    for i in range(18):
        t= i/18
        u=(i+1)/18
        a=left*(1-t)+right*t-UP*math.sin(t*math.pi)*1.5
        b=left*(1-u)+right*u-UP*math.sin(u*math.pi)*1.5
        beam(a,b,.035,.035,pal(ROOTS),5)
        if i%3==1:
            beam(a,a-UP*.42,.030,.030,pal(BRASS),5)
            block(a-UP*.54,(.14,.19,.14),pal("#ffc277"),group="Lantern")
            block(a-UP*.75,(.21,.065,.21),pal(ROOTS))
    # The intact upper watercourse reads as one silhouette across five stacked bays.
    for i in range(5):
        p=sluice+np.array([(i-2)*7.7,0,-18.5])
        arch(p,X,6.94,6.05,2.)
        block(p+UP*6.95,(3.88,.22,1.22),pal(STONE[2]))
        for j in range(2):
            arch(p+X*(j-.5)*3.8+UP*7.1,X,3.05,3.65,1.38)
        block(p+UP*11.58,(3.85,.20,.90),pal(STONE[0]))
    # One outer bay has collapsed; the remnant retains three voussoirs.
    stump=sluice+np.array([22.,0.,-18.5])
    for i in range(7):
        block(stump+UP*(i+.5)*.62,(.75-i*.045,.305,.88),pal(rng.choice(STONE)))
    for i in range(14):
        p=stump+X*rng.uniform(-2,5)+Z*rng.uniform(-3,2)+UP*.30
        ellipsoid(p,(rng.uniform(.4,1.2),rng.uniform(.3,.76),rng.uniform(.45,.90)),"#a99a80")
    for i in range(13):
        x=rng.uniform(-16,18)
        p=sluice+X*x-Z*17.35+UP*rng.choice([6.96,11.65])
        for j in range(rng.randrange(3,7)):
            p=p-UP*.29+X*rng.uniform(-.18,.18)
            ellipsoid(p,(.26,.15,.19),rng.choice(TEAL),5)
    # Side towers hold the sluice doors and anchor the long, stepped channels.
    for dx,dz in [(-12,-7),(-6,-10),(6,-11),(10,-3),(-13,5)]:
        p=sluice+X*dx+Z*dz
        block(p+UP*.45,(.81,.45,.81),pal(STONE[3]))
        block(p+UP*1.55,(.62,.70,.64),pal(STONE[1]))
        block(p+UP*2.31,(.83,.12,.80),pal(STONE[0]))
    for start,end in [((-15,-5),(-5,-5)),((6.65,-13),(6.65,-4))]:
        a=sluice+X*start[0]+Z*start[1]
        b=sluice+X*end[0]+Z*end[1]
        axis=(b-a)/np.linalg.norm(b-a)
        side=np.cross(UP,axis)
        for i in range(8):
            p=a+(b-a)*i/8
            for sign in (-1,1):
                ledge=p+side*1.02*sign-UP*.48
                block(ledge,(.84,.28,.28),pal(rng.choice(STONE),.81),(axis,UP,side),"Detail")
                if i%2==0:
                    fern(ledge+UP*.3,1.02,rng.choice(TEAL))
        for i in range(3):
            point=a+axis*i*.84
            block(point-UP*(.14+i*.13),(1.12,.24,.48),pal(STONE[3]),(side,UP,axis),"Detail")
    # Astrolabe and sighting pylons: the rings surround an empty sightline.
    hub=summit+np.array([6,3.90,-10])
    for i in range(5):
        t=i*.46
        block(hub+UP*(-3.7+t),(2.35-t*.66,.24,1.95-t*.58),pal(STONE[i]))
    beam(hub-UP*1.65,hub,.31,.18,pal(BRASS),8)
    for tilt,radius in [(.0,2.65),(.88,2.37)]:
        direction=np.array([math.cos(tilt),0.,math.sin(tilt)])
        for i in range(28):
            a,b=i*math.tau/28,(i+1)*math.tau/28
            beam(hub+radius*(UP*math.sin(a)+direction*math.cos(a)),hub+radius*(UP*math.sin(b)+direction*math.cos(b)),.105,.105,pal(BRASS),6)
    for dx,dz,h in [(-11,-10,8.5),(13,-8,10.5),(11,7,3.5),(-10,9,3.2)]:
        p=summit+X*dx+Z*dz
        block(p+UP*.22,(1.24,.22,1.24),pal(STONE[2]))
        for j in range(8):
            w=1-j*.078
            block(p+UP*(.46+h*(j+.5)/8),(w,h*.061,w),pal(rng.choice(STONE)))
        block(p+UP*(h+.48),(.71,.16,.71),pal(BRASS))
    # Interrupted copper vault wraps the astrolabe; open ribs leave views to the ridge.
    dome=summit+X*6-Z*10+UP*3.65
    for i in range(13):
        az=i*math.tau/13
        radial=X*math.cos(az)+Z*math.sin(az)
        next_az=(i+1)*math.tau/13
        neighbor=X*math.cos(next_az)+Z*math.sin(next_az)
        for j in range(7 if i%4 else 4):
            low=j*math.pi/16
            high=(j+1)*math.pi/16
            a=dome+5.65*(radial*math.cos(low)+UP*math.sin(low))
            b=dome+5.65*(radial*math.cos(high)+UP*math.sin(high))
            beam(a,b,.095,.068,pal(BRASS),6)
            if i in (5,6,8,9) and j<5:
                c=dome+5.65*(neighbor*math.cos(high)+UP*math.sin(high))
                d=dome+5.65*(neighbor*math.cos(low)+UP*math.sin(low))
                panel(a,b,c,d,pal(rng.choice(["#4d8173","#6e8c72","#a0774d"])),out=UP+radial)
        if i%2==0:
            foot=dome+radial*5.65
            beam(foot-UP*3.62,foot,.45,.29,pal(STONE[1]),7)
    # A copper compass rose anchors the observatory. Long needles share a
    # recessed circle, and are readable from the defense angle.
    for i in range(16):
        ang=i*math.tau/16
        a=X*math.cos(ang)+Z*math.sin(ang)
        side=np.cross(UP,a)
        p=summit+UP*.036
        radius=5.4 if i%4==0 else (4.15 if i%2==0 else 2.65)
        triangle(p+a*.98-side*.13,p+a*radius,p+a*1.95,pal("#b19059"),out=UP)
        triangle(p+a*.98+side*.13,p+a*radius,p+a*1.95,pal("#ded0a0"),out=UP)
    # The woodland's coppiced paths are fenced with irregular low timber rails.
    for x,z,ang in [(5,-5,.4),(8,-1,1.7),(-9,-8,1.2)]:
        p=wood+X*x+Z*z; d=X*math.cos(ang)+Z*math.sin(ang)
        for sign in (-1,1):
            foot=p+d*sign*1.9
            beam(foot,foot+UP*1.30,.13,.075,pal(ROOTS),6)
            beam(p+d*sign*1.35,p+d*sign*1.67+UP*.91,.09,.07,pal(ROOTS),5)
        for h in (.40,.90):
            beam(p-d*1.95+UP*h,p+d*1.95+UP*(h+.10),.085,.071,pal("#826141"),6)
    # Weathered orange pennants lift the observatory into the skyline.
    for x,z,height,direction in [(-11,-10,8.5,-1),(13,-8,10.5,1)]:
        p=summit+X*x+Z*z+UP*(height+.6)
        beam(p,p+UP*1.30,.055,.035,pal(BRASS),6)
        top=p+UP*1.22
        for j in range(5):
            a=top+X*(direction*j*.54)+Z*math.sin(j*1.34)*.21-UP*j*.10
            b=top+X*(direction*(j+1)*.54)+Z*math.sin((j+1)*1.34)*.21-UP*(j+1)*.10
            panel(a,b,b-UP*(.74-(j+1)*.11),a-UP*(.74-j*.11),pal("#cc793a"),"Leaves",Z)
    for idx,s in enumerate(SITES):
        for i in range(56):
            a=rng.uniform(0,math.tau); dist=rng.uniform(6.8,14.2)
            p=s+np.array([math.cos(a)*dist,0,math.sin(a)*dist])
            p[1]=surface(p[0],p[2])[0]
            if idx==1 and p[1]<s[1]-.25:continue
            for j in range(rng.randrange(6,12)):
                rot=rng.uniform(0,math.tau)
                axis=X*math.cos(rot)+Z*math.sin(rot); side=np.cross(UP,axis)
                base=p+axis*rng.uniform(0,.24)
                tip=base+axis*rng.uniform(.13,.49)+UP*rng.uniform(.17,.61)
                triangle(base-side*.044,base+side*.044,tip,pal(rng.choice(["#899955","#a99854","#b0823c"])),"Leaves",axis)
            if i%5==0:
                ellipsoid(p,(.59,.28,.48),"#99917a",6)
    for key,span in [("ruins",5.7),("saddle",4.5),("terrace",4.8)]:
        p=NODES[key].copy()
        for j in range(3):
            base=p+np.array([(j-1)*(span+.7),0,-8.8])
            base[1]=surface(base[0],base[2])[0]
            arch(base,X,span,4.7,1.02)
    # Place a lamp at each winch foundation, visible from its approach.
    for c,f,side in GATES:
        lantern(c-f*5.5+side*2.8)

def camp_paths():
    """Articulate the enemy approaches and retreat gaps on each site's floor."""
    for i,desc in enumerate(MARKS["sites"]):
        origin=SITES[i]
        for route in desc["lanes"]:
            chain=[origin+np.array([x,0,z]) for x,z in route]
            for a,b in zip(chain[:-1],chain[1:]):
                delta=b-a;length=np.linalg.norm(delta)
                side=np.cross(UP,delta/length)
                n=math.ceil(length/1.55)
                for j in range(n):
                    mid=a+delta*(j+.5)/n
                    distance=np.linalg.norm((mid-origin)[[0,2]])
                    if distance<2.2:continue
                    for sign in (-1,1):
                        p=mid+side*sign*(1.07 if i==0 else 1.30)
                        rel=p-origin
                        near_floor=np.linalg.norm(rel[[0,2]])<=7.78
                        if i==1 and distance<15.5:near_floor=True
                        p[1]=origin[1]+.034 if near_floor else surface(p[0],p[2])[0]+.025
                        if near_floor:
                            # Brass tacks double as a subtle lane border in the court.
                            p0=p+side*.084;p1=p-side*.084
                            triangle(p0,p+delta/length*.32,p1,pal("#b5915e"),out=UP)
                            triangle(p0,p-delta/length*.32,p1,pal("#856a50"),out=UP)
                        else:
                            col=rng.choice(STONE)
                            axis=delta/length
                            panel(p-axis*.56-side*.12,p-axis*.53+side*.12,p+axis*.52+side*.13,p+axis*.55-side*.14,pal(col),"Detail",UP)
        # Leave gaps exactly at the roads and attacking lanes. Architecture
        # between them sets up distinct sightlines and retreat choices.
        if i==1:continue
        for j in range(22):
            ang=math.tau*j/22.
            axis=X*math.cos(ang)+Z*math.sin(ang)
            side=np.cross(UP,axis)
            p=origin+axis*10.2
            _,road_distance=surface(p[0],p[2])
            if road_distance<3.9:continue
            clear=True
            for lane in desc["lanes"]:
                for q,r in zip(lane[:-1],lane[1:]):
                    q=np.array(q);r=np.array(r);seg=r-q;off=(p-origin)[[0,2]]-q
                    if np.linalg.norm(off-np.clip(np.dot(off,seg)/np.dot(seg,seg),0,1)*seg)<3.1:clear=False
            if not clear:continue
            if i==2:
                height=.64+.23*math.sin(j*1.8)
                block(p+UP*height*.5,(1.22,height*.5,.34),pal(rng.choice(STONE)),(side,UP,axis))
                block(p+UP*(height+.08),(1.27,.075,.40),pal(STONE[0]),(side,UP,axis))
            else:
                ellipsoid(p,(1.18,.69,1.05),"#737d69",8)
                ellipsoid(p+UP*.39,(.86,.42,.92),rng.choice(TEAL),7)

def water():
    s=SITES[1]
    # Rectangular sluice pools flush with the piers, offset from the dry camp.
    for i in range(-13,7,2):
        for j in range(-14,8,2):
            p=s+X*i+Z*j
            p[1]=s[1]-.45
            if surface(p[0]+1,p[2]+1)[0]>=p[1]:continue
            panel(p,p+X*2,p+X*2+Z*2,p+Z*2,pal("#4ca6a2"),"Water",UP)
    for dx,dz,wide,long in [(-10,-5,6,1.54),(6.65,-8.5,1.54,8.2)]:
        p=s+X*dx+Z*dz-UP*.33
        panel(p-X*wide*.5-Z*long*.5,p+X*wide*.5-Z*long*.5,
              p+X*wide*.5+Z*long*.5,p-X*wide*.5+Z*long*.5,pal("#5fc7b6"),"Water",UP)

def gltf():
    scene={"asset":{"version":"2.0","generator":"Cindertrail authored valley baker"},
           "scene":0,"scenes":[{"nodes":[]}],"nodes":[],"meshes":[],
           "materials":[],"accessors":[],"bufferViews":[],"buffers":[]}
    for name in ("Valley pigment","Two-sided reeds","Sluice water","Lantern glass"):
        material={"name":name,"pbrMetallicRoughness":{"metallicFactor":0,"roughnessFactor":.90}}
        if name=="Two-sided reeds":material["doubleSided"]=True
        if name=="Sluice water":material["pbrMetallicRoughness"]["roughnessFactor"]=.21
        if name=="Lantern glass":material["emissiveFactor"]=[.70,.27,.049]
        scene["materials"].append(material)
    blob=bytearray()
    def accessor(data,component,kind,normalized=False):
        while len(blob)%4:blob.append(0)
        offset=len(blob);blob.extend(data.tobytes())
        view=len(scene["bufferViews"])
        scene["bufferViews"].append({"buffer":0,"byteOffset":offset,"byteLength":len(blob)-offset})
        item={"bufferView":view,"componentType":component,"count":len(data),"type":kind}
        if kind=="VEC3" and component==5126:
            item.update(min=data.min(axis=0).tolist(),max=data.max(axis=0).tolist())
        if normalized:item["normalized"]=True
        index=len(scene["accessors"]);scene["accessors"].append(item)
        return index
    for (cx,cz,layer),(vertices,colors) in sorted(chunks.items()):
        verts=np.asarray(vertices,dtype=np.float32).reshape((-1,3,3))
        normals=np.cross(verts[:,1]-verts[:,0],verts[:,2]-verts[:,0])
        lengths=np.linalg.norm(normals,axis=1)
        mask=lengths>1e-7
        normals=normals[mask]/lengths[mask,None]
        verts=verts[mask]
        origin=np.array((cx*36.,0.,cz*36.),np.float32)
        positions=(verts-origin).reshape((-1,3))
        normals=normals.astype(np.float32).repeat(3,axis=0)
        if layer == "Ground":
            colors = np.round(terrain_colors(verts.reshape((-1,3)))*65535).astype("<u2")
        else:
            colors=np.round(np.asarray(colors)[mask]*65535).astype("<u2").repeat(3,axis=0)
        # Interleaved duplicate values compress efficiently after Godot import.
        attrs={"POSITION":accessor(positions,5126,"VEC3"),"NORMAL":accessor(normals,5126,"VEC3"),
               "COLOR_0":accessor(colors,5123,"VEC3",True)}
        idx=len(scene["meshes"])
        name=f"{layer}_{cx+10}_{cz+10}"+("-col" if layer in ("Ground","Deck","Masonry","Trunks") else "")
        scene["meshes"].append({"name":name,"primitives":[{"attributes":attrs,"material":{"Leaves":1,"Water":2,"Lantern":3}.get(layer,0)}]})
        scene["nodes"].append({"mesh":idx,"name":name,"translation":origin.tolist()})
        scene["scenes"][0]["nodes"].append(idx)
    while len(blob)%4:blob.append(0)
    scene["buffers"].append({"byteLength":len(blob)})
    js=json.dumps(scene,separators=(",",":")).encode()
    js+=b' '*(-len(js)%4)
    out=ROOT/"art/outer_valley/outer_land.glb"
    with out.open("wb") as f:
        f.write(struct.pack("<4sII",b"glTF",2,28+len(js)+len(blob)))
        f.write(struct.pack("<I4s",len(js),b"JSON")+js)
        f.write(struct.pack("<I4s",len(blob),b"BIN\x00")+blob)
    print(f"{out.name}: {len(chunks)} culled sections, {sum(len(v[1]) for v in chunks.values()):,} triangles, {out.stat().st_size//1024:,} KiB.")

if __name__=="__main__":
    terrain()
    roads()
    vegetation()
    landmarks()
    camp_paths()
    water()
    gltf()
