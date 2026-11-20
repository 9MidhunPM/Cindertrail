extends Node3D
## Reuses authored road beds and scatters compact, distinct stops along their verges.

signal cache_found(id: String, at: Vector3)

const MESH := preload("res://scripts/world/environment_mesh.gd")
const AMBER := preload("res://art/materials/sun_amber.tres")
const SPACING := 60.0
const ROAD_MARGIN := 4.15
const FOOTPRINT := 2.7
const CACHE_LIMIT := 3
const STONE := Color("#baae92")
const DEEP_STONE := Color("#66717a")
const TIMBER := Color("#6c493b")
const COPPER := Color("#a8794c")
const GOLD_LEAF := Color("#bb742e")
const GREEN_LEAF := Color("#568564")
const FIND_OFFSETS := [0.0, -5.0, 5.0, -11.0, 11.0, -16.0, 16.0]

enum Kind { RILL, QUARRY, WALL, SIGNAL }

## World-space records also let normal route QA walk every generated cache spur.
var stops: Array[Dictionary] = []
var discoveries: Array[Dictionary] = []
var _roads: Array[PackedVector3Array] = []
var _protected_paths: Array[PackedVector3Array] = []
var _protected_sites := PackedVector3Array()
var _protected_caches := PackedVector3Array()
var _stone: ShaderMaterial
var _wood: ShaderMaterial
var _space: PhysicsDirectSpaceState3D
var _clearance := PhysicsShapeQueryParameters3D.new()
var _rng := RandomNumberGenerator.new()

func build(roads: Array[PackedVector3Array], labels: PackedStringArray,
		reserved: PackedVector3Array, protected_paths: Array[PackedVector3Array],
		caches: PackedVector3Array, seed_value: int) -> void:
	_roads = roads
	_protected_sites = reserved
	_protected_paths = protected_paths
	_protected_caches = caches
	_stone = MESH.pigment()
	_wood = MESH.pigment(2)
	var capsule := CapsuleShape3D.new()
	capsule.radius = .44
	capsule.height = 1.62
	_clearance.shape = capsule
	_clearance.collision_mask = 1
	_space = get_world_3d().direct_space_state
	# Shuffle visitation with the journey seed so caches can occur in any part of the valley.
	var order := range(_roads.size())
	_rng.seed = seed_value ^ 0x34f12b
	for i in range(order.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap: int = order[i]
		order[i] = order[j]
		order[j] = swap
	for index: int in order:
		_dress_road(_roads[index], labels[index], index, seed_value)
	_roads = []
	_protected_paths = []
	_space = null

func _dress_road(path: PackedVector3Array, label: String, road_index: int, seed_value: int) -> void:
	var length_at := PackedFloat32Array([0.0])
	for i in range(1, path.size()):
		length_at.append(length_at[-1] + path[i - 1].distance_to(path[i]))
	var total := length_at[-1]
	if total < 20.0:
		return
	var count := ceili(total / SPACING)
	var can_hide_cache := total >= 42.0 and not label.contains("bridge")
	for beat in count:
		_rng.seed = hash("%s:%s:%s" % [seed_value, label, beat])
		var favored_side := 1.0 if _rng.randi_range(0, 1) == 0 else -1.0
		var distance := (beat + _rng.randf_range(.43, .57)) * total / count
		var placement := _find_stop(path, length_at, distance, favored_side)
		if placement.is_empty():
			continue
		var type := _family(label)
		var id := "wayside_%d_%d" % [road_index, beat]
		var access := PackedVector3Array()
		if can_hide_cache and discoveries.size() < CACHE_LIMIT and _far_from_discoveries(placement.center):
			access = _side_path(placement.road, placement.center.lerp(placement.road, .23))
			if not access.is_empty():
				discoveries.append({"id": id, "point": access[-1], "path": access})
				cache_found.emit(id, access[-1])
				can_hide_cache = false
		_raise_stop(id, placement, type, access)

func _find_stop(path: PackedVector3Array, length_at: PackedFloat32Array, target: float,
		favored_side: float) -> Dictionary:
	for shift: float in FIND_OFFSETS:
		var distance := clampf(target + shift, 6.0, length_at[-1] - 6.0)
		var segment := 1
		while length_at[segment] < distance:
			segment += 1
		var t := inverse_lerp(length_at[segment - 1], length_at[segment], distance)
		var road := path[segment - 1].lerp(path[segment], t)
		var forward := path[segment - 1].direction_to(path[segment]).slide(Vector3.UP).normalized()
		var verge := forward.cross(Vector3.UP)
		for lateral: float in [6.05, 8.5, 11.0]:
			for side: float in [favored_side, -favored_side]:
				var at := road + verge * lateral * side
				if not _verge_clear(at):
					continue
				var floor_hit := _ground(at)
				if floor_hit.is_empty() or absf(floor_hit.position.y - road.y) > 2.4:
					continue
				var sightline := PhysicsRayQueryParameters3D.create(road + Vector3.UP * 1.6,
					floor_hit.position + Vector3.UP * 1.66, 1)
				if not _space.intersect_ray(sightline).is_empty():
					continue
				if not _open_footprint(floor_hit):
					continue
				return {"center": floor_hit.position, "road": road}
	return {}

func _verge_clear(at: Vector3) -> bool:
	for point in _protected_sites:
		if _horizontal_distance(at, point) < 18.0:
			return false
	for point in _protected_caches:
		if _horizontal_distance(at, point) < 5.5:
			return false
	for placed in stops:
		if _horizontal_distance(at, placed.center) < 10.0:
			return false
	for path: PackedVector3Array in _roads:
		if _distance_to_path(at, path) < ROAD_MARGIN + 1.6:
			return false
	for path: PackedVector3Array in _protected_paths:
		if _distance_to_path(at, path) < 2.6 + FOOTPRINT:
			return false
	return true

func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _distance_to_path(at: Vector3, path: PackedVector3Array) -> float:
	var shortest := INF
	var point := Vector2(at.x, at.z)
	for i in range(1, path.size()):
		var a := Vector2(path[i - 1].x, path[i - 1].z)
		var b := Vector2(path[i].x, path[i].z)
		shortest = minf(shortest, point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b)))
	return shortest

