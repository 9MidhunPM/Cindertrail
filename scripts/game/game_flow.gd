extends Node3D

enum Mode { EXPLORE, DEPLOY, PREPARE, DEFEND, PACK, TRANSIT, WIN, LOSE }

const GROVE := preload("res://data/sites/grove.tres")
const TRAVELER := preload("res://scenes/player/traveler_visual.tscn")
const SHRINE := preload("res://scenes/core/sun_core.tscn")
const INTERFACE := preload("res://scenes/ui/hud.tscn")
const QUARRY_REGION := preload("res://scripts/world/quarry.gd")
const RELAY_REGION := preload("res://scripts/world/relay.gd")
const CACHE_MODEL := preload("res://art/models/supply_crate.glb")
const PACK_SECONDS := 1.7
const OPENING := Vector3(-3.0, 0.76, 15.0)

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
var hud: CinderHUD
var grove: CinderSite
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_mouse = DisplayServer.get_name() != "headless" and not OS.has_feature("movie")
	atmosphere = CinderAtmosphere.new()
	_add_runtime(atmosphere)
	var terrain := CinderGrove.new()
	_add_runtime(terrain)
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
	battle = CinderBattle.new()
	_add_runtime(battle)
	battle.bind_carried_core(core)
	battle.message.connect(_notify)
	battle.sound.connect(soundscape.cue)
	hud = INTERFACE.instantiate() as CinderHUD
	add_child(hud)
	_add_cache(Vector3(-6.1, 0.72, 9.0), 16)
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
			Vector3(4, 0.66, 0), center])], Vector3(10, 15, 19), Vector3(0, 0, -1))
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

func _waymark(label: String, point: Vector3, direction: Vector3) -> void:
	var marker := CinderWaymark.new()
	marker.position = point
	marker.set_destination(label, direction)
	_add_runtime(marker)

func _physics_process(delta: float) -> void:
	if _paused:
		return
	if mode == Mode.WIN or mode == Mode.LOSE:
		_update_hud_clock(delta)
		return
	_notice_time = maxf(0.0, _notice_time - delta)
	soundscape.step(delta, player.get_real_velocity().slide(Vector3.UP).length())
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
	_update_hud_clock(delta)

func _update_hud_clock(delta: float) -> void:
	_hud_clock += delta
	if _hud_clock >= 0.05:
		_hud_clock = 0
		_render_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_hud") and hud != null:
		hud.visible = not hud.visible
		return
	if event.is_action_pressed("cancel"):
		if _selected != -1 and not _paused:
			_selected = -1
		elif mode != Mode.LOSE and mode != Mode.WIN:
			_paused = not _paused
			get_tree().paused = _paused
			_sync_controls()
			_render_hud()
		return
	if event.is_action_pressed("restart") and (mode == Mode.WIN or mode == Mode.LOSE or _paused):
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
	if (tactical and event.button_index == MOUSE_BUTTON_RIGHT) or (not tactical and event.button_index == MOUSE_BUTTON_LEFT):
		var origin := player.global_position + Vector3.UP * 1.13
		var direction := -camera.global_basis.z
		if tactical:
			var pointed := _pointer_ground(event.position)
			if pointed != Vector3.INF:
				direction = origin.direction_to(pointed + Vector3.UP * 0.41)
		else:
			direction.y = clampf(direction.y, -0.12, 0.18)
		battle.attack(origin, direction.normalized())

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
			soundscape.cue("collect")
			_notify("Recovered %d scrap" % amount)
			_caches.erase(cache)
			cache.queue_free()
			return
		var site := _near_site()
		if site != null:
			_deploy(site)
	elif (mode == Mode.PREPARE or mode == Mode.DEFEND) and _near(active_site.anchor, 5.5):
		if battle != null:
			battle.repair()

func _deploy(site: CinderSite) -> void:
	active_site = site
	mode = Mode.DEPLOY
	core.transfer(site.anchor, SunCore.Form.DEPLOYED, 0.91)
	director.show_site(site.view_position, site.view_target)
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
	core.restoration += draw
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
	player.move_enabled = traveling or mode == Mode.PREPARE or mode == Mode.DEFEND
	player.tactical = not traveling
	if _capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if traveling and not _paused else Input.MOUSE_MODE_VISIBLE

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

func _add_cache(point: Vector3, amount: int) -> void:
	var cache := CACHE_MODEL.instantiate() as Node3D
	cache.position = point
	cache.set_meta("scrap", amount)
	_add_runtime(cache)
	_caches.append(cache)

func _win() -> void:
	mode = Mode.WIN
	if battle != null:
		battle.stop()
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
	soundscape.cue("hurt")

func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _notify(message: String) -> void:
	_notice = message
	_notice_time = 4.0

func _hint(nearest: CinderSite) -> String:
	if mode == Mode.EXPLORE or mode == Mode.TRANSIT:
		if _near(beacon, 2.6):
			if core.restoration >= 99.999:
				return "E   Deliver the sun"
			return "Restore the sun before lighting the beacon"
		if _near_cache() != null:
			return "E   Recover supplies"
		if nearest != null:
			return "E   Unfold shrine at %s" % nearest.label
		if core.restoration >= 99.999:
			return "Follow the ridge beyond Fallen Relay to the beacon"
		return "Follow the stone causeway to the shrine pad" if mode == Mode.EXPLORE else "Follow the trail markers to another ancient site"
	if mode == Mode.DEPLOY:
		return "Unfolding shrine"
	if mode == Mode.PACK:
		return "Folding shrine" if _transferring else "Hold R   Keep folding"
	if mode == Mode.PREPARE:
		if active_site.remaining_energy <= 0.001 or core.restoration >= 99.999:
			return "Hold R   Pack the shrine"
		return "Space   Start wave     •     E   Repair"
	if mode == Mode.DEFEND:
		return "Hold R   Pack     •     E   Repair     •     U   Upgrade tower"
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
	})
