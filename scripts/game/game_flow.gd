extends Node3D

enum Mode { EXPLORE, DEPLOY, PREPARE, DEFEND, PACK, TRANSIT, WIN, LOSE }

const SUMMIT := preload("res://scripts/world/beacon_guardian.gd")
const JOURNEY_LAYOUT := preload("res://scripts/world/journey_layout.gd")
const TRAVELER := preload("res://scenes/player/traveler_visual.tscn")
const SHRINE := preload("res://scenes/core/sun_core.tscn")
const INTERFACE := preload("res://scenes/ui/hud.tscn")
const FRONT_END := preload("res://scenes/ui/front_end.tscn")
const FINALE := preload("res://scenes/ui/beacon_finale.tscn")
const ARTS := preload("res://scripts/game/traveler_arts.gd")
const RAID_GLOW := preload("res://scripts/game/traveler_raid_glow.gd")
const OBJECTIVE_ROUTE := preload("res://scripts/world/objective_route.gd")
const QUARRY_REGION := preload("res://scripts/world/quarry.gd")
const RELAY_REGION := preload("res://scripts/world/relay.gd")
const OUTER_VALLEY := preload("res://scenes/world/outer_valley.tscn")
const FRONTIER := preload("res://scripts/world/frontier.gd")
const TRAIL_PACKS := preload("res://scripts/world/trail_encounters.gd")
const BELL_ROAD := preload("res://scripts/world/drowned_bell_road.gd")
const CACHE_MODEL := preload("res://art/models/supply_crate.glb")
const PACK_SECONDS := 1.7
const OPENING := Vector3(-3.0, 0.76, 15.0)
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
var arts: ARTS
var raid_glow: RAID_GLOW
var objective_route: OBJECTIVE_ROUTE
var hud: CinderHUD
var finale
var grove: CinderSite
var grove_terrain: CinderGrove
var bell_road: BELL_ROAD
var outer_valley: CinderOuterValley
var frontier: CinderFrontier
var trail_packs: TRAIL_PACKS
var landmarks: CinderCampLandmarks
var layout: JOURNEY_LAYOUT
var districts: Array[Node3D] = []
var sites: Array[CinderSite] = []
var active_site: CinderSite
var beacon: Marker3D
var summit: SUMMIT
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
var _map_open := false
var _journey_seconds := 0.0
var _defeated := 0
var _left_site: CinderSite
var _first_ability_award := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_mouse = DisplayServer.get_name() != "headless" and not OS.has_feature("movie")
	atmosphere = CinderAtmosphere.new()
	_add_runtime(atmosphere)
	player = CinderPlayer.new()
	player.name = "Traveler"
	player.position = OPENING
	player.recovery_point = OPENING
	_add_runtime(player)
	var traveler := TRAVELER.instantiate() as TravelerVisual
	player.add_child(traveler)
	player.visual = traveler
	raid_glow = RAID_GLOW.new()
	_add_runtime(raid_glow)
	raid_glow.configure(traveler)
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
	melee.sword_cue.connect(soundscape.cue)
	arts = ARTS.new()
	_add_runtime(arts)
	arts.configure(player, battle, core)
	arts.achievement_unlocked.connect(func(_title: String) -> void: _first_ability_award = true)
	player.recovered.connect(_traveler_recovered)
	hud = INTERFACE.instantiate() as CinderHUD
	add_child(hud)
	hud.action_requested.connect(_hud_action)
	_checkpoint_enabled = not _direct_launch()
	arts.profile_enabled = _checkpoint_enabled
	if not _checkpoint_enabled:
		var seed_value := int(get_tree().get_meta(&"journey_seed", JOURNEY_LAYOUT.LEGACY_SEED))
		var layout_version := int(get_tree().get_meta(&"world_layout_version", 0))
		if layout_version >= 1 and layout_version <= JOURNEY_LAYOUT.VERSION:
			_build_journey(JOURNEY_LAYOUT.generate(seed_value, layout_version))
		else:
			_build_journey(JOURNEY_LAYOUT.restore({"journey_seed": seed_value}))
	else:
		_checkpoint = JourneyCheckpoint.read()
		if not _checkpoint.is_empty() and JOURNEY_LAYOUT.restore(_checkpoint) == null:
			push_warning("The saved journey uses an unrecognized valley layout.")
			_checkpoint = {}
		_front_end = FRONT_END.instantiate() as CinderFrontEnd
		add_child(_front_end)
		_front_end.achievement_rows = arts.achievements
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
			# The title overlooks a real Grove. The rest of the valley belongs to the
			# selected journey and is assembled only after New or Continue.
			grove_terrain = CinderGrove.new()
			_add_runtime(grove_terrain)
			_front_active = true
			hud.hide()
			player.set_physics_process(false)
			if entry == &"new":
				_front_end.show_menu(not _checkpoint.is_empty())
				_front_end.request_new_journey()
			else:
				_front_end.show_menu(not _checkpoint.is_empty())
	battle.damaged.connect(_count_defeat)
	_sync_controls()
	_render_hud()

