extends RefCounted
## Extend only the first leg of an authored raid lane, stopping at the first
## break in walkable ground or obstacle. Existing waypoints stay intact.

const EXTENSION := 3.6
const SAMPLE_SPACING := 0.6
const STEP_HEIGHT := 0.30
const MIN_FLOOR_Y := 0.71
const TERRAIN := 1

static func extend(space: PhysicsDirectSpaceState3D, lane: PackedVector3Array,
		spec: CinderEnemyStats) -> PackedVector3Array:
	var heading := (lane[0] - lane[1]).slide(Vector3.UP).normalized()
	if heading.is_zero_approx():
		return lane
	var capsule := CapsuleShape3D.new()
	capsule.radius = spec.radius
	capsule.height = maxf(spec.height, capsule.radius * 2.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = TERRAIN
	var clearance := Vector3.UP * (capsule.height * 0.5 + 0.11)
	var previous := _floor(space, lane[0], 0.55)
	if not previous.is_finite():
		return lane
	var start := previous
	for index in range(1, roundi(EXTENSION / SAMPLE_SPACING) + 1):
		var sample := lane[0] + heading * SAMPLE_SPACING * index
		sample.y = previous.y
		var candidate := _floor(space, sample, STEP_HEIGHT)
		if not candidate.is_finite():
			break
		# A ray can hit right at a ledge; require support under the capsule's
		# shoulders too, on both sides of this segment.
		var shoulder := heading.cross(Vector3.UP) * capsule.radius * 0.7
		if not _floor(space, candidate + shoulder, STEP_HEIGHT).is_finite() \
				or not _floor(space, candidate - shoulder, STEP_HEIGHT).is_finite():
			break
		if not _clear_step(space, query, candidate, previous, clearance):
			break
		previous = candidate
	if (previous - start).slide(Vector3.UP).length_squared() < 1.0:
		return lane
	var route := PackedVector3Array([previous])
	route.append_array(lane)
	return route

static func _floor(space: PhysicsDirectSpaceState3D, point: Vector3, reach: float) -> Vector3:
	var offset := Vector3.UP * reach
	var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(point + offset, point - offset, TERRAIN))
	if ground.is_empty() or ground.normal.y < MIN_FLOOR_Y:
		return Vector3.INF
	return ground.position

static func _clear_step(space: PhysicsDirectSpaceState3D, query: PhysicsShapeQueryParameters3D,
		from: Vector3, to: Vector3, clearance: Vector3) -> bool:
	query.transform = Transform3D(Basis.IDENTITY, from + clearance)
	query.motion = Vector3.ZERO
	if not space.intersect_shape(query, 1).is_empty():
		return false
	# The mover can step up a low riser. Sweeping at the higher floor height
	# checks the body above it without treating ordinary slopes as walls.
	var lift := Vector3.UP * maxf(0.0, to.y - from.y)
	query.transform = query.transform.translated(lift)
	query.motion = (to - from).slide(Vector3.UP)
	if not space.intersect_shape(query, 1).is_empty():
		return false
	var sweep := space.cast_motion(query)
	return not sweep.is_empty() and sweep[0] >= 0.999
