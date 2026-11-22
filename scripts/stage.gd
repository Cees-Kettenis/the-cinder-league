extends Control

signal impact_reached
signal turn_animation_finished

const Symbol = preload("res://scripts/ui_symbol.gd")
const GEAR = preload("res://art/gear.png")
const GLADIATOR = preload("res://art/gladiator-base.png")
const TRIM = preload("res://art/try-on.png")
const MAIL = preload("res://art/mail.png")
const ARENAS = preload("res://art/arenas.png")
const SPELLS = preload("res://art/spells.png")
const TOWN = preload("res://art/town.png")
const STOCK = preload("res://art/stock.png")
const WEAPONS = preload("res://art/weapons.png")
const RIVAL_ARMOR = preload("res://art/rival-armor.png")
const RIVAL_HELMETS := [
	[Rect2(83, 70, 410, 302), Rect2(-91, -1023, 203, 166)],
	[Rect2(588, 49, 333, 388), Rect2(-92, -1008, 170, 183)],
	[Rect2(1080, 13, 361, 368), Rect2(-92, -1040, 174, 192)],
]
const RIVAL_CHESTS := [
	[Rect2(42, 455, 432, 562), Rect2(-204, -831, 365, 451)],
	[Rect2(555, 455, 408, 562), Rect2(-188, -835, 339, 455)],
	[Rect2(1036, 449, 465, 567), Rect2(-214, -834, 387, 456)],
]
const RIVAL_PALETTES := [Color.WHITE, Color("#aabdf0"), Color("#d9a4a1"), Color("#b6e0cb"), Color("#e6c38a")]
const WEAPON_SPRITES := {
	"dagger": [0, Vector2(171, 350), .37],
	"sword": [1, Vector2(137, 372), .51],
	"mace": [2, Vector2(164, 361), .53],
	"smith_sword": [3, Vector2(126, 378), .58],
	"court_mace": [4, Vector2(169, 341), .62],
	"warden_sword": [5, Vector2(123, 380), .70],
}
const SPELL_CONTACT := .60
const SPELL_COLORS := [Color("#ffc378"), Color("#cf9eff"), Color("#ffb66e"), Color("#7cdfff")]
const SPACE_PER_FIGHTER_HEIGHT := .37
const ARENA_MARGIN := 2.1
const KIT_SIZE := Vector2(768, 1024)
const BASE_SIZE := Vector2(1024, 1536)
const BASE_SCALE := Vector2(2.0 / 3.0, 2.0 / 3.0)
const BASE_ORIGIN := Vector2(-341, -1024)
const GRIP := Vector2(855, 649)
const SHOULDER := Vector2(672, 497)
const ELBOW := Vector2(670, 582)
const BODY_MASK := [Vector2(0, 0), Vector2(1024, 0), Vector2(1024, 478), Vector2(719, 478),
	Vector2(702, 490), Vector2(674, 510), Vector2(633, 524), Vector2(613, 548), Vector2(607, 577),
	Vector2(609, 623), Vector2(637, 681), Vector2(648, 742), Vector2(1024, 742), Vector2(1024, 1536), Vector2(0, 1536)]
const UPPER_ARM_MASK := [Vector2(615, 525), Vector2(638, 515), Vector2(687, 490), Vector2(710, 479),
	Vector2(737, 550), Vector2(710, 570), Vector2(680, 598), Vector2(648, 622), Vector2(609, 583)]
const FOREARM_MASK := [Vector2(620, 602), Vector2(650, 580), Vector2(681, 555), Vector2(710, 535),
	Vector2(935, 535), Vector2(935, 736), Vector2(641, 736)]
const TUNIC_EDGE := [Vector2(1024, 891), Vector2(713, 891), Vector2(669, 922), Vector2(595, 942),
	Vector2(507, 950), Vector2(367, 935), Vector2(265, 913), Vector2(0, 913)]
