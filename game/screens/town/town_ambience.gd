extends RefCounted
## Ambient motion registered to the pixels of the original town painting.

const BackdropEffects = preload("res://game/screens/backdrop_effects.gd")
const Data = preload("res://game/catalog/data.gd")
const BuildingEffects = preload("res://game/screens/town/town_building_effects.gd")
const DESIGN_SIZE := Vector2(1536, 1024)
const BANNERS := [
	Rect2(800, 224, 25, 57), Rect2(977, 206, 28, 67),
	Rect2(1205, 253, 57, 184), Rect2(1465, 195, 65, 218), Rect2(1064, 119, 67, 44),
]
const FLAMES := [Rect2(117, 551, 134, 92), Rect2(1209, 488, 30, 39), Rect2(1491, 470, 31, 40)]
const GUARD_HELMET_BOUNDS := Rect2(1262, 539, 21, 25)
const GUARD_NECK := Vector2(1270, 561)
const GUARD_HELMET := [
	Vector2(1263, 557), Vector2(1263.5, 550), Vector2(1265, 545), Vector2(1268, 542.5),
	Vector2(1270, 541), Vector2(1275, 541), Vector2(1277, 542), Vector2(1276.5, 544.5),
	Vector2(1274, 547), Vector2(1274, 549), Vector2(1276, 551), Vector2(1277, 554),
	Vector2(1277, 560.5), Vector2(1274, 562), Vector2(1269, 561.5), Vector2(1266, 560),
	Vector2(1266, 555.5), Vector2(1265, 555.5), Vector2(1265, 557.5),
]
const BRIDGE_PERCHES := [Vector2(855, 221.5), Vector2(925, 214.7), Vector2(1019, 204.1)]
const WALK_BACK_Y := 690.0
const WALK_FRONT_Y := 836.0
const WALK_ROUTES := [
	[Vector2(446, 768), Vector2(1040, WALK_FRONT_Y)],
	[Vector2(1195, 748), Vector2(470, 823)],
	[Vector2(753, 693), Vector2(1121, 752)],
]
const CLOTHING := [Color("#c2b1a1"), Color("#b5b0ca"), Color("#bac7bb"), Color("#d7c09d")]
const BIRD_ARRIVAL := 2.1
const BIRD_DEPARTURE := 1.7

var _rng := RandomNumberGenerator.new()
var _effects := BackdropEffects.new()
var _buildings: BuildingEffects
var _walks: Array[Dictionary] = []
var _player_armor: Dictionary = {}
var _weapons: Array[String] = []
var _max_level: int
var _bird_start := 0.0
var _bird_hold := 0.0
var _bird_perch := Vector2.ZERO
var _bird_facing := 1.0

func _init(data: RefCounted, seed_value: int = 0) -> void:
	_max_level = data.max_level()
	for item in data.items.values():
		if item.kind == "weapon":
			_weapons.append(item.id)
		elif item.kind == "armor" and not str(item.id).begins_with("rival_"):
			if not _player_armor.has(item.slot):
				_player_armor[item.slot] = []
			_player_armor[item.slot].append(item.id)
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	_schedule_bird(_rng.randf_range(4.5, 8.5))
	# Show a fully equipped fighter on the first walk. Later outfits vary what they carry.
	_walks.append(_schedule_walk(_rng.randf_range(1.5, 3.0), -1, true))
	_walks.append(_schedule_walk(_rng.randf_range(8.5, 14.0), _walks[0].route))
	_buildings = BuildingEffects.new(data, _player_armor, _rng, _effects.glow)

func advance(now: float) -> void:
	_buildings.advance(now)
	if now > _bird_start + BIRD_ARRIVAL + _bird_hold + BIRD_DEPARTURE:
		_schedule_bird(now + _rng.randf_range(6.0, 14.0))
	for index in _walks.size():
		var walk := _walks[index]
		if now >= walk.start + walk.duration:
			var other_route: int = _walks[1 - index].route
			_walks[index] = _schedule_walk(now + _rng.randf_range(3.5, 9.5), other_route)

func _schedule_bird(start: float) -> void:
	_bird_start = start
	_bird_hold = _rng.randf_range(2.0, 4.8)
	_bird_perch = BRIDGE_PERCHES[_rng.randi_range(0, BRIDGE_PERCHES.size() - 1)]
	var offset := _rng.randf_range(-9.0, 9.0)
	_bird_perch += Vector2(offset, -.10 * offset)
	_bird_facing = 1.0 if _rng.randf() > .5 else -1.0

