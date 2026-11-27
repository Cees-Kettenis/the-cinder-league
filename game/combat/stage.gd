extends Control
## Draws the town, fighter previews, and arena. Duel events supply the outcome of each animated move.

signal impact_reached
signal turn_animation_finished

const Symbol = preload("res://game/screens/ui_symbol.gd")
const Armor = preload("res://game/combat/armor_art.gd")
const Rig = preload("res://game/combat/fighter_rig.gd")
const MagicEffects = preload("res://game/combat/magic_effects.gd")
const Duel = preload("res://game/combat/duel.gd")
const Data = preload("res://game/catalog/data.gd")
const Content = preload("res://game/catalog/content_catalog.gd")
const BackdropArt = preload("res://game/screens/backdrop_art.gd")
const ArenaAmbience = preload("res://game/screens/arena/arena_ambience.gd")
const TownAmbience = preload("res://game/screens/town/town_ambience.gd")
const SPELLS = preload("res://content/spells/shared/projectiles.png")
const TOWN_DESIGN_SIZE := TownAmbience.DESIGN_SIZE
const TOWN_GROUND_HORIZON := 540.0
const TOWN_BACKGROUND_GAP := 27.0
const TOWN_WALK_STEP := 410.0
const MAX_WALK_STEP := 490.0
const GLASSGUARD = preload("res://content/spells/shared/glass-crucible-icons.png")
const POCKET_ANVIL = preload("res://content/spells/pocket-anvil/icon.png")
const BASTION_SPELLS := {7: preload("res://content/spells/dawnbolt/effect.webp"), 8: preload("res://content/spells/sunseal/effect.webp")}
const RIVAL_PALETTES := [Color.WHITE, Color("#c5d5e5"), Color("#e1ac96"), Color("#a2b1ac"), Color("#d2bc9e")]
const SPELL_CONTACT := .60
const FIREBALL_ART := 0
const FALLING_EMBER_ART := 2
const FIREBALL_RELEASE := .28
const SPELL_PREVIEW_DURATION := 1.9
const SPELL_PREVIEW_INTERVAL := 5.0
const MOVEMENT_PREVIEW_CONTACT := .43
const MOVEMENT_PREVIEW_RESET := .72
const SPELL_COLORS := [Color("#ffc378"), Color("#cf9eff"), Color("#ffb66e"), Color("#7cdfff"),
	Color("#e59bff"), Color("#d5b4e9"), Color("#ff855d"), Color("#f6c558"), Color("#ffc55e")]
const FIRE_CORES := {0: Color("#fff9bd"), 2: Color("#ffad65"), 3: Color("#c5f6ff"), 6: Color("#ffd777"), 8: Color("#fff0a6")}
const FIRE_EDGES := {0: Color("#ff5025"), 2: Color("#ff662b"), 3: Color("#366fea"), 6: Color("#f04d78"), 8: Color("#ff7a36")}
const STRIKE_COLORS := {"quick": Color("#7ee8ff"), "attack": Color("#ffca6e"),
	"power": Color("#ff9156"), "lunge": Color("#a5eaff")}
const STRIKE_RELEASE := {"quick": .57, "attack": .73, "power": .83, "lunge": .76}
const SWING_TRACE_TIME := .10
const SPACE_PER_FIGHTER_HEIGHT := .37
const ARENA_MARGIN := 2.1
const SHIELD_CENTER := Armor.SHIELD_CENTER

class FighterPoints:
	var hand := Vector2.ZERO
	var weapon_tip := Vector2.ZERO
	var chest := Vector2.ZERO
	var shield := Vector2.ZERO
	var has_shield := false
	var neck := Vector2.ZERO
	var elbow := Vector2.ZERO
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
var arena := 0:
	set(value):
		arena = value
		if is_node_ready():
			_sync_backdrop()
var positions: Array = [3, 7]
var previous_positions: Array = []
var arena_width := 10
var event: Dictionary = {}
var elapsed := 0.0
var action_time := .54
var impact_time := .24
var idle_time := 0.0
var spell_art := 0
# Shops can place the live preview directly on their own background.
var open_preview := false
var preview_spell_icon: Texture2D
var preview_spell_effect := "damage"
var preview_spell_power := 0
var preview_etching_rank := 1
var wards: Array = [0, 0]
var enchantments: Array = [0, 0]
var etching_ranks: Array[int] = [1, 1]
var full_arena := false
var lethal_bout := false
var finisher := ""
var finishing_spell_art := -1
var has_pits := false
var impact_played := false
var contact_hold_left := 0.0
var contact_hold_elapsed := 0.0
var impact_anchor_set := false
var impact_anchor := Vector2.ZERO
var wound_anchor := Vector2.ZERO
var neck_anchor := Vector2.ZERO
var elbow_anchor := Vector2.ZERO
var swing_trace: Array[Vector3] = []
var result_winner := -2
var celebration_time := 0.0
var _backdrop: Texture2D
var _arena_ambience: ArenaAmbience
var _town_ambience: TownAmbience
var _armor_pieces: Dictionary = {}
var _weapon_textures: Dictionary = {}
var _weapon_halos: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = kind in ["town", "arena_preview"]
	if kind == "town":
		if data != null:
			_town_ambience = TownAmbience.new(data)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(queue_redraw)
	get_window().size_changed.connect(_sync_backdrop)
	_sync_backdrop()

func _sync_backdrop() -> void:
	var stem := ""
	match kind:
		"town": stem = BackdropArt.TOWN
		"battle", "arena_preview": stem = Content.arena(arena).get("backdrop", "")
	if stem.is_empty():
		return
	var path := BackdropArt.texture_path(stem, get_window().size)
	if _backdrop == null or _backdrop.resource_path != path:
		if kind != "town" and (_backdrop == null or _backdrop.resource_path.get_base_dir() != path.get_base_dir()):
			_arena_ambience = ArenaAmbience.new(stem)
		_backdrop = load(path)
	queue_redraw()

func set_rival(fighter: Dictionary, player_level: int) -> void:
	right_loadout = fighter.loadout
	rival_skin = int(fighter.get("skin", 0))
	rival_hair = int(fighter.get("hair", 0))
	var look: Dictionary = fighter.get("look", {})
	# Older saves can supply a build without an armor look. Derive one while keeping the saved proportions.
	if not look.has("armor"):
		var legacy_build := int(look.get("build", 100))
		look = Data.rival_look(str(fighter.name).hash(), player_level)
		look.build = legacy_build
	rival_look = look

func _spell_preview_casting() -> bool:
	return open_preview and kind == "spell" and elapsed < SPELL_PREVIEW_DURATION

func _movement_spell_preview() -> bool:
	return preview_spell_effect in ["push", "pull"]

func _process(delta: float) -> void:
	if open_preview and kind == "spell":
		var was_casting := _spell_preview_casting()
		elapsed = fposmod(elapsed + delta, SPELL_PREVIEW_INTERVAL)
		var resetting := _movement_spell_preview() and elapsed >= SPELL_PREVIEW_INTERVAL - MOVEMENT_PREVIEW_RESET
		# Movement spells hold the result before the rival steps back to their mark.
		if was_casting or _spell_preview_casting() or resetting:
			queue_redraw()
	elif kind == "town":
		elapsed += delta
		if _town_ambience != null:
			_town_ambience.advance(elapsed)
		queue_redraw()
	elif kind == "arena_preview":
		idle_time += delta
		queue_redraw()
	elif full_arena:
		idle_time += delta
		if result_winner >= 0:
			celebration_time = minf(celebration_time + delta, 1.35)
		if not event.is_empty() and elapsed < action_time:
			var hold := minf(delta, contact_hold_left)
			contact_hold_left -= hold
			contact_hold_elapsed += hold
			elapsed = minf(elapsed + (delta - hold), action_time)
			if not impact_played and elapsed >= impact_time:
				impact_played = true
				if _landed_strike():
					elapsed = impact_time
					contact_hold_left = .095 if event.action == "power" and not event.blocked else (.065 if event.blocked or event.critical else .040)
				# The controller updates the HUD and plays contact audio at this animation cue.
				impact_reached.emit()
			if elapsed >= action_time:
				turn_animation_finished.emit()
		queue_redraw()

## Keep both sets of positions so the renderer can animate movement after the duel has applied it.
func animate(change: Dictionary) -> void:
	result_winner = -2
	previous_positions = positions.duplicate()
	positions = change.positions.duplicate()
	event = change
	elapsed = 0.0
	impact_played = false
	contact_hold_left = 0.0
	contact_hold_elapsed = 0.0
	impact_anchor_set = false
	swing_trace.clear()
	finisher = ""
	finishing_spell_art = -1
	if lethal_bout and _knockout():
		var kit := left_loadout if int(event.side) == 0 else right_loadout
		if event.action == "cast":
			finishing_spell_art = _casting_art(int(event.side))
			match finishing_spell_art:
				1, 4, 7: finisher = "ash"
				5: finisher = "crush"
				_: finisher = "burn"
		elif event.action in Duel.WEAPON_ACTIONS and int(_item(kit.get("weapon", "")).get("art", 1)) != 1:
			finisher = "arm" if event.action == "power" else "decapitation"
		else:
			finisher = "heart"
	match event.action:
		"attack":
			impact_time = .35
			action_time = .83 if event.critical else .72
		"quick":
			impact_time = .17
			action_time = .58 if event.critical else .44
		"power":
			impact_time = .56
			action_time = 1.09 if event.critical else .98
		"lunge":
			impact_time = .42
			action_time = .98 if event.critical else .85
		"cast":
			match str(event.get("utility", "")):
				"shield": action_time = .69
				"push": action_time = .76
				"pull": action_time = .91
				"enchant": action_time = .85
				_: action_time = .88
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
	elif not finisher.is_empty():
		action_time += 1.12
	elif event.has("yielded"):
		action_time += .58
	elif _knockout():
		action_time += .78
	queue_redraw()

func celebrate(winner: int) -> void:
	result_winner = winner
	celebration_time = 0.0
	queue_redraw()

func _knockout() -> bool:
	return (not event.is_empty() and not event.get("ring_out", false)
		and not event.has("yielded") and event.damage > 0 and event.health[1 - int(event.side)] <= 0)

func _bloodied_hit() -> bool:
	return ((event.damage > 0 or event.get("first_blood", false)) and not event.get("ring_out", false)
		and (event.action in Duel.WEAPON_ACTIONS or event.action == "cast"))

func _landed_strike() -> bool:
	return not event.get("miss", false) and (event.damage + event.armor_hit > 0 or event.get("first_blood", false)) and event.action in Duel.WEAPON_ACTIONS

