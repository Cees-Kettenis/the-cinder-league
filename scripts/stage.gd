extends Control

signal impact_reached
signal turn_animation_finished

const Symbol = preload("res://scripts/ui_symbol.gd")
const GEAR = preload("res://art/gear.png")
const Rig = preload("res://scripts/fighter_rig.gd")
const Duel = preload("res://scripts/duel.gd")
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
const SHIELD_ORIGIN := Vector2(-319, -1029)
const SHIELD_CENTER := SHIELD_ORIGIN + Vector2(.199, .507) * KIT_SIZE

class FighterPoints:
	var hand := Vector2.ZERO
	var chest := Vector2.ZERO
	var shield := Vector2.ZERO
	var has_shield := false
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
var contact_hold_left := 0.0
var contact_hold_elapsed := 0.0
var impact_anchor_set := false
var impact_anchor := Vector2.ZERO
var wound_anchor := Vector2.ZERO

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
			var hold := minf(delta, contact_hold_left)
			contact_hold_left -= hold
			contact_hold_elapsed += hold
			elapsed = minf(elapsed + delta - hold, action_time)
			if before < impact_time and elapsed >= impact_time:
				if _landed_strike():
					elapsed = impact_time
					contact_hold_left = .075 if event.blocked or event.critical or event.action == "power" else .045
				impact_reached.emit()
			if elapsed >= action_time:
				turn_animation_finished.emit()
		queue_redraw()

func animate(change: Dictionary) -> void:
	previous_positions = positions.duplicate()
	positions = change.positions.duplicate()
	event = change
	elapsed = 0.0
	contact_hold_left = 0.0
	contact_hold_elapsed = 0.0
	impact_anchor_set = false
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
		"lunge":
			impact_time = .42
			action_time = .98 if event.critical else .85
		"cast":
			action_time = .80
			impact_time = action_time * SPELL_CONTACT
		"advance", "retreat":
			impact_time = .21
			action_time = .35
		"jump", "jump_back":
			impact_time = .51
			action_time = .67
		_:
			impact_time = .22
			action_time = .45
	if _landed_strike():
		action_time = maxf(action_time, impact_time + .35)
	if event.get("ring_out", false):
		action_time += .55
	elif _knockout():
		action_time += .78
	queue_redraw()

func _knockout() -> bool:
	return (not event.is_empty() and not event.get("ring_out", false)
		and event.damage > 0 and event.health[1 - int(event.side)] <= 0)

func _bloodied_hit() -> bool:
	return (event.damage > 0 and not event.get("ring_out", false)
		and (event.action in Duel.WEAPON_ACTIONS or event.action == "cast"))

func _landed_strike() -> bool:
	return not event.get("miss", false) and event.damage + event.armor_hit > 0 and event.action in Duel.WEAPON_ACTIONS

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
	var art_scale := minf(size.x / TOWN.get_width(), size.y * 1.5 / TOWN.get_height())
	var extent := TOWN.get_size() * art_scale
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
		pose: Rig.Pose = null, look: Dictionary = {}, root_tilt: float = 0.0, trail: float = 0.0) -> FighterPoints:
	if height <= 0:
		return null
	var scale_value := height / 1024.0
	var width := scale_value * clampf(float(look.get("build", 100)) / 100.0, .85, 1.2)
	var body := Transform2D(-root_tilt if facing_left else root_tilt, feet).scaled_local(Vector2(-width if facing_left else width, scale_value))
	var bones := Rig.transforms(Rig.Pose.new() if pose == null else pose)
	var hand := body * bones[Rig.WEAPON_WRIST]
	_draw_weapon(gear, hand, Rig.local(Rig.GRIP), trail)
	draw_set_transform_matrix(body)
	Rig.draw_skin(self, bones, skin_index, hair_index)
	_draw_armor(gear.get("armor", {}), look, body, bones)
	draw_set_transform(Vector2.ZERO)
	var points := FighterPoints.new()
	points.hand = hand * Rig.local(Rig.GRIP)
	points.chest = body * bones[Rig.SPINE] * Rig.local(Vector2(577, 606))
	points.shield = body * bones[Rig.OFF_WRIST] * SHIELD_CENTER
	points.has_shield = not str(gear.get("armor", {}).get("shield", "")).is_empty()
	return points