func _ground(at: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4.0, at - Vector3.UP * 4.5, 1)
	var hit := _space.intersect_ray(query)
	if hit.is_empty() or hit.normal.y < .76:
		return {}
	var ground := hit.collider as Node3D
	if ground == null or not String(ground.get_parent().name).begins_with("Ground"):
		return {}
	return hit

func _open_footprint(center: Dictionary) -> bool:
	for offset in [Vector3.ZERO, Vector3.LEFT * 1.75, Vector3.RIGHT * 1.75, Vector3.FORWARD * 1.75, Vector3.BACK * 1.75]:
		var hit := center if offset == Vector3.ZERO else _ground(center.position + offset)
		if hit.is_empty() or absf(hit.position.y - center.position.y) > .62 or not _clear_step(hit):
			return false
	return true

func _clear_step(floor_hit: Dictionary) -> bool:
	_clearance.transform.origin = floor_hit.position + Vector3.UP * .87
	_clearance.exclude = [floor_hit.rid]
	return _space.intersect_shape(_clearance, 1).is_empty()

func _far_from_discoveries(at: Vector3) -> bool:
	for cache in discoveries:
		if _horizontal_distance(at, cache.point) < 92.0:
			return false
	return true

func _side_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var points := PackedVector3Array([from])
	var steps := ceili(_horizontal_distance(from, to) / .72)
	for i in range(1, steps + 1):
		var aim := from.lerp(to, float(i) / steps)
		var ground := _ground(aim)
		if ground.is_empty() or not _clear_step(ground) or absf(ground.position.y - points[-1].y) > .34:
			return PackedVector3Array()
		points.append(ground.position)
	return points

func _family(label: String) -> Kind:
	var lower := label.to_lower()
	if lower.contains("quarry") or lower.contains("mason"):
		return Kind.QUARRY
	if lower.contains("wash") or lower.contains("towpath") or lower.contains("tanner") or lower.contains("spillway"):
		return Kind.RILL
	if lower.contains("relay") or lower.contains("escarpment") or lower.contains("stair"):
		return Kind.SIGNAL
	return Kind.WALL

