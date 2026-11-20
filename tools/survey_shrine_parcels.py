"""Offline survey of shrine courts and access ramps against the imported valley geometry.

A road knot is the start of each spur. We search both shoulders and a small number
of authored grades/headings, keeping existing roads, forks and settlements clear.
The result belongs in the baked manifest; the runtime never runs this survey.
"""
import json
import math

import numpy as np

from build_trail_forks import ROOT, Survey

DATA = ROOT / "data/outer_valley"
# Each sector has one water-capable court and two dry courts.
PARCELS = [
    ("west_reed_bank", "Quarry switchback", True),
    ("west_lime_shelf", "Western causeway", False),
    ("west_orchard_watch", "High orchard", False),
    ("east_mirror_ford", "Eastern escarpment", True),
    ("east_relay_ridge", "Relay ascent", False),
    ("east_bronze_stair", "Northern stair", False),
    ("south_sedge_pool", "Tanners’ road", True),
    ("south_copper_bench", "Spice road", False),
    ("south_pilgrim_rest", "South wash", False),
]
RADIUS = 15.0


def xz(xyz):
    return xyz[..., [0, 2]]


def distance_to_paths(p, starts, ends):
    steps = ends - starts
    t = np.clip(np.sum((p - starts) * steps, axis=1) / np.sum(steps ** 2, axis=1), 0., 1.)
    return np.linalg.norm(p - starts - steps * t[:, None], axis=1)


def bounds_near(lo, hi, point, radius):
    delta = np.maximum(np.maximum(xz(lo) - point, point - xz(hi)), 0.)
    return np.sum(delta * delta, axis=1) <= radius * radius


def court_profile(survey, ground, start, unit, distance):
    """Envelope the existing triangles; a constant, low grade climbs to a flat court."""
    end = start + unit * distance
    ramp = distance - RADIUS
    center = xz(end)
    # Keep selected precinct clean even near nearby tree crowns and retaining walls.
    near = bounds_near(survey.lo, survey.hi, center, distance + 4)
    props_lo, props_hi = survey.lo[near], survey.hi[near]
    box = bounds_near(ground[0], ground[1], center, RADIUS + .5)
    if not box.any():
        return None
    top = float(ground[1][box, 1].max()) + .18
    occupied = bounds_near(props_lo, props_hi, center, RADIUS + 1.5)
    if occupied.any():
        top = max(top, props_hi[occupied, 1].max() + 1.0)
    grade = max(.025, (top - start[1]) / ramp)
    side = np.array([-unit[2], 0, unit[0]])
    for t in np.arange(1., ramp + .5, 1.0):
        p = start + unit * t
        try:
            floor = max(survey.height(*xz(p + side * off)) for off in (-1.55, 0., 1.55))
        except ValueError:
            return None
        grade = max(grade, (floor + min(.13, .03 * t) - start[1]) / t)
        obstruction = bounds_near(props_lo, props_hi, xz(p), 1.75)
        if obstruction.any():
            grade = max(grade, (props_hi[obstruction, 1].max() + .12 - start[1]) / t)
        if grade > .42:
            return None
    if grade > .42:
        return None
    top = start[1] + grade * ramp
    # Disc is flat for the last fifteen metres including where it meets the ramp.
    distances = [0., ramp, distance]
    profile = np.array([start + unit * t for t in distances])
    profile[:, 1] = [start[1], top, top]
    return grade, profile


