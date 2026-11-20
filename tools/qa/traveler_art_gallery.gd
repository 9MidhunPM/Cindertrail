extends SceneTree
## Stage the unlocked techniques at the same physical Grove crossing using the live ability controller.
## godot --script tools/qa/traveler_art_gallery.gd -- --out=/absolute/folder
const IDS := [&"flooded_grove",&"broken_quarry",&"fallen_relay",&"lanternwood",&"sunken_aqueduct",&"sunwatch_observatory",&"last_lantern_frontier"]
var out := ""
var game
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out=arg.trim_prefix("--out=")
	if not out.is_absolute_path() or DisplayServer.get_name()=="headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	set_meta(&"direct_journey",true)
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	game=current_scene
	var center: Vector3=game.grove.anchor.global_position
	var forward := Vector3(.90,0,-.43).normalized()
	var base: Vector3=center - forward * 2.8 + Vector3(0,0,2.05)
	game.player.global_position=center+Vector3.UP*.08
	game.player.reset_physics_interpolation()
	game.interact()
	for i in 75:
		await physics_frame
	game.hud.hide()
	game.director.show_site(center+Vector3(3.2,5.1,8.8),center+Vector3(0,.65,1.3))
	game.battle.set_physics_process(false)
	for pos:Vector3 in [base+forward*3.0,base+forward*3.9+Vector3.LEFT*.9,base+forward*3.9+Vector3.RIGHT*.7]:
		game.battle.spawn_enemy(game.battle.CRAWLER,PackedVector3Array([pos,pos]),game.grove)
	for i in 18:
		await physics_frame
	var failed := false
	for id in IDS:
		game.player.global_position = base
		game.player.velocity = Vector3.ZERO
		game.arts.restore(IDS,id,0)
		var good:bool=game.arts.cast(forward,base+forward*2.4)
		if not good:
			push_error("Could not stage "+String(id))
			failed=true
			continue
		for i in (9 if id != &"sunken_aqueduct" else 5):
			await physics_frame
		await RenderingServer.frame_post_draw
		var filename: String=game.arts.ability_name(id).to_snake_case()+".png"
		if root.get_texture().get_image().save_png(out.path_join(filename)) != OK:
			failed=true
		for enemy in game.battle.enemies:
			enemy.health=enemy.stats.health
	quit(1 if failed else 0)
