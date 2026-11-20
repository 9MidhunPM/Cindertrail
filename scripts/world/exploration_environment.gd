extends Node3D
## Mounts modular towns and hard-edged forest pockets on the active valley graph.

const TOWN := preload("res://scripts/world/abandoned_town.gd")
const FOREST := preload("res://scripts/world/forest_dressing.gd")
const MARKS := [
	[&"western_arcade", "ruins", "Masons’ walk"],
	[&"bellmakers_steps", "terrace", "Gallery road"],
	[&"mineral_ward", "spring", "Tanners’ road"],
]

var _towns := {}

func build(junctions: Dictionary, town_variants: Dictionary, roads: Array, road_names: PackedStringArray, journey_seed: int) -> void:
	name = "ExplorationEnvironment"
	var clearings := PackedVector3Array()
	for record: Array in MARKS:
		var at: Vector3 = junctions[record[1]]
		var edge := road_names.find(record[2])
		var direction := _street_direction(roads[edge], at) if edge >= 0 else Vector3.FORWARD
		var town := TOWN.new()
		add_child(town)
		var variant := int(town_variants.get(record[0], 0))
		town.configure(record[0], variant, at, direction, roads)
		_towns[record[0]] = town
		clearings.append(at)
	for key in ["west", "south", "east", "grove", "quarry", "relay", "quarry_gate", "relay_gate"]:
		if junctions.has(key):
			clearings.append(junctions[key])
	var forest := FOREST.new()
	forest.name = "ForestDressing"
	add_child(forest)
	forest.build(roads, road_names, clearings, journey_seed)

func settlement_at(id: StringName) -> TOWN:
	return _towns.get(id)

func _street_direction(path: PackedVector3Array, at: Vector3) -> Vector3:
	if path.size() < 2:
		return Vector3.FORWARD
	var toward := path[1] if at.distance_to(path[0]) <= at.distance_to(path[-1]) else path[-2]
	return at.direction_to(toward).slide(Vector3.UP).normalized()
