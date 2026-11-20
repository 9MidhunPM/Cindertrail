extends SceneTree

const SHRINE := preload("res://scenes/core/sun_core.tscn")
const CAMPS := ["grove", "quarry", "relay", "lanternwood", "sunken_aqueduct", "sunwatch", "frontier"]
var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var harness := Node3D.new()
	root.add_child(harness)
	var core: SunCore = SHRINE.instantiate()
	harness.add_child(core)
	var sun_id := core.get_node("Visual/SunCenter").get_child(-1).get_instance_id()
	var streams := core.get_node("SiteEnergyStreams") as MeshInstance3D
	for id in CAMPS:
		var site := CinderSite.new()
		root.add_child(site)
		site.configure(load("res://data/sites/%s.tres" % id), Vector3(4, .7, -2),
			PackedVector3Array(), [], Vector3.ZERO, Vector3.ZERO)
		core.transfer(site.anchor, SunCore.Form.DEPLOYED)
		_check(not streams.visible, id + " prepared in silence")
		core.receive_site_energy(site, 0.0, false)
		_check(not streams.visible, id + " zero transfer")
		core.receive_site_energy(site, .005, false)
		_check(streams.visible and streams.mesh.get_surface_count() == 1, id + " emitted a shared stream surface")
		_check_sky_reach(streams, core.get_node("Visual/SunCenter").global_position, id)
		_check(core.restoration == 0.0 and site.remaining_energy == site.spec.energy, id + " VFX independent of economy")
		core.receive_site_energy(site, .005, true)
		_check(streams.get("quiet") and is_zero_approx(streams.call("arrival_glow")), id + " steady trace")
		await physics_frame
		await physics_frame
		_check(not streams.visible, id + " stops after last transfer")
		core.receive_site_energy(site, .005, false)
		core.transfer(harness, SunCore.Form.CARRIED)
		_check(not streams.visible, id + " clears immediately during recall")
		_check(core.get_node("Visual/SunCenter").get_child(-1).get_instance_id() == sun_id, id + " same sun")
		site.queue_free()
	set_meta(&"direct_journey", true)
	var game = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.active_site = game.grove
	game.core.transfer(game.grove.anchor, SunCore.Form.DEPLOYED)
	game.core.restoration = 99.9998
	game.grove.remaining_energy = 0.0007
	game._extract(1.0)
	_check(is_equal_approx(game.core.restoration, 100.0) and absf(game.grove.remaining_energy - .0005) < .000001,
		"the last pulse only removes energy the core can receive")
	game.core.restoration = 80.0
	game.grove.remaining_energy = .003
	game._extract(.2)
	_check(is_zero_approx(game.grove.remaining_energy) and absf(game.core.restoration - 80.003) < .000001,
		"emptying a small reserve credits the precise final pulse")
	game.queue_free()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
	else:
		print("CORE_DRAW_OK seven camps, interrupted/reduced/zero draw, recall and sun identity")
	quit(0 if failures.is_empty() else 1)

func _check_sky_reach(streams: MeshInstance3D, focal: Vector3, id: String) -> void:
	var arrays := streams.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var track: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var sources := 0
	var arrivals := 0
	for vertex in range(0, points.size(), 2):
		if track[vertex].y < 2.0 or track[vertex].y >= 3.0:
			continue
		var point := streams.to_global(points[vertex])
		if uv[vertex].x < .03 and point.distance_to(focal) >= 22.0 and point.y - focal.y >= 7.0:
			sources += 1
		if uv[vertex].x > .999 and point.distance_to(focal) < .02:
			arrivals += 1
	_check(sources >= 3 and arrivals == 3, id + " draws three elevated distant shafts into the one sun")

func _check(condition: bool, detail: String) -> void:
	if not condition:
		failures.append(detail)
