extends "res://tools/qa/score_journey.gd"
## Record the three seeded side trails and their live cache interactions.

func _record_journey() -> bool:
	await _physics_frames(20)
	var discoveries: Array[Dictionary] = game.outer_valley.wayside_dressing.discoveries
	if not _check(discoveries.size() == 3, "The generated valley has three wayside discoveries"):
		return false
	for index in discoveries.size():
		var discovery := discoveries[index]
		var path: PackedVector3Array = discovery.path
		_position_player(path[0] + Vector3.UP * .18)
		game.player.recovery_point = game.player.global_position
		var forward := path[0].direction_to(discovery.point)
		game.director.yaw = atan2(-forward.x, -forward.z)
		game.director.reset_pose()
		_mark("wayside_%d" % (index + 1))
		await _physics_frames(38)
		if not await _walk_route(Array(path.slice(1)), "Wayside trail %d" % (index + 1)):
			return false
		await _physics_frames(35)
		var scrap: int = game.battle.scrap
		game.interact()
		if not _check(game.battle.scrap == scrap + 8, "Recovered a wayside cache"):
			return false
		await _physics_frames(62)
	return true