const HIPS := [Vector2(362, 935), Vector2(592, 932)]
const KNEES := [Vector2(259, 1127), Vector2(648, 1122)]
const THIGHS := [
	[Vector2(204, 884), Vector2(476, 916), Vector2(476, 991), Vector2(416, 1089), Vector2(368, 1150), Vector2(172, 1151), Vector2(173, 1050)],
	[Vector2(472, 887), Vector2(760, 884), Vector2(794, 1144), Vector2(516, 1146), Vector2(504, 1083), Vector2(463, 1000)],
]
const SHINS := [
	[Vector2(98, 1110), Vector2(417, 1110), Vector2(417, 1536), Vector2(98, 1536)],
	[Vector2(508, 1100), Vector2(903, 1100), Vector2(903, 1536), Vector2(508, 1536)],
]
const SKIN_TINTS := [Color.WHITE, Color(1.12, 1.09, 1.08), Color("#d2ad94"), Color("#a57862")]
const HAIR_TINTS := [Color.WHITE, Color(1.23, .86, .65), Color(.95, 1.05, 1.25)]
const SKIN_MASKS := [
	[Vector2(.441,.093),Vector2(.513,.084),Vector2(.563,.068),Vector2(.627,.094),Vector2(.624,.171),Vector2(.583,.205),Vector2(.555,.227),Vector2(.472,.198),Vector2(.390,.175),Vector2(.427,.129)],
	[Vector2(.175,.273),Vector2(.244,.273),Vector2(.339,.315),Vector2(.299,.364),Vector2(.264,.370),Vector2(.264,.446),Vector2(.229,.497),Vector2(.279,.522),Vector2(.270,.587),Vector2(.130,.587),Vector2(.126,.397)],
]
const HAIR_MASK := [Vector2(.338,.009),Vector2(.649,.009),Vector2(.649,.089),Vector2(.596,.093),Vector2(.566,.064),Vector2(.520,.087),Vector2(.497,.106),Vector2(.458,.103),Vector2(.434,.095),Vector2(.436,.125),Vector2(.469,.140),Vector2(.419,.159),Vector2(.365,.171),Vector2(.338,.158)]
const MASKS := {
	"helmet": [Vector2(.30,0),Vector2(.63,0),Vector2(.62,.09),Vector2(.51,.10),Vector2(.48,.17),Vector2(.39,.18),Vector2(.32,.14)],
	"chest": [Vector2(.123,.25),Vector2(.173,.203),Vector2(.30,.173),Vector2(.405,.170),Vector2(.47,.221),Vector2(.565,.216),Vector2(.629,.258),Vector2(.655,.307),Vector2(.593,.356),Vector2(.55,.387),Vector2(.543,.453),Vector2(.605,.489),Vector2(.66,.562),Vector2(.663,.622),Vector2(.587,.645),Vector2(.391,.64),Vector2(.399,.527),Vector2(.384,.436),Vector2(.352,.351),Vector2(.223,.331),Vector2(.143,.329)],
	"pants": [Vector2(.336,.646),Vector2(.494,.564),Vector2(.615,.55),Vector2(.663,.69),Vector2(.66,.761),Vector2(.577,.794),Vector2(.465,.788),Vector2(.441,.761),Vector2(.478,.667),Vector2(.384,.685),Vector2(.273,.795),Vector2(.116,.794),Vector2(.089,.722),Vector2(.171,.690),Vector2(.285,.689)],
	"shoe_left": [Vector2(.105,.75),Vector2(.24,.785),Vector2(.22,.89),Vector2(.245,1),Vector2(.03,1),Vector2(.03,.91),Vector2(.085,.86)],
	"shoe_right": [Vector2(.455,.76),Vector2(.65,.75),Vector2(.67,.85),Vector2(.77,.91),Vector2(.79,1),Vector2(.46,1),Vector2(.445,.91)],
}
const MAIL_HELMET := [Vector2(274, 114), Vector2(278, 88), Vector2(286, 66), Vector2(305, 42),
	Vector2(324, 25), Vector2(338, 15), Vector2(356, 17), Vector2(377, 25), Vector2(395, 39),
	Vector2(411, 60), Vector2(420, 83), Vector2(423, 101), Vector2(417, 118), Vector2(409, 115),
	Vector2(399, 87), Vector2(378, 90), Vector2(351, 96), Vector2(322, 105), Vector2(281, 128)]
const MAIL_CHEST := [Vector2(99, 254), Vector2(130, 211), Vector2(176, 190), Vector2(232, 178),
	Vector2(275, 203), Vector2(317, 234), Vector2(348, 248), Vector2(376, 242), Vector2(412, 214),
	Vector2(441, 225), Vector2(471, 248), Vector2(488, 279), Vector2(486, 300), Vector2(495, 335),
	Vector2(455, 362), Vector2(429, 383), Vector2(422, 415), Vector2(435, 470), Vector2(466, 519),
	Vector2(480, 557), Vector2(483, 585), Vector2(468, 603), Vector2(487, 634), Vector2(484, 650),
	Vector2(458, 646), Vector2(431, 625), Vector2(310, 655), Vector2(246, 623), Vector2(210, 580),
	Vector2(178, 537), Vector2(133, 446), Vector2(115, 374), Vector2(88, 327), Vector2(94, 290)]
