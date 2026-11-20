class_name CinderCampLandmarks
extends Node3D

const GROVE := &"flooded_grove"
const QUARRY := &"broken_quarry"
const RELAY := &"fallen_relay"
const LANTERNWOOD := &"lanternwood"
const AQUEDUCT := &"sunken_aqueduct"
const SUNWATCH := &"sunwatch_observatory"
const REACH := 2.65
const CRANE_FALL := 0.42

signal revealed_cache(position: Vector3)

var _grove: CinderGrove
var _quarry: CinderQuarry
var _relay: CinderRelay
var _outer: CinderOuterValley
var _positions: Dictionary[StringName, PackedVector3Array] = {}
var _used_wave: Dictionary[StringName, int] = {}
var _progress: Dictionary[StringName, int] = {}
var _prompt := Label3D.new()

func configure(grove: CinderGrove, quarry: CinderQuarry, relay: CinderRelay,
		outer: CinderOuterValley) -> void:
	_grove = grove
	_quarry = quarry
	_relay = relay
	_outer = outer
	_positions[GROVE] = PackedVector3Array([CinderGrove.BELL_POSITION])
	_positions[QUARRY] = PackedVector3Array([quarry.landmark_position])
	_positions[RELAY] = PackedVector3Array([relay.landmark_position])
	for area in [LANTERNWOOD, AQUEDUCT, SUNWATCH]:
		_positions[area] = outer.landmark_positions(area)
	_prompt.font_size = 34
	_prompt.pixel_size = 0.005
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.modulate = Color("#ffe4ad")
	_prompt.outline_modulate = Color("#172332")
	_prompt.outline_size = 8
	_prompt.visibility_range_end = 36.0
	_prompt.hide()
	add_child(_prompt)

func checkpoint_progress() -> Dictionary:
	return _progress.duplicate()

func restore_progress(state: Dictionary) -> void:
	_progress[LANTERNWOOD] = clampi(int(state.get(LANTERNWOOD, 0)), 0, 1)
	_progress[SUNWATCH] = clampi(int(state.get(SUNWATCH, 0)), 0, 2)
	for area in _progress:
		_outer.set_landmark_progress(area, _progress[area])
	if _progress[SUNWATCH] == 2:
		revealed_cache.emit(_outer.observatory_cache_position())

func _discovery_at(point: Vector3) -> StringName:
	var mirror := int(_progress.get(SUNWATCH, 0))
	if mirror < 2 and point.distance_to(_positions[SUNWATCH][mirror]) <= REACH:
		return SUNWATCH
	if not _progress.has(LANTERNWOOD) or _progress[LANTERNWOOD] == 0:
		if point.distance_to(_positions[LANTERNWOOD][0]) <= REACH:
			return LANTERNWOOD
	return &""

func discover(point: Vector3) -> String:
	match _discovery_at(point):
		LANTERNWOOD:
			_progress[LANTERNWOOD] = 1
			_outer.activate_landmark(LANTERNWOOD, 0)
			return "The lost lantern is lit. Its flash can stagger attackers."
		SUNWATCH:
			var mirror := int(_progress.get(SUNWATCH, 0))
			_progress[SUNWATCH] = mirror + 1
			_outer.activate_landmark(SUNWATCH, mirror)
			if mirror == 0:
				return "The first mirror points toward the eastern reflector."
			revealed_cache.emit(_outer.observatory_cache_position())
			return "The mirrors reveal a supply recess and power the survey beam."
	return ""

func _in_reach(site: CinderSite, point: Vector3) -> bool:
	return site != null and _positions.has(site.checkpoint_id) and (
		point.distance_to(_positions[site.checkpoint_id][-1]) <= REACH)

func _can_fire(site: CinderSite, battle: CinderBattle) -> bool:
	return battle.active_wave and not battle.held and (
		_used_wave.get(site.checkpoint_id, -1) != site.threat)

func _missing_discovery(id: StringName) -> bool:
	return (id == LANTERNWOOD and _progress.get(id, 0) < 1) or (
		id == SUNWATCH and _progress.get(id, 0) < 2)

