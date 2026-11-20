extends RefCounted
## Dress the surveyed footways with the starter kit's worn stone. The original ground remains the floor.

const DATA := preload("res://data/outer_valley/town_paths.json")
const STONE := preload("res://art/models/stone_block.glb")
const LIMESTONE := preload("res://art/materials/stylized/route_limestone.tres")
const MOSS := preload("res://art/materials/stylized/route_moss.tres")
const CACHE_IDS := {&"western_arcade": "western_arcade", &"bellmakers_steps": "east_terrace", &"mineral_ward": "mineral_spring"}

static func install(valley: Node3D, layout: CinderJourneyLayout) -> void:
	var source := STONE.instantiate()
	var stone: Mesh = source.find_children("*", "MeshInstance3D", true, false)[0].mesh
	source.free()
	for id: StringName in layout.TOWNS:
		var town: Node3D = valley.abandoned_towns.settlement_at(id)
		# The salt road can shift the Mineral Ward's cistern lot. The other town footprints are independent.
		var fork := int(layout.fork_variants[&"mineral_spring"]) if id == &"mineral_ward" else 0
		var key := "%d/%s/%d/%d" % [layout.layout_id, id, layout.town_variants[id], fork]
		var record: Dictionary = DATA.data[key]
		var local := PackedVector3Array()
		var path := PackedVector3Array()
		for xyz: Array in record.points:
			var point := Vector3(xyz[0], xyz[1], xyz[2])
			local.append(point)
			path.append(town.to_global(point))
		_dress(town, stone, local, MOSS if id == &"mineral_ward" else LIMESTONE)
		valley.town_side_paths[id] = path
		var cache_index: int = valley.cache_ids.find(CACHE_IDS[id])
		valley.caches[cache_index] = path[int(record.cache)]

static func _dress(town: Node3D, stone: Mesh, path: PackedVector3Array, material: Material) -> void:
	var tiles := MultiMesh.new()
	tiles.transform_format = MultiMesh.TRANSFORM_3D
	tiles.mesh = stone
	tiles.instance_count = (path.size() - 1) * 2
	for i in range(path.size() - 1):
		var direction := path[i].direction_to(path[i + 1])
		var right := Vector3.UP.cross(direction).normalized()
		var up := direction.cross(right)
		var along := path[i].distance_to(path[i + 1])
		for lane in 2:
			var offset := -.29 if lane == 0 else .29
			var stagger := .035 * sin(i * 2.3 + lane * 3.8)
			var center := path[i].lerp(path[i + 1], .5 + stagger) + right * offset + up * .025
			var basis := Basis(right * (.53 + stagger), up * .115, direction * along * 1.55)
			tiles.set_instance_transform(i * 2 + lane, Transform3D(basis, center))
	var street := MultiMeshInstance3D.new()
	street.name = "WornCourtPaving"
	street.multimesh = tiles
	street.material_override = material
	street.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	street.visibility_range_end = 70.0
	town.add_child(street)