const MAIL_LEGS := [
	[Vector2(121, 685), Vector2(271, 685), Vector2(278, 718), Vector2(269, 756), Vector2(237, 784),
		Vector2(208, 809), Vector2(195, 844), Vector2(173, 867), Vector2(147, 865), Vector2(89, 848),
		Vector2(90, 825), Vector2(107, 782), Vector2(95, 760), Vector2(101, 735)],
	[Vector2(329, 685), Vector2(472, 677), Vector2(486, 695), Vector2(495, 730), Vector2(492, 748),
		Vector2(466, 774), Vector2(457, 793), Vector2(472, 833), Vector2(460, 848), Vector2(417, 870),
		Vector2(399, 858), Vector2(378, 809), Vector2(370, 786), Vector2(347, 776), Vector2(329, 748)],
]
const MAIL_BOOTS := [
	[Vector2(91, 850), Vector2(121, 854), Vector2(153, 865), Vector2(155, 884), Vector2(139, 917),
		Vector2(156, 937), Vector2(172, 950), Vector2(178, 973), Vector2(175, 996), Vector2(80, 996),
		Vector2(57, 990), Vector2(58, 965), Vector2(71, 930), Vector2(78, 896), Vector2(82, 875)],
	[Vector2(404, 860), Vector2(450, 842), Vector2(467, 855), Vector2(475, 875), Vector2(498, 895),
		Vector2(541, 912), Vector2(565, 928), Vector2(578, 946), Vector2(584, 970), Vector2(559, 977),
		Vector2(492, 979), Vector2(445, 974), Vector2(396, 969), Vector2(399, 938), Vector2(409, 908)],
]
var kind := "town"
var data: RefCounted
var bout_items: Dictionary = {}
var left_loadout: Dictionary = {}
var right_loadout: Dictionary = {}
var skin := 0
var hair := 0
var rival_skin := 0
var rival_hair := 0
var rival_look: Dictionary = {}
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
var spell_art := 0
var demo := false
var full_arena := false
var lethal_bout := false
var has_pits := false
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
			impact_time = .27
			action_time = .79 if event.critical else .64
		"quick":
			impact_time = .17
			action_time = .58 if event.critical else .44
		"power":
			impact_time = .41
			action_time = .97 if event.critical else .87
		"cast":
			action_time = .80
			impact_time = action_time * SPELL_CONTACT
		"advance", "retreat":
			impact_time = .21
			action_time = .35
		"jump":
			impact_time = .51
			action_time = .67
		_:
			impact_time = .22
			action_time = .45
	if event.get("ring_out", false):
		action_time += .55
	elif _lethal_hit():
		action_time += .40
	queue_redraw()

func _lethal_hit() -> bool:
	return (lethal_bout and not event.is_empty() and not event.get("ring_out", false)
		and event.damage > 0 and event.health[1 - int(event.side)] <= 0)

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
			_draw_battle()
		"spell":
			_avatar(Vector2(size.x * .24, size.y * .9), size.y * .63, left_loadout, false, skin, hair)
			_draw_spell(Vector2(size.x * .32, size.y * .60), Vector2(size.x * .70, size.y * .81), minf(size.y * .72, size.x * .35), spell_art, fmod(elapsed, 1.9) / 1.9, 1.0)

func town_art_rect() -> Rect2:
	# Keep all four storefronts inside the visible band even on ultrawide screens.
	var scale := minf(size.x / TOWN.get_width(), size.y * 1.5 / TOWN.get_height())
	var extent := TOWN.get_size() * scale
	return Rect2((size - extent) * .5, extent)

func _draw_arena_backdrop(pan: float) -> void:
	if size.y <= 0 or size.x <= 0:
		return
	var half := ARENAS.get_height() * .5
	var region := Rect2(0, mini(arena, 1) * half + 2, ARENAS.get_width(), half - 4)
	var view_shape := size.x / size.y
	var source_shape := region.size.x / region.size.y
	var extent := region.size
	if view_shape > source_shape:
		extent.y /= view_shape / source_shape
	else:
		extent.x *= view_shape / source_shape
	if full_arena:
		extent *= .85
	var crop := Rect2(region.position + (region.size - extent) * Vector2(pan, .50), extent)
	draw_texture_rect_region(ARENAS, Rect2(Vector2.ZERO, size), crop)

func _item(id: String) -> Dictionary:
	var catalog: Dictionary = data.items if bout_items.is_empty() else bout_items
	return catalog.get(id, {})

