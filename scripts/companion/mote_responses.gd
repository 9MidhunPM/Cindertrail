extends RefCounted
## Native Responses API payload and local launch settings.

const URL := "https://api.openai.com/v1/responses"
const MODEL := "gpt-6-luna"
const MAX_REPLY_LENGTH := 280
const INSTRUCTIONS := """You're Mote, a tiny moth fairy flying beside the traveler in Cindertrail. You are curious, quick-witted, and fiercely attached to this little sun. Speak to the traveler in plain text, in one or two short sentences. For trail chatter, react to the change in front of you. Offer a concrete next move, acknowledge progress, or share a small observation when things are quiet. Sound like a friend on the trail, with the occasional dry aside. Vary how you start, and don't paraphrase your previous line. When asked a direct question, answer it first. Use only the supplied gameplay facts and local advice for destinations, controls, and progress. Never give directions or claim the player did something you cannot verify. Stay within 250 characters."""
const WORDS := ["mode", "region", "site", "objective", "guardian_action", "ability_name", "ability_description"]
const NUMBERS := ["health", "restoration", "energy", "threat", "objective_distance", "wave_left", "ability_cooldown", "pursuers"]
const FLAGS := ["at_summit", "guardian_cleared", "wave_active"]
const SETTINGS := ["OPENAI_API_KEY", "CINDERTRAIL_GUIDE_ONLINE", "CINDERTRAIL_GUIDE_VOICE"]


static func configuration() -> Dictionary:
	if OS.has_feature("web"):
		return {}
	var path := ProjectSettings.globalize_path("res://.env")
	if OS.has_feature("template"):
		path = OS.get_executable_path().get_base_dir().path_join(".env")
	var settings := {}
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null and file.get_length() <= 16384:
			for line in file.get_as_text().split("\n", false):
				var pair := line.split("=", true, 1)
				var name := pair[0].strip_edges() if pair.size() == 2 else ""
				if name in SETTINGS:
					var value := pair[1].strip_edges()
					if value.length() >= 2 and value[0] in ["'", "\""] and value.ends_with(value[0]):
						value = value.substr(1, value.length() - 2)
					settings[name] = value
	var local_default := "1" if _valid_key(settings.get("OPENAI_API_KEY", "")) else "0"
	for name in SETTINGS:
		if OS.has_environment(name):
			settings[name] = OS.get_environment(name).strip_edges()
	var key: String = settings.get("OPENAI_API_KEY", "")
	var has_key := _valid_key(key)
	return {
		"key": key if has_key else "",
		"automatic": settings.get("CINDERTRAIL_GUIDE_ONLINE", local_default) == "1",
		"voice": settings.get("CINDERTRAIL_GUIDE_VOICE", "1") == "1",
	}


static func body(question: String, context: Dictionary, local_advice: String, change := "", previous_line := "") -> String:
	var state := {}
	for key in WORDS:
		if context.has(key):
			state[key] = _single_line(str(context[key])).left(160)
	for key in NUMBERS:
		var value: Variant = context.get(key)
		if (value is float or value is int) and is_finite(float(value)):
			state[key] = snappedf(float(value), 0.1)
	for key in FLAGS:
		if context.has(key):
			state[key] = bool(context[key])
	var landmark: Variant = context.get("landmark")
	if landmark is Dictionary:
		state["landmark"] = {
			"title": _single_line(str(landmark.get("title", ""))).left(100),
			"detail": _single_line(str(landmark.get("detail", ""))).left(160),
		}
	var input := {"game_state": state, "local_advice": _single_line(local_advice).left(MAX_REPLY_LENGTH)}
	if change.is_empty():
		input["question"] = _single_line(question).left(400)
	else:
		input["trail_chatter"] = _single_line(change).left(200)
		input["last_chatter"] = _single_line(previous_line).left(MAX_REPLY_LENGTH)
	return JSON.stringify({
		"model": MODEL,
		"instructions": INSTRUCTIONS,
		"reasoning": {"effort": "none"},
		"max_output_tokens": 160,
		"store": false,
		"input": JSON.stringify(input),
	})


static func answer(data: PackedByteArray) -> String:
	var parsed: Variant = JSON.parse_string(data.get_string_from_utf8())
	if not parsed is Dictionary or parsed.get("status") != "completed":
		return ""
	var output: Variant = parsed.get("output")
	if not output is Array:
		return ""
	var lines := PackedStringArray()
	for item in output:
		if not item is Dictionary or item.get("type") != "message" or item.get("role") != "assistant":
			continue
		var content: Variant = item.get("content")
		if not content is Array:
			continue
		for part in content:
			if part is Dictionary and part.get("type") == "output_text" and part.get("text") is String:
				lines.append(part.text)
	var text := _single_line(" ".join(lines))
	if text.length() > MAX_REPLY_LENGTH:
		var clipped := text.left(MAX_REPLY_LENGTH - 1)
		var space := clipped.rfind(" ")
		text = (clipped.left(space) if space > 0 else clipped) + "…"
	return text


static func _single_line(text: String) -> String:
	return " ".join(text.replace("\r", " ").replace("\n", " ").replace("\t", " ").split(" ", false))


static func _valid_key(key: String) -> bool:
	if key.is_empty() or key.length() > 512:
		return false
	for index in key.length():
		var code := key.unicode_at(index)
		if code < 33 or code > 126:
			return false
	return true