func _draw() -> void:
	if not open_preview and kind != "town":
		draw_rect(Rect2(Vector2.ZERO, size), Color("#1a2024"))
	match kind:
		"town":
			var art := town_art_rect()
			var view := art.intersection(Rect2(Vector2.ZERO, size))
			if not view.has_area() or _backdrop == null:
				return
			var to_source := _backdrop.get_size() / art.size
			var crop := Rect2((view.position - art.position) * to_source, view.size * to_source)
			draw_texture_rect_region(_backdrop, view, crop)
			if _town_ambience != null:
				_town_ambience.draw_details(self, _backdrop, art, view, elapsed)
			_draw_town_figures(art, view)
		"avatar":
			var height := _portrait_height()
			if open_preview:
				height = minf(height, size.x * 1.06)
			var center := .45 if open_preview else .5
			_avatar(Vector2(size.x * center, size.y * .96), height, left_loadout, false, skin, hair)
		"battle":
			_draw_battle()
		"arena_preview":
			_draw_arena_preview()
		"spell":
			if _movement_spell_preview():
				_draw_movement_spell_preview()
				return
			var phase := fmod(elapsed, SPELL_PREVIEW_DURATION) / SPELL_PREVIEW_DURATION
			var resting := open_preview and not _spell_preview_casting()
			var caster_x := size.x * (.31 if open_preview else .24)
			var feet_y := size.y * (.80 if open_preview else .9)
			var caster_height := minf(size.y * .64, size.x * .79) if open_preview else size.y * .63
			var etching := 0.0
			var ward := 0.0
			if preview_spell_effect == "enchant":
				etching = smoothstep(.24, .55, phase) * (1.0 - smoothstep(.85, 1.0, phase))
			elif preview_spell_effect == "shield":
				ward = smoothstep(.10, .51, phase) * (1.0 - smoothstep(.90, 1.0, phase))
			var pose := _rest_pose(left_loadout)
			if not resting:
				if preview_spell_effect == "damage" and spell_art == FIREBALL_ART:
					_fireball_arm(pose, left_loadout, phase)
				else:
					pose.weapon_arm += Vector3(.12, -.33, -.22) * sin(phase * PI)
			if resting:
				pose = _rest_pose(left_loadout)
				etching = .65 if preview_spell_effect == "enchant" else 0.0
				ward = .72 if preview_spell_effect == "shield" else 0.0
			var fighter := _avatar(Vector2(caster_x, feet_y), caster_height, left_loadout, false, skin, hair,
				pose, {}, 0.0, false, Rig.SkinPart.WHOLE, Color.WHITE, etching, preview_etching_rank, ward)
			if resting:
				if preview_spell_effect != "shield":
					_draw_shop_spell_icon()
				return
			var target := Vector2(size.x * (.75 if open_preview else .70), size.y * .81)
			var height := minf(size.y * .72, size.x * .35)
			if preview_spell_effect == "damage":
				if spell_art == FIREBALL_ART:
					target.y = fighter.hand.y
				elif spell_art == FALLING_EMBER_ART:
					target.y = feet_y - caster_height * .55
				_draw_spell(fighter.hand, target, height, spell_art, phase, 1.0)
			elif preview_spell_effect != "shield":
				var approach := minf(1.0, phase / .51)
				var recovery := maxf(0.0, (phase - .51) / .49)
				var destination := target - Vector2(0, height * .26)

				MagicEffects.cast(self, preview_spell_effect, fighter.hand, destination, height, approach, recovery, 1.0, preview_etching_rank)

func _draw_movement_spell_preview() -> void:
	# Frame two fighters and reserve enough room to show the full push inside the shop panel.
	var height := minf(size.y * .60, size.x * .44)
	if height <= 0.0:
		return
	var cast_phase := minf(elapsed / SPELL_PREVIEW_DURATION, 1.0)
	var approach := minf(cast_phase / MOVEMENT_PREVIEW_CONTACT, 1.0)
	var recovery := maxf(0.0, (cast_phase - MOVEMENT_PREVIEW_CONTACT) / (1.0 - MOVEMENT_PREVIEW_CONTACT))
	var reset := clampf((elapsed - (SPELL_PREVIEW_INTERVAL - MOVEMENT_PREVIEW_RESET)) / MOVEMENT_PREVIEW_RESET, 0.0, 1.0)
	var pulling := preview_spell_effect == "pull"
	var gap := 3 if pulling else 2
	var travel := gap - 1 if pulling else gap
	if not data.rules.distance_based_spell_movement:
		travel = mini(travel, preview_spell_power)
	var slide := smoothstep(0.0, .73, recovery) if pulling else 1.0 - pow(1.0 - clampf(recovery / .58, 0.0, 1.0), 3.0)
	var distance := height * SPACE_PER_FIGHTER_HEIGHT
	var displacement := travel * distance * slide * (1.0 - smoothstep(0.0, 1.0, reset))
	var caster_feet := size * Vector2(.20, .74)
	var rival_feet := caster_feet + Vector2(gap * distance + displacement * (-1.0 if pulling else 1.0), 0.0)
	_draw_fighter_shadow(caster_feet, height)
	_draw_fighter_shadow(rival_feet, height)

	var recoil := smoothstep(0.0, .13, recovery) * (1.0 - smoothstep(.48, .94, recovery))
	var rival_pose := _rest_pose({})
	rival_pose.weapon_arm += Vector3(.08, -.19, .16) * recoil
	rival_pose.off_arm += Vector3(-.12, -.18, .20) * recoil
	var step := sin(reset * TAU * 2.0) * sin(reset * PI)
	rival_pose.lead_leg = Vector3(-.26, .17, -.04) * step
	rival_pose.rear_leg = Vector3(.26, -.17, .04) * step
	var rival := _avatar(rival_feet, height, {}, true, 2, 2, rival_pose, {},
		recoil * (.17 if pulling else -.22), false, Rig.SkinPart.WHOLE, Color("#bbb8bf"))

	var reach := smoothstep(.05, .37, approach) * (1.0 - smoothstep(.55, 1.0, recovery))
	var cast_hand := Vector3(883, 536, -.43)
	if pulling:
		cast_hand = cast_hand.lerp(Vector3(772, 574, -.72), smoothstep(0.0, .59, recovery))
	var wrist := _rest_hand(left_loadout).lerp(cast_hand, reach)
	if pulling:
		# Keep long weapons out of the rival's silhouette while they stand next to the caster.
		var hold := smoothstep(.35, .73, recovery) * (1.0 - smoothstep(0.0, .78, reset))
		wrist = wrist.lerp(Vector3(747, 590, -1.04), hold)
	var caster_pose := _rest_pose(left_loadout)
	caster_pose.weapon_arm = Rig.aim_weapon_arm(Vector2(wrist.x, wrist.y), wrist.z)
	var caster := _avatar(caster_feet, height, left_loadout, false, skin, hair, caster_pose)
	if cast_phase < 1.0:
		var effect_height := height * .76
		if pulling:
			effect_height = clampf((rival.chest.x - caster.hand.x) * 2.0, height * .34, effect_height)
		MagicEffects.cast(self, preview_spell_effect, caster.hand, rival.chest, effect_height, approach, recovery, 1.0)

func _draw_fighter_shadow(feet: Vector2, height: float, opacity: float = 1.0) -> void:
	draw_set_transform(feet, 0.0, Vector2(1.0, .25))
	draw_circle(Vector2.ZERO, height * .24, Color("#160f14", .28 * opacity), true)
	draw_set_transform(Vector2.ZERO)

func _draw_shop_spell_icon() -> void:
	if preview_spell_icon == null:
		return
	var art_size := preview_spell_icon.get_size()
	var limit := minf(size.x * .32, size.y * .25)
	var extent := art_size * (limit / maxf(art_size.x, art_size.y))
	var center := Vector2(size.x * .79, size.y * .53)
	draw_texture_rect(preview_spell_icon, Rect2(center - extent * .5, extent), false)

func _draw_town_figures(art: Rect2, view: Rect2) -> void:
	var scale := art.size.x / TOWN_DESIGN_SIZE.x
	var player_feet := view.position + view.size * Vector2(.49, .94)
	var player_height := view.size.y * .39
	var player_floor := (player_feet.y - art.position.y) / scale
	var player_depth := player_floor - TOWN_GROUND_HORIZON
	if _town_ambience != null:
		for passerby in _town_ambience.pedestrians(elapsed, player_floor - TOWN_BACKGROUND_GAP):
			var feet: Vector2 = art.position + passerby.feet * scale
			_draw_passerby(passerby, feet, scale, player_height, player_depth)
	_draw_town_player(player_feet, player_height)

func _draw_town_player(feet: Vector2, height: float) -> void:
	feet.y += sin(elapsed * 1.8) * 1.25
	_avatar(feet, height, left_loadout, false, skin, hair)

func _draw_passerby(passerby: Dictionary, feet: Vector2, scale: float, player_height: float, player_depth: float) -> void:
	var depth: float = passerby.feet.y - TOWN_GROUND_HORIZON
	var starting_depth: float = passerby.start_y - TOWN_GROUND_HORIZON
	var height: float = player_height * passerby.stature * depth / player_depth
	var average_depth := depth
	# Match travel to the changing perspective without resetting the gait as the person grows.
	if not is_equal_approx(depth, starting_depth):
		average_depth = (depth - starting_depth) / log(depth / starting_depth)
	var stride := height * average_depth / depth * TOWN_WALK_STEP / 1536.0
	var phase := fposmod(passerby.age * passerby.speed * scale / stride, 1.0)
	var pose := _rest_pose(passerby.loadout)
	pose.rigid_feet = true
	var crouch := _walk_step(pose, phase, phase, TOWN_WALK_STEP)
	_draw_fighter_shadow(feet, height, passerby.tint.a)
	feet.y += height * crouch
	_avatar(feet, height, passerby.loadout, passerby.facing_left, passerby.skin, passerby.hair, pose, passerby.look,
		0.0, false, Rig.SkinPart.WHOLE, passerby.tint)

func town_art_rect() -> Rect2:
	# Keep all four storefronts inside the visible band even on ultrawide screens.
	var art_scale := minf(size.x / TOWN_DESIGN_SIZE.x, size.y * 1.5 / TOWN_DESIGN_SIZE.y)
	var extent := TOWN_DESIGN_SIZE * art_scale
	return Rect2((size - extent) * .5, extent)

func preview_feet(index: int) -> Vector2:
	return size * Vector2(.18 if index == 0 else .82, .865)

func preview_fighter_height() -> float:
	return minf(size.y * .63, size.x * .285)

func _draw_arena_preview() -> void:
	# Keep the painted arena floor in frame even when a wide window crops out the sky.
	_draw_arena_backdrop(.5, 1.0)
	var height := preview_fighter_height()
	var feet := preview_feet(0)
	_draw_fighter_shadow(feet, height)
	_avatar(feet, height, left_loadout, false, skin, hair)
	if show_rival:
		feet = preview_feet(1)
		_draw_fighter_shadow(feet, height)
		_avatar(feet, height, right_loadout, true, rival_skin, rival_hair, null, rival_look)

func _draw_arena_backdrop(pan: float, vertical: float = .50) -> void:
	if size.y <= 0 or size.x <= 0 or _backdrop == null:
		return
	var region := Rect2(Vector2.ZERO, _backdrop.get_size())
	var view_shape := size.x / size.y
	var source_shape := region.size.x / region.size.y
	var extent := region.size
	if view_shape > source_shape:
		extent.y /= view_shape / source_shape
	else:
		extent.x *= view_shape / source_shape
	# Leave a crop margin for panning the backdrop as the arena camera moves.
	if full_arena:
		extent *= .85
	var crop := Rect2(region.position + (region.size - extent) * Vector2(pan, vertical), extent)
	draw_texture_rect_region(_backdrop, Rect2(Vector2.ZERO, size), crop)
	if _arena_ambience != null:
		_arena_ambience.draw(self, _backdrop, crop, size, idle_time)