func _draw_armor(armor: Dictionary, look: Dictionary, body: Transform2D, bones: Array[Transform2D]) -> void:
	for slot in ["pants", "shoes", "chest", "helmet", "shield"]:
		match slot:
			"helmet": draw_set_transform_matrix(body * bones[Rig.HEAD])
			"chest": draw_set_transform_matrix(body * bones[Rig.SPINE])
			"shield": draw_set_transform_matrix(body * bones[Rig.OFF_WRIST])
			_: draw_set_transform_matrix(body)
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
			_draw_mail_piece(slot, bones)
			continue
		match slot:
			"helmet": _mesh(texture, MASKS.helmet, KIT_SIZE, Vector2(-359, -1010))
			"chest": _mesh(texture, MASKS.chest, KIT_SIZE, Vector2(-296, -1034), Vector2(.89, .99))
			"pants": _mesh(texture, MASKS.pants, KIT_SIZE, Vector2(-307, -975), Vector2.ONE, bones)
			"shoes":
				_mesh(texture, MASKS.shoe_left, KIT_SIZE, Vector2(-290, -696), Vector2(.90, .68), bones, 0)
				_mesh(texture, MASKS.shoe_right, KIT_SIZE, Vector2(-290, -696), Vector2(.90, .68), bones, 1)
			"shield": _mesh(texture, shield_mask, KIT_SIZE, SHIELD_ORIGIN)

func _draw_mail_piece(slot: String, bones: Array[Transform2D]) -> void:
	match slot:
		"helmet":
			_mesh(MAIL, MAIL_HELMET, Vector2.ONE, Vector2(-399, -1027), Vector2(1.12, 1.0))
		"chest":
			_mesh(MAIL, MAIL_CHEST, Vector2.ONE, Vector2(-296, -1034), Vector2(.89, .99))
		"pants":
			_mesh(MAIL, MAIL_LEGS[0], Vector2.ONE, Vector2(-331, -1354), Vector2(1.0, 1.43), bones, 0)
			_mesh(MAIL, MAIL_LEGS[1], Vector2.ONE, Vector2(-312, -1354), Vector2(1.0, 1.43), bones, 1)
		"shoes":
			_mesh(MAIL, MAIL_BOOTS[0], Vector2.ONE, Vector2(-307, -699), Vector2(.92, .70), bones, 0)
			_mesh(MAIL, MAIL_BOOTS[1], Vector2.ONE, Vector2(-280, -686), Vector2(.90, .70), bones, 1)

func _draw_weapon(gear: Dictionary, hand: Transform2D, grip: Vector2, trail: float) -> void:
	var weapon := _item(gear.get("weapon", ""))
	if weapon.is_empty():
		return
	var sprite: Array = WEAPON_SPRITES.get(weapon.id, WEAPON_SPRITES.mace if int(weapon.art) == 1 else WEAPON_SPRITES.sword)
	var source := _cell(WEAPONS, 3, 2, int(sprite[0]))
	var scale_value: float = sprite[2]
	draw_set_transform_matrix(hand.translated_local(grip))
	if trail > 0.0:
		var tip: Vector2 = (Vector2(source.size.x - 43, 38) - sprite[1]) * scale_value
		var tint := Color("#89dfff") if weapon.id == "warden_sword" else Color("#ffc278")
		var mace := int(weapon.art) == 1
		if event.action in ["lunge", "quick"] and not mace:
			_draw_thrust_trail(tip, tint, trail)
		else:
			_draw_weapon_trail(tip, tint, trail, mace)
	draw_texture_rect_region(WEAPONS, Rect2(-sprite[1] * scale_value, source.size * scale_value), source)
	if not str(gear.get("enchant", "")).is_empty():
		_weapon_glow(Vector2(.54, -.57) * source.size * scale_value, 46.0, .6 + sin(elapsed * 4.0) * .12)

static func weapon_icon(item: Dictionary) -> AtlasTexture:
	var sprite: Array = WEAPON_SPRITES.get(item.id, WEAPON_SPRITES.mace if int(item.art) == 1 else WEAPON_SPRITES.sword)
	var icon := AtlasTexture.new()
	icon.atlas = WEAPONS
	icon.region = _cell(WEAPONS, 3, 2, int(sprite[0]))
	icon.filter_clip = true
	return icon

