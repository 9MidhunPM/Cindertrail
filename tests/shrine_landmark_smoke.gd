extends SceneTree
## godot --headless --fixed-fps 60 --script tests/shrine_landmark_smoke.gd

const LAYOUT := preload("res://scripts/world/journey_layout.gd")

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(passed: bool, description: String) -> void:
	if not passed:
		failures += 1
		push_error(description)

func _frames(count: int) -> void:
	for tick in count:
		await physics_frame

func _run() -> void:
	set_meta(&"direct_journey", true)
	set_meta(&"journey_seed", 2854)
	for version in range(2, LAYOUT.VERSION + 1):
		set_meta(&"world_layout_version", version)
		change_scene_to_file("res://scenes/main.tscn")
		await scene_changed
		await _frames(6)
		await _exercise(current_scene, version)
	print("SHRINE_LANDMARK_FAILURES ", failures)
	quit(0 if failures == 0 else 1)

func _exercise(game: Node, version: int) -> void:
	_check(game.layout.version == version, "Loaded journey layout v%d" % version)
	var landmarks: CinderCampLandmarks = game.landmarks
	var titles := PackedStringArray()
	var frontier: CinderSite
	for site: CinderSite in game.sites:
		var guide := landmarks.guide_for(site.checkpoint_id)
		var title := str(guide.get("title", ""))
		_check(not title.is_empty() and not titles.has(title), "Each shrine needs a distinct landmark guide")
		_check(" E " in str(guide.get("detail", "")), "Landmark guide explains the E interaction")
		titles.append(title)
		if site.checkpoint_id == landmarks.FRONTIER:
			frontier = site
	_check(titles.size() == 7 and frontier != null, "All seven shrines loaded")
	if frontier == null:
		return
	var points := landmarks.handle_positions_for(frontier)
	_check(not points.is_empty(), "Watchfire is registered in v%d" % version)
	if points.is_empty():
		return
	var center := frontier.anchor.global_position
	game.player.global_position = center + Vector3.UP * .10
	game.interact()
	await _frames(100)
	if not game.start_wave():
		_check(false, "Watchfire site deployed and entered combat in v%d" % version)
		return
	game.player.global_position = points[0] + Vector3.UP * .07
	var battle: CinderBattle = game.battle
	var hint := landmarks.hint(game.player.global_position, Vector3.INF, frontier, battle, false)
	_check(hint.begins_with("E   Stoke"), "Watchfire can be stoked within reach during a wave")
	var inside := _enemy_near(battle, frontier, center + Vector3.LEFT * 2.0)
	var outside := _enemy_near(battle, frontier, center + Vector3.RIGHT * 6.0)
	var pursuer := _enemy_near(battle, frontier, center + Vector3.RIGHT * 2.0)
	pursuer.pursuing = true
	game.interact()
	_check(game.get("_notice") == "An ember ring scorches approaching attackers.", "E stokes the watchfire in play")
	await _frames(3)
	_check(is_equal_approx(inside.health, 17.0), "Ring burns attackers inside")
	_check(is_equal_approx(outside.health, 34.0), "Ring does not burn attackers outside")
	_check(is_equal_approx(pursuer.health, 34.0), "Ring leaves retreat pursuers alone")
	outside.global_position = center + Vector3.RIGHT * 3.3
	await _frames(3)
	_check(is_equal_approx(outside.health, 17.0), "Ring burns an enemy arriving after ignition")
	_check(is_equal_approx(inside.health, 17.0), "Ring burns each enemy once")
	game.interact()
	_check(game.get("_notice") == "The landmark recharges each wave.", "Watchfire cannot be stoked twice in the same wave")
	var late := _enemy_near(battle, frontier, center + Vector3.LEFT * 3.0)
	battle.hold()
	await _frames(3)
	_check(is_equal_approx(late.health, 34.0), "Holding the battle extinguishes the ember ring")
	print("SHRINE_LANDMARKS v%d, seven guides and watchfire combat" % version)

func _enemy_near(battle: CinderBattle, site: CinderSite, at: Vector3) -> CinderEnemy:
	var enemy := battle.spawn_enemy(CinderBattle.CRAWLER,
		PackedVector3Array([at, site.anchor.global_position]), site, 0)
	enemy.set_physics_process(false)
	return enemy
