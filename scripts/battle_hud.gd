extends Control

signal action_selected(action: String)
signal sound_toggled
signal window_toggled

const Duel = preload("res://scripts/duel.gd")
const SAND := Color("#f4c68c")
const IVORY := Color("#f8eddb")
const EDGE := Color("#826440")
const BUTTON_SIZE := Vector2(138, 52)
const METERS := [
	["hp", "max_hp", "Health", Color("#e87962")],
	["armor", "max_armor", "Armor", Color("#ebbd76")],
	["energy", "max_energy", "Stamina", Color("#91d3ac")],
]

var action_buttons: Dictionary = {}
var action_layer := Control.new()
var fighter_cards: Array[Dictionary] = []
var turn_label: Label
var event_label: Label
var save_notice: Label
var window_button: Button
var sound_button: Button

func build(arena_name: String, seed: String, title_font: Font) -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var banner := _card()
	_dock(banner.get_parent(), Vector2(.5, 0), Rect2(-175, 21, 350, 0))
	var arena_label := _label(banner, arena_name, 30, IVORY)
	arena_label.add_theme_font_override("font", title_font)
	arena_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.get_parent().tooltip_text = "Seed " + seed
	turn_label = _label(banner, "", 15, SAND)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_make_fighter_card(false, title_font)
	_make_fighter_card(true, title_font)

	add_child(action_layer)
	action_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	action_layer.mouse_filter = MOUSE_FILTER_IGNORE
	for action in Duel.ACTIONS:
		var button := _button(action_layer, Duel.LABELS[action])
		button.pressed.connect(func() -> void: action_selected.emit(action))
		button.custom_minimum_size = BUTTON_SIZE
		button.clip_text = true
		var fill := Color("#29261f")
		if action == "attack":
			fill = Color("#643729")
		elif action == "cast":
			fill = Color("#253e50")
		button.add_theme_stylebox_override("normal", _plate(fill, EDGE, 5))
		button.add_theme_stylebox_override("hover", _plate(fill.lightened(.18), SAND, 5))
		button.add_theme_stylebox_override("disabled", _plate(Color(.12, .13, .12, .91), Color("#575548"), 5))
		action_buttons[action] = button

	var feed := _card()
	_dock(feed.get_parent(), Vector2(0, 1), Rect2(23, -72, 510, 50))
	feed.get_parent().grow_vertical = GROW_DIRECTION_BEGIN
	event_label = _label(feed, "Choose your move.", 15, IVORY)
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_notice = _label(feed, "", 13, Color("#ff9c87"))
	save_notice.hide()
	var settings := HBoxContainer.new()
	add_child(settings)
	_dock(settings, Vector2(1, 1), Rect2(-280, -64, 256, 42))
	settings.alignment = BoxContainer.ALIGNMENT_END
	window_button = _button(settings, "Windowed")
	window_button.pressed.connect(func() -> void: window_toggled.emit())
	sound_button = _button(settings, "Sound on")
	sound_button.pressed.connect(func() -> void: sound_toggled.emit())

func _make_fighter_card(opponent: bool, title_font: Font) -> void:
	var panel := _card()
	_dock(panel.get_parent(), Vector2(1 if opponent else 0, 0), Rect2(-281 if opponent else 23, 21, 258, 0))
	var title := _label(panel, "", 23, IVORY)
	title.add_theme_font_override("font", title_font)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var rows: Array[Dictionary] = []
	for meter in METERS:
		var line := HBoxContainer.new()
		panel.add_child(line)
		var label := _label(line, meter[2], 13, meter[3])
		label.custom_minimum_size.x = 53
		var bar := ProgressBar.new()
		line.add_child(bar)
		bar.size_flags_horizontal = SIZE_EXPAND_FILL
		bar.size_flags_vertical = SIZE_SHRINK_CENTER
		bar.custom_minimum_size.y = 7
		bar.show_percentage = false
		bar.add_theme_stylebox_override("background", _plate(Color("#20231f"), Color("#514637"), 0))
		bar.add_theme_stylebox_override("fill", _plate(meter[3], meter[3], 0))
		var value := _label(line, "", 13, IVORY)
		value.custom_minimum_size.x = 66
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rows.append({"bar": bar, "label": value})
	fighter_cards.append({"name": title, "rows": rows})

