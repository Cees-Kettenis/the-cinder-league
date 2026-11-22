extends Control

signal impact_reached
signal turn_animation_finished

const Symbol = preload("res://scripts/ui_symbol.gd")
const GEAR = preload("res://art/gear.png")
const GLADIATOR = preload("res://art/gladiator-base.png")
const TRIM = preload("res://art/try-on.png")
const MAIL = preload("res://art/mail.png")
const ARENAS = preload("res://art/arenas.png")
const MOTION = preload("res://art/motion.png")
const MAIL_MOTION = preload("res://art/motion-mail.png")
const SPELLS = preload("res://art/spells.png")
const TOWN = preload("res://art/town.png")
const STOCK = preload("res://art/stock.png")
const POSES: Array[Rect2] = [
	Rect2(0, 0, 444, 429), Rect2(444, 0, 444, 429), Rect2(888, 0, 498, 429), Rect2(1386, 0, 388, 429),
	Rect2(0, 429, 444, 458), Rect2(444, 429, 445, 458), Rect2(889, 429, 444, 458), Rect2(1333, 429, 441, 458)]
const POSE_PIVOT := [230.0, 228.0, 218.0, 174.0, 226.0, 175.0, 218.0, 212.0]
const POSE_FLOOR := [419.0, 419.0, 419.0, 419.0, 420.0, 439.0, 439.0, 440.0]
const SPELL_CONTACT := .60
const SPELL_COLORS := [Color("#ffc378"), Color("#cf9eff"), Color("#ffb66e"), Color("#7cdfff")]
const KIT_SIZE := Vector2(768, 1024)
const BASE_SIZE := Vector2(1024, 1536)
const BASE_SCALE := Vector2(2.0 / 3.0, 2.0 / 3.0)
const BASE_ORIGIN := Vector2(-341, -1024)
const BEND_TOP := 835.0
const BEND_BOTTOM := 335.0
const BODY_ROWS := [0.0, 1.0 - BEND_TOP / 1024.0, 1.0 - BEND_BOTTOM / 1024.0, 1.0]
const GRIP := Vector2(855, 649)
const SKIN_TINTS := [Color.WHITE, Color(1.12, 1.09, 1.08), Color("#d2ad94"), Color("#a57862")]
const HAIR_TINTS := [Color.WHITE, Color(1.23, .86, .65), Color(.95, 1.05, 1.25)]
const SKIN_MASKS := [
	[Vector2(.441,.093),Vector2(.513,.084),Vector2(.563,.068),Vector2(.627,.094),Vector2(.624,.171),Vector2(.583,.205),Vector2(.555,.227),Vector2(.472,.198),Vector2(.390,.175),Vector2(.427,.129)],
	[Vector2(.175,.273),Vector2(.244,.273),Vector2(.339,.315),Vector2(.299,.364),Vector2(.264,.370),Vector2(.264,.446),Vector2(.229,.497),Vector2(.279,.522),Vector2(.270,.587),Vector2(.130,.587),Vector2(.126,.397)],
	[Vector2(.612,.336),Vector2(.689,.313),Vector2(.728,.347),Vector2(.816,.375),Vector2(.940,.373),Vector2(.940,.482),Vector2(.766,.472),Vector2(.649,.429)],
]
const HAIR_MASK := [Vector2(.338,.009),Vector2(.649,.009),Vector2(.649,.089),Vector2(.596,.093),Vector2(.566,.064),Vector2(.520,.087),Vector2(.497,.106),Vector2(.458,.103),Vector2(.434,.095),Vector2(.436,.125),Vector2(.469,.140),Vector2(.419,.159),Vector2(.365,.171),Vector2(.338,.158)]
const SWORD_MASK := [Vector2(.724,.377),Vector2(.744,.363),Vector2(.762,.381),Vector2(.864,.252),Vector2(.977,.202),Vector2(.969,.223),Vector2(.802,.411),Vector2(.830,.425),Vector2(.824,.441),Vector2(.799,.444),Vector2(.741,.414)]
const MACE_MASK := [Vector2(.744,.400),Vector2(.832,.288),Vector2(.842,.267),Vector2(.830,.242),Vector2(.856,.229),Vector2(.864,.208),Vector2(.892,.214),Vector2(.928,.203),Vector2(.945,.226),Vector2(.963,.240),Vector2(.953,.260),Vector2(.955,.277),Vector2(.930,.282),Vector2(.917,.301),Vector2(.893,.291),Vector2(.781,.423)]
const MASKS := {
	"helmet": [Vector2(.30,0),Vector2(.63,0),Vector2(.62,.09),Vector2(.51,.10),Vector2(.48,.17),Vector2(.39,.18),Vector2(.32,.14)],
	"chest": [Vector2(.123,.25),Vector2(.173,.203),Vector2(.30,.173),Vector2(.405,.170),Vector2(.47,.221),Vector2(.565,.216),Vector2(.629,.258),Vector2(.655,.307),Vector2(.593,.356),Vector2(.55,.387),Vector2(.543,.453),Vector2(.605,.489),Vector2(.66,.562),Vector2(.663,.622),Vector2(.587,.645),Vector2(.391,.64),Vector2(.399,.527),Vector2(.384,.436),Vector2(.352,.351),Vector2(.223,.331),Vector2(.143,.329)],
	"pants": [Vector2(.336,.646),Vector2(.494,.564),Vector2(.615,.55),Vector2(.663,.69),Vector2(.66,.761),Vector2(.577,.794),Vector2(.465,.788),Vector2(.441,.761),Vector2(.478,.667),Vector2(.384,.685),Vector2(.273,.795),Vector2(.116,.794),Vector2(.089,.722),Vector2(.171,.690),Vector2(.285,.689)],
	"shoe_left": [Vector2(.105,.75),Vector2(.24,.785),Vector2(.22,.89),Vector2(.245,1),Vector2(.03,1),Vector2(.03,.91),Vector2(.085,.86)],
	"shoe_right": [Vector2(.455,.76),Vector2(.65,.75),Vector2(.67,.85),Vector2(.77,.91),Vector2(.79,1),Vector2(.46,1),Vector2(.445,.91)],
}
var kind := "town"
var data: RefCounted
var bout_items: Dictionary = {}
var left_loadout: Dictionary = {}
var right_loadout: Dictionary = {}
var skin := 0
var hair := 0
var rival_skin := 0
var rival_hair := 0
var show_rival := true
var arena := 0
var positions: Array = [3, 7]
var previous_positions: Array = []
var arena_width := 10
var event: Dictionary = {}
var elapsed := 0.0
var action_time := .54
var impact_time := .24
var idle_time := 0.0
var torso_bend := Vector2.ZERO
var spell_art := 0
var demo := false
var full_arena := false
var shield_mask: Array[Vector2] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(queue_redraw)
	for point in 36:
		var angle := TAU * point / 36.0
		shield_mask.append(Vector2(.199 + cos(angle) * .195, .507 + sin(angle) * .181))

