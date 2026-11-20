class_name CinderSite
extends Node3D

const BRONZE := preload("res://art/materials/bronze.tres")
const BRASS := preload("res://art/materials/brass.tres")

var spec: CinderSiteSpec
var anchor: Marker3D
var sockets: Array[Marker3D] = []
var lanes: Array[PackedVector3Array] = []
var threat := 0
var remaining_energy := 0.0
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
var _socket_rings: Array[MeshInstance3D] = []
var _selection := StandardMaterial3D.new()

func configure(data: CinderSiteSpec, center: Vector3, positions: PackedVector3Array,
		routes: Array[PackedVector3Array], camera_eye: Vector3, camera_target: Vector3) -> void:
	spec = data
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

func select_socket(index: int) -> void:
	for i in _socket_rings.size():
		_socket_rings[i].material_override = _selection if i == index else BRASS

func wet_depth_at(point: Vector3) -> bool:
	return wet and point.y < 0.20 and absf(point.x) < 19.0 and absf(point.z) < 19.0

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
