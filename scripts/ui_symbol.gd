extends Control

const INK := Color("#291e24")
const CREAM := Color("#ffebba")
const STEEL := Color("#bcdff2")
const GOLD := Color("#ffcc58")
const RED := Color("#f57a75")
const MINT := Color("#91dfab")
const LILAC := Color("#ceb1ff")

var symbol := ""

static func make(key: String, pixels: int) -> Control:
	var icon := new()
	icon.symbol = key
	icon.custom_minimum_size = Vector2.ONE * pixels
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	return icon

static func on_button(button: Button, key: String, pixels: int, description: String) -> void:
	var icon := make(key, pixels)
	button.add_child(icon)
	icon.set_anchors_preset(PRESET_CENTER)
	icon.offset_left = -pixels * .5
	icon.offset_top = -pixels * .5
	icon.offset_right = pixels * .5
	icon.offset_bottom = pixels * .5
	button.tooltip_text = description
	button.accessibility_name = description

func _draw() -> void:
	var extent := minf(size.x, size.y)
	paint(self, symbol, (size - Vector2.ONE * extent) * .5, extent)

static func paint(canvas: CanvasItem, key: String, origin: Vector2, extent: float) -> void:
	canvas.draw_set_transform(origin, 0, Vector2.ONE * extent / 32.0)
	match key:
		"attack", "strength":
			_shape(canvas, [Vector2(10,17), Vector2(23,4), Vector2(29,3), Vector2(28,10), Vector2(15,23)], STEEL)
			_line(canvas, [Vector2(15,18), Vector2(25,8)], CREAM, 1.5)
			_shape(canvas, [Vector2(5,14), Vector2(18,26), Vector2(15,29), Vector2(2,17)], GOLD)
			_line(canvas, [Vector2(10,23), Vector2(4,29)], INK, 6)
			_line(canvas, [Vector2(10,23), Vector2(4,29)], Color("#c88465"), 3)
		"guard", "armor", "shield":
			_shape(canvas, [Vector2(16,3), Vector2(27,7), Vector2(26,18), Vector2(22,25), Vector2(16,30), Vector2(10,25), Vector2(6,18), Vector2(5,7)], STEEL)
			_shape(canvas, [Vector2(16,7), Vector2(23,10), Vector2(22,18), Vector2(16,25)], Color("#6383af"), false)
			_dot(canvas, Vector2(16,14), 3.2, CREAM)
		"health":
			_shape(canvas, [Vector2(16,29), Vector2(5,20), Vector2(2,13), Vector2(4,7), Vector2(9,5), Vector2(13,6), Vector2(16,10), Vector2(19,6), Vector2(23,5), Vector2(28,7), Vector2(30,13), Vector2(27,20)], RED)
			_line(canvas, [Vector2(7,13), Vector2(8,10), Vector2(11,9)], CREAM, 2)
		"stamina":
			_shape(canvas, [Vector2(16,2), Vector2(27,2), Vector2(20,13), Vector2(28,13), Vector2(10,30), Vector2(13,19), Vector2(5,19)], GOLD)
		"cast", "critical":
			_star(canvas, Vector2(21,10), 9, LILAC)
			_star(canvas, Vector2(8,8), 4, CREAM)
			_star(canvas, Vector2(25,24), 5, STEEL)
			_line(canvas, [Vector2(5,28), Vector2(17,15)], INK, 6)
			_line(canvas, [Vector2(5,28), Vector2(17,15)], CREAM, 3)
		"advance", "retreat", "jump":
			var route: Array[Vector2] = [Vector2(5,16), Vector2(25,16)]
			if key == "jump":
				route = [Vector2(5,25), Vector2(10,15), Vector2(18,9), Vector2(26,8)]
			elif key == "retreat":
				route.reverse()
			var tip: Vector2 = route.back()
			var direction := (tip - route[route.size() - 2]).normalized()
			var tail := tip - direction * 8
			var arrow := [tail + direction.orthogonal() * 7, tip, tail - direction.orthogonal() * 7]
			_line(canvas, route, INK, 8)
			_line(canvas, arrow, INK, 8)
			_line(canvas, route, GOLD, 4)
			_line(canvas, arrow, GOLD, 4)
		"sleep":
			_shape(canvas, [Vector2(18,4), Vector2(14,10), Vector2(14,17), Vector2(20,22), Vector2(26,22), Vector2(28,20), Vector2(25,26), Vector2(20,29), Vector2(12,29), Vector2(6,25), Vector2(3,18), Vector2(5,11), Vector2(10,6)], LILAC)
			_star(canvas, Vector2(25,9), 4, CREAM)
		"taunt":
			_shape(canvas, [Vector2(4,5), Vector2(28,5), Vector2(30,9), Vector2(30,21), Vector2(26,24), Vector2(16,24), Vector2(8,29), Vector2(9,24), Vector2(4,24), Vector2(2,20), Vector2(2,9)], GOLD)
			_line(canvas, [Vector2(16,10), Vector2(16,15)], INK, 3)
			canvas.draw_circle(Vector2(16,19), 1.5, INK)
		"potion":
			_shape(canvas, [Vector2(11,4), Vector2(21,4), Vector2(21,12), Vector2(26,17), Vector2(27,24), Vector2(23,28), Vector2(9,28), Vector2(5,24), Vector2(6,17), Vector2(11,12)], STEEL)
			_shape(canvas, [Vector2(8,20), Vector2(24,20), Vector2(24,25), Vector2(21,27), Vector2(11,27), Vector2(8,25)], RED, false)
			_line(canvas, [Vector2(12,6), Vector2(20,6)], GOLD, 4)
		"settings":
			var teeth := PackedVector2Array()
			for index in 32:
				var angle := index * TAU / 32.0
				var radius := 14.0 if index % 4 in [1, 2] else 10.8
				teeth.append(Vector2(16,16) + Vector2.from_angle(angle) * radius)
			_shape(canvas, teeth, GOLD)
			_dot(canvas, Vector2(16,16), 4.8, INK)
		"coin", "xp":
			_dot(canvas, Vector2(16,16), 12, GOLD if key == "coin" else LILAC)
			_star(canvas, Vector2(16,16), 6, CREAM)
		"trophy":
			_line(canvas, [Vector2(8,7), Vector2(3,7), Vector2(4,14), Vector2(9,17)], GOLD, 3)
			_line(canvas, [Vector2(24,7), Vector2(29,7), Vector2(28,14), Vector2(23,17)], GOLD, 3)
			_shape(canvas, [Vector2(7,4), Vector2(25,4), Vector2(23,16), Vector2(19,20), Vector2(19,25), Vector2(23,25), Vector2(23,29), Vector2(9,29), Vector2(9,25), Vector2(13,25), Vector2(13,20), Vector2(9,16)], GOLD)
		"home":
			_shape(canvas, [Vector2(2,15), Vector2(16,3), Vector2(30,15), Vector2(26,15), Vector2(26,29), Vector2(20,29), Vector2(20,20), Vector2(12,20), Vector2(12,29), Vector2(6,29), Vector2(6,15)], GOLD)
		"lock":
			_line(canvas, [Vector2(10,15), Vector2(10,7), Vector2(13,4), Vector2(19,4), Vector2(22,7), Vector2(22,15)], STEEL, 3)
			_shape(canvas, [Vector2(6,13), Vector2(26,13), Vector2(26,28), Vector2(6,28)], GOLD)
			_dot(canvas, Vector2(16,20), 2.3, INK)
		"helmet":
			_shape(canvas, [Vector2(4,24), Vector2(4,13), Vector2(8,6), Vector2(16,3), Vector2(24,6), Vector2(28,13), Vector2(28,24), Vector2(21,28), Vector2(21,17), Vector2(11,17), Vector2(11,28)], STEEL)
		"chest":
			_shape(canvas, [Vector2(4,5), Vector2(11,3), Vector2(16,8), Vector2(21,3), Vector2(28,5), Vector2(30,13), Vector2(25,15), Vector2(24,28), Vector2(8,28), Vector2(7,15), Vector2(2,13)], STEEL)
		"pants":
			_shape(canvas, [Vector2(6,4), Vector2(26,4), Vector2(28,28), Vector2(19,29), Vector2(16,15), Vector2(13,29), Vector2(4,28)], STEEL)
		"shoes":
			_shape(canvas, [Vector2(5,5), Vector2(17,5), Vector2(18,18), Vector2(27,21), Vector2(30,26), Vector2(28,29), Vector2(4,29)], GOLD)
		"play":
			_shape(canvas, [Vector2(9,4), Vector2(27,16), Vector2(9,28)], MINT)
		"check":
			_line(canvas, [Vector2(5,17), Vector2(12,24), Vector2(27,8)], INK, 8)
			_line(canvas, [Vector2(5,17), Vector2(12,24), Vector2(27,8)], MINT, 4)
		"miss":
			_line(canvas, [Vector2(5,7), Vector2(13,15), Vector2(24,15), Vector2(29,11)], STEEL, 4)
			_line(canvas, [Vector2(6,24), Vector2(24,24)], CREAM, 2)
	canvas.draw_set_transform(Vector2.ZERO)

static func _shape(canvas: CanvasItem, points: PackedVector2Array, color: Color, outline: bool = true) -> void:
	canvas.draw_colored_polygon(points, color)
	if outline:
		points.append(points[0])
		_line(canvas, points, INK, 2.1)

static func _line(canvas: CanvasItem, points: PackedVector2Array, color: Color, width: float) -> void:
	canvas.draw_polyline(points, color, width, true)
	for point in points:
		canvas.draw_circle(point, width * .5, color, true, -1, true)

static func _dot(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_circle(center, radius, INK, true, -1, true)
	canvas.draw_circle(center, radius - 1.4, color, true, -1, true)

static func _star(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 8:
		var angle := index * TAU / 8.0
		points.append(center + Vector2.from_angle(angle) * radius * (1.0 if index % 2 == 0 else .34))
	_shape(canvas, points, color)
