extends SceneTree

const MAIN := "res://scenes/main.tscn"
const SIZE := Vector2i(1920, 1080)
const MODES := ["Explore", "Deploy", "Prepare", "Defend", "Pack", "Transit", "Win", "Lose"]
const QUARRY_PATH := [
    Vector3(-9.0, 0.7, 1.7), Vector3(-16.0, 0.7, 1.0), Vector3(-24.0, 0.7, 1.0),
    Vector3(-28.0, 0.7, 1.0), Vector3(-33.0, 0.8, 2.4), Vector3(-39.0, 1.0, 2.0),
    Vector3(-45.0, 1.15, 0.0), Vector3(-51.0, 1.15, 0.0),
]
const RELAY_PATH := [
    Vector3(0.5, 0.7, -4.4), Vector3(2.0, 0.7, -12.5), Vector3(0.0, 0.7, -19.0),
    Vector3(0.0, 0.68, -24.0), Vector3(0.0, 0.68, -27.0), Vector3(4.0, 1.6, -34.0),
    Vector3(7.0, 2.7, -41.0), Vector3(8.54, 4.8, -44.55),
    Vector3(9.0, 4.8, -47.0), Vector3(10.0, 4.8, -51.0),
]
const BEACON_PATH := [
    Vector3(16.0, 4.8, -56.0), Vector3(20.0, 5.4, -62.0), Vector3(20.0, 7.3, -69.0),
    Vector3(19.0, 9.3, -77.0), Vector3(20.0, 11.0, -81.0), Vector3(20.0, 11.0, -83.0),
]
const GROVE_SOUTH := [
    Vector3(0.2, 0.7, 4.5), Vector3(-2.6, 0.7, 10.0), Vector3(-3.4, 0.7, 16.0),
    Vector3(-1.0, 0.68, 24.7),
]
const QUARRY_SOUTH := [
    Vector3(-45, 1.15, 0), Vector3(-39, 1.0, 2), Vector3(-36, 0.92, 2),
    Vector3(-36, 0.92, 6.5),
]
const RELAY_FROM_EAST := [
    Vector3(23.4, 4.40, -51.4), Vector3(19.4, 4.8, -52.45),
    Vector3(16.7, 4.8, -53), Vector3(10, 4.8, -53),
]

var game: Variant
var viewport: Viewport
var output_dir: String
var route_case := "grove"
var failures: Array[String] = []
var measurements: Dictionary = {}
var use_window: bool
var physics_samples := 0
var start_usec: int
var frame_recording := false
var clip_frames := 0


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    start_usec = Time.get_ticks_usec()
    use_window = DisplayServer.get_name() != "headless"
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--case="):
            route_case = argument.trim_prefix("--case=")
        elif argument.begins_with("--out="):
            output_dir = argument.trim_prefix("--out=")
        elif argument == "--record-transition":
            frame_recording = true
    if output_dir.is_empty() or not output_dir.is_absolute_path():
        push_error("Supply --out=/absolute/path after Godot's -- separator.")
        quit(2)
        return
    if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
        push_error("Could not create " + output_dir)
        quit(2)
        return
    if route_case == "grove" and not use_window:
        push_error("Grove capture requires a running display driver.")
        quit(2)
        return

    var loaded := load(MAIN) as PackedScene
    if loaded == null:
        _check(false, "Load main scene")
        _finish()
        return
    viewport = root
    if use_window:
        var display := SubViewportContainer.new()
        root.add_child(display)
        var capture := SubViewport.new()
        capture.size = SIZE
        capture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        capture.msaa_3d = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", 0))
        capture.screen_space_aa = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/screen_space_aa", 0))
        display.add_child(capture)
        # Fit the fixed-size game output inside the compositor's actual window.
        var fit := func() -> void:
            var scale_factor := minf(float(root.size.x) / SIZE.x, float(root.size.y) / SIZE.y)
            display.scale = Vector2.ONE * scale_factor
            display.position = (Vector2(root.size) - Vector2(SIZE) * scale_factor) * 0.5
        root.size_changed.connect(fit)
        fit.call()
        viewport = capture

    set_meta(&"direct_journey", true)
    game = loaded.instantiate()
    viewport.add_child(game)
    if viewport == root:
        current_scene = game
    await _physics_frames(6)
    if not _check(_mode() == "Explore", "Run begins in Explore"):
        _finish()
        return
    match route_case:
        "grove":
            await _grove()
        "relocation":
            await _relocation()
        "defeat":
            await _defeat()
        "terrain":
            await _terrain()
        "input":
            await _window_input()
        "three-sites", "grove-relay":
            await _complete_run(route_case == "three-sites")
        "campaign-west", "campaign-south":
            await _campaign(route_case == "campaign-west")
            _check(measurements.has("journey_seconds"), "Campaign reaches the sunrise ending")
        "campaign-combinations":
            _campaign_combinations()
        "eastern-ascent":
            _position_player(Vector3(28, 4.01, -51.4))
            await _physics_frames(12)
            game.core.restoration = 100.0
            if await _walk_route(RELAY_FROM_EAST, "Relay eastern span"):
                await _deliver(game.core.get_instance_id())
        "relay-profile":
            await _relay_profile()
        "outer-profile":
            await _outer_profile()
        "quarry":
            if _check(use_window, "Quarry capture requires a graphical display") and await _cross_grove():
                await _quarry_frame()
        "dawn":
            if _check(use_window, "Dawn capture requires a graphical display"):
                await _dawn_frame()
        "render-tour":
            if _check(use_window, "Render tour requires a graphical display"):
                await _grove()
                await _quarry_frame()
                await _reset_capture()
                await _relay_profile()
                await _reset_capture()
                await _dawn_frame()
        _:
            _check(false, "Unknown case: " + route_case)
    _finish()


