extends SceneTree
## godot --headless --fixed-fps 60 -s tests/roaming_shrines.gd [-- --logical-only]
const LAYOUT := preload("res://scripts/world/journey_layout.gd")
const ROAM := preload("res://scripts/world/roaming_shrines.gd")
var failures := PackedStringArray()

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok and not failures.has(message):
		failures.append(message)
		push_error(message)

func _run() -> void:
	var sectors := {}
	var positions := {}
	var counts := {}
	var parcels := {}
	for base in range(1, 4):
		parcels[base] = {}
		counts[base] = 0
		for parcel: Dictionary in ROAM.parcel_definitions(base):
			parcels[base][parcel.id] = parcel
		for id: StringName in LAYOUT.CAMPS:
			var key := "%d/%s" % [base, id]
			sectors[key] = {}
			positions[key] = {}
	var previous := {}
	for seed_value in 3000:
		var layout := LAYOUT.generate(seed_value, 3)
		var record := layout.checkpoint_fields()
		var restored := LAYOUT.restore(record)
		_check(restored != null and record == restored.checkpoint_fields(), "Save record must restore exactly")
		_check(record == LAYOUT.generate(seed_value, 3).checkpoint_fields(), "Identical seed must rebuild exact placements")
		var chosen := LAYOUT.generate(seed_value, 3, previous)
		var used := {}
		var base := layout.layout_id
		counts[base] += 1
		for id: StringName in LAYOUT.CAMPS:
			var placement: Dictionary = layout.roaming_placements[id]
			_check(not used.has(placement.parcel), "Two shrines share a parcel")
			used[placement.parcel] = true
			var parcel: Dictionary = parcels[base][placement.parcel]
			_check(id != &"flooded_grove" or parcel.wet, "Grove selected a dry parcel")
			var key := "%d/%s" % [base, id]
			sectors[key][parcel.sector] = true
			positions[key][placement.offset] = true
			if not previous.is_empty():
				_check(chosen.roaming_placements[id].parcel != previous.roaming_placements[id].parcel,
					"A new journey reused the previous parcel for " + id)
		previous = chosen.checkpoint_fields()
	for base: int in counts:
		_check(counts[base] == 1000, "Seed sweep covers each base map 1,000 times")
	for key in sectors:
		_check(sectors[key].size() == 3, "Expected three different sectors for " + key)
		_check(positions[key].size() >= 100, "Expected continuous pad placement for " + key)
	for version in range(3):
		var original := LAYOUT.generate(34519, version)
		var record := original.checkpoint_fields()
		var restored := LAYOUT.restore(record)
		_check(not record.has("roaming_placements") and restored != null and restored.checkpoint_fields() == record,
			"Existing v%d journey retains its geography" % version)
	var duplicate := previous.duplicate(true)
	duplicate.roaming_placements[LAYOUT.CAMPS[1]] = duplicate.roaming_placements[LAYOUT.CAMPS[0]]
	_check(LAYOUT.restore(duplicate) == null, "Duplicate saved parcel must be rejected")
	print("ROAMING_LOGICAL 3000 seeds, 7 camps x 3 sectors on each base map, deterministic offsets and saved placements")
	if failures.is_empty() and not OS.get_cmdline_user_args().has("--logical-only"):
		set_meta(&"direct_journey", true)
		await _verify_older_scenes()
		set_meta(&"world_layout_version", 3)
		for seed_value in [0, 1, 2]:
			set_meta(&"journey_seed", seed_value)
			# Each encounter starts with a fresh core and enemy roster. Position jumps
			# between unrelated travel spurs must not carry pursuers into this fixture.
			for camp_id: StringName in LAYOUT.CAMPS:
				change_scene_to_file("res://scenes/main.tscn")
				await scene_changed
				await _frames(8)
				await _verify_scene(current_scene, camp_id)
	print("ROAMING_RESULT ", failures)
	quit(0 if failures.is_empty() else 1)

func _verify_older_scenes() -> void:
	set_meta(&"journey_seed", 80)
	var original_clearings := {}
	for version in range(3):
		set_meta(&"world_layout_version", version)
		change_scene_to_file("res://scenes/main.tscn")
		await scene_changed
		var game = current_scene
		_check(game.layout.version == version and game.sites.size() == 7, "Loaded historical journey version %d" % version)
		for site: CinderSite in game.sites:
			_check(site.parcel_id.is_empty(), "Historical journey moved " + site.label)
			if version == 1:
				original_clearings[site.checkpoint_id] = site.anchor.global_position
			elif version == 2:
				_check(site.anchor.global_position == original_clearings[site.checkpoint_id], "Unexpected moved v2 camp " + site.label)
		if version == 0:
			_check(game.grove.anchor.global_position.is_equal_approx(Vector3(0, .73, 0)), "Original Grove pad moved")

