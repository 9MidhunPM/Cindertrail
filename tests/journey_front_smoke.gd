extends SceneTree

## Run with a temporary XDG_DATA_HOME. This test writes a real journey checkpoint.
var game: Node
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, detail: String) -> void:
	if condition:
		print("PASS ", detail)
	else:
		failures += 1
		push_error("FAIL " + detail)

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame

func _press(name: String) -> void:
	var button := game.find_child(name, true, false) as Button
	_check(button != null and button.is_visible_in_tree(), "Action visible: " + name)
	if button != null and button.is_visible_in_tree():
		button.pressed.emit()
	await process_frame

func _run() -> void:
	if not OS.has_environment("CINDERTRAIL_TEST_SAVE"):
		push_error("Use a temporary XDG_DATA_HOME and set CINDERTRAIL_TEST_SAVE=1")
		quit(1)
		return
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	game = current_scene
	var front: CinderFrontEnd = game.get("_front_end")
	_check(front.get("stage") == &"menu" and not game.hud.visible, "Ordinary launch opens the title")
	var opening: Vector3 = game.player.position
	Input.action_press("move_forward")
	await _frames(30)
	Input.action_release("move_forward")
	_check(game.player.position.is_equal_approx(opening), "Title blocks movement")
	await _press("NewJourney")
	_check(front.get("stage") == &"comic", "New Journey opens the comic")
	await _press("NextPanel")
	_check(front.get("panel_index") == 1, "Comic advances")
	await _press("PreviousPanel")
	_check(front.get("panel_index") == 0, "Comic goes back")
	await _press("SkipIntro")
	await _frames(120)
	_check(front.get("stage") == &"hidden" and game.hud.visible, "Comic skip enters the world")
	_check(game.player.is_on_floor() and not JourneyCheckpoint.read().is_empty(), "First checkpoint is saved on safe ground")
	var grove_cache: Node3D = game._caches[-1]
	for cache: Node3D in game._caches:
		if cache.global_position.distance_to(game.player.global_position) < grove_cache.global_position.distance_to(game.player.global_position):
			grove_cache = cache
	_place(grove_cache.global_position + Vector3.RIGHT)
	await _frames(20)
	game.interact()
	game.grove.threat = 4
	game.grove.remaining_energy -= 3.5
	game.core.restoration = 3.5
	game.core.health = 64.0
	game.battle.inventory.append({"kind": 0, "level": 2, "socket": -1})
	var scrap: int = game.battle.scrap
	game._save_checkpoint()
	var saved := JourneyCheckpoint.read()
	var anchors := {}
	for site: CinderSite in game.sites:
		anchors[site.checkpoint_id] = site.anchor.global_position
	_check(saved.get("world_layout_version") == 1 and saved.get("world_layout_id") == game.layout.layout_id,
		"New Journey saves its generated valley layout")
	_check(saved.get("claimed", PackedStringArray()).size() == 1 and saved.get("health") == 64.0, "Checkpoint records supply pickup and core damage")
	game.player.position = game.grove.anchor.global_position + Vector3(0, 0.12, 2)
	await _frames(8)
	game.interact()
	await _frames(85)
	game.start_wave()
	await _frames(50)
	game._save_checkpoint()
	_check(JourneyCheckpoint.read() == saved, "An active defense cannot replace the safe checkpoint")
	game.core.damage(999)
	game._hud_action(&"checkpoint")
	await scene_changed
	game = current_scene
	await _frames(15)
	for site: CinderSite in game.sites:
		_check(anchors[site.checkpoint_id] == site.anchor.global_position, "Checkpoint returns to the same " + site.label + " shrine")
	_check(game.core.health == 64.0 and game.core.restoration == 3.5, "Retry restores health and extraction")
	_check(game.grove.threat == 4 and game.grove.remaining_energy == saved.sites[game.grove.checkpoint_id].reserve, "Retry restores finite reserve and threat")
	_check(game.battle.scrap == scrap and game.battle.inventory.size() == 1 and game.battle.inventory[0].level == 2, "Retry restores the upgraded packed module and economy")
	_check(game.core.get_parent() == game.player.visual.carry_anchor, "Retry returns the core to the harness")
	game._hud_action(&"title")
	await scene_changed
	game = current_scene
	await _press("ContinueJourney")
	_check(game.core.restoration == 3.5 and game.hud.visible, "Continue resumes from the same checkpoint")
	await _check_frontier()
	var old_layout: int = game.layout.layout_id
	game._hud_action(&"title")
	await scene_changed
	game = current_scene
	await _press("NewJourney")
	await _press("StartNew")
	await _press("SkipIntro")
	await _frames(10)
	_check(game.layout.layout_id != old_layout, "New Journey chooses a different valley")
	for site: CinderSite in game.sites:
		_check(anchors[site.checkpoint_id].distance_to(site.anchor.global_position) > 1,
			"New Journey relocates " + site.label)
	quit(1 if failures else 0)

func _check_frontier() -> void:
	var first_seed := CinderFrontier.new()
	first_seed.journey_seed = 108
	root.add_child(first_seed)
	var second_seed := CinderFrontier.new()
	second_seed.journey_seed = 441
	root.add_child(second_seed)
	_check(first_seed.paths[1] != second_seed.paths[1] or first_seed.paths[2] != second_seed.paths[2],
		"Different journey seeds assemble different trail layouts")
	first_seed.free()
	second_seed.free()
	var expedition: CinderFrontier = game.frontier
	var paths := expedition.paths.duplicate()
	var seed_before := expedition.journey_seed
	var loot_before: int = game.battle.scrap
	_place(expedition.discovery_points()[0])
	await _frames(6)
	game.interact()
	_place(expedition.discovery_points()[0])
	await _frames(6)
	game.interact()
	_check(expedition.claimed_discoveries().size() == 1 and game.battle.scrap > loot_before,
		"A frontier clue leads to a one-time supply reward")
	var sun_id: int = game.core.get_instance_id()
	_place(expedition.site.anchor.global_position + Vector3.BACK)
	await _frames(6)
	game.interact()
	await _frames(85)
	_check(game.active_site == expedition.site and game.start_wave(), "Last Lantern deploys and starts a defense")
	await _frames(146)
	Input.action_press("pack")
	await _frames(166)
	Input.action_release("pack")
	_check(game.core.form == SunCore.Form.CARRIED and game.core.get_instance_id() == sun_id,
		"Packing carries the original sun out of the frontier camp")
	var frontier_fork: Vector3 = expedition.paths[0][-1]
	_place(frontier_fork)
	await _frames(130)
	game._save_checkpoint()
	var saved := JourneyCheckpoint.read()
	_check(Vector3(saved.get("position", Vector3.ZERO)).distance_to(frontier_fork) < 1.0,
		"Checkpoint can be taken on safe ground inside the frontier")
	game._hud_action(&"title")
	await scene_changed
	game = current_scene
	await _press("ContinueJourney")
	await _frames(7)
	expedition = game.frontier
	_check(expedition.journey_seed == seed_before and expedition.paths == paths and game.player.is_on_floor(),
		"Continue reconstructs the same trail before placing the traveler")
	_check(expedition.site.threat == 1 and expedition.site.remaining_energy < 10.0,
		"The optional camp keeps its depleted reserve and threat")
	_check(expedition.claimed_discoveries().size() == 1 and expedition.hint_at(expedition.discovery_points()[0]).is_empty(),
		"Collected frontier supplies stay collected after Continue")

func _place(point: Vector3) -> void:
	game.player.global_position = point + Vector3.UP * 0.12
	game.player.velocity = Vector3.ZERO