func hint(point: Vector3, aim: Vector3, site: CinderSite,
		battle: CinderBattle, traveling: bool) -> String:
	_prompt.hide()
	var id := site.checkpoint_id if _in_reach(site, point) else &""
	if traveling:
		id = _discovery_at(point)
	if id == &"":
		return ""
	var handle := _positions[id][-1]
	var action := ""
	if traveling:
		if id == LANTERNWOOD:
			action = "E   Relight lost lantern"
		else:
			var mirror := int(_progress.get(SUNWATCH, 0))
			action = "E   Align west mirror" if mirror == 0 else "E   Align east mirror"
			handle = _positions[id][mirror]
	elif _missing_discovery(id):
		action = "Relight the lost lantern while traveling" if id == LANTERNWOOD else "Align both mirrors while traveling"
	elif not _can_fire(site, battle):
		action = "Landmark recharges next wave"
	else:
		match id:
			GROVE: action = "E   Ring bell · Western shallows"
			QUARRY: action = "E   Release ore cradle"
			RELAY: action = "E   Pulse " + site.lane_names[_aim_lane(site, aim)]
			LANTERNWOOD: action = "E   Flash the lantern"
			AQUEDUCT: action = "E   Open the sluice"
			SUNWATCH: action = "E   Sweep the survey beam"
	_prompt.position = handle + Vector3.UP * 1.85
	_prompt.text = action
	_prompt.show()
	return action

func hide_prompt() -> void:
	_prompt.hide()

func defend(site: CinderSite, point: Vector3, aim: Vector3, battle: CinderBattle) -> String:
	if not _in_reach(site, point):
		return ""
	var id := site.checkpoint_id
	if _missing_discovery(id):
		return "Prepare this landmark while traveling."
	if not _can_fire(site, battle):
		return "The landmark recharges each wave."
	_used_wave[id] = site.threat
	match id:
		GROVE:
			battle.bias_next_spawns(0, 5.0)
			_grove.ring_bell()
			return "Crawlers turn toward the western shallows."
		QUARRY:
			_quarry.release_crane()
			create_tween().tween_callback(_ore_impact.bind(site, battle)).set_delay(CRANE_FALL)
			return "The ore cradle falls across the choke."
		RELAY:
			var lane := _aim_lane(site, aim)
			_relay.pulse_lane(lane)
			_hit_lane(site, battle, lane, 30.0)
			return "The pylons pulse down %s." % site.lane_names[lane]
		LANTERNWOOD:
			_outer.activate_landmark(id, 1)
			for enemy in battle.enemies:
				if _on_camp(enemy, site) and enemy.global_position.distance_to(_positions[id][0]) <= 8.5:
					enemy.disrupt(2.0)
			return "The lost lantern flashes."
		AQUEDUCT:
			_outer.activate_landmark(id, 0)
			for enemy in battle.enemies:
				if _on_camp(enemy, site) and enemy.origin_lane == 1:
					enemy.disrupt(1.1, true)
			return "Water surges down Sluice crossing."
		SUNWATCH:
			_outer.activate_landmark(id, 2)
			_hit_lane(site, battle, 1, 38.0)
			return "The beam sweeps the Survey gallery."
	return ""

func _on_camp(enemy: CinderEnemy, site: CinderSite) -> bool:
	return enemy.site_of_origin == site and not enemy.pursuing

func _hit_lane(site: CinderSite, battle: CinderBattle, lane: int, damage: float) -> void:
	for enemy: CinderEnemy in battle.enemies.duplicate():
		if _on_camp(enemy, site) and enemy.origin_lane == lane:
			battle.landmark_hit(enemy, damage)

func _ore_impact(site: CinderSite, battle: CinderBattle) -> void:
	for enemy: CinderEnemy in battle.enemies.duplicate():
		if _on_camp(enemy, site) and CinderEnemy.flat_distance(enemy.global_position, _quarry.impact_position) < 5.0:
			battle.landmark_hit(enemy, 52.0)

func _aim_lane(site: CinderSite, aim: Vector3) -> int:
	if aim == Vector3.INF:
		return 0
	var nearest := INF
	var index := 0
	for i in site.lanes.size():
		var route := site.lanes[i]
		for j in range(route.size() - 1):
			var closest := Geometry3D.get_closest_point_to_segment(aim, route[j], route[j + 1])
			var distance := aim.distance_squared_to(closest)
			if distance < nearest:
				nearest = distance
				index = i
	return index
