extends RefCounted
## Cloth and fire overlays shared by the town and the arenas.

const MESH_COLUMNS := 3
const MESH_ROWS := 5

var glow: GradientTexture2D

func _init() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, .45, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, .40), Color(1, 1, 1, 0)])
	glow = GradientTexture2D.new()
	glow.gradient = gradient
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(.5, .5)
	glow.fill_to = Vector2(1.0, .5)
	glow.width = 64
	glow.height = 64

func draw_banner(canvas: CanvasItem, painting: Texture2D, design_size: Vector2,
		box: Rect2, time: float, strength: float = 1.0) -> void:
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var stride := MESH_COLUMNS + 1
	# Only the interior moves. Stationary outer vertices avoid seams in the baked painting.
	for row in MESH_ROWS + 1:
		var v := float(row) / MESH_ROWS
		for col in stride:
			var u := float(col) / MESH_COLUMNS
			var base := box.position + box.size * Vector2(u, v)
			var weight := sin(u * PI) * sin(v * PI)
			var wind := sin(time * 2.0 - v * 7.0 + u * 1.9)
			var shift := Vector2(wind * minf(6.0, box.size.x * .12), sin(time * 1.8 + u * 3.7) * 1.8) * weight
			var shade := 1.0 - (1.0 + wind) * .085 * weight
			points.append(base + shift * strength)
			uv.append(base / design_size)
			colors.append(Color(shade, shade, shade))
	_draw_cloth_mesh(canvas, painting, points, uv, colors, stride)

func draw_drape(canvas: CanvasItem, painting: Texture2D, design_size: Vector2,
		folds: PackedVector3Array, time: float) -> void:
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var left := folds[0].x
	var width := folds[-1].x - left
	for row in MESH_ROWS + 1:
		var v := float(row) / MESH_ROWS
		for fold in folds:
			var u := (fold.x - left) / width
			var base := Vector2(fold.x, lerpf(fold.y, fold.z, v))
			# The pinned ends and the contour stay fixed while the folds inside rise and settle.
			var weight := pow(sin(u * PI) * sin(v * PI), 2.0)
			var wind := sin(time * 2.1 - u * 4.7 - v * 1.2)
			var shade := 1.0 - (1.0 + wind) * .022 * weight
			points.append(base + Vector2(.45, 1.8) * wind * weight)
			uv.append(base / design_size)
			colors.append(Color(shade, shade, shade))
	_draw_cloth_mesh(canvas, painting, points, uv, colors, folds.size())

func _draw_cloth_mesh(canvas: CanvasItem, painting: Texture2D, points: PackedVector2Array,
		uv: PackedVector2Array, colors: PackedColorArray, stride: int) -> void:
	for row in MESH_ROWS:
		for col in stride - 1:
			var a := row * stride + col
			var b := a + 1
			var c := a + stride
			var d := c + 1
			canvas.draw_primitive(PackedVector2Array([points[a], points[b], points[d], points[c]]),
				PackedColorArray([colors[a], colors[b], colors[d], colors[c]]),
				PackedVector2Array([uv[a], uv[b], uv[d], uv[c]]), painting)

func draw_fire(canvas: CanvasItem, box: Rect2, time: float, forge: bool = false,
		intensity: float = 1.0) -> void:
	var hearth := box.position + box.size * Vector2(.53, .92)
	var flicker := .70 + .17 * sin(time * 10.7) + .13 * sin(time * 17.3)
	var light_size := box.size * Vector2(1.22, 1.36)
	canvas.draw_texture_rect(glow, Rect2(hearth - light_size * Vector2(.5, .78), light_size),
		false, Color("#ffac4e", .20 * flicker * intensity))
	var tongues := 5 if forge else 3
	for index in tongues:
		var phase := fposmod(time * (1.35 + index * .17) + index * .381, 1.0)
		var alpha := smoothstep(0.0, .18, phase) * (1.0 - smoothstep(.52, 1.0, phase))
		var offset := float(index) / (tongues - 1) - .5
		var root := hearth + Vector2(offset * box.size.x * .56, -float(index % 2) * box.size.y * .048)
		var length := box.size.y * lerpf(.24, .83, phase) * (1.0 - absf(offset) * .49)
		var width := box.size.x * (.14 if forge else .21) * (1.0 - phase * .34)
		_draw_flame_tongue(canvas, root, length, width, time * 6.2 + index * 2.17, alpha * intensity)
	for index in (5 if forge else 2):
		var phase := fposmod(time * (.59 + index * .073) + index * .393, 1.0)
		var alpha := smoothstep(.10, .24, phase) * (1.0 - smoothstep(.60, 1.0, phase))
		var drift := sin(index * 2.5 + time * 1.6) * box.size.x * (.09 + .14 * phase)
		var point := hearth + Vector2(drift, -box.size.y * (.35 + .88 * phase))
		canvas.draw_circle(point, lerpf(1.14, .45, phase), Color("#ffc267", alpha * .74 * intensity), true)

func _draw_flame_tongue(canvas: CanvasItem, root: Vector2, height: float, width: float, time: float, alpha: float) -> void:
	var past := root
	var past_width := width * .35
	var past_core := Color("#ffce62", .55 * alpha)
	var rim := Color("#fd6432", 0.0)
	# Soft edges and a taper keep the flame attached to the same ember bed as it rises.
	for segment in range(1, 7):
		var t := float(segment) / 6.0
		var drift := sin(time - t * 4.7) * width * .70 * t
		var center := root + Vector2(drift, -height * t)
		var spread := width * (.35 + .65 * sin(t * PI)) * (1.0 - t)
		var core := Color(Color("#ffed9a").lerp(Color("#ff7026"), t), alpha * .69 * (1.0 - t * t))
		canvas.draw_primitive(PackedVector2Array([past - Vector2(past_width, 0), past, center, center - Vector2(spread, 0)]),
			PackedColorArray([rim, past_core, core, rim]), PackedVector2Array())
		canvas.draw_primitive(PackedVector2Array([past, past + Vector2(past_width, 0), center + Vector2(spread, 0), center]),
			PackedColorArray([past_core, rim, rim, core]), PackedVector2Array())
		past = center
		past_width = spread
		past_core = core