func _raise_stop(id: String, placement: Dictionary, type: Kind, access: PackedVector3Array) -> void:
	var stop := Node3D.new()
	stop.name = id.to_pascal_case()
	stop.position = placement.center
	add_child(stop)
	var from_road: Vector3 = (placement.center - placement.road).slide(Vector3.UP).normalized()
	stop.look_at(stop.global_position + from_road, Vector3.UP)
	var masonry := MESH.new()
	var wood := MESH.new()
	var glint := MESH.new()
	match type:
		Kind.RILL:
			_ruined_waterwork(masonry, wood)
		Kind.QUARRY:
			_stone_yard(masonry, wood)
		Kind.WALL:
			_wall(masonry)
		Kind.SIGNAL:
			_signal_post(masonry, wood)
	_verge(masonry, wood, stop, type)
	if not access.is_empty():
		_stone_spur(masonry, stop, access)
		for side in [-1., 1.]:
			var marker := Vector3(side * 1.28, .25, .45)
			_pile(masonry, marker, 2)
			glint.block(marker + Vector3.UP * .26, Vector3(.082,.12,.085), Color("#ffbb55"))
	_mount(masonry, stop, "ChippedLimestone", _stone)
	_mount(wood, stop, "TimberAndLeaves", _wood)
	_mount(glint, stop, "CacheGlints", AMBER)
	stops.append({"id": id, "center": placement.center, "road": placement.road, "kind": type})

func _mount(mesh: MESH, parent: Node3D, label: String, material: Material) -> void:
	var part := mesh.mount(parent, label, material, false)
	if part:
		part.visibility_range_end = 74.0
		part.visibility_range_end_margin = 9.0

func _wall(stone: MESH) -> void:
	for i in 9:
		var x := (i - 4) * .46
		var rows := 3 if i in [1, 2, 6, 7, 8] else 1
		for row in rows:
			var pos := Vector3(x + (row % 2) * .07, .17 + row * .32, -1.18 + sin(i * 1.2)*.18)
			stone.block(pos, Vector3(.218,.16,.22), STONE.lerp(DEEP_STONE, _rng.randf_range(.07,.38)),
				_rng.randf_range(-.14,.14))
	for side in [-1.,1.]:
		var base := Vector3(side*1.30,0.16,-.32)
		for row in (5 if side < 0 else 3):
			stone.block(base + Vector3.UP * row*.32, Vector3(.27,.16,.28), STONE.lightened(row * .025))
		stone.block(base + Vector3.UP * (1.60 if side < 0 else .97), Vector3(.37,.09,.36), STONE)
	stone.facets(Vector3(-.42,.25,.02), Vector3(.49,.24,.34), 7, DEEP_STONE)

func _ruined_waterwork(stone: MESH, wood: MESH) -> void:
	for side in [-1.,1.]:
		var base := Vector3(side*1.25,.13,-.68)
		for row in (6 if side < 0 else 4):
			stone.block(base + Vector3.UP*row*.29, Vector3(.28,.143,.36), STONE.lerp(DEEP_STONE,.14*row/4.))
		stone.block(base + Vector3.UP * (1.74 if side < 0 else 1.14), Vector3(.38,.12,.39), DEEP_STONE.lerp(STONE,.65))
		for i in 4:
			stone.block(Vector3(side*1.39,.12,-.52+i*.48), Vector3(.44,.14,.23), STONE.darkened(i*.035))
	wood.tapered(Vector3(-1.33,1.67,-.7), Vector3(.87,1.22,-.79), .10,.065,7,TIMBER)
	wood.tapered(Vector3(-.58,1.49,-.74), Vector3(-.58,.65,-.74), .024,.022,5,COPPER)
	for row in 5:
		stone.block(Vector3(0,.044,-1.78+row*.48), Vector3(.52,.052,.23), Color("#628b85").lerp(DEEP_STONE,.38))

