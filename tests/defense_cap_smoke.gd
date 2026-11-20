extends SceneTree
## Run with godot --headless --fixed-fps 60 --script tests/defense_cap_smoke.gd.

const GROVE := preload("res://data/sites/grove.tres")
const SHRINE := preload("res://scenes/core/sun_core.tscn")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var core := SHRINE.instantiate() as SunCore
	world.add_child(core)
	var battle := CinderBattle.new()
	world.add_child(battle)
	var site := CinderSite.new()
	world.add_child(site)
	var lane := PackedVector3Array([Vector3(16, 0, 0), Vector3.ZERO])
	site.configure(GROVE, Vector3.ZERO, PackedVector3Array([
		Vector3(-3, 0, -1), Vector3(-3, 0, 1), Vector3(3, 0, 0),
	]), [lane], Vector3.ZERO, Vector3.ZERO)
	battle.prepare(site, core)
	battle.scrap = 2000
	for socket in 3:
		_check(battle.place(socket, socket), "Build module %d" % socket)
		_check(battle.upgrade(socket) and battle.upgrade(socket), "Reach base level 3")
		var at_three := battle.towers[socket].model.scale
		var funds := battle.scrap
		_check(battle.upgrade_cost(socket) == -1 and not battle.upgrade(socket)
			and battle.scrap == funds, "Base cap blocks a level and spends no scrap")
		battle.upgrade_cap = CinderBattle.BASE_UPGRADE_CAP + 1
		var next_price := battle.towers[socket].stats.upgrade_cost * 3
		_check(battle.upgrade_cost(socket) == next_price and battle.upgrade(socket)
			and battle.scrap == funds - next_price, "One shrine tier enables the existing level 4 cost")
		_check(battle.towers[socket].level == 4 and battle.towers[socket].model.scale == at_three,
			"Level 4 preserves the level 3 footprint")
		battle.upgrade_cap = CinderBattle.BASE_UPGRADE_CAP
	battle.upgrade_cap = 99
	_check(battle.upgrade_cap == 10, "Seven completions provide the final level cap")
	battle.recall()
	battle.prepare(site, core)
	var funds := battle.scrap
	_check(battle.place(1, 1) and battle.towers[1].level == 4 and funds == battle.scrap,
		"An upgraded module packs and redeploys for free at the same level")
	var at_four := battle.towers[1].model.scale
	for rank in range(5, 11):
		_check(battle.upgrade(1) and battle.towers[1].level == rank, "Upgrade to level %d" % rank)
	_check(battle.towers[1].model.scale == at_four and battle.upgrade_cost(1) == -1
		and not battle.upgrade(1), "Level 10 keeps its footprint and ends the upgrade ladder")

	_check(battle.begin(), "Start the pre-restoration wave")
	core.restoration = 100.0
	battle.hold()
	var threat := site.threat
	var spawns_left := battle.remaining_spawns
	_check(not battle.begin() and battle.held, "Full restoration waits for explicit continuation")
	_check(battle.begin(true) and battle.post_restoration and not battle.held
		and site.threat == threat and battle.remaining_spawns == spawns_left, "Continue the same active wave")
	for frame in 3:
		await physics_frame
	_check(battle.remaining_spawns < spawns_left, "Post-restoration defense spawns on the existing lane")
	battle.recall()
	battle.prepare(site, core)
	_check(not battle.post_restoration and not battle.begin(), "Packing clears post-restoration consent")
	_check(battle.begin(true) and site.threat == threat + 1, "An unfinished camp can start a fresh post-restoration wave")
	battle.recall()
	battle.prepare(site, core)
	site.remaining_energy = .0005
	_check(battle.begin(true), "Even a tiny positive reserve can still be defended and finished")
	battle.recall()
	battle.prepare(site, core)
	site.remaining_energy = 0.0
	_check(not battle.begin(true), "A drained camp cannot restart extraction")
	battle.stop()
	world.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)

func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS ", description)
	else:
		failures += 1
		push_error("FAIL " + description)
