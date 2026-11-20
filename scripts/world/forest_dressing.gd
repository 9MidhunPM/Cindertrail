extends Node3D
## Dense pockets frame the trails. Forest trunks stay outside the road beds.

const MESH := preload("res://scripts/world/environment_mesh.gd")
const DEN := preload("res://scripts/world/trail_den.gd")
const POCKETS := [
	["Masons’ walk", .29, -1.0, .20],
	["Masons’ walk", .29, 1.0, .25],
	["Masons’ walk", .58, 1.0, .16],
	["Western arcade", .40, -1.0, .37],
	["High orchard", .25, 1.0, .86],
	["High orchard", .60, -1.0, .71],
	["Orchard spillway", .51, 1.0, .50],
	["South wash", .42, 1.0, .12],
	["Pilgrim stair", .49, -1.0, .23],
	["Spice road", .38, 1.0, .37],
	["Spice road", .38, -1.0, .24],
	["Spice road", .68, -1.0, .48],
	["Bellmakers’ cut", .63, -1.0, .45],
	["Eastern escarpment", .29, 1.0, .22],
	["Gallery road", .43, -1.0, .32],
	["Tanners’ road", .19, 1.0, .17],
	["Tanners’ road", .78, -1.0, .16],
	["Quarry switchback", .52, 1.0, .61],
	["Relay ascent", .37, 1.0, .24],
]
const COOL := [Color("#174e57"), Color("#225d63"), Color("#2c766c"), Color("#3b7c6f")]
const GOLD := [Color("#b96534"), Color("#c8763a"), Color("#d58a41"), Color("#d59955")]

var _roads: Array = []
var _excluded := PackedVector3Array()
var _reserved_shrines := PackedVector3Array()
var _rng := RandomNumberGenerator.new()
var _bark: ShaderMaterial
var _leaf: ShaderMaterial
var _planted := PackedVector3Array()

func build(roads: Array, labels: PackedStringArray, forbidden: PackedVector3Array, seed_value: int,
		settlements: Array, reserved_shrines := PackedVector3Array()) -> void:
	_roads = roads.duplicate()
	_excluded = forbidden
	_reserved_shrines = reserved_shrines
	_rng.seed = 73183 ^ seed_value
	_bark = MESH.pigment(2)
	_leaf = MESH.pigment(0, true)
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	for record: Array in POCKETS:
		var route := labels.find(record[0])
		if route >= 0:
			_plant_pocket(_roads[route], record[1], record[2], record[3])
	for town: Node3D in settlements:
		_plant_town_skirt(town)
	_roads = []

func protect_walking_paths(paths: Array[PackedVector3Array]) -> void:
	_roads.append_array(paths)

func _plant_town_skirt(town: Node3D) -> void:
	var border := Node3D.new()
	border.name = "TownForestSkirt"
	border.position = town.position
	add_child(border)
	var wood := MESH.new()
	var canopy := MESH.new()
	var count := 0
	var forward := -town.global_basis.z
	for local: Vector2 in [Vector2(-6.8, 7.5), Vector2(7.2, 8.5), Vector2(-8.7, -10.5),
			Vector2(8.8, -10.0), Vector2(-11.8, -12.9), Vector2(12.5, -14.0),
			Vector2(-11.9, -.6), Vector2(11.1, 2.9), Vector2(-8.8, -18.4), Vector2(9.8, -20.1),
			Vector2(-9.5, 11.4), Vector2(10.15, 12.8), Vector2(-14.65, -4.8), Vector2(14.8, -7.3)]:
		var at := town.to_global(Vector3(local.x, 0, local.y))
		if _distance_to_roads(at) < 4.55 or _has_neighbor(at, 3.12) or _in_reserved_shrine(at):
			continue
		var ground := _ground(at)
		if ground == Vector3.INF:
			continue
		var center := border.to_local(ground)
		var warm := count % 3 == 0
		_tree(wood, canopy, center, _rng.randf_range(3.85, 5.65), warm, forward)
		_planted.append(ground)
		for cluster in 3:
			var bit := ground + Vector3(sin(cluster * 2.2), 0, cos(cluster * 2.2)) * 1.15
			if _distance_to_roads(bit) < 2.65:
				continue
			var floor_at := _ground(bit)
			if floor_at != Vector3.INF:
				var seedling := border.to_local(floor_at)
				_fern(canopy, seedling, _rng.randf_range(.57, .92), warm)
				canopy.facets(seedling + Vector3.UP * .18, Vector3(.35, .16, .31), 7, Color("#465d48"))
		count += 1
		if count >= 7:
			break
	if count == 0:
		border.queue_free()
		return
	for part: MeshInstance3D in [wood.mount(border, "TownSkirtBark", _bark, false),
			canopy.mount(border, "TownSkirtCanopy", _leaf, false)]:
		part.visibility_range_end = 69.0
		part.visibility_range_end_margin = 8.0

