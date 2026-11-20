class_name CinderDistricts
extends RefCounted
## The graph and its corresponding offline-baked landscape share a layout ID.
## ID zero is reserved for journeys made before the valley gained variants.

const GRAPHS := [
	preload("res://data/outer_valley/trails.json"),
	preload("res://data/outer_valley/layout_1.json"),
	preload("res://data/outer_valley/layout_2.json"),
	preload("res://data/outer_valley/layout_3.json"),
]

static func layout_for_seed(journey_seed: int) -> int:
	return 1 + posmod(journey_seed, GRAPHS.size() - 1)

static func graph(layout_id: int) -> Dictionary:
	return GRAPHS[layout_id].data

static func offset(district: String, layout_id: int = 0) -> Vector3:
	var value: Array = graph(layout_id).districts.get(district, [0, 0, 0])
	return Vector3(value[0], value[1], value[2])

static func landscape_path(layout_id: int) -> String:
	if layout_id == 0:
		return "res://art/outer_valley/outer_land.glb"
	return "res://art/outer_valley/outer_land_%d.glb" % layout_id
