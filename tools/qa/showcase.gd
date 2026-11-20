extends "res://tools/qa/runtime.gd"
## Launched by tools/showcase.sh so all writable Godot data is isolated.

const CARD := preload("res://tools/qa/showcase_card.gd")
const PROLOGUE := preload("res://scripts/ui/prologue_pages.gd")
const FRONT := preload("res://scenes/ui/front_end.tscn")
const ARTS := preload("res://scripts/game/art_achievements.gd").ARTS
const VOICE_ROOT := "res://art/audio/showcase"
const OPENING_LINE := "The morning has gone. One small sun is still warm."
const GUARDIAN_LINE := "The crown still has a keeper. Step toward the lit shoulder and interrupt its pulse."
const ENDING_LINE := "Set it down. Dawn knows the rest of the way."
const NARRATION := {
	&"flooded_grove": "The Grove kept its light beneath the water. We will need it before the next mile.",
	&"broken_quarry": "The last quarry crew left their tools where the rock gave way. Their work is still here.",
	&"fallen_relay": "This was the road the dawn took. We cross the place where it broke.",
	&"lanternwood": "Watch how the moths hold to the warm stones. They know what is still alive in here.",
	&"sunken_aqueduct": "Water took the lower streets. The high stones will hold if we defend them.",
	&"sunwatch_observatory": "These mirrors watched a sky the keepers never saw brighten again.",
	&"last_lantern_frontier": "Beyond the last town, someone kept this flame burning for the next traveler.",
}

var _card: CanvasLayer
var _voice: AudioStreamPlayer
var _results: Array[Dictionary] = []
var _cycles := 0
var _last_core := 0
var _next_art_frame := 0
var _art_casts: Dictionary = {}
var _spoken := true
var _stopping := false

func _run() -> void:
	route_case = "showcase"
	if not OS.has_environment("CINDERTRAIL_SHOWCASE_ISOLATED"):
		push_error("Start the showcase with tools/showcase.sh")
		quit(2)
		return
	use_window = DisplayServer.get_name() != "headless"
	for arg in OS.get_cmdline_user_args():
		if arg == "--once":
			_cycles = 1
		elif arg.begins_with("--cycles="):
			_cycles = maxi(1, int(arg.trim_prefix("--cycles=")))
		elif arg.begins_with("--out="):
			output_dir = arg.trim_prefix("--out=")
		elif arg == "--silent-voice":
			_spoken = false
	if output_dir.is_empty() or DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("The showcase needs a writable --out directory")
		quit(2)
		return
	viewport = root
	_card = CARD.new()
	_card.exit_requested.connect(_exit_showcase)
	root.add_child(_card)
	_voice = AudioStreamPlayer.new()
	_voice.bus = &"Effects"
	_voice.volume_db = -2.0
	_card.add_child(_voice)
	set_meta(&"direct_journey", true)
	set_meta(&"journey_seed", 80)
	set_meta(&"world_layout_version", CinderJourneyLayout.VERSION)
	while not _stopping and (_cycles == 0 or _results.size() < _cycles):
		await _play_journey()
		if _stopping:
			return
		if failures.is_empty() and not measurements.get("finale_completed", false):
			_check(false, "The journey stopped before the sunrise finale completed")
		_results.append({
			"journey": _results.size() + 1,
			"passed": failures.is_empty(),
			"failures": failures.duplicate(),
			"elapsed_seconds": float(Time.get_ticks_usec() - start_usec) / 1000000.0,
			"playthrough": measurements.duplicate(true)
		})
		_write_report()
		if not failures.is_empty():
			_exit_showcase(1)
			return
		await _clear_journey()
	_exit_showcase()

func _play_journey() -> void:
	start_usec = Time.get_ticks_usec()
	physics_samples = 0
	_next_art_frame = 0
	_art_casts = {}
	measurements = {
		"seed": get_meta(&"journey_seed"),
		"layout_version": get_meta(&"world_layout_version"),
		"engine": Engine.get_version_info().string,
		"display_driver": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"resolution": "%dx%d" % [root.size.x, root.size.y] if use_window else "headless",
		"art_casts": _art_casts,
	}
	game = (load(MAIN) as PackedScene).instantiate()
	root.add_child(game)
	root.move_child(_card, -1)
	current_scene = game
	game.arts.cast_succeeded.connect(_record_cast)
	await _physics_frames(6)
	var identity: int = game.core.get_instance_id()
	_check(_mode() == "Explore" and game.core.restoration == 0.0 and identity != _last_core,
		"The showcase starts a new journey with a fresh, uncharged core")
	_last_core = identity
	await _read_prologue()
	if use_window:
		_say("The journey begins", OPENING_LINE, "arrival")
		await _physics_frames(130)
	await _roaming_campaign()
	if not _check(measurements.has("journey_seconds") and _mode() == "Win" and game.summit.cleared,
			"The complete journey reaches the finale after the summit battle"):
		return
	_say("The first light", ENDING_LINE, "dawn")
	for tick in 1900:
		if not is_instance_valid(game.finale):
			break
		await _physics_frames(1)
	_check(not is_instance_valid(game.finale) and game.core.get_instance_id() == identity and _core_count() == 1,
		"The full finale ends with the same delivered sun")
	measurements["finale_completed"] = not is_instance_valid(game.finale)
	if use_window:
		await _physics_frames(360)