func _stone_yard(stone: MESH, wood: MESH) -> void:
	for side in [-1.,1.]:
		var foot := Vector3(side*1.31,.16,-.64)
		var top := Vector3(side*.77,2.25,-.83)
		stone.block(foot, Vector3(.31,.16,.32), STONE)
		wood.tapered(foot, top, .141,.10,6,TIMBER)
	wood.tapered(Vector3(-.87,2.23,-.83), Vector3(1.65,2.35,-1.18), .16,.09,7,TIMBER)
	wood.tapered(Vector3(-.99,.78,-.64), Vector3(.42,1.94,-.87), .095,.08,6,TIMBER)
	wood.tapered(Vector3(1.48,2.32,-1.14), Vector3(1.48,.83,-1.14), .026,.022,5,COPPER)
	stone.block(Vector3(1.48,.60,-1.14), Vector3(.41,.25,.36), STONE)
	for i in 5:
		var at := Vector3(-1.25+i*.51,.10,-.12 + _rng.randf_range(-.16,.08))
		stone.facets(at, Vector3(.22,.14,.27), 6, DEEP_STONE.lerp(STONE,_rng.randf_range(.14,.71)))

func _signal_post(stone: MESH, wood: MESH) -> void:
	for row in 5:
		var size := .49 - row*.046
		stone.block(Vector3(0,.17 + row * .34,-1.03), Vector3(size,.17,size), STONE.lerp(DEEP_STONE,.045*row))
	wood.tapered(Vector3(0,1.54,-1.03), Vector3(0,2.58,-1.03), .10,.067,7,TIMBER)
	wood.tapered(Vector3(-1.06,2.31,-1.03), Vector3(1.06,2.31,-1.03), .071,.071,6,COPPER)
	for column in [-.83,.83]:
		wood.tapered(Vector3(column,2.30,-1.03), Vector3(column,1.88,-1.03), .022,.021,5,COPPER)
		wood.facets(Vector3(column,1.78,-1.03), Vector3(.12,.13,.12), 7, COPPER.lightened(.20))
		_pile(stone, Vector3(column * 1.8,.07,-.53), 2)

func _verge(stone: MESH, wood: MESH, stop: Node3D, type: Kind) -> void:
	for i in 14:
		var around := float(i) * 2.39
		var radius := _rng.randf_range(1.6,2.6)
		var flat := Vector3(cos(around)*radius,0,sin(around)*radius)
		var hit := _ground(stop.to_global(flat))
		if hit.is_empty():
			continue
		var local := stop.to_local(hit.position)
		if i % 3 == 1:
			stone.facets(local + Vector3.UP*.055, Vector3(.12,.08,.16) * _rng.randf_range(.64,1.5), 5,
				DEEP_STONE.lerp(STONE, _rng.randf_range(.25,.80)))
		else:
			var color := GREEN_LEAF if type == Kind.RILL or i % 2 == 0 else GOLD_LEAF
			var tip := local + Vector3.UP * _rng.randf_range(.27,.54)
			for arm in 4:
				var angle := around + arm * PI * .5
				var side := Vector3(cos(angle),0,sin(angle))
				var spine := side.cross(Vector3.UP) * .073
				wood.face(local, tip.lerp(local,.35)+side*.22+spine, tip+side*.26, color, Vector3.UP)
				wood.face(local, tip+side*.26, tip.lerp(local,.35)+side*.22-spine, color.darkened(.14), Vector3.UP)

func _stone_spur(stone: MESH, stop: Node3D, path: PackedVector3Array) -> void:
	for i in range(1,path.size()):
		var at := stop.to_local(path[i])
		for side: float in [-1.,1.]:
			var sideways := Vector3.RIGHT*side*_rng.randf_range(.19,.31)
			stone.block(at + sideways + Vector3.UP*.016, Vector3(.19,.033,.26),
				STONE.lerp(DEEP_STONE,_rng.randf_range(.17,.58)), _rng.randf_range(-.2,.2))

func _pile(stone: MESH, at: Vector3, rows: int) -> void:
	for i in rows:
		stone.block(at + Vector3.UP*.22*i, Vector3(.28-.045*i,.11,.22-.025*i), STONE,
			_rng.randf_range(-.26,.26))
