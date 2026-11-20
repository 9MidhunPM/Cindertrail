extends Node3D

enum Mode { EXPLORE, DEPLOY, PREPARE, DEFEND, PACK, TRANSIT, WIN, LOSE }

const GROVE := preload("res://data/sites/grove.tres")
const TRAVELER := preload("res://scenes/player/traveler_visual.tscn")
const SHRINE := preload("res://scenes/core/sun_core.tscn")
const INTERFACE := preload("res://scenes/ui/hud.tscn")
const FRONT_END := preload("res://scenes/ui/front_end.tscn")
const QUARRY_REGION := preload("res://scripts/world/quarry.gd")
const RELAY_REGION := preload("res://scripts/world/relay.gd")
const OUTER_VALLEY := preload("res://scenes/world/outer_valley.tscn")
const FRONTIER := preload("res://scripts/world/frontier.gd")
const CACHE_MODEL := preload("res://art/models/supply_crate.glb")
const PACK_SECONDS := 1.7
const OPENING := Vector3(-3.0, 0.76, 15.0)
const LEGACY_JOURNEY_SEED := 34519
const MIRROR_CACHE_ID := "sunwatch_mirror_recess"

var mode := Mode.EXPLORE
var player: CinderPlayer
var director: CinderCamera
var camera: Camera3D:
	get:
		return director.camera
var core: SunCore
var atmosphere: CinderAtmosphere
var soundscape: CinderSoundscape
var battle: CinderBattle
var melee: CinderMelee
var hud: CinderHUD
var grove: CinderSite
var grove_terrain: CinderGrove
var outer_valley: CinderOuterValley
var frontier: CinderFrontier
var landmarks: CinderCampLandmarks
var sites: Array[CinderSite] = []
var active_site: CinderSite
var beacon: Marker3D
var _caches: Array[Node3D] = []
var _selected := -1
var _hovered := -1
var _pack_elapsed := 0.0
var _pack_source := Mode.PREPARE
var _transferring := false
var _paused := false
var _notice := ""
var _notice_time := 0.0
var _hud_clock := 0.0
var _capture_mouse := true
var _front_end: CinderFrontEnd
var _checkpoint: Dictionary = {}
var _claimed_caches := PackedStringArray()
var _quiet_travel := 0.0
var _checkpoint_timer := 0.0
var _checkpoint_enabled := true
var _front_active := false
var _settings_open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_mouse = DisplayServer.get_name() != "headless" and not OS.has_feature("movie")
	atmosphere = CinderAtmosphere.new()
	_add_runtime(atmosphere)
	grove_terrain = CinderGrove.new()
	_add_runtime(grove_terrain)
	_build_sites()
	player = CinderPlayer.new()
	player.name = "Traveler"
	player.position = OPENING
	player.recovery_point = OPENING
	_add_runtime(player)
	var traveler := TRAVELER.instantiate() as TravelerVisual
	player.add_child(traveler)
	player.visual = traveler
	director = CinderCamera.new()
	_add_runtime(director)
	director.player = player
	player.camera = director.camera
	director.reset_pose()
	core = SHRINE.instantiate() as SunCore
	_add_runtime(core)
	core.transfer(traveler.carry_anchor, SunCore.Form.CARRIED)
	core.destroyed.connect(_lose)
	soundscape = CinderSoundscape.new()
	_add_runtime(soundscape)
	traveler.footfall.connect(soundscape.footfall)
	battle = CinderBattle.new()
	_add_runtime(battle)
	battle.bind_carried_core(core)
	battle.message.connect(_notify)
	battle.sound.connect(_battle_sound)
	melee = CinderMelee.new()
	_add_runtime(melee)
	melee.bind(player, battle, director)
	melee.swung.connect(_melee_sound)
	hud = INTERFACE.instantiate() as CinderHUD
	add_child(hud)
	hud.action_requested.connect(_hud_action)
	_add_cache(Vector3(-6.1, 0.72, 9.0), 16)
	_checkpoint_enabled = not _direct_launch()
	if not _checkpoint_enabled:
		_open_frontier(int(get_tree().get_meta(&"journey_seed", LEGACY_JOURNEY_SEED)))
	else:
		_checkpoint = JourneyCheckpoint.read()
		_front_end = FRONT_END.instantiate() as CinderFrontEnd
		add_child(_front_end)
		_front_end.begin_journey.connect(_begin_journey)
		_front_end.continue_journey.connect(_continue_journey)
		_front_end.quit_requested.connect(get_tree().quit)
		_front_end.settings_closed.connect(_close_settings)
		_front_end.preferences_changed.connect(_apply_preferences)
		_apply_preferences()
		var entry: StringName = get_tree().get_meta(&"journey_entry", &"title")
		get_tree().remove_meta(&"journey_entry")
		if entry == &"continue":
			_continue_journey()
		else:
			_front_active = true
			hud.hide()
			player.set_physics_process(false)
			if entry == &"new":
				_front_end.show_menu(not _checkpoint.is_empty())
				_front_end.request_new_journey()
			else:
				_front_end.show_menu(not _checkpoint.is_empty())
	_sync_controls()
	_render_hud()

