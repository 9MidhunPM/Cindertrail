extends "res://tests/outer_valley_walk.gd"
## Survey fixtures cover the two street compositions on all three baked landscapes,
## including both possible approaches to Mineral Ward.

func _run() -> void:
	pawn.visual = TRAVELER.instantiate()
	pawn.add_child(pawn.visual)
	root.add_child(camera)
	root.add_child(pawn)
	pawn.camera = camera
	var passed := 0
	for base in range(1, 4):
		for choice in 2:
			for fork in 2:
				var layout := CinderJourneyLayout.generate(base - 1)
				for town in layout.TOWNS:
					layout.town_variants[town] = choice
				for id in layout.FORKS:
					layout.fork_variants[id] = fork
				var valley: CinderOuterValley = REGION.instantiate()
				valley.layout_id = base
				valley.journey_layout = layout
				root.add_child(valley)
				await physics_frame
				await physics_frame
				for town: StringName in layout.TOWNS:
					if fork == 1 and town != &"mineral_ward":
						continue
					var path: PackedVector3Array = valley.town_side_paths[town]
					var cache_id: String = valley.TOWN_WALKS.CACHE_IDS[town]
					var cache_index := valley.cache_ids.find(cache_id)
					var feature: Node3D = valley.abandoned_towns.settlement_at(town)
					var cache := valley.caches[cache_index]
					var near_discovery := false
					for point: Vector3 in feature.discovery_points:
						near_discovery = near_discovery or point.slide(Vector3.UP).distance_to(cache.slide(Vector3.UP)) < 2.3
					if not near_discovery or not path.has(cache) or valley.cache_ids.count(cache_id) != 1:
						failures.append("Cache missing from town discovery: %s %d/%d/%d" % [town, base, choice, fork])
					if path[0].distance_to(path[-1]) < 5:
						failures.append("Street has no distinct exit in " + town)
					pawn.position = path[0] + Vector3.UP * .20
					pawn.recovery_point = pawn.position
					pawn.velocity = Vector3.ZERO
					for i in 5:
						await physics_frame
					var ok := true
					for point: Vector3 in path.slice(1):
						if not await _walk(point):
							failures.append("%s %d/%d/%d traveler stuck %s approaching %s" % [town, base, choice, fork, pawn.position, point])
							ok = false
							break
					Input.action_release("move_forward")
					Input.action_release("sprint")
					if ok:
						passed += 1
				valley.free()
	print("Walked ", passed, " town cache loops; failures ", failures)
	quit(0 if failures.is_empty() else 1)
