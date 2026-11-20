extends Node3D
## Each recovered art has its own cooldown. A brief recovery separates consecutive casts.
signal achievement_unlocked(title: String)
const PROFILE := preload("res://scripts/game/art_achievements.gd")
const CAST_RECOVERY := 0.28
const SWORD_BUFFER := 0.20
const SPEC := preload("res://scripts/game/traveler_art_spec.gd")
const FX := preload("res://scripts/fx/traveler_art_effect.gd")
const REEDS := preload("res://data/abilities/flooded_grove.tres")
const SLUICE := preload("res://data/abilities/sunken_aqueduct.tres")
const WICK := preload("res://data/abilities/last_lantern_frontier.tres")
const ARTS := PROFILE.ARTS
var profile := PROFILE.new()
var profile_enabled := true
var reduced_motion := false
var _owned: Array[StringName] = []
var _selected: SPEC
var _cooldowns := {}
var _cast_lock := 0.0
var _queued_site: StringName
var _queued_aim: Vector3
var _queued_ground: Vector3
var _buffer_left := 0.0
var _available := false
var _player: CinderPlayer
var _battle: CinderBattle
var _core: SunCore
var _snare_point := Vector3.ZERO
var _snare_time := 0.0
var _snare_sample := 0.0
var _dash_dir := Vector3.ZERO
var _dash_hit := {}
var _wick_pos := Vector3.ZERO
var _wick_origin := Vector3.ZERO
var _wick_end := Vector3.ZERO
var _wick_age := 0.0
var _wick_home := false
var _wick_mesh: MeshInstance3D
var _wick_hit := {}

func configure(traveler: CinderPlayer, battle: CinderBattle, core: SunCore) -> void:
	if is_instance_valid(_player) and _player.dash_segment.is_connected(_on_dash_segment):
		_player.dash_segment.disconnect(_on_dash_segment)
	_player = traveler
	_player.dash_segment.connect(_on_dash_segment)
	_battle = battle
	_core = core
	_available = true

func set_available(value: bool) -> void:
	_available = value
	if not value:
		cancel_buffer()

func _definition(site: StringName) -> SPEC:
	for spec in ARTS:
		if spec.site == site:
			return spec
	return null

func ability_name(site: StringName) -> String:
	var spec := _definition(site)
	return spec.title if spec else ""

func selected_id() -> StringName:
	return _selected.site if _selected else &""

func remaining_seconds() -> float:
	return float(_cooldowns.get(selected_id(), 0.0))

func cast_lock() -> float:
	return _cast_lock

func cooldowns() -> Dictionary:
	return _cooldowns.duplicate()

func achievements() -> Array[Dictionary]:
	return profile.rows()

func cancel_buffer() -> void:
	_queued_site = &""
	_buffer_left = 0.0

func unlock(site: StringName) -> bool:
	var spec := _definition(site)
	if not spec or _owned.has(site):
		return false
	_learn(spec)
	if profile_enabled and profile.record([spec]):
		achievement_unlocked.emit(spec.title)
	return true

func _learn(spec: SPEC) -> void:
	_owned.append(spec.site)
	_cooldowns[spec.site] = 0.0
	if _selected == null:
		_selected = spec

func restore(earned, equipped: StringName, remaining: Variant = {}, lock_seconds := 0.0) -> void:
	# Checkpoints carry mastery and recovery; in-flight attacks and protective wards end.
	cancel_buffer()
	_dash_hit.clear()
	_snare_time = 0.0
	_wick_mesh = null
	for effect in get_children():
		effect.queue_free()
	if is_instance_valid(_core):
		_core.protect(0.0,0.0)
	if is_instance_valid(_battle):
		for enemy in _battle.enemies:
			enemy.set_lensmark(0.0,0,0.0)
			enemy.reed_snare(1.0,0.0)
	_owned.clear()
	_cooldowns.clear()
	_selected = null
	var learned: Array[SPEC] = []
	for id in earned:
		var spec := _definition(StringName(id))
		if spec and not _owned.has(spec.site):
			_learn(spec)
			learned.append(spec)
			# Old saves had one recovery for every learned art, regardless of equipped art.
			var seconds: Variant = remaining.get(String(spec.site), 0.0) if remaining is Dictionary else remaining
			_cooldowns[spec.site] = _safe_timer(seconds, spec.cooldown)
	if profile_enabled and not learned.is_empty():
		profile.record(learned)
	if _owned.has(equipped):
		_selected = _definition(equipped)
	_cast_lock = _safe_timer(lock_seconds, CAST_RECOVERY) if _selected else 0.0