func _count_defeat(_point: Vector3, _amount: float, _source: StringName, fatal: bool) -> void:
	if fatal:
		_defeated += 1

func _traveler_recovered(_previous: Vector3, _safe: Vector3) -> void:
	melee.cancel()
	arts.cancel_buffer()
	if mode == Mode.EXPLORE or mode == Mode.TRANSIT:
		director.reset_pose()

func _direct_launch() -> bool:
	return OS.get_cmdline_user_args().has("--direct") or bool(get_tree().get_meta(&"direct_journey", false))

func _apply_preferences() -> void:
	director.mouse_sensitivity = _front_end.mouse_sensitivity
	director.reduced_motion = _front_end.reduced_motion
	arts.reduced_motion = director.reduced_motion
	raid_glow.set_raid(mode == Mode.DEFEND, director.reduced_motion)

func _enter_journey() -> void:
	_front_active = false
	_front_end.hide_all()
	player.set_physics_process(true)
	hud.show()
	director.reset_pose()
	_sync_controls()
	_render_hud()

func _begin_journey() -> void:
	var previous: Dictionary = get_tree().get_meta(&"last_valley", {}) if _checkpoint.is_empty() else _checkpoint
	var next := JOURNEY_LAYOUT.generate(randi())
	while next.matches_selection(previous):
		next = JOURNEY_LAYOUT.generate(randi())
	if JourneyCheckpoint.write({}):
		_checkpoint.clear()
	else:
		_notify("The new journey could not replace the last checkpoint")
	_build_journey(next)
	_enter_journey()

func _continue_journey() -> void:
	_build_journey(JOURNEY_LAYOUT.restore(_checkpoint))
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
		&"achievements":
			if _front_end != null:
				_settings_open = true
				_render_hud()
				_front_end.show_achievements(true)
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
		arts.cancel_buffer()
	_paused = value
	get_tree().paused = value
	_sync_controls()
	_render_hud()