func _grove() -> void:
    if not _check(_core_count() == 1, "Scene begins with one core"):
        return
    var identity: int = game.core.get_instance_id()
    var carried_parent: Node = game.core.get_parent()
    game.hud.hide()
    if not frame_recording:
        measurements["quiet_exploration"] = await _profile(180, 60)
    await _capture("grove-exploration.png")
    game.hud.show()
    if frame_recording:
        _record_clip()
    if not await _cross_grove():
        return
    game.interact()
    if not await _wait_mode("Prepare", 180):
        return
    _check(game.core.get_instance_id() == identity, "The core retained identity on deployment")
    _check(game.core.get_parent() != carried_parent, "The core left the carry anchor")
    _check(_core_count() == 1, "One core after deployment")
    await _capture("grove-tactical.png")
    if not frame_recording:
        game.hud.hide()
        await _capture("grove-tactical-clean.png")
        game.hud.show()
    if not frame_recording and is_instance_valid(game.battle):
        if _check(game.battle.place(0, 0), "Bolt installed from starting scrap"):
            if game.battle.scrap >= 12:
                game.battle.place(1, 2)
            _check(game.start_wave(), "Started a Grove attack")
            await _physics_frames(260)
            await _capture("grove-defense-live.png")
            game.hud.hide()
            await _capture("grove-defense-clean.png")
            game.hud.show()
    if not await _pack():
        return
    _check(game.core.get_parent() == carried_parent, "Packing restored the carry anchor")
    _check(game.core.get_instance_id() == identity and _core_count() == 1, "Packing retained one core")
    await _walk_to(Vector3(0.0, 0.7, 5.0))
    await _capture("grove-retreat.png")
    frame_recording = false


func _record_clip() -> void:
    var folder := output_dir.path_join("transition_frames")
    if DirAccess.make_dir_recursive_absolute(folder) != OK:
        _check(false, "Create transition frames directory")
        return
    var draw := 0
    while frame_recording:
        await RenderingServer.frame_post_draw
        draw += 1
        if draw % 2 != 0 or not frame_recording:
            continue
        var frame := viewport.get_texture().get_image()
        frame.resize(960, 540, Image.INTERPOLATE_BILINEAR)
        var error := frame.save_jpg(folder.path_join("%04d.jpg" % clip_frames), 0.90)
        if error != OK:
            _check(false, "Write transition frame")
            return
        clip_frames += 1