# Live previews use the catalog. A saved bout uses the equipment recorded when it began.
func _item(id: String) -> Dictionary:
	var catalog: Dictionary = data.items if bout_items.is_empty() else bout_items
	return catalog.get(id, {})

func _casting_art(side: int) -> int:
	var kit := left_loadout if side == 0 else right_loadout
	var art := int(event.get("spell_art", _item(kit.get("spell", "")).get("art", 0)))
	return clampi(art, 0, SPELL_COLORS.size() - 1)

func _portrait_height() -> float:
	var height := minf(size.y * .89, size.x * 1.25)
	var sprite := Content.weapon_art(left_loadout.get("weapon", ""))
	if sprite.is_empty():
		return height
	var bones := Rig.transforms(_rest_pose(left_loadout))
	var hand := bones[Rig.WEAPON_WRIST].translated_local(Rig.local(Rig.GRIP))
	hand = hand.rotated_local(_weapon_rotation(left_loadout))
	var tip: Vector2 = hand * ((sprite.tip - sprite.grip) * sprite.scale)
	# Leave room above an upright weapon as well as the fighter's head.
	var top := minf(-1024.0, tip.y - 20.0)
	return minf(height, size.y * .92 * 1024.0 / -top)

func _weapon_rotation(gear: Dictionary) -> float:
	return Content.weapon_art(gear.get("weapon", "")).get("rotation", 0.0)

func _rest_hand(gear: Dictionary) -> Vector3:
	var wrist: Vector2 = Rig.PIVOTS[Rig.WEAPON_WRIST]
	return Content.weapon_art(gear.get("weapon", "")).get("rest_hand", Vector3(wrist.x, wrist.y, 0.0))

func _rest_pose(gear: Dictionary) -> Rig.Pose:
	var pose := Rig.Pose.new()
	var hand := _rest_hand(gear)
	pose.weapon_arm = Rig.aim_weapon_arm(Vector2(hand.x, hand.y), hand.z)
	return pose

func _avatar(feet: Vector2, height: float, gear: Dictionary, facing_left: bool, skin_index: int = 0, hair_index: int = 0,
		pose: Rig.Pose = null, look: Dictionary = {}, root_tilt: float = 0.0, firm_weapon_arm: bool = false,
		skin_part: Rig.SkinPart = Rig.SkinPart.WHOLE, tint: Color = Color.WHITE, etching: float = 0.0,
		etching_rank: int = 1, ward: float = 0.0) -> FighterPoints:
	if height <= 0:
		return null
	var scale_value := height / 1024.0
	var width := scale_value * clampf(float(look.get("build", 100)) / 100.0, .85, 1.2)
	var body := Transform2D(-root_tilt if facing_left else root_tilt, feet).scaled_local(Vector2(-width if facing_left else width, scale_value))
	var rig_pose := _rest_pose(gear) if pose == null else pose
	var bones := Rig.transforms(rig_pose)
	var hand := body * bones[Rig.WEAPON_WRIST]
	var grip := hand.translated_local(Rig.local(Rig.GRIP))
	# The weapon draws behind the body and armor. Keep the tip position for impact effects.
	var tip := grip.origin if skin_part == Rig.SkinPart.WITHOUT_ARM else _draw_weapon(gear, grip, tint, facing_left, etching, etching_rank)
	var armor: Dictionary = gear.get("armor", {})
	var boots := _armor_piece(armor, look, "shoes")
	var pants := _armor_piece(armor, look, "pants")
	var chest := _armor_piece(armor, look, "chest")
	var armor_tint := _armor_tint(look, tint)
	draw_set_transform_matrix(body)
	Rig.draw_skin(self, bones, skin_index, hair_index, firm_weapon_arm, skin_part, tint,
		not boots.is_empty(), not pants.is_empty(), _closed_helmet(armor, look), chest.get("sleeve_tint", Color.WHITE),
		rig_pose.rigid_feet)
	_draw_armor(armor, look, body, bones, skin_part == Rig.SkinPart.BODY, armor_tint, ward * tint.a, rig_pose.rigid_feet)
	Armor.draw_weapon_arm(self, chest, body, bones, armor_tint, skin_part)
	if skin_part == Rig.SkinPart.BODY:
		draw_set_transform_matrix(body * bones[Rig.NECK])
		_draw_cut(Rig.local(Rig.NECK_CUT))
	elif skin_part == Rig.SkinPart.WITHOUT_ARM:
		draw_set_transform_matrix(body * bones[Rig.WEAPON_ELBOW])
		_draw_cut(Rig.local(Rig.ARM_CUT))
	draw_set_transform(Vector2.ZERO)
	var points := FighterPoints.new()
	points.hand = hand * Rig.local(Rig.GRIP)
	points.weapon_tip = tip
	points.chest = body * bones[Rig.SPINE] * Rig.local(Vector2(577, 606))
	points.shield = body * bones[Rig.OFF_WRIST] * SHIELD_CENTER
	points.has_shield = not str(gear.get("armor", {}).get("shield", "")).is_empty()
	points.neck = body * bones[Rig.NECK] * Rig.local(Rig.NECK_CUT)
	points.elbow = body * bones[Rig.WEAPON_ELBOW] * Rig.local(Rig.ARM_CUT)
	return points

func _closed_helmet(armor: Dictionary, look: Dictionary) -> bool:
	return _armor_piece(armor, look, "helmet").get("closed", false)

func _armor_piece(armor: Dictionary, look: Dictionary, slot: String) -> Dictionary:
	var id: String = armor.get(slot, "")
	if id.is_empty():
		return {}
	# The rival look changes the art only for slots equipped in the duel loadout.
	var design: String = look.get("armor", {}).get(slot, "")
	var key := id if design.is_empty() else design + ":" + slot
	if not _armor_pieces.has(key):
		_armor_pieces[key] = Armor.equipped(_item(id)) if design.is_empty() else Armor.rival_piece(slot, design)
	return _armor_pieces[key]

func _armor_tint(look: Dictionary, tint: Color) -> Color:
	var palette := clampi(int(look.get("palette", 0)), 0, RIVAL_PALETTES.size() - 1)
	return RIVAL_PALETTES[palette] * tint

func _draw_armor(armor: Dictionary, look: Dictionary, body: Transform2D, bones: Array[Transform2D], headless: bool,
		tint: Color, ward: float, rigid_feet: bool) -> void:
	for slot in ["pants", "shoes", "chest", "helmet", "shield"]:
		if slot == "helmet" and headless:
			continue
		draw_set_transform_matrix(body if slot in ["pants", "shoes"] else body * bones[Armor.ANCHORS[slot]])
		var piece := _armor_piece(armor, look, slot)
		if slot == "shield" and ward > 0.0:
			Armor.draw(self, piece, slot, bones, Color(tint, tint.a * (1.0 - ward)))
			var shield_size: Vector2 = piece.get("size", Vector2(230, 365))
			MagicEffects.ward(self, SHIELD_CENTER, shield_size.y * 1.12, ward)
		else:
			Armor.draw(self, piece, slot, bones, tint, rigid_feet)

func _draw_weapon(gear: Dictionary, hand: Transform2D, tint: Color, rival: bool = false, etching: float = 0.0,
		etching_rank: int = 1) -> Vector2:
	var weapon := _item(gear.get("weapon", ""))
	if weapon.is_empty():
		return hand.origin
	var sprite := _player_weapon(weapon)
	var texture := _weapon_texture(sprite.texture)
	var source := Rect2(Vector2.ZERO, texture.get_size())
	var grip: Vector2 = sprite.grip
	var tip: Vector2 = sprite.tip
	var scale_value: float = sprite.scale
	var held := hand.rotated_local(_weapon_rotation(gear))
	var tip_offset: Vector2 = (sprite.tip - grip) * scale_value
	var contact := held * tip_offset
	var art_tip := tip_offset
	var rival_sprite := Content.weapon_art(weapon.id, true) if rival else {}
	if not rival_sprite.is_empty():
		texture = _weapon_texture(rival_sprite.texture)
		source = Rect2(Vector2.ZERO, texture.get_size())
		grip = rival_sprite.grip
		tip = rival_sprite.tip
		var art_axis := tip - grip
		# Align the rival art to the same hand position and animation contact point.
		scale_value = tip_offset.length() / art_axis.length()
		held = held.rotated_local(art_axis.angle_to(tip_offset))
		art_tip = art_axis * scale_value
	draw_set_transform_matrix(held)
	var bounds := Rect2(-grip * scale_value, source.size * scale_value)
	var halo: Dictionary = {}
	var heat := tint
	if etching > 0.0:
		if not _weapon_halos.has(texture):
			_weapon_halos[texture] = MagicEffects.weapon_halo(texture, grip, tip)
		halo = _weapon_halos[texture]
		var light_color: Color = MagicEffects.ETCHING_COLORS[etching_rank - 1]
		var heat_color: Color = MagicEffects.ETCHING_HEAT[etching_rank - 1]
		heat = tint.lerp(Color(heat_color, tint.a), etching * (.22 + etching_rank * .11))
		if not halo.is_empty():
			var margin: Vector2 = bounds.size * halo.padding
			var light := Rect2(bounds.position - margin, bounds.size + margin * 2.0)
			draw_texture_rect(halo.texture, light, false, Color(light_color, etching * tint.a * (.62 + etching_rank * .12)))
	draw_texture_rect_region(texture, bounds, source, heat)
	if not halo.is_empty():
		var rune_color := Color("#ffe2a0").lerp(Color("#fffdf1"), (etching_rank - 1) * .5)
		draw_texture_rect(halo.runes, bounds, false, Color(rune_color, etching * tint.a * (.26 + etching_rank * .21)))
		MagicEffects.weapon_embers(self, art_tip, elapsed if _spell_preview_casting() else idle_time, etching * tint.a, etching_rank)
	return contact

func _weapon_texture(path: String) -> Texture2D:
	if not _weapon_textures.has(path):
		_weapon_textures[path] = load(path)
	return _weapon_textures[path]

static func _player_weapon(item: Dictionary) -> Dictionary:
	var sprite := Content.weapon_art(item.id)
	if not sprite.is_empty():
		return sprite
	return Content.weapon_art("mace" if int(item.art) == 1 else "sword")