func _add_runtime(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(node)

func _build_journey(selected: JOURNEY_LAYOUT) -> void:
	layout = selected
	get_tree().set_meta(&"last_valley", layout.checkpoint_fields())
	if grove_terrain != null:
		grove_terrain.free()
	grove_terrain = CinderGrove.new()
	grove_terrain.randomized_layout = layout.version > 0
	grove_terrain.clearing_variant = layout.clearing(&"flooded_grove")
	_add_runtime(grove_terrain)
	grove = grove_terrain.build_grove_site()
	_add_runtime(grove)
	sites.append(grove)
	bell_road = BELL_ROAD.new()
	bell_road.name = "DrownedBellRoad"
	grove_terrain.add_child(bell_road)
	bell_road.configure(layout.journey_seed, bell_road.to_local(grove.anchor.global_position))
	bell_road.toll_requested.connect(soundscape.toll_bell)
	bell_road.raised.connect(grove_terrain.release_herons)
	var quarry := QUARRY_REGION.new()
	var relay := RELAY_REGION.new()
	quarry.layout_id = layout.layout_id
	quarry.randomized_layout = layout.version > 0
	quarry.clearing_variant = layout.clearing(&"broken_quarry")
	relay.layout_id = layout.layout_id
	relay.randomized_layout = layout.version > 0
	relay.clearing_variant = layout.clearing(&"fallen_relay")
	districts.assign([grove_terrain, quarry, relay])
	_add_runtime(quarry)
	_add_runtime(relay)
	sites.append(quarry.site)
	sites.append(relay.site)
	beacon = relay.beacon
	summit = SUMMIT.new()
	_add_runtime(summit)
	summit.build(beacon)
	summit.cleared_crown.connect(_guardian_fell)
	summit.sighted.connect(_guardian_sighting)
	_add_cache(Vector3(-6.1, 0.72, 9.0), 16, "grove_approach" if layout.version else "")
	_add_district_caches("quarry", quarry.caches)
	_add_district_caches("relay", relay.caches)
	var grove_paths := grove_terrain.map_paths()
	var destinations := ["Pilgrims’ Cross", "Broken Quarry", "Fallen Relay"]
	for index in grove_paths.size():
		var trail := grove_paths[index]
		var exit := trail[-2]
		var direction := exit.direction_to(trail[-3])
		_waymark(destinations[index], exit + direction.cross(Vector3.UP) * 1.12, direction)
	_waymark("Hilltop Beacon", relay.to_global(Vector3(15.4, 4.80, -56.3)), Vector3(1, 0, -1))
	outer_valley = OUTER_VALLEY.instantiate() as CinderOuterValley
	outer_valley.journey_layout = layout
	outer_valley.layout_id = layout.layout_id
	outer_valley.clearing_variants = layout.clearings
	_add_runtime(outer_valley)
	sites.append_array(outer_valley.get_sites())
	for index in outer_valley.caches.size():
		_add_cache(outer_valley.caches[index], 14, outer_valley.cache_ids[index])
	landmarks = CinderCampLandmarks.new()
	_add_runtime(landmarks)
	landmarks.revealed_cache.connect(_reveal_mirror_cache)
	landmarks.configure(grove_terrain, quarry, relay, outer_valley)

	frontier = FRONTIER.new()
	frontier.journey_seed = layout.journey_seed
	frontier.randomized_layout = layout.version > 0
	frontier.clearing_variant = layout.clearing(&"last_lantern_frontier")
	_add_runtime(frontier)
	sites.append(frontier.site)
	outer_valley.seed_life(layout.journey_seed)
	trail_packs = TRAIL_PACKS.new()
	_add_runtime(trail_packs)
	trail_packs.configure(layout.journey_seed, outer_valley, frontier, battle)
	_configure_recovery()
	objective_route = OBJECTIVE_ROUTE.new()
	_add_runtime(objective_route)
	objective_route.bind(self)
	hud.bind(self)

func _configure_recovery() -> void:
	var anchors := PackedVector3Array([OPENING, beacon.global_position + Vector3.BACK * 1.6])
	for site in sites:
		anchors.append(site.anchor.global_position)
	for district in districts:
		for path: PackedVector3Array in district.map_paths():
			anchors.append_array(path)
	for point: Vector3 in outer_valley.junctions.values():
		anchors.append(point)
	for path in frontier.paths:
		anchors.append_array(path)
	player.footing_filter = func(at: Vector3) -> bool: return not grove.wet_depth_at(at)
	player.configure_recovery(OPENING, anchors)

func _add_district_caches(district: String, points: PackedVector3Array) -> void:
	for index in points.size():
		var stable_id := "%s_supply_%d" % [district, index]
		_add_cache(points[index], 20, stable_id if layout.version else "")

func _reveal_mirror_cache(point: Vector3) -> void:
	if not _claimed_caches.has(MIRROR_CACHE_ID):
		_add_cache(point, 14, MIRROR_CACHE_ID)

func _waymark(label: String, point: Vector3, direction: Vector3) -> void:
	var marker := CinderWaymark.new()
	marker.position = point
	marker.set_destination(label, direction)
	_add_runtime(marker)

func _physics_process(delta: float) -> void:
	if _paused or _front_active or _map_open:
		return
	if mode == Mode.WIN or mode == Mode.LOSE:
		_update_hud_clock(delta)
		return
	if trail_packs != null:
		trail_packs.observe(delta, player.global_position, mode == Mode.EXPLORE or mode == Mode.TRANSIT)
	if mode == Mode.EXPLORE or mode == Mode.TRANSIT:
		bell_road.listen(player.global_position)
	summit.watch(core.restoration, player.global_position, active_site, camera, delta)
	_notice_time = maxf(0.0, _notice_time - delta)
	_journey_seconds += delta
	if mode == Mode.DEPLOY and director.settled():
		mode = Mode.PREPARE
		_sync_controls()
	if mode == Mode.PACK:
		if _transferring and director.settled():
			_transferring = false
			_left_site = active_site
			active_site = null
			mode = Mode.TRANSIT
			player.set_recovery_context()
			_sync_controls()
		elif not _transferring and not Input.is_action_pressed("pack"):
			_cancel_pack()
	if _can_pack() and Input.is_action_pressed("pack"):
		pack_step(delta)
	if battle != null and active_site != null and active_site != summit.site and not _transferring:
		var holding_shrine := mode == Mode.DEFEND or (mode == Mode.PACK and _pack_source == Mode.DEFEND)
		# An immediate pack can hold a new wave before its first attacker arrives.
		if holding_shrine and battle.active_wave and battle.remaining_spawns < battle.total_in_wave:
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

## Catch releases even when the pointer has crossed onto the HUD since pressing.
func _input(event: InputEvent) -> void:
	if melee == null or not player.move_enabled or _map_open:
		return
	if event.is_action_released("melee"):
		melee.release(&"keyboard", _sword_direction(get_viewport().get_mouse_position()))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		melee.release(&"mouse", _sword_direction(event.position))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(melee):
		melee.cancel()
		arts.cancel_buffer()

func _unhandled_input(event: InputEvent) -> void:
	if _front_active or _settings_open or finale != null:
		return
	if event.is_action_pressed("map") and not _paused and mode != Mode.WIN and mode != Mode.LOSE:
		_map_open = not _map_open
		if _map_open:
			melee.cancel()
			arts.cancel_buffer()
		get_tree().paused = _map_open
		_sync_controls()
		_render_hud()
		return
	if _map_open and event.is_action_pressed("cancel"):
		_map_open = false
		get_tree().paused = false
		_sync_controls()
		_render_hud()
		return
	if event.is_action_pressed("toggle_hud") and hud != null:
		hud.toggle_gameplay_hud()
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
	if _paused or _map_open or mode == Mode.WIN or mode == Mode.LOSE:
		return
	if event.is_action_pressed("cycle_ability"):
		arts.cycle()
		return
	if event.is_action_pressed("cast_ability"):
		var cursor := get_viewport().get_mouse_position()
		var tactical := mode == Mode.PREPARE or mode == Mode.DEFEND
		if arts.cast(_sword_direction(cursor), _pointer_ground(cursor) if tactical else Vector3.INF):
			raid_glow.accent()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		director.orbit(event.relative)
	if event.is_action_pressed("interact"):
		interact()
	if event.is_action_pressed("start_wave"):
		start_wave()
	if mode == Mode.PREPARE or mode == Mode.DEFEND:
		var previous_selection := _selected
		if event.is_action_pressed("module_bolt"):
			_selected = 0 if _selected != 0 else -1
		if event.is_action_pressed("module_slow"):
			_selected = 1 if _selected != 1 else -1
		if event.is_action_pressed("module_mortar"):
			_selected = 2 if _selected != 2 else -1
		if _selected >= 0 and _selected != previous_selection:
			melee.cancel()
		if event.is_action_pressed("upgrade") and battle != null:
			battle.upgrade(_hovered)
	if event.is_action_pressed("melee"):
		swing(get_viewport().get_mouse_position(), &"keyboard")
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
		swing(event.position, &"mouse")
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if player.is_dashing() or player.is_staggered():
			return
		var origin := player.global_position + Vector3.UP * 1.13
		var direction := -camera.global_basis.z
		if tactical:
			var pointed := _pointer_ground(event.position)
			if pointed != Vector3.INF:
				direction = origin.direction_to(pointed + Vector3.UP * 0.41)
		else:
			direction.y = clampf(direction.y, -0.12, 0.18)
		if not tactical and trail_packs != null and battle.weapon_timer <= 0.0:
			trail_packs.provoke_by_aim(origin, direction.normalized())
		if battle.attack(origin, direction.normalized()):
			player.visual.gesture(&"fire")
			raid_glow.accent()

## Without a nearby target, exploration swings use the camera and defense uses the pointer.
func swing(pointer: Vector2, source: StringName = &"") -> bool:
	if melee == null or not player.move_enabled or _map_open or player.is_dashing() or player.is_staggered():
		return false
	var direction := _sword_direction(pointer)
	return melee.request(direction) if source.is_empty() else melee.press(direction, source)

func _sword_direction(pointer: Vector2) -> Vector3:
	var direction := -camera.global_basis.z
	if mode == Mode.PREPARE or mode == Mode.DEFEND:
		var pointed := _pointer_ground(pointer)
		if pointed != Vector3.INF:
			direction = pointed - player.global_position
	return direction

func _melee_sound(index: int, hits: int) -> void:
	if index == CinderMelee.ATTACKS.SPIN:
		return
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
			if summit.cleared:
				_win()
			else:
				_save_checkpoint(true)
				summit.site.show()
				_deploy(summit.site)
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
		if active_site == summit.site:
			if summit.cleared and _near(beacon, 3.4):
				_win()
			elif _near(active_site.anchor, 5.5):
				battle.repair()
			return
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
	player.visual.gesture(&"deploy", core)
	core.transfer(site.anchor, SunCore.Form.DEPLOYED, 0.91)
	director.show_site(site.view_position, site.view_target)
	if site == grove:
		grove_terrain.release_herons()
	player.set_recovery_context(site.anchor.global_position)
	if battle != null:
		battle.prepare(site, core)
	_sync_controls()
	soundscape.cue("deploy")

func start_wave() -> bool:
	if mode != Mode.PREPARE or battle == null:
		return false
	if active_site == summit.site:
		if summit.begin(battle, player):
			mode = Mode.DEFEND
			_sync_controls()
			_notify("Vesper Colossus  •  move to the lit shoulder and counter")
			return true
		return false
	if active_site.remaining_energy <= 0.0:
		_notify("Pack the shrine and continue your journey")
		return false
	if not battle.begin(core.restoration >= 100.0):
		return false
	mode = Mode.DEFEND
	_sync_controls()
	return true

func _extract(delta: float) -> void:
	var capacity := active_site.remaining_energy
	if not battle.post_restoration:
		capacity = minf(capacity, 100.0 - core.restoration)
	var draw := minf(capacity, active_site.spec.rate * delta)
	if capacity - draw <= 0.00001:
		draw = capacity
	active_site.remaining_energy -= draw
	core.restoration = minf(100.0, core.restoration + draw)
	core.receive_site_energy(active_site, draw, director.reduced_motion)
	if draw > 0.0:
		soundscape.hear_extraction()
		if active_site == grove:
			bell_road.apply_reserve(grove.remaining_energy, grove.spec.energy, true, director.reduced_motion)
	var depleted := active_site.remaining_energy <= 0.0
	var filled_sun := not battle.post_restoration and core.restoration >= 100.0
	if depleted or filled_sun:
		battle.hold()
		mode = Mode.PREPARE if mode != Mode.PACK else Mode.PACK
		_pack_source = Mode.PREPARE
		_sync_controls()
		if depleted and draw > 0.0:
			_unlock_site_reward(active_site)
		elif filled_sun:
			_notify("Sun restored  ·  T to finish this shrine, or carry the sun to the beacon")

func _completed_sites() -> Array[StringName]:
	var complete: Array[StringName] = []
	for site in sites:
		if site.spec.energy > 0.0 and site.remaining_energy <= 0.0:
			complete.append(site.checkpoint_id)
	return complete

func _unlock_site_reward(site: CinderSite) -> void:
	_first_ability_award = false
	arts.unlock(site.checkpoint_id)
	battle.upgrade_cap = CinderBattle.BASE_UPGRADE_CAP + _completed_sites().size()
	var icon: Texture2D
	for row: Dictionary in arts.achievements():
		if StringName(row.get("id", "")) == site.checkpoint_id:
			icon = row.get("icon") as Texture2D
			break
	hud.announce_ability(arts.ability_name(site.checkpoint_id), icon, battle.upgrade_cap, _first_ability_award)

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
		player.visual.gesture(&"pack", core)
		if battle != null:
			battle.hold()
		_sync_controls()
	_pack_elapsed += delta
	if _pack_elapsed < PACK_SECONDS:
		return
	_transferring = true
	if active_site == summit.site:
		summit.retreat()
	if battle != null:
		battle.recall()
	active_site.select_socket(-1)
	core.transfer(player.visual.carry_anchor, SunCore.Form.CARRIED, 0.93)
	director.tactical = false
	soundscape.cue("pack")

func _cancel_pack() -> void:
	mode = _pack_source
	_pack_elapsed = 0.0
	if battle != null and (active_site == summit.site or
			(active_site.remaining_energy > 0.0 and (battle.post_restoration or core.restoration < 100.0))):
		battle.resume()
	_sync_controls()

func _sync_controls() -> void:
	var traveling := mode == Mode.EXPLORE or mode == Mode.TRANSIT
	player.move_enabled = (not _front_active and not _paused and not _map_open
		and (traveling or mode == Mode.PREPARE or mode == Mode.DEFEND))
	arts.set_available(player.move_enabled)
	raid_glow.set_raid(mode == Mode.DEFEND, director.reduced_motion)
	if not player.move_enabled and melee:
		melee.cancel()
	player.tactical = not traveling
	if _capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if traveling and player.move_enabled else Input.MOUSE_MODE_VISIBLE

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

func _guardian_sighting(message: String) -> void:
	_notify(message)
	soundscape.cue("vesper_call")

func _guardian_fell() -> void:
	# The core remains vulnerable during the pack channel. A killing blow can
	# coincide with packing, and the player may still choose to finish folding.
	if mode == Mode.PACK:
		_pack_source = Mode.PREPARE
	else:
		mode = Mode.PREPARE
	_notify("The guardian yields. Bring the sun to the beacon cradle.")
	if _checkpoint_enabled:
		_store_checkpoint(beacon.global_position + Vector3(0, .15, 1.6))
	_sync_controls()

func _win() -> void:
	if mode == Mode.WIN or mode == Mode.LOSE:
		return
	mode = Mode.WIN
	if battle != null:
		battle.stop()
	player.visual.gesture(&"deliver", core)
	core.transfer(beacon, SunCore.Form.DELIVERED, 1.25)
	_sync_controls()
	hud.hide()
	finale = FINALE.instantiate()
	add_child(finale)
	finale.score_cue.connect(_ending_cue)
	finale.finished.connect(_ending_finished)
	finale.play(director, player, beacon, director.reduced_motion)
	var clasp := get_tree().create_timer(1.25, false)
	clasp.timeout.connect(func() -> void:
		if finale != null:
			core.flare()
	)

func _ending_cue(cue: StringName) -> void:
	if cue == &"arch":
		atmosphere.sunrise = true
	soundscape.ending_cue(cue)

func _ending_finished() -> void:
	core.transfer(beacon, SunCore.Form.DELIVERED)
	atmosphere.sunrise = true
	atmosphere.set_dawn_fraction(1.0)
	if _checkpoint_enabled and JourneyCheckpoint.write({}):
		_checkpoint.clear()
	finale.queue_free()
	finale = null
	hud.show()
	_render_hud()

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
		and battle.enemies.is_empty() and player.has_safe_footing())

