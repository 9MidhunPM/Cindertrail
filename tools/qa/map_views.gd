extends SceneTree
## Windowed captures of the spread-out valley, the minimap and the full map.
## godot --script tools/qa/map_views.gd -- --out=/absolute/folder

const SIZE := Vector2i(1920, 1080)
var out := ""
var view: SubViewport
var game: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	var frame := SubViewportContainer.new()
	root.add_child(frame)
	view = SubViewport.new()
	view.size = SIZE
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	frame.add_child(view)
	set_meta(&"direct_journey", true)
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	view.add_child(game)
	for f in 20:
		await physics_frame
	var west: PackedVector3Array = game.outer_valley.route_between_nodes("grove_west", "quarry_gate")
	var north: PackedVector3Array = game.outer_valley.route_between_nodes("grove_north", "relay_gate")
	await _stand(west[3], west[4], "causeway-west")
	await _stand(north[4], north[5], "stair-north")
	await _stand(west[-2], west[-1], "quarry-arrival")
	await _stand(north[-2], north[-1], "relay-arrival")
	game.set("_map_open", true)
	game._render_hud()
	await _save("full-map")
	quit()

func _stand(at: Vector3, toward: Vector3, label: String) -> void:
	game.player.global_position = at + Vector3.UP * 0.3
	game.player.velocity = Vector3.ZERO
	var heading := toward - at
	game.director.yaw = atan2(-heading.x, -heading.z)
	game.director.pitch = 0.12
	game.player.visual.rotation.y = game.director.yaw
	game.director.reset_pose()
	for f in 40:
		await physics_frame
	await _save(label)

func _save(label: String) -> void:
	for f in 4:
		await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(out.path_join(label + ".png"))
