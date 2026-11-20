extends Node3D
## The crown has no reserve. Its encounter is deliberately started at full sun
## and shares target selection, damage, weapons and the active budget with camps.
const BOSS := preload("res://scripts/combat/vesper_colossus.gd")
const SPEC := preload("res://data/enemies/vesper.tres")
const SITE := preload("res://data/sites/beacon.tres")
const CRAWLER := preload("res://data/enemies/crawler.tres")
signal cleared_crown
signal sighted(text: String)
var site := CinderSite.new()
var guardian: BOSS
var cleared := false
var halfway_seen := false
var _battle: CinderBattle
var _escort_released := false
var _apparition: Node3D
var _sighting_time := 0.0
var _opening_seen := false
var _escort: CinderEnemyStats

func build(beacon: Marker3D) -> void:
	var crown := beacon.global_position
	var pad := crown + Vector3(0, -.04, -3.45)
	var sockets := PackedVector3Array([crown + Vector3(-3.9,-.05,-6.05),
		crown + Vector3(3.65,-.05,-6.1), crown + Vector3(4.1,-.05,-2.15)])
	var west := PackedVector3Array([crown + Vector3(-6.45,-.07,-4.25),
		crown + Vector3(-3.5,-.07,-3.55), pad])
	var stair := PackedVector3Array([crown + Vector3(.0,-.07,2.8),
		crown + Vector3(-1.15,-.04,.75), crown + Vector3(-1.2,-.04,-2.0), pad])
	var east := PackedVector3Array([crown + Vector3(6.3,-.07,-4.4),
		crown + Vector3(3.4,-.07,-3.85), pad])
	add_child(site)
	site.name = "BeaconCrown"
	site.configure(SITE, pad, sockets, [west, stair, east], crown + Vector3(6.1,11.6,-16.0), crown + Vector3(0,.50,-2.15))
	site.hide()
	_escort = CRAWLER.duplicate()
	_escort.bounty = 0

func begin(battle: CinderBattle) -> bool:
	if cleared or is_instance_valid(guardian) or battle.enemies.size() >= CinderBattle.WAVES.active_limit:
		return false
	_battle = battle
	_guard_sighting_end()
	var lane := site.lanes[0].duplicate()
	lane[-1] += Vector3(-1.55, 0.0, -.35)
	guardian = BOSS.new()
	battle.add_child(guardian)
	guardian.cue_requested.connect(battle.sound.emit)
	guardian.configure(SPEC, lane, site)
	if not battle.register_enemy(guardian):
		guardian.queue_free()
		guardian = null
		return false
	guardian.fell.connect(_fell)
	site.threat = 1
	_escort_released = false
	return true

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(guardian) or guardian.fading or _battle.held or _escort_released:
		return
	if guardian.health <= guardian.stats.health * .55:
		_escort_released = true
		site.threat = 2
		_battle.message.emit("The carapace fractures. Shadows are climbing the dawn stair.")
		_battle.spawn_enemy(_escort, site.lanes[1], site, 1)
		_battle.spawn_enemy(_escort, site.lanes[0], site, 0)

func _fell() -> void:
	cleared = true
	guardian = null
	# A mortar splash or sword sweep can still be traversing battle.enemies.
	_clear_escorts.call_deferred()
	cleared_crown.emit()

func retreat() -> void:
	if is_instance_valid(guardian):
		_battle.enemies.erase(guardian)
		guardian.withdraw()
		guardian = null
	_clear_escorts()
	site.hide()
	site.threat = 0

func _clear_escorts() -> void:
	if _battle == null:
		return
	for enemy: CinderEnemy in _battle.enemies.duplicate():
		if enemy.site_of_origin == site:
			_battle.enemies.erase(enemy)
			enemy.withdraw()

func health_percent() -> float:
	if is_instance_valid(guardian):
		return maxf(0.0, 100.0 * guardian.health / guardian.stats.health)
	return 0.0 if cleared else 100.0

func phase_name() -> String:
	if is_instance_valid(guardian):
		return guardian.phase_name()
	return "Crown secured" if cleared else "Awaiting challenge"

func hint() -> String:
	if cleared:
		return "E   Deliver the restored sun at the beacon"
	if is_instance_valid(guardian):
		return "%s   •   Vesper %d%%" % [guardian.phase_name(), ceili(100.0 * guardian.health / guardian.stats.health)]
	return "Space   Challenge the guardian    •    E   Repair    •    Hold R   Leave"

func watch(restoration: float, player_point: Vector3, camp: CinderSite, camera: Camera3D, delta: float) -> void:
	if cleared or is_instance_valid(guardian):
		return
	if _sighting_time > 0.0:
		_sighting_time -= delta
		if is_instance_valid(_apparition):
			_apparition.rotation.y += delta * .095
			if _sighting_time < 1.5:
				_apparition.position.y -= delta * 1.4
		if _sighting_time <= 0:
			_guard_sighting_end()
	if not _opening_seen and restoration < 1.0 and player_point.z < 13.0 and player_point.z > 3.0:
		_opening_seen = true
		_show_sighting(Vector3(-5.6, 3.12, -18.0), player_point)
	elif not halfway_seen and restoration >= 50.0 and restoration < 100.0 and camp != null:
		halfway_seen = true
		var anchor := camp.anchor.global_position
		var back := (anchor - camera.global_position).slide(Vector3.UP).normalized()
		var ledge := anchor + back * 17.0 + back.cross(Vector3.UP) * 6.0
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
			ledge + Vector3.UP * 22, ledge - Vector3.UP * 17, 1))
		if not hit.is_empty():
			ledge.y = hit.position.y
		_show_sighting(ledge, anchor)
		sighted.emit("The Vesper Colossus turns toward the hilltop beacon.")

func _show_sighting(point: Vector3, look: Vector3) -> void:
	_guard_sighting_end()
	_apparition = SPEC.model.instantiate()
	add_child(_apparition)
	_apparition.global_position = point
	_apparition.rotation.y = atan2(look.x - point.x, look.z - point.z)
	_sighting_time = 6.0

func _guard_sighting_end() -> void:
	if is_instance_valid(_apparition):
		_apparition.queue_free()
		_apparition = null
	_sighting_time = 0.0