func _update_checkpoint(delta: float) -> void:
	if not _safe_checkpoint():
		_quiet_travel = 0.0
		return
	_quiet_travel += delta
	_checkpoint_timer += delta
	if _quiet_travel < 1.5 or (_checkpoint_timer < 7.0 and not _checkpoint.is_empty()):
		return
	_save_checkpoint()

func _save_checkpoint(beacon_arrival := false) -> void:
	if not _checkpoint_enabled:
		return
	if beacon_arrival:
		# Retry at the gate with the inventory and health carried up the ridge.
		_store_checkpoint(beacon.global_position + Vector3(0, .15, 1.6))
	elif _safe_checkpoint() and _quiet_travel >= 1.5:
		_store_checkpoint(player.recovery_point)

func _store_checkpoint(safe_position: Vector3) -> void:
	_checkpoint_timer = 0.0
	var records := {}
	for site in sites:
		records[site.checkpoint_id] = {"reserve": site.remaining_energy, "threat": site.threat}
	var state := {
		"position": safe_position, "yaw": director.yaw, "pitch": director.pitch,
		"facing": player.visual.rotation.y, "health": core.health, "restoration": core.restoration,
		"scrap": battle.scrap, "inventory": battle.inventory.duplicate(true),
		"sites": records, "claimed": _claimed_caches,
		"guardian_cleared": summit.cleared, "guardian_sighted": summit.halfway_seen,
		"shortcuts": outer_valley.unlocked_shortcut_ids(),
		"landmarks": landmarks.checkpoint_progress(),
		"ability_selected": arts.selected_id(),
		"ability_cooldowns": arts.cooldowns(),
		"ability_cast_lock": arts.cast_lock(),
		"frontier_version": CinderFrontier.LAYOUT_VERSION,
		"frontier_discoveries": frontier.claimed_discoveries(),
		"frontier_revealed": frontier.revealed_discoveries(),
		"trail_packs": trail_packs.progress(),
	}
	state.merge(layout.checkpoint_fields())
	if state != _checkpoint and JourneyCheckpoint.write(state):
		_checkpoint = state