func _mesh(texture: Texture2D, mask: Array, source_size: Vector2, origin: Vector2, stretch: Vector2 = Vector2.ONE,
		bones: Array[Transform2D] = [], leg: int = -1) -> void:
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var texture_size := texture.get_size()
	for point: Vector2 in mask:
		var pixel := point * source_size
		vertices.append(origin + pixel * stretch)
		uv.append(pixel / texture_size)
	var colors := PackedColorArray([Color.WHITE])
	if bones.is_empty():
		draw_polygon(vertices, colors, uv, texture)
		return
	# Keep the original triangle connections as the leggings bend across the joints.
	var triangles := Geometry2D.triangulate_polygon(vertices)
	for index in vertices.size():
		var point := vertices[index]
		var side := leg if leg >= 0 else int(point.x >= 0.0)
		vertices[index] = Rig.bend_armor(point, bones, side)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), triangles, vertices, colors, uv,
		PackedInt32Array(), PackedFloat32Array(), texture.get_rid())

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
	var shift := smoothstep(.17, 1.0, approach) if action in ["jump", "jump_back"] else smoothstep(.04, .90, phase)
	if action == "lunge":
		shift = smoothstep(.22, .97, approach)
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
	if height <= 0.0:
		return
	var knocked_out := animating and _knockout()
	var topple := smoothstep(.32, .76, recovery) if knocked_out else 0.0
	if topple > 0.0:
		var target_x := (view * Vector2(visible_positions[1 - side], 0)).x
		var room := size.x - target_x if side == 0 else target_x
		view.origin.x -= (1.0 if side == 0 else -1.0) * maxf(0.0, height * 1.27 * topple - room)
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
		var shadow := foot + Vector2(.06, .008) * height
		var shadow_radius := height * .24
		if index == 1 - side and knocked_out:
			shadow += Vector2(.61 if side == 0 else -.71, .22) * (topple * height)
			shadow_radius = height * lerpf(.24, .48, topple)
		draw_set_transform(shadow, 0.0, Vector2(1, .24))
		draw_circle(Vector2.ZERO, shadow_radius, Color(0.08, 0.07, 0.055, .26))
		draw_set_transform(Vector2.ZERO)
	if animating and (action in Duel.MOVEMENT or action == "lunge") and elapsed >= impact_time:
		_draw_dust(feet[side], height, recovery)
	if stagger > 0.0:
		_draw_dust(feet[1 - side], height, clampf(recovery * 1.4, 0.0, 1.0))
	if animating and action == "lunge" and approach > .22 and approach < .97:
		_draw_lunge_lines(feet[side], height, 1.0 if side == 0 else -1.0, approach)
	if knocked_out and recovery > .70:
		_draw_fall_ground(feet[1 - side], height, 1.0 if side == 0 else -1.0, recovery)
	if full_arena and not animating:
		var marker := feet[0] + Vector2(0, 7)
		draw_set_transform(marker, 0.0, Vector2(1, .24))
		draw_arc(Vector2.ZERO, height * .24, 0, TAU, 40, Color(1.0, .75, .42, .8), 2.5, true)
		draw_set_transform(Vector2.ZERO)
	var gap := absf(feet[1].x - feet[0].x) if feet.size() == 2 else 0.0
	if action == "power" and animating and previous_positions.size() == 2:
		gap = (previous_positions[1] - previous_positions[0]) * view.x.x
	var points: Array[FighterPoints] = [null, null]
	var draw_order := range(feet.size())
	if feet.size() == 2 and animating:
		# Keep the blocking shield or parrying weapon in front of the incoming swing.
		draw_order = [side, 1 - side] if event.blocked else [1 - side, side]
	for index in draw_order:
		var loadout := left_loadout if index == 0 else right_loadout
		points[index] = _draw_fighter(feet[index], height, loadout, index, gap, approach, recovery, phase)
	if action == "cast" and animating:
		var kit := left_loadout if side == 0 else right_loadout
		var attack_art := int(_item(kit.get("spell", "")).get("art", 0))
		var target := view * Vector2(visible_positions[1 - side], 0)
		var direction := 1.0 if side == 0 else -1.0
		var defender := points[1 - side]
		if event.blocked and defender != null and defender.has_shield:
			target.x = defender.shield.x - direction * height * .09
		_draw_spell(points[side].hand, target, height, attack_art, phase, direction, event.miss)
	if animating and elapsed >= impact_time:
		var contact_offset: float = (previous_positions[1 - side] - visible_positions[1 - side]) * view.x.x if pushed else 0.0
		_draw_impact(feet, points[1 - side], height, side, recovery, contact_offset, view)

