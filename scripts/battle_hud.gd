extends Control

signal action_selected(action: String)
signal settings_requested

const Duel = preload("res://scripts/duel.gd")
const Symbol = preload("res://scripts/ui_symbol.gd")
const SAND := Color("#f4c68c")
const IVORY := Color("#f8eddb")
const EDGE := Color("#ae784d")
const BUTTON_SIZE := Vector2(60, 60)
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

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		var frame := PackedVector2Array()
		var well := PackedVector2Array()
		for corner: Vector2 in SHAPES[crest]:
			frame.append(corner * size)
			well.append((Vector2.ONE * .09 + corner * .82) * size)
		draw_colored_polygon(frame, Color("#ac7846"))
		draw_colored_polygon(well, Color("#27222b"))
		if value > .002:
			var top := lerpf(size.y * .90, size.y * .10, value)
			var fill := PackedVector2Array([Vector2(0, top), Vector2(size.x, top), size, Vector2(0, size.y)])
			for section in Geometry2D.intersect_polygons(well, fill):
				var colors := PackedColorArray()
				for point in section:
					colors.append(tint.lightened(.18).lerp(tint.darkened(.24), inverse_lerp(top, size.y, point.y)))
				draw_polygon(section, colors)
		frame.append(frame[0])
		draw_polyline(frame, Color("#f2c485"), 1.5, true)
		draw_circle(size * .5, 15, Color("#251b26"), true, -1, true)
		Symbol.paint(self, icon, size * .5 - Vector2.ONE * 11, 22)


var action_buttons: Dictionary = {}
var action_layer := Control.new()
var fighter_cards: Array[Dictionary] = []
var save_notice: Label
var settings_button: Button
var pack: PanelContainer
var charges: Dictionary = {}
var auto_sleep_notice: Label
var split_attacks := false
var weapon_action := "attack"

func build(arena_name: String, title_font: Font) -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var banner := _card(self)
	_dock(banner.get_parent(), Vector2(.5, 0), Rect2(-175, 21, 350, 0))
	var arena_label := _label(banner, arena_name, 30, IVORY)
	arena_label.add_theme_font_override("font", title_font)
	arena_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_make_fighter_card(false, title_font)
	_make_fighter_card(true, title_font)

	add_child(action_layer)
	action_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	action_layer.mouse_filter = MOUSE_FILTER_IGNORE
	var supplies := _card(action_layer)
	pack = supplies.get_parent()
	_dock(pack, Vector2.ONE, Rect2(-258, -114, 159, 98))
	_label(supplies, "Pack", 14, SAND)
	var items := HBoxContainer.new()
	items.add_theme_constant_override("separation", 7)
	supplies.add_child(items)
	pack.hide()
	for action in Duel.ACTIONS:
		if action == "lunge":
			continue
		var button := _button(items if action in ["cast", "potion"] else action_layer, "")
		button.pressed.connect(func() -> void: action_selected.emit(weapon_action if action == "attack" else action))
		button.custom_minimum_size = BUTTON_SIZE
		Symbol.on_button(button, action, 36, Duel.LABELS[action])
		var fill := Color("#45312b")
		match action:
			"attack": fill = Color("#924a3d")
			"power": fill = Color("#a3592c")
			"quick": fill = Color("#526878")
			"cast": fill = Color("#634f90")
			"guard": fill = Color("#36566b")
			"sleep", "potion": fill = Color("#365447")
		button.add_theme_stylebox_override("normal", _plate(fill, EDGE, 0, 22))
		button.add_theme_stylebox_override("hover", _plate(fill.lightened(.18), SAND, 0, 22))
		button.add_theme_stylebox_override("disabled", _plate(Color("#332a2d"), Color("#675560"), 0, 22))
		button.visible = action not in ["quick", "power"]
		action_buttons[action] = button
	for action in ["cast", "potion"]:
		var count := _label(action_buttons[action], "", 14, IVORY)
		count.mouse_filter = MOUSE_FILTER_IGNORE
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_color_override("font_outline_color", Color("#261c24"))
		count.add_theme_constant_override("outline_size", 4)
		_dock(count, Vector2.ONE, Rect2(-36, -21, 29, 20))
		charges[action] = count

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
	settings_button.pressed.connect(func() -> void: settings_requested.emit())

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
		bar.custom_minimum_size = Vector2(61, 64)
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.step = 0.0
		bar.accessibility_name = str(meter[2]).capitalize()
		bar.mouse_filter = MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
		bar.add_theme_stylebox_override("fill", StyleBoxEmpty.new())
		bar.value_changed.connect(func(_value: float) -> void: bar.queue_redraw())
		row.add_child(bar)
		if opponent:
			row.move_child(bar, 0)
		bars.append(bar)
	fighter_cards.append({"name": title, "bars": bars})