func _restore_checkpoint() -> void:
	var saved_position: Vector3 = _checkpoint.get("position", OPENING)
	# The original version-1 hilltop was subsequently moved with the Relay district.
	if not _checkpoint.has("guardian_cleared") and float(_checkpoint.get("restoration", 0.0)) >= 99.999:
		var old_gate := CinderRelay.SUMMIT + Vector3.UP * .08
		if saved_position.distance_to(old_gate) < 6.0:
			saved_position += beacon.global_position - old_gate
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
	var complete := _completed_sites()
	battle.upgrade_cap = CinderBattle.BASE_UPGRADE_CAP + complete.size()
	arts.restore(complete, StringName(_checkpoint.get("ability_selected", &"")),
		_checkpoint.get("ability_cooldowns", _checkpoint.get("ability_cooldown", 0.0)),
		float(_checkpoint.get("ability_cast_lock", 0.0)))
	bell_road.apply_reserve(grove.remaining_energy, grove.spec.energy, false)
	summit.cleared = bool(_checkpoint.get("guardian_cleared", false))
	summit.halfway_seen = bool(_checkpoint.get("guardian_sighted", false))
	_claimed_caches = _checkpoint.get("claimed", PackedStringArray())
	outer_valley.restore_shortcuts(_checkpoint.get("shortcuts", PackedStringArray()))
	var saved_frontier := int(_checkpoint.get("frontier_version", CinderFrontier.LAYOUT_VERSION))
	if saved_frontier == CinderFrontier.LAYOUT_VERSION:
		frontier.restore_discoveries(_checkpoint.get("frontier_discoveries", PackedStringArray()),
			_checkpoint.get("frontier_revealed", PackedStringArray()))
	elif saved_position.z > CinderFrontier.ENTRANCE.z:
		saved_position = CinderFrontier.ENTRANCE
	player.restore_position(saved_position)
	trail_packs.restore_progress(_checkpoint.get("trail_packs", {}))
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
				return "E   Deliver the sun" if summit.cleared else "E   Unfold the shrine for the final defense"
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
		return ""
	if mode == Mode.DEPLOY:
		return "Unfolding shrine"
	if mode == Mode.PACK:
		return "Folding shrine" if _transferring else "Hold R   Keep folding"
	if active_site == summit.site and (mode == Mode.PREPARE or mode == Mode.DEFEND):
		return summit.hint()
	if mode == Mode.PREPARE:
		if active_site.remaining_energy <= 0.0:
			return "Hold R   Pack the shrine"
		if core.restoration >= 100.0:
			return "T   Finish the shrine     •     Hold R   Pack"
		return "T   Start wave     •     E   Repair"
	if mode == Mode.DEFEND:
		return landmarks.hint(player.global_position, _landmark_aim(), active_site, battle, false)
	return ""