func _relocation() -> void:
    var grove: Variant = game.grove
    var identity: int = game.core.get_instance_id()
    if not await _cross_grove():
        return
    game.interact()
    if not await _wait_mode("Prepare", 180):
        return
    var original_scrap: int = game.battle.scrap
    _check(not game.battle.place(-1, 0), "Invalid socket rejected")
    _check(game.battle.scrap == original_scrap, "Invalid purchase preserves scrap")
    # Keep the east approach deliberately undefended so an attacker can reach the shrine.
    if not _check(game.battle.place(0, 1), "Slowing field placed"):
        return
    var balance: int = game.battle.scrap
    _check(not game.battle.place(0, 0), "Occupied socket rejected")
    _check(game.battle.scrap == balance, "Occupied socket preserves scrap")
    _check(game.battle.upgrade(0), "Slowing field upgraded")
    game.start_wave()
    if not await _wait_mode("Defend", 90):
        return
    for tick in range(0, 1800, 12):
        if game.core.health < 100.0 and _enemy_count() > 0:
            break
        await _physics_frames(12)
    _check(game.core.health < 100.0, "Hostiles damaged the shrine before retreat")
    var charged: float = game.core.restoration
    var depleted: float = grove.remaining_energy
    var health_before_pack: float = game.core.health
    _check(charged > 0.0 and depleted < grove.spec.energy, "Defense restores the core and depletes the grove")
    if not await _pack():
        return
    var departure := _snapshot(grove)
    _check(departure.health < health_before_pack, "Hostile damage continued during packing")
    _check(departure.enemies > 0, "Existing enemies survived packing")
    _check(game.battle.towers.is_empty(), "Packing recalled the installed tower")
    _check(game.battle.enemies.any(func(enemy): return enemy.pursuing), "Attackers became pursuers")
    var quarry: Variant = _find_site("Broken Quarry")
    if quarry == null or not await _walk_route(QUARRY_PATH, "Grove to Quarry"):
        return
    if not await _interact_at_pad():
        return
    _check(game.core.get_instance_id() == identity and _core_count() == 1, "One persistent core on redeploy")
    _check(is_equal_approx(game.core.restoration, departure.restoration), "Restoration survived relocation")
    _check(game.core.health > 0.0 and game.core.health <= departure.health, "Retreat did not reset core health")
    _check(game.battle.scrap == departure.scrap, "Scrap survived relocation")
    _check(grove.threat == departure.threat, "Travel did not start a Grove wave")
    _check(game.battle.place(0, 1), "Recalled field can be placed at destination")
    _check(game.battle.scrap == departure.scrap, "Recalled field is owned and deploys without cost")
    _check(game.battle.towers.has(0) and game.battle.towers[0].level == 2, "Recalled field retained its upgrade")
    var return_route := QUARRY_PATH.duplicate()
    return_route.reverse()
    return_route.append(Vector3(-1.8, 0.72, 0.6))
    if not await _pack() or not await _walk_route(return_route, "Quarry back to Grove") or not await _interact_at_pad():
        return
    _check(is_equal_approx(grove.remaining_energy, departure.energy), "Grove energy persisted on return")
    _check(grove.threat == departure.threat, "Grove threat persisted on return")
    measurements["grove_departure"] = departure


func _defeat() -> void:
    if not await _deploy(game.grove):
        return
    game.start_wave()
    if not await _wait_mode("Defend", 90):
        return
    Input.action_press("pack")
    if not await _wait_mode("Pack", 20):
        Input.action_release("pack")
        return
    game.core.damage(1000.0)
    Input.action_release("pack")
    if not await _wait_mode("Lose", 90):
        return
    var charged: float = game.core.restoration
    await _physics_frames(90)
    _check(is_equal_approx(game.core.restoration, charged), "Defeat stopped extraction")
    await _restart()


func _terrain() -> void:
    if not await _deploy(game.grove):
        return
    game.start_wave()
    await _physics_frames(20)
    if not _check(_enemy_count() > 0, "The Grove spawned a crawler"):
        return
    var crawler: CharacterBody3D = game.battle.enemies[0]
    var wet_peak := 0.0
    var dry_peak := 0.0
    for frame in range(0, 1180, 6):
        if not is_instance_valid(crawler):
            break
        var speed := crawler.get_real_velocity().slide(Vector3.UP).length()
        if game.grove.wet_depth_at(crawler.global_position):
            wet_peak = maxf(wet_peak, speed)
        else:
            dry_peak = maxf(dry_peak, speed)
        if dry_peak > 2.3 and wet_peak > 1.0:
            break
        await _physics_frames(6)
    measurements["crawler_ground_speed"] = {"wet_m_per_s": wet_peak, "dry_m_per_s": dry_peak}
    _check(wet_peak > 1.0 and wet_peak < 1.8, "Crawler made progress at reduced speed in shallow water")
    _check(dry_peak > 2.3, "The same crawler returned to its dry movement speed")


