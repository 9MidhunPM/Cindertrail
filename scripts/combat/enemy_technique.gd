extends Node3D
## One telegraphed special at a time. Movement, hits and lane ownership stay on the actor.
enum Phase { READY, WINDUP, ACTIVE, RECOVER }
const RAM := &"quarry_ram"
const SKIMMER := &"ford_skimmer"
const SPLINTER := &"splinterback"
const WARDEN := &"bell_warden"
const VOLLEY_RADIUS := 1.65

var body: CinderEnemy
var phase := Phase.READY
var clock := 0.0
var duration := 1.0
var cooldown := 0.8
var mark := Vector3.ZERO
var ward: CinderEnemy
var in_water := false
var _ring: MeshInstance3D
var _body_cue: MeshInstance3D
static var _hoop: TorusMesh
static var _inks: Dictionary[Color, StandardMaterial3D] = {}

func bind(actor: CinderEnemy) -> void:
	body = actor

func advance(delta: float, wet: bool, field: float, target: Vector3, distance: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	var species := body.stats.species
	if species == SKIMMER:
		if wet and not in_water and cooldown <= 0.0:
			body.cue.emit("skimmer_wake")
			cooldown = 3.0
		in_water = wet
		if wet:
			_show_body_cue(Color("#5be6cf"), 0.8 + 0.12 * sin(body.stride))
		elif _body_cue:
			_body_cue.hide()
		return
	if phase != Phase.READY:
		if species == RAM and field < 0.95 and phase != Phase.RECOVER:
			body.disrupt(0.65)
			return
		if species == WARDEN and phase != Phase.RECOVER and not _valid_ally(ward):
			cancel()
			return
		clock = maxf(0.0, clock - delta)
		_visualize()
		if clock <= 0.0:
			_next_phase()
		return
	if cooldown > 0.0 or body.is_disrupted():
		return
	match species:
		RAM:
			if field >= 0.95 and distance > 2.0 and distance < 10.5:
				body.cue.emit("ram_stamp")
				_set_phase(Phase.WINDUP, 0.90)
		SPLINTER:
			if distance > 2.3 and distance < 9.5 and _line_clear(target):
				mark = target
				body.cue.emit("splinter_rattle")
				_set_phase(Phase.WINDUP, 1.05)
				_ground_mark()
		WARDEN:
			var fight := body.get_parent() as CinderBattle
			if fight:
				ward = _choose_ally(fight)
			if is_instance_valid(ward):
				body.cue.emit("warden_chime")
				_set_phase(Phase.WINDUP, 0.85)

func _line_clear(point: Vector3) -> bool:
	var start := body.body_center() + Vector3.UP * 0.25
	var end := point + Vector3.UP * 0.45
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start, end, 1)).is_empty()

func _choose_ally(fight: CinderBattle) -> CinderEnemy:
	var best: CinderEnemy
	var nearest := 5.5 * 5.5
	for candidate in fight.enemies:
		if not _valid_ally(candidate) or candidate.is_warded():
			continue
		var d := candidate.global_position.distance_squared_to(body.global_position)
		if d < nearest:
			nearest = d
			best = candidate
	return best

func _valid_ally(other: CinderEnemy) -> bool:
	return is_instance_valid(other) and other != body and not other.fading and other.health > 0.0 and other.stats.species != WARDEN and other.stats.species != &"vesper" and other.global_position.distance_squared_to(body.global_position) < 7.0 * 7.0

func _set_phase(value: Phase, seconds: float) -> void:
	phase = value
	clock = seconds
	duration = seconds

func _next_phase() -> void:
	if phase == Phase.WINDUP:
		match body.stats.species:
			RAM:
				_set_phase(Phase.ACTIVE, 0.85)
			SPLINTER:
				body.volley.emit(body.body_center() + Vector3.UP * 0.18, mark, VOLLEY_RADIUS, body.stats.damage)
				_recover(0.48)
			WARDEN:
				if ward.is_warded():
					cancel()
					return
				ward.warded_by = body
				_set_phase(Phase.ACTIVE, 2.0)
	elif phase == Phase.ACTIVE:
		_recover(0.62)
	else:
		phase = Phase.READY
		cooldown = 4.0 if body.stats.species == WARDEN else 3.5

func _release() -> void:
	if is_instance_valid(ward) and ward.warded_by == body:
		ward.warded_by = null
	ward = null
	if _ring:
		_ring.hide()
	if _body_cue:
		_body_cue.hide()

func _recover(seconds: float) -> void:
	_release()
	_set_phase(Phase.RECOVER, seconds)

func cancel() -> void:
	if phase == Phase.WINDUP or phase == Phase.ACTIVE:
		_recover(0.7)

func movement_factor() -> float:
	if phase == Phase.WINDUP:
		return 0.0
	if phase == Phase.ACTIVE and body.stats.species == RAM:
		return 2.9
	if phase == Phase.RECOVER:
		return 0.35
	if phase == Phase.ACTIVE and body.stats.species == WARDEN:
		return 0.45
	return 1.0

func opening() -> float:
	if phase == Phase.WINDUP:
		return smoothstep(0.0, 0.75, 1.0 - clock / duration)
	return 1.0 if phase == Phase.ACTIVE else 0.0

func _visualize() -> void:
	match body.stats.species:
		RAM:
			if phase == Phase.WINDUP:
				_show_body_cue(Color("#e38b59"), 0.56 + 0.28 * opening())
		SPLINTER:
			if _ring and phase == Phase.WINDUP:
				_ring.scale = Vector3.ONE * VOLLEY_RADIUS * (0.78 + 0.22 * opening())
		WARDEN:
			if phase == Phase.ACTIVE:
				_ring = _make_hoop(_ring, Color("#a4e7cb"))
				_ring.global_position = ward.body_center()
				_ring.scale = Vector3.ONE * (ward.stats.radius + 0.39)
				_ring.rotation.z = 0.3
			if phase != Phase.RECOVER:
				_show_body_cue(Color("#8ddeb8"), 0.54 + 0.16 * opening())

func _ground_mark() -> void:
	var from := mark + Vector3.UP * 0.65
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, mark + Vector3.DOWN * 4.0, 1))
	_ring = _make_hoop(_ring, Color("#d892ce"))
	_ring.global_position = (hit.position as Vector3 if not hit.is_empty() else mark) + Vector3.UP * 0.045
	_ring.scale = Vector3.ONE * VOLLEY_RADIUS
	_ring.rotation = Vector3.ZERO

func _show_body_cue(tint: Color, radius: float) -> void:
	_body_cue = _make_hoop(_body_cue, tint)
	_body_cue.global_position = body.global_position + Vector3.UP * 0.09
	_body_cue.scale = Vector3(radius, 0.45, radius)

func _make_hoop(existing: MeshInstance3D, tint: Color) -> MeshInstance3D:
	if existing:
		existing.show()
		return existing
	if not _hoop:
		_hoop = TorusMesh.new()
		_hoop.inner_radius = 0.968
		_hoop.outer_radius = 1.0
		_hoop.rings = 36
		_hoop.ring_segments = 4
	if not _inks.has(tint):
		var ink := StandardMaterial3D.new()
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.albedo_color = tint
		_inks[tint] = ink
	var result := MeshInstance3D.new()
	result.mesh = _hoop
	result.material_override = _inks[tint]
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(result)
	result.top_level = true
	return result