func _avatar(feet: Vector2, height: float, gear: Dictionary, facing_left: bool, skin_index: int = 0, hair_index: int = 0,
		lean: float = 0.0, arm: Vector2 = Vector2.ZERO, wrist: float = 0.0, look: Dictionary = {},
		legs: Vector4 = Vector4.ZERO, trail: float = 0.0) -> void:
	if height <= 0:
		return
	var scale_value := height / 1024.0
	var width := scale_value * clampf(float(look.get("build", 100)) / 100.0, .85, 1.2)
	var body := Transform2D(-lean if facing_left else lean, feet).scaled_local(Vector2(-width if facing_left else width, scale_value))
	draw_set_transform_matrix(body)
	var shoulder := BASE_ORIGIN + SHOULDER * BASE_SCALE
	var elbow := shoulder + ((ELBOW - SHOULDER) * BASE_SCALE).rotated(arm.x)
	var forearm_angle := arm.x + arm.y
	var grip := elbow + ((GRIP - ELBOW) * BASE_SCALE).rotated(forearm_angle)
	var skin_tint: Color = SKIN_TINTS[skin_index]
	var leg_rig: Array[Transform2D] = []
	if not legs.is_zero_approx():
		leg_rig = _draw_legs(body, legs)
	# The grip moves with the forearm. Draw the fist over the weapon handle.
	_draw_weapon(gear, body, grip, forearm_angle + wrist, trail)
	_mesh(GLADIATOR, UPPER_ARM_MASK, Vector2.ONE, shoulder - (SHOULDER * BASE_SCALE).rotated(arm.x), BASE_SCALE, skin_tint, arm.x)
	_mesh(GLADIATOR, FOREARM_MASK, Vector2.ONE, elbow - (ELBOW * BASE_SCALE).rotated(forearm_angle), BASE_SCALE, skin_tint, forearm_angle)
	var torso: Array = BODY_MASK if leg_rig.is_empty() else BODY_MASK.slice(0, BODY_MASK.size() - 2) + TUNIC_EDGE
	_mesh(GLADIATOR, torso, Vector2.ONE, BASE_ORIGIN, BASE_SCALE)
	if skin_index > 0:
		for mask: Array in SKIN_MASKS:
			_mesh(GLADIATOR, mask, BASE_SIZE, BASE_ORIGIN, BASE_SCALE, skin_tint)
	if hair_index > 0:
		_mesh(GLADIATOR, HAIR_MASK, BASE_SIZE, BASE_ORIGIN, BASE_SCALE, HAIR_TINTS[hair_index])
	_draw_armor(gear.get("armor", {}), look, leg_rig)
	draw_set_transform(Vector2.ZERO)

func _draw_legs(body: Transform2D, pose: Vector4) -> Array[Transform2D]:
	var bones: Array[Transform2D] = []
	for side in 2:
		var hip: Vector2 = BASE_ORIGIN + HIPS[side] * BASE_SCALE
		var knee: Vector2 = BASE_ORIGIN + KNEES[side] * BASE_SCALE
		var hip_angle: float = pose[side * 2]
		var knee_angle: float = pose[side * 2 + 1]
		var thigh := Transform2D(hip_angle, hip - hip.rotated(hip_angle))
		var shin := thigh * Transform2D(knee_angle, knee - knee.rotated(knee_angle))
		bones.append(thigh)
		bones.append(shin)
		draw_set_transform_matrix(body * shin)
		_mesh(GLADIATOR, SHINS[side], Vector2.ONE, BASE_ORIGIN, BASE_SCALE)
		draw_set_transform_matrix(body * thigh)
		_mesh(GLADIATOR, THIGHS[side], Vector2.ONE, BASE_ORIGIN, BASE_SCALE)
	draw_set_transform_matrix(body)
	return bones

func _draw_armor(armor: Dictionary, look: Dictionary, leg_rig: Array[Transform2D]) -> void:
	for slot in ["pants", "shoes", "chest", "helmet", "shield"]:
		if not look.is_empty() and slot in ["chest", "helmet"]:
			var sheet: Array = RIVAL_CHESTS if slot == "chest" else RIVAL_HELMETS
			var index := int(look.get(slot, -1))
			if index >= 0 and index < sheet.size():
				var piece: Array = sheet[index]
				var tint: Color = RIVAL_PALETTES[clampi(int(look.get("palette", 0)), 0, RIVAL_PALETTES.size() - 1)]
				draw_texture_rect_region(RIVAL_ARMOR, piece[1], piece[0], tint)
			continue
		var item := _item(armor.get(slot, ""))
		if item.is_empty():
			continue
		var tier := int(item.get("tier", 0))
		var texture := MAIL if tier >= 2 else (TRIM if tier == 1 else GEAR)
		if texture == MAIL and slot != "shield":
			_draw_mail_piece(slot, leg_rig)
			continue
		match slot:
			"helmet": _mesh(texture, MASKS.helmet, KIT_SIZE, Vector2(-359, -1010))
			"chest": _mesh(texture, MASKS.chest, KIT_SIZE, Vector2(-296, -1034), Vector2(.89, .99))
			"pants": _mesh(texture, MASKS.pants, KIT_SIZE, Vector2(-307, -975), Vector2.ONE, Color.WHITE, 0.0, leg_rig)
			"shoes":
				_mesh(texture, MASKS.shoe_left, KIT_SIZE, Vector2(-290, -696), Vector2(.90, .68), Color.WHITE, 0.0, leg_rig, 0)
				_mesh(texture, MASKS.shoe_right, KIT_SIZE, Vector2(-290, -696), Vector2(.90, .68), Color.WHITE, 0.0, leg_rig, 1)
			"shield": _mesh(texture, shield_mask, KIT_SIZE, Vector2(-319, -1029))