func _window_input() -> void:
    if not _check(use_window, "Window input test uses the actual viewport"):
        return
    var opening_pose: Transform3D = game.camera.global_transform
    var motion := InputEventMouseMotion.new()
    motion.relative = Vector2(165.0, 18.0)
    motion.position = Vector2(SIZE) / 2.0
    viewport.push_input(motion, true)
    await _physics_frames(45)
    _check(not game.camera.global_transform.is_equal_approx(opening_pose), "Mouse input rotated exploration camera")
    _key_action("cancel")
    await process_frame
    _check(paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape pauses and releases mouse")
    _key_action("cancel")
    await process_frame
    _check(not paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Escape resumes and captures mouse")
    if not await _cross_grove():
        return
    _key_action("interact")
    if not await _wait_mode("Prepare", 180):
        return
    _check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Tactical mode has a free pointer")
    var socket_position: Vector3 = game.grove.sockets[0].global_position
    var point: Vector2 = game.camera.unproject_position(socket_position)
    var pointer := InputEventMouseMotion.new()
    pointer.position = point
    pointer.global_position = point
    viewport.push_input(pointer, true)
    await _physics_frames(2)
    _key_action("module_bolt")
    var click := InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    click.pressed = true
    click.position = point
    click.global_position = point
    viewport.push_input(click, true)
    click = click.duplicate()
    click.pressed = false
    viewport.push_input(click, true)
    await _physics_frames(2)
    _check(game.battle.towers.has(0), "Number key and click installed the bolt tower")
    _key_action("start_wave")
    if not await _wait_mode("Defend", 60):
        return
    if not await _pack():
        return
    _check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Packed mode restored captured orbit")


func _key_action(action: StringName) -> void:
    var event := InputEventAction.new()
    event.action = action
    event.pressed = true
    viewport.push_input(event, true)
    event = event.duplicate()
    event.pressed = false
    viewport.push_input(event, true)


func _complete_run(use_quarry: bool) -> void:
    var route: Array = [game.grove]
    if use_quarry:
        route.append(_find_site("Broken Quarry"))
    route.append(_find_site("Fallen Relay"))
    if route.has(null):
        return
    var identity: int = game.core.get_instance_id()
    var route_summary: Array[Dictionary] = []
    if not await _collect_grove_supplies() or not await _cross_grove():
        return
    for site in route:
        if site.label == "Broken Quarry":
            if not await _walk_route(QUARRY_PATH, "Grove to Quarry"):
                return
        elif site.label == "Fallen Relay":
            if use_quarry:
                var return_route := QUARRY_PATH.duplicate()
                return_route.reverse()
                return_route.append(Vector3(-1.5, 0.72, 0.6))
                if not await _walk_route(return_route, "Quarry back to Grove"):
                    return
            if not await _walk_route(RELAY_PATH, "Grove to Relay"):
                return
        if not await _interact_at_pad():
            return
        for index in site.sockets.size():
            # Start with splash in one lane and fill the other positions with bolt fire.
            var kind := 2 if index == 1 else 0
            game.battle.place(index, kind)
        game.start_wave()
        if not await _wait_mode("Defend", 90):
            return
        if not await _defend_site(site, site == route.back()):
            return
        if not await _pack():
            return
        var visit := _snapshot(site)
        visit["site"] = site.label
        route_summary.append(visit)
    measurements["route"] = route_summary
    if not _check(is_equal_approx(game.core.restoration, 25.0 * float(route.size())),
        "Original camps contribute their complete reserves"):
        return
    _check(game.core.restoration < 100.0, "Old two- and three-camp routes require another defense")
    await _restart()


func _campaign_combinations() -> void:
    if not _check(game.sites.size() == 6, "Six camps loaded"):
        return
    var tested := 0
    for a in range(6):
        for b in range(a + 1, 6):
            for c in range(b + 1, 6):
                for d in range(c + 1, 6):
                    game.core.restoration = 0.0
                    for index: int in [a, b, c, d]:
                        var camp: CinderSite = game.sites[index]
                        camp.remaining_energy = camp.spec.energy
                        game.active_site = camp
                        game._extract(1000.0)
                        _check(camp.remaining_energy == 0.0, camp.label + " has a finite reserve")
                    _check(game.core.restoration == 100.0, "%d/%d/%d/%d reaches the beacon threshold" % [a, b, c, d])
                    tested += 1
    measurements["combinations"] = tested
    _check(tested == 15, "Checked every four-camp combination")


func _campaign(use_quarry: bool) -> void:
    var identity: int = game.core.get_instance_id()
    var route_summary: Array[Dictionary] = []
    if not await _collect_grove_supplies() or not await _cross_grove():
        return
    if not await _campaign_defense(game.grove, route_summary):
        return
    var junction := "grove"
    if use_quarry:
        if not await _walk_route(QUARRY_PATH, "Grove to Quarry"):
            return
        if not await _campaign_defense(_find_site("Broken Quarry"), route_summary):
            return
        if not await _walk_route(QUARRY_SOUTH, "Quarry's southern gallery"):
            return
        junction = "quarry"
    elif not await _walk_route(GROVE_SOUTH, "Grove's southern causeway"):
        return
    var destinations := PackedStringArray(["west", "east"] if use_quarry else ["west", "south", "east"])
    var sites_by_junction := {"west": "Lanternwood", "south": "Sunken Aqueduct", "east": "Sunwatch Observatory"}
    for next in destinations:
        if not await _walk_outer(junction, next):
            return
        if not await _campaign_defense(_find_site(sites_by_junction[next]), route_summary):
            return
        junction = next
    measurements["route"] = route_summary
    if not _check(is_equal_approx(game.core.restoration, 100.0), "Four fought defenses restore the sun"):
        return
    if not await _walk_outer(junction, "relay") or not await _walk_route(RELAY_FROM_EAST, "Relay eastern span"):
        return
    if not await _deliver(identity):
        return
    measurements["journey_seconds"] = physics_samples / 60.0
    _check(game.battle.enemies.is_empty(), "Victory ends pursuit and organized attacks")


func _walk_outer(from: String, to: String) -> bool:
    var steps: PackedVector3Array = game.outer_valley.route_between_nodes(from, to)
    if not _check(steps.size() > 1, "Outer trail is open from %s to %s" % [from, to]):
        return false
    return await _walk_route(Array(steps), "%s to %s" % [from, to])


func _outer_profile() -> void:
    if not _check(use_window, "Outer profile requires the graphical renderer"):
        return
    var route: PackedVector3Array = game.outer_valley.route_between_nodes("grove", "cross")
    if not _check(route.size() >= 3, "Pilgrims' Cross trail available"):
        return
    var offset := route[2] - route[1]
    _position_player(route[1] + Vector3.UP * 0.18)
    game.director.yaw = atan2(-offset.x, -offset.z)
    game.player.visual.rotation.y = game.director.yaw
    game.director.reset_pose()
    await _physics_frames(24)
    var start: Vector3 = game.player.global_position
    Input.action_press("move_forward")
    measurements["outer_crossing"] = await _profile(210, 10)
    Input.action_release("move_forward")
    _check(game.player.global_position.distance_to(start) > 2.0 and game.player.is_on_floor(),
        "Player moves along the outer trail during the sample")
    await _capture("outer-trail-profile.png")


func _campaign_defense(site: CinderSite, route_summary: Array[Dictionary]) -> bool:
    if site == null or not await _interact_at_pad():
        return false
    for index in site.sockets.size():
        game.battle.place(index, 2 if index == 1 else 0)
    if not game.start_wave() or not await _wait_mode("Defend", 90):
        return false
    if not await _defend_site(site, false) or not await _pack():
        return false
    var visit := _snapshot(site)
    visit["site"] = site.label
    route_summary.append(visit)
    return true


func _deliver(identity: int) -> bool:
    var beacon: Marker3D = game.get("beacon")
    if not _check(is_instance_valid(beacon), "Beacon anchor available"):
        return false
    if not await _walk_route(BEACON_PATH, "Relay to hilltop beacon"):
        return false
    game.interact()
    if not await _wait_mode("Win", 180):
        return false
    _check(game.core.get_instance_id() == identity and _core_count() == 1, "The same core is delivered")
    if use_window:
        await _physics_frames(160)
        await _capture("beacon-sunrise.png")
    return true


func _relay_profile() -> void:
    if not _check(use_window, "Relay profile requires the graphical renderer"):
        return
    var relay: Variant = _find_site("Fallen Relay")
    if relay == null or not await _deploy(relay):
        return
    # Seed the expected challenge of a late run without making a separate fixture scene.
    game.core.restoration = 85.0
    relay.threat = 5
    game.battle.scrap = 50
    game.battle.place(1, 1)
    if not _check(game.start_wave(), "Started a late Relay wave"):
        return
    var observed_peak := 0
    for frame in range(0, 1320, 30):
        observed_peak = maxi(observed_peak, _enemy_count())
        if _enemy_count() >= 8 or (_enemy_count() >= 5 and game.battle.remaining_spawns == 0):
            break
        await _physics_frames(30)
    _check(observed_peak >= 5, "At least five enemies active together")
    # Build into the active attack with all four sockets populated for the timed sample.
    game.battle.place(0, 0)
    game.battle.place(2, 2)
    game.battle.place(3, 0)
    measurements["relay_defense"] = await _profile(240, 0)
    measurements["relay_defense"]["site_threat"] = relay.threat
    measurements["relay_defense"]["starting_restoration"] = 85.0
    await _capture("fallen-relay-defense.png")


func _quarry_frame() -> void:
    var quarry: Variant = _find_site("Broken Quarry")
    if quarry == null or not await _walk_to(Vector3(-1.8, 0.72, 1.2)):
        return
    if not await _walk_route(QUARRY_PATH, "Grove to Quarry"):
        return
    if not await _interact_at_pad():
        return
    game.battle.place(0, 0)
    game.battle.place(1, 2)
    _check(game.start_wave(), "Started a Quarry wave")
    await _physics_frames(310)
    await _capture("broken-quarry-defense.png")


func _dawn_frame() -> void:
    var beacon := game.get("beacon") as Marker3D
    if not _check(is_instance_valid(beacon), "Find beacon for the sunrise capture"):
        return
    game.core.restoration = 100.0
    var identity: int = game.core.get_instance_id()
    _position_player(beacon.global_position + Vector3(0.0, 0.12, 1.85))
    await _physics_frames(8)
    game.interact()
    if not await _wait_mode("Win", 80):
        return
    await _physics_frames(320)
    _check(game.core.get_instance_id() == identity and game.core.get_parent() == beacon,
        "End frame shows the delivered core with its original identity")
    await _capture("beacon-sunrise.png")
    game.hud.hide()
    await _capture("beacon-sunrise-clean.png")


func _reset_capture() -> void:
    game.queue_free()
    await process_frame
    game = (load(MAIN) as PackedScene).instantiate()
    viewport.add_child(game)
    await _physics_frames(10)


func _defend_site(site: Variant, last_site: bool) -> bool:
    # Repair, upgrade, and start subsequent waves through the same gameplay APIs used by the HUD.
    var capture_taken := false
    var frame_budget := 42000
    for frame in range(0, frame_budget, 30):
        if _mode() == "Lose":
            return _check(false, "Survived defenses at " + site.label)
        if game.core.restoration >= 99.999 or site.remaining_energy <= 0.001:
            return true
        if _mode() == "Prepare":
            for index in site.sockets.size():
                game.battle.place(index, 0)
            if game.core.health < 70.0:
                game.battle.repair()
            if game.battle.scrap >= 30:
                game.battle.upgrade(0)
            game.start_wave()
        elif game.core.health < 75.0:
            game.battle.repair()
        for index in site.sockets.size():
            if not game.battle.towers.has(index) and game.battle.scrap >= 8:
                game.battle.place(index, 0)
            elif game.battle.towers.has(index) and game.battle.scrap >= 24 and game.battle.towers[index].level < 3:
                game.battle.upgrade(index)
        _assist_target()
        if use_window and not capture_taken and _enemy_count() >= 6:
            var shot_name: String = site.label.to_lower().replace(" ", "-")
            if last_site:
                measurements["relay_defense"] = await _profile(180, 0)
            await _capture(shot_name + "-defense.png")
            capture_taken = true
        await _physics_frames(30)
    return _check(false, "Extraction finished within time budget at " + site.label)


func _assist_target() -> void:
    var enemies: Array = game.battle.enemies
    if enemies.is_empty():
        return
    var origin: Vector3 = game.player.global_position + Vector3.UP
    var closest: Node3D
    var closest_distance := INF
    for enemy in enemies:
        var distance: float = origin.distance_squared_to(enemy.global_position)
        if distance < closest_distance:
            closest_distance = distance
            closest = enemy
    if closest != null:
        var target: Vector3 = closest.body_center()
        game.battle.attack(origin, origin.direction_to(target))


func _restart() -> void:
    var old_game: int = game.get_instance_id()
    if viewport != root:
        game.reparent(root)
        current_scene = game
    game.restart()
    await _physics_frames(12)
    game = current_scene
    if not _check(is_instance_valid(game) and game.get_instance_id() != old_game, "Restart replaces the run"):
        return
    _check(_mode() == "Explore" and _core_count() == 1, "Restart returns to Explore with one core")
    _check(is_equal_approx(game.core.health, 100.0), "Restart resets core health")
    _check(is_zero_approx(game.core.restoration), "Restart resets restoration")
    _check(is_equal_approx(game.grove.remaining_energy, game.grove.spec.energy) and game.grove.threat == 0, "Restart resets the grove")
    _check(_enemy_count() == 0, "Restart clears enemies")


func _deploy(site: Variant) -> bool:
    _position_player(site.anchor.global_position + Vector3(0.0, 0.12, 2.0))
    await _physics_frames(6)
    return await _interact_at_pad()


func _interact_at_pad() -> bool:
    game.interact()
    return await _wait_mode("Prepare", 180)


func _cross_grove() -> bool:
    for point in [Vector3(-2.7, 0.7, 10), Vector3(0, 0.7, 5), Vector3(0, 0.7, 2.0)]:
        if not await _walk_to(point):
            return false
    return _check(game.player.global_position.y > 0.55 and game.player.is_on_floor(),
        "Player walked the causeway onto the dry pad")


func _collect_grove_supplies() -> bool:
    var before: int = game.battle.scrap
    if not await _walk_to(Vector3(-4.08, 0.7, 9.0)):
        return false
    game.interact()
    return _check(game.battle.scrap > before, "Collected the Grove supply cache through interaction")


func _walk_route(path: Array, label: String) -> bool:
    Input.action_press("sprint")
    for point: Vector3 in path:
        if not await _walk_to(point):
            Input.action_release("sprint")
            return false
        if not _check(absf(game.player.global_position.y - point.y) < 0.75, "Walkable elevation at %s" % point):
            Input.action_release("sprint")
            return false
    Input.action_release("sprint")
    return _check(true, "Walked " + label)


func _walk_to(point: Vector3, limit := 360) -> bool:
    var actions := ["move_left", "move_right", "move_forward", "move_back"]
    for tick in limit:
        var offset: Vector3 = point - game.player.global_position
        offset.y = 0.0
        if offset.length_squared() < 0.28:
            for action in actions:
                Input.action_release(action)
            await _physics_frames(9)
            return true
        var direction := offset.normalized()
        var right: Vector3 = game.camera.global_basis.x.slide(Vector3.UP).normalized()
        var forward: Vector3 = -game.camera.global_basis.z.slide(Vector3.UP).normalized()
        var dx := direction.dot(right)
        var dz := direction.dot(forward)
        var amounts := [-dx, dx, dz, -dz]
        for i in actions.size():
            if amounts[i] > 0.0:
                Input.action_press(actions[i], amounts[i])
            else:
                Input.action_release(actions[i])
        await _physics_frames(1)
    for action in actions:
        Input.action_release(action)
    return _check(false, "Player path reaches %s from %s" % [point, game.player.global_position])


func _pack() -> bool:
    Input.action_press("pack")
    var packed := await _wait_mode("Transit", 240)
    Input.action_release("pack")
    return packed


func _position_player(point: Vector3) -> void:
    game.player.global_position = point
    game.player.velocity = Vector3.ZERO


func _find_site(label: String) -> Variant:
    for site in game.sites:
        if site.label == label:
            return site
    _check(false, "Find site " + label)
    return null


func _snapshot(site: Variant) -> Dictionary:
    return {
        "health": game.core.health,
        "restoration": game.core.restoration,
        "energy": site.remaining_energy,
        "threat": site.threat,
        "scrap": game.battle.scrap,
        "enemies": _enemy_count(),
    }


func _mode() -> String:
    var index: int = game.mode
    return MODES[index] if index >= 0 and index < MODES.size() else "Unknown"


func _core_count() -> int:
    return _count_script(game, game.core.get_script())


func _count_script(node: Node, script: Script) -> int:
    var count := int(node.get_script() == script)
    for child in node.get_children():
        count += _count_script(child, script)
    return count


func _enemy_count() -> int:
    return game.battle.enemies.size() if is_instance_valid(game.battle) else 0


func _wait_mode(target: String, limit: int) -> bool:
    for frame in limit:
        if _mode() == target:
            return true
        await _physics_frames(1)
    return _check(false, "Reached %s from %s" % [target, _mode()])


func _physics_frames(count: int) -> void:
    for frame in count:
        await physics_frame
    physics_samples += count


func _capture(filename: String) -> void:
    for frame in 4:
        await RenderingServer.frame_post_draw
    var screenshot := viewport.get_texture().get_image()
    if not _check(screenshot != null and screenshot.get_size() == SIZE, "Read back rendered 1920×1080 image"):
        return
    var path := output_dir.path_join(filename)
    if _check(screenshot.save_png(path) == OK, "Saved " + path):
        print("CINDERTRAIL_CAPTURE ", path)


func _profile(samples: int, warmup: int) -> Dictionary:
    var times: Array[float] = []
    var cpu_times: Array[float] = []
    var gpu_times: Array[float] = []
    var draws: Array[int] = []
    var enemies: Array[int] = []
    var viewport_id := viewport.get_viewport_rid()
    RenderingServer.viewport_set_measure_render_time(viewport_id, true)
    for frame in maxi(warmup, 8):
        await RenderingServer.frame_post_draw
    var previous := Time.get_ticks_usec()
    for frame in samples:
        await RenderingServer.frame_post_draw
        var now := Time.get_ticks_usec()
        times.append(float(now - previous) / 1000.0)
        previous = now
        cpu_times.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport_id))
        gpu_times.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport_id))
        draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
        enemies.append(_enemy_count())
    RenderingServer.viewport_set_measure_render_time(viewport_id, false)
    var frame_stats := _timing_summary(times)
    return {
        "samples": samples,
        "mean_frame_ms": frame_stats.mean,
        "p95_frame_ms": frame_stats.p95,
        "worst_frame_ms": frame_stats.max,
        "viewport_cpu_render_ms": _timing_summary(cpu_times),
        "viewport_gpu_render_ms": _timing_summary(gpu_times),
        "peak_enemies": enemies.max(),
        "peak_draw_calls": draws.max(),
        "vsync": DisplayServer.window_get_vsync_mode(),
        "frame_time_source": "wall time between frame_post_draw signals",
    }


