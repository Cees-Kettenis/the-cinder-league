extends Control
## Displays the resolved duel state and sends action requests to the fight controller.

signal action_selected(action: String)
signal settings_requested

const Duel = preload("res://game/combat/duel.gd")
const Content = preload("res://game/catalog/content_catalog.gd")
const Symbol = preload("res://game/screens/ui_symbol.gd")
const SAND := Color("#f4c68c")
const IVORY := Color("#f8eddb")
const EDGE := Color("#ae784d")
const BUTTON_SIZE := Vector2(88, 60)
const SUPPLY_SIZE := Vector2(106, 64)
const SUPPLY_GAP := 7
const STRIKE_SIZE := Vector2(118, 72)
const BUTTON_LABELS := {
	"advance": "Step in", "retreat": "Step back", "jump": "Leap in", "jump_back": "Leap back",
	"attack": "Attack", "quick": "Quick", "power": "Power", "lunge": "Lunge",
	"guard": "Guard", "sleep": "Sleep", "taunt": "Taunt", "cast": "Spell", "cast_reserve": "Reserve", "potion": "Potion",
}
const METERS := [
	["hp", "max_hp", "health", Color("#e25855")],
	["armor", "max_armor", "armor", Color("#559bd4")],
	["energy", "max_energy", "stamina", Color("#e8a939")],
]

class CrestMeter extends ProgressBar:
	const SHAPES := [
		[Vector2(.50,.02), Vector2(.84,.13), Vector2(.96,.37), Vector2(.91,.68),
			Vector2(.70,.91), Vector2(.50,.99), Vector2(.30,.91), Vector2(.09,.68), Vector2(.04,.37), Vector2(.16,.13)],
		[Vector2(.05,.12), Vector2(.50,.02), Vector2(.95,.12), Vector2(.86,.69), Vector2(.50,.99), Vector2(.14,.69)],
		[Vector2(.30,.03), Vector2(.70,.03), Vector2(.92,.27), Vector2(.92,.75),
			Vector2(.68,.98), Vector2(.32,.98), Vector2(.08,.75), Vector2(.08,.27)],
	]
	var crest: int
	var icon: String
	var tint: Color
	var readout: Label

	func _draw() -> void:
		var crest_size := size - Vector2(0, 22)
		if crest_size.x <= 0.0 or crest_size.y <= 0.0:
			return
		var frame := PackedVector2Array()
		var well := PackedVector2Array()
		for corner: Vector2 in SHAPES[crest]:
			frame.append(corner * crest_size)
			well.append((Vector2.ONE * .09 + corner * .82) * crest_size)
		draw_colored_polygon(frame, Color("#ac7846"))
		draw_colored_polygon(well, Color("#27222b"))
		if value > .002:
			var top := lerpf(crest_size.y * .90, crest_size.y * .10, value)
			var fill := PackedVector2Array([Vector2(0, top), Vector2(crest_size.x, top), crest_size, Vector2(0, crest_size.y)])
			for section in Geometry2D.intersect_polygons(well, fill):
				var colors := PackedColorArray()
				for point in section:
					colors.append(tint.lightened(.18).lerp(tint.darkened(.24), inverse_lerp(top, crest_size.y, point.y)))
				draw_polygon(section, colors)
		frame.append(frame[0])
		draw_polyline(frame, Color("#f2c485"), 1.5, true)
		draw_circle(crest_size * .5, 14, Color("#251b26"), true, -1, true)
		Symbol.paint(self, icon, crest_size * .5 - Vector2.ONE * 11, 22)


class ActionButton extends Button:
	var glyph: Control
	var art: TextureRect
	var caption: Label
	var summary: Label


var action_buttons: Dictionary = {}
var action_layer: Control
var action_preview: Label
var fighter_cards: Array[Dictionary] = []
var save_notice: Label
var settings_button: Button
var pack: PanelContainer
var charges: Dictionary = {}
var auto_sleep_notice: Label
var split_attacks := false
var weapon_action := "attack"
var spell_buttons: Array[String] = []