func _draw_fighter(feet: Vector2, height: float, loadout: Dictionary, index: int, gap: float, approach: float, recovery: float,
		phase: float) -> FighterPoints:
	var actor := int(event.get("side", -1))
	var action := str(event.get("action", ""))
	var skin_index := skin if index == 0 else rival_skin
	var hair_index := hair if index == 0 else rival_hair
	var facing_left := index == 1
	var direction := -1.0 if facing_left else 1.0
	var pose := Rig.Pose.new()
	var root_tilt := 0.0
	var trail := 0.0
	var pulse := sin(phase * PI)
	var shielded := not str(loadout.get("armor", {}).get("shield", "")).is_empty()
	if full_arena:
		var breath := sin(idle_time * 2.8 + index * 2.2)
		pose.spine = .017 * breath
		pose.head = -.018 * breath
		pose.weapon_arm.y = .025 * breath
		pose.off_arm.x = -.024 * breath
	if actor == index and phase < 1:
		match action:
			"lunge":
				var coil := smoothstep(.0, .22, approach) * (1.0 - smoothstep(.37, .76, approach))
				var strike := smoothstep(.61, .99, approach) * (1.0 - smoothstep(.17, .90, recovery))
				var plant := smoothstep(.37, .93, approach) * (1.0 - smoothstep(.22, .92, recovery))
				var stride := sin(TAU * clampf((approach - .22) / .66, 0.0, 1.0)) * (1.0 - plant)
				var mace := int(_item(loadout.get("weapon", "")).get("art", 0)) == 1
				feet.x -= direction * height * (.055 * coil + (.09 if event.miss else .022) * strike)
				feet.y += height * (.036 * (coil + plant) - .018 * absf(stride))
				pose.pelvis = -.05 * coil + .07 * plant
				pose.spine += -.12 * coil + .12 * strike
				pose.head += .12 * coil - .10 * strike
				pose.rear_leg = Vector3(.22, -.12, -.09) * plant + Vector3(-.22, .31, -.10) * coil
				pose.rear_leg += Vector3(.39, -.23, -.16) * stride
				pose.lead_leg = Vector3(-.37, .36, -.03) * plant + Vector3(-.23, .32, -.09) * coil
				pose.lead_leg += Vector3(-.38, .27, .11) * stride
				pose.weapon_arm += (Vector3(-.30, -1.21, -.51) if mace else Vector3(.47, -.85, -.64)) * coil
				pose.weapon_arm += (Vector3(-.75, .56, 1.17) if mace else Vector3(-.83, .54, .90)) * strike
				pose.off_arm += Vector3(-.20, -.32, .16) * coil + Vector3(.38, -.21, .19) * strike
				trail = smoothstep(.72, .97, approach) * (1.0 - smoothstep(.09, .43, recovery))
			"attack", "quick", "power":
				var windup := smoothstep(.0, .55, approach) * (1.0 - smoothstep(.58, .94, approach))
				var follow := smoothstep(.60, 1.0, approach) * (1.0 - smoothstep(.28, .96, recovery))
				var weight := .55 if action == "quick" else (1.25 if action == "power" else 1.0)
				var reach := clampf(gap - height * .38, 0, height * .32) * (.65 if event.miss else 1.0)
				feet.x += direction * (reach * follow - height * .05 * windup) * weight
				feet.y += height * (.031 * windup + .025 * follow) * weight
				pose.pelvis = (.045 * follow - .045 * windup) * weight
				pose.spine += (.12 * follow - .24 * windup) * weight
				pose.neck = .11 * windup * weight
				pose.head += .09 * windup - .11 * follow
				pose.weapon_arm += Vector3(.36, -.93, -.59) * windup * weight + Vector3(-.77, .55, .85) * follow
				pose.off_arm += (Vector3(-.15, -.50, .17) * windup + Vector3(.31, -.19, .16) * follow) * weight
				pose.rear_leg = (Vector3(-.16, -.06, .22) * windup + Vector3(.20, -.18, -.07) * follow) * weight
				pose.lead_leg = (Vector3(-.12, .26, -.15) * windup + Vector3(-.22, .26, -.06) * follow) * weight
				trail = smoothstep(.63, .96, approach) * (1.0 - smoothstep(.04, .51, recovery)) * minf(weight, 1.0)
				if action == "power":
					pose.weapon_arm += Vector3(-.35, -.25, 0) * windup + Vector3(0, 0, .36) * follow
			"advance", "retreat":
				var forward := action == "advance"
				var stride := float(1 if forward else -1)
				var root_progress := smoothstep(.04, .90, phase)
				var first_step := smoothstep(.04, .49, phase)
				var follow_step := smoothstep(.49, .94, phase)
				var first_lift := .5 - .5 * cos(first_step * TAU)
				var follow_lift := .5 - .5 * cos(follow_step * TAU)
				var crouch := 51.0 * pulse
				var spaces := absf(positions[index] - previous_positions[index])
				var step_size := minf(spaces * SPACE_PER_FIGHTER_HEIGHT * 1536.0, 490.0) * stride
				var first := Vector2(step_size * (first_step - root_progress), -crouch - 107.0 * first_lift)
				var second := Vector2(step_size * (follow_step - root_progress), -crouch - 92.0 * follow_lift)
				feet.y += height * crouch / 1536.0
				pose.lead_leg = Rig.walk_leg(1, first if forward else second, -.16 * first_lift if forward else .12 * follow_lift)
				pose.rear_leg = Rig.walk_leg(0, second if forward else first, .12 * follow_lift if forward else -.16 * first_lift)
				var arm_swing := sin(phase * TAU) * stride
				pose.spine += .13 * pulse * stride
				pose.neck = -.09 * pulse * stride
				pose.head += .06 * (follow_lift - first_lift)
				pose.weapon_arm += Vector3(.29, -.36, .15) * arm_swing
				pose.off_arm += Vector3(-.32, -.19, .20) * arm_swing
			"jump", "jump_back":
				var launch := smoothstep(.0, .14, approach) * (1.0 - smoothstep(.16, .29, approach))
				var flight := clampf((approach - .17) / .83, 0.0, 1.0)
				var airborne := sin(PI * flight)
				var landing := sin(PI * recovery)
				feet.y += height * (.062 * launch + .074 * landing - .34 * airborne)
				pose.pelvis = .065 * airborne
				pose.spine += -.12 * launch + .19 * airborne + .17 * landing
				pose.neck = -.15 * airborne - .10 * landing
				pose.head += -.10 * launch + .13 * airborne + .08 * landing
				pose.weapon_arm += Vector3(.29, -.71, -.17) * launch + Vector3(-.51, -.55, .40) * airborne
				pose.weapon_arm += Vector3(-.26, -.32, .19) * landing
				pose.off_arm += Vector3(.32, -.25, .19) * launch + Vector3(-.53, -.64, .29) * airborne
				pose.off_arm += Vector3(-.30, -.32, .13) * landing
				pose.rear_leg = Vector3(.49, -.56, .63) * airborne + Vector3(.31, -.52, .21) * (launch + landing)
				pose.lead_leg = Vector3(-.65, .97, -.48) * airborne + Vector3(-.34, .56, -.22) * (launch + landing)
				if action == "jump_back":
					pose.spine -= .38 * airborne
					pose.weapon_arm += Vector3(.43, -.25, .26) * airborne
					pose.rear_leg += Vector3(.17, -.16, .08) * airborne
			"cast":
				var release := smoothstep(.44, 1.0, approach) * (1.0 - recovery)
				pose.spine += .17 * release
				pose.head -= .08 * release
				pose.weapon_arm += Vector3(-.57, -.41, .47) * release + Vector3(.31, -.70, -.28) * (pulse - release)
				pose.off_arm += Vector3(-.33, -.42, .25) * pulse
				pose.lead_leg = Vector3(-.15, .19, -.04) * release
			"guard":
				_brace(pose, smoothstep(.0, .32, phase) * (1.0 - smoothstep(.67, 1.0, phase)), shielded)
			"taunt", "sleep", "potion":
				pose.spine += pulse * (-.16 if action in ["guard", "sleep"] else .11)
				pose.head += pulse * (.26 if action == "sleep" else -.09)
				pose.weapon_arm += Vector3(-.24, -.47, .29) * pulse
				pose.off_arm += Vector3(-.32, -.56, .14) * pulse
				pose.rear_leg = Vector3(.08, -.14, .06) * pulse
				pose.lead_leg = Vector3(-.07, .15, -.08) * pulse
	elif actor >= 0 and elapsed >= impact_time:
		var recoil := _hit_recoil(recovery)
		pose.pelvis = -.07 * recoil
		pose.spine -= .36 * recoil
		pose.neck -= .20 * recoil
		pose.head += .13 * recoil
		pose.weapon_arm += Vector3(.35, .24, -.45) * recoil
		pose.off_arm += Vector3(.35, -.49, .26) * recoil
		pose.rear_leg = Vector3(.33, -.30, -.08) * recoil
		pose.lead_leg = Vector3(-.19, .39, -.23) * recoil
		if event.get("ring_out", false):
			var fall := smoothstep(.46, .98, recovery)
			if fall >= .96:
				return null
			feet.y += height * .035 * fall
			root_tilt = -.25 * sin(PI * fall)
			height *= 1.0 - fall
			pose.rear_leg += Vector3(-.20, .37, -.11) * fall
			pose.lead_leg += Vector3(.18, .62, -.30) * fall
		elif _knockout():
			var buckle := smoothstep(.08, .36, recovery)
			var topple := smoothstep(.32, .76, recovery)
			var bounce := sin(PI * clampf((recovery - .72) / .21, 0.0, 1.0))
			feet.x -= direction * height * (.06 * buckle + .17 * topple)
			feet.y += height * (.15 * buckle + .035 * topple - .055 * bounce)
			root_tilt = -1.40 * topple + .10 * bounce
			pose.pelvis += -.12 * buckle + .17 * topple
			pose.spine += .40 * buckle - .26 * topple
			pose.neck += .23 * buckle + .14 * topple
			pose.head += -.14 * buckle + .30 * topple
			pose.rear_leg += Vector3(.30, -.69, .33) * buckle + Vector3(-.15, .30, -.13) * topple
			pose.lead_leg += Vector3(-.44, .82, -.30) * buckle + Vector3(.20, -.25, .11) * topple
			pose.weapon_arm += Vector3(.17, -.16, .08) * buckle + Vector3(.26, .51, -.48) * topple
			pose.weapon_arm.z += 1.15 * smoothstep(.74, .98, recovery)
			pose.off_arm += Vector3(-.16, -.35, .19) * buckle + Vector3(.34, .33, -.40) * topple
	if actor >= 0 and index != actor and phase < 1.0:
		if event.blocked:
			var catch_blow := smoothstep(.28, .92, approach) * (1.0 - smoothstep(.06, .41, recovery))
			_brace(pose, catch_blow, shielded)
		elif event.miss and action in Duel.WEAPON_ACTIONS:
			var dodge := smoothstep(.54, .98, approach) * (1.0 - smoothstep(.13, .82, recovery))
			feet.x -= direction * height * .08 * dodge
			feet.y += height * .065 * dodge
			pose.spine -= .28 * dodge
			pose.neck += .12 * dodge
			pose.head -= .10 * dodge
			pose.rear_leg += Vector3(.19, -.39, .12) * dodge
			pose.lead_leg += Vector3(-.20, .42, -.18) * dodge
	return _avatar(feet, height, loadout, facing_left, skin_index, hair_index, pose, rival_look if facing_left else {}, root_tilt, trail)