static func weapon_icon(item: Dictionary) -> AtlasTexture:
	var sprite := _player_weapon(item)
	var icon := AtlasTexture.new()
	icon.atlas = load(sprite.texture)
	icon.region = Rect2(Vector2.ZERO, icon.atlas.get_size())
	icon.filter_clip = true
	return icon

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
	var utility := str(event.get("utility", ""))
	var phase := clampf(elapsed / action_time, 0, 1)
	var animating := side >= 0 and phase < 1
	var approach := clampf(elapsed / impact_time, 0, 1)
	var recovery := clampf((elapsed - impact_time) / (action_time - impact_time), 0, 1)
	var shift := smoothstep(.17, 1.0, approach) if action in ["jump", "jump_back"] else smoothstep(.04, .90, phase)
	if action == "lunge":
		shift = smoothstep(.22, .97, approach)
	var stagger := _hit_recoil(clampf((elapsed - impact_time) / .34, 0.0, 1.0)) if animating else 0.0
	# Draw movement between the old and resolved positions. Knockback begins at contact.
	var visible_positions: Array[float] = [float(positions[0]), float(positions[1])]
	var pushed := false
	if animating and previous_positions.size() == 2:
		pushed = (action == "power" or utility in ["push", "pull"]) and positions[1 - side] != previous_positions[1 - side]
		for index in 2:
			var travel := shift
			if pushed and index != side:
				var push_time := .32 if event.get("ring_out", false) or utility == "pull" else .20
				var push_progress := clampf((elapsed - impact_time) / push_time, 0.0, 1.0)
				travel = 1.0 - pow(1.0 - push_progress, 3.0)
			visible_positions[index] = lerpf(float(previous_positions[index]), visible_positions[index], travel)
	var view := _battle_view(visible_positions)
	var height := _fighter_height(view)
	if height <= 0.0:
		return
	var knocked_out := (animating or result_winner != -2) and _knockout()
	var topple := smoothstep(.32, .76, recovery) if knocked_out and finisher != "ash" else 0.0
	if topple > 0.0:
		var target_x := (view * Vector2(visible_positions[1 - side], 0)).x
		var room := size.x - target_x if side == 0 else target_x
		var fall_room := 1.62 if finishing_spell_art < 0 and not finisher.is_empty() else 1.27
		if finisher == "arm":
			fall_room = 1.77
		view.origin.x -= (1.0 if side == 0 else -1.0) * maxf(0.0, height * fall_room * topple - room)
	var pan := .5
	if full_arena and view.x.x > 0.0:
		var center := (size.x * .5 - view.origin.x) / view.x.x
		pan = clampf(center / arena_width, 0.0, 1.0)
	_draw_arena_backdrop(pan)
	if animating and action == "power":
		# A brief shade over the arena holds the eye on the raised weapon and leaves the HUD alone.
		var strike_age := elapsed - impact_time + contact_hold_elapsed
		var focus := smoothstep(.36, .73, approach) * (1.0 - smoothstep(.06, .25, strike_age))
		draw_rect(Rect2(Vector2.ZERO, size), Color("#24182f", .38 * focus))
	if full_arena and has_pits:
		_draw_pit(view * Vector2(-1, 0), height)
		_draw_pit(view * Vector2(arena_width + 1, 0), height)
	for index in 2 if show_rival else 1:
		var distance := visible_positions[index]
		var foot := view * Vector2(distance, 0)
		if side >= 0 and index != side and not pushed:
			foot.x += height * .13 * stagger * (1.0 if side == 0 else -1.0)
		feet.append(foot)
		if distance < 0 or distance > arena_width:
			continue
		var shadow := foot + Vector2(.06, .008) * height
		var shadow_radius := height * .24
		if index == 1 - side and knocked_out:
			shadow += Vector2(.61 if side == 0 else -.71, .22) * (topple * height)
			shadow_radius = height * lerpf(.24, .48, topple)
		draw_set_transform(shadow, 0.0, Vector2(1, .24))
		var ash_fade := smoothstep(.17, .62, recovery) if index == 1 - side and finisher == "ash" else 0.0
		draw_circle(Vector2.ZERO, shadow_radius, Color(0.08, 0.07, 0.055, .26 * (1.0 - ash_fade)))
		draw_set_transform(Vector2.ZERO)
	if animating and (action in Duel.MOVEMENT or action == "lunge") and elapsed >= impact_time:
		_draw_dust(feet[side], height, recovery)
	if stagger > 0.0:
		_draw_dust(feet[1 - side], height, clampf(recovery * 1.4, 0.0, 1.0))
	if animating and action == "lunge" and approach > .22 and approach < .97:
		_draw_lunge_lines(feet[side], height, 1.0 if side == 0 else -1.0, approach)
	if knocked_out and recovery > .70:
		_draw_fall_ground(feet[1 - side], height, 1.0 if side == 0 else -1.0, recovery)
	if full_arena and not animating and result_winner == -2 and not event.has("yielded") and not knocked_out:
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
		points[index] = _draw_fighter(feet[index], height, loadout, index, gap, approach, recovery, phase, stagger)
	if animating and action in Duel.WEAPON_ACTIONS and approach >= float(STRIKE_RELEASE[action]) - .035:
		_draw_swing_trace(points[side], view, height, action)
	if action == "cast" and animating:
		var attack_art := _casting_art(side)
		var target := view * Vector2(visible_positions[1 - side], 0)
		var direction := 1.0 if side == 0 else -1.0
		var defender := points[1 - side]
		var spell_phase := clampf(elapsed * SPELL_CONTACT / impact_time, 0.0, 1.0)
		var caster := points[side]
		if utility.is_empty():
			if attack_art in [FIREBALL_ART, FALLING_EMBER_ART]:
				# Projectiles and hit sparks meet at the same point on the defender.
				if impact_anchor_set:
					target = view * (impact_anchor * Vector2(1.0, height))
				elif defender != null:
					target = _guard_contact(defender, height, direction) if event.blocked else defender.chest
				else:
					target.y -= height * .55
			elif event.blocked and defender != null and defender.has_shield:
				target.x = defender.shield.x - direction * height * .09
			_draw_spell(caster.hand, target, height, attack_art, spell_phase, direction, event.miss)
			if attack_art not in [FIREBALL_ART, FALLING_EMBER_ART] and approach < .65:
				var charge := sin(approach / .65 * PI)
				var color := Color("#7cbeff") if attack_art == 3 else Color("#ffd795")
				draw_arc(caster.hand, height * (.07 + .06 * charge), approach * TAU, approach * TAU + PI * 1.65,
					24, Color(color, charge), 3.0, true)
		elif utility != "shield" and defender != null:
			MagicEffects.cast(self, utility, caster.hand, defender.chest, height, approach, recovery, direction, etching_ranks[side])
	if animating and elapsed >= impact_time:
		var contact_offset: float = (previous_positions[1 - side] - visible_positions[1 - side]) * view.x.x if pushed else 0.0
		_draw_impact(feet, points[1 - side], height, side, recovery, contact_offset, view)
		if event.has("shield_absorbed") and points[1 - side] != null:
			MagicEffects.ward_break(self, points[1 - side].shield, height, -1.0 if side == 0 else 1.0, recovery)
		if event.get("enchant_used", false) and points[1 - side] != null:
			var rank := etching_ranks[side]
			MagicEffects.burst(self, points[1 - side].chest, height * (.55 + rank * .13), recovery, MagicEffects.ETCHING_COLORS[rank - 1])
	if not finisher.is_empty() and recovery >= .024:
		_draw_finisher(feet[1 - side], height, 1 - side, recovery, view)

