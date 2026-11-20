class_name CinderWorldOverlay
extends Control
## Screen-space readouts pinned to the 3D world, drawn in one pass:
## creature health bars, rising damage numbers, edge arrows toward creatures
## that are hunting the shrine off screen, and a label over the hovered socket.

const ENEMY := Color("#ff6f5e")
const BAR_BACK := Color(0.03, 0.05, 0.07, 0.78)
const GOLD := Color("#ffce83")
const CREAM := Color("#f7e9c9")
const MUTED := Color("#a7bfc2")

var game: Node
var socket_text := ""
var socket_point := Vector3.INF
var socket_ok := true
var _numbers: Array[Dictionary] = []
var _font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = get_theme_default_font()

func bind(world: Node) -> void:
	game = world
	if not world.battle.damaged.is_connected(_on_damaged):
		world.battle.damaged.connect(_on_damaged)

func _on_damaged(point: Vector3, amount: float, source: StringName, fatal: bool) -> void:
	if source == &"tower" and not fatal:
		return
	_numbers.append({"point": point + Vector3(randf_range(-0.25, 0.25), 0.2, 0.0), "amount": amount,
		"age": 0.0, "heavy": amount >= 18.0, "fatal": fatal, "source": source})
	if _numbers.size() > 24:
		_numbers.pop_front()

func _process(delta: float) -> void:
	for number in _numbers:
		number.age += delta
	_numbers = _numbers.filter(func(n: Dictionary) -> bool: return n.age < 0.9)
	queue_redraw()

func _draw() -> void:
	if game == null or game.get("camera") == null or game.battle == null:
		return
	var view: Camera3D = game.camera
	var screen := get_viewport_rect().size
	var core_point: Vector3 = game.core.global_position
	for enemy: CinderEnemy in game.battle.enemies:
		if enemy.fading:
			continue
		var head := enemy.global_position + Vector3.UP * (enemy.stats.height + 0.45)
		var on_screen := not view.is_position_behind(head)
		var p := view.unproject_position(head) if on_screen else Vector2.ZERO
		if on_screen and Rect2(Vector2.ZERO, screen).has_point(p):
			var distance := view.global_position.distance_to(head)
			var wounded := enemy.health < enemy.stats.health - 0.01
			if distance < 34.0 and (wounded or distance < 16.0):
				var width := clampf(520.0 / distance, 22.0, 54.0) * (1.4 if enemy.stats.height >= 1.0 else 1.0)
				var frac := clampf(enemy.health / enemy.stats.health, 0.0, 1.0)
				var box := Rect2(p - Vector2(width * 0.5, 0), Vector2(width, 5))
				draw_rect(box.grow(1.5), BAR_BACK)
				draw_rect(Rect2(box.position, Vector2(width * frac, 5)), ENEMY.lerp(GOLD, 0.15))
		elif enemy.global_position.distance_to(core_point) < 26.0:
			_edge_arrow(view, enemy.global_position, screen)
	for number in _numbers:
		var anchor: Vector3 = number.point
		if view.is_position_behind(anchor):
			continue
		var t: float = number.age / 0.9
		var p := view.unproject_position(anchor) + Vector2(0, -38.0 * t)
		var size_px := 30 if number.heavy else 22
		var pop := 1.0 + 0.4 * (1.0 - smoothstep(0.0, 0.12, number.age))
		var tint: Color = GOLD if number.source == &"melee" else Color("#bfefff")
		if number.fatal:
			tint = Color("#ffffff")
		tint.a = 1.0 - smoothstep(0.55, 1.0, t)
		var text := str(roundi(number.amount))
		var font_size := roundi(size_px * pop)
		draw_string_outline(_font, p - Vector2(font_size * 0.3 * text.length(), 0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0.05, 0.03, 0.02, tint.a * 0.85))
		draw_string(_font, p - Vector2(font_size * 0.3 * text.length(), 0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)
	if not socket_text.is_empty() and socket_point != Vector3.INF and not view.is_position_behind(socket_point):
		var p := view.unproject_position(socket_point + Vector3.UP * 1.9)
		var width := _font.get_string_size(socket_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 22.0
		var box := Rect2(p - Vector2(width * 0.5, 30), Vector2(width, 28))
		draw_rect(box, Color(0.02, 0.06, 0.09, 0.92))
		draw_rect(box, GOLD if socket_ok else ENEMY, false, 1.5)
		draw_string(_font, box.position + Vector2(11, 20), socket_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17,
			CREAM if socket_ok else Color("#ffb3a8"))

func _edge_arrow(view: Camera3D, point: Vector3, screen: Vector2) -> void:
	var local := view.global_transform.affine_inverse() * point
	var direction := Vector2(local.x, -local.y)
	if local.z > 0.0:
		direction.y = absf(direction.y) + 0.001
	if direction.length_squared() < 0.0001:
		direction = Vector2.DOWN
	direction = direction.normalized()
	var center := screen * 0.5
	var margin := Vector2(48, 48)
	var half := center - margin
	var scale_to_edge := minf(half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001))
	var tip := center + direction * scale_to_edge
	var side := Vector2(-direction.y, direction.x)
	draw_colored_polygon(PackedVector2Array([tip + direction * 14.0, tip + side * 10.0, tip - side * 10.0]), Color(ENEMY, 0.9))
