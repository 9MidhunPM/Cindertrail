class_name CinderCampLandmarks
extends Node3D

const GROVE := &"flooded_grove"
const QUARRY := &"broken_quarry"
const RELAY := &"fallen_relay"
const LANTERNWOOD := &"lanternwood"
const AQUEDUCT := &"sunken_aqueduct"
const SUNWATCH := &"sunwatch_observatory"
const FRONTIER := &"last_lantern_frontier"
const FX := preload("res://scripts/fx/landmark_signal.gd")
const REACH := 2.65
const CRANE_FALL := 0.42
const WATCHFIRE_SECONDS := 4.5
const WATCHFIRE_RADIUS := 5.3
const WATCHFIRE_DAMAGE := 17.0
const GUIDES := {
	GROVE: { "title": "Ford bell",
		"detail": "Press E at the bell during a wave. For five seconds, arriving crawlers enter by Western shallows." },
	QUARRY: { "title": "Ore cradle",
		"detail": "Press E at the winch during a wave. The cradle drops after a short warning and crushes attackers under it." },
	RELAY: { "title": "Pylon console",
		"detail": "During a wave, stand at the console, point at an attack lane and press E to shock enemies from that lane." },
	LANTERNWOOD: { "title": "Lost lantern",
		"detail": "Relight the lantern with E while traveling. During a wave, press E at the lantern to stagger attackers nearby." },
	AQUEDUCT: { "title": "Sluice wheel",
		"detail": "Press E at the wheel during a wave. The surge pushes back enemies from Sluice crossing." },
	SUNWATCH: { "title": "Survey mirrors",
		"detail": "Align the first mirror, then the second with E while traveling. During a wave, press E at the second mirror to sweep Survey gallery." },
	FRONTIER: { "title": "Last watchfire",
		"detail": "Press E at the watchfire during a wave. For a few seconds, each enemy entering the ring around the core takes damage once." },
}

signal revealed_cache(position: Vector3)

var _grove: CinderGrove
var _quarry: CinderQuarry
var _relay: CinderRelay
var _outer: CinderOuterValley
var _positions: Dictionary[StringName, PackedVector3Array] = {}
var _kits: Dictionary[StringName, Node3D] = {}
var _used_wave: Dictionary[StringName, int] = {}
var _progress: Dictionary[StringName, int] = {}
var _prompt := Label3D.new()
var _watchfire_battle: CinderBattle
var _watchfire_site: CinderSite
var _watchfire_ring: MeshInstance3D
var _watchfire_time := 0.0
var _watchfire_burned: Dictionary[int, bool] = {}

func guide_for(site_id: StringName) -> Dictionary:
	var guide: Dictionary = GUIDES.get(site_id, {})
	return guide.duplicate()

func configure(grove: CinderGrove, quarry: CinderQuarry, relay: CinderRelay,
		outer: CinderOuterValley) -> void:
	_grove = grove
	_quarry = quarry
	_relay = relay
	_outer = outer
	_positions[GROVE] = PackedVector3Array([grove.world_landmark()])
	_positions[QUARRY] = PackedVector3Array([quarry.world_landmark()])
	_positions[RELAY] = PackedVector3Array([relay.world_landmark()])
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
	set_physics_process(false)

func set_roaming_sites(sites: Array[CinderSite]) -> void:
	_kits.clear()
	for site in sites:
		var kit := site.get_node_or_null("RoamingShrineKit") as Node3D
		if kit != null:
			_kits[site.checkpoint_id] = kit
			_positions[site.checkpoint_id] = kit.call(&"handle_positions")

func handle_positions_for(site: CinderSite) -> PackedVector3Array:
	if site.checkpoint_id == FRONTIER and not _positions.has(FRONTIER):
		# The legacy clearing already has a watchfire by the rear arch.
		return PackedVector3Array([site.habitat_frame * Vector3(4.6, 0, 4.8)])
	return _positions.get(site.checkpoint_id, PackedVector3Array())

func _activate_device(id: StringName, stage: int) -> void:
	if _kits.has(id):
		_kits[id].call(&"activate", stage)
		return
	match id:
		GROVE:
			_grove.ring_bell()
		QUARRY:
			_quarry.release_crane()
		RELAY:
			_relay.pulse_lane(stage)
		_:
			_outer.activate_landmark(id, stage)

