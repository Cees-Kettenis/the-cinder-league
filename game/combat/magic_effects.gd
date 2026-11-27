extends RefCounted
## Draws effects in arena space and builds weapon halos from the held sprite's alpha.

const Content = preload("res://game/catalog/content_catalog.gd")
const FORCE := Color("#ff9a39")
const TETHER := Color("#d99aff")
const ETCHING_COLORS := [Color("#ffad53"), Color("#ff6935"), Color("#ffe7a0")]
const ETCHING_HEAT := [Color("#ffc078"), Color("#ff9453"), Color("#ffe4a0")]
const HALO_EDGE := 160
const HALO_BLUR := 7
const HALO_PADDING := 12

static func ward(canvas: CanvasItem, center: Vector2, extent: float, alpha: float) -> void:
	# Stage has already applied the off-hand transform. The ward follows the shield through the pose.
	var texture: Texture2D = Content.MAGIC_ICONS.magic_shield
	var size := Vector2.ONE * extent
	canvas.draw_texture_rect(texture, Rect2(center - size * .58, size * 1.16), false, Color("#74cfff", alpha * .28))
	canvas.draw_texture_rect(texture, Rect2(center - size * .5, size), false, Color(Color.WHITE, alpha))

static func ward_break(canvas: CanvasItem, center: Vector2, height: float, facing: float, phase: float) -> void:
	var scatter := smoothstep(0.0, .70, phase)
	var alpha := 1.0 - scatter
	if alpha < .04:
		return
	ward(canvas, center, height * (.36 + scatter * .18), alpha * (1.0 - smoothstep(0.0, .18, phase)))
	for index in 6:
		var lift := (index - 2.5) * .062
		var shard := center + Vector2(facing * (.025 + .23 * scatter), lift * (1.0 + scatter)) * height
		var extent := Vector2(.022 * facing, .025) * height * alpha
		canvas.draw_colored_polygon(PackedVector2Array([shard - extent, shard + Vector2(extent.x, 0), shard + extent]),
			Color("#b1f1ff", alpha))

static func weapon_halo(texture: Texture2D, grip: Vector2, tip: Vector2) -> Dictionary:
	var image := texture.get_image()
	if image == null or (image.is_compressed() and image.decompress() != OK):
		return {}
	var sides := image.get_size()
	var scale := minf(1.0, float(HALO_EDGE) / maxi(sides.x, sides.y))
	var width := maxi(1, roundi(sides.x * scale))
	var height := maxi(1, roundi(sides.y * scale))
	image.convert(Image.FORMAT_RGBA8)
	image.resize(width, height, Image.INTERPOLATE_BILINEAR)
	var sprite := image.get_data()
	var stride := width + HALO_PADDING * 2
	var rows := height + HALO_PADDING * 2
	var silhouette := PackedFloat32Array()
	silhouette.resize(stride * rows)
	var marks := PackedByteArray()
	marks.resize(width * height * 4)
	var axis := (tip - grip) * scale
	var start := grip * scale
	var axis_size := axis.length()
	var along := axis.normalized() / maxf(1.0, axis_size)
	var across := along.orthogonal()
	for y in height:
		for x in width:
			var pixel := (y * width + x) * 4
			var alpha := sprite[pixel + 3]
			silhouette[(y + HALO_PADDING) * stride + x + HALO_PADDING] = alpha / 255.0
			if alpha == 0:
				continue
			# Clip the hot cuts to the same alpha as the weapon, including curved blades and hammer heads.
			var point := Vector2(x + .5, y + .5) - start
			var length := point.dot(along)
			var side := point.dot(across)
			var notch := absf(fposmod(length * 8.0 - absf(side) * 13.0, 1.0) - .5)
			var edge := smoothstep(.23, .35, length) * (1.0 - smoothstep(.92, 1.04, length))
			var center := 1.0 - smoothstep(.055, .16, absf(side))
			marks[pixel] = 255
			marks[pixel + 1] = 255
			marks[pixel + 2] = 255
			marks[pixel + 3] = roundi(alpha * edge * center * (1.0 - smoothstep(.10, .24, notch)))
	# Two short blur passes soften the alpha edge. The intact weapon is drawn on top.
	var horizontal := _blur_halo(silhouette, stride, rows, true)
	var halo := _blur_halo(horizontal, stride, rows, false)
	var pixels := PackedByteArray()
	pixels.resize(stride * rows * 4)
	for index in halo.size():
		var brightness := roundi(lerpf(140, 255, smoothstep(.025, .35, halo[index])))
		pixels[index * 4] = brightness
		pixels[index * 4 + 1] = brightness
		pixels[index * 4 + 2] = brightness
		pixels[index * 4 + 3] = roundi(255.0 * smoothstep(.002, .26, halo[index]))
	var mask := Image.create_from_data(stride, rows, false, Image.FORMAT_RGBA8, pixels)
	var runes := Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, marks)
	return {"texture": ImageTexture.create_from_image(mask), "runes": ImageTexture.create_from_image(runes),
		"padding": Vector2(HALO_PADDING, HALO_PADDING) / Vector2(width, height)}

