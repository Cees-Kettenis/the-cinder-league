extends Control

const GEAR = preload("res://art/gear.png")
const TRIM = preload("res://art/try-on.png")
const MAIL = preload("res://art/mail.png")
const ARENAS = preload("res://art/arenas.png")
const MOTION = preload("res://art/motion.png")
const MAIL_MOTION = preload("res://art/motion-mail.png")
const MAGE_MOTION = preload("res://art/motion-mage.png")
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
const MASKS := {
	"base": [Vector2(0,0),Vector2(1,0),Vector2(1,.27),Vector2(.93,.34),Vector2(.93,1),Vector2(0,1)],
	"helmet": [Vector2(.30,0),Vector2(.63,0),Vector2(.62,.09),Vector2(.51,.10),Vector2(.48,.17),Vector2(.39,.18),Vector2(.32,.14)],
	"chest": [Vector2(.08,.23),Vector2(.19,.17),Vector2(.40,.17),Vector2(.46,.22),Vector2(.57,.22),Vector2(.67,.32),Vector2(.59,.37),Vector2(.57,.49),Vector2(.69,.62),Vector2(.61,.66),Vector2(.37,.60),Vector2(.35,.34),Vector2(.14,.35)],
	"pants": [Vector2(.36,.56),Vector2(.59,.54),Vector2(.67,.65),Vector2(.66,.76),Vector2(.54,.81),Vector2(.46,.78),Vector2(.48,.67),Vector2(.36,.68),Vector2(.25,.83),Vector2(.10,.83),Vector2(.09,.72),Vector2(.31,.68)],
	"shoe_left": [Vector2(.105,.75),Vector2(.24,.785),Vector2(.22,.89),Vector2(.245,1),Vector2(.03,1),Vector2(.03,.91),Vector2(.085,.86)],
	"shoe_right": [Vector2(.455,.76),Vector2(.65,.75),Vector2(.67,.85),Vector2(.77,.91),Vector2(.79,1),Vector2(.46,1),Vector2(.445,.91)],
	"face": [Vector2(.515,.108),Vector2(.557,.109),Vector2(.558,.132),Vector2(.575,.149),Vector2(.55,.155),Vector2(.552,.176),Vector2(.53,.193),Vector2(.49,.176),Vector2(.46,.153),Vector2(.477,.124)],
	"hair": [Vector2(.564,.095),Vector2(.585,.103),Vector2(.563,.132),Vector2(.549,.129),Vector2(.535,.117),Vector2(.515,.12),Vector2(.504,.13),Vector2(.484,.117),Vector2(.507,.101),Vector2(.545,.096)],
}
var kind := "town"
var data: RefCounted
var left_loadout: Dictionary = {}
var right_loadout: Dictionary = {}
var right_style := ""
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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(queue_redraw)

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
			_cover(ARENAS, Rect2(0, arena * half + 2, ARENAS.get_width(), half - 4))
			_draw_battle()
		"spell":
			_avatar(Vector2(size.x * .24, size.y * .9), size.y * .63, left_loadout, false, skin, hair)
			_draw_spell(Vector2(size.x * .32, size.y * .60), Vector2(size.x * .70, size.y * .81), spell_art, fmod(elapsed, 1.9) / 1.9)
		"weapon":
			var item: Dictionary = data.items.get(left_loadout.get("weapon", ""), {})
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

func _avatar(feet: Vector2, height: float, gear: Dictionary, facing_left: bool, skin_index: int = 0, hair_index: int = 0, lean: float = 0.0) -> void:
	if height <= 0:
		return
	var scale_value := height / 1024.0
	draw_set_transform(feet, -lean if facing_left else lean, Vector2(-scale_value if facing_left else scale_value, scale_value))
	var top_left := Vector2(-310, -1024)
	var weapon: Dictionary = data.items.get(gear.get("weapon", ""), {})
	var holds_mace := int(weapon.get("art", 0)) == 1
	var base: Array = MASKS.base
	if holds_mace:
		base = [Vector2(0,0),Vector2(.72,0),Vector2(.73,.37),Vector2(.79,.42),
			Vector2(.80,.50),Vector2(.67,.54),Vector2(.69,1),Vector2(0,1)]
	_mesh(GEAR, top_left, base)
	var armor: Dictionary = gear.get("armor", {})
	for slot in ["pants", "shoes", "chest", "helmet", "shield"]:
		var item: Dictionary = data.items.get(armor.get(slot, ""), {})
		var tier := int(item.get("tier", 0))
		var texture := MAIL if tier >= 2 else (TRIM if tier == 1 else GEAR)
		var tint := Color("#928676") if item.is_empty() and not gear.is_empty() else Color.WHITE
		if slot == "shield":
			var oval: Array[Vector2] = []
			for point in 30:
				var theta := TAU * point / 30.0
				oval.append(Vector2(.199 + cos(theta) * .195, .507 + sin(theta) * .182))
			_mesh(texture, top_left, oval, tint)
		elif slot == "shoes":
			_mesh(texture, top_left, MASKS.shoe_left, tint)
			_mesh(texture, top_left, MASKS.shoe_right, tint)
		else:
			_mesh(texture, top_left, MASKS[slot], tint)
	if holds_mace:
		_mesh(MAIL, top_left, [Vector2(.67,.48),Vector2(.71,.35),Vector2(.80,.18),Vector2(.99,.18),
			Vector2(.99,.29),Vector2(.86,.37),Vector2(.8,.51),Vector2(.67,.53)])
	if not str(gear.get("enchant", "")).is_empty():
		_weapon_glow(Vector2(334, -680), 52.0, .6 + sin(elapsed * 4.0) * .12)
	if skin_index > 0:
		var tones := [Color.WHITE, Color("#e8bb9c"), Color("#c89270"), Color("#a57862")]
		_mesh(GEAR, top_left, MASKS.face, tones[clampi(skin_index, 0, tones.size() - 1)])
	if hair_index > 0:
		var hues := [Color.WHITE, Color("#d28b62"), Color("#cfd2df")]
		_mesh(GEAR, top_left, MASKS.hair, hues[clampi(hair_index, 0, hues.size() - 1)])
	draw_set_transform(Vector2.ZERO)

