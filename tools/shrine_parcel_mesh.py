"""Bake the walkable approach, limestone terrace and ruined rim of one shrine parcel."""
from __future__ import annotations

import hashlib
import math
import random

import numpy as np

import build_outer_valley as art


def _bank_toe(point, side, ground_height):
    if ground_height is None:
        return point - art.UP * .45
    try:
        height = ground_height(point[0], point[2])
    except ValueError:
        height = min(point[1] - 18., -6.)
    depth = max(.12, point[1] - height)
    base = point + side * min(1.55, depth * .24)
    base[1] = min(point[1] - .12, height - .30)
    return base


def _approach(points, stone, moss, bronze, ground_height):
    """A broad continuous ramp under the worn flags, flush at both landings."""
    sections = [points[0]]
    for a, b in zip(points, points[1:]):
        distance = np.linalg.norm((b - a)[[0, 2]])
        if distance < 0.005:
            continue
        steps = max(1, math.ceil(distance / .85))
        sections.extend(a + (b - a) * (i / steps) for i in range(1, steps + 1))
    if len(sections) < 2:
        return
    tangents = np.diff(sections, axis=0)
    sides = np.cross(tangents, art.UP)
    sides /= np.linalg.norm(sides, axis=1)[:, None]
    rims = [sides[0]]
    for previous, following in zip(sides[:-1], sides[1:]):
        middle = previous + following
        middle /= np.linalg.norm(middle)
        rims.append(middle / max(0.7, middle @ following))
    rims.append(sides[-1])
    width = 2.1
    lengths = np.linalg.norm(tangents[:, [0, 2]], axis=1)
    travel = np.r_[0., np.cumsum(lengths)]

    for i, (a, b) in enumerate(zip(sections, sections[1:])):
        sa, sb = rims[i:i + 2]

        def point(t, x):
            p = a + (b - a) * t + (sa + (sb - sa) * t) * x
            distance = travel[i] + t * lengths[i]
            if ground_height is not None and distance < 7.:
                # Embed the landing under the crowned road. The rise starts
                # beyond its shoulder where the player's capsule can step on.
                ground = ground_height(p[0], p[2]) - .10
                blend = max(0., (distance - 1.5) / 5.5)
                smooth = blend * blend * (3. - 2. * blend)
                p[1] = ground + (p[1] - ground) * smooth
            return p

        # Both road rims can sit at different heights from the centerline.
        # A single full-width triangle pair would bridge across its crown.
        strips = 6 if travel[i] < 7. else 1
        for strip in range(strips):
            left = width * (2. * strip / strips - 1.)
            right = width * (2. * (strip + 1) / strips - 1.)
            art.panel(point(0, left), point(1, left), point(1, right),
                      point(0, right), moss, "Deck", art.UP)
        # Staggered joints between the cream coping and the older paving.
        split = (-0.42, 0.64, 0.08)[i % 3]
        for j, (left, right) in enumerate(zip(
                [-width, -1.72, split, 1.72], [-1.72, split, 1.72, width])):
            lift = art.UP * (0.025 if j in (0, 3) else 0.018)
            color = stone[(i + j) % len(stone)]
            art.panel(point(.014, left + .024) + lift, point(.978, left + .024) + lift,
                      point(.978, right - .024) + lift, point(.014, right - .024) + lift,
                      color, "Detail", art.UP)
        for sign in (-1, 1):
            e, f = point(0, width * sign), point(1, width * sign)
            side = sa * sign
            art.panel(e, f, _bank_toe(f, side, ground_height), _bank_toe(e, side, ground_height),
                      stone[-1] * .76, "Detail", side)
            if i % 5 == 2:
                art.panel(point(.32, 1.8 * sign) + art.UP * .031,
                          point(.65, 1.8 * sign) + art.UP * .031,
                          point(.65, 2.03 * sign) + art.UP * .031,
                          point(.32, 2.03 * sign) + art.UP * .031, bronze, "Detail", art.UP)


