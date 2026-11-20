class_name CinderEnemy
extends CharacterBody3D

signal cue(name: String)
signal volley(origin: Vector3, target: Vector3, radius: float, damage: float)

const TECHNIQUE := preload("res://scripts/combat/enemy_technique.gd")
var technique: TECHNIQUE
var warded_by: CinderEnemy
var _lens_hits := 0
var _lens_time := 0.0
var _lens_power := 0.0
var _reed_time := 0.0
var _reed_factor := 1.0
var counts_for_wave := false
var award_bounty := true
var is_roamer := false
var stats: CinderEnemyStats
var health: float
var site_of_origin: CinderSite
var origin_lane := -1
var route: PackedVector3Array
var pursuing := false
var fading := false
var step := 0
var stride := 0.0
const ATTACK_INTERVAL := 1.15
var attack_timer := 0.5
var gait_weight := 0.0
var breath := 0.0
var strike := 0.0
var windup := 0.0
var model: Node3D
var base_scale := Vector3.ONE
var last_hit := 0.0
var separation := Vector3.ZERO
var _articulation := preload("res://scripts/combat/enemy_pose.gd").new()
var fissure: StandardMaterial3D
var _disruption := 0.0
var _fallback := Vector3.INF
## Melee knockback velocity, decaying back to zero.
var knock := Vector3.ZERO
var _flash := 0.0
var _flash_meshes: Array[MeshInstance3D] = []
static var _flash_material: ShaderMaterial

func configure(spec: CinderEnemyStats, path: PackedVector3Array, camp: CinderSite) -> void:
	set_physics_process(false)
	stats = spec
	health = stats.health
	site_of_origin = camp
	route = path.duplicate()
	model = stats.model.instantiate() as Node3D
	add_child(model)
	base_scale = Vector3.ONE * stats.model_scale
	_articulation.bind(model)
	model.scale = base_scale
	# Vary breathing independently from locomotion without consuming wave RNG.
	breath = fmod(get_instance_id() * 0.63, TAU)
	if stats.species in [TECHNIQUE.SKIMMER, TECHNIQUE.RAM, TECHNIQUE.SPLINTER, TECHNIQUE.WARDEN]:
		technique = TECHNIQUE.new()
		add_child(technique)
		technique.bind(self)
	_bind_emissive_seams()
	collision_layer = 0
	collision_mask = 1
	floor_snap_length = 0.55
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = stats.radius
	capsule.height = maxf(stats.height, capsule.radius * 2.0)
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5 + 0.02
	add_child(shape)
	global_position = route[0] + Vector3.UP * 0.09
	step = 1

func _bind_emissive_seams() -> void:
	# Each moving plate group shares its atlas and has a separate emissive vein surface.
	for piece: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in piece.get_surface_override_material_count():
			var source := piece.get_active_material(surface) as StandardMaterial3D
			if source and source.emission_enabled:
				if not fissure:
					fissure = source.duplicate()
				piece.set_surface_override_material(surface, fissure)

func _pose(delta: float, distance: float, near: bool, core_distance: float) -> void:
	var crawler := stats.species in [&"crawler", TECHNIQUE.SKIMMER]
	var gait_speed := distance / maxf(delta, 0.001)
	gait_weight = lerpf(gait_weight, clampf(gait_speed / stats.speed, 0.0, 1.0), 1.0 - exp(-12.0 * delta))
	# The feet advance with distance even while slowed by water or a field.
	stride = fmod(stride + distance * stats.stride_frequency, TAU)
	breath = fmod(breath + delta * (2.9 if crawler else 1.8), TAU)
	strike = maxf(0.0, strike - delta / (0.24 if crawler else 0.34))
	last_hit = maxf(0.0, last_hit - delta)
	var anticipation := 0.0
	if attack_timer < 0.36 and is_zero_approx(strike):
		anticipation = 1.0 - smoothstep(0.0, 0.36, attack_timer)
		if not near:
			anticipation *= 1.0 - smoothstep(1.4, 2.6, core_distance)
	windup = lerpf(windup, anticipation, 1.0 - exp(-18.0 * delta))
	var hit := sin(PI * clampf(last_hit / 0.15, 0.0, 1.0))
	var thrust := smoothstep(0.0, 0.93, strike)
	if near and attack_timer <= 0.09 and attack_timer >= 0.0:
		thrust = maxf(thrust, 1.0 - smoothstep(0.0, 0.09, attack_timer))
	_articulation.advance(self, delta, thrust, hit)
	var bob := (1.0 - cos(stride * 2.0)) * gait_weight
	var brace := technique.opening() if technique and stats.species == TECHNIQUE.RAM else 0.0
	model.position.y = 0.015 + sin(breath) * 0.012 + bob * (0.026 if crawler else 0.045) - windup * 0.07 - brace * 0.08
	model.position.z = thrust * (0.36 if crawler else 0.24) - windup * 0.10 - hit * 0.10
	model.rotation.x = thrust * 0.24 - windup * 0.14 - hit * 0.15 - brace * 0.1
	model.rotation.z = sin(stride) * gait_weight * (0.060 if crawler else 0.12) + hit * 0.12
	if fissure:
		var special_glow := technique.opening() if technique else 0.0
		fissure.emission_energy_multiplier = 0.90 + 0.18 * sin(breath) + windup * 1.45 + special_glow * 0.8 + hit * 1.6

