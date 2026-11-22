extends Control

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
const ACTION_TIME := .66
const IMPACT_TIME := .29
const KIT_SIZE := Vector2(768, 1024)
const BASE_SIZE := Vector2(1024, 1536)
const BASE_SCALE := Vector2(2.0 / 3.0, 2.0 / 3.0)
const BASE_ORIGIN := Vector2(-341, -1024)
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
var arena := 0
var positions: Array = [3, 7]
var previous_positions: Array = []
var arena_width := 10
var event: Dictionary = {}
var elapsed := 0.0
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
	if kind == "town" or demo or (not event.is_empty() and elapsed <= ACTION_TIME):
		elapsed += delta
		queue_redraw()

func animate(change: Dictionary) -> void:
	previous_positions = positions.duplicate()
	positions = change.positions.duplicate()
	event = change
	elapsed = 0.0
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#1a2024"))
	match kind:
		"town":
			_cover(TOWN, Rect2(0, 0, 1536, 1024))
			var feet := Vector2(size.x * .52, size.y * .94 + sin(elapsed * 1.8) * 1.25)
			_avatar(feet, size.y * .43, left_loadout, false, skin, hair)
		"avatar":
			_avatar(Vector2(size.x * .5, size.y * .96), minf(size.y * .89, size.x * 1.25), left_loadout, false, skin, hair)
		"battle":
			var half := ARENAS.get_height() * .5
			_cover(ARENAS, Rect2(0, mini(arena, 1) * half + 2, ARENAS.get_width(), half - 4))
			_draw_battle()
		"spell":
			_avatar(Vector2(size.x * .24, size.y * .9), size.y * .63, left_loadout, false, skin, hair)
			_draw_spell(Vector2(size.x * .32, size.y * .60), Vector2(size.x * .70, size.y * .81), spell_art, fmod(elapsed, 1.9) / 1.9)
		"weapon":
			var item := _item(left_loadout.get("weapon", ""))
			draw_texture_rect_region(STOCK, Rect2(size * .16, size * .68), _cell(STOCK, 3, 2, int(item.get("art", 0))), Color.WHITE)

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

func _avatar(feet: Vector2, height: float, gear: Dictionary, facing_left: bool, skin_index: int = 0, hair_index: int = 0, lean: float = 0.0, swing: float = 0.0) -> void:
	if height <= 0:
		return
	var scale_value := height / 1024.0
	draw_set_transform(feet, -lean if facing_left else lean, Vector2(-scale_value if facing_left else scale_value, scale_value))
	_draw_weapon(gear, swing)
	draw_texture_rect(GLADIATOR, Rect2(BASE_ORIGIN, BASE_SIZE * BASE_SCALE), false)
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
	draw_set_transform(Vector2.ZERO)

func _draw_weapon(gear: Dictionary, swing: float) -> void:
	var weapon := _item(gear.get("weapon", ""))
	if weapon.is_empty():
		return
	var mace := int(weapon.art) == 1
	var grip := BASE_ORIGIN + GRIP * BASE_SCALE
	var source_grip := Vector2(551, 459)
	var origin := grip - source_grip.rotated(swing)
	_mesh(MAIL if mace else GEAR, MACE_MASK if mace else SWORD_MASK, KIT_SIZE, origin, Vector2.ONE, Color.WHITE, swing)
	if not str(gear.get("enchant", "")).is_empty():
		var edge := grip + Vector2(141, -177).rotated(swing)
		_weapon_glow(edge, 52.0, .6 + sin(elapsed * 4.0) * .12)

func _mesh(texture: Texture2D, mask: Array, source_size: Vector2, origin: Vector2, stretch: Vector2 = Vector2.ONE, tint: Color = Color.WHITE, angle: float = 0.0) -> void:
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var texture_size := texture.get_size()
	for point: Vector2 in mask:
		var pixel := point * source_size
		vertices.append(origin + (pixel * stretch).rotated(angle))
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
	var phase := clampf(elapsed / ACTION_TIME, 0, 1)
	var animating := side >= 0 and phase < 1
	var shift := smoothstep(.04, .83, phase)
	for index in 2:
		var distance := float(positions[index])
		if animating and previous_positions.size() == 2:
			distance = lerpf(float(previous_positions[index]), distance, shift)
		var foot := _feet_at(distance)
		feet.append(foot)
		draw_set_transform(foot + Vector2(height * .06, height * .008), 0.0, Vector2(1, .24))
		draw_circle(Vector2.ZERO, height * .24, Color(0.08, 0.07, 0.055, .26))
		draw_set_transform(Vector2.ZERO)
	if full_arena and not animating:
		var marker := feet[0] + Vector2(0, 7)
		draw_set_transform(marker, 0.0, Vector2(1, .24))
		draw_arc(Vector2.ZERO, height * .24, 0, TAU, 40, Color(1.0, .75, .42, .8), 2.5, true)
		draw_set_transform(Vector2.ZERO)
	for index in 2:
		var loadout := left_loadout if index == 0 else right_loadout
		_draw_fighter(feet[index], height, loadout, index, side, action, phase)
	if action == "cast" and animating:
		var kit := left_loadout if side == 0 else right_loadout
		var attack_art := int(_item(kit.get("spell", "")).get("art", 0))
		var target := feet[1 - side]
		if event.miss:
			target.x += height * (.52 if side == 0 else -.52)
		_draw_spell(feet[side] - Vector2(0, height * .58), target, attack_art, phase, side == 1)
	if animating and elapsed >= IMPACT_TIME:
		_draw_impact(feet, height, side, phase)

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