func _brace(pose: Rig.Pose, amount: float, shielded: bool) -> void:
	pose.spine += .10 * amount
	pose.neck -= .11 * amount
	pose.head += .14 * amount
	if shielded:
		pose.off_arm = pose.off_arm.lerp(Vector3(-.99, -.58, 1.46), amount)
		pose.weapon_arm += Vector3(.15, -.26, .17) * amount
	else:
		pose.weapon_arm = pose.weapon_arm.lerp(Vector3(-.44, -.57, .72), amount)
		pose.off_arm += Vector3(-.31, -.50, .24) * amount
	pose.rear_leg += Vector3(.10, -.24, .12) * amount
	pose.lead_leg += Vector3(-.13, .26, -.11) * amount

func _hit_recoil(recovery: float) -> float:
	if event.damage + event.armor_hit <= 0:
		return 0.0
	var weight := .30 if event.blocked else (.58 if event.damage <= 0 else 1.12)
	if event.critical:
		weight *= 1.22
	return weight * smoothstep(.0, .13, recovery) * (1.0 - smoothstep(.22, .82, recovery))

func _draw_dust(at: Vector2, height: float, progress: float) -> void:
	for index in 6:
		var spread := float(index) - 2.5
		var x := spread * height * (.04 + progress * .08)
		var y := -height * progress * (.07 + (index % 3) * .045)
		var alpha := .86 * sin(progress * PI) * (1.0 - progress)
		var point := at + Vector2(x, y)
		var radius := height * (.022 + progress * .042)
		draw_circle(point, radius * 1.10, Color("#69432f", alpha * .76), true, -1, true)
		draw_circle(point - Vector2(0, radius * .13), radius, Color("#ffddab", alpha), true, -1, true)