func _plant_pocket(path: PackedVector3Array, fraction: float, bank: float, autumn_ratio: float) -> void:
	if path.size() < 2:
		return
	var edge := fraction * (path.size() - 1)
	var segment := clampi(floori(edge), 0, path.size() - 2)
	var direction := (path[segment + 1] - path[segment]).slide(Vector3.UP).normalized()
	if direction.is_zero_approx():
		return
	var across := direction.cross(Vector3.UP) * bank
	var center := path[segment].lerp(path[segment + 1], edge - segment)
	var sector := Node3D.new()
	sector.name = "ForestClump"
	sector.position = center + across * 8.0
	add_child(sector)
	var wood := MESH.new()
	var canopy := MESH.new()
	var solid := StaticBody3D.new()
	solid.name = "Trunks"
	sector.add_child(solid)
	for slot in 22:
		var row := floorf(slot / 6.0)
		var verge := 4.3 + row * 5.7 + _rng.randf_range(-.7, .62)
		var along := (slot % 6 - 2.5) * 3.28 + _rng.randf_range(-1.2, 1.2)
		var at := center + across * verge + direction * along
		var distance := _distance_to_roads(at)
		if distance < 4.05 or distance > 36.0 or _protected(at, 17.0) or _has_neighbor(at, 2.85):
			continue
		var ground := _ground(at)
		if ground == Vector3.INF:
			continue
		var point := sector.to_local(ground) - Vector3.UP * .05
		_planted.append(ground)
		var height := _rng.randf_range(2.25, 4.55) if verge > 9.4 else _rng.randf_range(4.25, 6.65)
		var warm := _rng.randf() < autumn_ratio
		_tree(wood, canopy, point, height, warm, direction)
		if distance < 10.0:
			_trunk_collider(solid, point, height)
		for i in 4:
			var offset := (across * _rng.randf_range(-1.6, 2.6) + direction * _rng.randf_range(-1.65, 1.65))
			if _distance_to_roads(ground + offset) < 2.32:
				continue
			var floor_at := _ground(ground + offset)
			if floor_at != Vector3.INF:
				_fern(canopy, sector.to_local(floor_at), _rng.randf_range(.48, 1.20), warm)
		if slot % 5 == 1 and distance > 6.5:
			var deadfall := point + direction * 1.1 + across * .36
			wood.tapered(deadfall, deadfall + direction * 2.9 + Vector3.UP * .27, .20, .11, 6, Color("#654b3e"))
	if solid.get_child_count() == 0:
		solid.queue_free()
	# Baked landmark trees already supply shadows. The supplemental foliage adds
	# nearby silhouettes without sending every moving leaf through the shadow pass.
	var floor_mesh := wood.mount(sector, "BarkAndDeadfall", _bark, false)
	var leaf_mesh := canopy.mount(sector, "CanopyAndUnderstory", _leaf, false)
	if floor_mesh == null and leaf_mesh == null:
		sector.queue_free()
		return
	for view: MeshInstance3D in [floor_mesh, leaf_mesh]:
		if view:
			view.visibility_range_end = 81.0
			view.visibility_range_end_margin = 10.0

