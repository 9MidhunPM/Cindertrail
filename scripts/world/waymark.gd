class_name CinderWaymark
extends Node3D

const STONE := preload("res://art/materials/stone_shadow.tres")
const GOLD := preload("res://art/materials/brass.tres")

func set_destination(label: String, direction: Vector3) -> void:
	var base := CylinderMesh.new()
	base.top_radius = 0.26
	base.bottom_radius = 0.39
	base.height = 0.94
	base.radial_segments = 6
	var marker := MeshInstance3D.new()
	marker.mesh = base
	marker.material_override = STONE
	marker.position.y = 0.45
	add_child(marker)
	var tip := PrismMesh.new()
	tip.size = Vector3(0.62, 0.26, 0.35)
	var arrow := MeshInstance3D.new()
	arrow.mesh = tip
	arrow.material_override = GOLD
	arrow.rotate_x(-PI * 0.5)
	marker.add_child(arrow)
	arrow.position.y = 0.55
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
