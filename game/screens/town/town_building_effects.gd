extends RefCounted
## Animated details anchored to the storefronts and hillside in the town painting.

const Armor = preload("res://game/combat/armor_art.gd")
const LANTERN := Vector2(1147, 422)
const CHIMNEY := Vector2(866, 292)
# The two casements share the center mullion of the large upstairs Armory window.
const ARMORY_LEFT_SASH := [Vector2(464, 340), Vector2(464, 278), Vector2(467, 270), Vector2(473, 264),
	Vector2(483, 261), Vector2(483, 344)]
const ARMORY_RIGHT_SASH := [Vector2(483, 261), Vector2(491, 263), Vector2(498, 267), Vector2(503, 274),
	Vector2(507, 283), Vector2(507, 348), Vector2(483, 344)]
const ARMORY_WALL_SAMPLE := Rect2(531, 283, 20, 69)
const TOSS_ORIGIN := Vector2(484, 313)
const TOSS_RELEASE := .48
const TOSS_LANDING := 1.68
const TOSS_SETTLED := 2.22
const TOSS_GONE := 3.32
const WINDOW_CLOSED := 3.82
const HILL_WINDOW := Vector2(595, 146)
const HILL_DROP_TIME := .94

var _rng: RandomNumberGenerator
var _glow: GradientTexture2D
var _armor_items: Array[Dictionary] = []
var _toss_texture: Texture2D
var _toss_start: float
var _toss_ground: Vector2
var _toss_turn: float
var _hill_start: float
var _hill_drift: float

func _init(data: RefCounted, armor_ids: Dictionary, rng: RandomNumberGenerator, glow: GradientTexture2D) -> void:
	_rng = rng
	_glow = glow
	for slot in ["helmet", "shield"]:
		for id in armor_ids.get(slot, []):
			_armor_items.append(data.items[id])
	_schedule_toss(_rng.randf_range(5.5, 9.5))
	_schedule_drop(_rng.randf_range(11.0, 17.0))

func advance(now: float) -> void:
	if now > _toss_start + WINDOW_CLOSED:
		_schedule_toss(now + _rng.randf_range(19.0, 34.0))
	if now > _hill_start + HILL_DROP_TIME:
		_schedule_drop(now + _rng.randf_range(23.0, 41.0))

func _schedule_toss(start: float) -> void:
	_toss_start = start
	if _armor_items.is_empty():
		return
	var item := _armor_items[_rng.randi_range(0, _armor_items.size() - 1)]
	_toss_texture = Armor.equipped(item).get("texture")
	_toss_ground = Vector2(_rng.randf_range(367.0, 425.0), _rng.randf_range(720.0, 744.0))
	_toss_turn = _rng.randf_range(1.02, 1.26) * TAU

func _schedule_drop(start: float) -> void:
	_hill_start = start
	_hill_drift = _rng.randf_range(13.0, 22.0)

func draw(canvas: CanvasItem, painting: Texture2D, design_size: Vector2, visible: Rect2, now: float) -> void:
	if visible.grow(48.0).has_point(LANTERN):
		_draw_lantern(canvas, now)
	if visible.intersects(Rect2(CHIMNEY - Vector2(26, 100), Vector2(123, 116))):
		_draw_smoke(canvas, now)
	var toss_age := now - _toss_start
	if _toss_texture != null and toss_age > 0.0 and toss_age < WINDOW_CLOSED:
		_draw_armory_window(canvas, painting, design_size, toss_age)
		if toss_age >= TOSS_RELEASE and toss_age < TOSS_GONE:
			_draw_toss(canvas, toss_age)
	var hill_age := now - _hill_start
	if hill_age >= 0.0 and hill_age < HILL_DROP_TIME and visible.grow(52.0).has_point(HILL_WINDOW):
		_draw_hill_drop(canvas, hill_age)