def survey_layout(layout: int, survey=None) -> list[dict]:
    graph = json.loads((DATA / f"layout_{layout}.json").read_text())
    nodes = graph["nodes"]
    roads = {name: np.array([nodes[a], *knots, nodes[b]], float)
             for name, a, knots, b in graph["trails"]}
    forks = json.loads((DATA / "trail_forks.json").read_text())[str(layout)]
    paths = list(roads.values()) + [np.array(f["points"]) for pair in forks.values() for f in pair]
    paths.append(np.array([[55, 5, 214], [56, 5, 236], [49, 5, 257], [55, 5, 280]]))
    # District interiors are provided by separate scenes outside the surveyed GLB.
    quarry = xz(np.array(graph["districts"]["quarry"]))
    relay = xz(np.array(graph["districts"]["relay"]))
    districts = np.array([[[-27, -27], [26, 25]],
                          [quarry + [-79, -25], quarry + [-24, 9]],
                          [relay + [-25, -113], relay + [34, -24]],
                          [[-79, 224], [185, 552]]])
    starts = np.concatenate([xz(path[:-1]) for path in paths])
    ends = np.concatenate([xz(path[1:]) for path in paths])
    anchors = xz(np.array(list(nodes.values()) + [[55, 5, 214]], float))
    if survey is None:
        survey = Survey(ROOT / f"art/outer_valley/outer_land_{layout}.glb")
    tris = np.array([tri for cell in survey.ground.values() for tri in cell])
    ground = tris.min(axis=1), tris.max(axis=1)
    records = []
    for identifier, road, wet in PARCELS:
        # Layout 2's Orchard spillway crosses the South wash shoulders. Use the
        # western pilgrim path there so both approaches stay open.
        if layout == 2 and identifier == "south_pilgrim_rest":
            road = "Pilgrim stair"
        path = roads[road]
        options = []
        for index in range(1, len(path) - 1):
            start = path[index].copy()
            start[1] = survey.height(*xz(start)) + .045
            if np.linalg.norm(anchors - xz(start), axis=1).min() < 15.:
                continue
            delta = path[index + 1] - path[index - 1]
            base_angle = math.atan2(delta[2], delta[0])
            for angle in (90, -90, 65, -65, 115, -115, 45, -45, 135, -135):
                heading = base_angle + math.radians(angle)
                unit = np.array([math.cos(heading), 0., math.sin(heading)])
                for distance in (32., 38., 43.):
                    center = xz(start + unit * distance)
                    if identifier.startswith("east") and center[0] < 45:
                        continue
                    if identifier.startswith("south") and center[1] < 100:
                        continue
                    if np.any(np.all((center >= districts[:, 0] - RADIUS) &
                                     (center <= districts[:, 1] + RADIUS), axis=1)):
                        continue
                    if distance_to_paths(center, starts, ends).min() < RADIUS + 5:
                        continue
                    if np.linalg.norm(anchors - center, axis=1).min() < 36.:
                        continue
                    if any(np.linalg.norm(center - xz(np.array(r["center"]))) < 46. for r in records):
                        continue
                    # Preserve both possible fork spans and all other routes across the full spur.
                    crossing = False
                    for t in np.arange(8., distance, 3.):
                        p = xz(start + unit * t)
                        in_district = np.all((p >= districts[:, 0] - 2) &
                                             (p <= districts[:, 1] + 2), axis=1).any()
                        hits_court = any(np.linalg.norm(p - xz(np.array(r["center"]))) < RADIUS + 3.
                                         for r in records)
                        if in_district or hits_court or distance_to_paths(p, starts, ends).min() < 3.6:
                            crossing = True
                            break
                    if crossing:
                        continue
                    option = court_profile(survey, ground, start, unit, distance)
                    if option:
                        grade, profile = option
                        score = grade * 15 + distance * .005 + abs(abs(angle) - 90) * .001
                        options.append((score, index, profile))
        if not options:
            raise ValueError(f"No safe {identifier} clearing in layout {layout}")
        _, index, profile = min(options, key=lambda o: o[0])
        starts = np.vstack((starts, xz(profile[:-1])))
        ends = np.vstack((ends, xz(profile[1:])))
        points = np.round(profile, 3).tolist()
        records.append(dict(id=identifier, sector=identifier.split("_")[0], road=road,
                            road_index=index, approach_points=points, center=points[-1], wet=wet))
    return records
