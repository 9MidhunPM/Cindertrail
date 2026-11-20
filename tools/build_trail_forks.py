#!/usr/bin/env python3
"""Bake the six possible fork spans on each existing valley. Run after build_outer_valley.py.

The fixed road knots choose the destinations. The survey tests a small family of bows
against the shipped landscape meshes to clear tree trunks and seat both dry landings.
Output consists of ordinary imported static scenes and the matching map coordinates.
"""
import json
import math
import struct
from collections import defaultdict
from pathlib import Path

import numpy as np

import build_outer_valley as art

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art/outer_valley/forks"
# Every index refers to the full polyline including both named junctions.
FORKS = [
    ("pilgrims_cross", ("Grove causeway", -2), [
        ("Limeburners’ Crossing", ("Masons’ walk", -3), -5, "limestone"),
        ("Founders’ Walk", ("Bellmakers’ cut", -3), 4, "copper")]),
    ("orchard_pass", ("High orchard", -2), [
        ("Cider Press Run", ("Pilgrim stair", 1), 5, "timber"),
        ("Drovers’ Ridge", ("South wash", -2), -3, "limestone")]),
    ("mineral_spring", ("Tanners’ road", -2), [
        ("Ochre Flume", ("Eastern escarpment", 1), 5, "copper"),
        ("Salters’ Walk", ("Spice road", 1), 1, "timber")]),
]


class Survey:
    def __init__(self, path):
        data = path.read_bytes()
        metadata_size = struct.unpack_from("<I", data, 12)[0]
        gltf = json.loads(data[20:20 + metadata_size])
        binary = memoryview(data)[28 + metadata_size:]
        self.ground = defaultdict(list)
        obstacles = []
        for node in gltf["nodes"]:
            name = node["name"]
            if not name.endswith("-col"):
                continue
            prim = gltf["meshes"][node["mesh"]]["primitives"][0]
            acc = gltf["accessors"][prim["attributes"]["POSITION"]]
            view = gltf["bufferViews"][acc["bufferView"]]
            triangles = np.frombuffer(binary, "<f4", acc["count"] * 3,
                                      view["byteOffset"]).reshape(-1, 3, 3) + node["translation"]
            if name.startswith("Ground"):
                for tri in triangles:
                    key = tuple(np.floor(tri[:, [0, 2]].mean(axis=0) / 4).astype(int))
                    self.ground[key].append(tri)
            else:
                obstacles.append(triangles)
        props = np.concatenate(obstacles)
        self.lo, self.hi = props.min(axis=1), props.max(axis=1)

    def height(self, x, z):
        ix, iz = math.floor(x / 4), math.floor(z / 4)
        for dx in [-1, 0, 1]:
            for dz in [-1, 0, 1]:
                for tri in self.ground.get((ix + dx, iz + dz), []):
                    a, b, c = tri
                    ab, ac = b - a, c - a
                    det = ab[0] * ac[2] - ab[2] * ac[0]
                    u = ((x - a[0]) * ac[2] - (z - a[2]) * ac[0]) / det
                    v = (ab[0] * (z - a[2]) - ab[2] * (x - a[0])) / det
                    if min(u, v, 1 - u - v) >= -1e-6:
                        return a[1] + u * ab[1] + v * ac[1]
        raise ValueError(f"Fork left the baked landscape at {(x, z)}")

    def profile(self, start, end, bow):
        delta = end - start
        side = np.array([-delta[2], 0, delta[0]]) / np.linalg.norm(delta[[0, 2]])
        n = max(12, math.ceil(np.linalg.norm(delta) / 1.9))
        # Filtering first keeps each survey limited to the nearby chunks.
        lower, upper = np.minimum(start, end) - 20, np.maximum(start, end) + 20
        mask = np.all((self.hi >= lower) & (self.lo <= upper), axis=1)
        lo, hi = self.lo[mask], self.hi[mask]
        best, best_score = [], math.inf
        for offset in [bow, bow + 3, bow - 3, bow + 7, bow - 7, bow + 11, bow - 11]:
            profile = []
            score = abs(offset - bow) * .14
            for t in np.linspace(0, 1, n + 1):
                arch = math.sin(t * math.pi)
                p = start + delta * t + side * arch * offset
                heights = [self.height(*(p + side * i)[[0, 2]]) for i in (-.95, 0, .95)]
                p[1] = heights[1] + arch * (max(heights) - heights[1] + 1.05) + .035
                radius = np.array([1.32, 0, 1.32])
                occupied = np.all((lo < p + radius + [0, 2.1, 0]) & (hi > p - radius), axis=1)
                score += min(100, occupied.sum()) * 4
                profile.append(p)
            if score < best_score:
                best, best_score = profile, score
        return np.array(best)