func _render_hud() -> void:
	if hud == null or layout == null:
		return
	var local_site := active_site if active_site != null else _near_site()
	hud.render({
		"health": core.health, "restoration": core.restoration,
		"at_summit": active_site == summit.site,
		"guardian_health": summit.health_percent(), "guardian_phase": summit.phase_name(),
		"scrap": battle.scrap if battle != null else 0,
		"mode": str(Mode.keys()[mode]).capitalize(),
		"site": local_site.label if local_site != null else "",
		"energy": local_site.remaining_energy if local_site != null else 0.0,
		"site_energy_max": local_site.spec.energy if local_site != null else 0.0,
		"threat": local_site.threat if local_site != null else 0,
		"forecast": summit.hint() if active_site == summit.site else (battle.forecast() if battle != null and active_site != null else ""),
		"hint": _hint(local_site), "status": _notice if _notice_time > 0.0 else "",
		"selected": _selected, "socket": _hovered,
		"pack_progress": clampf(_pack_elapsed / PACK_SECONDS, 0.0, 1.0),
		"modules": battle.module_labels() if battle != null else PackedStringArray(),
		"paused": _paused,
		"settings_open": _settings_open, "checkpoint_available": not _checkpoint.is_empty(),
		"checkpoint_hint": "The last safe trail checkpoint will be used." if not _safe_checkpoint() and not _checkpoint.is_empty() else "",
	}.merged(_interface_state()))

