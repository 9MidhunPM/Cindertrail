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
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
	else:
		print("CORE_DRAW_OK seven camps, interrupted/reduced/zero draw, recall and sun identity")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, detail: String) -> void:
	if not condition:
		failures.append(detail)