func _draw_mail_piece(slot: String, leg_rig: Array[Transform2D]) -> void:
	match slot:
		"helmet":
			_mesh(MAIL, MAIL_HELMET, Vector2.ONE, Vector2(-399, -1027), Vector2(1.12, 1.0))
		"chest":
			_mesh(MAIL, MAIL_CHEST, Vector2.ONE, Vector2(-296, -1034), Vector2(.89, .99))
		"pants":
			_mesh(MAIL, MAIL_LEGS[0], Vector2.ONE, Vector2(-331, -1354), Vector2(1.0, 1.43), Color.WHITE, 0.0, leg_rig, 0)
			_mesh(MAIL, MAIL_LEGS[1], Vector2.ONE, Vector2(-312, -1354), Vector2(1.0, 1.43), Color.WHITE, 0.0, leg_rig, 1)
		"shoes":
			_mesh(MAIL, MAIL_BOOTS[0], Vector2.ONE, Vector2(-307, -699), Vector2(.92, .70), Color.WHITE, 0.0, leg_rig, 0)
			_mesh(MAIL, MAIL_BOOTS[1], Vector2.ONE, Vector2(-280, -686), Vector2(.90, .70), Color.WHITE, 0.0, leg_rig, 1)

func _draw_weapon(gear: Dictionary, body: Transform2D, grip: Vector2, angle: float, trail: float) -> void:
	var weapon := _item(gear.get("weapon", ""))
	if weapon.is_empty():
		return
	var sprite: Array = WEAPON_SPRITES.get(weapon.id, WEAPON_SPRITES.mace if int(weapon.art) == 1 else WEAPON_SPRITES.sword)
	var source := _cell(WEAPONS, 3, 2, int(sprite[0]))
	var scale_value: float = sprite[2]
	draw_set_transform_matrix(body * Transform2D(angle, grip))
	if trail > 0.0:
		var tip: Vector2 = (Vector2(source.size.x - 43, 38) - sprite[1]) * scale_value
		var tint := Color("#89dfff") if weapon.id == "warden_sword" else Color("#ffc278")
		var mace := int(weapon.art) == 1
		if event.action == "quick" and not mace:
			_draw_thrust_trail(tip, tint, trail)
		else:
			_draw_weapon_trail(tip, tint, trail, mace)
	draw_texture_rect_region(WEAPONS, Rect2(-sprite[1] * scale_value, source.size * scale_value), source)
	if not str(gear.get("enchant", "")).is_empty():
		_weapon_glow(Vector2(.54, -.57) * source.size * scale_value, 46.0, .6 + sin(elapsed * 4.0) * .12)
	draw_set_transform_matrix(body)

static func weapon_icon(item: Dictionary) -> AtlasTexture:
	var sprite: Array = WEAPON_SPRITES.get(item.id, WEAPON_SPRITES.mace if int(item.art) == 1 else WEAPON_SPRITES.sword)
	var icon := AtlasTexture.new()
	icon.atlas = WEAPONS
	icon.region = _cell(WEAPONS, 3, 2, int(sprite[0]))
	icon.filter_clip = true
	return icon

func _mesh(texture: Texture2D, mask: Array, source_size: Vector2, origin: Vector2, stretch: Vector2 = Vector2.ONE,
		tint: Color = Color.WHITE, angle: float = 0.0, leg_rig: Array[Transform2D] = [], leg: int = -1) -> void:
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var texture_size := texture.get_size()
	for point: Vector2 in mask:
		var pixel := point * source_size
		var vertex := origin + (pixel * stretch).rotated(angle)
		if not leg_rig.is_empty():
			var side := leg if leg >= 0 else int(vertex.x >= 0.0)
			var knee: float = BASE_ORIGIN.y + KNEES[side].y * BASE_SCALE.y
			vertex = leg_rig[side * 2 + int(vertex.y >= knee)] * vertex
		vertices.append(vertex)
		uv.append(pixel / texture_size)
	draw_polygon(vertices, PackedColorArray([tint]), uv, texture)

func fighter_height() -> float:
	return _fighter_height(_battle_view(positions))

func _fighter_height(view: Transform2D) -> float:
	return view.x.x / SPACE_PER_FIGHTER_HEIGHT if full_arena else minf(size.y * .76, size.x * .265)

func fighter_feet(index: int) -> Vector2:
	return _battle_view(positions) * Vector2(positions[index], 0)