func spark_radius() -> float:
	return maxf(.85, stats.height)

func combat_hit(amount: float, _source: StringName) -> void:
	wound(amount)

func wound(amount: float) -> void:
	health -= amount
	last_hit = 0.15

## Knock the creature away from a blade strike and stagger it briefly.
func shove(push: Vector3, stun: float) -> void:
	knock = push.slide(Vector3.UP) * stats.knock_factor
	disrupt(stun * lerpf(0.3, 1.0, stats.knock_factor))
	if stats.knock_factor >= 0.75 and push.length() > 6.0:
		velocity.y = 3.2

## White hit flash drawn as a temporary overlay pass.
func flash() -> void:
	if _flash_material == null:
		_flash_material = ShaderMaterial.new()
		_flash_material.shader = preload("res://scripts/combat/hit_flash.gdshader")
	if _flash_meshes.is_empty():
		for piece in model.find_children("*", "MeshInstance3D", true, false):
			_flash_meshes.append(piece)
	_flash = 1.0
	for piece in _flash_meshes:
		piece.material_overlay = _flash_material
		piece.set_instance_shader_parameter(&"flash", 1.0)

func _fade_flash(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash = maxf(0.0, _flash - delta / 0.14)
	for piece in _flash_meshes:
		if _flash <= 0.0:
			piece.material_overlay = null
		else:
			piece.set_instance_shader_parameter(&"flash", _flash)

func disrupt(duration: float, push_back := false) -> void:
	if technique:
		technique.cancel()
	_disruption = maxf(_disruption, duration)
	attack_timer = maxf(attack_timer, duration + 0.25)
	_fallback = route[clampi(step - 2, 0, route.size() - 2)] if push_back and route.size() > 1 else Vector3.INF
	last_hit = 0.15

func is_disrupted() -> bool:
	return _disruption > 0.0

func is_warded() -> bool:
	return is_instance_valid(warded_by) and not warded_by.fading and warded_by.health > 0.0

func set_lensmark(seconds: float, hits: int, power: float) -> void:
	_lens_time = seconds
	_lens_hits = hits
	_lens_power = power
	set_physics_process(_lens_time > 0.0 or _reed_time > 0.0)

func lensmarked() -> bool:
	return _lens_time > 0.0 and _lens_hits > 0 and not fading

func consume_mark_bonus(source: StringName) -> float:
	if source not in [&"spark", &"melee"] or not lensmarked():
		return 0.0
	_lens_hits -= 1
	return _lens_power

func reed_snare(factor: float, seconds: float) -> void:
	_reed_time = seconds
	_reed_factor = factor
	set_physics_process(_lens_time > 0.0 or _reed_time > 0.0)

func _physics_process(delta: float) -> void:
	_lens_time = maxf(0.0, _lens_time - delta)
	_reed_time = maxf(0.0, _reed_time - delta)
	if _reed_time <= 0.0 and _lens_time <= 0.0:
		set_physics_process(false)

func direct_hit() -> void:
	if technique and stats.species in [TECHNIQUE.SPLINTER, TECHNIQUE.WARDEN]:
		technique.cancel()

func body_center() -> Vector3:
	return global_position + Vector3.UP * stats.height * 0.7

func follow_trail(point: Vector3) -> void:
	if route.is_empty() or route[-1].distance_squared_to(point) >= 0.65:
		if step > 24:
			route = route.slice(step)
			step = 0
		route.append(point)

func advance(core: SunCore, delta: float, field_factor: float) -> bool:
	if _reed_time > 0.0:
		field_factor = minf(field_factor, _reed_factor)
	var target := core.global_position
	while step < route.size() and flat_distance(global_position, route[step]) < 0.6:
		step += 1
	var waypoint := route[step] if step < route.size() else target
	var direction := waypoint - global_position
	direction.y = 0
	var close_to_target := flat_distance(global_position, target) < 1.35 and absf(target.y - global_position.y) < 2.5
	var near := close_to_target and step >= route.size() - 1
	var wet := is_instance_valid(site_of_origin) and site_of_origin.wet_depth_at(global_position)
	var speed := stats.speed * field_factor * (stats.water_factor if wet else 1.0)
	if technique:
		technique.advance(delta, wet, field_factor, target, flat_distance(global_position, target))
		speed *= technique.movement_factor()
		if technique.phase == TECHNIQUE.Phase.WINDUP:
			near = false
	var movement := Vector3.ZERO
	if _disruption > 0.0:
		_disruption = maxf(0.0, _disruption - delta)
		near = false
		if _fallback != Vector3.INF and flat_distance(global_position, _fallback) > 0.45:
			movement = (_fallback - global_position).slide(Vector3.UP).normalized() * 5.0
	elif not near:
		movement = (direction.normalized() + separation.limit_length(0.55)).normalized() * speed
		if movement.length_squared() > 0.001:
			rotation.y = lerp_angle(rotation.y, atan2(movement.x, movement.z), 1.0-exp(-10*delta))
	if knock.length_squared() > 0.0004:
		movement += knock
		knock = knock.move_toward(Vector3.ZERO, delta * 16.0)
	_fade_flash(delta)
	velocity.x = movement.x
	velocity.z = movement.z
	velocity.y = maxf(velocity.y - 18.0 * delta, -14.0)
	var before := global_position
	move_and_slide()
	if is_on_floor() and movement.length_squared() > 0.1 and flat_distance(before, global_position) < speed * delta * 0.35:
		_climb_step(movement.normalized())
	attack_timer -= delta
	if near and target.distance_squared_to(global_position) > 0.001:
		var aim := target - global_position
		rotation.y = lerp_angle(rotation.y, atan2(aim.x, aim.z), 1.0 - exp(-10.0 * delta))
	var connected := false
	if near and attack_timer <= 0.0:
		var from := body_center()
		var to := Vector3(target.x, maxf(from.y, target.y + 0.25), target.z)
		var sight := PhysicsRayQueryParameters3D.create(from, to, 1)
		if get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
			attack_timer = ATTACK_INTERVAL
			strike = 1.0
			connected = true
	_pose(delta, flat_distance(before, global_position), near, flat_distance(global_position, target))
	return connected

# Jolt slides capsules against vertical risers. Only step onto a verified floor
# within one low stone course; solid walls and gaps keep blocking movement.
func _climb_step(forward: Vector3) -> void:
	var lift := Vector3.UP * 0.33
	if test_move(global_transform, lift):
		return
	var lifted := global_transform.translated(lift)
	var advance_by := forward * 0.24
	if test_move(lifted, advance_by):
		return
	var landing := KinematicCollision3D.new()
	if not test_move(lifted.translated(advance_by), -lift - Vector3.UP * 0.04, landing):
		return
	if landing.get_normal().y < 0.70:
		return
	global_position += lift + advance_by + landing.get_travel()
	velocity.y = 0.0

func withdraw(defeated := false) -> void:
	if fading:
		return
	fading = true
	if technique:
		technique.cancel()
		technique.hide()
	var tween := create_tween()
	if defeated:
		var crawler := stats.species in [&"crawler", TECHNIQUE.SKIMMER]
		# Break the silhouette first, then let the fallen shell sink into the ground.
		tween.set_parallel(true)
		tween.tween_property(model, "rotation:z", 0.62 if crawler else -0.94, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(model, "position:y", 0.02 if crawler else -0.16, 0.24)
		_articulation.collapse(tween, stats.species)
		if fissure:
			tween.tween_property(fissure, "emission_energy_multiplier", 0.0, 0.36)
		tween.chain().tween_property(model, "scale", base_scale * 0.03, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		tween.tween_property(model, "scale", Vector3.ZERO, 0.4)
	tween.chain().tween_callback(queue_free)

static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