func _draw_fighter(feet: Vector2, height: float, loadout: Dictionary, index: int, gap: float, approach: float, recovery: float,
		phase: float, recoil: float) -> FighterPoints:
	var actor := int(event.get("side", -1))
	var action := str(event.get("action", ""))
	var utility := str(event.get("utility", ""))
	var skin_index := skin if index == 0 else rival_skin
	var hair_index := hair if index == 0 else rival_hair
	var facing_left := index == 1
	var direction := -1.0 if facing_left else 1.0
	var pose := _rest_pose(loadout)
	var rest_hand := _rest_hand(loadout)
	var grip_angle := _weapon_rotation(loadout)
	var root_tilt := 0.0
	var pulse := sin(phase * PI)
	var shielded := not str(loadout.get("armor", {}).get("shield", "")).is_empty()
	var yielding := int(event.get("yielded", -1)) == index
	var skin_part := Rig.SkinPart.WHOLE
	var tint := Color.WHITE
	if actor == 1 - index and recovery >= .024:
		match finisher:
			"decapitation": skin_part = Rig.SkinPart.BODY
			"arm": skin_part = Rig.SkinPart.WITHOUT_ARM
			"burn": tint = tint.lerp(Color("#504651"), smoothstep(.025, .42, recovery))
			"ash":
				tint = tint.lerp(Color("#a3a2bb"), smoothstep(.03, .19, recovery))
				tint.a = 1.0 - smoothstep(.17, .62, recovery)
				if tint.a <= 0.0:
					return null
	var striking := actor == index and phase < 1.0 and action in Duel.WEAPON_ACTIONS
	if full_arena:
		var breath := sin(idle_time * 2.8 + index * 2.2)
		pose.spine = .017 * breath
		pose.head = -.018 * breath
		if not striking:
			pose.weapon_arm.y += .025 * breath
		pose.off_arm.x = -.024 * breath
	if result_winner == index:
		_victory_pose(pose, rest_hand, grip_angle)
	elif actor == index and phase < 1:
		match action:
			"lunge":
				var coil := smoothstep(.0, .22, approach) * (1.0 - smoothstep(.37, .66, approach))
				var release := smoothstep(STRIKE_RELEASE.lunge, 1.0, approach)
				var plant := smoothstep(.45, .93, approach) * (1.0 - smoothstep(.22, .92, recovery))
				var stride := sin(TAU * clampf((approach - .22) / .66, 0.0, 1.0)) * (1.0 - plant)
				var mace := int(_item(loadout.get("weapon", "")).get("art", 0)) == 1
				feet.x -= direction * height * (.081 * coil + (.08 if event.miss else .019) * plant)
				feet.y += height * (.065 * coil + .042 * plant - .010 * absf(stride))
				pose.pelvis = -.04 * coil + .04 * plant
				pose.spine += -.16 * coil + .17 * plant
				pose.head += .13 * coil - .15 * plant
				pose.rear_leg = Vector3(.22, -.12, -.09) * plant + Vector3(-.22, .31, -.10) * coil
				pose.rear_leg += Vector3(.39, -.23, -.16) * stride
				pose.lead_leg = Vector3(-.37, .36, -.03) * plant + Vector3(-.23, .32, -.09) * coil
				pose.lead_leg += Vector3(-.38, .27, .11) * stride
				var ready_arm := Vector3(783, 369, -.81) if mace else Vector3(767, 568, .27)
				var hit_arm := Vector3(885, 575, 1.02) if mace else Vector3(907, 570, .72)
				var follow_arm := Vector3(830, 671, 1.40) if mace else Vector3(868, 606, .63)
				var swing_arc := Vector3(49, -55, 0) if mace else Vector3.ZERO
				if finisher == "decapitation":
					hit_arm = Vector3(889, 447, .22)
					follow_arm = Vector3(864, 604, .96)
				pose.weapon_arm = _swing_arm(ready_arm, hit_arm, follow_arm, swing_arc,
					smoothstep(.03, .32, approach), release, recovery, rest_hand, grip_angle)
				pose.off_arm += Vector3(-.20, -.32, .16) * coil + Vector3(.33, -.26, .19) * plant
			"attack", "quick", "power":
				var mace := int(_item(loadout.get("weapon", "")).get("art", 0)) == 1
				var motion := _close_strike(pose, action, approach, recovery, gap / height, mace, rest_hand, grip_angle)
				feet += Vector2(motion.x * direction, motion.y) * height
			"advance", "retreat":
				var forward := action == "advance"
				var root_progress := smoothstep(.04, .90, phase)
				var spaces := absf(positions[index] - previous_positions[index])
				var step_size := minf(spaces * SPACE_PER_FIGHTER_HEIGHT * 1536.0, MAX_WALK_STEP)
				feet.y += height * _walk_step(pose, phase, root_progress, step_size, forward)
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
				if utility.is_empty() and _casting_art(actor) == FIREBALL_ART:
					_fireball_arm(pose, loadout, phase)
				else:
					pose.weapon_arm += Vector3(-.57, -.41, .47) * release + Vector3(.31, -.70, -.28) * (pulse - release)
				pose.off_arm += Vector3(-.33, -.42, .25) * pulse
				pose.lead_leg = Vector3(-.15, .19, -.04) * release
				if utility == "pull":
					var reel := smoothstep(.0, .45, recovery) * (1.0 - smoothstep(.55, 1.0, recovery))
					pose.spine -= .23 * reel
					pose.weapon_arm += Vector3(.33, .37, -.45) * reel
				elif utility == "shield":
					var lift := .60 * smoothstep(.20, .84, approach) * (1.0 - recovery)
					_brace(pose, lift, true, grip_angle)
			"guard":
				_brace(pose, smoothstep(.0, .32, phase) * (1.0 - smoothstep(.67, 1.0, phase)), shielded, grip_angle)
			"taunt", "sleep", "potion":
				pose.spine += pulse * (-.16 if action in ["guard", "sleep"] else .11)
				pose.head += pulse * (.26 if action == "sleep" else -.09)
				pose.weapon_arm += Vector3(-.24, -.47, .29) * pulse
				pose.off_arm += Vector3(-.32, -.56, .14) * pulse
				pose.rear_leg = Vector3(.08, -.14, .06) * pulse
				pose.lead_leg = Vector3(-.07, .15, -.08) * pulse
	elif actor >= 0 and index != actor and elapsed >= impact_time:
		# Tip the fighter as a unit on contact. A deep bend in several joints made the silhouette pulse.
		root_tilt = -.14 * recoil
		pose.weapon_arm += Vector3(.09, .07, -.15) * recoil
		pose.off_arm += Vector3(.07, -.10, .06) * recoil
		if utility in ["push", "pull"]:
			var forced := smoothstep(.0, .15, recovery) * (1.0 - smoothstep(.42, .96, recovery))
			root_tilt = (.23 if utility == "pull" else -.27) * forced
			pose.lead_leg += Vector3(-.20, .33, -.18) * forced
		if event.get("ring_out", false):
			var fall := smoothstep(.46, .98, recovery)
			if fall >= .96:
				return null
			feet.y += height * .035 * fall
			root_tilt -= .25 * sin(PI * fall)
			height *= 1.0 - fall
			pose.rear_leg += Vector3(-.20, .37, -.11) * fall
			pose.lead_leg += Vector3(.18, .62, -.30) * fall
		elif finisher == "ash":
			var shock := sin(recovery * 62.0) * (1.0 - smoothstep(.20, .62, recovery))
			var slump := smoothstep(.08, .58, recovery)
			feet.y += height * (.24 * slump - .023 * shock)
			feet.x -= direction * height * .015 * shock
			root_tilt = -.37 * slump
			pose.spine += .21 * slump - .055 * shock
			pose.weapon_arm += Vector3(-.32, .61, -.20) * slump
			pose.lead_leg += Vector3(-.42, .81, -.32) * slump
			pose.rear_leg += Vector3(.30, -.69, .33) * slump
		elif _knockout():
			var buckle := smoothstep(.08, .36, recovery)
			var topple := smoothstep(.32, .76, recovery)
			var bounce := sin(PI * clampf((recovery - .72) / .21, 0.0, 1.0))
			feet.x -= direction * height * (.06 * buckle + .17 * topple)
			feet.y += height * (.15 * buckle + .035 * topple - .055 * bounce)
			root_tilt += -1.40 * topple + .10 * bounce
			pose.pelvis += -.12 * buckle + .17 * topple
			pose.spine += .40 * buckle - .26 * topple
			pose.neck += .23 * buckle + .14 * topple
			pose.head += -.14 * buckle + .30 * topple
			pose.rear_leg += Vector3(.30, -.69, .33) * buckle + Vector3(-.15, .30, -.13) * topple
			pose.lead_leg += Vector3(-.44, .82, -.30) * buckle + Vector3(.20, -.25, .11) * topple
			pose.weapon_arm += Vector3(.17, -.16, .08) * buckle + Vector3(.26, .51, -.48) * topple
			pose.weapon_arm.z += 1.15 * smoothstep(.74, .98, recovery)
			pose.off_arm += Vector3(-.16, -.35, .19) * buckle + Vector3(.34, .33, -.40) * topple
	if result_winner >= 0 and result_winner != index and not _knockout() and not yielding:
		var dejection := smoothstep(.05, .50, celebration_time)
		pose.spine += .11 * dejection
		pose.head += .22 * dejection
		pose.weapon_arm += Vector3(.20, .06, .31) * dejection
	if actor >= 0 and index != actor and phase < 1.0:
		if event.blocked:
			var catch_blow := smoothstep(.28, .92, approach) * (1.0 - smoothstep(.06, .41, recovery))
			_brace(pose, catch_blow, shielded, grip_angle)
		elif event.miss and action in Duel.WEAPON_ACTIONS:
			var dodge := smoothstep(.54, .98, approach) * (1.0 - smoothstep(.13, .82, recovery))
			feet.x -= direction * height * .08 * dodge
			feet.y += height * .065 * dodge
			pose.spine -= .28 * dodge
			pose.neck += .12 * dodge
			pose.head -= .10 * dodge
			pose.rear_leg += Vector3(.19, -.39, .12) * dodge
			pose.lead_leg += Vector3(-.20, .42, -.18) * dodge
	if yielding:
		var kneel := smoothstep(.05, .72, recovery)
		feet += Vector2(-direction * .14, .195) * (height * kneel)
		root_tilt = lerpf(root_tilt, 0.0, kneel)
		pose.spine = lerpf(pose.spine, .18, kneel)
		pose.neck = lerpf(pose.neck, .22, kneel)
		pose.head = lerpf(pose.head, .31, kneel)
		pose.rear_leg = pose.rear_leg.lerp(Vector3(-.49, 1.86, -.55), kneel)
		pose.lead_leg = pose.lead_leg.lerp(Vector3(-1.78, 1.88, -.10), kneel)
		pose.weapon_arm = pose.weapon_arm.lerp(Rig.aim_weapon_arm(Vector2(758, 754), 1.15 - grip_angle), kneel)
		pose.off_arm = pose.off_arm.lerp(Vector3(.18, -.06, -.01), kneel)
	var etching := .82 + sin(idle_time * 5.0) * .12 if enchantments[index] > 0 else 0.0
	var ward := 1.0 if wards[index] > 0 else 0.0
	if actor == index and phase < 1.0:
		if utility == "enchant":
			etching = maxf(etching, smoothstep(.38, .95, approach))
		elif utility == "shield":
			ward = maxf(ward, smoothstep(.26, .98, approach))
		elif event.get("enchant_used", false) and enchantments[index] == 0:
			etching = .82 * (1.0 - smoothstep(.04, .62, recovery))
	return _avatar(feet, height, loadout, facing_left, skin_index, hair_index, pose, rival_look if facing_left else {},
		root_tilt, striking or result_winner == index or yielding, skin_part, tint, etching, etching_ranks[index], ward)

func _victory_pose(pose: Rig.Pose, rest_hand: Vector3, grip_angle: float) -> void:
	var raise_weapon := smoothstep(.02, .40, celebration_time)
	var cheer := sin(PI * clampf((celebration_time - .36) / .38, 0.0, 1.0))
	var wrist := Vector2(rest_hand.x, rest_hand.y)
	var salute := Vector2(799 - cheer * 13.0, 304 - cheer * 28.0)
	pose.weapon_arm = Rig.aim_weapon_arm(wrist.lerp(salute, raise_weapon),
		lerpf(rest_hand.z, -.74 - .14 * cheer - grip_angle, raise_weapon))
	pose.off_arm = Vector3(.22, .09, -.12) * raise_weapon
	pose.spine += -.055 * raise_weapon
	pose.head -= (.14 + .07 * cheer) * raise_weapon

func _close_strike(pose: Rig.Pose, action: String, approach: float, recovery: float, gap: float, mace: bool,
		rest_hand: Vector3, grip_angle: float) -> Vector2:
	var ready_arm := Vector3(752, 516, -1.31)
	var hit_arm := Vector3(891, 568, .94)
	var follow_arm := Vector3(825, 672, 1.48)
	var swing_arc := Vector3(63, -61, 0)
	var guard_windup := Vector3(-.15, -.43, .26)
	var weight := 1.0
	var release_start: float = STRIKE_RELEASE[action]
	match action:
		"quick":
			weight = .53
			ready_arm = Vector3(773, 562, -.39) if mace else Vector3(774, 588, .20)
			hit_arm = Vector3(876, 579, .98) if mace else Vector3(906, 581, .75)
			follow_arm = Vector3(837, 640, .89) if mace else Vector3(865, 615, .51)
			swing_arc = Vector3(39, -33, 0) if mace else Vector3.ZERO
		"power":
			weight = 1.42
			ready_arm = Vector3(808, 281, -.83)
			hit_arm = Vector3(886, 584, 1.04)
			follow_arm = Vector3(827, 700, 1.59)
			swing_arc = Vector3(105, -37, 0)
			guard_windup = Vector3(.39, -.59, .18)
	if finisher == "decapitation":
		hit_arm = Vector3(895, 447, .27)
	elif finisher == "arm":
		hit_arm = Vector3(897, 550, .88)
	# Finish the windup early so the raised weapon has a readable pose before it snaps forward.
	var windup := smoothstep(.01, release_start - .15, approach)
	var release := smoothstep(release_start, 1.0, approach)
	# The planted body starts the turn, then the forearm and weapon come through.
	var turn := smoothstep(release_start - .13, release_start + .09, approach)
	var backswing := windup * (1.0 - turn)
	var drive := turn * (1.0 - smoothstep(.16, .85, recovery))
	var reach := clampf(gap - SPACE_PER_FIGHTER_HEIGHT, 0.0, .32)
	var stride := reach * drive * (.75 if event.miss else 1.0)
	var shift := stride + (.045 * drive - .065 * backswing) * weight
	var sink := (.048 * backswing + .034 * drive) * weight
	pose.spine += (.10 * drive - .10 * backswing) * weight
	pose.neck += (.07 * backswing - .06 * drive) * weight
	pose.head += (.15 * backswing - .11 * drive) * weight
	pose.weapon_arm = _swing_arm(ready_arm, hit_arm, follow_arm, swing_arc, windup, release, recovery, rest_hand, grip_angle)
	pose.off_arm += guard_windup * backswing + Vector3(.39, -.35, .26) * drive
	# Hold the boots on the floor as the torso loads backwards and drives forward.
	pose.rear_leg = Rig.walk_leg(0, Vector2(-shift, -sink) * 1536.0, 0.0)
	pose.lead_leg = Rig.walk_leg(1, Vector2(stride - shift, -sink) * 1536.0, 0.0)
	return Vector2(shift, sink)

