class_name JourneyCheckpoint
extends RefCounted

const PATH := "user://journey.save"
const VERSION := 1

static func read() -> Dictionary:
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {}
	var value: Variant = file.get_var(false)
	if not value is Dictionary or value.get("version") != VERSION:
		return {}
	return value.get("journey", {}) if value.get("journey") is Dictionary else {}

static func write(journey: Dictionary) -> bool:
	var staging := PATH + ".tmp"
	var file := FileAccess.open(staging, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var({"version": VERSION, "journey": journey}, false)
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(staging),
		ProjectSettings.globalize_path(PATH)) == OK