## Objective, wave, shop and hover details for the interface.
func _interface_state() -> Dictionary:
	var state := {
		"map_open": _map_open,
		"dash_cooldown": player.dash_cooldown_remaining(),
		"dash_cooldown_max": CinderPlayer.DASH_COOLDOWN,
	}.merged(arts.hud_state())
	var goal := _objective()
	state["objective"] = goal.text
	state["objective_point"] = goal.point
	state["objective_distance"] = player.global_position.distance_to(goal.point) if goal.point != Vector3.INF else -1.0
	if (mode == Mode.EXPLORE or mode == Mode.TRANSIT) and goal.point != Vector3.INF:
		var guide := objective_route.direction_to(player.global_position, goal.point)
		state["compass_point"] = guide.point
		state["compass_distance"] = guide.distance
	if battle == null:
		return state
	state["upgrade_cap"] = battle.upgrade_cap
	var prices := []
	var owned := []
	var summaries := []
	for kind in CinderBattle.MODULES.size():
		var stats: CinderModuleStats = CinderBattle.MODULES[kind]
		prices.append(stats.price)
		var level := 0
		for module in battle.inventory:
			if module.kind == kind and module.socket == -1:
				level = maxi(level, module.level)
		owned.append(level)
		summaries.append("%s  Range %.1f m." % [stats.summary, stats.reach])
	state["prices"] = prices
	state["owned"] = owned
	state["summaries"] = summaries
	if active_site != null:
		var remaining := battle.remaining_spawns
		for enemy in battle.enemies:
			if not enemy.pursuing:
				remaining += 1
		state["wave"] = active_site.threat
		state["wave_active"] = battle.active_wave
		state["wave_left"] = remaining
		state["wave_total"] = battle.total_in_wave
		state["wave_lanes"] = active_site.lane_names
		state["engaged"] = battle.engaged
		state["next_wave"] = battle.intermission if battle.engaged and not battle.active_wave else -1.0
		state["breather"] = CinderBattle.WAVES.breather
		_socket_state(state)
	else:
		state["region"] = _region_name()
	state["summary"] = "%d creatures defeated  ·  %d:%02d on the trail  ·  sun %d%%" % [
		_defeated, int(_journey_seconds) / 60, int(_journey_seconds) % 60, floori(core.restoration)]
	return state