func _timing_summary(samples: Array[float]) -> Dictionary:
    samples.sort()
    return {
        "mean": samples.reduce(func(sum: float, ms: float) -> float: return sum + ms, 0.0) / samples.size(),
        "p95": samples[ceili(samples.size() * 0.95) - 1],
        "max": samples[-1],
    }


func _check(condition: bool, description: String) -> bool:
    print("CINDERTRAIL_", "PASS" if condition else "FAIL", " ", description)
    if not condition:
        failures.append(description)
    return condition


func _finish() -> void:
    var result := {
        "case": route_case,
        "passed": failures.is_empty(),
        "failures": failures,
        "engine": Engine.get_version_info().string,
        "os": OS.get_name(),
        "processor": OS.get_processor_name(),
        "display_driver": DisplayServer.get_name(),
        "renderer": RenderingServer.get_current_rendering_method(),
        "graphics_api": RenderingServer.get_current_rendering_driver_name(),
        "gpu": RenderingServer.get_video_adapter_name(),
        "gpu_api_version": RenderingServer.get_video_adapter_api_version(),
        "resolution": "%dx%d" % [SIZE.x, SIZE.y] if use_window else "headless",
        "elapsed_seconds": float(Time.get_ticks_usec() - start_usec) / 1000000.0,
        "physics_frames_awaited": physics_samples,
        "transition_frames": clip_frames,
        "performance": measurements,
    }
    var report := FileAccess.open(output_dir.path_join(route_case + ".json"), FileAccess.WRITE)
    if report != null:
        report.store_string(JSON.stringify(result, "  ") + "\n")
        report.close()
    print("CINDERTRAIL_QA ", JSON.stringify(result))
    _close.call_deferred(0 if failures.is_empty() else 1)


func _close(exit_code: int) -> void:
    if is_instance_valid(game):
        if game == current_scene:
            current_scene = null
        game.queue_free()
        await process_frame
    # Give the mixer a frame to release any ambient or combat voices.
    await create_timer(0.08).timeout
    quit(exit_code)
