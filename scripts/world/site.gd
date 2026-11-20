class_name CinderSite
extends Node3D

const BRONZE := preload("res://art/materials/stylized/painted_bronze.tres")
const BRASS := preload("res://art/materials/stylized/painted_brass.tres")

var spec: CinderSiteSpec
var anchor: Marker3D
var sockets: Array[Marker3D] = []
var lanes: Array[PackedVector3Array] = []
var threat := 0
var remaining_energy := 0.0
var checkpoint_id: StringName:
	get:
		return spec.id if spec.id != &"" else StringName(spec.label.to_snake_case())
var label: String:
	get:
		return spec.label
var lane_names: PackedStringArray:
	get:
		return spec.lane_names
var intensity: float:
	get:
		return spec.intensity
var view_position: Vector3
var view_target: Vector3
var wet := false
## Canonical district center used by wildlife and terrain hazards, independent of the shrine pad.
var habitat_frame := Transform3D.IDENTITY
var _socket_rings: Array[MeshInstance3D] = []
var _selection := StandardMaterial3D.new()

func configure(data: CinderSiteSpec, center: Vector3, positions: PackedVector3Array,
		routes: Array[PackedVector3Array], camera_eye: Vector3, camera_target: Vector3) -> void:
	spec = data
	habitat_frame.origin = center
	remaining_energy = spec.energy
	lanes = routes
	view_position = camera_eye
	view_target = camera_target
	anchor = Marker3D.new()
	anchor.position = center
	add_child(anchor)
	_selection.albedo_color = Color("#e7b96c")
	_selection.emission_enabled = true
	_selection.emission = Color("#df9c42")
	_selection.emission_energy_multiplier = 0.8
	for point in positions:
		var marker := Marker3D.new()
		marker.position = point
		add_child(marker)
		sockets.append(marker)
		var socket_ring := _ring(marker, 0.71, 0.79, 0.06, BRASS)
		_socket_rings.append(socket_ring)
		_ring(marker, 0.48, 0.72, 0.035, BRONZE)

## Move world-space data (attack lanes and the tactical camera) with a relocated parent.
func shift_world(shift: Vector3) -> void:
	transform_world(Transform3D(Basis.IDENTITY, shift))

func transform_world(placement: Transform3D) -> void:
	for i in lanes.size():
		lanes[i] = placement * lanes[i]
	view_position = placement * view_position
	view_target = placement * view_target
	habitat_frame = placement * habitat_frame

## Empty bronze-lined limestone footing for the portable shrine.
func mark_clearing() -> void:
	var stone := CylinderMesh.new()
	stone.top_radius = 1.29
	stone.bottom_radius = 1.38
	stone.height = .075
	stone.radial_segments = 12
	var plinth := MeshInstance3D.new()
	plinth.mesh = stone
	plinth.material_override = preload("res://art/materials/stylized/painted_stone_cream.tres")
	anchor.add_child(plinth)
	plinth.position.y = -.022
	_ring(anchor, .94, 1.03, .016, BRONZE)
	_ring(anchor, 1.13, 1.18, .017, BRASS)

func select_socket(index: int) -> void:
	for i in _socket_rings.size():
		_socket_rings[i].material_override = _selection if i == index else BRASS

func wet_depth_at(point: Vector3) -> bool:
	if not wet:
		return false
	var local := habitat_frame.affine_inverse() * point
	return local.y < -.53 and absf(local.x) < 19.0 and absf(local.z) < 19.0

func _ring(parent: Node3D, inner: float, outer: float, altitude: float,
		material: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 28
	mesh.ring_segments = 6
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.position.y = altitude
	parent.add_child(visual)
	return visual