func _draw_pit(at: Vector2, height: float) -> void:
	var radius := height * .23
	draw_set_transform(at + Vector2(0, height * .018), 0.0, Vector2(1.0, .36))
	draw_circle(Vector2.ZERO, radius, Color("#704530"), true, -1, true)
	draw_circle(Vector2(0, -radius * .06), radius * .88, Color("#321f2b"), true, -1, true)
	draw_circle(Vector2(0, radius * .02), radius * .67, Color("#17151f"), true, -1, true)
	draw_arc(Vector2.ZERO, radius * .94, .1, PI - .1, 29, Color("#e3aa68"), height * .020, true)
	draw_set_transform(Vector2.ZERO)

func _draw_lunge_lines(feet: Vector2, height: float, direction: float, approach: float) -> void:
	var strength := smoothstep(.22, .49, approach) * (1.0 - smoothstep(.70, .97, approach))
	for index in 4:
		var tip := feet + Vector2(-direction * height * (.16 + index * .095), -height * (.31 + index * .101))
		var trail := Vector2(-direction * height * (.12 + index * .04) * strength, 0)
		draw_line(tip, tip + trail, Color(.99, .89, .70, strength * .64), 2.5, true)

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

func _draw_impact(feet: Array[Vector2], defender: FighterPoints, height: float, side: int, recovery: float,
		contact_offset: float, view: Transform2D) -> void:
	var symbol := ""
	var at := feet[1 - side]
	var direction := 1.0 if side == 0 else -1.0
	var spell: bool = event.action == "cast"
	var weapon: bool = event.action in Duel.WEAPON_ACTIONS
	if defender != null and event.damage + event.armor_hit > 0:
		if not impact_anchor_set:
			var chest_at_impact := defender.chest + Vector2(contact_offset, 0)
			var struck := chest_at_impact
			if event.blocked:
				struck = defender.shield if defender.has_shield else defender.hand
				struck += Vector2(-direction * .085, -.015) * height
			var inverse := view.affine_inverse()
			impact_anchor = inverse * struck / Vector2(1.0, height)
			wound_anchor = inverse * chest_at_impact / Vector2(1.0, height)
			impact_anchor_set = true
		# Let the debris stay at the impact as the defender recoils and the camera pans.
		var contact := view * (impact_anchor * Vector2(1.0, height))
		var chest := view * (wound_anchor * Vector2(1.0, height))
		var particle_phase := clampf((elapsed - impact_time + contact_hold_elapsed) / .43, 0.0, 1.0)
		var metal: bool = event.blocked or event.armor_hit > 0
		var tint := Color("#ffdc79") if metal else Color("#ffead1")
		if spell and not metal:
			var kit := left_loadout if side == 0 else right_loadout
			var art := clampi(int(_item(kit.get("spell", "")).get("art", 0)), 0, SPELL_COLORS.size() - 1)
			tint = SPELL_COLORS[art]
		if metal or spell or event.critical:
			_draw_sparks(contact, height * (.48 if event.critical else .36), tint, particle_phase)
		if weapon:
			var large: bool = metal or event.action == "power" or event.critical
			_draw_impact_burst(contact, height * (.21 if large else .13), tint, particle_phase)
		if event.armor_hit > 0:
			var armor_after: Array = event.get("armor", [])
			var broken: bool = armor_after.size() == 2 and armor_after[1 - side] == 0
			_draw_armor_chips(contact, height, direction, particle_phase, broken)
		if _bloodied_hit():
			_draw_blood_drops(chest + Vector2(-direction * height * .045, 0), height, direction, particle_phase, _knockout())
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
	if symbol.is_empty() or (_knockout() and recovery > .55):
		return
	var extent := lerpf(42.0, 28.0, recovery)
	var center := Vector2(at.x, maxf(36.0, at.y - height * .94 - recovery * 30.0))
	draw_circle(center, extent * .58, Color("#392831"), true, -1, true)
	Symbol.paint(self, symbol, center - Vector2.ONE * extent * .5, extent)