func refresh(bout: RefCounted, locked: bool) -> void:
	for index in fighter_cards.size():
		var fighter: Dictionary = bout.fighters[index]
		var card := fighter_cards[index]
		card.name.text = fighter.name
		for row in METERS.size():
			var meter: Array = METERS[row]
			card.bars[row].value = float(fighter[meter[0]]) / maxf(1.0, fighter[meter[1]])
	action_layer.visible = not locked and bout.active == 0 and bout.winner == -2
	show_auto_sleep(action_layer.visible and bout.must_sleep())
	if not action_layer.visible:
		return
	var player: Dictionary = bout.fighters[0]
	var has_spell: bool = not player.spell.is_empty()
	var has_potion: bool = player.loadout.get("potion", false) or player.potions > 0
	action_buttons.cast.visible = has_spell
	action_buttons.potion.visible = has_potion
	pack.visible = has_spell or has_potion
	charges.cast.text = str(int(player.casts))
	charges.potion.text = str(int(player.potions))
	weapon_action = "lunge" if bout.in_lunge_range() else "attack"
	split_attacks = bout.in_weapon_reach() and bout.has_attack_styles()
	action_buttons.quick.visible = split_attacks
	action_buttons.power.visible = split_attacks
	for key in action_buttons:
		var action: String = weapon_action if key == "attack" else key
		var button: Button = action_buttons[key]
		var reason: String = bout.reason(action)
		button.disabled = not reason.is_empty()
		var icon: Control = button.get_child(0)
		icon.modulate = Color("#afa4a7") if button.disabled else Color.WHITE
		if icon.symbol != action:
			icon.symbol = action
			icon.queue_redraw()
		if reason.begins_with("Needs"):
			reason = "Not enough stamina"
		elif reason == "Out of weapon reach" and action == "attack":
			reason = "Out of weapon reach. Move closer."
		var title: String = Duel.LABELS[action]
		if action == "attack" and split_attacks:
			title = "Normal attack"
		if action == "cast" and has_spell:
			title = "%s · %d %s left" % [player.spell.name, player.casts, "cast" if player.casts == 1 else "casts"]
		button.accessibility_name = title
		match action:
			"lunge":
				var spaces: int = bout.lunge_spaces()
				title += " · %d %s · %d stamina · Lower accuracy" % [spaces, "space" if spaces == 1 else "spaces", bout.cost(action)]
			"advance", "retreat", "jump", "jump_back":
				var spaces: int = bout.travel(action)
				if spaces > 0:
					title += " · %d %s · %d stamina" % [spaces, "space" if spaces == 1 else "spaces", bout.cost(action)]
			"power":
				if split_attacks:
					title += " · %d stamina · More damage · Lower accuracy · Push %d" % [bout.cost(action), bout.power_push()]
			"quick": title += " · %d stamina · Less damage · Higher accuracy" % bout.cost(action)
			"attack", "guard", "cast", "taunt": title += " · %d stamina" % bout.cost(action)
		button.tooltip_text = title if reason.is_empty() else "%s · %s" % [title, reason]

func place_actions(feet: Vector2, fighter_height: float) -> void:
	var top := maxf(183, feet.y - maxf(118, fighter_height + 26))
	if split_attacks:
		var attack_center := clampf(feet.x, 107, size.x - 107)
		_place("quick", Vector2(attack_center - 72, top))
		_place("attack", Vector2(attack_center, top))
		_place("power", Vector2(attack_center + 72, top))
	else:
		_place("attack", Vector2(feet.x, top))
	var movement_offset := clampf(fighter_height * .42, 101, 155)
	var movement_left := feet.x - movement_offset - 68
	if feet.x < 145:
		movement_left = feet.x + movement_offset
	movement_left = clampf(movement_left, 45, size.x - 113)
	var movement_top := feet.y - clampf(fighter_height * .69, 108, 180)
	_place("retreat", Vector2(movement_left, movement_top))
	_place("advance", Vector2(movement_left + 68, movement_top))
	_place("jump_back", Vector2(movement_left, movement_top + 71))
	_place("jump", Vector2(movement_left + 68, movement_top + 71))
	var center := clampf(feet.x, 117, size.x - 117)
	_place("guard", Vector2(center - 72, feet.y + 52))
	_place("sleep", Vector2(center, feet.y + 66))
	_place("taunt", Vector2(center + 72, feet.y + 52))

func _place(action: String, center: Vector2) -> void:
	var button: Button = action_buttons[action]
	button.size = BUTTON_SIZE
	button.position = Vector2(clampf(center.x - BUTTON_SIZE.x * .5, 15, size.x - BUTTON_SIZE.x - 15), center.y - BUTTON_SIZE.y * .5)

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