func _process(delta: float) -> void:
	if kind == "town" or demo:
		elapsed += delta
		queue_redraw()
	elif full_arena:
		idle_time += delta
		if not event.is_empty() and elapsed < action_time:
			var before := elapsed
			elapsed = minf(elapsed + delta, action_time)
			if before < impact_time and elapsed >= impact_time:
				impact_reached.emit()
			if elapsed >= action_time:
				turn_animation_finished.emit()
		queue_redraw()

func animate(change: Dictionary) -> void:
	previous_positions = positions.duplicate()
	positions = change.positions.duplicate()
	event = change
	elapsed = 0.0
	match event.action:
		"attack":
			impact_time = .23
			action_time = .65 if event.critical else .52
		"rush":
			impact_time = .36
			action_time = .73 if event.critical else .64
		"cast":
			action_time = .80
			impact_time = action_time * SPELL_CONTACT
		"advance", "retreat":
			impact_time = .21
			action_time = .35
		"jump":
			impact_time = .36
			action_time = .49
		_:
			impact_time = .22
			action_time = .45
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#1a2024"))
	match kind:
		"town":
			var art := town_art_rect()
			var view := art.intersection(Rect2(Vector2.ZERO, size))
			if not view.has_area():
				return
			var to_source := TOWN.get_size() / art.size
			var crop := Rect2((view.position - art.position) * to_source, view.size * to_source)
			draw_texture_rect_region(TOWN, view, crop)
			var feet := view.position + view.size * Vector2(.49, .94)
			feet.y += sin(elapsed * 1.8) * 1.25
			_avatar(feet, view.size.y * .39, left_loadout, false, skin, hair)
		"avatar":
			_avatar(Vector2(size.x * .5, size.y * .96), minf(size.y * .89, size.x * 1.25), left_loadout, false, skin, hair)
		"battle":
			var half := ARENAS.get_height() * .5
			_cover(ARENAS, Rect2(0, mini(arena, 1) * half + 2, ARENAS.get_width(), half - 4))
			_draw_battle()
		"spell":
			_avatar(Vector2(size.x * .24, size.y * .9), size.y * .63, left_loadout, false, skin, hair)
			_draw_spell(Vector2(size.x * .32, size.y * .60), Vector2(size.x * .70, size.y * .81), minf(size.y * .72, size.x * .35), spell_art, fmod(elapsed, 1.9) / 1.9, 1.0)

