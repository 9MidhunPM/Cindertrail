class_name CinderMelee
extends Node
## The traveler's sunsteel combo: buffered input, aim assist, lunges and the
## feel of contact (sparks, hit-stop and camera shake). Damage resolves through
## CinderBattle so every creature still belongs to one enemy budget.

const ATTACKS := preload("res://scripts/hero/traveler_attacks.gd")
const COMBO_WINDOW := 0.55
const BUFFER := 0.28
const ASSIST_RANGE := 4.2
const ASSIST_ARC := 1.1

signal swung(index: int, hits: int)

var player: CinderPlayer
var battle: CinderBattle
var director: CinderCamera
var _combo := 0
var _since_swing := 99.0
var _buffered := 0.0
var _buffer_direction := Vector3.ZERO
var _trail: CinderBladeTrail

func bind(traveler: CinderPlayer, fight: CinderBattle, camera: CinderCamera) -> void:
	player = traveler
	battle = fight
	director = camera
	player.visual.strike.connect(_on_strike)
	_trail = CinderBladeTrail.new()
	_trail.source = player.visual
	add_child(_trail)

## Ask for the next swing toward a world direction. Returns true if it started.
func request(direction: Vector3) -> bool:
	_buffered = BUFFER
	_buffer_direction = direction
	return _try_swing()

func _try_swing() -> bool:
	if player == null or _buffered <= 0.0:
		return false
	if _since_swing > COMBO_WINDOW + ATTACKS.length(maxi(_combo - 1, 0)):
		_combo = 0
	var index := _combo % ATTACKS.COUNT
	if not player.visual.attack(index):
		return false
	_buffered = 0.0
	var aim := _assist(_buffer_direction)
	player.visual.rotation.y = atan2(-aim.x, -aim.z)
	player.attack_hold = ATTACKS.length(index) * 0.8
	_combo = index + 1
	_since_swing = 0.0
	return true

func _assist(direction: Vector3) -> Vector3:
	var aim := direction.slide(Vector3.UP).normalized()
	if aim.length_squared() < 0.5:
		aim = -player.visual.global_basis.z.slide(Vector3.UP).normalized()
	var best: CinderEnemy
	var score := INF
	for enemy in battle.enemies:
		var offset := (enemy.global_position - player.global_position).slide(Vector3.UP)
		if offset.length() > ASSIST_RANGE or offset.length() < 0.05:
			continue
		var angle := aim.angle_to(offset.normalized())
		if angle < ASSIST_ARC and offset.length() + angle * 2.0 < score:
			score = offset.length() + angle * 2.0
			best = enemy
	if best:
		return (best.global_position - player.global_position).slide(Vector3.UP).normalized()
	return aim

func _on_strike(index: int) -> void:
	var hit := ATTACKS.hit(index)
	var forward := -player.visual.global_basis.z.slide(Vector3.UP).normalized()
	player.lunge = forward * float(hit.lunge)
	var hits := battle.melee(player.global_position, forward, hit.reach, hit.arc, hit.damage, hit.knock)
	var heavy := index == ATTACKS.COUNT - 1
	if heavy:
		CinderImpactBurst.spawn(self, player.global_position + forward * 0.9 + Vector3.UP * 0.05, 26, hit.reach)
		director.add_trauma(0.55)
	if hits > 0:
		CinderImpactBurst.spawn(self, player.global_position + forward * 1.1 + Vector3.UP * 0.75, 10 + hits * 4)
		director.add_trauma(0.22 + 0.08 * hits)
		_hit_stop(0.085 if heavy else 0.05)
	swung.emit(index, hits)

## Freeze the world for a few frames of real time on solid contact.
func _hit_stop(seconds: float) -> void:
	if DisplayServer.get_name() == "headless" or get_tree().paused:
		return
	Engine.time_scale = 0.06
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0

func _physics_process(delta: float) -> void:
	_since_swing += delta
	if _buffered > 0.0:
		_buffered -= delta
		_try_swing()

func _exit_tree() -> void:
	Engine.time_scale = 1.0