func _schedule_walk(start: float, occupied_route: int, fully_armed: bool = false) -> Dictionary:
	var route := _rng.randi_range(0, WALK_ROUTES.size() - 2) if occupied_route >= 0 else _rng.randi_range(0, WALK_ROUTES.size() - 1)
	if occupied_route >= 0 and route >= occupied_route:
		route += 1
	var ends: Array = WALK_ROUTES[route]
	var reverse := _rng.randf() > .5
	var from: Vector2 = ends[1] if reverse else ends[0]
	var to: Vector2 = ends[0] if reverse else ends[1]
	var duration := from.distance_to(to) / _rng.randf_range(48.0, 65.0)
	var stature := _rng.randf_range(.92, 1.07)
	var outfit := _walker_outfit(fully_armed)
	return {
		"route": route, "start": start, "duration": duration, "speed": absf(to.x - from.x) / duration,
		"from": from, "to": to, "stature": stature, "skin": _rng.randi_range(0, 3), "hair": _rng.randi_range(0, 2),
		"loadout": outfit.loadout, "look": outfit.look,
		"tint": CLOTHING[_rng.randi_range(0, CLOTHING.size() - 1)],
	}

func _walker_outfit(fully_armed: bool = false) -> Dictionary:
	var look := Data.rival_look(_rng.randi(), _max_level)
	var armor := {}
	var slots := ["chest", "pants", "helmet", "shoes"]
	if fully_armed or _rng.randf() < .55:
		slots.append("shield")
	var player_slot: String = slots[_rng.randi_range(0, slots.size() - 1)]
	for slot in slots:
		var pool: Array = _player_armor.get(slot, [])
		if pool.is_empty():
			continue
		if slot != player_slot and slot in ["helmet", "shoes"] and _rng.randf() < .25:
			continue
		# An equipped ID occupies the slot. Leaving its rival override in place draws the rival sprite.
		armor[slot] = pool[_rng.randi_range(0, pool.size() - 1)]
		if slot == player_slot:
			look.armor.erase(slot)
	var loadout := {"armor": armor}
	if not _weapons.is_empty() and (fully_armed or _rng.randf() < .70):
		loadout.weapon = _weapons[_rng.randi_range(0, _weapons.size() - 1)]
	return {"loadout": loadout, "look": look}

func pedestrians(now: float, nearest_y: float = WALK_FRONT_Y) -> Array[Dictionary]:
	var visible: Array[Dictionary] = []
	# Fit the routes behind the player even when an ultrawide viewport crops the street.
	var lane_depth := clampf(inverse_lerp(WALK_BACK_Y, WALK_FRONT_Y, nearest_y), 0.0, 1.0)
	for walk in _walks:
		var age: float = now - walk.start
		if age <= 0.0 or age >= walk.duration:
			continue
		var progress: float = age / walk.duration
		var feet: Vector2 = walk.from.lerp(walk.to, progress)
		feet.y = lerpf(WALK_BACK_Y, feet.y, lane_depth)
		var starting_y := lerpf(WALK_BACK_Y, walk.from.y, lane_depth)
		var fade := smoothstep(0.0, .85, age) * (1.0 - smoothstep(walk.duration - .95, walk.duration, age))
		visible.append({
			"feet": feet, "start_y": starting_y, "stature": walk.stature, "speed": walk.speed, "age": age,
			"facing_left": walk.to.x < walk.from.x,
			"skin": walk.skin, "hair": walk.hair, "tint": Color(walk.tint, fade), "loadout": walk.loadout, "look": walk.look,
		})
	visible.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return left.feet.y < right.feet.y)
	return visible

func draw_details(canvas: CanvasItem, painting: Texture2D, art: Rect2, view: Rect2, now: float) -> void:
	var scale := art.size.x / DESIGN_SIZE.x
	var visible := Rect2((view.position - art.position) / scale, view.size / scale)
	canvas.draw_set_transform(art.position, 0.0, Vector2.ONE * scale)
	for index in BANNERS.size():
		var box: Rect2 = BANNERS[index]
		if visible.intersects(box):
			_effects.draw_banner(canvas, painting, DESIGN_SIZE, box, now + index * 1.18)
	if visible.intersects(GUARD_HELMET_BOUNDS):
		_draw_guard(canvas, painting, now)
	for index in FLAMES.size():
		var box: Rect2 = FLAMES[index]
		if visible.grow(35).intersects(box):
			_effects.draw_fire(canvas, box, now + index * 3.23, index == 0)
	_buildings.draw(canvas, painting, DESIGN_SIZE, visible, now)
	_draw_bird(canvas, now)
	canvas.draw_set_transform(Vector2.ZERO)

