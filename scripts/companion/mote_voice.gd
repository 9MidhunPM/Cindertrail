class_name CinderMoteVoice
extends Node
## Optional system speech for the same line that appears in Mote's subtitle.

const SPEECH_VOLUME := 72.0

var enabled := false:
	set(value):
		if enabled and not value:
			stop()
		enabled = value

var _voice := ""
var _checked_voices := false
var _issued_line := false


func available() -> bool:
	if not _checked_voices:
		_checked_voices = true
		if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH) and _has_system_service():
			var english := DisplayServer.tts_get_voices_for_language("en")
			if not english.is_empty():
				_voice = english[0]
	return not _voice.is_empty()


func say(text: String) -> void:
	if not enabled or text.strip_edges().is_empty():
		return
	var volume := roundi(SPEECH_VOLUME * _bus_gain(&"Master") * _bus_gain(&"Effects"))
	if volume <= 0 or not available():
		return
	# Some system synthesizers interpret SSML. Speak dialogue as plain text.
	var line := text.replace("<", " ").replace(">", " ").replace("&", " and ")
	DisplayServer.tts_speak(line, _voice, volume, 1.12, 1.05, 0, true)
	_issued_line = true


func stop() -> void:
	if _issued_line:
		DisplayServer.tts_stop()
		_issued_line = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		stop()


func _exit_tree() -> void:
	stop()


func _has_system_service() -> bool:
	if not OS.has_feature("linux") and not OS.has_feature("bsd"):
		return true
	# Avoid Speech Dispatcher's startup retry on systems that ship only its client library.
	var address := OS.get_environment("SPEECHD_ADDRESS")
	if not address.is_empty() and not address.begins_with("unix_socket"):
		return false
	var socket := address.trim_prefix("unix_socket:")
	if address.is_empty() or address == "unix_socket" or socket.is_empty():
		var runtime_dir := OS.get_environment("XDG_RUNTIME_DIR")
		socket = runtime_dir.path_join("speech-dispatcher/speechd.sock") if not runtime_dir.is_empty() else ""
	if socket.is_absolute_path():
		var directory := DirAccess.open(socket.get_base_dir())
		if directory != null and directory.file_exists(socket.get_file()):
			return true
	for directory in OS.get_environment("PATH").split(":", false):
		if directory.is_absolute_path() and FileAccess.file_exists(directory.path_join("speech-dispatcher")):
			return true
	return false


func _bus_gain(bus: StringName) -> float:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return 1.0
	if AudioServer.is_bus_mute(index):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(index)), 0.0, 1.0)