func build(title_font: Font, spells: Array[String] = Duel.SPELL_ACTIONS) -> void:
	spell_buttons = spells
	mouse_filter = MOUSE_FILTER_IGNORE
	_make_fighter_card(false, title_font)
	_make_fighter_card(true, title_font)

	action_layer = Control.new()
	add_child(action_layer)
	action_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	action_layer.mouse_filter = MOUSE_FILTER_IGNORE
	var supplies := _card(action_layer)
	pack = supplies.get_parent()
	# A fixed, centered dock keeps spell access independent of the arena camera.
	pack.add_theme_stylebox_override("panel", _plate(Color("#30222a", .96), EDGE, 9, 16))
	var items := HBoxContainer.new()
	items.add_theme_constant_override("separation", SUPPLY_GAP)
	supplies.add_child(items)
	pack.hide()
	var actions := Duel.ACTIONS.filter(func(action: String) -> bool: return not Duel.is_spell_action(action) and action != "potion")
	for action in actions + spell_buttons + ["potion"]:
		if action == "lunge":
			continue
		var button := ActionButton.new()
		var supply: bool = Duel.is_spell_action(action) or action == "potion"
		var parent: Control = items if supply else action_layer
		parent.add_child(button)
		button.pressed.connect(func() -> void: action_selected.emit(weapon_action if action == "attack" else action))
		var strike: bool = action in Duel.WEAPON_ACTIONS
		button.custom_minimum_size = SUPPLY_SIZE if supply else (STRIKE_SIZE if strike else BUTTON_SIZE)
		var content := VBoxContainer.new()
		button.add_child(content)
		content.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		content.mouse_filter = MOUSE_FILTER_IGNORE
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 0)
		var icon := Symbol.make("cast" if Duel.is_spell_action(action) else action, 26)
		icon.size_flags_horizontal = SIZE_SHRINK_CENTER
		content.add_child(icon)
		button.glyph = icon
		if supply:
			button.art = TextureRect.new()
			button.art.custom_minimum_size = Vector2(34, 34)
			button.art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			button.art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			button.art.size_flags_horizontal = SIZE_SHRINK_CENTER
			button.art.mouse_filter = MOUSE_FILTER_IGNORE
			button.art.hide()
			content.add_child(button.art)
		button.caption = _action_caption(content, BUTTON_LABELS.get(action, "Spell"), 15, IVORY)
		if supply:
			button.caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			button.caption.add_theme_font_size_override("font_size", 13)
		if strike:
			button.summary = _action_caption(content, "", 13, SAND)
		button.add_theme_stylebox_override("normal", _plate(Color("#3b2c2b"), EDGE, 0, 13))
		button.add_theme_stylebox_override("hover", _plate(Color("#594236"), SAND, 0, 13))
		button.add_theme_stylebox_override("disabled", _plate(Color("#332a2d"), Color("#675560"), 0, 13))
		button.mouse_entered.connect(_update_action_preview, CONNECT_DEFERRED)
		button.mouse_exited.connect(_update_action_preview, CONNECT_DEFERRED)
		button.focus_entered.connect(_update_action_preview, CONNECT_DEFERRED)
		button.focus_exited.connect(_update_action_preview, CONNECT_DEFERRED)
		button.visible = action not in ["quick", "power"]
		button.accessibility_name = Duel.LABELS.get(action, "Spell")
		action_buttons[action] = button
	for action in spell_buttons + ["potion"]:
		var count := _label(action_buttons[action], "", 14, IVORY)
		count.mouse_filter = MOUSE_FILTER_IGNORE
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_color_override("font_outline_color", Color("#261c24"))
		count.add_theme_constant_override("outline_size", 4)
		_dock(count, Vector2(1, 0), Rect2(-32, 4, 24, 20))
		charges[action] = count
	action_preview = _label(action_layer, "", 14, IVORY)
	var tooltip_style := _plate(Color("#251e21"), EDGE, 8, 8)
	tooltip_style.set_border_width_all(1)
	action_preview.add_theme_stylebox_override("normal", tooltip_style)
	action_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_preview.mouse_filter = MOUSE_FILTER_IGNORE
	action_preview.z_index = 1
	action_preview.size.x = 258
	action_preview.hide()

	var notice := _card(self)
	_dock(notice.get_parent(), Vector2(.5, 0), Rect2(-125, 85, 250, 0))
	auto_sleep_notice = _label(notice, "Exhausted · Auto-sleep", 17, SAND)
	auto_sleep_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	show_auto_sleep(false)

	settings_button = _button(self, "")
	_dock(settings_button, Vector2(1, 1), Rect2(-76, -76, 54, 54))
	settings_button.add_theme_stylebox_override("normal", _plate(Color("#3b2c2b"), EDGE, 0, 18))
	settings_button.add_theme_stylebox_override("hover", _plate(Color("#63503a"), SAND, 0, 18))
	Symbol.on_button(settings_button, "settings", 32, "Settings")
	settings_button.pressed.connect(func() -> void:
		action_preview.hide()
		settings_requested.emit())

	var warning := _card(self)
	_dock(warning.get_parent(), Vector2(0, 1), Rect2(22, -78, 385, 54))
	save_notice = _label(warning, "", 15, Color("#ff9c87"))
	save_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.get_parent().hide()