func town_art_rect() -> Rect2:
	# Keep all four storefronts inside the visible band even on ultrawide screens.
	var scale := minf(size.x / TOWN.get_width(), size.y * 1.5 / TOWN.get_height())
	var extent := TOWN.get_size() * scale
	return Rect2((size - extent) * .5, extent)

func _cover(texture: Texture2D, region: Rect2) -> void:
	if size.y <= 0 or size.x <= 0:
		return
	var view_shape := size.x / size.y
	var source_shape := region.size.x / region.size.y
	var crop := region
	if view_shape > source_shape:
		crop.size.y = region.size.x / view_shape
		crop.position.y += (region.size.y - crop.size.y) * .5
	else:
		crop.size.x = region.size.y * view_shape
		crop.position.x += (region.size.x - crop.size.x) * .5
	draw_texture_rect_region(texture, Rect2(Vector2.ZERO, size), crop)

func _item(id: String) -> Dictionary:
	var catalog: Dictionary = data.items if bout_items.is_empty() else bout_items
	return catalog.get(id, {})

func _avatar(feet: Vector2, height: float, gear: Dictionary, facing_left: bool, skin_index: int = 0, hair_index: int = 0, lean: float = 0.0, swing: float = 0.0, bend: Vector2 = Vector2.ZERO) -> void:
	if height <= 0:
		return
	torso_bend = bend
	var scale_value := height / 1024.0
	draw_set_transform(feet, -lean if facing_left else lean, Vector2(-scale_value if facing_left else scale_value, scale_value))
	_draw_weapon(gear, swing)
	_draw_body()
	if skin_index > 0:
		for mask: Array in SKIN_MASKS:
			_mesh(GLADIATOR, mask, BASE_SIZE, BASE_ORIGIN, BASE_SCALE, SKIN_TINTS[skin_index])
	if hair_index > 0:
		_mesh(GLADIATOR, HAIR_MASK, BASE_SIZE, BASE_ORIGIN, BASE_SCALE, HAIR_TINTS[hair_index])
	var armor: Dictionary = gear.get("armor", {})
	for slot in ["pants", "shoes", "chest", "helmet", "shield"]:
		var item := _item(armor.get(slot, ""))
		if item.is_empty():
			continue
		var tier := int(item.get("tier", 0))
		var texture := MAIL if tier >= 2 else (TRIM if tier == 1 else GEAR)
		match slot:
			"helmet": _mesh(texture, MASKS.helmet, KIT_SIZE, Vector2(-359, -1010))
			"chest": _mesh(texture, MASKS.chest, KIT_SIZE, Vector2(-296, -1034), Vector2(.89, .99))
			"pants": _mesh(texture, MASKS.pants, KIT_SIZE, Vector2(-307, -975))
			"shoes":
				_mesh(texture, MASKS.shoe_left, KIT_SIZE, Vector2(-290, -696), Vector2(.90, .68))
				_mesh(texture, MASKS.shoe_right, KIT_SIZE, Vector2(-290, -696), Vector2(.90, .68))
			"shield": _mesh(texture, shield_mask, KIT_SIZE, Vector2(-319, -1029))
	torso_bend = Vector2.ZERO
	draw_set_transform(Vector2.ZERO)