func _swing_arm(ready_arm: Vector3, hit_arm: Vector3, follow_arm: Vector3, swing_arc: Vector3,
		windup: float, release: float, recovery: float, rest: Vector3, grip_angle: float = 0.0) -> Vector3:
	ready_arm.z -= grip_angle
	hit_arm.z -= grip_angle
	follow_arm.z -= grip_angle
	var launch := rest.lerp(ready_arm, windup)
	var curve := (launch + hit_arm) * .5 + swing_arc
	var hand_pose := launch.lerp(curve, release).lerp(curve.lerp(hit_arm, release), release)
	hand_pose = hand_pose.lerp(follow_arm, smoothstep(.03, .35, recovery))
	hand_pose = hand_pose.lerp(rest, smoothstep(.38, .97, recovery))
	return Rig.aim_weapon_arm(Vector2(hand_pose.x, hand_pose.y), hand_pose.z)

func _walk_step(pose: Rig.Pose, phase: float, root_progress: float, step_size: float, forward: bool = true) -> float:
	# Step, transfer weight, then bring the trailing foot back into stance.
	var direction := 1.0 if forward else -1.0
	var first_step := smoothstep(.04, .49, phase)
	var follow_step := smoothstep(.49, .94, phase)
	var first_lift := .5 - .5 * cos(first_step * TAU)
	var follow_lift := .5 - .5 * cos(follow_step * TAU)
	var pulse := sin(phase * PI)
	var crouch := 51.0 * pulse
	var first := Vector2(step_size * direction * (first_step - root_progress), -crouch - 107.0 * first_lift)
	var second := Vector2(step_size * direction * (follow_step - root_progress), -crouch - 92.0 * follow_lift)
	var first_pitch := 0.0 if pose.rigid_feet else -.16 * first_lift
	var follow_pitch := 0.0 if pose.rigid_feet else .12 * follow_lift
	pose.lead_leg = Rig.walk_leg(1, first if forward else second, first_pitch if forward else follow_pitch)
	pose.rear_leg = Rig.walk_leg(0, second if forward else first, follow_pitch if forward else first_pitch)
	var arm_swing := sin(phase * TAU) * direction
	pose.spine += .13 * pulse * direction
	pose.neck = -.09 * pulse * direction
	pose.head += .06 * (follow_lift - first_lift)
	pose.weapon_arm += Vector3(.29, -.36, .15) * arm_swing
	pose.off_arm += Vector3(-.32, -.19, .20) * arm_swing
	return crouch / 1536.0

func _fireball_arm(pose: Rig.Pose, gear: Dictionary, phase: float) -> void:
	# Hold the wrist through contact so the projectile leaves an extended hand.
	var reach := smoothstep(.02, FIREBALL_RELEASE, phase) * (1.0 - smoothstep(.64, .95, phase))
	var gesture := _rest_hand(gear).lerp(Vector3(888, 526, -.28), reach)
	pose.weapon_arm = Rig.aim_weapon_arm(Vector2(gesture.x, gesture.y), gesture.z)

func _brace(pose: Rig.Pose, amount: float, shielded: bool, grip_angle: float = 0.0) -> void:
	pose.spine += .10 * amount
	pose.neck -= .11 * amount
	pose.head += .14 * amount
	if shielded:
		pose.off_arm = pose.off_arm.lerp(Vector3(-.99, -.58, 1.46), amount)
		pose.weapon_arm += Vector3(.15, -.26, .17) * amount
	else:
		pose.weapon_arm = pose.weapon_arm.lerp(Vector3(-.44, -.57, .72 - grip_angle), amount)
		pose.off_arm += Vector3(-.31, -.50, .24) * amount
	pose.rear_leg += Vector3(.10, -.24, .12) * amount
	pose.lead_leg += Vector3(-.13, .26, -.11) * amount

func _hit_recoil(recovery: float) -> float:
	if event.damage + event.armor_hit <= 0:
		return 0.0
	var weight := .30 if event.blocked else (.58 if event.damage <= 0 else 1.12)
	if event.critical:
		weight *= 1.22
	return weight * smoothstep(.0, .09, recovery) * (1.0 - smoothstep(.22, .91, recovery))

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
	for index in 3:
		var tip := feet + Vector2(-direction * height * (.13 + index * .078), -height * (.14 + index * .14))
		var trail := Vector2(direction * height * (.27 + index * .085) * strength, 0)
		_draw_streak(tip, trail, height * .014 * strength, STRIKE_COLORS.lunge, strength * .68)

func _draw_streak(tip: Vector2, travel: Vector2, width: float, tint: Color, opacity: float) -> void:
	if opacity < .03:
		return
	var edge := travel.normalized().orthogonal() * width
	var streak := PackedVector2Array([tip, tip - travel * .29 + edge, tip - travel, tip - travel * .25 - edge])
	draw_polygon(streak, PackedColorArray([Color(tint, opacity), Color(tint, opacity), Color(tint, 0.0), Color(tint, opacity)]))
	draw_line(tip - travel * .62, tip - travel * .08, Color(tint.lightened(.65), opacity), width * .62, true)

func _draw_swing_trace(fighter: FighterPoints, view: Transform2D, height: float, action: String) -> void:
	if fighter == null or fighter.weapon_tip.is_equal_approx(fighter.hand):
		return
	var clock := elapsed + contact_hold_elapsed
	# Keep the mark in arena coordinates so it doesn't move with the weapon or the camera.
	var units := Vector2(1.0, height)
	var tip := fighter.hand.lerp(fighter.weapon_tip, 1.12)
	var anchor := (view.affine_inverse() * tip) / units
	if elapsed < impact_time + .078 and (swing_trace.is_empty()
			or anchor.distance_squared_to(Vector2(swing_trace.back().x, swing_trace.back().y)) > .0001):
		swing_trace.append(Vector3(anchor.x, anchor.y, clock))
	while swing_trace.size() > 1 and clock - swing_trace[0].z > SWING_TRACE_TIME:
		swing_trace.pop_front()
	var tint: Color = STRIKE_COLORS[action]
	var thickness := height * (.059 if action == "power" else .031)
	for index in range(1, swing_trace.size()):
		var past := swing_trace[index - 1]
		var sample := swing_trace[index]
		var start := view * (Vector2(past.x, past.y) * units)
		var end := view * (Vector2(sample.x, sample.y) * units)
		var travel := end - start
		if travel.length_squared() < 4.0:
			continue
		var tail := clampf(1.0 - (clock - past.z) / SWING_TRACE_TIME, 0.0, 1.0)
		var head := clampf(1.0 - (clock - sample.z) / SWING_TRACE_TIME, 0.0, 1.0)
		var normal := travel.normalized().orthogonal() * thickness
		var corners := PackedVector2Array([start - normal * tail * .5, end - normal * head * .5,
			end + normal * head * .5, start + normal * tail * .5])
		var colors := PackedColorArray([Color(tint, tail * .82), Color(tint.lightened(.48), head),
			Color(tint, head * .84), Color(tint, tail * .64)])
		draw_primitive(corners, colors, PackedVector2Array())

func _guard_contact(defender: FighterPoints, height: float, direction: float) -> Vector2:
	var guard := defender.shield if defender.has_shield else defender.hand
	return guard + Vector2(-direction * .085, -.015) * height

func _draw_impact(feet: Array[Vector2], defender: FighterPoints, height: float, side: int, recovery: float,
		contact_offset: float, view: Transform2D) -> void:
	var symbol := ""
	var at := feet[1 - side]
	var direction := 1.0 if side == 0 else -1.0
	var spell: bool = event.action == "cast"
	var weapon: bool = event.action in Duel.WEAPON_ACTIONS
	if defender != null and (event.damage + event.armor_hit > 0 or event.get("first_blood", false)):
		if not impact_anchor_set:
			var chest_at_impact := defender.chest + Vector2(contact_offset, 0)
			var neck_at_impact := defender.neck + Vector2(contact_offset, 0)
			var elbow_at_impact := defender.elbow + Vector2(contact_offset, 0)
			var struck := neck_at_impact if finisher == "decapitation" else chest_at_impact
			if finisher == "arm":
				struck = elbow_at_impact
			if event.blocked:
				struck = _guard_contact(defender, height, direction)
			var inverse := view.affine_inverse()
			impact_anchor = inverse * struck / Vector2(1.0, height)
			wound_anchor = inverse * chest_at_impact / Vector2(1.0, height)
			neck_anchor = inverse * neck_at_impact / Vector2(1.0, height)
			elbow_anchor = inverse * elbow_at_impact / Vector2(1.0, height)
			impact_anchor_set = true
		# Let the debris stay at the impact as the defender recoils and the camera pans.
		var contact := view * (impact_anchor * Vector2(1.0, height))
		var chest := view * (wound_anchor * Vector2(1.0, height))
		var particle_phase := clampf((elapsed - impact_time + contact_hold_elapsed) / .43, 0.0, 1.0)
		var metal: bool = event.blocked or event.armor_hit > 0
		var tint := Color("#ffdc79") if metal else Color("#ffead1")
		if spell and not metal:
			tint = SPELL_COLORS[_casting_art(side)]
		if spell or (not weapon and metal):
			_draw_sparks(contact, height * (.48 if event.critical else .36), tint, particle_phase)
		if weapon:
			var radius := .16
			match event.action:
				"quick": radius = .12
				"power": radius = .26
				"lunge": radius = .18
			if event.critical:
				radius *= 1.12
			var burst_tint: Color = Color("#a5e4ff") if event.blocked else STRIKE_COLORS.get(event.action, STRIKE_COLORS.attack)
			var heavy: bool = event.action == "power" or event.critical or event.blocked
			_draw_impact_burst(contact, height * radius, burst_tint, particle_phase, direction, heavy)
		if event.armor_hit > 0:
			var armor_after: Array = event.get("armor", [])
			var broken: bool = armor_after.size() == 2 and armor_after[1 - side] == 0
			_draw_armor_chips(contact, height, direction, particle_phase, broken)
		if _bloodied_hit() and finisher.is_empty():
			_draw_blood_drops(chest + Vector2(-direction * height * .045, 0), height, direction, particle_phase, _knockout())
	if event.miss:
		symbol = "miss"
	elif event.blocked or event.armor_hit > 0 and event.damage == 0:
		symbol = "armor"
	elif event.damage > 0 and (not weapon or event.critical):
		symbol = "critical" if event.critical else "attack"
	elif event.action in ["potion", "sleep", "guard"]:
		symbol = event.action
		at = feet[side]
	elif event.action == "taunt":
		symbol = "taunt"
	if symbol.is_empty() or (_knockout() and recovery > .55):
		return
	if weapon and not event.miss and elapsed - impact_time + contact_hold_elapsed < .12:
		return
	var extent := lerpf(42.0, 28.0, recovery)
	var center := Vector2(at.x, maxf(36.0, at.y - height * .94 - recovery * 30.0))
	draw_circle(center, extent * .58, Color("#392831"), true, -1, true)
	Symbol.paint(self, symbol, center - Vector2.ONE * extent * .5, extent)

