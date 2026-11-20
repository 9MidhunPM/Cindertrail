class_name CinderInstalledModule
extends Node3D

const FIELD_MATERIAL := preload("res://art/materials/slowing_field_material.tres")

var kind: int
var level: int
var stats: CinderModuleStats
var cooldown := 0.0
var model: Node3D
var field_ring: MeshInstance3D
var rotor: Node3D
var carriage: Node3D
var muzzle: Marker3D
var charge_material: StandardMaterial3D
var recoil := 0.0
var field_time := 0.0
var acquired := false

func configure(type: int, rank: int, spec: CinderModuleStats) -> void:
	kind = type
	level = rank
	stats = spec
	model = spec.model.instantiate() as Node3D
	add_child(model)
	model.scale = Vector3.ONE * 1.55 * pow(1.07, level - 1)
	if kind == 1:
		_configure_emitter()
		return
	rotor = Node3D.new()
	model.add_child(rotor)
	rotor.position.y = 0.54 if kind == 0 else 0.42
	carriage = Node3D.new()
	rotor.add_child(carriage)
	var parts := ["Bolt_prong*", "Rear_prong*", "Amber_crystal*"] if kind == 0 else ["Mortar_bowl*", "Bowl_glow*", "Amber_chamber*"]
	for pattern in parts:
		for piece in model.find_children(pattern, "MeshInstance3D", true, false):
			piece.reparent(carriage, true)
	var bearing := model.find_child("Turret_rotor*", true, false)
	if bearing:
		bearing.reparent(rotor, true)
	muzzle = Marker3D.new()
	carriage.add_child(muzzle)
	muzzle.position = Vector3(0, 0.30, 0.47) if kind == 0 else Vector3(0, 0.29, 0.04)
	charge_material = _own_glow("Amber_crystal*" if kind == 0 else "Bowl_glow*")

func _own_glow(pattern: String) -> StandardMaterial3D:
	var lens := model.find_child(pattern, true, false) as MeshInstance3D
	if not lens:
		return null
	var source := lens.get_active_material(0) as StandardMaterial3D
	if not source:
		return null
	var unique := source.duplicate() as StandardMaterial3D
	lens.material_override = unique
	return unique

func _configure_emitter() -> void:
	field_ring = MeshInstance3D.new()
	var disk := PlaneMesh.new()
	disk.size = Vector2.ONE * stats.reach * 2.0
	field_ring.mesh = disk
	field_ring.material_override = FIELD_MATERIAL
	field_ring.position.y = 0.13
	field_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(field_ring)
	charge_material = _own_glow("Cyan_cap*")

func track(point: Vector3, delta: float) -> void:
	var local := to_local(point)
	var yaw := atan2(local.x, local.z)
	rotor.rotation.y = lerp_angle(rotor.rotation.y, yaw, 1.0 - exp(-10.0 * delta)) if acquired else yaw
	acquired = true
	if kind == 0:
		var rise := point.y - rotor.global_position.y
		var pitch := -atan2(rise, maxf(0.01, Vector2(local.x, local.z).length()))
		carriage.rotation.x = lerpf(carriage.rotation.x, clampf(pitch, -0.35, 0.32), 1.0 - exp(-9.0 * delta))
	else:
		carriage.rotation.x = lerpf(carriage.rotation.x, 0.20, 1.0 - exp(-5.0 * delta))

func fire() -> Vector3:
	recoil = 1.0
	return muzzle.global_position

func _process(delta: float) -> void:
	if kind == 1:
		field_time = fmod(field_time + delta * 1.8, TAU)
		if charge_material:
			charge_material.emission_energy_multiplier = 1.5 + 0.45 * cos(field_time)
		return
	recoil = maxf(0.0, recoil - delta / (0.30 if kind == 0 else 0.48))
	# A short mechanical kick with a longer return leaves the planted feet still.
	var kick := sin(PI * pow(recoil, 2.7))
	carriage.position.z = -kick * (0.17 if kind == 0 else 0.05)
	carriage.position.y = -kick * (0.035 if kind == 0 else 0.19)
	if charge_material:
		charge_material.emission_energy_multiplier = 1.1 + 2.6 * kick