func _battle_view(fighter_positions: Array) -> Transform2D:
	if not full_arena:
		return Transform2D(Vector2(size.x * .70 / arena_width, 0), Vector2.DOWN, size * Vector2(.15, .88))
	var left := float(fighter_positions[0])
	var right := float(fighter_positions[1])
	# Keep movement proportional to the sprites. Pull back only when the fighters need more room.
	var base_scale := minf(size.y * .34, size.x * .255) * SPACE_PER_FIGHTER_HEIGHT
	var scale_x := minf(base_scale, size.x / (right - left + 2.0 * ARENA_MARGIN))
	var half_view := size.x / (2.0 * scale_x) if scale_x > 0 else 0.0
	var center := arena_width * .5
	if half_view < center + ARENA_MARGIN:
		center = clampf((left + right) * .5, half_view - ARENA_MARGIN, arena_width + ARENA_MARGIN - half_view)
	return Transform2D(Vector2(scale_x, 0), Vector2.DOWN, Vector2(size.x * .5 - center * scale_x, size.y * .73))

func _draw_battle() -> void:
	var feet: Array[Vector2] = []
	var side := int(event.get("side", -1))
	var action := str(event.get("action", ""))
	var phase := clampf(elapsed / action_time, 0, 1)
	var animating := side >= 0 and phase < 1
	var approach := clampf(elapsed / impact_time, 0, 1)
	var recovery := clampf((elapsed - impact_time) / (action_time - impact_time), 0, 1)
	var shift := smoothstep(.17, 1.0, approach) if action == "jump" else smoothstep(.04, .90, phase)
	var stagger := _hit_recoil(recovery) if animating and elapsed >= impact_time else 0.0
	var visible_positions: Array[float] = [float(positions[0]), float(positions[1])]
	var pushed := false
	if animating and previous_positions.size() == 2:
		pushed = action == "power" and positions[1 - side] != previous_positions[1 - side]
		for index in 2:
			var travel := smoothstep(.01, .65, recovery) if pushed and index != side else shift
			visible_positions[index] = lerpf(float(previous_positions[index]), visible_positions[index], travel)
	var view := _battle_view(visible_positions)
	var height := _fighter_height(view)
	var pan := .5
	if full_arena and view.x.x > 0.0:
		var center := (size.x * .5 - view.origin.x) / view.x.x
		pan = clampf(center / arena_width, 0.0, 1.0)
	_draw_arena_backdrop(pan)
	if full_arena and has_pits:
		_draw_pit(view * Vector2(-1, 0), height)
		_draw_pit(view * Vector2(arena_width + 1, 0), height)
	for index in 2 if show_rival else 1:
		var distance := visible_positions[index]
		var foot := view * Vector2(distance, 0)
		if side >= 0 and index != side and not pushed:
			foot.x += height * .29 * stagger * (1.0 if side == 0 else -1.0)
		feet.append(foot)
		if distance < 0 or distance > arena_width:
			continue
		draw_set_transform(foot + Vector2(height * .06, height * .008), 0.0, Vector2(1, .24))
		draw_circle(Vector2.ZERO, height * .24, Color(0.08, 0.07, 0.055, .26))
		draw_set_transform(Vector2.ZERO)
	if animating and action in ["advance", "retreat", "jump"] and elapsed >= impact_time:
		_draw_dust(feet[side], height, recovery)
	if stagger > 0.0:
		_draw_dust(feet[1 - side], height, clampf(recovery * 1.4, 0.0, 1.0))
	if full_arena and not animating:
		var marker := feet[0] + Vector2(0, 7)
		draw_set_transform(marker, 0.0, Vector2(1, .24))
		draw_arc(Vector2.ZERO, height * .24, 0, TAU, 40, Color(1.0, .75, .42, .8), 2.5, true)
		draw_set_transform(Vector2.ZERO)
	var gap := absf(feet[1].x - feet[0].x) if feet.size() == 2 else 0.0
	if action == "power" and animating and previous_positions.size() == 2:
		gap = (previous_positions[1] - previous_positions[0]) * view.x.x
	var draw_order := [1 - side, side] if feet.size() == 2 and animating else range(feet.size())
	for index in draw_order:
		var loadout := left_loadout if index == 0 else right_loadout
		_draw_fighter(feet[index], height, loadout, index, gap, approach, recovery, phase)
	if action == "cast" and animating:
		var kit := left_loadout if side == 0 else right_loadout
		var attack_art := int(_item(kit.get("spell", "")).get("art", 0))
		var target := view * Vector2(visible_positions[1 - side], 0)
		var direction := 1.0 if side == 0 else -1.0
		var start := view * Vector2(visible_positions[side], 0)
		_draw_spell(start + Vector2(.20 * direction, -.56) * height, target, height, attack_art, phase, direction, event.miss)
	if animating and elapsed >= impact_time:
		_draw_impact(feet, height, side, recovery, view)

