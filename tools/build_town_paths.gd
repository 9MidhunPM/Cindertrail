extends SceneTree
## Offline survey of the authored side alleys. Run: godot --headless --fixed-fps 60 -s tools/build_town_paths.gd
## The shipped game reads the finished stone placements without querying physics or building navigation.

const OUT := "res://data/outer_valley/town_paths.json"
const REGION := preload("res://scenes/world/outer_valley.tscn")
const SPACING := .72
const WIDTH := 49
const HEIGHT := 57
var capsule := CapsuleShape3D.new()
var failures := PackedStringArray()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	capsule.height = 1.66
	capsule.radius = .46
	var collection := {}
	for base in range(1, 4):
		for choice in 2:
			for branch in 2:
				var layout := CinderJourneyLayout.generate(base - 1)
				for town in layout.TOWNS:
					layout.town_variants[town] = choice
				for fork in layout.FORKS:
					layout.fork_variants[fork] = branch
				var valley: CinderOuterValley = REGION.instantiate()
				valley.journey_layout = layout
				valley.layout_id = base
				root.add_child(valley)
				await physics_frame
				await physics_frame
				for id: String in layout.TOWNS:
					var town = valley.abandoned_towns.settlement_at(id)
					var key := "%d/%s/%d/%d" % [base, id, choice, branch]
					collection[key] = _survey(town, key)
				valley.free()
	if not failures.is_empty():
		print("Failed side alleys: ", failures)
		quit(1)
		return
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(collection) + "\n")
	print("Surveyed ", collection.size(), " town configurations")
	quit()

func _survey(town: Node3D, key: String) -> Dictionary:
	var graph := AStar2D.new()
	var floors := {}
	var space := town.get_world_3d().direct_space_state
	var standing := PhysicsShapeQueryParameters3D.new()
	standing.shape = capsule
	standing.collision_mask = 1
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = 1
	for iz in HEIGHT:
		for ix in WIDTH:
			var local := Vector3((ix - 24) * SPACING, 0, (iz - 35) * SPACING)
			var world := town.to_global(local)
			ray.from = world + Vector3.UP * 9
			ray.to = world - Vector3.UP * 10
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or hit.normal.y < .87:
				continue
			var parent: Node = hit.collider.get_parent()
			if not str(parent.name).begins_with("Ground"):
				continue
			var floor_at: Vector3 = hit.position
			standing.transform.origin = floor_at + Vector3.UP * .92
			standing.exclude = [hit.rid]
			if not space.intersect_shape(standing, 1).is_empty():
				continue
			var i := ix + iz * WIDTH
			local.y = town.to_local(floor_at).y
			floors[i] = local
			graph.add_point(i, Vector2(local.x, local.z))
	for i: int in floors:
		for offset: int in [1, WIDTH, WIDTH + 1, WIDTH - 1]:
			var j := i + offset
			if not floors.has(j) or absi(j % WIDTH - i % WIDTH) > 1:
				continue
			if absf(floors[j].y - floors[i].y) > .30:
				continue
			if offset > WIDTH or offset == WIDTH - 1:
				if not floors.has(i + WIDTH) or not floors.has(i + offset - WIDTH):
					continue
			graph.connect_points(i, j)
	# The feature is authored by the town: the well court, bell foundry or cistern.
	# Enter from one end of its high street, return through a different block.
	var street: PackedVector3Array = town.street_waypoints()
	if street.size() < 2:
		failures.append(key + " missing street")
		return {}
	var entrances := [town.to_local(street[0]), town.to_local(street[-1])]
	var start := graph.get_closest_point(Vector2(entrances[0].x, entrances[0].z))
	var finish := graph.get_closest_point(Vector2(entrances[1].x, entrances[1].z))
	for feature: Vector3 in town.discovery_points:
		var local := town.to_local(feature)
		var cache := graph.get_closest_point(Vector2(local.x, local.z))
		if cache < 0 or graph.get_point_position(cache).distance_to(Vector2(local.x, local.z)) > 2.0:
			continue
		for i: int in floors:
			# Keep the side lane out of the cartway between its two entrances.
			graph.set_point_weight_scale(i, 4.5 if absf(floors[i].x) < 1.8 else 1.0)
		var entry := graph.get_id_path(start, cache)
		if entry.size() < 3:
			continue
		for i in entry:
			if i == cache:
				continue
			graph.set_point_weight_scale(i, 22.0)
			for j in graph.get_point_connections(i):
				if j != cache:
					graph.set_point_weight_scale(j, maxf(5.0, graph.get_point_weight_scale(j)))
		var leave := graph.get_id_path(cache, finish)
		if leave.size() < 3:
			continue
		var line: Array = []
		for i in entry:
			line.append(_xyz(floors[i]))
		for i in leave.slice(1):
			line.append(_xyz(floors[i]))
		return {"points": line, "cache": entry.size() - 1}
	failures.append(key + " has no reachable discovery")
	return {}

func _xyz(at: Vector3) -> Array:
	return [snappedf(at.x, .001), snappedf(at.y, .001), snappedf(at.z, .001)]