func _draw_body() -> void:
	if torso_bend.is_zero_approx():
		draw_texture_rect(GLADIATOR, Rect2(BASE_ORIGIN, BASE_SIZE * BASE_SCALE), false)
		return
	# Split at the chest and hips so the bend can move the body while keeping the feet planted.
	for row in BODY_ROWS.size() - 1:
		var top: float = BODY_ROWS[row]
		var bottom: float = BODY_ROWS[row + 1]
		_mesh(GLADIATOR, [Vector2(0, top), Vector2(1, top), Vector2(1, bottom), Vector2(0, bottom)], BASE_SIZE, BASE_ORIGIN, BASE_SCALE)

func _bend_point(point: Vector2) -> Vector2:
	return point + torso_bend * clampf((-point.y - BEND_BOTTOM) / (BEND_TOP - BEND_BOTTOM), 0.0, 1.0)

func _draw_weapon(gear: Dictionary, swing: float) -> void:
	var weapon := _item(gear.get("weapon", ""))
	if weapon.is_empty():
		return
	var mace := int(weapon.art) == 1
	var grip := _bend_point(BASE_ORIGIN + GRIP * BASE_SCALE)
	var source_grip := Vector2(551, 459)
	var blade_scale := Vector2(.58, .62) if weapon.id == "dagger" else Vector2.ONE
	var origin := grip - (source_grip * blade_scale).rotated(swing)
	_mesh(MAIL if mace else GEAR, MACE_MASK if mace else SWORD_MASK, KIT_SIZE, origin, blade_scale, Color.WHITE, swing, false)
	if not str(gear.get("enchant", "")).is_empty():
		var edge := grip + (Vector2(141, -177) * blade_scale).rotated(swing)
		_weapon_glow(edge, 52.0, .6 + sin(elapsed * 4.0) * .12)

func _mesh(texture: Texture2D, mask: Array, source_size: Vector2, origin: Vector2, stretch: Vector2 = Vector2.ONE, tint: Color = Color.WHITE, angle: float = 0.0, follows_body: bool = true) -> void:
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var texture_size := texture.get_size()
	for point: Vector2 in mask:
		var pixel := point * source_size
		var vertex := origin + (pixel * stretch).rotated(angle)
		vertices.append(_bend_point(vertex) if follows_body else vertex)
		uv.append(pixel / texture_size)
	draw_polygon(vertices, PackedColorArray([tint]), uv, texture)

func fighter_height() -> float:
	return minf(size.y * .34, size.x * .255) if full_arena else minf(size.y * .76, size.x * .265)

func fighter_feet(index: int) -> Vector2:
	return _feet_at(float(positions[index]))

func _feet_at(position: float) -> Vector2:
	return Vector2(size.x * (.15 + .70 * position / arena_width), size.y * (.73 if full_arena else .88))

func _draw_battle() -> void:
	var feet: Array[Vector2] = []
	var height := fighter_height()
	var side := int(event.get("side", -1))
	var action := str(event.get("action", ""))
	var phase := clampf(elapsed / action_time, 0, 1)
	var animating := side >= 0 and phase < 1
	var approach := clampf(elapsed / impact_time, 0, 1)
	var recovery := clampf((elapsed - impact_time) / (action_time - impact_time), 0, 1)
	var shift := smoothstep(.04, 1.0, approach) if action in ["jump", "rush"] else smoothstep(.04, .90, phase)
	for index in 2 if show_rival else 1:
		var distance := float(positions[index])
		if animating and previous_positions.size() == 2:
			distance = lerpf(float(previous_positions[index]), distance, shift)
		var foot := _feet_at(distance)
		feet.append(foot)
		draw_set_transform(foot + Vector2(height * .06, height * .008), 0.0, Vector2(1, .24))
		draw_circle(Vector2.ZERO, height * .24, Color(0.08, 0.07, 0.055, .26))
		draw_set_transform(Vector2.ZERO)
	if animating and action in ["advance", "retreat", "jump", "rush"] and elapsed >= impact_time:
		_draw_dust(feet[side], height, recovery)
	if full_arena and not animating:
		var marker := feet[0] + Vector2(0, 7)
		draw_set_transform(marker, 0.0, Vector2(1, .24))
		draw_arc(Vector2.ZERO, height * .24, 0, TAU, 40, Color(1.0, .75, .42, .8), 2.5, true)
		draw_set_transform(Vector2.ZERO)
	var gap := absf(feet[1].x - feet[0].x) if feet.size() == 2 else 0.0
	for index in feet.size():
		var loadout := left_loadout if index == 0 else right_loadout
		_draw_fighter(feet[index], height, loadout, index, gap, approach, recovery, phase)
	if action in ["attack", "rush"] and animating:
		var kit := left_loadout if side == 0 else right_loadout
		var mace := int(_item(kit.get("weapon", "")).get("art", 0)) == 1
		_draw_swing(feet[side], height, gap, 1.0 if side == 0 else -1.0, mace)
	if action == "cast" and animating:
		var kit := left_loadout if side == 0 else right_loadout
		var attack_art := int(_item(kit.get("spell", "")).get("art", 0))
		var target := feet[1 - side]
		var direction := 1.0 if side == 0 else -1.0
		if event.miss:
			target.x += height * .62 * direction
		_draw_spell(feet[side] + Vector2(.20 * direction, -.56) * height, target, height, attack_art, phase, direction)
	if animating and elapsed >= impact_time:
		_draw_impact(feet, height, side, recovery)

