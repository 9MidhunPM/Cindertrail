class_name CinderDistricts
extends RefCounted
## Placement of the hand-built Quarry and Relay districts in the valley.
## The outer-valley baker reads the same offsets, so the joining trails meet them.

const LAYOUT := preload("res://data/outer_valley/trails.json")

static func offset(district: String) -> Vector3:
	var value: Array = LAYOUT.data.get("districts", {}).get(district, [0, 0, 0])
	return Vector3(value[0], value[1], value[2])
