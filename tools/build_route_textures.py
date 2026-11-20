"""Paint Cindertrail's seamless mineral, vegetation and workshop surface families.

Run with Python, NumPy and Pillow. The drawing wraps explicitly at each tile edge.
The channel maps are linear data; the workshop strip is an sRGB colour texture.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

OUTPUT = Path(__file__).resolve().parents[1] / "art/textures/stylized"
SIZE = 2048
SCALE = SIZE / 1024
rng = np.random.default_rng(81355)
axis = np.arange(SIZE, dtype=np.float32) / SIZE
x, y = np.meshgrid(axis, axis)


def field(across, down):
    grid = rng.random((down, across), dtype=np.float32)
    u, v = x * across, y * down
    i, j = u.astype(int), v.astype(int)
    u, v = u - i, v - j
    u, v = u*u*(3-2*u), v*v*(3-2*v)
    top = grid[j, i] * (1-u) + grid[j, (i+1) % across] * u
    bottom = grid[(j+1) % down, i] * (1-u) + grid[(j+1) % down, (i+1) % across] * u
    return top*(1-v) + bottom*v


def ramp(low, high, value):
    t = np.clip((value-low)/(high-low), 0, 1)
    return t*t*(3-2*t)


def channel(values):
    return Image.fromarray(np.uint8(np.clip(values, 0, 1)*255 + .5))


def normalized(image):
    return np.asarray(image, dtype=np.float32) / 255


def wrap(draw, points, shade, width=0):
    """Paint an irregular stroke or polygon, including its neighboring tile copies."""
    xs, ys = zip(*points)
    shifts_x = [0] + ([SIZE] if min(xs)<0 else []) + ([-SIZE] if max(xs)>=SIZE else [])
    shifts_y = [0] + ([SIZE] if min(ys)<0 else []) + ([-SIZE] if max(ys)>=SIZE else [])
    for dx in shifts_x:
        for dy in shifts_y:
            p = [(int(px+dx), int(py+dy)) for px, py in points]
            if width:
                draw.line(p, fill=shade, width=width)
            else:
                draw.polygon(p, fill=shade)


def rock_faults():
    im = Image.new("L", (SIZE, SIZE))
    pen = ImageDraw.Draw(im)
    for _ in range(23):
        point = rng.uniform(0, SIZE, 2)
        angle = rng.uniform(-np.pi, np.pi)
        line = [point.copy()]
        for step in range(rng.integers(4, 12)):
            angle += rng.uniform(-.65, .65)
            point = point + np.array([np.cos(angle), np.sin(angle)]) * rng.uniform(6, 25) * SCALE
            line.append(point.copy())
            if step % 3 == 2:
                twig = angle + rng.choice([-1.0, 1.0])*.82
                end = point + np.array([np.cos(twig), np.sin(twig)]) * rng.uniform(10, 33) * SCALE
                wrap(pen, [point, end], 158, int(2 * SCALE))
        wrap(pen, line, int(rng.uniform(180, 235)), int(rng.integers(2, 5) * SCALE))
    return normalized(im)


def leaves_and_gravel():
    leaves = Image.new("L", (SIZE, SIZE), 72)
    soil = Image.new("L", (SIZE, SIZE), 105)
    lp, sp = ImageDraw.Draw(leaves), ImageDraw.Draw(soil)
    for _ in range(115):
        cx, cy = rng.uniform(0, SIZE, 2)
        orientation = rng.uniform(-2.4, 2.4)
        for _ in range(rng.integers(6, 14)):
            center = np.array([cx, cy]) + rng.normal(0, 32 * SCALE, 2)
            angle = orientation + rng.uniform(-.9, .9)
            reach = np.array([np.cos(angle), np.sin(angle)]) * rng.uniform(7, 19) * SCALE
            width = np.array([-reach[1], reach[0]]) * rng.uniform(.29, .51)
            points = [center-reach, center+width, center+reach, center-width]
            shade = int(rng.uniform(93, 235))
            wrap(lp, points, shade)
            wrap(lp, [points[0], points[1], points[2]], max(40, shade-38))
            wrap(lp, [points[0], points[2]], min(shade + 15, 247), int(SCALE))
    for _ in range(3300):
        cx, cy = rng.uniform(0, SIZE, 2)
        reach = rng.uniform(1.5, 10) * SCALE
        wide = reach*rng.uniform(.32, .72)
        pts = [(cx-reach,cy+wide*.2),(cx-reach*.45,cy-wide),(cx+reach*.63,cy-wide*.65),
               (cx+reach,cy+wide*.24),(cx-reach*.16,cy+wide)]
        wrap(sp, pts, int(rng.uniform(94, 189)))
        if reach > 4 * SCALE:
            wrap(sp, pts[:3], 202, int(SCALE))
    return normalized(leaves), normalized(soil)


def workshop_strip(wood, bronze, mineral):
    """A 2K strip of beaten copper, chased brass, timber, stone, rope and enamel."""
    width, row_height = 2048, 128
    bands = []
    for i, values in enumerate([bronze, bronze, wood, mineral, wood, mineral]):
        crop = channel(values).resize((width, row_height*2), Image.Resampling.LANCZOS)
        v = normalized(crop)[:row_height]
        u, h = np.meshgrid(np.arange(width)/width, np.arange(row_height)/row_height)
        if i == 4:
            v = .52 + .21*np.sin(2*np.pi*(u*38-h*1.65)) + .10*np.sin(2*np.pi*(u*114-h*4.95)) + (v-.5)*.24
        edge = np.exp(-((h-.11)/.024)**2) + np.exp(-((h-.89)/.024)**2)
        if i in (0, 1, 3, 5):
            v += .19*edge
        tone = np.clip(.62+(v-.45)*.62, .21, 1)
        if i == 0:
            patina = ramp(.57,.76,v)*(1-np.minimum(edge, 1))*.52
            color = np.stack((tone*(1-.43*patina), tone*(.96+.18*patina), tone*(.90+.20*patina)), axis=2)
        else:
            color = np.stack([tone]*3, axis=2)
        band = Image.fromarray(np.uint8(np.clip(color,0,1)*255))
        d = ImageDraw.Draw(band)
        if i in (0,1,3,5):
            for px in range(32, width, 128):
                if i in (0,3):
                    d.line([(px-13,64),(px,52),(px+13,64),(px,76),(px-13,64)], fill=(119,107,87), width=2)
                    d.line([(px-12,62),(px,51),(px+12,62)], fill=(194,185,165), width=1)
                else:
                    d.arc((px-13,51,px+13,77),180,360,fill=(205,196,174),width=2)
                    for off in (-1,0,1):
                        d.line((px+off*6,49,px+off*9,43), fill=(207,198,178),width=2)
        bands.append(band)
    out = Image.new("RGB", (width, row_height*len(bands)))
    for i, band in enumerate(bands):
        out.paste(band,(0,i*row_height))
    out.save(OUTPUT/"workshop_trim.png",optimize=True)


def main():
    broad = field(6, 7)
    strokes = field(18, 74)
    grain = field(96, 103)
    cracks = rock_faults()
    vein = abs(np.sin(2*np.pi*(y*5+x+broad*.37)))
    facets = ramp(.34, .67, field(22, 26) * .72 + broad * .28)
    pits = ramp(.7, .9, field(132, 141)) * .065
    mineral = .36 + broad*.19 + facets*.13 + (strokes-.5)*.15 + (grain-.5)*.095 - pits
    lip = np.maximum(np.roll(cracks, int(3*SCALE), axis=0) - cracks, 0)
    mineral += .10*(1-ramp(.05,.23,vein)) + .24*lip - cracks*.29
    waviness = field(6, 4)
    warp = x + waviness*.047 + np.sin(y*2*np.pi)*.019
    split = abs(np.sin(2*np.pi*warp*14))
    pores = field(160, 29)
    honey = (1 + np.sin(2*np.pi*warp*46)) * .033
    wood = .34 + .22*field(44,4) + .16*field(72,7) + honey - .25*(1-ramp(.04,.27,split))
    wood -= ramp(.59,.87,pores)*.06
    moss = ramp(.39,.72, broad*.31 + field(23,18)*.45 + grain*.17 + pores*.07)
    bronze = .18 + .63*ramp(.31,.72,field(11,10)*.55+field(40,37)*.22+grain*.15+pores*.08)
    Image.merge("RGBA", tuple(channel(ch) for ch in (mineral,wood,moss,bronze))).save(OUTPUT/"route_paint.png")
    leaf, pebble = leaves_and_gravel()
    caustic = abs(np.sin(2*np.pi*(2*x+4*y+waviness*.67)) + np.sin(2*np.pi*(5*x-y+broad*.72))*.87)
    ripple = .76*(1-ramp(.025,.19,caustic)) + .20*(1-ramp(.06,.42,caustic))
    track = abs(np.sin(2*np.pi*(x*4 + .11*np.sin(2*np.pi*y) + field(6,7)*.07)))
    ruts = (1-ramp(.02,.14,track))*ramp(.36,.65,field(7,7))
    soil_banks = field(12, 13)
    organic = (leaf*.79+strokes*.21, pebble*.57+broad*.15+soil_banks*.20+grain*.08, ripple, ruts)
    Image.merge("RGBA", tuple(channel(ch) for ch in organic)).save(OUTPUT/"valley_brush.png")
    workshop_strip(wood, bronze, mineral)


if __name__ == "__main__":
    main()