func refresh(bout: RefCounted, locked: bool) -> void:
	for index in fighter_cards.size():
		var fighter: Dictionary = bout.fighters[index]
		var card := fighter_cards[index]
		card.name.text = fighter.name
		for row in METERS.size():
			var meter: Array = METERS[row]
			var current := int(fighter[meter[0]])
			var capacity := int(fighter[meter[1]])
			card.rows[row].bar.max_value = maxi(1, capacity)
			card.rows[row].bar.value = current
			card.rows[row].label.text = "%d / %d" % [current, capacity]
	action_layer.visible = not locked and bout.active == 0 and bout.winner == -2
	if not action_layer.visible:
		return
	turn_label.text = "Your move   ·   Distance %d" % bout.distance()
	var fighter: Dictionary = bout.fighters[0]
	for action in Duel.ACTIONS:
		var button: Button = action_buttons[action]
		var title: String = Duel.LABELS[action]
		if action == "cast" and not fighter.spell.is_empty():
			title = fighter.spell.name
		var why: String = bout.reason(action)
		button.disabled = not why.is_empty()
		button.tooltip_text = why
		var detail := why
		if why.begins_with("Provoked."):
			detail = "Provoked"
		elif why.ends_with("current stamina"):
			detail = "Need %d st. now" % int(bout.rules.taunt_minimum)
		elif why in ["Out of weapon reach", "Out of spell range"]:
			detail = "Out of range"
		elif why == "No draught available":
			detail = "No potions"
		elif why == "Already face to face":
			detail = "At closest range"
		elif why.is_empty():
			var stamina: int = bout.cost(action)
			detail = "%d stamina" % stamina if stamina > 0 else ""
			match action:
				"attack":
					detail = "%d st. · %d%% hit" % [stamina, roundi(bout.chance(action) * 100)]
				"cast":
					detail = "%d st. · %d%% · %d left" % [stamina, roundi(bout.chance(action) * 100), fighter.casts]
					button.tooltip_text = "%d casts remaining." % fighter.casts
					if bout.threatens_cast(bout.fighters[1]) and bout.rules.spell_close_penalty > 0:
						button.tooltip_text += " An opponent within weapon reach with enough stamina to attack reduces spell accuracy."
				"sleep":
					detail = "+%d stamina" % Duel.recovery(bout.rules, fighter.stats.Stamina)
				"potion":
					detail = "+%d health" % int(bout.rules.heal)
		button.text = title if detail.is_empty() else title + "\n" + detail

func place_actions(feet: Vector2, fighter_height: float) -> void:
	var heading_y := maxf(167, feet.y - fighter_height - 26)
	_place("attack", Vector2(feet.x - 76, heading_y))
	_place("cast", Vector2(feet.x + 76, heading_y))
	var move_x := feet.x - clampf(fighter_height * .51, 126, 195)
	_place("advance", Vector2(move_x, heading_y + 63))
	_place("jump", Vector2(move_x - 15, heading_y + 124))
	_place("retreat", Vector2(move_x, heading_y + 185))
	var spacing := BUTTON_SIZE.x + 9
	var center := clampf(feet.x, 2.0 * spacing + 15, size.x - 2.0 * spacing - 15)
	_place("guard", Vector2(center - 1.5 * spacing, feet.y + 36))
	_place("sleep", Vector2(center - .5 * spacing, feet.y + 58))
	_place("taunt", Vector2(center + .5 * spacing, feet.y + 58))
	_place("potion", Vector2(center + 1.5 * spacing, feet.y + 36))

func _place(action: String, center: Vector2) -> void:
	var button: Button = action_buttons[action]
	button.size = BUTTON_SIZE
	button.position = Vector2(clampf(center.x - BUTTON_SIZE.x * .5, 15, size.x - BUTTON_SIZE.x - 15), center.y - BUTTON_SIZE.y * .5)

func _card() -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _plate(Color(.08, .105, .10, .93), EDGE, 10))
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

func _plate(fill: Color, edge: Color, padding: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
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
