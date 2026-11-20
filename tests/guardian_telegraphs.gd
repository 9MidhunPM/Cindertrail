extends SceneTree
## Isolated cue geometry and counter-source checks. guardian_smoke exercises a full journey.
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var cradle := Marker3D.new()
	world.add_child(cradle)
	var crown := preload("res://scripts/world/beacon_guardian.gd").new()
	world.add_child(crown)
	crown.build(cradle)
	var player := CinderPlayer.new()
	world.add_child(player)
	var battle := CinderBattle.new()
	world.add_child(battle)
	crown.begin(battle, player)
	var boss := crown.guardian
	var core := preload("res://scenes/core/sun_core.tscn").instantiate() as SunCore
	world.add_child(core)
	core.global_position = crown.site.anchor.global_position
	boss._enter(boss.Phase.BRACE)
	player.global_position = boss.counter_position()
	boss.combat_hit(80.0, &"tower")
	check(boss.phase == boss.Phase.BRACE, "High-power tower cannot interrupt a brace")
	player.global_position = boss.global_position - boss.shoulder_direction() * 1.5
	boss.combat_hit(25.0, &"melee")
	check(boss.phase == boss.Phase.BRACE, "Armor blocks direct hits on the dark side")
	player.global_position = boss.counter_position()
	boss.combat_hit(4.0, &"spark")
	check(boss.phase == boss.Phase.BRACE, "First correct spark marks the lit plate")
	boss.combat_hit(4.0, &"spark")
	check(boss.phase == boss.Phase.OPEN, "Second correct spark interrupts")
	boss.combat_hit(9999.0, &"ability")
	check(is_equal_approx(boss.health, 238.0), "Overkill cannot skip a whole phase")
	boss._enter(boss.Phase.RETURN)
	check(boss.stage == 2, "Phase two follows a successfully broken stage")
	boss._enter(boss.Phase.RING)
	player.global_position = boss.global_position + boss.shoulder_direction() * 2.18
	boss.advance(core, .3, 1.0)
	check(not player.is_staggered(), "The drawn ring gap is walkable")
	boss._enter(boss.Phase.RING)
	player.global_position = boss.global_position - boss.shoulder_direction() * 2.18 + Vector3.UP * .9
	boss.advance(core, .3, 1.0)
	check(not player.is_staggered(), "Jump height clears the solid arc")
	boss._enter(boss.Phase.RING)
	player.global_position = boss.global_position - boss.shoulder_direction() * 2.18
	boss.advance(core, .3, 1.0)
	check(player.is_staggered(), "Grounded contact with the solid arc staggers")
	quit(1 if failures else 0)