func _tree(wood: MESH, canopy: MESH, at: Vector3, height: float, warm: bool, toward: Vector3) -> void:
	var radius := height * .051
	var bark := Color("#614539").lerp(Color("#576059"), _rng.randf() * .72)
	var fork := at - toward * _rng.randf_range(.18, .55) + Vector3.UP * height * .50
	var apex := fork + Vector3.UP * height * .27 + Vector3.RIGHT * _rng.randf_range(-.54, .58)
	wood.tapered(at, at + Vector3.UP * height * .16, radius * 1.2, radius * .81, 7, bark)
	wood.tapered(at + Vector3.UP * height * .155, fork, radius * .84, radius * .49, 7, bark.lightened(.04))
	wood.tapered(fork, apex, radius * .50, radius * .16, 6, bark.lightened(.06))
	var leaf_set := GOLD if warm else COOL
	var phase := _rng.randf() * TAU
	for ray in 4:
		var a := phase + TAU * ray / 4.0
		var reach := Vector3(cos(a), 0.13, sin(a))
		var crotch := fork.lerp(apex, .23 + .15 * ray)
		var tip := crotch + reach * height * _rng.randf_range(.20, .29) + Vector3.UP * height * .19
		wood.tapered(crotch, tip, radius * .35, radius * .087, 6, bark)
		var twig := tip + reach.rotated(Vector3.UP, .54) * height * .20 + Vector3.UP * height * .045
		wood.tapered(tip, twig, radius * .12, radius * .036, 5, bark.lightened(.09))
		var paint: Color = leaf_set[ray]
		canopy.facets(tip + Vector3.UP * .15, Vector3(.31, .132, .28) * height, 9, paint, a)
		canopy.facets(twig, Vector3(.22, .102, .20) * height, 7, paint.lightened(.11), a - .62)
		if ray % 2 == 1:
			canopy.facets(crotch + Vector3.UP * height * .28, Vector3(.24, .113, .23) * height, 8, paint.lightened(.15), a)
	for root in 4:
		var a := phase + TAU * root / 4.0
		var outward := Vector3(cos(a), 0, sin(a))
		var heel := at + outward * radius * 2.1 + Vector3.UP * .13
		wood.tapered(at + Vector3.UP * radius * 2.2, heel, radius * .59, radius * .41, 5, bark)
		wood.tapered(heel, at + outward * radius * 5.2 - Vector3.UP * .077, radius * .41, radius * .081, 5, bark)

func _fern(canopy: MESH, at: Vector3, size: float, warm: bool) -> void:
	var tint := Color("#947048") if warm else Color("#4b8464")
	for arm in 6:
		var angle := TAU * arm / 6.0 + _rng.randf_range(-.26, .25)
		var out := Vector3(cos(angle), 0, sin(angle))
		var bend := at + Vector3.UP * size * .40 + out * size * .40
		var tip := bend + out * size * .28 - Vector3.UP * size * .065
		var spine := out.cross(Vector3.UP) * size
		for row in 4:
			var t := .22 + .19 * row
			var node := at.lerp(bend, t) if row < 3 else bend
			var width := .19 * (1.0 - t * .64)
			for sign_side in [-1.0, 1.0]:
				var leaf := node + spine * float(sign_side) * width
				var end := node.lerp(tip, .32)
				canopy.face(node, leaf, end, tint.lightened(t * .22), Vector3.UP)

func _ground(at: Vector3) -> Vector3:
	var state := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 6.5, at - Vector3.UP * 10.0, 1)
	var hit := state.intersect_ray(ray)
	if hit.is_empty() or (hit.normal as Vector3).y < .75:
		return Vector3.INF
	var body := hit.collider as Node3D
	if body != null and (body.get_parent() is DEN or body.name == "TownShellCollisions"):
		return Vector3.INF
	return hit.position

func _trunk_collider(solid: StaticBody3D, at: Vector3, height: float) -> void:
	var capsule := CylinderShape3D.new()
	capsule.height = height * .62
	capsule.radius = height * .053
	var collider := CollisionShape3D.new()
	collider.position = at + Vector3.UP * capsule.height * .50
	collider.shape = capsule
	solid.add_child(collider)

func _protected(at: Vector3, minimum: float) -> bool:
	for point in _excluded:
		if _flat_distance(at, point) < minimum:
			return true
	return false

func _in_reserved_shrine(at: Vector3) -> bool:
	for center in _reserved_shrines:
		if _flat_distance(at, center) < 17.0:
			return true
	return false

func _has_neighbor(at: Vector3, minimum: float) -> bool:
	for point in _planted:
		if _flat_distance(at, point) < minimum:
			return true
	return false

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _distance_to_roads(at: Vector3) -> float:
	var target := Vector2(at.x, at.z)
	var closest := INF
	for path: PackedVector3Array in _roads:
		for i in range(1, path.size()):
			var a := Vector2(path[i - 1].x, path[i - 1].z)
			var b := Vector2(path[i].x, path[i].z)
			if minf(a.distance_squared_to(target), b.distance_squared_to(target)) > 85.0 * 85.0:
				continue
			var point := Geometry2D.get_closest_point_to_segment(target, a, b)
			closest = minf(closest, point.distance_squared_to(target))
	return sqrt(closest)