def build_parcel(record: dict, ground_height=None):
    """Append geometry in world space. All gameplay contacts use the Deck layer."""
    center = np.asarray(record["center"], dtype=float)
    yaw = float(record["yaw"])
    right = np.array([math.cos(yaw), 0., -math.sin(yaw)])
    ahead = np.array([math.sin(yaw), 0., math.cos(yaw)])
    seed = hashlib.blake2s(record["id"].encode(), digest_size=8).digest()
    rng = random.Random(int.from_bytes(seed, "big"))

    def world(x, z, y=0.):
        return center + right * x + ahead * z + art.UP * y

    def local_ground(point):
        if ground_height is not None:
            try:
                return min(center[1] - .20, ground_height(point[0], point[2]) - .25)
            except ValueError:
                # A terrace at the edge of the imported plateau can overhang a cliff.
                pass
        # Some edges meet the valley's painted canyon rather than a walkable
        # triangle. Taper into the canyon floor well below its nearest terrace.
        return min(center[1] - 18., -6.)

    stone = [art.pal(c) for c in ("#c6b794", "#beae90", "#d2c29e", "#b4a98e", "#9c9585")]
    bronze = art.pal("#ae8252")
    wet = record["wet"]
    garden = record["sector"] == "south"
    soil = art.pal("#527067" if wet else "#647363" if garden else "#777b69")
    rock_colors = [art.pal(c) for c in ("#7a8177", "#8d9282", "#717d79", "#9b9b85")]
    access = np.asarray(record["access"], dtype=float)
    _approach(access, stone, soil, bronze, ground_height)

    count = 24
    directions = []
    rim = []
    angle_offset = rng.uniform(-.12, .12)
    for i in range(count):
        angle = math.tau * i / count + angle_offset
        radial = right * math.cos(angle) + ahead * math.sin(angle)
        directions.append(radial)
        # The negative-z shoulder meets the final level section of the approach.
        radius = 13.45 if math.sin(angle) < -.86 else 14.65 + rng.uniform(-.72, .66)
        rim.append(center + radial * radius)

    # Monolithic bed below a patchwork of worn flags. Gaps in the surface painting
    # reveal earth, moss and mortar without introducing edges into the walk mesh.
    for i, point in enumerate(rim):
        neighbor = rim[(i + 1) % count]
        art.triangle(center, point, neighbor, soil, "Deck", art.UP)

    # Several surviving runs of causeway converge at the camp. Weathered flags
    # follow each bend; the open pockets between them collect moss and grasses.
    paint = random.Random(seed + b"court")
    silt = art.pal("#688279" if wet else "#797e66" if garden else "#918675")
    lichen = art.pal("#8d9a68" if garden else "#849878" if wet else "#a7986d")

    def flake(x, z, width, length, bearing, shade, lift, flag=False):
        # Fractured, short-sided polygons. The chipped rim of a flag casts a
        # fine shadow while the dirt and moss washes have flush edges.
        points = []
        sides = paint.choice((5, 6, 7))
        for j in range(sides):
            angle = math.tau * (j + paint.uniform(-.16, .16)) / sides
            u = width * math.cos(angle) * paint.uniform(.77, 1.04)
            v = length * math.sin(angle) * paint.uniform(.81, 1.05)
            points.append(world(x + u * math.cos(bearing) - v * math.sin(bearing),
                                z + u * math.sin(bearing) + v * math.cos(bearing), lift))
        for j in range(1, len(points) - 1):
            art.triangle(points[0], points[j], points[j + 1], shade, "Detail", art.UP)
        if flag:
            for j, v in enumerate(points):
                w = points[(j + 1) % sides]
                outward = (v + w) * .5 - world(x, z, lift)
                art.panel(v, w, w - art.UP * .023, v - art.UP * .023,
                          shade * .72, "Detail", outward)

    for patch in range(26):
        angle = paint.uniform(0., math.tau)
        radius = 11.1 * math.sqrt(paint.random())
        x, z = radius * math.cos(angle), radius * math.sin(angle)
        patch_color = soil * .38 + paint.choice((silt, lichen)) * .62
        flake(x, z, paint.uniform(1.1, 2.4), paint.uniform(.51, 1.42),
              angle - .4, patch_color, .006 + patch * .00017)
        if patch % 2 == 0 and radius > 4.8:
            for _ in range(5):
                base = world(x + paint.uniform(-.66, .66), z + paint.uniform(-.38, .38), .011)
                lean = ahead * paint.uniform(.04, .16) + right * paint.uniform(-.08, .08)
                art.triangle(base - right * .035, base + right * .035,
                             base + lean + art.UP * paint.uniform(.08, .20),
                             lichen, "Leaves")

    # Four arcs create a broken fan pavement, with wider dressed stones on the
    # walk in and scattered, turned fragments at the outer tips.
    for branch, heading in enumerate((-math.pi * .5, -.04, 1.41, 2.92)):
        bend = paint.uniform(.12, .34) * (-1 if branch % 2 else 1)
        if garden:
            bend *= 1.35
        reach = 12.4 if branch == 0 else paint.uniform(9.8, 12.1)
        distance = 1.3
        while distance < reach:
            angle = heading + bend * math.sin(math.pi * distance / reach)
            tangent = angle + math.atan(bend * math.pi * distance / reach
                                        * math.cos(math.pi * distance / reach))
            pieces = 3 if branch == 0 else 2
            for j in range(pieces):
                if distance > 4.5 and paint.random() < (.12 if branch == 0 else .29):
                    continue
                offset = (j - (pieces - 1) * .5) * .92 + paint.uniform(-.13, .13)
                x = distance * math.cos(angle) - offset * math.sin(tangent)
                z = distance * math.sin(angle) + offset * math.cos(tangent)
                tone = paint.choice(stone)
                tint = art.pal("#8caa9b" if wet else "#c69d73")
                tone = .74 * tone + .18 * tint + .08 * silt
                flake(x, z, paint.uniform(.57, .91), paint.uniform(.40, .66),
                      tangent + paint.uniform(-.28, .28), tone,
                      paint.uniform(.025, .044), True)
            distance += paint.uniform(1.30, 1.76)

    # Extend the exposed ledge into overlapping strata. Tall banks expose
    # longer limestone ribs; low areas end in a moss-coloured fan of scree.
    bank_rng = random.Random(int.from_bytes(seed, "big") ^ 0x5C07)
    edges = []
    for i, cap in enumerate(rim):
        radial = directions[i]
        depth = center[1] - local_ground(cap)
        toe_width = min(5.3, 1.2 + .40 * depth) * bank_rng.uniform(.78, 1.13)
        rib = .5 + .5 * math.sin(i * 1.63)
        course = cap + radial * (.3 + rib * .85)
        shelf = cap + radial * (toe_width * (.49 + .12 * rib))
        foot = cap + radial * toe_width
        toe = foot + radial * bank_rng.uniform(.25, .75)
        toe[1] = local_ground(toe)
        drop = max(.28, cap[1] - toe[1])
        course[1] = cap[1] - drop * (.13 + .11 * rib)
        shelf[1] = cap[1] - drop * (.30 + .11 * rib)
        foot[1] = max(toe[1] + .09, cap[1] - drop * (.70 + .12 * rib))
        edges.append([cap, course, shelf, foot, toe])
    rock_light = art.pal("#aba38e")
    ochre = art.pal("#91765b")
    for i, edge in enumerate(edges):
        other = edges[(i + 1) % count]
        radial = directions[i]
        for j in range(4):
            shade = rock_colors[(i + j) % len(rock_colors)]
            if j == 1:
                shade = soil * .47 + shade * .35 + ochre * .18
            elif j == 3:
                shade = soil * .65 + shade * .35
            art.panel(edge[j], other[j], other[j + 1], edge[j + 1],
                      shade, "Detail", radial + art.UP * .4)

        # Outcrops stand above the crest and break its straight horizon.
        # Keep the interpolated support on the outside of the playable floor.
        if i % 4 == 1 and radial @ ahead > -.72:
            ledge = .5 * (edge[0] + other[0])
            tang = np.cross(art.UP, radial)
            run = bank_rng.uniform(1.15, 1.95)
            dip = min(3.5, max(.70, .28 * (ledge[1] - local_ground(ledge))))
            crest = [.45, .95, .70, .30]
            offsets = [(-run,.16),(-run*.46,1.02),(run*.76,1.21),(run,.23)]
            crown = [ledge + tang * x + radial * z + art.UP * h
                     for (x, z), h in zip(offsets, crest)]
            base = [point + radial * bank_rng.uniform(.35,.77) - art.UP * (dip + h)
                    for point, h in zip(crown, crest)]
            art.panel(*crown, rock_light * .65 + soil * .35, "Detail", art.UP)
            for k in range(4):
                n = (k + 1) % 4
                art.panel(crown[k], crown[n], base[n], base[k],
                          rock_colors[(i + k) % 4], "Detail",
                          .5 * (crown[k] + crown[n]) - np.mean(crown, axis=0))

    # Three regional rim silhouettes stay beyond the combat disc. Each low
    # plinth grows down to the bank and leaves the entrance side completely open.
    for sign in (-1, 1):
        x, z = sign * rng.uniform(12.9, 14.0), rng.uniform(9.3, 10.6)
        foot = world(x, z)
        bottom = local_ground(foot)
        axes = (right, art.UP, ahead)
        h = (center[1] - bottom) * .5
        art.block(foot - art.UP * h, (1.04, h, .88), rock_colors[0], axes, "Detail")
        art.block(foot + art.UP * .16, (1.1, .16, .94), rock_colors[1], axes, "Detail")
        if wet:
            # The two copper-banded levels of a broken tide gauge.
            art.block(foot + art.UP * .83, (.52, .52, .48), stone[1], axes, "Detail")
            art.block(foot + art.UP * 1.39, (.61, .065, .53), bronze, axes, "Detail")
            art.block(foot + art.UP * 1.63, (.33, .19, .33), stone[3], axes, "Detail")
        elif garden:
            # Honey-coloured fragments atop the garden's old seat wall.
            art.block(foot + art.UP * .59, (.78, .27, .56), stone[3], axes, "Detail")
            art.block(foot + art.UP * .92, (.90, .10, .65), stone[0], axes, "Detail")
            across = foot + right * sign * .51
            art.beam(across + art.UP * 1.02, across + art.UP * 1.50, .14, .10, bronze, 6)
        else:
            # Tapered survey cairn, with a small inset amber glass cap.
            art.beam(foot + art.UP * .30, foot + art.UP * 1.53, .70, .34, stone[2], 5)
            art.beam(foot + art.UP * 1.53, foot + art.UP * 1.65, .39, .39, bronze, 5)
            art.beam(foot + art.UP * 1.65, foot + art.UP * 1.89, .19, .11,
                     art.pal("#f4b86f"), 5, "Lantern")