func _motion_atlas(loadout: Dictionary, skin_index: int, hair_index: int) -> Texture2D:
	if skin_index != 0 or hair_index != 0 or not str(loadout.get("enchant", "")).is_empty():
		return null
	var weapon: String = loadout.get("weapon", "")
	if weapon not in ["sword", "mace"]:
		return null
	var mace := weapon == "mace"
	if int(_item(weapon).get("art", -1)) != int(mace):
		return null
	var prefix := "mail_" if mace else "leather_"
	var armor: Dictionary = loadout.get("armor", {})
	for slot in ["pants", "shoes", "chest", "helmet", "shield"]:
		if armor.get(slot, "") != prefix + slot or int(_item(prefix + slot).get("tier", -1)) != (2 if mace else 0):
			return null
	return MAIL_MOTION if mace else MOTION

func _draw_fighter(feet: Vector2, height: float, loadout: Dictionary, index: int, gap: float, approach: float, recovery: float, phase: float) -> void:
	var actor := int(event.get("side", -1))
	var action := str(event.get("action", ""))
	var skin_index := skin if index == 0 else rival_skin
	var hair_index := hair if index == 0 else rival_hair
	var motion := _motion_atlas(loadout, skin_index, hair_index)
	var facing_left := index == 1
	var direction := -1.0 if facing_left else 1.0
	var lean := 0.0
	var pose := 0
	var swing := 0.0
	var bend := Vector2(0, sin(idle_time * 3.1 + index * 2.2) * 9.0) if full_arena else Vector2.ZERO
	var pulse := sin(phase * PI)
	if actor == index and phase < 1:
		match action:
			"attack", "rush":
				var windup := smoothstep(.0, .45, approach) * (1.0 - smoothstep(.48, .96, approach))
				var follow_through := smoothstep(.47, 1.0, approach) * (1.0 - smoothstep(.12, 1.0, recovery))
				var lunge := (height * .025 + clampf(gap - height * .37, 0, height * .45)) * (.68 if event.miss else 1.0)
				feet.x += direction * (lunge * follow_through - height * .10 * windup)
				lean = .095 * follow_through - .13 * windup
				bend += Vector2(58, -34) * follow_through + Vector2(-104, 44) * windup
				swing = -1.45 * windup + 1.08 * follow_through
				pose = 2 if approach >= .91 else 1
				if action == "rush" and approach < .91:
					feet.y -= sin(approach * PI) * height * .21
					pose = 4
			"advance", "retreat":
				var stride := sin(phase * TAU)
				feet.y -= absf(stride) * height * .043
				lean = pulse * (.15 if action == "advance" else -.12)
				bend += Vector2(34 * stride, -24 * absf(stride))
				var step := absf(stride)
				swing = -.25 * step
			"jump":
				feet.y -= sin(approach * PI) * height * .25
				bend += Vector2(48, -31) * pulse
				lean = .12 * pulse
				pose = 4 if approach < 1.0 else 0
			"cast":
				var release := smoothstep(.44, 1.0, approach) * (1.0 - recovery)
				bend += Vector2(72, -51) * release - Vector2(39, 20) * (pulse - release)
				lean = .15 * release
				swing = -.36 * pulse
				pose = 5
			"guard", "taunt", "sleep", "potion":
				lean = pulse * (-.14 if action in ["guard", "sleep"] else .14)
				bend += Vector2(-32, 46) * pulse if action in ["guard", "sleep"] else Vector2(37, -40) * pulse
				pose = {"guard": 3, "taunt": 6, "sleep": 7}.get(action, 0)
				if action == "sleep" and motion == null:
					height *= 1.0 - .18 * pulse
		if recovery > .78:
			pose = 0
	elif actor >= 0 and elapsed >= impact_time:
		var recoil := smoothstep(.0, .18, recovery) * (1.0 - smoothstep(.24, .94, recovery))
		if event.damage + event.armor_hit > 0 or event.miss:
			var weight := .55 if event.blocked else (1.4 if event.critical else 1.0)
			feet.x -= recoil * height * .12 * weight * direction
			lean = -.19 * recoil * weight
			bend += Vector2(-77, 45) * recoil * weight
			pose = 3 if event.blocked and recoil > .25 else 0
		if event.health[index] <= 0:
			var fall := smoothstep(.14, 1.0, recovery)
			feet.x -= fall * height * .28 * direction
			lean -= .53 * fall
			height *= 1.0 - .32 * fall
	if motion != null:
		_pose(motion, feet, height + bend.y * .12, pose, facing_left, lean)
	else:
		_avatar(feet, height, loadout, facing_left, skin_index, hair_index, lean, swing, bend)