func _direct_launch() -> bool:
	return OS.get_cmdline_user_args().has("--direct") or bool(get_tree().get_meta(&"direct_journey", false))

func _apply_preferences() -> void:
	director.mouse_sensitivity = _front_end.mouse_sensitivity
	director.reduced_motion = _front_end.reduced_motion

func _enter_journey() -> void:
	_front_active = false
	_front_end.hide_all()
	player.set_physics_process(true)
	hud.show()
	director.reset_pose()
	_sync_controls()
	_render_hud()

func _begin_journey() -> void:
	if JourneyCheckpoint.write({}):
		_checkpoint.clear()
	else:
		_notify("The new journey could not replace the last checkpoint")
	_open_frontier(randi())
	_enter_journey()

func _continue_journey() -> void:
	_open_frontier(int(_checkpoint.get("journey_seed", LEGACY_JOURNEY_SEED)))
	if not _checkpoint.is_empty():
		_restore_checkpoint()
	_enter_journey()

func _reload_for(entry: StringName) -> void:
	get_tree().paused = false
	get_tree().set_meta(&"journey_entry", entry)
	get_tree().reload_current_scene()

func _hud_action(action: StringName) -> void:
	match action:
		&"resume":
			_set_paused(false)
		&"settings":
			if _front_end != null:
				_settings_open = true
				_render_hud()
				_front_end.show_settings(true)
		&"title":
			_save_checkpoint()
			_reload_for(&"title")
		&"checkpoint":
			_reload_for(&"continue")
		&"restart":
			restart()

func _close_settings() -> void:
	_settings_open = false
	_render_hud()

func _set_paused(value: bool) -> void:
	if value:
		_save_checkpoint()
	_paused = value
	get_tree().paused = value
	_sync_controls()
	_render_hud()

