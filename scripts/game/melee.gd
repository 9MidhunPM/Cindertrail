class_name CinderMelee
extends Node
## Sunsteel tap combo and hold-release spin, sharing the battle's enemy budget.

const ATTACKS := preload("res://scripts/hero/traveler_attacks.gd")
const COMBO_WINDOW := 0.55
const BUFFER := 0.28
const ASSIST_RANGE := 4.2
const CHARGE_TIME := 0.65
const DASH_FOLLOW := 0.25

signal swung(index: int, hits: int)
signal sword_cue(cue: String)

var player: CinderPlayer
var battle: CinderBattle
var director: CinderCamera
var hit_stop_enabled := true
var _combo := 0
var _since_swing := 99.0
var _buffered := 0.0
var _buffer_direction := Vector3.ZERO
var _buffer_spin := false
var _buffer_variant := -1
var _dash_follow := 0.0
var _jump_armed := false
var _held_source: StringName
var _held_seconds := 0.0
var _spin_active := false
var _spin_progress := 0.0
var _spin_forward := Vector3.FORWARD
var _spin_hits := {}
var _stop_serial := 0

func bind(traveler: CinderPlayer, fight: CinderBattle, camera: CinderCamera) -> void:
	player = traveler
	battle = fight
	director = camera
	player.visual.strike.connect(_on_strike)
	player.movement_used.connect(_on_movement)
	player.dash_segment.connect(_on_dash_segment)
	battle.damaged.connect(_on_damage)
	var trail := CinderBladeTrail.new()
	trail.source = player.visual
	trail.director = director
	add_child(trail)

func _on_movement(kind: StringName) -> void:
	_jump_armed = kind == &"jump"
	_dash_follow = DASH_FOLLOW if kind == &"dash" else 0.0

func _on_dash_segment(kind: StringName, _from: Vector3, _to: Vector3) -> void:
	if kind == &"dash":
		_dash_follow = DASH_FOLLOW

func _accept_input() -> bool:
	return player.move_enabled and not player.is_staggered() and (not player.is_dashing() or _dash_follow > 0.0)

## Input from one physical binding owns its charge through release.
func press(direction: Vector3, source: StringName) -> bool:
	if not _held_source.is_empty() or not _accept_input():
		return false
	_held_source = source
	_held_seconds = 0.0
	return request(direction)

func release(source: StringName, direction: Vector3 = Vector3.INF) -> bool:
	if _held_source != source or source.is_empty():
		return false
	var ready := _held_seconds >= CHARGE_TIME
	_held_source = &""
	_held_seconds = 0.0
	player.visual.set_charge(0.0)
	if ready and _accept_input():
		if direction.is_finite():
			_buffer_direction = direction
		_buffer_spin = true
		_buffered = BUFFER
		return _try_swing()
	return false

## A single tap, also used by the direct gameplay entry point.
func request(direction: Vector3) -> bool:
	if not _accept_input():
		return false
	_buffered = BUFFER
	_buffer_spin = false
	_buffer_direction = direction
	_buffer_variant = -1
	if _dash_follow > 0.0 and player.is_on_floor():
		_buffer_variant = ATTACKS.DASH_CUT
	elif _jump_armed and not player.is_on_floor() and player.velocity.y < -0.22:
		_buffer_variant = ATTACKS.DESCENT
	if player.is_dashing():
		return true
	return _try_swing()

func cancel() -> void:
	_held_source = &""
	_held_seconds = 0.0
	_buffered = 0.0
	_buffer_spin = false
	_buffer_variant = -1
	_dash_follow = 0.0
	_jump_armed = false
	_combo = 0
	_spin_active = false
	_spin_hits.clear()
	player.visual.cancel_attack()
	player.clear_swing()
	_stop_serial += 1
	if hit_stop_enabled:
		Engine.time_scale = 1.0

