extends RefCounted
## A safe landing needs five points of walkable ground and space for the whole capsule.
## The exact same terrain mask is used by the traveler, the dash and the recovery check.

const OFFSETS := [Vector3.ZERO, Vector3(.25,0,0), Vector3(-.25,0,0),
	Vector3(0,0,.25), Vector3(0,0,-.25)]
var body: CharacterBody3D
var capsule: CapsuleShape3D
var collider_y: float
var authored := PackedVector3Array()
var opening := Vector3.INF
var camp := Vector3.INF
var history := PackedVector3Array()
var dry_filter := Callable()
var _ray := PhysicsRayQueryParameters3D.new()
var _room := PhysicsShapeQueryParameters3D.new()

func _init(traveler: CharacterBody3D, shape: CapsuleShape3D, center_y: float) -> void:
	body = traveler
	capsule = shape
	collider_y = center_y
	_ray.collision_mask = 1
	_room.collision_mask = 1
	_room.shape = shape
	_room.margin = .002

func _floor_at(point: Vector3, above: float, below: float) -> Dictionary:
	_ray.from = point + Vector3.UP * above
	_ray.to = point - Vector3.UP * below
	return body.get_world_3d().direct_space_state.intersect_ray(_ray)

func snap(candidate: Vector3, for_recovery: bool, above := .32, below := .48) -> Vector3:
	if not candidate.is_finite():
		return Vector3.INF
	var min_normal := cos(body.floor_max_angle)
	var center := Vector3.INF
	var lift := 0.0
	for offset: Vector3 in OFFSETS:
		var floor_hit := _floor_at(candidate + offset, above, below)
		if floor_hit.is_empty() or (floor_hit.normal as Vector3).y < min_normal:
			return Vector3.INF
		var point: Vector3 = floor_hit.position
		if center == Vector3.INF:
			center = point
			# A capsule resting on a slope is tangent slightly above the
			# point hit by a vertical ray along its axis.
			lift = capsule.radius * (1.0 / float(floor_hit.normal.y) - 1.0)
		elif absf(point.y - center.y) > .32:
			return Vector3.INF
	if for_recovery and dry_filter.is_valid() and not dry_filter.call(center):
		return Vector3.INF
	var feet := Vector3(candidate.x, center.y + lift + .035, candidate.z)
	_room.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * collider_y)
	if not body.get_world_3d().direct_space_state.intersect_shape(_room, 1).is_empty():
		return Vector3.INF
	return feet

func remember(point: Vector3) -> void:
	if history.is_empty() or history[-1].distance_to(point) >= .65:
		history.append(point)
		if history.size() > 7:
			history.remove_at(0)

func anchor_for(origin: Vector3, saved := Vector3.INF) -> Vector3:
	var place := snap(saved, true, .70, 1.4)
	if place.is_finite():
		return place
	# Restrict a failed saved location to anchors of the regenerated world.
	# Ordinary falls prefer the trail or clearing the player just occupied.
	if not saved.is_finite():
		for i in range(history.size() - 1, -1, -1):
			place = snap(history[i], true, .50, .85)
			if place.is_finite():
				return place
	place = snap(camp, true, .70, 1.4)
	if place.is_finite():
		return place
	var ordered := Array(authored)
	ordered.sort_custom(func(a: Vector3,b: Vector3) -> bool:
		return a.distance_squared_to(origin) < b.distance_squared_to(origin))
	for point: Vector3 in ordered:
		place = snap(point, true, .70, 1.4)
		if place.is_finite():
			return place
	return snap(opening, true, .80, 1.5)

func lost_below_ground(position: Vector3, fallback: Vector3) -> bool:
	if not position.is_finite() or position.y < -95.0:
		return true
	var reference := history[-1] if not history.is_empty() else fallback
	if not reference.is_finite() or position.y >= reference.y - 4.0:
		return false
	# Allow a deliberate descent to a lower reachable landing.
	return _floor_at(position, .05, 5.5).is_empty()
