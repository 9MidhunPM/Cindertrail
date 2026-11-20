extends SceneTree
## Run with godot --headless --fixed-fps 60 -s tests/outer_valley_walk.gd.

const REGION := preload("res://scenes/world/outer_valley.tscn")
const TRAVELER := preload("res://scenes/player/traveler_visual.tscn")
const GROVE := preload("res://scripts/world/grove.gd")
const QUARRY := preload("res://scripts/world/quarry.gd")
const RELAY := preload("res://scripts/world/relay.gd")
const CORE := preload("res://scenes/core/sun_core.tscn")
const UNITS := [preload("res://data/enemies/crawler.tres"), preload("res://data/enemies/brute.tres")]

var failures := PackedStringArray()
var pawn := CinderPlayer.new()
var camera := Camera3D.new()
var measured := 0.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.add_child(GROVE.new())
	var layout_id := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--layout="):
			layout_id = arg.trim_prefix("--layout=").to_int()
	var quarry := QUARRY.new()
	var relay := RELAY.new()
	quarry.layout_id = layout_id
	relay.layout_id = layout_id
	root.add_child(quarry)
	root.add_child(relay)
	var valley: CinderOuterValley = REGION.instantiate()
	valley.layout_id = layout_id
	root.add_child(valley)
	pawn.visual = TRAVELER.instantiate()
	pawn.add_child(pawn.visual)
	root.add_child(camera)
	root.add_child(pawn)
	pawn.camera = camera
	var closed_way := valley.route_between_nodes("ruins", "saddle")
	if closed_way.is_empty():
		failures.append("missing open detour from arcade to orchard")
	var ids := PackedStringArray(["aqueduct_towpath","bellmakers_cut"])
	for id in ids:
		var handle := valley.shortcut_handle(id)
		if valley.nearby_shortcut(handle).is_empty() or not valley.try_open_shortcut(handle):
			failures.append("inoperable winch " + id)
		if valley.try_open_shortcut(handle):
			failures.append("winch opens twice " + id)
	await create_timer(1.5).timeout
	var open_way := valley.route_between_nodes("ruins", "saddle")
	if open_way.size() >= closed_way.size() or open_way.is_empty():
		failures.append("opened towpath missing from route graph")
	var saved := valley.unlocked_shortcut_ids()
	valley.restore_shortcuts(PackedStringArray())
	if not valley.unlocked_shortcut_ids().is_empty():
		failures.append("winches retained on fresh start")
	valley.restore_shortcuts(saved)
	if saved.size() != 2 or valley.unlocked_shortcut_ids() != saved:
		failures.append("checkpoint winch round trip")
	for i in valley.roads.size() * 2:
		var index := i % valley.roads.size()
		var route := valley.roads[index].duplicate()
		var reverse := i >= valley.roads.size()
		if reverse:
			route.reverse()
		pawn.position = route[0] + Vector3.UP * .45
		pawn.recovery_point = pawn.position
		pawn.velocity = Vector3.ZERO
		for tick in 4:
			await physics_frame
		var distance := 0.
		for j in range(1,route.size()):
			distance += route[j-1].distance_to(route[j])
			if not await _walk(route[j]):
				failures.append("%s blocked after %s at %s toward %s" % [valley.road_names[index], j, pawn.position, route[j]])
				break
		if not reverse:
			measured += distance
		print("Reverse " if reverse else "Forward ", valley.road_names[index], "  ", snappedf(distance,.1), " m")
	# Cross all three seams from inside the original districts.
	var q := CinderDistricts.offset("quarry", layout_id)
	var r := CinderDistricts.offset("relay", layout_id)
	var entrances: Array[PackedVector3Array] = [
		PackedVector3Array([Vector3(-1,.68,19), Vector3(-1,.68,24.7), _onto_road(valley, "grove")]),
		PackedVector3Array([Vector3(-36,.92,2) + q, Vector3(-36,.92,6.5) + q, _onto_road(valley, "quarry")]),
		PackedVector3Array([Vector3(23.4,4.4,-51.4) + r, Vector3(28,3.88,-51.4) + r, _onto_road(valley, "relay")]),
		PackedVector3Array([Vector3(-15,.7,1), Vector3(-24.5,.68,1), _onto_road(valley, "grove_west")]),
		PackedVector3Array([Vector3(0,.7,-19), Vector3(0,.68,-24.5), _onto_road(valley, "grove_north")]),
		PackedVector3Array([_onto_road(valley, "quarry_gate"), Vector3(-24,.68,1) + q, Vector3(-28,.68,1) + q, Vector3(-39,1.0,2) + q]),
		PackedVector3Array([_onto_road(valley, "relay_gate"), Vector3(0,.68,-24) + r, Vector3(0,.68,-27) + r, Vector3(4,1.6,-34) + r]),
	]
	for seam in entrances:
		pawn.position = seam[0] + Vector3.UP * .32
		pawn.recovery_point = pawn.position
		pawn.velocity = Vector3.ZERO
		for f in 4:
			await physics_frame
		for point in seam.slice(1):
			if not await _walk(point):
				failures.append("existing district join stalled near %s toward %s" % [pawn.position, point])
				break
	Input.action_release("move_forward")
	Input.action_release("sprint")
	pawn.move_enabled = false
	var core: SunCore = CORE.instantiate()
	root.add_child(core)
	for site in valley.sites:
		core.transfer(site.anchor, SunCore.Form.DEPLOYED)
		for lane in site.lanes:
			for stats: CinderEnemyStats in UNITS:
				var unit := CinderEnemy.new()
				root.add_child(unit)
				unit.configure(stats,lane,site)
				var contact := false
				for frame in 1560:
					await physics_frame
					if unit.advance(core, 1./60.,1):
						contact = true
						break
				if not contact:
					failures.append("%s %s from %s stalled at %s" % [site.label,stats.resource_path,lane[0],unit.position])
				unit.queue_free()
		for socket in site.sockets:
			var query := PhysicsRayQueryParameters3D.create(socket.global_position + Vector3.UP, socket.global_position - Vector3.UP * .4, 1)
			if root.world_3d.direct_space_state.intersect_ray(query).is_empty():
				failures.append("missing socket terrain in " + site.label)
	print("Outer valley ", snappedf(measured,.01), " m / ", valley.roads.size(), " trails / ", valley.sites.size(), " camps. Failures ", failures)
	quit(1 if not failures.is_empty() else 0)

func _onto_road(valley: CinderOuterValley, node_id: String) -> Vector3:
	var start: Vector3 = valley.junctions[node_id]
	for road in valley.roads:
		if start.is_equal_approx(road[0]):
			return start.move_toward(road[1], 6)
		if start.is_equal_approx(road[-1]):
			return start.move_toward(road[-2], 6)
	return Vector3.INF

func _walk(point: Vector3) -> bool:
	var initial := pawn.position.distance_to(point)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for frame in ceili(initial / 5.0 * 60.) + 180:
		await physics_frame
		var direction := point - pawn.position
		direction.y = 0.
		if direction.length() < .43:
			return absf(point.y - pawn.position.y) < .9
		camera.rotation.y = atan2(-direction.x, -direction.z)
	return false