func _socket_state(state: Dictionary) -> void:
	if _hovered < 0 or _hovered >= active_site.sockets.size() or (mode != Mode.PREPARE and mode != Mode.DEFEND):
		return
	state["socket_point"] = active_site.sockets[_hovered].global_position
	state["socket_ok"] = true
	if battle.towers.has(_hovered):
		var tower: CinderInstalledModule = battle.towers[_hovered]
		var cost := battle.upgrade_cost(_hovered)
		state["socket_level"] = tower.level
		var level := "Lv %d/%d" % [tower.level, battle.upgrade_cap]
		if cost < 0:
			state["socket_text"] = "%s  ·  %s  ·  upgrade cap reached" % [CinderHUD.MODULES[tower.kind], level]
		else:
			state["socket_ok"] = battle.scrap >= cost
			state["socket_text"] = "%s  ·  %s   [U] upgrade for %d scrap" % [CinderHUD.MODULES[tower.kind], level, cost]
	elif _selected >= 0:
		var stats: CinderModuleStats = CinderBattle.MODULES[_selected]
		var free := battle.module_labels()[_selected].begins_with("packed")
		state["socket_ok"] = free or battle.scrap >= stats.price
		state["socket_text"] = ("Click to place %s (owned)" % CinderHUD.MODULES[_selected]) if free else (
			"Click to build %s  ·  %d scrap" % [CinderHUD.MODULES[_selected], stats.price] if state.socket_ok
			else "Need %d more scrap" % (stats.price - battle.scrap))
	else:
		state["socket_text"] = "Empty socket  ·  press 1, 2 or 3 to choose a tower"

func _region_name() -> String:
	var best := "The valley"
	var closest := 70.0
	for site in sites:
		var distance := player.global_position.distance_to(site.anchor.global_position)
		if distance < closest:
			closest = distance
			best = "Near " + site.label
	return best

## The single most useful next step, with a world point for the map.
func _objective() -> Dictionary:
	if active_site == summit.site and (mode == Mode.PREPARE or mode == Mode.DEFEND):
		if summit.cleared:
			return {"text": "Bring the sun to the beacon cradle", "point": beacon.global_position}
		return {"text": "Move to the lit shoulder and strike or spark twice" if mode == Mode.DEFEND
			else "Place modules and press T to challenge the guardian", "point": Vector3.INF}
	match mode:
		Mode.WIN, Mode.LOSE:
			return {"text": "", "point": Vector3.INF}
		Mode.DEPLOY, Mode.PACK:
			return {"text": "Unfolding the shrine" if mode == Mode.DEPLOY else "Hold R to fold the shrine",
				"point": Vector3.INF}
		Mode.PREPARE:
			if active_site.remaining_energy <= 0.0:
				return {"text": "This camp is spent  ·  hold R to pack up and move on", "point": Vector3.INF}
			if core.restoration >= 100.0:
				return {"text": "Finish this shrine for its reward or travel to the beacon", "point": Vector3.INF}
			return {"text": "Build towers, then press T to start drawing energy", "point": Vector3.INF}
		Mode.DEFEND:
			if battle.post_restoration:
				return {"text": "Defend the shrine to earn %s" % arts.ability_name(active_site.checkpoint_id), "point": Vector3.INF}
			return {"text": "Defend the shrine while it drinks %s's energy" % active_site.label, "point": Vector3.INF}
	if core.restoration >= 99.999 and beacon != null:
		return {"text": "Carry the restored sun to the Hilltop Beacon", "point": beacon.global_position}
	var target: CinderSite
	var best := INF
	for site in sites:
		if site.remaining_energy <= 0.001:
			continue
		var distance := player.global_position.distance_to(site.anchor.global_position)
		if site == _left_site:
			distance += 100000.0
		if distance < best:
			best = distance
			target = site
	if target == null:
		return {"text": "Every camp is spent", "point": Vector3.INF}
	return {"text": "Unfold the shrine at %s" % target.label, "point": target.anchor.global_position}
