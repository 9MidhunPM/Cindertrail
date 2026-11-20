extends SceneTree
## godot --headless --fixed-fps 60 -s tests/generated_journey.gd [-- --logical-only]

const LAYOUT := preload("res://scripts/world/journey_layout.gd")
const SITE_IDS := [&"broken_quarry", &"flooded_grove", &"fallen_relay", &"lanternwood",
	&"sunken_aqueduct", &"sunwatch_observatory", &"last_lantern_frontier"]
const GATES := preload("res://data/outer_valley/landmarks.json")
var failures := PackedStringArray()

func _initialize() -> void:
	_run.call_deferred()

func _require(ok: bool, detail: String) -> void:
	if not ok and not failures.has(detail):
		failures.append(detail)
		push_error(detail)

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame

func _run() -> void:
	var variants := {}
	var candidates := {}
	var topologies := {}
	var quarry_destinations := {}
	for seed_value in 1000:
		var layout = LAYOUT.generate(seed_value)
		var replay = LAYOUT.generate(seed_value)
		var restored = LAYOUT.restore(layout.checkpoint_fields())
		_require(restored != null and restored.layout_id == layout.layout_id and restored.clearings == layout.clearings,
			"Saved seed and explicitly selected placements must round-trip")
		_require(layout.layout_id == replay.layout_id and layout.clearings == replay.clearings, "Seed replay changed")
		var selected := PackedStringArray()
		for id in SITE_IDS:
			var variant: int = layout.clearings.get(id, -1)
			_require(variant in [0, 1], "Missing clearing for " + id)
			var key := "%s:%s" % [id, variant]
			selected.append(key)
			variants[key] = true
		selected.append("graph:%s" % layout.layout_id)
		candidates[seed_value] = selected
		if not topologies.has(layout.layout_id):
			var graph := CinderDistricts.graph(layout.layout_id)
			topologies[layout.layout_id] = _check_graph(graph)
			for trail: Array in graph.trails:
				if trail[0] == "Quarry switchback":
					quarry_destinations[trail[3]] = true
	_require(variants.size() == SITE_IDS.size() * 2, "All seven camps must have two variants in 1,000 seeds")
	var signatures := {}
	for signature: String in topologies.values():
		signatures[signature] = true
	_require(signatures.size() >= 3, "Expected three different trail adjacencies")
	_require(quarry_destinations.size() == 3, "The Quarry exit must lead toward three distinct named camps")
	print("1,000 seeds: ", topologies.size(), " graphs, ", variants.size(), " camp clearing choices.")
	if not OS.get_cmdline_user_args().has("--logical-only") and failures.is_empty():
		set_meta(&"direct_journey", true)
		set_meta(&"world_layout_version", 1)
		var covered := {}
		var junctions := {&"lanternwood": "west", &"sunken_aqueduct": "south", &"sunwatch_observatory": "east"}
		# Select a small, deterministic set of journeys covering all graphs and clearings.
		var positions := {}
		while covered.size() < variants.size() + topologies.size():
			var best_seed := -1
			var best_count := 0
			for candidate: int in candidates:
				var count := 0
				for token in candidates[candidate]:
					if not covered.has(token):
						count += 1
				if count > best_count:
					best_seed = candidate
					best_count = count
			if best_seed < 0:
				break
			set_meta(&"journey_seed", best_seed)
			change_scene_to_file("res://scenes/main.tscn")
			await scene_changed
			await _frames(8)
			var game = current_scene
			for site: CinderSite in game.sites:
				var key := "%s:%s" % [site.checkpoint_id, game.layout.clearings[site.checkpoint_id]]
				if junctions.has(site.checkpoint_id):
					var destination: Vector3 = game.outer_valley.junctions[junctions[site.checkpoint_id]]
					_require(site.anchor.global_position.distance_to(destination) < 15, "Landmark and camp disagree in " + site.label)
				if not covered.has(key):
					await _check_camp(game, site)
				if not positions.has(site.checkpoint_id):
					positions[site.checkpoint_id] = {}
				positions[site.checkpoint_id][site.anchor.global_position] = true
			for token in candidates[best_seed]:
				covered[token] = true
			print("Runtime coverage seed ", best_seed, " includes ", candidates[best_seed])
		for id in SITE_IDS:
			_require(positions.get(id, {}).size() >= 2, "Only one runtime shrine position for " + id)
	print("Generated journey failures ", failures)
	quit(0 if failures.is_empty() else 1)

func _check_graph(graph: Dictionary) -> String:
	var neighbors := {}
	var edges := PackedStringArray()
	for name: String in graph.nodes:
		neighbors[name] = []
	var gated := PackedStringArray()
	for gate: Dictionary in GATES.data.gates:
		gated.append(gate.trail)
	for trail: Array in graph.trails:
		var endpoints := PackedStringArray([trail[1], trail[3]])
		endpoints.sort()
		edges.append("/".join(endpoints))
		if not gated.has(trail[0]):
			neighbors[trail[1]].append(trail[3])
			neighbors[trail[3]].append(trail[1])
	for connection: Array in [["grove", "grove_north"], ["grove", "grove_west"], ["quarry", "quarry_gate"], ["relay", "relay_gate"]]:
		neighbors[connection[0]].append(connection[1])
		neighbors[connection[1]].append(connection[0])
	var seen := {"grove": true}
	var pending := ["grove"]
	while not pending.is_empty():
		var here: String = pending.pop_back()
		for next: String in neighbors[here]:
			if not seen.has(next):
				seen[next] = true
				pending.append(next)
	_require(seen.size() == neighbors.size(), "Unreachable junction with both shortcut gates closed")
	edges.sort()
	return "|".join(edges)

func _check_camp(game: Node, site: CinderSite) -> void:
	var anchor := site.anchor.global_position
	var label := site.label
	var world := site.get_world_3d().direct_space_state
	if site == game.grove:
		var crossing: Dictionary = game.grove_terrain.bell_road_sockets()
		for key in ["start", "end"]:
			var point: Vector3 = crossing[key]
			var ground := world.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP, point - Vector3.UP * .3, 1))
			_require(not ground.is_empty(), "Grove bell-road " + key + " has no dry landing")
		_require(crossing.ruin.distance_to(crossing.start) > 1 and crossing.ruin.distance_to(crossing.end) > 1,
			"Grove submerged ruin is separate from dry landings")
	for socket in site.sockets:
		var at := socket.global_position
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP, at - Vector3.UP * 0.65, 1)
		_require(not world.intersect_ray(ray).is_empty(), "Unreachable socket ground at %s in %s" % [at, label])
	for lane in site.lanes:
		_require(lane[-1].distance_to(anchor) < 1.0, label + " lane ends away from shrine")
	game.player.global_position = anchor + Vector3(0, 0.16, 1.1)
	game.player.velocity = Vector3.ZERO
	await _frames(4)
	game.interact()
	await _frames(90)
	_require(game.active_site == site and game.core.get_parent() == site.anchor, label + " deploy failed")
	if game.active_site != site:
		return
	var before := site.remaining_energy
	_require(game.start_wave(), label + " wave would not start")
	await _frames(55)
	_require(site.remaining_energy < before and not game.battle.enemies.is_empty(), label + " failed to draw energy under attack")
	Input.action_press("pack")
	await _frames(180)
	Input.action_release("pack")
	_require(game.core.form == SunCore.Form.CARRIED and game.core.get_parent() == game.player.visual.carry_anchor,
		label + " packing failed")
