class_name CinderBladeTrail
extends MeshInstance3D
## Ribbon swept by the sunsteel blade. Samples the blade's base and tip every
## frame while the traveler swings, and fades the oldest sections first.

const ATTACKS := preload("res://scripts/hero/traveler_attacks.gd")
const LIFETIME := 0.16
const MAX_SECTIONS := 22

var source: TravelerVisual
var director: CinderCamera
var _color_mode := -2
var _ink: ShaderMaterial
var _quiet := false
var _samples: Array[Dictionary] = []
var _strip := ImmediateMesh.new()
var _sampling := false

func _ready() -> void:
	mesh = _strip
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ink = ShaderMaterial.new()
	_ink.shader = preload("res://scripts/fx/blade_trail.gdshader")
	material_override = _ink
	global_transform = Transform3D.IDENTITY

func _process(delta: float) -> void:
	var quiet := director != null and director.reduced_motion
	var lifetime := .070 if quiet else LIFETIME
	if quiet != _quiet:
		_quiet = quiet
		_ink.set_shader_parameter("quiet", quiet)
	for sample in _samples:
		sample.age += delta
	while not _samples.is_empty() and _samples[0].age > lifetime:
		_samples.pop_front()
	var active := source != null and source.trailing()
	if active:
		if not _sampling:
			_samples.clear()
		var attack := source.active_attack_index()
		if attack != _color_mode:
			_color_mode = attack
			var ink_color := Color("#ff963b")
			if attack == ATTACKS.DASH_CUT:
				ink_color = Color("#61e3d3")
			elif attack == ATTACKS.DESCENT:
				ink_color = Color("#ffb658")
			_ink.set_shader_parameter("ember", ink_color)
		var blade := source.blade_segment()
		if _samples.is_empty() or blade[1].distance_squared_to(_samples[-1].tip) > 0.000004:
			_samples.append({"base": blade[0], "tip": blade[1], "age": 0.0})
			if _samples.size() > MAX_SECTIONS:
				_samples.pop_front()
	_sampling = active
	_strip.clear_surfaces()
	if _samples.size() < 2:
		return
	_strip.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for sample in _samples:
		var life := 1.0 - float(sample.age) / lifetime
		_strip.surface_set_color(Color(1, 1, 1, life))
		_strip.surface_set_uv(Vector2(life, 0.0))
		_strip.surface_add_vertex(sample.base)
		_strip.surface_set_color(Color(1, 1, 1, life))
		_strip.surface_set_uv(Vector2(life, 1.0))
		_strip.surface_add_vertex(sample.tip)
	_strip.surface_end()
