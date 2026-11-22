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
	["hp", "max_hp", "health", Color("#f4706e"), 22],
	["armor", "max_armor", "armor", Color("#8bbbe8"), 15],
	["energy", "max_energy", "stamina", Color("#f5c451"), 17],
]

var action_buttons: Dictionary = {}
var action_layer := Control.new()
var fighter_cards: Array[Dictionary] = []
var save_notice: Label
var settings_button: Button
var cast_charges: Label
var split_attacks := false
var weapon_action := "attack"

func build(arena_name: String, title_font: Font) -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var banner := _card()
	_dock(banner.get_parent(), Vector2(.5, 0), Rect2(-175, 21, 350, 0))
	var arena_label := _label(banner, arena_name, 30, IVORY)
	arena_label.add_theme_font_override("font", title_font)
	arena_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_make_fighter_card(false, title_font)
	_make_fighter_card(true, title_font)

	add_child(action_layer)
	action_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	action_layer.mouse_filter = MOUSE_FILTER_IGNORE
	for action in Duel.ACTIONS:
		if action == "lunge":
			continue
		var button := _button(action_layer, "")
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
	cast_charges = _label(action_buttons.cast, "", 14, IVORY)
	cast_charges.mouse_filter = MOUSE_FILTER_IGNORE
	cast_charges.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cast_charges.add_theme_color_override("font_outline_color", Color("#261c24"))
	cast_charges.add_theme_constant_override("outline_size", 4)
	_dock(cast_charges, Vector2.ONE, Rect2(-36, -21, 30, 20))

	settings_button = _button(self, "")
	_dock(settings_button, Vector2(1, 1), Rect2(-76, -76, 54, 54))
	settings_button.add_theme_stylebox_override("normal", _plate(Color("#3b2c2b"), EDGE, 0, 18))
	settings_button.add_theme_stylebox_override("hover", _plate(Color("#63503a"), SAND, 0, 18))
	Symbol.on_button(settings_button, "settings", 32, "Settings")
	settings_button.pressed.connect(func() -> void: settings_requested.emit())

	var warning := _card()
	_dock(warning.get_parent(), Vector2(0, 1), Rect2(22, -78, 385, 54))
	save_notice = _label(warning, "", 15, Color("#ff9c87"))
	save_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.get_parent().hide()

func show_save_error(message: String) -> void:
	save_notice.text = message
	save_notice.get_parent().get_parent().visible = not message.is_empty()

func _make_fighter_card(opponent: bool, title_font: Font) -> void:
	var panel := _card()
	_dock(panel.get_parent(), Vector2(1 if opponent else 0, 0), Rect2(-281 if opponent else 23, 21, 258, 0))
	var title := _label(panel, "", 23, IVORY)
	title.add_theme_font_override("font", title_font)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var bars: Array[ProgressBar] = []
	for meter in METERS:
		var line := HBoxContainer.new()
		panel.add_child(line)
		line.add_theme_constant_override("separation", 9)
		line.add_child(Symbol.make(meter[2], 23))
		var bar := ProgressBar.new()
		line.add_child(bar)
		bar.size_flags_horizontal = SIZE_EXPAND_FILL
		bar.size_flags_vertical = SIZE_SHRINK_CENTER
		bar.custom_minimum_size.y = meter[4]
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.step = 0.0
		bar.accessibility_name = str(meter[2]).capitalize()
		bar.mouse_filter = MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", _plate(Color("#261c24"), Color("#987153"), 0, 12))
		bar.add_theme_stylebox_override("fill", _plate(meter[3], meter[3].lightened(.35), 0, 12))
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
	if not action_layer.visible:
		return
	var player: Dictionary = bout.fighters[0]
	cast_charges.visible = not player.spell.is_empty()
	cast_charges.text = str(int(player.casts))
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
		if action == "cast" and not player.spell.is_empty():
			title = "%s · %d %s left" % [player.spell.name, player.casts, "cast" if player.casts == 1 else "casts"]
		button.accessibility_name = title
		match action:
			"lunge":
				var spaces: int = bout.lunge_spaces()
				title += " · %d %s · %d stamina · Lower accuracy" % [spaces, "space" if spaces == 1 else "spaces", bout.cost(action)]
			"advance", "retreat", "jump":
				var spaces: int = bout.travel(action)
				if spaces > 0:
					title += " · %d %s · %d stamina" % [spaces, "space" if spaces == 1 else "spaces", bout.cost(action)]
			"power":
				if split_attacks:
					title += " · %d stamina · More damage · Lower accuracy · Push %d" % [bout.cost(action), bout.power_push()]
			"quick": title += " · %d stamina · Less damage · Higher accuracy" % bout.cost(action)
		button.tooltip_text = title if reason.is_empty() else "%s · %s" % [title, reason]

func place_actions(feet: Vector2, fighter_height: float) -> void:
	var top := maxf(175, feet.y - maxf(236, fighter_height + 24))
	if split_attacks:
		var attack_center := clampf(feet.x, 153, size.x - 153)
		_place("quick", Vector2(attack_center - 108, top))
		_place("attack", Vector2(attack_center - 36, top))
		_place("power", Vector2(attack_center + 36, top))
		_place("cast", Vector2(attack_center + 108, top))
	else:
		_place("attack", Vector2(feet.x - 40, top))
		_place("cast", Vector2(feet.x + 40, top))
	var movement_offset := clampf(fighter_height * .42, 92, 155)
	var movement_x := feet.x - movement_offset
	if movement_x < 45:
		movement_x = feet.x + movement_offset
	_place("advance", Vector2(movement_x + 10, top + 72))
	_place("jump", Vector2(movement_x - 6, top + 140))
	_place("retreat", Vector2(movement_x + 10, top + 208))
	var spacing := BUTTON_SIZE.x + 12
	var center := clampf(feet.x, 2 * spacing + 15, size.x - 2 * spacing - 15)
	_place("guard", Vector2(center - 1.5 * spacing, feet.y + 37))
	_place("sleep", Vector2(center - .5 * spacing, feet.y + 61))
	_place("taunt", Vector2(center + .5 * spacing, feet.y + 61))
	_place("potion", Vector2(center + 1.5 * spacing, feet.y + 37))

func _place(action: String, center: Vector2) -> void:
	var button: Button = action_buttons[action]
	button.size = BUTTON_SIZE
	button.position = Vector2(clampf(center.x - BUTTON_SIZE.x * .5, 15, size.x - BUTTON_SIZE.x - 15), center.y - BUTTON_SIZE.y * .5)

func _card() -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _plate(Color("#3a292e"), EDGE, 12, 16))
	add_child(panel)
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