func _try_swing() -> bool:
	if not player.move_enabled or player.is_staggered() or player.is_dashing() or _buffered <= 0.0:
		return false
	if _since_swing > COMBO_WINDOW + ATTACKS.length(maxi(_combo - 1, 0)):
		_combo = 0
	var index := _combo % ATTACKS.COUNT
	if _buffer_spin:
		index = ATTACKS.SPIN
	elif _buffer_variant >= 0:
		index = _buffer_variant
	if not player.visual.attack(index):
		return false
	_buffered = 0.0
	_buffer_spin = false
	_buffer_variant = -1
	_dash_follow = 0.0
	if index == ATTACKS.DESCENT:
		_jump_armed = false
	var fallback := _buffer_direction.slide(Vector3.UP).normalized()
	if fallback.length_squared() < 0.5:
		fallback = -player.visual.global_basis.z.slide(Vector3.UP).normalized()
	var target := battle.closest_melee_target(player.global_position, ASSIST_RANGE)
	player.commit_swing(target, fallback, ATTACKS.impact(index), ATTACKS.length(index) * 0.8)
	if index == ATTACKS.SPIN:
		_combo = 0
		sword_cue.emit("spin")
	elif index < ATTACKS.COUNT:
		_combo = index + 1
	else:
		_combo = 0
	_since_swing = 0.0
	return true

func _on_damage(point: Vector3, _amount: float, source: StringName, _fatal: bool) -> void:
	if source == &"melee":
		CinderImpactBurst.spawn(self, point, 3 if director.reduced_motion else 10)

func _on_strike(index: int) -> void:
	var hit := ATTACKS.hit(index)
	var forward := -player.visual.global_basis.z.slide(Vector3.UP).normalized()
	if index == ATTACKS.SPIN:
		_spin_active = true
		_spin_hits.clear()
		_spin_progress = 0.0
		_spin_forward = forward
		return
	player.lunge = forward * float(hit.lunge)
	var hits := battle.melee(player.global_position, forward, hit.reach, hit.arc, hit.damage, hit.knock)
	var heavy := index == ATTACKS.COUNT - 1 or index == ATTACKS.DESCENT
	if heavy:
		var point := player.global_position + forward * .65 + Vector3.UP * .05
		var radius := float(hit.reach) * (.45 if director.reduced_motion else .83)
		CinderImpactBurst.spawn(self, point, 4 if director.reduced_motion else 24, radius)
		if not director.reduced_motion:
			director.add_trauma(.50)
	elif index == ATTACKS.DASH_CUT and hits > 0:
		var edge := player.visual.blade_segment()[1]
		CinderImpactBurst.spawn(self, edge, 2 if director.reduced_motion else 8)
	if hits > 0:
		director.add_trauma(0.22 + 0.08 * hits)
		_hit_stop(0.085 if heavy else 0.05)
	swung.emit(index, hits)

func _sweep_spin() -> void:
	var progress: float = ATTACKS.spin_progress(player.visual.attack_age())
	var middle := (_spin_progress + progress) * 0.5
	var facing := _spin_forward.rotated(Vector3.UP, ATTACKS.SPIN_START_YAW + ATTACKS.SPIN_TURN_SIGN * TAU * middle)
	var half_arc := (progress - _spin_progress) * PI + 0.07
	var hit := ATTACKS.hit(ATTACKS.SPIN)
	var first_contact := _spin_hits.is_empty()
	var count := battle.melee(player.global_position, facing, hit.reach, half_arc, hit.damage, hit.knock, _spin_hits)
	if first_contact and count:
		sword_cue.emit("impact")
		director.add_trauma(0.28)
		_hit_stop(0.045)
	_spin_progress = progress
	if progress >= 1.0:
		_spin_active = false
		swung.emit(ATTACKS.SPIN, _spin_hits.size())

func _hit_stop(seconds: float) -> void:
	if not hit_stop_enabled or DisplayServer.get_name() == "headless" or director.reduced_motion or get_tree().paused:
		return
	_stop_serial += 1
	var serial := _stop_serial
	Engine.time_scale = 0.06
	await get_tree().create_timer(seconds, true, false, true).timeout
	if serial == _stop_serial:
		Engine.time_scale = 1.0

func _physics_process(delta: float) -> void:
	_since_swing += delta
	_dash_follow = maxf(0.0, _dash_follow - delta)
	if player.is_on_floor():
		_jump_armed = false
	if _spin_active:
		_sweep_spin()
	if not _held_source.is_empty() and _held_seconds < CHARGE_TIME:
		# Hit-stop slows animation, while the physical hold threshold stays constant.
		var hold_delta := delta / maxf(Engine.time_scale, 0.001)
		_held_seconds = minf(CHARGE_TIME, _held_seconds + hold_delta)
		player.visual.set_charge(_held_seconds / CHARGE_TIME)
		if _held_seconds >= CHARGE_TIME:
			sword_cue.emit("blade_ready")
	if _buffered > 0.0:
		_buffered -= delta
		_try_swing()

func _exit_tree() -> void:
	if hit_stop_enabled:
		Engine.time_scale = 1.0