func _safe_timer(value: Variant, maximum: float) -> float:
	if (value is int or value is float) and is_finite(float(value)):
		return clampf(float(value), 0.0, maximum)
	return 0.0

func cycle() -> bool:
	if not _can_use() or _owned.size() < 2:
		return false
	cancel_buffer()
	var index := ARTS.find(_selected)
	for offset in range(1, ARTS.size()):
		var next := ARTS[(index + offset) % ARTS.size()]
		if _owned.has(next.site):
			_selected = next
			return true
	return false

func hud_state() -> Dictionary:
	var slots: Array[Dictionary] = []
	for spec in ARTS:
		var selected := _selected == spec
		slots.append({"id": spec.site, "name": spec.title, "key": "G" if selected else "",
			"selected": selected, "owned": _owned.has(spec.site), "description": spec.description,
			"cooldown": float(_cooldowns.get(spec.site, 0.0)), "cooldown_max": spec.cooldown, "icon": spec.icon})
	var state := {"ability_slots": slots, "ability_cast_lock": _cast_lock}
	if _selected:
		state.merge({"ability_name": _selected.title, "ability_id": _selected.site,
			"ability_cooldown": remaining_seconds(), "ability_description": _selected.description, "ability_count": _owned.size()})
	return state

func _can_use() -> bool:
	return _available and _selected != null and is_instance_valid(_player) and _player.move_enabled and is_instance_valid(_battle) and not _battle.halted and is_instance_valid(_core) and _core.health > 0.0 and not get_tree().paused

func cast(aim_direction: Vector3, ground := Vector3.INF) -> bool:
	if not _can_use() or remaining_seconds() > 0.0 or _player.is_dashing() or _player.is_staggered():
		return false
	if _player.visual.can_cast_art() and _cast_lock <= 0.0:
		cancel_buffer()
		return _cast_now(aim_direction, ground)
	if _player.visual.art_buffer_window() and _queued_site == &"":
		_queued_site = selected_id()
		_queued_aim = aim_direction
		_queued_ground = ground
		_buffer_left = SWORD_BUFFER
		return true
	return false

func _cast_now(aim_direction: Vector3, ground: Vector3) -> bool:
	var aim := aim_direction.slide(Vector3.UP).normalized()
	if aim.length_squared() < .001:
		aim = -_player.visual.global_basis.z.slide(Vector3.UP).normalized()
	var accepted := false
	match _selected.site:
		&"flooded_grove": accepted = _snare(aim, ground)
		&"broken_quarry": accepted = _fault(aim)
		&"fallen_relay": accepted = _spark(aim, ground)
		&"lanternwood": accepted = _ward()
		&"sunken_aqueduct": accepted = _dash(aim)
		&"sunwatch_observatory": accepted = _mark(aim, ground)
		&"last_lantern_frontier": accepted = _wick(aim)
	if accepted:
		_cooldowns[_selected.site] = _selected.cooldown
		_cast_lock = CAST_RECOVERY
		_player.visual.gesture(_selected.site)
		if _selected.site != &"lanternwood":
			var facing := _dash_dir if _selected == SLUICE else aim
			_player.visual.rotation.y = atan2(-facing.x, -facing.z)
		_battle.sound.emit(_cast_sound())
	return accepted

func _cast_sound() -> String:
	match _selected.site:
		&"flooded_grove", &"sunken_aqueduct": return "skimmer_wake"
		&"broken_quarry": return "slam"
		&"fallen_relay": return "attack"
		&"lanternwood": return "collect"
		&"sunwatch_observatory": return "blade_ready"
		_: return "spin"

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_battle) or _battle.halted:
		return
	_cast_lock = maxf(0.0, _cast_lock - delta)
	for id in _owned:
		_cooldowns[id] = maxf(0.0, float(_cooldowns[id]) - delta)
	if _queued_site != &"":
		if not _can_use() or _queued_site != selected_id() or _player.is_dashing() or _player.is_staggered():
			cancel_buffer()
		elif _player.visual.can_cast_art() and _cast_lock <= 0.0 and remaining_seconds() <= 0.0:
			cancel_buffer()
			_cast_now(_queued_aim, _queued_ground)
		else:
			_buffer_left -= delta
			if _buffer_left <= 0.0:
				cancel_buffer()
	if _snare_time > 0.0:
		_snare_time = maxf(0.0, _snare_time-delta)
		_snare_sample -= delta
		if _snare_sample <= 0.0:
			_snare_tick()
	if is_instance_valid(_wick_mesh):
		_wick_tick(delta)