func _draw_finisher(feet: Vector2, height: float, loser: int, recovery: float, view: Transform2D) -> void:
	if not impact_anchor_set:
		return
	var severed_head := finisher == "decapitation"
	var severed_arm := finisher == "arm"
	var anchor := neck_anchor if severed_head else elbow_anchor if severed_arm else wound_anchor
	var wound := view * (anchor * Vector2(1.0, height))
	var direction := 1.0 if loser == 1 else -1.0
	if finishing_spell_art >= 0:
		_draw_spell_finisher(feet, wound, height, direction, recovery)
		return
	var body_part := severed_head or severed_arm
	var flight := clampf((recovery - .024) / .75, 0.0, 1.0)
	var ground := feet + Vector2(direction * (1.43 if body_part else 1.22), -.026) * height
	var part := wound.lerp(ground, flight)
	part.y -= height * sin(PI * flight) * (.48 if body_part else .30)
	part.y -= height * .052 * sin(PI * clampf((recovery - .774) / .16, 0, 1))
	var part_angle := direction * (TAU + (.48 if severed_arm else 1.62)) * flight
	var splatter := clampf((recovery - .024) / .62, 0.0, 1.0)
	var spray_alpha := 1.0 - smoothstep(.36, 1.0, splatter)
	if spray_alpha > 0.0:
		for index in 18:
			var spread := float((index * 7) % 19) / 18.0
			var lift := .34 + .54 * float(index % 5) / 4.0
			var drop := wound + Vector2(direction * (-.28 + spread * 1.13) * splatter,
				-lift * splatter + .96 * splatter * splatter) * height
			var radius := (.009 + .004 * (index % 4)) * height
			var tint := Color("#e24859", spray_alpha) if index % 3 == 0 else Color("#912036", spray_alpha)
			draw_line(drop, drop - Vector2(direction * spread, .88 * splatter - lift) * radius * 2.5,
				tint, radius * 1.25, true)
			draw_circle(drop, radius, tint, true, -1, true)
	var pool := smoothstep(.73, 1.0, recovery)
	_draw_blood_pool(ground, height * (.14 if body_part else .085) * pool)
	if body_part:
		var look := rival_look if loser == 1 else {}
		var loadout := right_loadout if loser == 1 else left_loadout
		var armor: Dictionary = loadout.get("armor", {})
		var chest := _armor_piece(armor, look, "chest")
		var armor_tint := _armor_tint(look, Color.WHITE)
		var scale_value := height / 1024.0
		var width := scale_value * clampf(float(look.get("build", 100)) / 100.0, .85, 1.2)
		var scale_xy := Vector2(width * -direction, scale_value)
		var cut := Rig.local(Rig.NECK_CUT if severed_head else Rig.ARM_CUT)
		var piece := Transform2D(part_angle, part).scaled_local(scale_xy).translated_local(-cut)
		var bones := Rig.transforms(Rig.Pose.new())
		if severed_arm:
			var drop := smoothstep(.43, .91, recovery)
			var grip := (piece * Rig.local(Rig.GRIP)).lerp(ground + Vector2(direction * .20, .036) * height, drop)
			var dropped := Transform2D(lerp_angle(part_angle, -direction * .77, drop), grip).scaled_local(scale_xy)
			_draw_weapon(loadout, dropped, Color.WHITE, loser == 1)
		draw_set_transform_matrix(piece)
		Rig.draw_skin(self, bones, rival_skin if loser == 1 else skin, rival_hair if loser == 1 else hair,
			false, Rig.SkinPart.HEAD_ONLY if severed_head else Rig.SkinPart.ARM_ONLY, Color.WHITE, false, false,
			_closed_helmet(armor, look), chest.get("sleeve_tint", Color.WHITE))
		_draw_cut(cut)
		if severed_head:
			Armor.draw(self, _armor_piece(armor, look, "helmet"), "helmet", bones, armor_tint)
		else:
			Armor.draw_weapon_arm(self, chest, piece, bones, armor_tint, Rig.SkinPart.ARM_ONLY)
		draw_set_transform(Vector2.ZERO)
	else:
		_draw_heart(part, height * .075, part_angle)

func _draw_spell_finisher(feet: Vector2, wound: Vector2, height: float, direction: float, recovery: float) -> void:
	if finisher == "crush":
		_draw_dust(feet, height, clampf(recovery * 2.0, 0.0, 1.0))
		return
	var settling := smoothstep(.19, .71, recovery)
	var ash := finisher == "ash"
	var ground := feet + Vector2(direction * (.08 if ash else .91), .20) * height
	var source := wound.lerp(ground, settling)
	if ash:
		_draw_ash_pile(ground, height, settling)
		_draw_discharge(wound, height, recovery)
	else:
		var edge: Color = FIRE_EDGES[finishing_spell_art]
		var core: Color = FIRE_CORES[finishing_spell_art]
		var growth := smoothstep(.026, .18, recovery) * (1.0 - .82 * smoothstep(.35, .91, recovery))
		if growth > 0.0:
			draw_circle(source, height * .33 * growth, Color(edge, .15 * growth), true, -1, true)
			for index in 8:
				var flicker := sin(idle_time * 19.0 + index * 3.7)
				var lift := (.32 + .14 * (index % 3)) * growth * (.86 + .14 * flicker)
				var width := (.07 + .04 * (index % 3)) * (.68 + growth * .32)
				var curl := .11 * sin(idle_time * 10.0 + index * 2.2)
				var base := source + Vector2((float(index * 5 % 9) - 4.0) * .074, .075 + .042 * (index % 4)) * height
				var flare := PackedVector2Array([base + Vector2(-width * .58, .077) * height,
					base + Vector2(-width, -lift * .21) * height,
					base + Vector2(-width * .37 + curl * .24, -lift * .59) * height,
					base + Vector2(curl, -lift) * height,
					base + Vector2(width * .41 + curl * .44, -lift * .67) * height,
					base + Vector2(width * .71, -lift * .23) * height, base + Vector2(width * .59, .047) * height])
				draw_polygon(flare, PackedColorArray([Color(edge, 0), Color(edge, growth * .60), Color(edge, growth * .80),
					Color(edge, 0), Color(edge, growth * .65), Color(core, growth), Color(core, 0)]))
	var smoke := smoothstep(.04, .23, recovery) * (1.0 - .50 * smoothstep(.56, 1.0, recovery))
	var smoke_tint := Color("#605a69") if ash else Color("#3a3037")
	for index in 10:
		var drift := fposmod(idle_time * (.74 if ash else .58) + index * .21, 1.0)
		var curl := sin(index * 3.7 + drift * 4.3)
		var point := source + Vector2(curl * (.04 + drift * .22), -drift * .67) * height
		var alpha := smoke * smoothstep(0.0, .12, drift) * (1.0 - drift)
		draw_circle(point, height * (.037 + drift * .095), Color(smoke_tint, alpha * .67), true, -1, true)
		var spark: Color = Color("#d3cdde") if ash else FIRE_CORES[finishing_spell_art]
		draw_circle(point + Vector2(.06 * curl, -.065) * height, height * (.006 + .004 * (index % 3)),
			Color(spark, alpha), true, -1, true)

func _draw_discharge(wound: Vector2, height: float, recovery: float) -> void:
	var fade := 1.0 - smoothstep(.095, .37, recovery)
	if fade <= 0.0:
		return
	var flicker := floorf(idle_time * 38.0)
	for index in 5:
		var ray := Vector2.from_angle(index * TAU / 5.0 + .37) * height * (.28 + recovery)
		var bend := ray.orthogonal() * sin(index * 5.3 + flicker) * .52
		var bolt := PackedVector2Array([wound, wound + ray * .29 + bend,
			wound + ray * .63 - bend * .31, wound + ray])
		draw_polyline(bolt, Color("#ae83fc", fade * .77), height * .025, true)
		draw_polyline(bolt, Color("#f5ebff", fade), height * .009, true)

func _draw_ash_pile(at: Vector2, height: float, settled: float) -> void:
	if settled <= 0.0:
		return
	var scale_value := height * settled
	draw_set_transform(at + Vector2(0, .02) * scale_value, 0.0, Vector2(1.0, .31) * scale_value)
	draw_circle(Vector2.ZERO, .34, Color("#504751"), true, -1, true)
	draw_set_transform(at, 0.0, Vector2.ONE * scale_value)
	var pile := PackedVector2Array([Vector2(-.33, 0), Vector2(-.23, -.08), Vector2(-.12, -.095), Vector2(-.044, -.19),
		Vector2(.04, -.15), Vector2(.11, -.16), Vector2(.17, -.09), Vector2(.31, -.03), Vector2(.37, .035),
		Vector2(.12, .075), Vector2(-.14, .070)])
	var shades := PackedColorArray()
	for point in pile:
		shades.append(Color("#514851").lerp(Color("#a3979d"), clampf(-point.y * 5.0, 0.0, 1.0)))
	draw_polygon(pile, shades)
	for index in 21:
		var x := float((index * 13) % 23) / 22.0 - .5
		var y := float((index * 9) % 23) / 22.0 - .5
		draw_circle(Vector2(x * .61, y * .16 - .039 + absf(x) * .09), .008 + .004 * (index % 3),
			Color("#c3bbc1") if index % 4 == 0 else Color("#6a6168"), true, -1, true)
	draw_set_transform(Vector2.ZERO)

func _draw_cut(at: Vector2) -> void:
	var rim := PackedVector2Array([at + Vector2(-47, 1), at + Vector2(-33, -9), at + Vector2(24, -9),
		at + Vector2(45, -2), at + Vector2(25, 12), at + Vector2(-19, 13)])
	draw_colored_polygon(rim, Color("#67192a"))
	draw_line(at + Vector2(-30, -4), at + Vector2(27, -4), Color("#d84955"), 6.0, true)

func _draw_heart(at: Vector2, radius: float, angle: float) -> void:
	draw_set_transform(at, angle, Vector2.ONE * radius)
	var outline := PackedVector2Array([Vector2(-.69, -.05), Vector2(-.68, -.45), Vector2(-.37, -.69),
		Vector2(-.06, -.57), Vector2(-.09, -.89), Vector2(.21, -.97), Vector2(.38, -.54),
		Vector2(.57, -.56), Vector2(.79, -.26), Vector2(.74, .17), Vector2(.31, .78), Vector2(.04, .89),
		Vector2(-.38, .59), Vector2(-.61, .28)])
	draw_colored_polygon(outline, Color("#b42f45"))
	outline.append(outline[0])
	draw_polyline(outline, Color("#5c1929"), .11, true)
	draw_line(Vector2(-.25, -.35), Vector2(.17, .46), Color("#761f31"), .15, true)
	draw_line(Vector2(-.43, -.29), Vector2(-.37, -.04), Color("#fa6870"), .14, true)
	draw_set_transform(Vector2.ZERO)