static func _blur_halo(source: PackedFloat32Array, width: int, height: int, horizontal: bool) -> PackedFloat32Array:
	var blurred := PackedFloat32Array()
	blurred.resize(source.size())
	var step := 1 if horizontal else width
	var peak := HALO_BLUR + 1
	for y in range(HALO_BLUR, height - HALO_BLUR):
		for x in range(HALO_BLUR, width - HALO_BLUR):
			var index := y * width + x
			var sum := 0.0
			for offset in range(-HALO_BLUR, peak):
				sum += source[index + offset * step] * (peak - absi(offset))
			blurred[index] = sum / (peak * peak)
	return blurred

static func weapon_embers(canvas: CanvasItem, axis: Vector2, time: float, alpha: float, rank: int) -> void:
	var along := axis.length()
	var across := axis.orthogonal().normalized()
	var count := 3 + rank * 3
	var tint: Color = ETCHING_COLORS[rank - 1]
	for index in count:
		var age := fposmod(time * (.61 + rank * .16) + float(index) / count, 1.0)
		var side := -1.0 if index % 2 == 0 else 1.0
		var point := axis * lerpf(.25, 1.02, float(index) / (count - 1)) + across * along * side * (.028 + age * .075 * rank)
		var glow := sin(age * PI) * alpha
		canvas.draw_circle(point, along * (.016 + rank * .005), Color(tint, glow * .52), true, -1, true)
		canvas.draw_circle(point, along * (.007 + rank * .004), Color("#fff2cc", glow), true, -1, true)

static func burst(canvas: CanvasItem, center: Vector2, height: float, phase: float, color: Color) -> void:
	var alpha := 1.0 - phase
	for index in 10:
		var unit := Vector2.from_angle(index * TAU / 10.0)
		var inner := center + unit * height * (.12 + .19 * phase)
		var outer := inner + unit * height * .09 * alpha
		canvas.draw_line(inner, outer, Color(color, alpha), 2.5, true)

static func cast(canvas: CanvasItem, effect: String, hand: Vector2, target: Vector2,
		height: float, approach: float, recovery: float, facing: float, rank: int = 1) -> void:
	match effect:
		"push":
			var flight := smoothstep(.22, 1.0, approach)
			var alpha := smoothstep(.12, .52, approach) * (1.0 - smoothstep(.08, .74, recovery))
			var front := hand.lerp(target, flight)
			var extent := height * lerpf(.30, .74, flight)
			var wave: Texture2D = Content.MAGIC_ICONS.push
			_sprite(canvas, wave, front - Vector2(facing * extent * .20, 0), extent * .86, facing, alpha * .29)
			_sprite(canvas, wave, front, extent, facing, alpha, Vector2(.76, .50))
			if approach >= 1.0:
				burst(canvas, target, height, recovery, FORCE)
		"pull":
			var alpha := smoothstep(.15, .48, approach) * (1.0 - smoothstep(.39, .89, recovery))
			var end := hand.lerp(target, smoothstep(.18, .97, approach))
			# The hook is on the left in the source art. Anchor that end on the rival through the slide.
			var hook: Texture2D = Content.MAGIC_ICONS.pull
			var reach := hand.distance_to(end)
			var tail := end - Vector2(facing * minf(reach * .65, height * .36), 0)
			var line := PackedVector2Array()
			for index in 9:
				var t := index / 8.0
				var sag := sin(t * PI) * height * lerpf(.11, .018, approach)
				line.append(hand.lerp(tail, t) + Vector2(0, sag))
			canvas.draw_polyline(line, Color("#913cec", alpha * .52), maxf(2.0, height * .025), true)
			canvas.draw_polyline(line, Color(TETHER, alpha), maxf(1.0, height * .008), true)
			_sprite(canvas, hook, end, height * .70, -facing, alpha, Vector2(.25, .45))
		"enchant":
			var charge := smoothstep(.05, .44, approach)
			var merge := smoothstep(.32, 1.0, approach)
			var alpha := charge * (1.0 - smoothstep(.05, .58, recovery))
			var center := hand + Vector2(facing * .18, -.34) * height * (1.0 - merge)
			var sigil: Texture2D = Content.MAGIC_ICONS.ember_etching
			_sprite(canvas, sigil, center, height * lerpf(.55, .28, merge), facing, alpha)
			if approach >= 1.0:
				burst(canvas, hand, height * (.40 + rank * .12), recovery, ETCHING_COLORS[rank - 1])

static func _sprite(canvas: CanvasItem, texture: Texture2D, position: Vector2, extent: float, facing: float,
		alpha: float, anchor: Vector2 = Vector2(.5, .5)) -> void:
	if alpha <= .005:
		return
	var size := Vector2.ONE * extent
	canvas.draw_set_transform(position, 0.0, Vector2(facing, 1.0))
	canvas.draw_texture_rect(texture, Rect2(-size * anchor, size), false, Color(Color.WHITE, alpha))
	canvas.draw_set_transform(Vector2.ZERO)