func _draw_fighter(feet: Vector2, height: float, loadout: Dictionary, index: int, gap: float, approach: float, recovery: float, phase: float) -> void:
	var actor := int(event.get("side", -1))
	var action := str(event.get("action", ""))
	var skin_index := skin if index == 0 else rival_skin
	var hair_index := hair if index == 0 else rival_hair
	var facing_left := index == 1
	var direction := -1.0 if facing_left else 1.0
	var lean := 0.0
	var arm := Vector2.ZERO
	var wrist := 0.0
	var legs := Vector4.ZERO
	var trail := 0.0
	var pulse := sin(phase * PI)
	if full_arena:
		arm.y = sin(idle_time * 2.8 + index * 2.2) * .025
	if actor == index and phase < 1:
		match action:
			"attack", "quick", "power":
				var windup := smoothstep(.0, .55, approach) * (1.0 - smoothstep(.58, .94, approach))
				var follow := smoothstep(.60, 1.0, approach) * (1.0 - smoothstep(.28, .96, recovery))
				var reach := clampf(gap - height * .38, 0, height * .38) * (.65 if event.miss else 1.0)
				var weight := .55 if action == "quick" else 1.0
				feet.x += direction * (reach * follow - height * .05 * windup) * weight
				lean = (.08 * follow - .09 * windup) * weight
				arm += Vector2(.48, -1.16) * windup * weight + Vector2(-.93, .55) * follow
				wrist = -.72 * windup * weight + .98 * follow
				trail = smoothstep(.63, .96, approach) * (1.0 - smoothstep(.04, .51, recovery)) * weight
				if action == "power":
					lean -= .07 * windup
					arm += Vector2(-.53, -.41) * windup
					wrist += .34 * follow
					legs = Vector4(.19, -.14, -.30, .19) * follow
			"advance", "retreat":
				var stride := sin(phase * TAU)
				feet.y -= absf(stride) * height * .029
				lean = pulse * (.09 if action == "advance" else -.09)
				arm += Vector2(.15, -.23) * stride
			"jump":
				var launch := smoothstep(.0, .13, approach) * (1.0 - smoothstep(.14, .26, approach))
				var flight := clampf((approach - .17) / .83, 0.0, 1.0)
				var airborne := sin(PI * flight)
				var landing := sin(PI * recovery)
				feet.y += height * (.045 * (launch + landing) - .31 * airborne)
				lean = .17 * airborne + .08 * (launch + landing)
				arm += Vector2(-.46, -.42) * airborne
				legs = Vector4(.62, .67, -.69, .91) * airborne + Vector4(-.21, .41, -.24, .40) * (launch + landing)
			"cast":
				var release := smoothstep(.44, 1.0, approach) * (1.0 - recovery)
				lean = .09 * release
				arm += Vector2(-.52, -.41) * release + Vector2(.25, -.63) * (pulse - release)
			"guard", "taunt", "sleep", "potion":
				lean = pulse * (-.10 if action in ["guard", "sleep"] else .08)
				arm += Vector2(-.24, -.47) * pulse
	elif actor >= 0 and elapsed >= impact_time:
		var recoil := _hit_recoil(recovery)
		lean = -.24 * recoil
		arm += Vector2(.35, .24) * recoil
		legs = Vector4(.32, -.19, -.19, .38) * recoil
		if event.get("ring_out", false):
			var fall := smoothstep(.46, .98, recovery)
			if fall >= .96:
				return
			feet.y += height * .035 * fall
			lean -= .25 * sin(PI * fall)
			height *= 1.0 - fall
			legs += Vector4(-.20, .37, .18, .62) * fall
		elif event.health[index] <= 0:
			var fall := smoothstep(.14, .96, recovery)
			feet.x -= fall * height * .28 * direction
			feet.y += height * .06 * fall
			lean -= (1.53 if _lethal_hit() else .80) * fall
			arm += Vector2(.24, .68) * fall
	_avatar(feet, height, loadout, facing_left, skin_index, hair_index, lean, arm, wrist, rival_look if facing_left else {}, legs, trail)

func _hit_recoil(recovery: float) -> float:
	if event.damage + event.armor_hit <= 0:
		return 0.0
	var weight := .48 if event.blocked else (1.32 if event.critical else 1.0)
	return weight * smoothstep(.0, .24, recovery) * (1.0 - smoothstep(.45, 1.0, recovery))

func _draw_dust(at: Vector2, height: float, progress: float) -> void:
	for index in 6:
		var spread := float(index) - 2.5
		var x := spread * height * (.04 + progress * .08)
		var y := -height * progress * (.07 + (index % 3) * .045)
		var alpha := .43 * sin(progress * PI) * (1.0 - progress)
		draw_circle(at + Vector2(x, y), height * (.012 + progress * .028), Color(.94, .77, .55, alpha), true, -1, true)

func _draw_pit(at: Vector2, height: float) -> void:
	var radius := height * .23
	draw_set_transform(at + Vector2(0, height * .018), 0.0, Vector2(1.0, .36))
	draw_circle(Vector2.ZERO, radius, Color("#704530"), true, -1, true)
	draw_circle(Vector2(0, -radius * .06), radius * .88, Color("#321f2b"), true, -1, true)
	draw_circle(Vector2(0, radius * .02), radius * .67, Color("#17151f"), true, -1, true)
	draw_arc(Vector2.ZERO, radius * .94, .1, PI - .1, 29, Color("#e3aa68"), height * .020, true)
	draw_set_transform(Vector2.ZERO)

