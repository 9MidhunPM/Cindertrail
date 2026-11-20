extends RefCounted
## Profile-wide records of the seven recovered arts. Journey resets leave this file alone.
const SPEC := preload("res://scripts/game/traveler_art_spec.gd")
const ARTS: Array[SPEC] = [
	preload("res://data/abilities/flooded_grove.tres"), preload("res://data/abilities/broken_quarry.tres"),
	preload("res://data/abilities/fallen_relay.tres"), preload("res://data/abilities/lanternwood.tres"),
	preload("res://data/abilities/sunken_aqueduct.tres"), preload("res://data/abilities/sunwatch.tres"),
	preload("res://data/abilities/last_lantern_frontier.tres"),
]
var path: String

func _init(profile_path := "user://art_achievements.cfg") -> void:
	path = profile_path

func _read() -> ConfigFile:
	var profile := ConfigFile.new()
	if FileAccess.file_exists(path) and profile.load(path) != OK:
		push_warning("Could not read the traveler achievement profile.")
	return profile

func record(specs: Array[SPEC]) -> bool:
	var profile := _read()
	var changed := false
	for spec in specs:
		if not profile.get_value("learned", spec.site, false):
			profile.set_value("learned", spec.site, true)
			changed = true
	if not changed:
		return false
	if profile.save(path + ".tmp") == OK and DirAccess.rename_absolute(
			ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK:
		return true
	push_warning("Could not save the traveler achievement profile.")
	return false

func rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var profile := _read()
	for spec in ARTS:
		var place := "Last Lantern" if spec.site == &"last_lantern_frontier" else String(spec.site).capitalize()
		var learned: bool = profile.get_value("learned", spec.site, false) == true
		result.append({"id": spec.site, "name": spec.title, "title": spec.title, "description": "Draw all the light from %s to recover %s." % [place, spec.title],
			"icon": spec.icon, "earned": learned, "unlocked": learned})
	return result