func _draw_dust(at: Vector2, height: float, progress: float) -> void:
	for index in 6:
		var spread := float(index) - 2.5
		var x := spread * height * (.04 + progress * .08)
		var y := -height * progress * (.07 + (index % 3) * .045)
		var alpha := .43 * sin(progress * PI) * (1.0 - progress)
		draw_circle(at + Vector2(x, y), height * (.012 + progress * .028), Color(.94, .77, .55, alpha), true, -1, true)

func _draw_swing(feet: Vector2, height: float, gap: float, direction: float, mace: bool) -> void:
	var sweep := clampf((elapsed - impact_time + .09) / .24, 0, 1)
	if sweep <= 0 or sweep >= 1:
		return
	var center := feet + Vector2(minf(gap * .58, height * .40) * direction, -height * .60)
	var radius := minf(gap * .56, height * (.26 if mace else .32))
	var tip := lerpf(-1.25, 1.12, sweep)
	var alpha := sin(sweep * PI)
	draw_set_transform(center, 0, Vector2(direction, .80))
	draw_arc(Vector2.ZERO, radius, tip - 1.10, tip, 21, Color(1, .74, .38, alpha * .52), height * .041, true)
	draw_arc(Vector2.ZERO, radius, tip - .80, tip, 18, Color(1, .96, .78, alpha * .89), height * .013, true)
	draw_set_transform(Vector2.ZERO)

func _draw_impact(feet: Array[Vector2], height: float, side: int, recovery: float) -> void:
	var symbol := ""
	var at := feet[1 - side]
	if event.damage + event.armor_hit > 0:
		var spark_color := Color("#c8edff") if event.blocked or event.armor_hit > 0 else Color("#ffc16e")
		var spark_center := at + Vector2(height * (.10 if side == 1 else -.10), -height * .54)
		if event.action == "cast":
			var kit := left_loadout if side == 0 else right_loadout
			var art := clampi(int(_item(kit.get("spell", "")).get("art", 0)), 0, SPELL_COLORS.size() - 1)
			spark_color = SPELL_COLORS[art]
		_draw_sparks(spark_center, height * (.35 if event.critical else .23), spark_color, recovery)
	if event.miss:
		symbol = "miss"
	elif event.blocked or event.armor_hit > 0 and event.damage == 0:
		symbol = "armor"
	elif event.damage > 0:
		symbol = "critical" if event.critical else "attack"
	elif event.action in ["potion", "sleep", "guard"]:
		symbol = event.action
		at = feet[side]
	elif event.action == "taunt":
		symbol = "taunt"
	if symbol.is_empty():
		return
	var extent := lerpf(42.0, 28.0, recovery)
	var center := Vector2(at.x, maxf(36.0, at.y - height * .94 - recovery * 30.0))
	draw_circle(center, extent * .58, Color("#392831"), true, -1, true)
	Symbol.paint(self, symbol, center - Vector2.ONE * extent * .5, extent)