func _read_prologue() -> void:
	game.player.set_physics_process(false)
	var comic: CanvasLayer = FRONT.instantiate()
	root.add_child(comic)
	root.move_child(_card, -1)
	comic.show_comic()
	for index in PROLOGUE.PAGES.size():
		comic._show_panel(index)
		await _physics_frames(315 if use_window else 3)
	comic._finish_comic()
	_check(comic.stage == &"hidden", "The illustrated prologue hands off to the playable world")
	measurements["prologue_pages"] = PROLOGUE.PAGES.size()
	game.player.set_physics_process(true)
	await _physics_frames(35)
	comic.queue_free()

func _campaign_defense(site: CinderSite, route_summary: Array[Dictionary]) -> bool:
	var id := site.checkpoint_id
	_say(site.label, NARRATION.get(id, "The sun can take the light here if we hold the ground."), String(id))
	if id == CinderCampLandmarks.SUNWATCH and not await _prepare_observatory(site):
		return false
	return await super._campaign_defense(site, route_summary)

func _prepare_observatory(site: CinderSite) -> bool:
	for handle: Vector3 in game.landmarks.handle_positions_for(site):
		if not await _walk_to(handle):
			return false
		game.interact()
	if not _check(game.landmarks.checkpoint_progress().get(CinderCampLandmarks.SUNWATCH, 0) == 2,
			"Aligned both Sunwatch mirrors on foot"):
		return false
	for cache: Node3D in game._caches:
		if cache.get_meta(&"checkpoint_id") == game.MIRROR_CACHE_ID:
			var scrap: int = game.battle.scrap
			if not await _walk_to(cache.global_position):
				return false
			game.interact()
			return _check(game.battle.scrap > scrap, "Collected the Sunwatch mirror recess")
	return _check(false, "Found the Sunwatch mirror recess")

func _assist_target() -> void:
	_cast_ready_art()
	super._assist_target()

func _cast_ready_art() -> void:
	if physics_samples < _next_art_frame or game.battle.enemies.is_empty() or not game.player.visual.can_cast_art():
		return
	if game.player.is_dashing() or game.player.is_staggered():
		return
	_next_art_frame = physics_samples + 36
	var cooldowns: Dictionary = game.arts.cooldowns()
	var origin: Vector3 = game.player.global_position
	for spec: CinderArtSpec in ARTS:
		if float(cooldowns.get(spec.site, INF)) > 0.0 or spec.site == &"sunken_aqueduct":
			continue
		var target: CinderEnemy
		var best := maxf(spec.reach - .35, 3.0)
		for enemy: CinderEnemy in game.battle.enemies:
			var distance := origin.distance_to(enemy.global_position)
			if not enemy.fading and distance < best and game.battle.blade_path_clear(origin, enemy):
				target = enemy
				best = distance
		if not target:
			continue
		for step in cooldowns.size():
			if game.arts.selected_id() == spec.site or not game.arts.cycle():
				break
		var offset := target.global_position - origin
		if game.arts.cast(offset, target.global_position):
			return

func _record_cast(site: StringName) -> void:
	_art_casts[site] = int(_art_casts.get(site, 0)) + 1

func _fight_guardian(capture := false) -> bool:
	_say("Vesper's vigil", GUARDIAN_LINE, "guardian")
	return await super._fight_guardian(capture)

# The shared campaign helper takes fixed-size evidence stills in native runs.
# The showcase stays in the viewer's window and skips those captures.
func _capture(_filename: String) -> void:
	pass

func _say(headline: String, line: String, voice_name: String) -> void:
	if not use_window:
		return
	var seconds := 5.0
	if _spoken:
		var path := VOICE_ROOT.path_join(voice_name + ".ogg")
		var speech := load(path) as AudioStream if ResourceLoader.exists(path) else null
		if speech != null:
			_voice.stream = speech
			_voice.play()
			seconds = maxf(seconds, speech.get_length() + .25)
	_card.narrate(headline, line, seconds)

func _clear_journey() -> void:
	_voice.stop()
	_voice.stream = null
	_card.clear()
	current_scene = null
	game.queue_free()
	await process_frame
	await process_frame
	failures.clear()

func _write_report() -> void:
	var report := FileAccess.open(output_dir.path_join("showcase.json"), FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify({"journeys": _results}, "  ") + "\n")
	print("CINDERTRAIL_SHOWCASE ", JSON.stringify(_results[-1]))

func _exit_showcase(code := 0) -> void:
	if _stopping:
		return
	_stopping = true
	_voice.stop()
	_voice.stream = null
	for action in ["move_left", "move_right", "move_forward", "move_back", "pack", "sprint", "walk"]:
		Input.action_release(action)
	_close.call_deferred(code)
