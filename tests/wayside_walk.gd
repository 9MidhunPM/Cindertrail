extends "res://tests/outer_valley_walk.gd"
## godot --headless --fixed-fps 60 --script tests/wayside_walk.gd

const SEEDS := [80, 81, 82, 149, 150, 151, 421103, 80]
const CACHE_LIMIT := 3

func _run() -> void:
	pawn.visual = TRAVELER.instantiate()
	pawn.add_child(pawn.visual)
	root.add_child(camera)
	root.add_child(pawn)
	pawn.camera = camera
	var first := []
	var checked := 0
	var minimum_stops := 1000
	for seed_value: int in SEEDS:
		var valley := REGION.instantiate() as CinderOuterValley
		var layout := CinderJourneyLayout.generate(seed_value)
		valley.journey_layout = layout
		valley.layout_id = layout.layout_id
		valley.clearing_variants = layout.clearings
		root.add_child(valley)
		for tick in 4:
			await physics_frame
		var dress := valley.wayside_dressing
		minimum_stops = mini(minimum_stops, dress.stops.size())
		if dress.stops.size() < 40 or dress.discoveries.size() != CACHE_LIMIT:
			failures.append("Too few features or side trails in seed " + str(seed_value))
		var dressed_roads := {}
		for stop in dress.stops:
			dressed_roads[String(stop.id).get_slice("_", 1).to_int()] = true
			for parcel: Dictionary in layout.parcel_definitions(layout.layout_id):
				var coordinates: Array = parcel.center
				var center := Vector3(coordinates[0], coordinates[1], coordinates[2])
				if stop.center.slide(Vector3.UP).distance_to(center.slide(Vector3.UP)) < 18.0:
					failures.append("Scenery overlaps a reserved shrine clearing in seed " + str(seed_value))
		for index in valley.roads.size():
			var path := valley.roads[index]
			var length := 0.0
			for knot in range(1, path.size()):
				length += path[knot - 1].distance_to(path[knot])
			if length >= 60.0 and not dressed_roads.has(index):
				failures.append("Long road has no wayside stop: " + valley.road_names[index])
		if seed_value == SEEDS[0]:
			var fingerprint := [dress.stops, dress.discoveries].duplicate(true)
			if first.is_empty():
				first = fingerprint
			elif fingerprint != first:
				failures.append("Reload moved a wayside stop or its cache")
		for cache: Dictionary in dress.discoveries:
			var path: PackedVector3Array = cache.path
			pawn.position = path[0] + Vector3.UP * .14
			pawn.recovery_point = pawn.position
			pawn.velocity = Vector3.ZERO
			for point in path.slice(1):
				if not await _walk(point):
					failures.append("Cannot walk from road to %s (seed %d)" % [cache.id, seed_value])
					break
			if pawn.position.distance_to(cache.point) >= 2.3:
				failures.append("Supply cache %s is out of interaction range" % cache.id)
			path.reverse()
			for point in path.slice(1):
				if not await _walk(point):
					failures.append("Cannot return to the road from %s (seed %d)" % [cache.id, seed_value])
					break
			checked += 1
			Input.action_release("move_forward")
			Input.action_release("sprint")
		valley.free()
	print("Waysides ", minimum_stops, " minimum stops per seed. Walked ", checked,
		" side spurs both ways. Failures ", failures)
	quit(0 if failures.is_empty() else 1)
