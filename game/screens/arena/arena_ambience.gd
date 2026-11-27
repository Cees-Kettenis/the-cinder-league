extends RefCounted
## Adds motion to features already painted into the arena backdrop.

const BackdropEffects = preload("res://game/screens/backdrop_effects.gd")

var _effects := BackdropEffects.new()
var _design_size := Vector2.ZERO
var _banners: Array = []
var _flames: Array = []
var _lights: Array = []
var _walkways: Array = []

func _init(backdrop_stem: String) -> void:
	# Each arena can place an optional ambience.gd alongside its two backdrop resolutions.
	var path := backdrop_stem.get_base_dir().path_join("ambience.gd")
	if not ResourceLoader.exists(path):
		return
	var layout: Script = load(path)
	var anchors := layout.get_script_constant_map()
	_design_size = anchors.DESIGN_SIZE
	_banners = anchors.get("BANNERS", [])
	_flames = anchors.get("FLAMES", [])
	_lights = anchors.get("LIGHTS", [])
	_walkways = anchors.get("WALKWAYS", [])

func draw(canvas: CanvasItem, painting: Texture2D, crop: Rect2, output: Vector2, time: float) -> void:
	if _design_size == Vector2.ZERO:
		return
	# Use exactly the crop the stage painted so details follow the fight camera and texture resolution.
	var to_design := _design_size / painting.get_size()
	var visible := Rect2(crop.position * to_design, crop.size * to_design)
	var scale := output / visible.size
	canvas.draw_set_transform(-visible.position * scale, 0.0, scale)
	for index in _walkways.size():
		_draw_walkway(canvas, _walkways[index], visible, time, index)
	for index in _banners.size():
		var cloth: Rect2 = _banners[index]
		if visible.intersects(cloth):
			_effects.draw_banner(canvas, painting, _design_size, cloth, time + index * 1.18, 1.45)
	for index in _flames.size():
		var fire: Rect2 = _flames[index]
		if visible.grow(fire.size.y * .5).intersects(fire):
			var age := time + index * 2.67
			# Bend the painted flame above its bowl and layer a few translucent embers over it.
			_effects.draw_banner(canvas, painting, _design_size, fire, age * 2.4, .65)
			_effects.draw_fire(canvas, fire, age, false, .65)
	for index in _lights.size():
		var light: Array = _lights[index]
		var center: Vector2 = light[0]
		var extent: Vector2 = light[1]
		var area := Rect2(center - extent * .5, extent)
		if visible.intersects(area):
			var age := time + index * 1.91
			var pulse := .18 + .09 * sin(age * 2.1) + .035 * sin(age * 4.7)
			canvas.draw_texture_rect(_effects.glow, area, false, Color(light[2], pulse))
	canvas.draw_set_transform(Vector2.ZERO)

func _draw_walkway(canvas: CanvasItem, route: Array, visible: Rect2, time: float, index: int) -> void:
	var entry: Vector2 = route[0]
	var exit: Vector2 = route[1]
	var height: float = route[2]
	var bounds := Rect2(entry, Vector2.ZERO).expand(exit).grow(height)
	if not visible.intersects(bounds):
		return
	var travel_time := entry.distance_to(exit) / (height * .63)
	var clock := time + index * 7.17 + 2.9
	var lap := travel_time + 4.0 + index * .7
	var age := fposmod(clock, lap)
	if age >= travel_time:
		return
	var progress := age / travel_time
	var direction := 1.0 if posmod(floori(clock / lap) + index, 2) == 0 else -1.0
	var at := entry.lerp(exit, progress if direction > 0.0 else 1.0 - progress)
	# Fade at the ends of each section of stands, where columns and shadows hide the entrances.
	var opacity := smoothstep(0.0, .16, progress) * (1.0 - smoothstep(.84, 1.0, progress))
	var stride := sin(age * TAU * 1.8)
	var shoulders := at + Vector2(stride * height * .05, -height * (.61 + absf(stride) * .05))
	var ink := Color(route[3], opacity * .94)
	var arm := Vector2(direction * stride * height * .19, height * .35)
	var hips := at - Vector2(0, height * .17)
	# Below the hips the ledge hides the stride, so only the upper body and swinging arm are visible.
	canvas.draw_colored_polygon(PackedVector2Array([
		shoulders - Vector2(height * .18, 0), shoulders + Vector2(height * .18, 0),
		hips + Vector2(height * .14, 0), at + Vector2(height * .11, 0),
		at - Vector2(height * .11, 0), hips - Vector2(height * .14, 0),
	]), ink)
	canvas.draw_line(shoulders + Vector2(height * .12 * direction, height * .08),
		shoulders + Vector2(height * .12 * direction, 0) + arm, ink, height * .12, true)
	var head := shoulders + Vector2(direction * height * .05, -height * .14)
	canvas.draw_circle(head, height * .15, ink, true, -1.0, true)