func _frames(n: int) -> void:
	for tick in n:
		await physics_frame

func _verify_scene(game: Node, camp_id: StringName) -> void:
	var core: SunCore = game.core
	var opening: Vector3 = game.player.global_position
	var encounters := 0
	_check(game.sites.size() == 7, "Exactly seven extraction sites in the generated scene")
	for site: CinderSite in game.sites:
		if site.checkpoint_id != camp_id:
			continue
		var expected: Dictionary = game.layout.roaming_placements[site.checkpoint_id]
		if site.parcel_id != expected.parcel:
			_check(false, "Unrelocated runtime site " + site.label)
			continue
		var center := site.anchor.global_position
		var reading: Dictionary = game.objective_route.direction_to(opening, center)
		_check(reading.point.is_finite() and reading.distance >= opening.distance_to(center) - .02,
			"Objective route must connect the Grove entrance and " + site.label)
		_check(center.is_equal_approx(site.parcel_frame * (expected.offset as Vector3)), "Runtime position does not match checkpoint for " + site.label)
		var space := site.get_world_3d().direct_space_state
		for pad in site.sockets:
			_check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(pad.global_position + Vector3.UP * .45,
				pad.global_position - Vector3.UP * .35, 1)).is_empty(), "Unsupported socket " + site.label)
		for lane in site.lanes:
			_check(lane[-1].distance_to(center) < .1, "Lane does not reach moved anchor " + site.label)
			_probe_lane(space, lane, site.label)
		var path := site.approach
		_check(path.size() >= 3 and path[-1].distance_to(center) < .2, "Road does not lead to the saved pad " + site.label)
		game.player.global_position = path[0] + Vector3.UP * .15
		game.player.velocity = Vector3.ZERO
		await _frames(5)
		for point in path.slice(1):
			if not await _walk(game, point):
				_check(false, "Could not walk to %s at %s (stalled at %s)" % [site.label, point, game.player.global_position])
				break
		game.interact()
		await _frames(95)
		if game.active_site != site:
			_check(false, "Interaction did not deploy " + site.label)
			continue
		_check(game.start_wave(), "Failed to start encounter at " + site.label)
		await _frames(64)
		if site.checkpoint_id == &"flooded_grove":
			var before := core.health
			for tick in 720:
				if core.health < before:
					break
				await physics_frame
			_check(core.health < before, "An actual wave must reach and damage the deployed core")
		_check(core.get_parent() == site.anchor and site.remaining_energy < site.spec.energy, "No extraction at " + site.label)
		Input.action_press("pack")
		await _frames(180)
		Input.action_release("pack")
		_check(core.form == SunCore.Form.CARRIED and core.get_parent() == game.player.visual.carry_anchor, "Did not pack original core at " + site.label)
		_check(await _walk(game, site.recovery_point), "Failed to retreat from " + site.label)
		encounters += 1
	_check(encounters == 1, "Expected one working camp for " + camp_id)
	print("ROAMING_RUNTIME base ", game.layout.layout_id, " camp ", camp_id, " encounter count ", encounters, " failures ", failures.size())

func _probe_lane(space: PhysicsDirectSpaceState3D, lane: PackedVector3Array, label: String) -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = .43
	capsule.height = 1.5
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	for index in range(1, lane.size()):
		var start := lane[index - 1]
		var end := lane[index]
		var samples := ceili(start.distance_to(end))
		for n in samples:
			var point := start.lerp(end, float(n) / samples)
			var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * .35, point - Vector3.UP * .4, 1))
			_check(not ground.is_empty(), "Unsupported enemy lane at %s in %s" % [point, label])
		query.transform = Transform3D(Basis.IDENTITY, start + Vector3.UP * .90)
		query.motion = end - start
		var cast := space.cast_motion(query)
		_check(cast.size() > 0 and cast[0] >= .999, "Brute lane obstructed between %s and %s in %s" % [start, end, label])

func _walk(game: Node, target: Vector3) -> bool:
	var budget := ceili(game.player.global_position.distance_to(target) / 3.0 * 60) + 120
	var arrived := false
	for tick in budget:
		var heading: Vector3 = (target - game.player.global_position).slide(Vector3.UP)
		if heading.length() < .45:
			arrived = absf(target.y - game.player.global_position.y) < .7
			break
		var forward: Vector3 = -game.camera.global_basis.z.slide(Vector3.UP).normalized()
		var right: Vector3 = game.camera.global_basis.x.slide(Vector3.UP).normalized()
		var vector := heading.normalized()
		var axes := {"move_forward": forward.dot(vector), "move_back": -forward.dot(vector),
			"move_right": right.dot(vector), "move_left": -right.dot(vector)}
		for action: String in axes:
			if axes[action] > 0:
				Input.action_press(action, axes[action])
			else:
				Input.action_release(action)
		await physics_frame
	for action in ["sprint", "move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(action)
	return arrived