func _hit_floor(at: Vector3, above := 1.4, below := 2.5) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * above, at - Vector3.UP * below, 1)
	return get_world_3d().direct_space_state.intersect_ray(ray)

func _visible_line(from: Vector3, to: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(from, to, 1)
	ray.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _source() -> Vector3:
	return _player.global_position + Vector3.UP * .98

func _target(aim: Vector3, ground: Vector3, reach: float) -> CinderEnemy:
	var best: CinderEnemy
	var best_score := INF
	for e in _battle.enemies:
		if not is_instance_valid(e) or e.fading:
			continue
		var offset := e.body_center() - _source()
		var distance := offset.length()
		var alignment := aim.dot(offset.slide(Vector3.UP).normalized())
		if distance > reach or alignment < .73:
			continue
		if not _visible_line(_source(),e.body_center()):
			continue
		var score := distance + (1.0 - alignment) * 25.0
		if ground.is_finite():
			score = e.global_position.distance_squared_to(ground)
		if score < best_score:
			best_score = score
			best = e
	return best

func _snare(aim: Vector3, ground: Vector3) -> bool:
	var base := _player.global_position
	var chosen := base + aim * _selected.reach
	if ground.is_finite():
		var toward := (ground-base).limit_length(_selected.reach)
		chosen = base + toward
	var floor_hit := _hit_floor(chosen,2.0,3.0)
	if floor_hit.is_empty() or floor_hit.normal.y < .58:
		return false
	_snare_point = floor_hit.position + Vector3.UP * .045
	if not _visible_line(_source(), _snare_point + Vector3.UP * .25):
		return false
	_snare_time = _selected.duration
	FX.glyph(self,_selected.site,_snare_point,_selected.radius,_selected.tint,_snare_time,reduced_motion)
	_snare_tick()
	return true

func _snare_tick() -> void:
	_snare_sample = .10
	var spec := REEDS
	for e in _battle.enemies:
		if absf(e.global_position.y-_snare_point.y) < 1.7 and CinderEnemy.flat_distance(_snare_point,e.global_position) <= spec.radius and _visible_line(_snare_point+Vector3.UP*.35,e.body_center()):
			e.reed_snare(spec.power,minf(.14,_snare_time))

func _fault(aim: Vector3) -> bool:
	var origin := _player.global_position
	var count := 0
	for e: CinderEnemy in _battle.enemies.duplicate():
		var offset := (e.global_position-origin).slide(Vector3.UP)
		if offset.length() > _selected.reach + e.stats.radius or (offset.length_squared() > .05 and offset.normalized().dot(aim) < cos(deg_to_rad(40.0))):
			continue
		if not _battle.blade_path_clear(origin,e):
			continue
		e.shove(aim * 8.0,_selected.duration)
		_battle.ability_hit(e,_selected.power)
		count += 1
	if count > 0:
		FX.glyph(self,_selected.site,origin + Vector3.UP * .07,_selected.reach,_selected.tint,_selected.duration,reduced_motion,aim)
	return count > 0

func _spark(aim: Vector3, ground: Vector3) -> bool:
	var enemy := _target(aim,ground,_selected.reach)
	if not enemy:
		return false
	var struck := {}
	var points := PackedVector3Array([_source()])
	var damage := _selected.power
	for jump in _selected.followup_damage.size() + 1:
		var end := enemy.body_center()
		points.append(end)
		struck[enemy.get_instance_id()] = true
		_battle.ability_hit(enemy, damage)
		if jump == _selected.followup_damage.size():
			break
		enemy = null
		damage = _selected.followup_damage[jump]
		var distance := _selected.radius * _selected.radius
		for next in _battle.enemies:
			if next.fading or struck.has(next.get_instance_id()):
				continue
			var d := next.body_center().distance_squared_to(end)
			if d <= distance and _visible_line(end,next.body_center()):
				enemy = next
				distance = d
		if enemy == null:
			break
	FX.chain(self,points,_selected.tint,_selected.duration,reduced_motion)
	return true

func _ward() -> bool:
	_core.protect(_selected.power,_selected.duration)
	var focus: Node3D = _core.get_node("Visual/SunCenter")
	FX.glyph(self,_selected.site,focus.global_position,.7,_selected.tint,_selected.duration,reduced_motion,Vector3.FORWARD,_core)
	return true

func _mark(aim: Vector3, ground: Vector3) -> bool:
	var enemy := _target(aim,ground,_selected.reach)
	if not enemy:
		return false
	enemy.set_lensmark(_selected.duration, _selected.charges, _selected.power)
	FX.glyph(self,_selected.site,enemy.body_center(),.3,_selected.tint,_selected.duration,reduced_motion,aim,enemy)
	return true

func _dash(aim: Vector3) -> bool:
	var input := Input.get_vector("move_left","move_right","move_forward","move_back")
	if _player.camera and input.length_squared() > .01:
		var right := _player.camera.global_basis.x.slide(Vector3.UP).normalized()
		var back := _player.camera.global_basis.z.slide(Vector3.UP).normalized()
		aim = (right*input.x + back*input.y).normalized()
	if not _player.begin_swept_dash(aim, _selected.reach, _selected.duration, &"sluice"):
		return false
	_dash_dir = aim
	_dash_hit.clear()
	FX.glyph(self,_selected.site,_player.global_position+Vector3.UP*.065,_selected.reach,_selected.tint,.35,reduced_motion,aim)
	return true

func _on_dash_segment(kind: StringName, from: Vector3, to: Vector3) -> void:
	if kind != &"sluice" or not _available or _battle.halted:
		return
	var spec := SLUICE
	for e in _battle.enemies:
		if _dash_hit.has(e.get_instance_id()) or not _battle.blade_path_clear(from,e):
			continue
		var d := _distance_to_segment(e.global_position,from,to)
		if d <= spec.radius + e.stats.radius:
			_dash_hit[e.get_instance_id()] = true
			var side := (e.global_position-from).slide(Vector3.UP)
			e.shove((_dash_dir + side.normalized()).normalized()*6.0,.45)

func _wick(aim: Vector3) -> bool:
	_wick_origin = _source()
	var goal := _wick_origin + aim * _selected.reach
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(_wick_origin,goal,1))
	_wick_end = hit.position - aim*.08 if not hit.is_empty() else goal
	if _wick_end.distance_to(_wick_origin) < .45:
		return false
	_wick_pos = _wick_origin
	_wick_age = 0.0
	_wick_home = false
	_wick_hit.clear()
	_wick_mesh = FX.glyph(self,_selected.site,_wick_origin,.7,_selected.tint,_selected.duration+.1,reduced_motion,aim)
	return true

