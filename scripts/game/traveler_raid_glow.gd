extends Node
## A short, material-only highlight for the tactical camera.

const RIM := preload("res://scripts/fx/traveler_raid_rim.gdshader")
const PARTS := ["HoodGeometry", "MantleLGeometry", "MantleRGeometry",
	"CoatHemGeometry", "TailLGeometry", "TailRGeometry"]
const STRIKE_SECONDS := .18
const FADE_SECONDS := .15

var _parts: Array[MeshInstance3D] = []
var _rim := ShaderMaterial.new()
var _strength := 0.0
var _strike_left := 0.0
var _active := false
var _reduced_motion := false

func configure(visual: TravelerVisual) -> void:
	_rim.shader = RIM
	for label: String in PARTS:
		var piece := visual.find_child(label, true, false) as MeshInstance3D
		if piece != null:
			_parts.append(piece)
	visual.strike.connect(_on_strike)
	set_process(false)

func set_raid(active: bool, reduced_motion: bool) -> void:
	if _active == active and _reduced_motion == reduced_motion:
		return
	_active = active
	_reduced_motion = reduced_motion
	_strike_left = 0.0
	if _active:
		for piece in _parts:
			if piece.material_overlay == null:
				piece.material_overlay = _rim
	if reduced_motion:
		_strength = float(_active)
		_update_rim()
		if not _active:
			_remove_rim()
		set_process(false)
	elif _active or _strength > 0.0:
		set_process(true)
	else:
		_remove_rim()
		set_process(false)

func accent() -> void:
	if _active and not _reduced_motion:
		_strike_left = STRIKE_SECONDS
		set_process(true)

func _on_strike(_index: int) -> void:
	accent()

func _process(delta: float) -> void:
	_strength = move_toward(_strength, float(_active), delta / FADE_SECONDS)
	_strike_left = maxf(0.0, _strike_left - delta)
	_update_rim()
	if _strength == float(_active) and _strike_left <= 0.0:
		if not _active:
			_remove_rim()
		set_process(false)

func _update_rim() -> void:
	_rim.set_shader_parameter("strength", smoothstep(0.0, 1.0, _strength))
	var accent_weight := _strike_left / STRIKE_SECONDS
	_rim.set_shader_parameter("strike", accent_weight * accent_weight)

func _remove_rim() -> void:
	for piece in _parts:
		if is_instance_valid(piece) and piece.material_overlay == _rim:
			piece.material_overlay = null

func _exit_tree() -> void:
	_remove_rim()
