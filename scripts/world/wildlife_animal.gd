extends Node3D
## Non-combat animal. Motion stays inside its authored habitat and uses no pathfinding.

enum Species { FISH, FROG, PIKA, GOAT, DEER, OTTER, KITE, OWL }
enum Activity { CALM, ALERT, FLEEING, HIDING, RETURNING }

const MODELS: Array[PackedScene] = [
	preload("res://art/wildlife/fish.glb"), preload("res://art/wildlife/frog.glb"),
	preload("res://art/wildlife/pika.glb"), preload("res://art/wildlife/goat.glb"),
	preload("res://art/wildlife/deer.glb"), preload("res://art/wildlife/otter.glb"),
	preload("res://art/wildlife/kite.glb"), preload("res://art/wildlife/owl.glb")]
const RUN_SPEED := [3.4, 1.65, 3.5, 3.2, 4.8, 2.1, 5.4, 4.2]
const ALERT_RADIUS := [3.7, 3.0, 4.2, 5.8, 7.4, 4.3, 8.0, 6.1]
var species: Species
var activity := Activity.CALM
var home: Vector3
var refuge: Vector3
var authored_footing := false
var _phase: float
var _time := 0.0
var _state_time := 0.0
var _pace := 0.0
var _stride := 0.0
var _at: Vector3
var _from: Vector3
var _to: Vector3
var _duration := 1.0
var _heading := 0.0
var _floor_sample := Vector3.INF
var _ground_y := 0.0
var _grounded_height := false
var _model: Node3D
var _head: Node3D
var _tail: Node3D
var _legs: Array[Node3D] = []
var _wing_l: Node3D
var _wing_r: Node3D

func configure(kind: Species, resting: Vector3, hiding: Vector3, variation: float, initial_yaw: float) -> void:
	species = kind
	home = resting
	refuge = hiding
	_at = resting
	_phase = variation
	_heading = initial_yaw
	_model = MODELS[kind].instantiate() as Node3D
	add_child(_model)
	_head = _model.find_child("Head", true, false)
	_tail = _model.find_child("Tail", true, false)
	for i in 4:
		var leg := _model.find_child("Leg%d" % i, true, false) as Node3D
		if leg: _legs.append(leg)
	_wing_l = _model.find_child("WingL", true, false)
	_wing_r = _model.find_child("WingR", true, false)
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.scale = Vector3.ONE * (.94 + .10 * sin(variation))
	global_position = resting
	rotation.y = initial_yaw

func wake_point() -> Vector3:
	return _at

func _walks_on_ground() -> bool:
	return species in [Species.PIKA, Species.GOAT, Species.DEER]

func step(delta: float, traveler: Vector3, traveler_speed: float, danger: bool) -> void:
	_time += delta
	_state_time += delta
	var gap := traveler - _at
	if species in [Species.KITE, Species.OWL]:
		gap.y *= .3
	var threshold: float = ALERT_RADIUS[species]
	var near := gap.length_squared() < threshold * threshold
	var startle := danger or (near and (traveler_speed > .7 or gap.length_squared() < threshold * threshold * .35))
	if activity == Activity.CALM and startle:
		activity = Activity.ALERT
		_state_time = 0.0
	elif activity == Activity.ALERT and _state_time >= .2 + .11 * (1.0 + sin(_phase)):
		_move_to(refuge, Activity.FLEEING)
	elif activity == Activity.HIDING and not near and not danger and _state_time > 3.8 + fmod(_phase, 2.2):
		_move_to(home, Activity.RETURNING)
	elif activity == Activity.RETURNING and startle and _at.distance_squared_to(refuge) > 1.2:
		_move_to(refuge, Activity.FLEEING)
	var previous := _at
	if activity == Activity.FLEEING or activity == Activity.RETURNING:
		var p := clampf(_state_time / _duration, 0.0, 1.0)
		_at = _from.lerp(_to, smoothstep(0.0, 1.0, p))
		if species == Species.OWL or species == Species.KITE:
			_at.y += sin(p * PI) * 2.0
		if p >= 1.0:
			activity = Activity.HIDING if activity == Activity.FLEEING else Activity.CALM
			_state_time = 0.0
	elif activity == Activity.CALM:
		# Ease into the local grazing/swimming circuit after returning to its starting point.
		_at = home + _ambient_offset() * smoothstep(0.0, 1.2, _state_time)
	var movement := _at - previous
	var horizontal := Vector2(movement.x, movement.z)
	var speed := horizontal.length() / maxf(delta,.001)
	_pace = lerpf(_pace, clampf(speed / float(RUN_SPEED[species]), 0, 1), 1.0-exp(-delta*8.0))
	_stride += delta * (2.0 + _pace * 12.0)
	if horizontal.length_squared() > .0000002:
		_heading = lerp_angle(_heading, atan2(-movement.x,-movement.z), 1.0-exp(-delta*9.0))
	rotation.y = _heading
	global_position = _at
	if _walks_on_ground() and not authored_footing:
		_place_on_ground(delta)
	_pose(delta)