func _wick_tick(delta: float) -> void:
	var spec := WICK
	var half := spec.duration*.5
	_wick_age += delta
	if not _wick_home:
		_wick_sweep(_wick_origin.lerp(_wick_end,minf(1.0,_wick_age/half)),spec)
		if _wick_age >= half:
			_wick_home = true
			_wick_hit.clear()
	if _wick_home:
		var goal := _wick_end.lerp(_source(),clampf((_wick_age-half)/half,0.0,1.0))
		if not _visible_line(_wick_pos,goal):
			_wick_mesh.queue_free()
			_wick_mesh = null
			return
		_wick_sweep(goal,spec)
	_wick_mesh.global_position = _wick_pos
	if _wick_age >= spec.duration:
		_wick_mesh.queue_free()
		_wick_mesh = null

func _wick_sweep(goal: Vector3, spec: SPEC) -> void:
	if _wick_pos.distance_squared_to(goal) < .000001:
		return
	for e: CinderEnemy in _battle.enemies.duplicate():
		if _wick_hit.has(e.get_instance_id()) or _distance_to_segment(e.body_center(),_wick_pos,goal) > spec.radius+e.stats.radius:
			continue
		if _visible_line(_wick_pos,e.body_center()):
			_wick_hit[e.get_instance_id()] = true
			e.shove(Vector3.ZERO,.16)
			_battle.ability_hit(e,spec.power)
	_wick_pos = goal

func _distance_to_segment(point: Vector3, from: Vector3, to: Vector3) -> float:
	if from.is_equal_approx(to):
		return point.distance_to(from)
	return point.distance_to(Geometry3D.get_closest_point_to_segment(point,from,to))
