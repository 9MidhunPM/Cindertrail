extends SceneTree
## Run with godot --headless --fixed-fps 60 --script tests/terrain_support.gd.

const REGION := preload("res://scenes/world/outer_valley.tscn")
const BELL := preload("res://scripts/world/drowned_bell_road.gd")
const GUARDIAN := preload("res://scripts/world/beacon_guardian.gd")
const TRAVELER := preload("res://scenes/player/traveler_visual.tscn")
const BRIDGES := ["aqueduct_towpath", "bellmakers_cut"]

var _failures := PackedStringArray()
var _samples := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for base in 4:
		for variant in (1 if base == 0 else 2):
			await _check_valley(base, variant)
	print("Terrain support sampled ", _samples, " points. Failures ", _failures)
	quit(0 if _failures.is_empty() else 1)

func _check_valley(base: int, variant: int) -> void:
	var world := Node3D.new()
	root.add_child(world)
	var journey := CinderJourneyLayout.generate(base - 1, 0 if base == 0 else 2)
	for id in CinderJourneyLayout.FORKS:
		journey.fork_variants[id] = variant
	for id in CinderJourneyLayout.TOWNS:
		journey.town_variants[id] = variant
	var grove := CinderGrove.new()
	var quarry := CinderQuarry.new()
	var relay := CinderRelay.new()
	quarry.layout_id = base
	relay.layout_id = base
	for district: Node3D in [grove, quarry, relay]:
		district.randomized_layout = base > 0
		district.clearing_variant = variant
		world.add_child(district)
	var outer: CinderOuterValley = REGION.instantiate()
	outer.layout_id = base
	outer.journey_layout = journey
	world.add_child(outer)
	outer.restore_shortcuts(PackedStringArray(BRIDGES))
	var frontier := CinderFrontier.new()
	frontier.randomized_layout = base > 0
	frontier.clearing_variant = variant
	world.add_child(frontier)
	var bell := BELL.new()
	grove.add_child(bell)
	bell.configure(variant)
	bell.apply_reserve(0, 25, false)
	var guardian := GUARDIAN.new()
	world.add_child(guardian)
	guardian.build(relay.beacon)
	await physics_frame
	await physics_frame
	var label := "Layout %d variant %d" % [base, variant]
	for i in outer.roads.size():
		_check_path(label + " " + outer.road_names[i], outer.roads[i], .75, 1.05)
	for group in [grove.map_paths(), quarry.map_paths(), relay.map_paths(), frontier.paths, guardian.site.lanes]:
		for path: PackedVector3Array in group:
			_check_path(label + " district", path, .70, .70)
	_check_path(label + " Bell Road", bell.route, .70, .80)
	for town: StringName in outer.town_side_paths:
		_check_path(label + " " + town, outer.town_side_paths[town], .36, .65)
	_check_quarry_slabs(label, quarry)
	_check_relay_handrail(label, relay)
	await _land_off_center(label, world, quarry.to_global(Vector3(-34.49, .9, 6.35)))
	world.free()

func _check_path(label: String, route: PackedVector3Array, shoulder: float, drop: float) -> void:
	for i in range(1, route.size()):
		var begin := route[i - 1]
		var end := route[i]
		var side := begin.direction_to(end).cross(Vector3.UP).normalized()
		var count := maxi(1, ceili(begin.distance_to(end) / .25))
		for j in range(count + 1):
			var along := begin.lerp(end, float(j) / count)
			for lane: float in [-1.0, 0.0, 1.0]:
				var foot := along + side * (shoulder * lane)
				var floor := _floor_y(foot)
				if not is_finite(floor) or floor < foot.y - drop:
					_failures.append("%s missing floor near %s" % [label, foot])
					return

func _floor_y(point: Vector3, headroom := 3.0) -> float:
	_samples += 1
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * headroom, point - Vector3.UP * 5.0, 1)
	var hit := root.world_3d.direct_space_state.intersect_ray(query)
	return INF if hit.is_empty() else float(hit.position.y)

func _check_quarry_slabs(label: String, quarry: CinderQuarry) -> void:
	var surfaces := PackedVector3Array([Vector3(-34.49, .9, 6.35), Vector3(-37.51, .9, 6.35)])
	for i in 3:
		surfaces.append(Vector3(-60.4 + i * 1.10, 1.15 + i * .21, -4.98))
	for i in 7:
		var height := 2.02 if i in [2, 6] else 1.70
		surfaces.append(Vector3(-48.6 + (i % 3) * .74, height, -4.5 - floorf(i / 3.0) * .86))
	for i in 5:
		surfaces.append(Vector3(-54.7 + i * 1.05, 3.81, -5.93))
	for local in surfaces:
		var top := quarry.to_global(local)
		if absf(_floor_y(top, .16) - top.y) > .03:
			_failures.append("%s missing visible Quarry slab at %s" % [label, top])

func _check_relay_handrail(label: String, relay: CinderRelay) -> void:
	var mid := CinderRelay.BEACON_TRAIL[1].lerp(CinderRelay.BEACON_TRAIL[2], .39)
	var from := relay.to_global(mid + Vector3.UP * .53)
	var outside := relay.to_global(mid + Vector3.UP * .53 + Vector3.RIGHT * 2.8)
	var test := PhysicsRayQueryParameters3D.create(from, outside, 1)
	var hit := root.world_3d.direct_space_state.intersect_ray(test)
	if hit.is_empty():
		_failures.append(label + " summit handrail allows a lateral crossing")
	var cliff := relay.to_global(CinderRelay.SUMMIT + Vector3(0, 0, 10))
	var distant_floor := _floor_y(cliff)
	if is_finite(distant_floor) and distant_floor >= cliff.y - 1.0:
		_failures.append(label + " summit cliff was filled beyond the walkway")

func _land_off_center(label: String, world: Node3D, floor: Vector3) -> void:
	var traveler := CinderPlayer.new()
	traveler.visual = TRAVELER.instantiate()
	traveler.add_child(traveler.visual)
	var camera := Camera3D.new()
	world.add_child(camera)
	traveler.camera = camera
	traveler.position = floor + Vector3.UP * .65
	traveler.recovery_point = floor + Vector3(0, .1, -1.2)
	world.add_child(traveler)
	for i in 45:
		await physics_frame
	if not traveler.is_on_floor() or traveler.position.distance_to(floor) > .10:
		_failures.append(label + " traveler fell through the visible Quarry alcove")