func _draw_blood_pool(at: Vector2, radius: float) -> void:
	if radius <= 0.0:
		return
	draw_set_transform(at, 0.0, Vector2(1.0, .30))
	draw_circle(Vector2.ZERO, radius, Color("#7f2033"), true, -1, true)
	draw_circle(Vector2(-.47, .27) * radius, radius * .60, Color("#a62e43"), true, -1, true)
	draw_circle(Vector2(.98, -.35) * radius, radius * .28, Color("#7f2033"), true, -1, true)
	draw_circle(Vector2(-1.25, -.37) * radius, radius * .18, Color("#7f2033"), true, -1, true)
	draw_set_transform(Vector2.ZERO)

func _draw_fall_ground(feet: Vector2, height: float, direction: float, recovery: float) -> void:
	if finishing_spell_art >= 0:
		return
	var ground := feet + Vector2(direction * .99, .27) * height
	_draw_dust(ground, height, clampf((recovery - .70) / .25, 0, 1))
	if _bloodied_hit() or not finisher.is_empty():
		var spread := smoothstep(.80, .97, recovery) * height * (.24 if lethal_bout else .063)
		_draw_blood_pool(ground, spread)

func _draw_impact_burst(at: Vector2, radius: float, tint: Color, recovery: float, direction: float, heavy: bool) -> void:
	var fade := 1.0 - smoothstep(.035, .20, recovery)
	if fade > .0:
		var slash := Vector2(direction * .68, .73) * radius
		var arm := slash.orthogonal() * .48
		var flash := PackedVector2Array([at - slash, at - slash * .19 - arm * .19, at - arm, at + slash * .08 - arm * .25,
			at + slash, at + slash * .13 + arm * .19, at + arm, at - slash * .17 + arm * .22])
		draw_colored_polygon(flash, Color(tint.lightened(.75), fade))
		flash.append(flash[0])
		draw_polyline(flash, Color(tint.darkened(.22), fade), 2.5 if heavy else 1.6, true)
	if heavy:
		var spread := smoothstep(.03, .42, recovery)
		var spark_fade := smoothstep(.03, .10, recovery) * (1.0 - smoothstep(.18, .42, recovery))
		for index in 3:
			var ray := Vector2(direction, -.66 + index * .44).normalized()
			var tip := at + ray * radius * lerpf(.44, 1.5, spread)
			_draw_streak(tip, ray * radius * (.55 - .16 * spread), radius * .044, tint, spark_fade)

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

func _draw_flying_spell(hand: Vector2, target: Vector2, height: float, art: int, phase: float, direction: float, missed: bool) -> void:
	var fireball := art == FIREBALL_ART
	var tint: Color = SPELL_COLORS[art]
	var contact := target - Vector2(0, height * .28) if missed else target
	# Fireball launches from the wrist. Falling Ember enters from above the target.
	var launch := hand if fireball else contact + Vector2(-direction * .45, -.98) * height
	var released_at := FIREBALL_RELEASE if fireball else .23
	if fireball and phase < released_at:
		var charge := smoothstep(.04, released_at, phase)
		draw_circle(hand, height * (.025 + .043 * charge), Color(tint, charge * .28), true, -1, true)
		draw_circle(hand, height * .025 * charge, Color(tint.lightened(.62), charge), true, -1, true)
		return
	var flight := clampf((phase - released_at) / (SPELL_CONTACT - released_at), 0.0, 1.0)
	var travel := contact - launch
	var distance := flight if fireball else flight * (.45 + .55 * flight)
	var center := launch + travel * distance
	var opacity := smoothstep(released_at, released_at + .055, phase)
	opacity *= 1.0 - smoothstep(SPELL_CONTACT, .73, phase)
	if opacity > 0.0:
		var extent := Vector2(.78, .52) * height if fireball else Vector2(.90, .60) * height
		if fireball:
			extent *= lerpf(.22, 1.0, smoothstep(0.0, .60, flight))
		# Anchor the luminous core in the atlas sprite instead of its transparent center.
		var core := Vector2(.82, .54) if fireball else Vector2(.73, .73)
		var art_angle := 0.0 if fireball else .59
		var rotation := (Vector2(travel.x * direction, travel.y).angle() - art_angle) * direction
		draw_set_transform(center, rotation, Vector2(direction, 1))
		draw_texture_rect_region(SPELLS, Rect2(-extent * core, extent), _cell(SPELLS, 2, 2, art), Color(1, 1, 1, opacity))
		draw_set_transform(Vector2.ZERO)
	if open_preview and not missed and phase >= SPELL_CONTACT:
		_draw_impact_burst(contact, height * (.16 if fireball else .24), tint, phase - SPELL_CONTACT, direction, not fireball)

func _draw_spell(start: Vector2, target: Vector2, height: float, art: int, phase: float, direction: float, missed: bool = false) -> void:
	art = clampi(art, 0, SPELL_COLORS.size() - 1)
	if art in [FIREBALL_ART, FALLING_EMBER_ART]:
		_draw_flying_spell(start, target, height, art, phase, direction, missed)
		return
	var tint: Color = SPELL_COLORS[art]
	var charge := smoothstep(.01, .23, phase) * (1.0 - smoothstep(.24, .43, phase))
	if charge > 0.0:
		draw_circle(start, height * (.02 + .085 * charge), Color(tint, charge * .24), true, -1, true)
		draw_circle(start, height * (.01 + .031 * charge), Color(tint.lightened(.5), charge * .91), true, -1, true)
	var fade := 1.0 - smoothstep(SPELL_CONTACT, .97, phase)
	var flight := smoothstep(.24, SPELL_CONTACT, phase)
	if art >= 4:
		_draw_advanced_spell(start, target, height, art, phase, flight, fade, missed)
		return
	var extent := Vector2(1.35, .90) * height
	var aim := target - Vector2(0, extent.y * .48)
	var alpha := fade * smoothstep(.21, .38, phase)
	match art:
		1:
			extent *= 1.29
			aim = target - Vector2(0, extent.y * .48)
			alpha = smoothstep(.50, SPELL_CONTACT, phase) * (1.0 - smoothstep(.65, .91, phase))
		3:
			extent.y *= lerpf(.26, 1.12, smoothstep(.40, .67, phase))
			aim = target - Vector2(0, extent.y * .46)
			alpha = fade * smoothstep(.39, SPELL_CONTACT, phase)
	if missed:
		alpha *= 1.0 - smoothstep(.50, .71, phase)
	if alpha <= 0.0:
		return
	draw_texture_rect_region(SPELLS, Rect2(aim - extent * .5, extent), _cell(SPELLS, 2, 2, art), Color(1, 1, 1, alpha))

func _draw_advanced_spell(start: Vector2, target: Vector2, height: float, art: int, phase: float, flight: float,
		fade: float, missed: bool) -> void:
	if phase < .24 or fade <= 0.0:
		return
	var color: Color = SPELL_COLORS[art]
	var aim := target - Vector2(0, height * .55)
	var opacity := fade * smoothstep(.24, .33, phase)
	if missed:
		opacity *= 1.0 - smoothstep(.48, .70, phase)
	var contact := smoothstep(SPELL_CONTACT, .90, phase)
	match art:
		4:
			var center := start.lerp(aim, flight)
			var trail := start.lerp(aim, maxf(0.0, flight - .22))
			draw_line(trail, center, Color(color, opacity * .60), height * .042, true)
			for index in 6:
				var hue := Color.from_hsv(float(index) / 6.0, .55, 1.0, opacity)
				var ray := Vector2.from_angle(index * TAU / 6.0 + phase * 8.0)
				var point := center + ray * height * (.052 + contact * .45)
				var size_hint := height * (.034 + index * .002)
				var wing := ray.orthogonal() * size_hint * .48
				draw_colored_polygon(PackedVector2Array([point + ray * size_hint, point + wing,
					point - ray * size_hint, point - wing]), hue)
		5:
			var extent := height * Vector2(.88, .88)
			var center := aim - Vector2(0, height * (1.48 * (1.0 - flight) - .42 * contact))
			draw_texture_rect(POCKET_ANVIL, Rect2(center - extent * .5, extent), false, Color(1, 1, 1, opacity))
			if phase >= SPELL_CONTACT and not missed:
				_draw_dust(target, height, contact)
		6:
			var scale_hint := height * (.35 + .64 * flight + .24 * contact)
			var crown := PackedVector2Array([Vector2(-.56, .28), Vector2(-.64, -.38), Vector2(-.29, -.12),
				Vector2(0, -.63), Vector2(.29, -.12), Vector2(.64, -.38), Vector2(.56, .28)])
			var center := aim - Vector2(0, height * .29 * (1.0 - flight))
			for index in crown.size():
				crown[index] = center + crown[index] * scale_hint
			draw_colored_polygon(crown, Color(color, opacity * .34))
			crown.append(crown[0])
			draw_polyline(crown, Color("#ffe594", opacity), maxf(2.0, height * .028), true)
			if phase >= SPELL_CONTACT and not missed:
				for index in 9:
					var flare := Vector2.from_angle(float(index) * TAU / 9.0)
					var point := center + flare * height * (.29 + .66 * contact)
					draw_line(point, point + flare * height * .14, Color(color, opacity), height * .016, true)
		7:
			var point := start.lerp(aim, flight)
			var trail := start.lerp(aim, maxf(0.0, flight - .35))
			var sparks := PackedVector2Array([trail])
			var across := (aim - start).normalized().orthogonal()
			for index in range(1, 5):
				sparks.append(trail.lerp(point, index / 5.0) + across * sin(index * 4.2 + phase * 27.0) * height * .058)
			sparks.append(point)
			draw_polyline(sparks, Color(color, opacity * .6), height * .063, true)
			draw_polyline(sparks, Color("#fff8dd", opacity), height * .016, true)
			if phase >= SPELL_CONTACT and not missed:
				_draw_impact_burst(aim, height * .23, color, phase - SPELL_CONTACT, signf(aim.x - start.x), false)
		8:
			var center := start.lerp(aim, flight)
			var extent := Vector2.ONE * height * (.21 + .47 * flight + .25 * contact)
			draw_texture_rect(BASTION_SPELLS[art], Rect2(center - extent * .5, extent), false, Color(1, 1, 1, opacity))
			if phase >= SPELL_CONTACT and not missed:
				draw_arc(aim, height * (.23 + .48 * contact), 0, TAU, 32,
					Color(color, opacity * contact), height * .018, true)

static func _cell(texture: Texture2D, columns: int, rows: int, index: int) -> Rect2:
	var width := float(texture.get_width()) / columns
	var height := float(texture.get_height()) / rows
	return Rect2((index % columns) * width, floori(float(index) / columns) * height, width, height)
