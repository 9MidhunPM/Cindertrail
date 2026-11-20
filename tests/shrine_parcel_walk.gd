extends SceneTree
## Walk every baked side trail, including the transition from the original road.

const CATALOGUE := "res://data/outer_valley/roaming_parcels.json"
var pawn := CinderPlayer.new()
var view := Camera3D.new()
var failures := PackedStringArray()
var walked := 0
var disc_samples := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var data: Dictionary = (load(CATALOGUE) as JSON).data
	var regions := range(1, 4)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--layout="):
			regions = [int(arg.trim_prefix("--layout="))]
	root.add_child(view)
	root.add_child(pawn)
	pawn.camera = view
	for region_id in regions:
		var land := (load(CinderDistricts.landscape_path(region_id)) as PackedScene).instantiate()
		var terrain := (load("res://art/outer_valley/roaming_parcels_%d.glb" % region_id) as PackedScene).instantiate()
		root.add_child(land)
		root.add_child(terrain)
		await physics_frame
		await physics_frame
		for parcel: Dictionary in data[str(region_id)]:
			await _walk_parcel(region_id, parcel)
		land.free()
		terrain.free()
		await physics_frame
	print("Shrine parcel travel: ", walked, " directed walks, ", disc_samples, " floor samples, failures ", failures)
	quit(0 if failures.is_empty() else 1)

func _walk_parcel(layout_id: int, parcel: Dictionary) -> void:
	var path := PackedVector3Array()
	var graph := CinderDistricts.graph(layout_id)
	for road: Array in graph.trails:
		if road[0] == parcel.road:
			var knots: Array = [graph.nodes[road[1]]] + road[2] + [graph.nodes[road[3]]]
			var index := int(parcel.road_index)
			path.append(_v(knots[index]).move_toward(_v(knots[index - 1]), 2.5))
			break
	for point: Array in parcel.access:
		path.append(_v(point))
	var center := _v(parcel.center)
	path.append(center)
	var title := "%d/%s" % [layout_id, parcel.id]
	for radius in [0., 4., 8., 11.9]:
		var count := 1 if radius == 0. else 16
		for i in count:
			var theta := TAU * i / count
			var p := center + Vector3(cos(theta), 0., sin(theta)) * float(radius)
			var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * .15, p - Vector3.UP * .15, 1)
			if root.world_3d.direct_space_state.intersect_ray(query).is_empty():
				failures.append("%s unsupported court at %s" % [title, p])
			disc_samples += 1
	for reverse in [false, true]:
		if reverse:
			path.reverse()
		Input.action_release("move_forward")
		pawn.global_position = path[0] + Vector3.UP * .2
		pawn.recovery_point = pawn.position
		pawn.velocity = Vector3.ZERO
		for tick in 8:
			await physics_frame
		Input.action_press("move_forward")
		Input.action_press("sprint")
		for target in path.slice(1):
			if not await _walk(target):
				failures.append("%s from %s toward %s" % [title, pawn.position, target])
				break
		walked += 1
	Input.action_release("move_forward")
	Input.action_release("sprint")

func _walk(target: Vector3) -> bool:
	for tick in ceili(pawn.position.distance_to(target) * 15.) + 140:
		var delta := target - pawn.position
		var horizontal := delta.slide(Vector3.UP)
		if horizontal.length() < .35:
			return absf(delta.y) < .55
		view.rotation.y = atan2(-horizontal.x, -horizontal.z)
		await physics_frame
	return false

func _v(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])