func _draw_thrust_trail(tip: Vector2, tint: Color, pulse: float) -> void:
	var along := tip.normalized()
	var across := along.orthogonal()
	for index in 3:
		var offset := across * (float(index) - 1.0) * 24.0
		var start := tip * .35 + offset - along * 36.0
		var end := tip * (1.15 - .06 * index) + offset
		draw_line(start, end, Color(tint, pulse * .74), 11.0 - index * 2.0, true)

func _draw_weapon_trail(tip: Vector2, tint: Color, pulse: float, mace: bool) -> void:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var spread := (.95 if mace else 1.44) * pulse
	for edge in 2:
		for index in 14:
			var progress := float(index if edge == 0 else 13 - index) / 13.0
			var width := sin(progress * PI) * (.26 if mace else .18)
			var radius := 1.01 + width if edge == 0 else .97 - width * .52
			vertices.append(tip.rotated(-spread * progress) * radius)
			colors.append(Color(tint.lightened(.18) if edge == 0 else tint, pulse * (1.0 - progress) * (.91 if edge == 0 else .31)))
	draw_polygon(vertices, colors)

func _draw_impact(feet: Array[Vector2], height: float, side: int, recovery: float, view: Transform2D) -> void:
	var symbol := ""
	var at := feet[1 - side]
	if _lethal_hit():
		_draw_blood(at, height, 1.0 if side == 0 else -1.0, recovery)
	if event.damage + event.armor_hit > 0:
		var spark_color := Color("#c8edff") if event.blocked or event.armor_hit > 0 else Color("#ffc16e")
		var spark_center := at + Vector2(height * (.10 if side == 1 else -.10), -height * .54)
		if event.action == "power":
			spark_center.x = (view * Vector2(previous_positions[1 - side], 0)).x + height * (.10 if side == 1 else -.10)
			_draw_impact_burst(spark_center, height * .26, spark_color, recovery)
		if event.action == "cast":
			var kit := left_loadout if side == 0 else right_loadout
			var art := clampi(int(_item(kit.get("spell", "")).get("art", 0)), 0, SPELL_COLORS.size() - 1)
			spark_color = SPELL_COLORS[art]
		_draw_sparks(spark_center, height * (.44 if event.critical else .30), spark_color, recovery)
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

func _draw_impact_burst(at: Vector2, radius: float, tint: Color, recovery: float) -> void:
	var fade := 1.0 - smoothstep(.06, .28, recovery)
	if fade <= 0.0:
		return
	var outline := PackedVector2Array()
	for index in 12:
		var ray := Vector2.from_angle(index * TAU / 12.0 + .24)
		outline.append(at + ray * radius * (1.0 if index % 2 == 0 else .38))
	draw_colored_polygon(outline, Color(tint.lightened(.50), fade))
	outline.append(outline[0])
	draw_polyline(outline, Color(tint.darkened(.55), fade), 2.5, true)

func _draw_blood(feet: Vector2, height: float, direction: float, recovery: float) -> void:
	var flight := clampf(recovery * 1.7, 0, 1)
	var landing := feet + Vector2(direction * height * .68, 10)
	var pool_size := smoothstep(.54, 1.0, recovery)
	draw_set_transform(landing, 0.0, Vector2(1, .20))
	draw_circle(Vector2.ZERO, height * .12 * pool_size, Color("#831f2b"), true, -1, true)
	draw_set_transform(Vector2.ZERO)
	for index in 9:
		var speed := .12 + (index % 5) * .055
		var point := feet + Vector2(direction * (speed + float(index % 3) * .03) * flight,
			-.54 - speed * flight + .63 * flight * flight) * height
		draw_circle(point, height * (.006 + (index % 3) * .003), Color(.54, .075, .125, 1.0 - smoothstep(.65, .96, flight)), true, -1, true)

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

func _draw_spell(start: Vector2, target: Vector2, height: float, art: int, phase: float, direction: float, missed: bool = false) -> void:
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
	if missed:
		alpha *= 1.0 - smoothstep(.50, .71, phase)
	if alpha <= 0.0:
		return
	draw_set_transform(aim, 0, Vector2(mirror, 1))
	draw_texture_rect_region(SPELLS, Rect2(-extent * .5, extent), _cell(SPELLS, 2, 2, art), Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO)

static func _cell(texture: Texture2D, columns: int, rows: int, index: int) -> Rect2:
	var width := float(texture.get_width()) / columns
	var height := float(texture.get_height()) / rows
	return Rect2((index % columns) * width, floori(float(index) / columns) * height, width, height)