func _mesh(texture: Texture2D, origin: Vector2, mask: Array, tint: Color = Color.WHITE) -> void:
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	for point: Vector2 in mask:
		vertices.append(origin + Vector2(point.x * 768, point.y * 1024))
		uv.append(Vector2(point.x * .5, point.y))
	draw_polygon(vertices, PackedColorArray([tint]), uv, texture)

func _draw_battle() -> void:
	var feet: Array[Vector2] = []
	var height := minf(size.y * .76, size.x * .265)
	var side := int(event.get("side", -1))
	var action := str(event.get("action", ""))
	var phase := clampf(elapsed / ACTION_TIME, 0, 1)
	var animating := side >= 0 and phase < 1
	var shift := smoothstep(.04, .83, phase)
	for index in 2:
		var distance := float(positions[index])
		if animating and previous_positions.size() == 2:
			distance = lerpf(float(previous_positions[index]), distance, shift)
		var x := size.x * (.15 + .70 * distance / arena_width)
		var foot := Vector2(x, size.y * .88)
		feet.append(foot)
		draw_set_transform(foot + Vector2(height * .06, height * .008), 0.0, Vector2(1, .24))
		draw_circle(Vector2.ZERO, height * .24, Color(0.08, 0.07, 0.055, .26))
		draw_set_transform(Vector2.ZERO)
	for index in 2:
		var loadout := left_loadout if index == 0 else right_loadout
		_draw_fighter(feet[index], height, loadout, index, side, action, phase)
	if action == "cast" and animating and not event.get("miss", false):
		var attack_art: int = int(data.items.get((left_loadout if side == 0 else right_loadout).get("spell", ""), {}).get("art", 0))
		_draw_spell(feet[side] - Vector2(0, height * .58), feet[1 - side], attack_art, phase, side == 1)
	if animating and elapsed >= IMPACT_TIME:
		_draw_impact(feet, height, side, phase)

func _motion_atlas(loadout: Dictionary, side: int) -> Texture2D:
	if side == 1 and right_style == "mage":
		return MAGE_MOTION
	var chest: Dictionary = data.items.get(loadout.get("armor", {}).get("chest", ""), {})
	var weapon: Dictionary = data.items.get(loadout.get("weapon", ""), {})
	var tier := int(chest.get("tier", 0))
	var mace := int(weapon.get("art", 0)) == 1
	if tier >= 2 and mace:
		return MAIL_MOTION
	if tier == 0 and not mace:
		return MOTION
	return null

func _draw_fighter(feet: Vector2, height: float, loadout: Dictionary, index: int, actor: int, action: String, phase: float) -> void:
	var motion := _motion_atlas(loadout, index)
	var facing_left := index == 1
	var direction := -1.0 if facing_left else 1.0
	var lean := 0.0
	var pose := 0 if index == 1 and motion in [MAGE_MOTION, MAIL_MOTION] else -1
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
		if action == "attack" and pose == 2 and not str(loadout.get("enchant", "")).is_empty():
			var glow := feet + Vector2(height * .6 * direction, -height * .65)
			_weapon_glow(glow, height * .14, 1.0 - phase * .58)
	elif actor >= 0 and phase < 1 and elapsed >= IMPACT_TIME and event.damage + event.armor_hit > 0:
		var recoil := sin((phase - IMPACT_TIME / ACTION_TIME) * TAU) * height * .085
		feet.x -= recoil * direction
		lean = -.09 * recoil / maxf(1.0, height * .085)
	if motion != null and pose >= 0:
		_pose(motion, feet, height, pose, facing_left)
	else:
		_avatar(feet, height, loadout, facing_left, skin if index == 0 else 2, hair if index == 0 else 1, lean)

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