func _add_runtime(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(node)

func _build_sites() -> void:
	grove = CinderSite.new()
	grove.name = "FloodedGroveSite"
	grove.wet = true
	var center := Vector3(0, 0.73, 0)
	grove.configure(GROVE, center,
		PackedVector3Array([Vector3(-3.45, 0.75, -1.5), Vector3(2.6, 0.75, -3.05),
			Vector3(3.6, 0.75, 1.4), Vector3(-2, 0.75, 3.45)]),
		[PackedVector3Array([Vector3(-13, 0, -9), Vector3(-10, 0, -4), Vector3(-7, 0, -2),
			Vector3(-4, 0.66, 0), center]),
		PackedVector3Array([Vector3(14, 0, -9), Vector3(11, 0, -4), Vector3(7, 0, 1),
			Vector3(4, 0.66, 0), center])], Vector3(10, 12.3, 19.7), Vector3(0, 0.42, -1))
	_add_runtime(grove)
	sites.append(grove)
	var quarry := QUARRY_REGION.new()
	var relay := RELAY_REGION.new()
	_add_runtime(quarry)
	_add_runtime(relay)
	sites.append(quarry.site)
	sites.append(relay.site)
	beacon = relay.beacon
	for point in quarry.caches + relay.caches:
		_add_cache(point, 20)
	_waymark("Broken Quarry", Vector3(-4.1, 0.71, 2.25), Vector3.LEFT)
	_waymark("Fallen Relay", Vector3(1.38, 0.71, -4.28), Vector3.FORWARD)
	_waymark("Hilltop Beacon", Vector3(15.4, 4.80, -56.3), Vector3(1, 0, -1))
	outer_valley = OUTER_VALLEY.instantiate() as CinderOuterValley
	_add_runtime(outer_valley)
	sites.append_array(outer_valley.get_sites())
	for index in outer_valley.caches.size():
		_add_cache(outer_valley.caches[index], 14, outer_valley.cache_ids[index])
	_waymark("Pilgrims’ Cross", Vector3(-2.5, 0.72, 19.3), Vector3.BACK)
	landmarks = CinderCampLandmarks.new()
	_add_runtime(landmarks)
	landmarks.revealed_cache.connect(_reveal_mirror_cache)
	landmarks.configure(grove_terrain, quarry, relay, outer_valley)

func _open_frontier(journey_seed: int) -> void:
	if frontier != null:
		return
	frontier = FRONTIER.new()
	frontier.journey_seed = journey_seed
	_add_runtime(frontier)
	sites.append(frontier.site)
	outer_valley.seed_life(journey_seed)

func _reveal_mirror_cache(point: Vector3) -> void:
	if not _claimed_caches.has(MIRROR_CACHE_ID):
		_add_cache(point, 14, MIRROR_CACHE_ID)

func _waymark(label: String, point: Vector3, direction: Vector3) -> void:
	var marker := CinderWaymark.new()
	marker.position = point
	marker.set_destination(label, direction)
	_add_runtime(marker)

func _physics_process(delta: float) -> void:
	if _paused or _front_active:
		return
	if mode == Mode.WIN or mode == Mode.LOSE:
		_update_hud_clock(delta)
		return
	_notice_time = maxf(0.0, _notice_time - delta)
	if mode == Mode.DEPLOY and director.settled():
		mode = Mode.PREPARE
		_sync_controls()
	if mode == Mode.PACK:
		if _transferring and director.settled():
			_transferring = false
			active_site = null
			mode = Mode.TRANSIT
			_sync_controls()
		elif not _transferring and not Input.is_action_pressed("pack"):
			_cancel_pack()
	elif mode == Mode.TRANSIT and player.get_slide_collision_count() > 0 and player.is_on_floor():
		player.recovery_point = player.global_position
	if _can_pack() and Input.is_action_pressed("pack"):
		pack_step(delta)
	if battle != null and active_site != null and not _transferring:
		if (mode == Mode.DEFEND or (mode == Mode.PACK and _pack_source == Mode.DEFEND)) and battle.active_wave:
			_extract(delta)
	if mode == Mode.PREPARE or mode == Mode.DEFEND:
		_update_socket()
	_update_checkpoint(delta)
	_update_hud_clock(delta)

func _battle_sound(cue: String) -> void:
	if cue == "hit":
		if core.form == SunCore.Form.CARRIED:
			player.visual.gesture(&"hurt")
		soundscape.cue("hurt")
	else:
		soundscape.cue(cue)

func _update_hud_clock(delta: float) -> void:
	_hud_clock += delta
	if _hud_clock >= 0.05:
		_hud_clock = 0
		_render_hud()

func _unhandled_input(event: InputEvent) -> void:
	if _front_active or _settings_open:
		return
	if event.is_action_pressed("toggle_hud") and hud != null:
		hud.visible = not hud.visible
		return
	if event.is_action_pressed("cancel"):
		if _selected != -1 and not _paused:
			_selected = -1
		elif mode != Mode.LOSE and mode != Mode.WIN:
			_set_paused(not _paused)
		return
	if _direct_launch() and event.is_action_pressed("restart") and (mode == Mode.WIN or mode == Mode.LOSE or _paused):
		restart()
		return
	if _paused or mode == Mode.WIN or mode == Mode.LOSE:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		director.orbit(event.relative)
	if event.is_action_pressed("interact"):
		interact()
	if event.is_action_pressed("start_wave"):
		start_wave()
	if mode == Mode.PREPARE or mode == Mode.DEFEND:
		if event.is_action_pressed("module_bolt"):
			_selected = 0 if _selected != 0 else -1
		if event.is_action_pressed("module_slow"):
			_selected = 1 if _selected != 1 else -1
		if event.is_action_pressed("module_mortar"):
			_selected = 2 if _selected != 2 else -1
		if event.is_action_pressed("upgrade") and battle != null:
			battle.upgrade(_hovered)
	if event.is_action_pressed("melee"):
		swing(get_viewport().get_mouse_position())
	if event is InputEventMouseButton and event.pressed:
		_handle_click(event)

func _handle_click(event: InputEventMouseButton) -> void:
	if battle == null or mode == Mode.DEPLOY or mode == Mode.PACK:
		return
	var tactical := mode == Mode.PREPARE or mode == Mode.DEFEND
	if tactical and event.button_index == MOUSE_BUTTON_LEFT and _selected != -1:
		_update_socket(event.position)
		if battle.place(_hovered, _selected):
			_selected = -1
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		swing(event.position)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		var origin := player.global_position + Vector3.UP * 1.13
		var direction := -camera.global_basis.z
		if tactical:
			var pointed := _pointer_ground(event.position)
			if pointed != Vector3.INF:
				direction = origin.direction_to(pointed + Vector3.UP * 0.41)
		else:
			direction.y = clampf(direction.y, -0.12, 0.18)
		if battle.attack(origin, direction.normalized()):
			player.visual.gesture(&"fire")

## Swing the sunsteel blade toward the camera's facing, or toward the pointer in defense.
func swing(pointer: Vector2) -> bool:
	if melee == null or not player.move_enabled:
		return false
	var direction := -camera.global_basis.z
	if mode == Mode.PREPARE or mode == Mode.DEFEND:
		var pointed := _pointer_ground(pointer)
		if pointed != Vector3.INF:
			direction = pointed - player.global_position
	return melee.request(direction)

func _melee_sound(index: int, hits: int) -> void:
	soundscape.cue("slam" if index == 2 else "slash")
	if hits > 0:
		soundscape.cue("impact")

func _pointer_ground(pointer: Vector2) -> Vector3:
	var start := camera.project_ray_origin(pointer)
	var end := start + camera.project_ray_normal(pointer) * 95.0
	var query := PhysicsRayQueryParameters3D.create(start, end, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("position", Vector3.INF)

func _update_socket(pointer := Vector2.INF) -> void:
	_hovered = -1
	if active_site != null and battle != null:
		var cursor := get_viewport().get_mouse_position() if pointer == Vector2.INF else pointer
		var pointed := _pointer_ground(cursor)
		if pointed != Vector3.INF:
			_hovered = battle.socket_at(pointed)
		active_site.select_socket(_hovered)

func interact() -> void:
	if mode == Mode.EXPLORE or mode == Mode.TRANSIT:
		if _near(beacon, 2.6) and core.restoration >= 99.999:
			_win()
			return
		var cache := _near_cache()
		if cache != null and battle != null:
			var amount: int = cache.get_meta("scrap")
			battle.scrap += amount
			_claimed_caches.append(cache.get_meta(&"checkpoint_id"))
			player.visual.gesture(&"collect")
			soundscape.cue("collect")
			_notify("Recovered %d scrap" % amount)
			_caches.erase(cache)
			cache.queue_free()
			return
		var discovery := landmarks.discover(player.global_position)
		if not discovery.is_empty():
			soundscape.cue("collect")
			_notify(discovery)
			return
		var site := _near_site()
		if site != null:
			_deploy(site)
		elif _interact_frontier():
			return
		elif outer_valley.try_open_shortcut(player.global_position):
			soundscape.cue("collect")
			_notify("Shortcut opened")
	elif mode == Mode.PREPARE or mode == Mode.DEFEND:
		var action := landmarks.defend(active_site, player.global_position, _landmark_aim(), battle) if mode == Mode.DEFEND else ""
		if not action.is_empty():
			_notify(action)
		elif _near(active_site.anchor, 5.5):
			battle.repair()

func _landmark_aim() -> Vector3:
	if active_site != null and active_site.checkpoint_id == CinderCampLandmarks.RELAY:
		return _pointer_ground(get_viewport().get_mouse_position())
	return Vector3.INF

func _interact_frontier() -> bool:
	if frontier == null:
		return false
	var result := frontier.interact_at(player.global_position)
	if result.is_empty():
		return false
	battle.scrap += int(result.get("scrap", 0))
	player.visual.gesture(&"collect")
	soundscape.cue("collect")
	_notify(String(result.get("message", "")))
	return true

func _deploy(site: CinderSite) -> void:
	active_site = site
	mode = Mode.DEPLOY
	player.visual.gesture(&"deploy")
	core.transfer(site.anchor, SunCore.Form.DEPLOYED, 0.91)
	director.show_site(site.view_position, site.view_target)
	if site == grove:
		grove_terrain.release_herons()
	player.recovery_point = site.anchor.global_position + Vector3(0, 0.1, 2)
	if battle != null:
		battle.prepare(site, core)
	_sync_controls()
	soundscape.cue("deploy")

func start_wave() -> bool:
	if mode != Mode.PREPARE or battle == null:
		return false
	if active_site.remaining_energy <= 0.001 or core.restoration >= 99.999:
		_notify("Pack the shrine and continue your journey")
		return false
	if not battle.begin():
		return false
	mode = Mode.DEFEND
	return true

func _extract(delta: float) -> void:
	var draw := minf(minf(active_site.remaining_energy, active_site.spec.rate * delta), 100.0 - core.restoration)
	active_site.remaining_energy -= draw
	if active_site.remaining_energy <= 0.001:
		draw += active_site.remaining_energy
		active_site.remaining_energy = 0.0
	core.restoration += draw
	if core.restoration >= 99.999:
		core.restoration = 100.0
	if core.restoration >= 99.999 or active_site.remaining_energy <= 0.001:
		battle.hold()
		mode = Mode.PREPARE if mode != Mode.PACK else Mode.PACK
		_pack_source = Mode.PREPARE
		_notify("Carry the restored sun to the hilltop beacon" if core.restoration >= 99.999 else "This site's reserve is depleted")

func _can_pack() -> bool:
	if _transferring:
		return false
	if mode == Mode.PACK:
		return true
	return (mode == Mode.PREPARE or mode == Mode.DEFEND) and _near(active_site.anchor, 6.2)

func pack_step(delta: float) -> void:
	if not _can_pack():
		return
	if mode != Mode.PACK:
		_pack_source = mode
		mode = Mode.PACK
		_selected = -1
		_pack_elapsed = 0.0
		player.visual.gesture(&"pack")
		if battle != null:
			battle.hold()
		_sync_controls()
	_pack_elapsed += delta
	if _pack_elapsed < PACK_SECONDS:
		return
	_transferring = true
	if battle != null:
		battle.recall()
	active_site.select_socket(-1)
	core.transfer(player.visual.carry_anchor, SunCore.Form.CARRIED, 0.93)
	director.tactical = false
	soundscape.cue("pack")

func _cancel_pack() -> void:
	mode = _pack_source
	_pack_elapsed = 0.0
	if battle != null and active_site.remaining_energy > 0.001 and core.restoration < 99.999:
		battle.resume()
	_sync_controls()

func _sync_controls() -> void:
	var traveling := mode == Mode.EXPLORE or mode == Mode.TRANSIT
	player.move_enabled = not _front_active and not _paused and (traveling or mode == Mode.PREPARE or mode == Mode.DEFEND)
	player.tactical = not traveling
	if _capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if traveling and not _paused and not _front_active else Input.MOUSE_MODE_VISIBLE

func _near(node: Node3D, radius: float) -> bool:
	return node != null and player.global_position.distance_to(node.global_position) <= radius

func _near_site() -> CinderSite:
	for site in sites:
		if _near(site.anchor, 2.55):
			return site
	return null

func _near_cache() -> Node3D:
	for cache in _caches:
		if _near(cache, 2.3):
			return cache
	return null

func _add_cache(point: Vector3, amount: int, identifier := "") -> void:
	var cache := CACHE_MODEL.instantiate() as Node3D
	cache.position = point
	cache.set_meta("scrap", amount)
	cache.set_meta(&"checkpoint_id", identifier if not identifier.is_empty() else
		"cache_%d_%d_%d" % [roundi(point.x * 10), roundi(point.y * 10), roundi(point.z * 10)])
	_add_runtime(cache)
	_caches.append(cache)

func _win() -> void:
	mode = Mode.WIN
	if battle != null:
		battle.stop()
	if _checkpoint_enabled and JourneyCheckpoint.write({}):
		_checkpoint.clear()
	player.visual.gesture(&"deliver")
	core.transfer(beacon, SunCore.Form.DELIVERED, 1.25)
	director.show_ending(beacon.global_position + Vector3(5.5, 2.55, 6.2),
		beacon.global_position + Vector3(-0.35, 1.2, 0.26))
	atmosphere.sunrise = true
	var facing := lerp_angle(player.visual.rotation.y, 0.0, 1.0)
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(player.visual, "rotation:y", facing, 0.8)
	_sync_controls()
	soundscape.cue("win")

func _lose() -> void:
	if mode == Mode.WIN or mode == Mode.LOSE:
		return
	mode = Mode.LOSE
	_selected = -1
	if battle != null:
		battle.stop()
	_sync_controls()
	player.visual.gesture(&"hurt")
	soundscape.cue("hurt")

func restart() -> void:
	_reload_for(&"new")

func _safe_checkpoint() -> bool:
	return (_checkpoint_enabled and not _front_active and not _transferring
		and (mode == Mode.EXPLORE or mode == Mode.TRANSIT) and core.form == SunCore.Form.CARRIED
		and battle.enemies.is_empty() and player.is_on_floor()
		and not grove.wet_depth_at(player.global_position))

func _update_checkpoint(delta: float) -> void:
	if not _safe_checkpoint():
		_quiet_travel = 0.0
		return
	_quiet_travel += delta
	_checkpoint_timer += delta
	if _quiet_travel < 1.5 or (_checkpoint_timer < 7.0 and not _checkpoint.is_empty()):
		return
	_save_checkpoint()

func _save_checkpoint() -> void:
	if not _safe_checkpoint() or _quiet_travel < 1.5:
		return
	_checkpoint_timer = 0.0
	var records := {}
	for site in sites:
		records[site.checkpoint_id] = {"reserve": site.remaining_energy, "threat": site.threat}
	var state := {
		"position": player.global_position, "yaw": director.yaw, "pitch": director.pitch,
		"facing": player.visual.rotation.y, "health": core.health, "restoration": core.restoration,
		"scrap": battle.scrap, "inventory": battle.inventory.duplicate(true),
		"sites": records, "claimed": _claimed_caches,
		"shortcuts": outer_valley.unlocked_shortcut_ids(),
		"landmarks": landmarks.checkpoint_progress(),
		"journey_seed": frontier.journey_seed, "frontier_version": CinderFrontier.LAYOUT_VERSION,
		"frontier_discoveries": frontier.claimed_discoveries(),
		"frontier_revealed": frontier.revealed_discoveries(),
	}
	if state != _checkpoint and JourneyCheckpoint.write(state):
		_checkpoint = state

func _restore_checkpoint() -> void:
	player.global_position = _checkpoint.get("position", OPENING) + Vector3.UP * 0.04
	player.recovery_point = player.global_position
	player.reset_physics_interpolation()
	director.yaw = _checkpoint.get("yaw", director.yaw)
	director.pitch = _checkpoint.get("pitch", director.pitch)
	player.visual.rotation.y = _checkpoint.get("facing", 0.0)
	core.health = clampf(_checkpoint.get("health", 100.0), 0.01, 100.0)
	core.restoration = clampf(_checkpoint.get("restoration", 0.0), 0.0, 100.0)
	battle.scrap = maxi(0, _checkpoint.get("scrap", battle.scrap))
	battle.inventory.assign(_checkpoint.get("inventory", []))
	for module in battle.inventory:
		module.socket = -1
	var records: Dictionary = _checkpoint.get("sites", {})
	for site in sites:
		var record: Dictionary = records.get(site.checkpoint_id, {})
		site.remaining_energy = clampf(record.get("reserve", site.spec.energy), 0.0, site.spec.energy)
		site.threat = maxi(0, record.get("threat", 0))
	_claimed_caches = _checkpoint.get("claimed", PackedStringArray())
	outer_valley.restore_shortcuts(_checkpoint.get("shortcuts", PackedStringArray()))
	var saved_frontier := int(_checkpoint.get("frontier_version", CinderFrontier.LAYOUT_VERSION))
	if saved_frontier == CinderFrontier.LAYOUT_VERSION:
		frontier.restore_discoveries(_checkpoint.get("frontier_discoveries", PackedStringArray()),
			_checkpoint.get("frontier_revealed", PackedStringArray()))
	elif player.global_position.z > CinderFrontier.ENTRANCE.z:
		player.global_position = CinderFrontier.ENTRANCE + Vector3.UP * 0.10
		player.recovery_point = player.global_position
		player.reset_physics_interpolation()
	landmarks.restore_progress(_checkpoint.get("landmarks", {}))
	for index in range(_caches.size() - 1, -1, -1):
		if _claimed_caches.has(_caches[index].get_meta(&"checkpoint_id")):
			var cache := _caches.pop_at(index) as Node3D
			cache.queue_free()
	if core.restoration > 0.0:
		mode = Mode.TRANSIT
	_notify("Journey resumed")

func _notify(message: String) -> void:
	_notice = message
	_notice_time = 4.0

func _hint(nearest: CinderSite) -> String:
	landmarks.hide_prompt()
	if mode == Mode.EXPLORE or mode == Mode.TRANSIT:
		if _near(beacon, 2.6):
			if core.restoration >= 99.999:
				return "E   Deliver the sun"
			return "Restore the sun before lighting the beacon"
		if _near_cache() != null:
			return "E   Recover supplies"
		var discovery := landmarks.hint(player.global_position, Vector3.INF, null, battle, true)
		if not discovery.is_empty():
			return discovery
		if nearest != null:
			return "E   Unfold shrine at %s" % nearest.label
		if frontier != null:
			var expedition := frontier.hint_at(player.global_position)
			if not expedition.is_empty():
				return expedition
		var shortcut := outer_valley.nearby_shortcut(player.global_position)
		if not shortcut.is_empty():
			return "E   Open " + shortcut
		if core.restoration >= 99.999:
			return "Follow the ridge beyond Fallen Relay to the beacon"
		return "Follow the stone causeway to the shrine pad" if _near(grove.anchor, 22.0) and mode == Mode.EXPLORE else "Follow the trail markers to another ancient site"
	if mode == Mode.DEPLOY:
		return "Unfolding shrine"
	if mode == Mode.PACK:
		return "Folding shrine" if _transferring else "Hold R   Keep folding"
	if mode == Mode.PREPARE:
		if active_site.remaining_energy <= 0.001 or core.restoration >= 99.999:
			return "Hold R   Pack the shrine"
		return "Space   Start wave     •     E   Repair"
	if mode == Mode.DEFEND:
		return landmarks.hint(player.global_position, _landmark_aim(), active_site, battle, false)
	return ""

func _render_hud() -> void:
	if hud == null:
		return
	var local_site := active_site if active_site != null else _near_site()
	hud.render({
		"health": core.health, "restoration": core.restoration,
		"scrap": battle.scrap if battle != null else 0,
		"mode": str(Mode.keys()[mode]).capitalize(),
		"site": local_site.label if local_site != null else "",
		"energy": local_site.remaining_energy if local_site != null else 0.0,
		"site_energy_max": local_site.spec.energy if local_site != null else 0.0,
		"threat": local_site.threat if local_site != null else 0,
		"forecast": battle.forecast() if battle != null and active_site != null else "",
		"hint": _hint(local_site), "status": _notice if _notice_time > 0.0 else "",
		"selected": _selected, "socket": _hovered,
		"pack_progress": clampf(_pack_elapsed / PACK_SECONDS, 0.0, 1.0),
		"modules": battle.module_labels() if battle != null else PackedStringArray(),
		"paused": _paused,
		"settings_open": _settings_open, "checkpoint_available": not _checkpoint.is_empty(),
		"checkpoint_hint": "The last safe trail checkpoint will be used." if not _safe_checkpoint() and not _checkpoint.is_empty() else "",
	})