func _draw_fall_ground(feet: Vector2, height: float, direction: float, recovery: float) -> void:
	var ground := feet + Vector2(direction * .99, .27) * height
	_draw_dust(ground, height, clampf((recovery - .70) / .25, 0, 1))
	if _bloodied_hit():
		var spread := smoothstep(.80, .97, recovery) * height * (.080 if lethal_bout else .063)
		draw_set_transform(ground, 0.0, Vector2(1.0, .22))
		draw_circle(Vector2.ZERO, spread, Color("#92283c"), true, -1, true)
		draw_set_transform(Vector2.ZERO)

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
	draw_polyline(outline, Color("#533027", fade), 3.0, true)

func _draw_armor_chips(at: Vector2, height: float, direction: float, recovery: float, broken: bool) -> void:
	var flight := clampf(recovery / .82, 0, 1)
	var fade := 1.0 - smoothstep(.34, 1.0, flight)
	for index in (7 if broken else 4):
		var speed := float(index) * .104 - .29
		var lift := .33 + (index % 3) * .18
		var point := at + Vector2(direction * speed * flight, -.03 - lift * flight + .74 * flight * flight) * height
		var sliver := Vector2.from_angle(index * 1.93 + flight * 6.0) * height * (.024 if broken else .016)
		var across := sliver.orthogonal() * .46
		var tint := Color("#fff6ce") if index % 2 == 0 else Color("#e2a66d")
		var chip := PackedVector2Array([point - sliver, point + across, point + sliver, point - across])
		draw_colored_polygon(chip, Color(tint, fade))
		chip.append(chip[0])
		draw_polyline(chip, Color("#673b31", fade), 1.5, true)