func _mirror_cache_position() -> Vector3:
	return _kits[SUNWATCH].call(&"cache_position") if _kits.has(SUNWATCH) else _outer.observatory_cache_position()

func checkpoint_progress() -> Dictionary:
	return _progress.duplicate()

func restore_progress(state: Dictionary) -> void:
	_progress[LANTERNWOOD] = clampi(int(state.get(LANTERNWOOD, 0)), 0, 1)
	_progress[SUNWATCH] = clampi(int(state.get(SUNWATCH, 0)), 0, 2)
	for area in _progress:
		if _kits.has(area):
			_kits[area].call(&"show_progress", _progress[area])
		else:
			_outer.set_landmark_progress(area, _progress[area])
	if _progress[SUNWATCH] == 2:
		revealed_cache.emit(_mirror_cache_position())

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
			_activate_device(LANTERNWOOD, 0)
			return "The lost lantern is lit. Its flash can stagger attackers."
		SUNWATCH:
			var mirror := int(_progress.get(SUNWATCH, 0))
			_progress[SUNWATCH] = mirror + 1
			_activate_device(SUNWATCH, mirror)
			if mirror == 0:
				return "The first mirror points toward the second reflector."
			revealed_cache.emit(_mirror_cache_position())
			return "The mirrors reveal a supply recess and power the survey beam."
	return ""

func _in_reach(site: CinderSite, point: Vector3) -> bool:
	return site != null and (site.checkpoint_id == FRONTIER or _positions.has(site.checkpoint_id)) and (
		point.distance_to(handle_positions_for(site)[-1]) <= REACH)