func _move_to(target: Vector3, next: Activity) -> void:
	activity = next
	_state_time = 0.0
	_from = _at
	_to = target
	_duration = maxf(.55, _from.distance_to(target) / float(RUN_SPEED[species]))
	if next == Activity.RETURNING:
		_duration *= 1.65

func _ambient_offset() -> Vector3:
	var t := _time
	match species:
		Species.FISH:
			return Vector3(sin(t*.57+_phase*.12)*1.14, sin(t*1.6+_phase)*.035, cos(t*.57+_phase*.12)*.60)
		Species.OTTER:
			return Vector3(sin(t*.52+_phase)*1.42, -.09-.20*pow(maxf(0, sin(t*.68+_phase)), 2), cos(t*.52+_phase)*.18)
		Species.KITE:
			return Vector3(cos(t*.30+_phase)*5.0, sin(t*.67+_phase)*.65, sin(t*.30+_phase)*3.4)
		Species.GOAT, Species.DEER:
			return Vector3(sin(t*.23+_phase)*.57,0,cos(t*.23+_phase)*.28)
	return Vector3.ZERO

func _place_on_ground(delta: float) -> void:
	if not _grounded_height or Vector2(_floor_sample.x-_at.x, _floor_sample.z-_at.z).length_squared() > .065:
		_floor_sample = _at
		var query := PhysicsRayQueryParameters3D.create(_at+Vector3.UP*4.5, _at-Vector3.UP*5.5, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		_ground_y = float(hit.position.y) if not hit.is_empty() else _at.y
		if not _grounded_height:
			_model.position.y = _ground_y-_at.y
			_grounded_height = true
	_model.position.y = lerpf(_model.position.y,_ground_y-_at.y,1.0-exp(-delta*18.0))

func _pose(delta: float) -> void:
	var t := _time + _phase
	var alert := activity == Activity.ALERT
	var fleeing := activity == Activity.FLEEING
	if _head:
		var look := sin(t*1.27)*.14
		var nod := sin(t*1.6)*.045
		if species == Species.DEER or species == Species.GOAT:
			nod += smoothstep(.12,.85,sin(t*.64))*.91 if activity == Activity.CALM else -.14
		elif species == Species.OWL:
			look = sin(t*.57)*.9 if activity == Activity.CALM else .0
		elif species == Species.OTTER and activity == Activity.CALM:
			nod -= smoothstep(.22,.86,sin(t*.75))*.30
		_head.rotation.y = lerp_angle(_head.rotation.y, look, 1.0-exp(-delta*6.0))
		_head.rotation.x = lerp_angle(_head.rotation.x, -.23 if alert else -nod, 1.0-exp(-delta*9.0))
	if _tail:
		var sway := .32 if species in [Species.FISH, Species.OTTER] else .10
		_tail.rotation.y = sin(t*(6.6 if species==Species.FISH else 3.0)+_stride)*sway
	for i in _legs.size():
		var phase := _stride + (PI if i in [1,2] else 0.0)
		_legs[i].rotation.x = sin(phase) * _pace * (.80 if species==Species.FROG else .54)
	if species in [Species.FROG, Species.PIKA]:
		var jump := absf(sin(_stride)) * _pace
		_model.position.y = (_ground_y-_at.y if species==Species.PIKA else 0.0) + jump * (.28 if species==Species.FROG else .13)
		_model.rotation.x = cos(_stride) * _pace * .29
	elif species == Species.FISH or species == Species.OTTER:
		_model.rotation.z = sin(t*3.4)*.071
		_model.rotation.x = sin(t*3.2)*(.04 if species == Species.FISH else .17)
	if _wing_l:
		var flying := species == Species.KITE or activity in [Activity.FLEEING,Activity.RETURNING]
		var flap := sin(t*(10.1 if fleeing else 6.1))
		var wing := flap*(.66 if fleeing else .35) if flying else .15
		var fold := 0.0 if flying else 1.32
		_wing_l.rotation.z = lerpf(_wing_l.rotation.z, -wing, 1.0-exp(-delta*15.0))
		_wing_r.rotation.z = -_wing_l.rotation.z
		_wing_l.rotation.y = lerpf(_wing_l.rotation.y, fold, 1.0-exp(-delta*8.0))
		_wing_r.rotation.y = -_wing_l.rotation.y
		_model.rotation.z = sin(t*.55)*.19 if flying else 0.0