func _draw_blood_drops(at: Vector2, height: float, direction: float, recovery: float, finishing: bool) -> void:
	var flight := clampf(recovery / (.48 if finishing else .65), 0, 1)
	var fade := 1.0 - smoothstep(.18, 1.0, flight)
	for index in (5 if finishing else 3):
		var spread := float(index) * .065 + .13
		var point := at + Vector2(direction * spread * flight, -.018 - (.10 + spread * .56) * flight + .32 * flight * flight) * height
		var radius := height * (.013 - .001 * (index % 3))
		draw_circle(point, radius * 1.17, Color("#591c30", fade), true, -1, true)
		draw_circle(point, radius, Color("#c54553", fade), true, -1, true)

func _draw_sparks(at: Vector2, radius: float, tint: Color, recovery: float) -> void:
	var progress := clampf(recovery / .92, 0, 1)
	var fade := 1.0 - smoothstep(.03, 1.0, progress)
	var spread := lerpf(.31, 1.23, progress) * radius
	for index in 10:
		var ray := Vector2.from_angle(float(index) * TAU / 10.0 + .31)
		var point := at + ray * spread * (1.0 if index % 2 == 0 else .66)
		var length := radius * (.26 if index % 3 == 0 else .17)
		draw_line(point - ray * length, point, Color("#673b31", fade), 5.0, true)
		draw_line(point - ray * length, point, Color(tint, fade), 3.0, true)
		if index % 2 == 0:
			draw_circle(point, 2.5 + fade, Color(tint.lightened(.38), fade), true, -1, true)

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
