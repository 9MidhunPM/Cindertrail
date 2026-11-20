class_name CinderWaymark
extends Node3D

const STONE := preload("res://art/materials/stylized/route_limestone.tres")
const BRONZE := preload("res://art/materials/stylized/route_bronze.tres")
const BRASS := preload("res://art/materials/stylized/route_brass.tres")

static var _waymark_mesh: ArrayMesh

func set_destination(label: String, direction: Vector3) -> void:
	if _waymark_mesh == null:
		_waymark_mesh = _build_waymark()
	var marker := MeshInstance3D.new()
	marker.mesh = _waymark_mesh
	add_child(marker)
	rotation.y = atan2(-direction.x, -direction.z)
	var named := Label3D.new()
	named.text = label
	named.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	named.font_size = 52
	named.pixel_size = 0.0054
	named.outline_size = 9
	named.modulate = Color("#e9d3a4")
	named.outline_modulate = Color("#102031")
	named.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	named.visibility_range_end = 12.0
	named.position.y = 1.48
	add_child(named)

static func _build_waymark() -> ArrayMesh:
	var marker := ArrayMesh.new()
	var stone := SurfaceTool.new()
	stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	_collar(stone, 0.32, 0.40, 0.20, 0.073)
	_collar(stone, 0.25, 0.30, 0.13, 0.225)
	_collar(stone, 0.17, 0.22, 0.53, 0.535)
	_collar(stone, 0.20, 0.17, 0.10, 0.825)
	stone.set_material(STONE)
	stone.commit(marker)

	var metal := SurfaceTool.new()
	metal.begin(Mesh.PRIMITIVE_TRIANGLES)
	_collar(metal, 0.20, 0.20, 0.07, 0.285)
	_collar(metal, 0.22, 0.22, 0.08, 0.88)
	_block(metal, Vector3(0.48, 0.07, 0.18), Vector3(0.0, 1.11, 0.0))
	_block(metal, Vector3(0.21, 0.07, 0.19), Vector3(0.0, 0.91, 0.0))
	for x in [-0.08, 0.08]:
		for z in [-0.07, 0.07]:
			_block(metal, Vector3(0.024, 0.17, 0.023), Vector3(x, 1.01, z))
	for x in [-0.16, 0.16]:
		_block(metal, Vector3(0.082, 0.10, 0.15), Vector3(x, 0.985, 0.0))
	metal.set_material(BRONZE)
	metal.commit(marker)

	var brass := SurfaceTool.new()
	brass.begin(Mesh.PRIMITIVE_TRIANGLES)
	_block(brass, Vector3(0.106, 0.036, 0.33), Vector3(0.0, 1.16, 0.066))
	var arrowhead := PrismMesh.new()
	arrowhead.size = Vector3(0.30, 0.26, 0.060)
	brass.append_from(arrowhead, 0, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.0, 1.165, -0.182)))
	brass.set_material(BRASS)
	brass.commit(marker)

	var lamp := SurfaceTool.new()
	lamp.begin(Mesh.PRIMITIVE_TRIANGLES)
	_collar(lamp, 0.047, 0.078, 0.14, 1.01)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("#f3b258")
	glass.emission_enabled = true
	glass.emission = Color("#ffc059")
	glass.emission_energy_multiplier = 1.3
	glass.roughness = 0.70
	lamp.set_material(glass)
	lamp.commit(marker)
	return marker

static func _collar(surface: SurfaceTool, top: float, bottom: float, height: float, center_y: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	surface.append_from(mesh, 0, Transform3D(Basis(Vector3.UP, PI / 8.0), Vector3.UP * center_y))

static func _block(surface: SurfaceTool, size: Vector3, center: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	surface.append_from(mesh, 0, Transform3D(Basis.IDENTITY, center))
