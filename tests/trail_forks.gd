extends "res://tests/outer_valley_walk.gd"
## 1,000 layouts plus all 18 fork scenes walked in both directions on their own terrain.

func _run() -> void:
	var combinations := {}
	var fixtures := {}
	var town_patterns := {}
	for seed_value in 1000:
		var layout := CinderJourneyLayout.generate(seed_value)
		var record := layout.checkpoint_fields()
		if not layout.matches_selection(record) or not CinderJourneyLayout.generate(seed_value).matches_selection(record):
			failures.append("Failed to replay seed %d" % seed_value)
		var forks := layout.fork_variants.values()
		var pattern := "%s/%s" % [layout.layout_id, forks]
		combinations[pattern] = true
		town_patterns["%s/%s" % [layout.layout_id, layout.town_variants.values()]] = true
		if forks[0] == forks[1] and forks[1] == forks[2] and not fixtures.has(pattern):
			fixtures[pattern] = seed_value
	var original := CinderJourneyLayout.generate(42, 1)
	if CinderJourneyLayout.restore(original.checkpoint_fields()).version != 1 or not original.fork_variants.is_empty():
		failures.append("Version 1 layout migrated unexpectedly")
	if CinderJourneyLayout.restore({"journey_seed": 42}).layout_id != 0:
		failures.append("Legacy layout migrated unexpectedly")
	var current := CinderJourneyLayout.generate(42)
	var changed := current.checkpoint_fields()
	changed.town_variants[&"mineral_ward"] ^= 1
	if current.matches_selection(changed):
		failures.append("Fingerprint ignored town selection")
	changed = current.checkpoint_fields()
	changed.fork_variants.erase(&"orchard_pass")
	if CinderJourneyLayout.restore(changed) != null:
		failures.append("Accepted missing v2 fork")
	if town_patterns.size() != 24:
		failures.append("Expected eight independent town combinations on each landscape")
	if combinations.size() != 24 or fixtures.size() != 6:
		failures.append("Expected eight independent fork topologies on each of the three landscapes")
	print("1,000 seeds / ", combinations.size(), " fork topologies / ", town_patterns.size(), " town combinations / six walk fixtures ", fixtures.values())
	if not OS.get_cmdline_user_args().has("--logical-only"):
		pawn.visual = TRAVELER.instantiate()
		pawn.add_child(pawn.visual)
		root.add_child(camera)
		root.add_child(pawn)
		pawn.camera = camera
		for seed_value: int in fixtures.values():
			await _check_world(seed_value)
	print("Valley fork failures ", failures)
	quit(1 if not failures.is_empty() else 0)

func _check_world(seed_value: int) -> void:
	var layout := CinderJourneyLayout.generate(seed_value)
	var valley: CinderOuterValley = REGION.instantiate()
	valley.journey_layout = layout
	valley.layout_id = layout.layout_id
	valley.clearing_variants = layout.clearings
	root.add_child(valley)
	await physics_frame
	await physics_frame
	for id: String in layout.FORKS:
		var fork: Dictionary = valley.active_forks[id]
		var route: PackedVector3Array = fork.points
		var alternative := "%s_landing_%d" % [id, 1 - int(layout.fork_variants[id])]
		if valley.junctions.has(alternative) or not valley.road_names.has(fork.name):
			failures.append("Map does not match active fork: " + fork.name)
		var found := valley.route_between_nodes(fork.start, fork.end)
		if found.is_empty() or not found.has(route[route.size() / 2]):
			failures.append("Branch missing from shortest open route: %s layout %d" % [fork.name, layout.layout_id])
		for reverse in [false, true]:
			if reverse:
				route = route.duplicate()
				route.reverse()
			pawn.global_position = route[0] + Vector3.UP * .22
			pawn.recovery_point = pawn.global_position
			pawn.velocity = Vector3.ZERO
			for tick in 6:
				await physics_frame
			for at: Vector3 in route.slice(1):
				if not await _walk(at):
					failures.append("%s layout %d reverse %s stuck %s approaching %s" % [fork.name, layout.layout_id, reverse, pawn.global_position, at])
					break
			Input.action_release("move_forward")
			Input.action_release("sprint")
		print("Walked ", layout.layout_id, " / ", fork.name)
	# Splitting the Bellmakers’ road at its new landing must leave the gated section closed.
	var before := valley.route_between_nodes("cross", "terrace")
	valley.try_open_shortcut(valley.shortcut_handle("bellmakers_cut"))
	var after := valley.route_between_nodes("cross", "terrace")
	if before.is_empty() or after.is_empty() or _distance(after) >= _distance(before):
		failures.append("Split trail lost its Bellmakers’ winch on layout %d" % layout.layout_id)
	valley.free()

func _distance(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total