func _draw_sparks(at: Vector2, radius: float, tint: Color, recovery: float) -> void:
	var progress := clampf(recovery / .75, 0, 1)
	var fade := 1.0 - smoothstep(.03, 1.0, progress)
	var spread := lerpf(.15, 1.25, progress) * radius
	for index in 10:
		var ray := Vector2.from_angle(float(index) * TAU / 10.0 + .31)
		var point := at + ray * spread * (1.0 if index % 2 == 0 else .66)
		var length := radius * (.30 if index % 3 == 0 else .17)
		draw_line(point - ray * length, point, Color(tint, fade), 2.0 + fade, true)
		if index % 2 == 0:
			draw_circle(point, 2.0 + fade, Color(tint.lightened(.38), fade), true, -1, true)
	draw_circle(at, radius * (.30 + progress * .45), Color(tint, fade * .34), true, -1, true)

func _weapon_glow(point: Vector2, radius: float, opacity: float) -> void:
	draw_circle(point, radius * 1.18, Color(1.0, .43, .16, opacity * .12))
	draw_circle(point, radius * .72, Color(1.0, .57, .23, opacity * .18))
	draw_arc(point, radius, -.8, 1.8, 14, Color(1.0, .66, .26, opacity), maxf(1.0, radius * .06), true)

func _pose(sheet: Texture2D, feet: Vector2, height: float, index: int, facing_left: bool, lean: float) -> void:
	var source := POSES[index]
	var floor_origin: float = POSE_FLOOR[index]
	if sheet == MAIL_MOTION and index == 4:
		source.position.y -= 7
		source.size.y += 7
		floor_origin += 7
	var scale_value := height / 421.0
	draw_set_transform(feet, -lean if facing_left else lean, Vector2(-scale_value if facing_left else scale_value, scale_value))
	draw_texture_rect_region(sheet, Rect2(Vector2(-POSE_PIVOT[index], -floor_origin), source.size), source)
	draw_set_transform(Vector2.ZERO)

func _draw_spell(start: Vector2, target: Vector2, height: float, art: int, phase: float, direction: float) -> void:
	art = clampi(art, 0, SPELL_COLORS.size() - 1)
	var tint: Color = SPELL_COLORS[art]
	var charge := smoothstep(.01, .23, phase) * (1.0 - smoothstep(.24, .43, phase))
	if charge > 0.0:
		draw_circle(start, height * (.02 + .085 * charge), Color(tint, charge * .24), true, -1, true)
		draw_circle(start, height * (.01 + .031 * charge), Color(tint.lightened(.5), charge * .91), true, -1, true)
	var fade := 1.0 - smoothstep(SPELL_CONTACT, .97, phase)
	var flight := smoothstep(.24, SPELL_CONTACT, phase)
	var extent := Vector2(1.35, .90) * height
	var aim := target - Vector2(0, extent.y * .48)
	var alpha := fade * smoothstep(.21, .38, phase)
	var mirror := 1.0
	match art:
		0:
			extent *= .66
			aim = start.lerp(target - Vector2(0, height * .53), flight) - Vector2(extent.x * .40 * direction, 0)
			alpha *= 1.0 - smoothstep(SPELL_CONTACT, .76, phase)
			mirror = direction
		1:
			extent *= 1.29
			aim = target - Vector2(0, extent.y * .48)
			alpha = smoothstep(.50, SPELL_CONTACT, phase) * (1.0 - smoothstep(.65, .91, phase))
		2:
			aim -= Vector2(extent.x * .28, -extent.y * .02)
			aim -= Vector2(extent.x * .62, extent.y * 1.16) * (1.0 - flight)
			alpha *= 1.0 - smoothstep(SPELL_CONTACT, .82, phase)
		3:
			extent.y *= lerpf(.26, 1.12, smoothstep(.40, .67, phase))
			aim = target - Vector2(0, extent.y * .46)
			alpha = fade * smoothstep(.39, SPELL_CONTACT, phase)
	if alpha <= 0.0:
		return
	draw_set_transform(aim, 0, Vector2(mirror, 1))
	draw_texture_rect_region(SPELLS, Rect2(-extent * .5, extent), _cell(SPELLS, 2, 2, art), Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO)

static func _cell(texture: Texture2D, columns: int, rows: int, index: int) -> Rect2:
	var width := float(texture.get_width()) / columns
	var height := float(texture.get_height()) / rows
	return Rect2((index % columns) * width, floori(float(index) / columns) * height, width, height)
