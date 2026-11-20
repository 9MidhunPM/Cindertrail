extends Node3D
## The traveler keeps every recovered art. All seven draw on one shared recovery time.
const SPEC := preload("res://scripts/game/traveler_art_spec.gd")
const FX := preload("res://scripts/fx/traveler_art_effect.gd")
const REEDS := preload("res://data/abilities/flooded_grove.tres")
const SLUICE := preload("res://data/abilities/sunken_aqueduct.tres")
const WICK := preload("res://data/abilities/last_lantern_frontier.tres")
const ARTS: Array[SPEC] = [
	REEDS, preload("res://data/abilities/broken_quarry.tres"),
	preload("res://data/abilities/fallen_relay.tres"), preload("res://data/abilities/lanternwood.tres"),
	SLUICE, preload("res://data/abilities/sunwatch.tres"), WICK,
]
var reduced_motion := false
var _owned: Array[StringName] = []
var _selected: SPEC
var _cooldown := 0.0
var _available := false
var _player: CinderPlayer
var _battle: CinderBattle
var _core: SunCore
var _snare_point := Vector3.ZERO
var _snare_time := 0.0
var _snare_sample := 0.0
var _dash_dir := Vector3.ZERO
var _dash_time := 0.0
var _dash_hit := {}
var _wick_pos := Vector3.ZERO
var _wick_origin := Vector3.ZERO
var _wick_end := Vector3.ZERO
var _wick_age := 0.0
var _wick_home := false
var _wick_mesh: MeshInstance3D
var _wick_hit := {}

func configure(traveler: CinderPlayer, battle: CinderBattle, core: SunCore) -> void:
	_player = traveler
	_battle = battle
	_core = core
	_available = true

func set_available(value: bool) -> void:
	_available = value
	if not value:
		_dash_time = 0.0

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
	return _cooldown

func unlock(site: StringName) -> bool:
	var spec := _definition(site)
	if not spec or _owned.has(site):
		return false
	_owned.append(site)
	if _selected == null:
		_selected = spec
	return true

func restore(earned, equipped: StringName, remaining: float) -> void:
	# Checkpoints carry mastery and recovery; in-flight attacks and protective wards end.
	_dash_time = 0.0
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
	_selected = null
	for id in earned:
		unlock(StringName(id))
	if _owned.has(equipped):
		_selected = _definition(equipped)
	_cooldown = clampf(remaining, 0.0, 18.0) if _selected else 0.0

func cycle() -> bool:
	if not _can_use() or _owned.size() < 2:
		return false
	var index := (_owned.find(_selected.site) + 1) % _owned.size()
	_selected = _definition(_owned[index])
	return true

func hud_state() -> Dictionary:
	if not _selected:
		return {}
	return {"ability_name": _selected.title, "ability_id": _selected.site,
		"ability_cooldown": _cooldown, "ability_description": _selected.description, "ability_count": _owned.size()}

func _can_use() -> bool:
	return _available and _selected != null and is_instance_valid(_player) and _player.move_enabled and is_instance_valid(_battle) and not _battle.halted and is_instance_valid(_core) and _core.health > 0.0 and not get_tree().paused

func cast(aim_direction: Vector3, ground := Vector3.INF) -> bool:
	if not _can_use() or _cooldown > 0.0 or not _player.visual.can_cast_art():
		return false
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
		_cooldown = _selected.cooldown
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
	_cooldown = maxf(0.0, _cooldown-delta)
	if _snare_time > 0.0:
		_snare_time = maxf(0.0, _snare_time-delta)
		_snare_sample -= delta
		if _snare_sample <= 0.0:
			_snare_tick()
	if _dash_time > 0.0:
		_dash_tick(delta)
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
		if offset.length() > _selected.reach + e.stats.radius or (offset.length_squared() > .05 and offset.normalized().dot(aim) < cos(.59)):
			continue
		if not _battle.blade_path_clear(origin,e):
			continue
		e.shove(aim * 8.0,.48)
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
	for strength: float in [1.0,.7,.4]:
		var end := enemy.body_center()
		points.append(end)
		struck[enemy.get_instance_id()] = true
		_battle.ability_hit(enemy,_selected.power*strength)
		enemy = null
		var distance := _selected.radius * _selected.radius
		for next in _battle.enemies:
			var d := next.body_center().distance_squared_to(end)
			if d < distance and not struck.has(next.get_instance_id()) and _visible_line(end,next.body_center()):
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
	enemy.set_lensmark(_selected.duration,3,_selected.power)
	FX.glyph(self,_selected.site,enemy.body_center(),.3,_selected.tint,_selected.duration,reduced_motion,aim,enemy)
	return true

func _dash(aim: Vector3) -> bool:
	var input := Input.get_vector("move_left","move_right","move_forward","move_back")
	if _player.camera and input.length_squared() > .01:
		var right := _player.camera.global_basis.x.slide(Vector3.UP).normalized()
		var back := _player.camera.global_basis.z.slide(Vector3.UP).normalized()
		aim = (right*input.x + back*input.y).normalized()
	if _safe_step(aim*.28) == Vector3.ZERO:
		return false
	_dash_dir = aim
	_dash_time = _selected.duration
	_dash_hit.clear()
	FX.glyph(self,_selected.site,_player.global_position+Vector3.UP*.065,_selected.reach,_selected.tint,.35,reduced_motion,aim)
	return true

func _safe_step(step: Vector3) -> Vector3:
	var floor_hit := _hit_floor(_player.global_position + step,.5,.65)
	if floor_hit.is_empty() or floor_hit.normal.y < cos(_player.floor_max_angle):
		return Vector3.ZERO
	var rise: float = floor_hit.position.y - _player.global_position.y
	if absf(rise) > .36:
		return Vector3.ZERO
	# Keep a tiny clearance so a sweep parallel to a flat floor cannot catch the floor.
	var motion := step + Vector3.UP * maxf(0.0, rise + .005)
	return Vector3.ZERO if _player.test_move(_player.global_transform,motion) else motion

func _dash_tick(delta: float) -> void:
	if _player.visual.attacking():
		_dash_time = 0.0
		return
	var spec := SLUICE
	var portion := minf(delta,_dash_time)
	_dash_time -= portion
	var motion := _safe_step(_dash_dir * spec.reach * portion / spec.duration)
	if motion == Vector3.ZERO:
		_dash_time = 0.0
		return
	var from := _player.global_position
	_player.move_and_collide(motion)
	for e in _battle.enemies:
		if _dash_hit.has(e.get_instance_id()) or not _battle.blade_path_clear(from,e):
			continue
		var d := _distance_to_segment(e.global_position,from,_player.global_position)
		if d <= spec.radius + e.stats.radius:
			_dash_hit[e.get_instance_id()] = true
			var side := (e.global_position-from).slide(Vector3.UP)
			e.shove((_dash_dir + side.normalized()).normalized()*6.0,.36)

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
