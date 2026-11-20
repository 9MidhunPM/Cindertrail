extends SceneTree
## From outside the checkout, run Godot with --headless --main-pack <Linux export>
## and --script <absolute path to this file>.

const EXPECTED := {
	&"exploration": ["exploration.ogg", "exploration_alt.ogg"],
	&"defense": ["defense.ogg", "defense_alt.ogg"],
	&"pursuit": ["pursuit.ogg"],
	&"vesper": ["vesper.ogg"],
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var failures := PackedStringArray()
	var score_script := load("res://scripts/game/journey_score.gd") as GDScript
	if score_script == null:
		push_error("The game pack did not load JourneyScore")
		quit(1)
		return
	var score: Node = score_script.new()
	root.add_child(score)
	var library: Dictionary = score.get("_library")
	for cue: StringName in EXPECTED:
		var names := PackedStringArray()
		for stream: AudioStreamOggVorbis in library.get(cue, []):
			if not stream.loop or stream.get_length() < 30.0:
				failures.append("Invalid music loop for %s" % cue)
			names.append(stream.resource_path.get_file())
			print("%s  %s  %.2fs" % [cue, stream.resource_path.get_file(), stream.get_length()])
		if names != PackedStringArray(EXPECTED[cue]):
			failures.append("Missing or incorrect packaged tracks for %s" % cue)
	for bus in [&"Music", &"Effects", &"Ambience"]:
		if AudioServer.get_bus_index(bus) < 0:
			failures.append("Missing audio bus %s" % bus)
	var foley_root := "res://art/audio/foley/"
	var takes := 0
	for directory in ResourceLoader.list_directory(foley_root):
		if not directory.ends_with("/"):
			continue
		for filename in ResourceLoader.list_directory(foley_root + directory):
			if filename.get_extension() != "wav" and filename.get_extension() != "ogg":
				continue
			if load(foley_root + directory + filename) is AudioStream:
				takes += 1
	if takes < 50:
		failures.append("Expected at least 50 recorded effect and ambience takes")
	print("Packed effects and ambience takes ", takes)
	var finale := load("res://art/audio/valley/last_sunrise.ogg") as AudioStreamOggVorbis
	if finale == null or absf(finale.get_length() - 26.0) > .1:
		failures.append("Missing timed sunrise music")
	if not FileAccess.get_file_as_string("res://art/audio/score/README.md").contains("Scott Buckley"):
		failures.append("Missing composer credits")
	if not FileAccess.get_file_as_string("res://art/audio/foley/README.md").contains("Kenney"):
		failures.append("Missing recording credits")
	score.free()
	for failure in failures:
		push_error(failure)
	print("Packed audio failures ", failures.size())
	quit(0 if failures.is_empty() else 1)
