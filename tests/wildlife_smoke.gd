extends SceneTree

const ANIMAL := preload("res://scripts/world/wildlife_animal.gd")
const HABITAT := preload("res://scripts/world/wildlife_habitats.gd")
const S := ANIMAL.Species
const A := ANIMAL.Activity
const CAMPS := {
	S.FISH: &"flooded_grove", S.FROG: &"flooded_grove",
	S.PIKA: &"broken_quarry", S.GOAT: &"broken_quarry",
	S.DEER: &"lanternwood", S.OTTER: &"sunken_aqueduct",
	S.KITE: &"sunwatch_observatory", S.OWL: &"last_lantern_frontier",
}

var _failures := 0
var _game: Node3D
var _player: CinderPlayer
var _habitats: HABITAT
var _battle: CinderBattle
var _capture_dir := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	set_meta(&"direct_journey", true)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_capture_dir = arg.trim_prefix("--capture=")
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	_game = current_scene as Node3D
	_player = _game.player
	_player.set_physics_process(false)
	_habitats = _game.get_node("WildlifeHabitats") as HABITAT
	_battle = _game.battle
	await _frames(20)
	if _habitats.animals.is_empty():
		_check(false, "Main scene populated the valley wildlife")
		quit(1)
		return
	var deer := await _check_habitats()
	if deer != null:
		await _check_deer(deer)
	_check(_habitats.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"Wildlife never adds bodies or hitboxes to combat physics")
	quit(1 if _failures else 0)

func _check_habitats() -> ANIMAL:
	var deer: ANIMAL
	for species: int in CAMPS:
		var site := _find_camp(CAMPS[species])
		if site == null:
			_check(false, "Missing habitat for " + S.keys()[species])
			continue
		_player.global_position = site.anchor.global_position
		await _frames(20)
		var local: ANIMAL
		for animal in _habitats.animals:
			if animal.species == species and animal.home.distance_to(site.anchor.global_position) < 24.0:
				local = animal
				break
		_check(local != null and local.is_visible_in_tree()
			and not local.find_children("*", "MeshInstance3D", true, false).is_empty(),
			"%s is rendered at %s" % [S.keys()[species].capitalize(), site.label])
		if species == S.DEER:
			deer = local
			_check(deer != null and _has_painted_mesh(deer), "Deer geometry displays its painted coat colors")
	return deer

func _has_painted_mesh(animal: ANIMAL) -> bool:
	for part: MeshInstance3D in animal.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var material := part.get_active_material(surface) as BaseMaterial3D
			var paint: PackedColorArray = part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			if material != null and material.vertex_color_use_as_albedo and not paint.is_empty():
				return true
	return false

func _check_deer(deer: ANIMAL) -> void:
	_player.global_position = deer.home + Vector3.RIGHT * 20.0
	await _frames(20)
	_check(deer.visible and deer.activity == A.CALM, "Lanternwood deer graze while the traveler keeps their distance")
	if not _capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		await _capture_deer(deer)
		return

	_player.global_position = deer.wake_point() + Vector3.RIGHT * 1.0
	await _frames(3)
	_check(deer.activity == A.ALERT, "Nearby traveler makes the deer look up")
	await _frames(27)
	_check(deer.activity == A.FLEEING, "Startled deer run to cover")
	_player.global_position = deer.refuge + Vector3.BACK * 15.0
	await _frames(105)
	_check(deer.activity == A.HIDING and deer.wake_point().distance_to(deer.refuge) < 0.2,
		"Startled deer reach cover in their local habitat")
	await _frames(510)
	_check(deer.activity == A.CALM and deer.wake_point().distance_to(deer.home) < 1.2,
		"Deer return to grazing after the traveler moves away")

	var site := _find_camp(&"lanternwood")
	_player.global_position = site.anchor.global_position + Vector3.BACK * 1.4
	_game.interact()
	await _frames(88)
	_check(deer.activity == A.CALM and _game.active_site == site and _game.start_wave(),
		"Deployment at Lanternwood settles before an actual defense starts")
	await _frames(28)
	_check(deer.activity == A.FLEEING or deer.activity == A.HIDING,
		"Nearby combat makes wildlife seek cover")
	var combatants_only := not _battle.enemies.is_empty()
	for enemy in _battle.enemies:
		combatants_only = combatants_only and not _habitats.is_ancestor_of(enemy)
	_check(combatants_only, "A live wave registers combatants without allocating enemy slots to wildlife")

	_battle.stop()
	_player.global_position = deer.refuge + Vector3.BACK * 15.0
	await _frames(635)
	_check(deer.activity == A.CALM, "Wildlife returns after combat clears")
	_player.global_position = Vector3(0, 2, 0)
	await _frames(20)
	var resting := deer.wake_point()
	await _frames(85)
	_check(not deer.visible and resting.is_equal_approx(deer.wake_point()),
		"Distant wildlife hides and stops simulation")

func _capture_deer(deer: ANIMAL) -> void:
	var dir_error := DirAccess.make_dir_recursive_absolute(_capture_dir)
	if dir_error != OK:
		_check(false, "Create the wildlife capture directory")
		return
	var camera: Camera3D = _game.camera
	_game.director.set_physics_process(false)
	_game.hud.hide()
	camera.fov = 48.0
	var look := deer.wake_point() + Vector3(-1.3, .7, .2)
	camera.global_position = deer.wake_point() + Vector3(2.7, 1.65, 3.8)
	camera.look_at(look)
	var head := deer.find_child("Head", true, false) as Node3D
	for i in 230:
		if head != null and head.rotation.x < -.45:
			break
		await physics_frame
	await _capture("lanternwood-deer-grazing.png")
	_player.global_position = deer.wake_point() + Vector3.RIGHT
	await _frames(44)
	await _capture("lanternwood-deer-fleeing.png")

func _capture(file: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _capture_dir.path_join(file)
	_check(root.get_texture().get_image().save_png(path) == OK, "Captured " + file)

func _find_camp(id: StringName) -> CinderSite:
	for camp: CinderSite in _game.sites:
		if camp.checkpoint_id == id:
			return camp
	return null

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		_failures += 1
