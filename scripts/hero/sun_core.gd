class_name SunCore
extends Node3D

signal destroyed
enum Form { CARRIED, DEPLOYED, DELIVERED }
const FRAMES: Array[PackedScene] = [
	preload("res://art/models/sun_shrine_folded.glb"),
	preload("res://art/models/sun_shrine_deployed.glb"),
	preload("res://art/models/sun_shrine_restored.glb")
]
const CENTER_HEIGHT: Array[float] = [.55, 1.08, 1.08]
const FOLDED_RADIUS := .34
const OPEN_RADIUS := .53

var health: float = 100.0
var restoration: float = 0.0
var form: int = Form.CARRIED
var _frame: Node3D
var _sun: MeshInstance3D
var _transfer_time: Tween
var _openness := 0.0
var _frame_band: MeshInstance3D
var _hinges: Array[MeshInstance3D] = []
var _feet: Array[Node3D] = []
var _base: Node3D
var _trim: Node3D
var _handle: Node3D
@onready var _visual: Node3D = $Visual
@onready var _focal: Node3D = $Visual/SunCenter
@onready var _orbits: Node3D = $Visual/OrbitCenter
@onready var _light: OmniLight3D = $Visual/SunCenter/Sunlight

func _ready() -> void:
	_show_form(form)

func _process(delta: float) -> void:
	_orbits.rotate_y(delta * (.47 if form == Form.DELIVERED else .2))

func damage(amount: float) -> void:
	if health <= 0.0 or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		destroyed.emit()

func repair(amount: float) -> void:
	if health > 0.0 and amount > 0.0:
		health = minf(100.0, health + amount)

func transfer(anchor: Node3D, new_form: int, duration: float = 0.0) -> void:
	if not is_instance_valid(anchor) or new_form < Form.CARRIED or new_form > Form.DELIVERED:
		return
	if not is_inside_tree() or not anchor.is_inside_tree():
		return
	if _transfer_time:
		_transfer_time.kill()
	if get_parent() != anchor:
		reparent(anchor, true)
	var end_pose := 0.0 if new_form == Form.CARRIED else 1.0
	if duration <= 0.0:
		transform = Transform3D.IDENTITY
		_show_form(new_form)
		_pose(end_pose)
		return
	_transfer_time = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transfer_time.tween_property(self, "position", Vector3.ZERO, duration)
	_transfer_time.parallel().tween_property(self, "quaternion", Quaternion.IDENTITY, duration)
	_transfer_time.parallel().tween_property(self, "scale", Vector3.ONE, duration)
	_transfer_time.parallel().tween_method(_pose, _openness, end_pose, duration)
	_transfer_time.parallel().tween_callback(_show_form.bind(new_form)).set_delay(duration * .62)

func _show_form(new_form: int) -> void:
	if form == new_form and is_instance_valid(_frame):
		return
	form = new_form
	if _frame:
		_frame.free()
	for ring in _orbits.get_children():
		ring.free()
	_frame = FRAMES[form].instantiate()
	_visual.add_child(_frame)
	var center := Vector3.UP * CENTER_HEIGHT[form]
	var baked := _frame.find_child("Sun*", true, false) as MeshInstance3D
	if not is_instance_valid(_sun):
		_sun = baked
		_sun.reparent(_focal, true)
		_sun.position = Vector3.ZERO
		var surface := ShaderMaterial.new()
		surface.shader = preload("res://scripts/hero/sun_surface.gdshader")
		_sun.material_override = surface
	else:
		baked.free()
	_focal.position = center
	var orbit_phase := _orbits.rotation.y
	_orbits.rotation.y = 0
	_orbits.scale = Vector3.ONE
	_orbits.position = center
	for ring in _frame.find_children("Orbit_ring*", "MeshInstance3D", true, false):
		ring.reparent(_orbits, true)
	_orbits.rotation.y = orbit_phase
	_hinges.clear()
	_feet.clear()
	for leg in _frame.find_children("Fold*leg*", "MeshInstance3D", true, false):
		_hinges.append(leg)
	for foot in _frame.find_children("Foot*", "Node3D", true, false):
		_feet.append(foot)
	_base = _frame.find_child("*base*", true, false)
	_trim = _frame.find_child("Shrine_trim*", true, false)
	_handle = _frame.find_child("Carry_handle", true, false)
	if form == Form.CARRIED:
		_frame_band = MeshInstance3D.new()
		var belt := TorusMesh.new()
		belt.inner_radius = .298
		belt.outer_radius = .371
		belt.rings = 18
		belt.ring_segments = 4
		belt.material = preload("res://art/materials/bronze.tres")
		_frame_band.mesh = belt
		_frame_band.scale.y = 1.45
		_frame.add_child(_frame_band)
	else:
		_frame_band = null
	_pose(_openness)

func _pose(openness: float) -> void:
	_openness = openness
	var folded := form == Form.CARRIED
	var center_y := lerpf(CENTER_HEIGHT[0], CENTER_HEIGHT[1], openness)
	var size := lerpf(.54, 1.32, openness)
	_visual.scale = Vector3(lerpf(.94, 1.0, openness), lerpf(1.06, 1.0, openness), 1.0) * size
	_sun.scale = Vector3.ONE * lerpf(.74, 1.0, openness)
	if _frame_band:
		_frame_band.position.y = center_y - .014
		_frame_band.scale.x = lerpf(1.0, 1.2, openness)
		_frame_band.scale.z = _frame_band.scale.x
	_focal.position.y = center_y
	_orbits.position.y = center_y
	var frame_radius := FOLDED_RADIUS if folded else OPEN_RADIUS
	_orbits.scale = Vector3.ONE * lerpf(FOLDED_RADIUS, OPEN_RADIUS, openness) / frame_radius
	_light.light_energy = lerpf(.66, 4.4, openness)
	_light.omni_range = lerpf(2.4, 9.0, openness)
	_base.position.y = lerpf(.15, .69, openness)
	var base_radius := .27 if folded else .40
	var width := lerpf(.27, .40, openness) / base_radius
	_base.scale = Vector3(width, 1.0, width)
	if _trim:
		_trim.position.y = _base.position.y + .09
		_trim.scale = Vector3(width, 1.0, width)
	if _handle:
		# The glTF handle is modeled away from its pivot at (0, .93, 0).
		_handle.position.y = center_y - CENTER_HEIGHT[0] - openness * .12
	var boom_length := lerpf(.57, .715, openness)
	var tilt := deg_to_rad(155.4) * openness
	for i in _hinges.size():
		var leg := _hinges[i]
		var radial := Vector3(cos(i * TAU / 3.0), 0, -sin(i * TAU / 3.0))
		var hinge := radial * lerpf(.29, .253, openness) + Vector3.UP * lerpf(.18, .72, openness)
		var direction := radial * sin(tilt) + Vector3.UP * cos(tilt)
		leg.position = hinge + direction * (boom_length * .5)
		leg.quaternion = Quaternion(Vector3.UP, direction.normalized())
		leg.scale.y = boom_length / leg.mesh.get_aabb().size.y
		if i < _feet.size():
			_feet[i].position = hinge + direction * boom_length - Vector3.UP * .02
			_feet[i].scale = Vector3.ONE * lerpf(.05, 1, openness)