def model(profile, style):
    art.chunks.clear()
    up = art.UP
    axes = np.diff(profile, axis=0)
    sides = np.cross(axes, up)
    sides /= np.linalg.norm(sides, axis=1)[:, None]
    miters = [sides[0]]
    for a, b in zip(sides[:-1], sides[1:]):
        side = (a + b) / np.linalg.norm(a + b)
        miters.append(side / max(.75, side @ b))
    miters.append(sides[-1])
    stone = art.pal("#b9ad92")
    shadow = art.pal("#697a79")
    copper = art.pal("#a87146")
    moss = art.pal("#71917c")
    timber = [art.pal(c) for c in ["#976a47", "#c18d60", "#ab7953"]]
    for i, (a, b) in enumerate(zip(profile[:-1], profile[1:])):
        sa, sb = miters[i], miters[i + 1]
        half = 1.39 if style == "limestone" else 1.25
        def quad(t0, t1, x0, x1, lift, color, group="Detail"):
            points = []
            for t, x in ((t0, x0), (t0, x1), (t1, x1), (t1, x0)):
                points.append(a + (b - a) * t + (sa + (sb - sa) * t) * x + up * lift)
            art.panel(*points, color, group, up)
        # A single continuous collision surface lies immediately below the dressed boards.
        quad(0, 1, -half, half, 0, shadow, "Deck")
        for sign in [-1, 1]:
            e, f = a + sa * half * sign, b + sb * half * sign
            art.panel(e, f, f-up*.27, e-up*.27, shadow if style == "limestone" else copper,
                      "Detail", (sa+sb)*sign)
        rows = 5 if style == "timber" else 2
        lanes = 1 if style == "timber" else 2
        for row in range(rows):
            for lane in range(lanes):
                material = timber[(i + row) % 3] if style == "timber" else (moss if (i+lane*3)%9==0 else stone)
                quad((row + .035)/rows, (row + .965)/rows, -half + 2*half*lane/lanes + .028,
                     -half + 2*half*(lane+1)/lanes - .028, .022, material)
        if i % 3 == 0 and 1 < i < len(axes) - 1:
            forward = np.cross(up, sides[i]); axes_local = (sides[i], up, forward)
            for sign in [-1, 1]:
                foot = a + sides[i]*sign*(half-.10)
                art.block(foot-up*.81, (.17,.90,.23), shadow, axes_local, "Detail")
                art.block(foot+up*.28, (.12,.31,.14), copper if style == "copper" else stone, axes_local, "Detail")
                art.block(foot+up*.59, (.17,.055,.19), copper, axes_local, "Detail")
                if style == "limestone":
                    art.block(foot+up*.66, (.12,.05,.14), stone, axes_local, "Detail")
                elif i + 3 < len(axes) - 1:
                    other = profile[i+3]+sides[i+3]*sign*(half-.10)
                    art.beam(foot+up*.53, other+up*.53, .045, .045, copper, 6)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    definitions = {}
    for layout in range(1, 4):
        source = ROOT / f"data/outer_valley/layout_{layout}.json"
        graph = json.loads(source.read_text())
        roads = {name: np.array([graph['nodes'][a], *via, graph['nodes'][b]], float)
                 for name, a, via, b in graph['trails']}
        survey = Survey(ROOT / f"art/outer_valley/outer_land_{layout}.glb")
        choices = {}
        for fork, start, destinations in FORKS:
            choices[fork] = []
            for index, (name, end, bow, style) in enumerate(destinations):
                a, b = roads[start[0]][start[1]], roads[end[0]][end[1]]
                profile = survey.profile(a, b, bow)
                model(profile, style)
                asset = OUT / f"{layout}_{fork}_{index}.glb"
                art.gltf(asset)
                choices[fork].append({"name": name, "start": list(start), "end": list(end),
                                      "scene": "res://" + str(asset.relative_to(ROOT)),
                                      "points": np.round(profile, 3).tolist()})
        definitions[str(layout)] = choices
    (ROOT / "data/outer_valley/trail_forks.json").write_text(json.dumps(definitions, separators=(',', ':')) + '\n')


if __name__ == "__main__":
    main()