func _draw_lantern(canvas: CanvasItem, now: float) -> void:
	var pulse := .62 + .22 * sin(now * 1.9) + .16 * sin(now * 4.3)
	canvas.draw_texture_rect(_glow, Rect2(LANTERN - Vector2(44, 40), Vector2(88, 80)),
		false, Color("#b653ff", .18 * pulse))
	canvas.draw_texture_rect(_glow, Rect2(LANTERN - Vector2(13, 20), Vector2(26, 40)),
		false, Color("#efadff", .39 * pulse))

func _draw_smoke(canvas: CanvasItem, now: float) -> void:
	canvas.draw_texture_rect(_glow, Rect2(CHIMNEY - Vector2(11, 27), Vector2(22, 30)),
		false, Color("#514454", .28))
	for index in 7:
		var phase := fposmod(now / 3.8 + index / 7.0, 1.0)
		var seed := index * 2.399
		var opacity := smoothstep(0.0, .10, phase) * (1.0 - smoothstep(.35, 1.0, phase))
		var wind := sin(phase * 5.0 + seed) * 11.0 * phase
		var center := CHIMNEY + Vector2((index % 3 - 1) * 3.0 + 66.0 * phase * phase + wind, -85.0 * phase)
		var width := lerpf(17.0, 61.0, phase)
		var puff := Vector2(width, width * .82)
		canvas.draw_texture_rect(_glow, Rect2(center - puff * .5, puff), false, Color("#514454", opacity * .50))
		var lobe := puff * .61
		var fringe := center + Vector2((.30 if index % 2 == 0 else -.30) * width, -.21 * width)
		canvas.draw_texture_rect(_glow, Rect2(fringe - lobe * .5, lobe), false, Color("#7f6e82", opacity * .18))

func _draw_armory_window(canvas: CanvasItem, painting: Texture2D, design_size: Vector2, age: float) -> void:
	var open := smoothstep(0.0, .37, age) * (1.0 - smoothstep(TOSS_GONE, WINDOW_CLOSED, age))
	if open < .001:
		return
	var aperture := PackedVector2Array([
		Vector2(464, 340), Vector2(464, 278), Vector2(467, 270), Vector2(473, 264), Vector2(483, 261),
		Vector2(491, 263), Vector2(498, 267), Vector2(503, 274), Vector2(507, 283), Vector2(507, 348),
	])
	var wall_uv := PackedVector2Array()
	var lighting := PackedColorArray()
	var reveal := smoothstep(0.0, .26, open)
	# Sample the neighboring sandstone. The arch shades the far wall and the sill catches daylight.
	for point in aperture:
		var across := inverse_lerp(464.0, 507.0, point.x)
		var down := inverse_lerp(261.0, 348.0, point.y)
		var source := ARMORY_WALL_SAMPLE.position + ARMORY_WALL_SAMPLE.size * Vector2(across, down)
		wall_uv.append(source / design_size)
		var tint := Color("#61504a").lerp(Color("#d1aa83"), down * .81 + across * .14)
		lighting.append(Color(tint, reveal))
	canvas.draw_polygon(aperture, lighting, wall_uv, painting)
	canvas.draw_line(Vector2(465, 339), Vector2(506, 347), Color("#dbaa79", reveal * .78), 1.7, true)
	_draw_casement(canvas, painting, design_size, ARMORY_LEFT_SASH, 464.0, open * 1.34)
	_draw_casement(canvas, painting, design_size, ARMORY_RIGHT_SASH, 507.0, open * 1.41)

