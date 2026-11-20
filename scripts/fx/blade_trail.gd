class_name CinderBladeTrail
extends MeshInstance3D
## Ribbon swept by the sunsteel blade. Samples the blade's base and tip every
## frame while the traveler swings, and fades the oldest sections first.

const LIFETIME := 0.16
const MAX_SECTIONS := 22

var source: TravelerVisual
var _samples: Array[Dictionary] = []
var _strip := ImmediateMesh.new()
var _sampling := false

func _ready() -> void:
	mesh = _strip
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://scripts/fx/blade_trail.gdshader")
	material_override = ink
	global_transform = Transform3D.IDENTITY

func _process(delta: float) -> void:
	for sample in _samples:
		sample.age += delta
	while not _samples.is_empty() and _samples[0].age > LIFETIME:
		_samples.pop_front()
	var active := source != null and source.trailing()
	if active:
		if not _sampling:
			_samples.clear()
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
		var life := 1.0 - float(sample.age) / LIFETIME
		_strip.surface_set_color(Color(1, 1, 1, life))
		_strip.surface_set_uv(Vector2(life, 0.0))
		_strip.surface_add_vertex(sample.base)
		_strip.surface_set_color(Color(1, 1, 1, life))
		_strip.surface_set_uv(Vector2(life, 1.0))
		_strip.surface_add_vertex(sample.tip)
	_strip.surface_end()