func _can_fire(site: CinderSite, battle: CinderBattle) -> bool:
	return battle.site == site and battle.active_wave and not battle.held and (
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
	var handle := _positions[id][-1] if traveling else handle_positions_for(site)[-1]
	var action := ""
	if traveling:
		if id == LANTERNWOOD:
			action = "E   Relight lost lantern"
		else:
			var mirror := int(_progress.get(SUNWATCH, 0))
			action = "E   Align first mirror" if mirror == 0 else "E   Align second mirror"
			handle = _positions[id][mirror]
	elif _missing_discovery(id):
		action = "Relight the lost lantern while traveling" if id == LANTERNWOOD else "Align both mirrors while traveling"
	elif not battle.active_wave and not _used_wave.has(id):
		action = "Ready when the next wave begins"
	elif not _can_fire(site, battle):
		action = "Landmark recharges next wave"
	else:
		match id:
			GROVE: action = "E   Ring bell · " + site.lane_names[0]
			QUARRY: action = "E   Release ore cradle"
			RELAY: action = "E   Pulse " + site.lane_names[_aim_lane(site, aim)]
			LANTERNWOOD: action = "E   Flash the lantern"
			AQUEDUCT: action = "E   Open the sluice · " + site.lane_names[1]
			SUNWATCH: action = "E   Sweep " + site.lane_names[1]
			FRONTIER: action = "E   Stoke watchfire"
	_prompt.global_position = handle + Vector3.UP * 1.85
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
			_activate_device(id, 0)
			_trace_roaming_lane(site, 0, Color("#75eadc"), .36, 1.3, true)
			return "Arriving crawlers turn toward %s." % site.lane_names[0]
		QUARRY:
			_activate_device(id, 0)
			if _kits.has(QUARRY):
				FX.ring(self, _kits[QUARRY].call(&"impact_position") + Vector3.UP * .16,
					5.0, Color("#ef9a58"), CRANE_FALL)
			create_tween().tween_callback(_ore_impact.bind(site, battle)).set_delay(CRANE_FALL)
			return "The ore cradle falls across the choke."
		RELAY:
			var lane := _aim_lane(site, aim)
			_activate_device(id, lane)
			_trace_roaming_lane(site, lane, Color("#c0efff"), .24, .72, false)
			_hit_lane(site, battle, lane, 30.0)
			return "The pylons pulse down %s." % site.lane_names[lane]
		LANTERNWOOD:
			_activate_device(id, 1)
			if _kits.has(id):
				FX.ring(self, _positions[id][0] + Vector3.UP * .17,
					8.5, Color("#ffd18a"), .7, true)
			for enemy in battle.enemies:
				if _on_camp(enemy, site) and enemy.global_position.distance_to(_positions[id][0]) <= 8.5:
					enemy.disrupt(2.0)
			return "The lost lantern flashes."
		AQUEDUCT:
			_activate_device(id, 0)
			_trace_roaming_lane(site, 1, Color("#4fdfcd"), .85, 1.25, false)
			for enemy in battle.enemies:
				if _on_camp(enemy, site) and enemy.origin_lane == 1:
					enemy.disrupt(1.1, true)
			return "Water sweeps attackers back along %s." % site.lane_names[1]
		SUNWATCH:
			_activate_device(id, 2)
			_trace_roaming_lane(site, 1, Color("#ffdc87"), .48, 1.0, false)
			_hit_lane(site, battle, 1, 38.0)
			return "The survey beam sweeps %s." % site.lane_names[1]
		FRONTIER:
			_light_watchfire(site, battle)
			return "An ember ring scorches approaching attackers."
	return ""

func _trace_roaming_lane(site: CinderSite, lane: int, tint: Color, width: float,
		duration: float, inward: bool) -> void:
	if _kits.has(site.checkpoint_id):
		FX.trace_lane(self, site.lanes[lane], tint, width, duration, inward)

func _light_watchfire(site: CinderSite, battle: CinderBattle) -> void:
	_extinguish_watchfire()
	if _kits.has(FRONTIER):
		_activate_device(FRONTIER, 0)
	FX.ring(self, handle_positions_for(site)[0] + Vector3.UP * .2, 1.15, Color("#ffce8b"), .6, true)
	_watchfire_site = site
	_watchfire_battle = battle
	_watchfire_time = WATCHFIRE_SECONDS
	_watchfire_ring = FX.ring(self, site.anchor.global_position + Vector3.UP * .14,
		WATCHFIRE_RADIUS, Color("#ffd087"), WATCHFIRE_SECONDS)
	set_physics_process(true)

func _extinguish_watchfire() -> void:
	if is_instance_valid(_watchfire_ring):
		_watchfire_ring.queue_free()
	_watchfire_site = null
	_watchfire_battle = null
	_watchfire_burned.clear()
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_watchfire_battle) or not is_instance_valid(_watchfire_site):
		_extinguish_watchfire()
		return
	_watchfire_time -= delta
	var battle := _watchfire_battle
	var site := _watchfire_site
	if _watchfire_time <= 0.0 or battle.site != site or battle.held or not battle.active_wave:
		_extinguish_watchfire()
		return
	var center := site.anchor.global_position
	for enemy: CinderEnemy in battle.enemies.duplicate():
		var key := enemy.get_instance_id()
		if not _watchfire_burned.has(key) and _on_camp(enemy, site) and (
				CinderEnemy.flat_distance(enemy.global_position, center) < WATCHFIRE_RADIUS):
			_watchfire_burned[key] = true
			battle.landmark_hit(enemy, WATCHFIRE_DAMAGE)

func _on_camp(enemy: CinderEnemy, site: CinderSite) -> bool:
	return enemy.site_of_origin == site and not enemy.pursuing

func _hit_lane(site: CinderSite, battle: CinderBattle, lane: int, damage: float) -> void:
	for enemy: CinderEnemy in battle.enemies.duplicate():
		if _on_camp(enemy, site) and enemy.origin_lane == lane:
			battle.landmark_hit(enemy, damage)

func _ore_impact(site: CinderSite, battle: CinderBattle) -> void:
	var impact: Vector3 = _kits[QUARRY].call(&"impact_position") if _kits.has(QUARRY) else _quarry.world_impact()
	if _kits.has(QUARRY):
		FX.ring(self, impact + Vector3.UP * .17, 5.0, Color("#ffd398"), .68, true)
	for enemy: CinderEnemy in battle.enemies.duplicate():
		if _on_camp(enemy, site) and CinderEnemy.flat_distance(enemy.global_position, impact) < 5.0:
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