func _draw_casement(canvas: CanvasItem, painting: Texture2D, design_size: Vector2, shape: Array,
		hinge_x: float, angle: float) -> void:
	var panel := PackedVector2Array()
	var uv := PackedVector2Array()
	var side := 1.0 if hinge_x < TOSS_ORIGIN.x else -1.0
	# Only the glass and its frame rotate. The hinges stay on the upright edge of the arch.
	for point: Vector2 in shape:
		var hinge_distance := point.x - hinge_x
		var toward_camera := hinge_distance * side * sin(angle)
		panel.append(Vector2(hinge_x + hinge_distance * cos(angle), point.y + (point.y - 307.0) * .007 * toward_camera))
		uv.append(point / design_size)
	var tint := Color.WHITE.lerp(Color("#a79886"), sin(angle) * .27)
	canvas.draw_polygon(panel, PackedColorArray([tint]), uv, painting)
	var top := panel[-2] if side > 0.0 else panel[0]
	canvas.draw_line(top, panel[-1], Color("#aa8765", sin(angle) * .76), 1.4, true)

func _draw_toss(canvas: CanvasItem, age: float) -> void:
	var flight := clampf(inverse_lerp(TOSS_RELEASE, TOSS_LANDING, age), 0.0, 1.0)
	var settling := clampf(inverse_lerp(TOSS_LANDING, TOSS_SETTLED, age), 0.0, 1.0)
	var fade := (1.0 - smoothstep(TOSS_SETTLED + .30, TOSS_GONE, age)) * smoothstep(0.0, .08, flight)
	var angle := lerpf(-.45, _toss_turn, flight) + .43 * smoothstep(0.0, 1.0, settling)
	var extent := _toss_texture.get_size()
	extent *= lerpf(25.0, 47.0, flight) / maxf(extent.x, extent.y)
	var sprite_height := absf(sin(angle)) * extent.x + absf(cos(angle)) * extent.y
	var ground := _toss_ground - Vector2(20.0 * smoothstep(0.0, 1.0, settling), 0.0)
	# A shallow throw clears the windowsill, then two smaller hops sell the weight on impact.
	var center := TOSS_ORIGIN.lerp(ground - Vector2(0, sprite_height * .5), flight)
	center.y -= 495.0 * flight * (1.0 - flight)
	if settling < .68:
		var bounce := settling / .68
		center.y -= 46.0 * bounce * (1.0 - bounce)
	else:
		var bounce := inverse_lerp(.68, 1.0, settling)
		center.y -= 14.0 * bounce * (1.0 - bounce)
	var shadow := Vector2(center.x, ground.y)
	canvas.draw_texture_rect(_glow, Rect2(shadow - Vector2(27, 5), Vector2(54, 10)),
		false, Color("#241626", .52 * fade * smoothstep(.64, .99, flight)))
	# Compose the sprite transform with the town painting transform supplied by the caller.
	var corners := PackedVector2Array()
	for corner: Vector2 in [Vector2(-.5, -.5), Vector2(.5, -.5), Vector2(.5, .5), Vector2(-.5, .5)]:
		corners.append(center + (extent * corner).rotated(angle))
	var uv := PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN])
	canvas.draw_polygon(corners, PackedColorArray([Color(.98, .93, .88, fade)]), uv, _toss_texture)

func _draw_hill_drop(canvas: CanvasItem, age: float) -> void:
	var travel := age / HILL_DROP_TIME
	var show := smoothstep(0.0, .13, travel) * (1.0 - smoothstep(.67, 1.0, travel))
	var center := HILL_WINDOW + Vector2(-_hill_drift * travel, 53.0 * travel * travel - 6.0 * travel)
	var angle := travel * -4.8
	var clay := Color("#804c39", show)
	var rim := Color("#bc8566", show)
	var foliage := Color("#5c6250", show)
	var pot := PackedVector2Array()
	for point: Vector2 in [Vector2(-3.5, 0), Vector2(3.5, 0), Vector2(2.5, 5), Vector2(-2.5, 5)]:
		pot.append(center + point.rotated(angle))
	canvas.draw_colored_polygon(pot, clay)
	canvas.draw_line(pot[0], pot[1], rim, 1.4, true)
	canvas.draw_line(center, center + Vector2(-3, -5).rotated(angle), foliage, 2.0, true)
	canvas.draw_line(center, center + Vector2(2, -7).rotated(angle), foliage, 2.3, true)
