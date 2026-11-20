#!/usr/bin/env python3
"""Bake the nine shrine clearings and their walk-in routes for each journey landscape."""
import json
import math

import numpy as np

import build_outer_valley as art
from build_trail_forks import Survey
from shrine_parcel_mesh import build_parcel
from survey_shrine_parcels import survey_layout


def parcel_record(survey):
    center = np.array(survey["center"], dtype=float)
    path = np.array(survey["approach_points"], dtype=float)
    toward_camp = center - path[-2]
    yaw = math.atan2(toward_camp[0], toward_camp[2])
    entry = center - 10.5 * np.array([math.sin(yaw), 0, math.cos(yaw)])
    # The final stretch belongs to the level court, including its retreat gate.
    access = [p for p in path if np.linalg.norm((p - center)[[0, 2]]) > 10.51]
    access.append(entry)
    return {
        "id": survey["id"],
        "sector": survey["sector"],
        "road": survey["road"],
        "road_index": survey["road_index"],
        "wet": survey["wet"],
        "center": np.round(center, 3).tolist(),
        "yaw": round(yaw, 6),
        "access": np.round(access, 3).tolist(),
    }


def main():
    regions = {}
    for layout_id in (1, 2, 3):
        survey = Survey(art.ROOT / f"art/outer_valley/outer_land_{layout_id}.glb")
        parcels = [parcel_record(row) for row in survey_layout(layout_id, survey)]
        assert len(parcels) == len({p["id"] for p in parcels}) == 9
        for sector in ("west", "east", "south"):
            members = [p for p in parcels if p["sector"] == sector]
            assert len(members) == 3 and any(p["wet"] for p in members)
        art.chunks.clear()
        for parcel in parcels:
            build_parcel(parcel, survey.height)
        art.gltf(art.ROOT / f"art/outer_valley/roaming_parcels_{layout_id}.glb")
        regions[str(layout_id)] = parcels
    index = art.ROOT / "data/outer_valley/roaming_parcels.json"
    index.write_text(json.dumps(regions, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