func _draw_fighter(feet: Vector2, height: float, loadout: Dictionary, index: int, actor: int, action: String, phase: float) -> void:
	var skin_index := skin if index == 0 else 0
	var hair_index := hair if index == 0 else 0
	var motion := _motion_atlas(loadout, skin_index, hair_index)
	var facing_left := index == 1
	var direction := -1.0 if facing_left else 1.0
	var lean := 0.0
	var pose := 0
	var swing := 0.0
	if actor == index and phase < 1:
		match action:
			"attack": pose = 1 if phase < .37 else 2
			"guard": pose = 3
			"jump": pose = 4
			"cast": pose = 5
			"taunt": pose = 6
			"sleep": pose = 7
		if pose == 2:
			feet.x += height * .14 * direction * sin(phase * PI)
		if pose == 4:
			feet.y -= sin(phase * PI) * height * .24
		if action in ["advance", "retreat"]:
			feet.y -= absf(sin(phase * TAU)) * height * .035
		if motion == null:
			lean = sin(phase * PI) * (-.16 if action in ["guard", "sleep"] else .12)
			if action == "sleep":
				height *= .83
			if action == "attack":
				swing = lerpf(-.8, .9, smoothstep(.14, .64, phase)) * sin(phase * PI)
	elif actor >= 0 and phase < 1 and elapsed >= IMPACT_TIME and event.damage + event.armor_hit > 0:
		var recoil := sin((phase - IMPACT_TIME / ACTION_TIME) * TAU) * height * .085
		feet.x -= recoil * direction
		lean = -.09 * recoil / maxf(1.0, height * .085)
	if motion != null:
		_pose(motion, feet, height, pose, facing_left)
	else:
		_avatar(feet, height, loadout, facing_left, skin_index, hair_index, lean, swing)

func _draw_impact(feet: Array[Vector2], height: float, side: int, phase: float) -> void:
	var message := ""
	var color := Color("#ffe1a1")
	var at := feet[1 - side]
	if event.miss:
		message = "Miss"
	elif event.blocked:
		message = "Blocked"
	elif event.damage > 0:
		message = ("Critical! " if event.critical else "") + "−%d HP" % event.damage
		color = Color("#ffc0a4")
	elif event.armor_hit > 0:
		message = "−%d armor" % event.armor_hit
	elif event.action in ["potion", "sleep"]:
		message = "Restored"
		color = Color("#b5f4b8")
		at = feet[side]
	if message.is_empty():
		return
	var font := ThemeDB.fallback_font
	var y := maxf(28.0, at.y - height * (.76 + phase * .15))
	var width := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var center := clampf(at.x, width * .5 + 10, size.x - width * .5 - 10)
	var label_at := Vector2(center - width * .5, y)
	draw_rect(Rect2(label_at - Vector2(7, 19), Vector2(width + 14, 25)), Color(0.09, .07, .06, .77))
	draw_string(font, label_at, message, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)

func _weapon_glow(point: Vector2, radius: float, opacity: float) -> void:
	draw_circle(point, radius * 1.18, Color(1.0, .43, .16, opacity * .12))
	draw_circle(point, radius * .72, Color(1.0, .57, .23, opacity * .18))
	draw_arc(point, radius, -.8, 1.8, 14, Color(1.0, .66, .26, opacity), maxf(1.0, radius * .06), true)

func _pose(sheet: Texture2D, feet: Vector2, height: float, index: int, facing_left: bool) -> void:
	var source := POSES[index]
	var floor_origin: float = POSE_FLOOR[index]
	if sheet == MAIL_MOTION and index == 4:
		source.position.y -= 7
		source.size.y += 7
		floor_origin += 7
	var scale_value := height / 421.0
	draw_set_transform(feet, 0, Vector2(-scale_value if facing_left else scale_value, scale_value))
	draw_texture_rect_region(sheet, Rect2(Vector2(-POSE_PIVOT[index], -floor_origin), source.size), source)
	draw_set_transform(Vector2.ZERO)

func _draw_spell(start: Vector2, target: Vector2, art: int, phase: float, facing_left: bool = false) -> void:
	if phase < .12 or phase > .91:
		return
	var magnitude := minf(size.y * .69, size.x * .34)
	var extent := Vector2(magnitude * 1.35, magnitude)
	var alpha := 1.0 - maxf(0, phase - .69) * 3.9
	var aim := target - Vector2(0, extent.y * .47)
	if art == 0:
		aim = start.lerp(aim, minf(phase / .72, 1))
	if art == 2:
		aim += Vector2(-extent.x * (1.0 - phase), -extent.y * (1.0 - phase))
	if art == 3:
		extent.y *= clampf(phase * 3.1, .15, 1.0)
	draw_set_transform(aim, 0, Vector2(-1, 1) if art == 0 and facing_left else Vector2.ONE)
	draw_texture_rect_region(SPELLS, Rect2(-extent * .5, extent), _cell(SPELLS, 2, 2, art), Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO)

static func _cell(texture: Texture2D, columns: int, rows: int, index: int) -> Rect2:
	var width := float(texture.get_width()) / columns
	var height := float(texture.get_height()) / rows
	return Rect2((index % columns) * width, floori(float(index) / columns) * height, width, height)