func _draw_guard(canvas: CanvasItem, painting: Texture2D, now: float) -> void:
	var phase := fposmod(now, 8.0)
	var nod := smoothstep(.9, 1.45, phase) * (1.0 - smoothstep(1.85, 2.5, phase))
	if is_zero_approx(nod):
		return
	var angle := deg_to_rad(11.0) * nod
	var helmet := PackedVector2Array()
	var helmet_uv := PackedVector2Array()
	var stone_uv := PackedVector2Array()
	var stone_colors := PackedColorArray()
	# Fill the original silhouette from the clean stone above it, keeping the vertical mortar line aligned.
	for point: Vector2 in GUARD_HELMET:
		stone_uv.append(Vector2(point.x, remap(point.y, 541.0, 562.0, 532.0, 539.0)) / DESIGN_SIZE)
		# Blend into the original neck and collar where the helmet meets the figure.
		stone_colors.append(Color(Color.WHITE, 1.0 - smoothstep(554.0, 560.0, point.y)))
		helmet_uv.append(point / DESIGN_SIZE)
		helmet.append(GUARD_NECK + (point - GUARD_NECK).rotated(angle))
	canvas.draw_polygon(PackedVector2Array(GUARD_HELMET), stone_colors, stone_uv, painting)
	canvas.draw_polygon(helmet, PackedColorArray([Color.WHITE]), helmet_uv, painting)

func _draw_bird(canvas: CanvasItem, now: float) -> void:
	var age := now - _bird_start
	if age < 0.0:
		return
	var perched := age >= BIRD_ARRIVAL and age <= BIRD_ARRIVAL + _bird_hold
	var at := _bird_perch
	if age < BIRD_ARRIVAL:
		var t := smoothstep(0.0, BIRD_ARRIVAL, age)
		var edge := _bird_perch + Vector2(-_bird_facing * 210.0, -69.0)
		at = edge.bezier_interpolate(edge + Vector2(_bird_facing * 88.0, -30.0),
			_bird_perch + Vector2(-_bird_facing * 47.0, -29.0), _bird_perch, t)
	elif not perched:
		var t := clampf((age - BIRD_ARRIVAL - _bird_hold) / BIRD_DEPARTURE, 0.0, 1.0)
		var edge := _bird_perch + Vector2(_bird_facing * 168.0, -92.0)
		at = _bird_perch.bezier_interpolate(_bird_perch + Vector2(_bird_facing * 18.0, -39.0),
			edge - Vector2(_bird_facing * 57.0, -8.0), edge, t)
	var opacity := smoothstep(0.0, .30, age) * (1.0 - smoothstep(
		BIRD_ARRIVAL + _bird_hold + BIRD_DEPARTURE - .30, BIRD_ARRIVAL + _bird_hold + BIRD_DEPARTURE, age))
	var plumage := Color("#3e373c", opacity)
	if perched:
		var nod := .9 * smoothstep(.82, .98, sin(age * 2.6))
		canvas.draw_line(at - Vector2(.8, 0), at - Vector2(.8, 2.4), plumage, .7, true)
		canvas.draw_line(at + Vector2(.8, 0), at + Vector2(.8, -2.4), plumage, .7, true)
		canvas.draw_circle(at - Vector2(0, 3.0), 2.35, plumage, true)
		canvas.draw_circle(at + Vector2(_bird_facing * 1.8, -5.0 + nod), 1.40, plumage, true)
		return
	var flap := sin(age * 29.0)
	var near := at + Vector2(-_bird_facing * 2.1, 4.3 * flap)
	var far := at + Vector2(-_bird_facing * 1.6, -3.8 * flap)
	var beak := at + Vector2(_bird_facing * 3.1, 0)
	var tail := at + Vector2(-_bird_facing * 4, .8)
	var color := PackedColorArray([plumage])
	canvas.draw_primitive(PackedVector2Array([beak, near, tail]), color, PackedVector2Array())
	canvas.draw_primitive(PackedVector2Array([beak, tail, far]), color, PackedVector2Array())