func show_save_error(message: String) -> void:
	save_notice.text = message
	save_notice.get_parent().get_parent().visible = not message.is_empty()

func show_auto_sleep(enabled: bool) -> void:
	auto_sleep_notice.get_parent().get_parent().visible = enabled

func _make_fighter_card(opponent: bool, title_font: Font) -> void:
	var panel := _card(self)
	_dock(panel.get_parent(), Vector2(1 if opponent else 0, 0), Rect2(-256 if opponent else 23, 21, 233, 0))
	var title := _label(panel, "", 22, IVORY)
	title.add_theme_font_override("font", title_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if opponent else HORIZONTAL_ALIGNMENT_LEFT
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var status := _label(panel, "", 14, SAND)
	status.horizontal_alignment = title.horizontal_alignment
	status.hide()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	var bars: Array[ProgressBar] = []
	for index in METERS.size():
		var meter: Array = METERS[index]
		var bar := CrestMeter.new()
		bar.crest = index
		bar.icon = meter[2]
		bar.tint = meter[3]
		bar.custom_minimum_size = Vector2(61, 78)
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.step = 0.0
		bar.accessibility_name = str(meter[2]).capitalize()
		bar.mouse_filter = MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
		bar.add_theme_stylebox_override("fill", StyleBoxEmpty.new())
		bar.value_changed.connect(func(_value: float) -> void: bar.queue_redraw())
		row.add_child(bar)
		bar.readout = _action_caption(bar, "", 17, IVORY)
		_dock(bar.readout, Vector2(.5, 1), Rect2(-32, -22, 64, 22))
		if opponent:
			row.move_child(bar, 0)
		bars.append(bar)
	fighter_cards.append({"name": title, "status": status, "bars": bars})

func refresh(bout: RefCounted, locked: bool) -> void:
	for index in fighter_cards.size():
		var fighter: Dictionary = bout.fighters[index]
		var card := fighter_cards[index]
		card.name.text = fighter.name
		var status := PackedStringArray()
		var ward := int(fighter.get("magic_shield", 0))
		if ward > 0:
			status.append("Ward %d" % ward)
		var hits := int(fighter.get("enchant_hits", 0))
		if hits > 0:
			status.append("Etching %d" % hits)
		card.status.text = " · ".join(status)
		card.status.visible = not status.is_empty()
		for row in METERS.size():
			var meter: Array = METERS[row]
			var bar: CrestMeter = card.bars[row]
			var current := int(fighter[meter[0]])
			var capacity := int(fighter[meter[1]])
			bar.value = float(current) / maxf(1.0, capacity)
			bar.readout.text = "%d/%d" % [current, capacity]
			bar.accessibility_description = "%d out of %d" % [current, capacity]
	# Update the meters at impact even while the animation locks the action buttons.
	action_layer.visible = not locked and bout.active == 0 and bout.winner == -2
	show_auto_sleep(action_layer.visible and bout.must_sleep())
	if not action_layer.visible:
		_update_action_preview()
		return
	var player: Dictionary = bout.fighters[0]
	var has_potion: bool = player.loadout.get("potion", false) or not str(player.get("draught", "")).is_empty() or player.potions > 0
	var supplies := int(has_potion)
	for action in spell_buttons:
		var spell := Duel.spell_for_action(player, action)
		action_buttons[action].visible = not spell.is_empty()
		charges[action].text = str(Duel.spell_charges(player, action))
		supplies += int(not spell.is_empty())
	action_buttons.potion.visible = has_potion
	pack.visible = supplies > 0
	var pack_width := supplies * SUPPLY_SIZE.x + maxi(0, supplies - 1) * SUPPLY_GAP + 18.0
	_dock(pack, Vector2(.5, 1), Rect2(-pack_width * .5, -101, pack_width, 82))
	charges.potion.text = str(int(player.potions))
	# Reuse the main strike button for lunge at range. Quick and power appear at weapon reach.
	weapon_action = "lunge" if bout.in_lunge_range() else "attack"
	split_attacks = bout.in_weapon_reach() and bout.has_attack_styles()
	action_buttons.quick.visible = split_attacks
	action_buttons.power.visible = split_attacks
	for key in action_buttons:
		var action: String = weapon_action if key == "attack" else key
		var button: ActionButton = action_buttons[key]
		var reason: String = bout.reason(action)
		button.disabled = not reason.is_empty()
		button.glyph.modulate = Color("#afa4a7") if button.disabled else Color.WHITE
		var icon := action
		var item_id := ""
		if Duel.is_spell_action(action):
			var spell := Duel.spell_for_action(player, action)
			var effect: String = spell.get("effect", "damage")
			icon = {"shield": "shield", "push": "advance", "pull": "retreat", "enchant": "attack"}.get(effect, "cast")
			item_id = spell.get("id", "")
		elif action == "potion":
			item_id = "armor_potion" if player.get("draught", "") == "armor_potion" else "potion"
		if button.art != null:
			button.art.texture = Content.MAGIC_ICONS.get(item_id)
			button.art.visible = button.art.texture != null
			button.art.modulate = Color("#aeaaa5") if button.disabled else Color.WHITE
			button.glyph.visible = not button.art.visible
		if button.glyph.symbol != icon:
			button.glyph.symbol = icon
			button.glyph.queue_redraw()
		if reason.begins_with("Needs"):
			reason = reason.replace("Needs", "Requires")
		var title: String = Duel.LABELS.get(action, "Spell")
		button.caption.text = BUTTON_LABELS.get(action, "Spell")
		if action == "attack":
			button.caption.text = "Normal" if split_attacks else "Attack"
			if split_attacks:
				title = "Normal attack"
		if Duel.is_spell_action(action) and button.visible:
			title = Duel.spell_for_action(player, action).name
			button.caption.text = title
		if action == "potion":
			title = "Armor Potion" if player.get("draught", "") == "armor_potion" else "Health Potion"
			button.caption.text = title
		button.accessibility_name = title
		if not button.visible:
			continue
		var detail := _describe_action(bout, action, title, button, reason)
		button.accessibility_description = detail

func _describe_action(bout: RefCounted, action: String, title: String, button: ActionButton, reason: String) -> String:
	var player: Dictionary = bout.fighters[0]
	var cost := "%d stamina" % bout.cost(action)
	if Duel.is_spell_action(action):
		var spell := Duel.spell_for_action(player, action)
		var effect: String = spell.get("effect", "damage")
		if effect != "damage":
			if not reason.is_empty():
				return "%s · %s" % [title, reason]
			var description: String
			match effect:
				"shield": description = "Absorb up to %d damage from the next hit" % spell.power
				"push":
					var shift: int = bout.spell_displacement(spell, 0)
					description = "Push the rival %s back · Final gap %s" % [_spaces(shift), _spaces(bout.distance() + shift)]
				"pull":
					var shift: int = bout.spell_displacement(spell, 0)
					description = "Bring the rival next to you" if bout.distance() - shift == 1 else "Pull the rival %s closer" % _spaces(shift)
				"enchant": description = "+%d damage on the next 3 weapon hits" % Duel.enchant_bonus(spell, player)
			return "%s · %s · %s" % [title, description, cost]
	if action in Duel.WEAPON_ACTIONS or Duel.is_spell_action(action):
		if reason in ["Out of weapon reach", "Out of spell range"]:
			if button.summary != null:
				button.summary.text = "Out of reach"
			return "%s\n%s away · %s" % [reason, _spaces(bout.distance()), cost]
		var damage := maxi(1, roundi(bout.action_damage(action, player, bout.fighters[1])))
		var accuracy := roundi(100.0 * bout.chance(action))
		if button.summary != null:
			button.summary.text = "%d dmg · %d%% hit" % [damage, accuracy]
		return _strike_preview(bout, action, title, cost, damage, accuracy, reason)
	if not reason.is_empty():
		return "%s · %s" % [title, reason]
	match action:
		"advance", "jump": return "%s · Move %s toward the rival · %s" % [title, _spaces(bout.travel(action)), cost]
		"retreat", "jump_back": return "%s · Move %s away from the rival · %s" % [title, _spaces(bout.travel(action)), cost]
		"guard":
			var block := roundi(100.0 * Duel.block_chance(bout.rules, player.stats.Defence, true))
			return "Guard · %d%% chance to reduce damage from a hit · %s" % [block, cost]
		"sleep":
			var restored := mini(player.max_energy - player.energy, Duel.recovery(bout.rules, player.stats.Stamina))
			return "Sleep · Recover %d stamina · Easier to hit and cannot block" % restored
		"taunt":
			var provoke := roundi(100.0 * Duel.taunt_chance(bout.rules, player.stats.Charisma))
			return "Taunt · %d%% chance to provoke, otherwise %d damage · %s" % [provoke, Duel.taunt_damage(bout.rules, player.stats.Charisma), cost]
		"potion":
			var amount := mini(Duel.potion_missing(player), Duel.potion_amount(bout.rules, player))
			return "%s · Restore %d %s" % [title, amount, "armor" if player.get("draught", "") == "armor_potion" else "health"]
	return title

func _strike_preview(bout: RefCounted, action: String, title: String, cost: String, damage: int, accuracy: int, reason: String) -> String:
	var rival: Dictionary = bout.fighters[1]
	var block := 0 if rival.exposed else roundi(100.0 * Duel.block_chance(bout.rules, rival.stats.Defence, rival.guarding))
	var odds := "%d%% hit · %d%% block if hit" % [accuracy, block]
	var spell := Duel.is_spell_action(action)
	if spell:
		odds = title + "\n" + odds
	if not reason.is_empty():
		return odds + "\n" + reason
	# Use the duel rules for the clean-hit preview, including armor and the regular-bout yield threshold.
	var ward := mini(damage, int(rival.get("magic_shield", 0)))
	var armor := mini(damage - ward, rival.armor)
	var health: int = bout.health_damage(action, damage, rival)
	var wins: bool = bout.health_hit_wins(rival, health)
	var losses := "%d HP" % health if armor == 0 else "%d armor" % armor
	if armor > 0 and health > 0:
		losses += " and %d HP" % health
	var impact := "Clean hit takes " + losses
	if ward > 0:
		impact += " · Ward absorbs %d" % ward
	if wins:
		impact += " · Wins bout" if bout.regular_bout else " · Fatal"
	elif action == "power" and bout.power_push() > 0:
		cost += " · Pushes " + _spaces(bout.power_push())
	if action == "lunge":
		cost += " · Moves " + _spaces(bout.lunge_spaces())
	return odds + "\n" + cost + "\n" + impact

func _spaces(count: int) -> String:
	return "%d %s" % [count, "space" if count == 1 else "spaces"]

func _update_action_preview() -> void:
	if not is_inside_tree() or not action_layer.is_visible_in_tree():
		action_preview.hide()
		return
	var hovered := get_viewport().gui_get_hovered_control()
	var focused := get_viewport().gui_get_focus_owner()
	var button := hovered as ActionButton
	if button == null:
		button = focused as ActionButton
	if button == null or not button.is_visible_in_tree() or button.accessibility_description.is_empty():
		action_preview.hide()
		return
	action_preview.text = button.accessibility_description
	action_preview.size.y = action_preview.get_minimum_size().y
	var area := button.get_global_rect()
	var center := area.get_center() - action_preview.size * .5
	var in_pack := button.get_parent() != action_layer
	if in_pack:
		area = pack.get_global_rect()
	elif action_buttons.find_key(button) in Duel.MOVEMENT:
		area = action_buttons.retreat.get_global_rect().merge(action_buttons.jump.get_global_rect())
	var bounds := get_global_rect().grow(-12.0)
	var extent := action_preview.size
	var x := clampf(center.x, bounds.position.x, bounds.end.x - extent.x)
	var above := Vector2(x, area.position.y - extent.y - 8)
	var below := Vector2(x, area.end.y + 8)
	var left_card: Control = fighter_cards[0].name.get_parent().get_parent()
	var right_card: Control = fighter_cards[1].name.get_parent().get_parent()
	var between_cards := clampf(x, left_card.get_global_rect().end.x + 8,
		right_card.get_global_rect().position.x - extent.x - 8)
	var above_between_cards := Vector2(between_cards, above.y)
	var options := [above, above_between_cards, below] if button.summary != null or in_pack else [below, above, above_between_cards]
	var y := clampf(center.y, bounds.position.y, bounds.end.y - extent.y)
	options.append(Vector2(area.position.x - extent.x - 8, y))
	options.append(Vector2(area.end.x + 8, y))
	var occupied := action_buttons.values() + [settings_button, pack, save_notice.get_parent().get_parent(),
		auto_sleep_notice.get_parent().get_parent(), left_card, right_card]
	for tip_position: Vector2 in options:
		var candidate := Rect2(tip_position, extent)
		if bounds.encloses(candidate) and not occupied.any(func(control: Control) -> bool:
				return control.is_visible_in_tree() and control.get_global_rect().intersects(candidate)):
			action_preview.global_position = tip_position
			action_preview.show()
			return
	action_preview.hide()

## Anchor the buttons to the fighter in screen coordinates so they follow arena camera movement.
func place_actions(feet: Vector2, fighter_height: float) -> void:
	var top := maxf(183, feet.y - maxf(118, fighter_height + 38))
	if split_attacks:
		var attack_center := clampf(feet.x, 200, size.x - 200)
		_place("quick", Vector2(attack_center - 126, top))
		_place("attack", Vector2(attack_center, top))
		_place("power", Vector2(attack_center + 126, top))
	else:
		_place("attack", Vector2(feet.x, top))
	var movement_offset := clampf(fighter_height * .49, 109, 155)
	var movement_left := feet.x - movement_offset - 96
	# Move controls to the other side of the fighter when there is too little room on the left.
	if movement_left < 59:
		movement_left = feet.x + movement_offset
	movement_left = clampf(movement_left, 59, size.x - 155)
	var movement_top := feet.y - clampf(fighter_height * .69, 108, 180)
	_place("retreat", Vector2(movement_left, movement_top))
	_place("advance", Vector2(movement_left + 96, movement_top))
	_place("jump_back", Vector2(movement_left, movement_top + 68))
	_place("jump", Vector2(movement_left + 96, movement_top + 68))
	var center := clampf(feet.x, 155, size.x - 155)
	_place("guard", Vector2(center - 96, feet.y + 56))
	_place("sleep", Vector2(center, feet.y + 56))
	_place("taunt", Vector2(center + 96, feet.y + 56))
	_update_action_preview()

func _place(action: String, center: Vector2) -> void:
	var button: Button = action_buttons[action]
	button.size = button.custom_minimum_size
	button.position = Vector2(clampf(center.x - button.size.x * .5, 15, size.x - button.size.x - 15), center.y - button.size.y * .5)

func _card(parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _plate(Color("#3a292e"), EDGE, 12, 16))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	content.add_theme_constant_override("separation", 4)
	return content

func _label(parent: Control, value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _action_caption(parent: Control, value: String, font_size: int, color: Color) -> Label:
	var label := _label(parent, value, font_size, color)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _button(parent: Control, value: String) -> Button:
	var button := Button.new()
	button.text = value
	parent.add_child(button)
	return button

func _plate(fill: Color, edge: Color, padding: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		box.set_content_margin(side, padding)
	return box

func _dock(control: Control, anchor: Vector2, rect: Rect2) -> void:
	control.anchor_left = anchor.x
	control.anchor_right = anchor.x
	control.anchor_top = anchor.y
	control.anchor_bottom = anchor.y
	control.offset_left = rect.position.x
	control.offset_right = rect.end.x
	control.offset_top = rect.position.y
	control.offset_bottom = rect.end.y
