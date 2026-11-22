extends Control

const Data = preload("res://scripts/data.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Duel = preload("res://scripts/duel.gd")
const Simulator = preload("res://scripts/simulator.gd")
const Stage = preload("res://scripts/stage.gd")
const Foley = preload("res://scripts/foley.gd")
const BattleHud = preload("res://scripts/battle_hud.gd")
const Symbol = preload("res://scripts/ui_symbol.gd")

const SAND := Color("#e1b880")
const TEXT := Color("#f3e8d6")
const MUTED := Color("#abaca0")
const BG := Color("#121718")
const PANEL := Color("#1a2223")
const BORDER := Color("#343f3d")
const GREEN := Color("#96d4ad")
const RED := Color("#e38d79")
const SLOTS := {"helmet": "Helmet", "chest": "Chest plate", "pants": "Pants", "shoes": "Shoes", "shield": "Shield"}
const STAT_ICONS := {"Attack": "attack", "Strength": "strength", "Defence": "armor", "Magic": "cast",
	"Vitality": "health", "Stamina": "stamina", "Charisma": "taunt"}
const USER_BALANCE := "user://balance.override.json"
const USER_SETTINGS := "user://settings.cfg"

enum DisplayMode { WINDOWED, FIGHTS, FULLSCREEN }

var data := Data.new()
var game: RefCounted
var simulations: RefCounted
var shell: VBoxContainer
var content: VBoxContainer
var serif: SystemFont
var current_screen := ""
var notification := ""
var selected_slot := 0
var draft: Dictionary
var draft_skin := 0
var draft_hair := 0
var allocation_grid: VBoxContainer
var points_notice: Label
var stat_labels: Dictionary = {}
var confirm_button: Button
var creation_error: Label
var name_input: LineEdit
var creation_stage: Control
var level_mode := false
var shop_type := "armor"
var armor_slot := "chest"
var selected_item := ""
var shop_stage: Control
var shop_title: Label
var shop_stats: HFlowContainer
var shop_buy: Button
var shop_entries: Dictionary = {}
var bout: RefCounted
var battle_layer: Control
var battle_stage: Control
var battle_hud: Control
var display_mode: int = DisplayMode.FIGHTS
var window_mode_before_fullscreen := Window.MODE_WINDOWED
var settings_popup: PopupPanel
var character_name: Label
var fight_locked := false
var fight_generation := 0
var practicing := false
var bout_result: Dictionary = {}
var balance_editor: TextEdit
var balance_notice: Label
var sim_output: TextEdit
var sound := Foley.new()
var spell_preview_button: Button

func _ready() -> void:
	_make_theme()
	add_child(sound)
	var settings := ConfigFile.new()
	if settings.load(USER_SETTINGS) == OK:
		sound.enabled = bool(settings.get_value("audio", "enabled", true))
		var previous_mode := DisplayMode.FIGHTS if settings.get_value("display", "fullscreen_bouts", true) else DisplayMode.WINDOWED
		display_mode = clampi(int(settings.get_value("display", "mode", previous_mode)), DisplayMode.WINDOWED, DisplayMode.FULLSCREEN)
	elif settings.load("user://audio.cfg") == OK:
		sound.enabled = bool(settings.get_value("audio", "enabled", true))
	if get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
		display_mode = DisplayMode.FULLSCREEN
	var color := ColorRect.new()
	color.color = BG
	color.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(color)
	color.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20 if side in ["left", "right"] else 14)
	shell = _column(margin, 9)
	var profile_path := USER_BALANCE if FileAccess.file_exists(USER_BALANCE) else Data.DEFAULT_FILE
	var err := data.load_profile(profile_path)
	if not err.is_empty():
		var default_error := data.load_profile()
		if not default_error.is_empty():
			_label(shell, default_error, 20, RED)
			return
		notification = "Custom balance couldn't load. %s" % err
	game = Campaign.new(data)
	simulations = Simulator.new(data)
	show_menu()

func _make_theme() -> void:
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Liberation Serif", "DejaVu Serif"])
	theme = Theme.new()
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", TEXT)
	for type in ["Button", "OptionButton", "LineEdit", "TextEdit"]:
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_hover_color", type, TEXT)
		theme.set_color("font_pressed_color", type, SAND)
		theme.set_color("font_disabled_color", type, Color("#7f8582"))
		theme.set_stylebox("normal", type, _style(PANEL, BORDER, 9))
		theme.set_stylebox("hover", type, _style(Color("#273332"), BORDER, 9))
		theme.set_stylebox("pressed", type, _style(Color("#352e25"), SAND, 9))
		theme.set_stylebox("disabled", type, _style(Color("#191f20"), BORDER, 9))
		theme.set_stylebox("focus", type, _style(Color(0, 0, 0, 0), SAND, 9))

func _style(fill: Color, edge: Color, padding: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_content_margin(side, padding)
	return box

func _column(parent: Node, spacing: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", spacing)
	parent.add_child(v)
	return v

func _row(parent: Node, spacing: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", spacing)
	parent.add_child(h)
	return h

func _card(parent: Node, spacing: int = 8) -> VBoxContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _style(PANEL, BORDER, 12))
	parent.add_child(box)
	return _column(box, spacing)

func _fill(node: Control, vertical: bool = false) -> void:
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vertical:
		node.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _label(parent: Node, value: String, font_size: int = 15, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _wrapped(parent: Node, value: String, font_size: int = 15, color: Color = MUTED) -> Label:
	var label := _label(parent, value, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _title(parent: Node, value: String, font_size: int = 31) -> Label:
	var label := _label(parent, value, font_size)
	label.add_theme_font_override("font", serif)
	return label

func _button(parent: Node, caption: String, call: Callable = Callable(), accent: bool = false) -> Button:
	var result := Button.new()
	result.text = caption
	parent.add_child(result)
	if call.is_valid():
		result.pressed.connect(call)
	if accent:
		result.add_theme_stylebox_override("normal", _style(Color("#3a2c20"), Color("#986d45"), 9))
		result.add_theme_color_override("font_color", SAND)
	return result

func _icon_button(parent: Node, symbol: String, caption: String, call: Callable, accent: bool = false) -> Button:
	var button := _button(parent, "", call, accent)
	button.custom_minimum_size = Vector2(45, 42)
	Symbol.on_button(button, symbol, 26, caption)
	return button

func _town_destination(stage: Control, building: Rect2, symbol: String, caption: String, call: Callable) -> void:
	var button := _button(stage, "", call)
	button.accessibility_name = caption
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var highlight := _style(Color(1.0, .77, .4, .14), SAND, 0)
	button.add_theme_stylebox_override("hover", highlight)
	button.add_theme_stylebox_override("pressed", highlight)
	var sign_position := CenterContainer.new()
	button.add_child(sign_position)
	sign_position.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	sign_position.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sign_panel := PanelContainer.new()
	sign_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign_panel.add_theme_stylebox_override("panel", _style(Color("#342620"), Color("#c18c57"), 8))
	sign_position.add_child(sign_panel)
	var contents := _row(sign_panel)
	contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.add_child(Symbol.make(symbol, 25))
	var label := _label(contents, caption, 17)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var place := func() -> void:
		var art: Rect2 = stage.town_art_rect()
		var scale := art.size / Stage.TOWN.get_size()
		button.position = art.position + building.position * scale
		button.size = building.size * scale
	stage.resized.connect(place)
	place.call()

func _token(parent: Node, symbol: String, value: String, caption: String) -> void:
	var pair := _row(parent, 5)
	pair.mouse_filter = Control.MOUSE_FILTER_PASS
	pair.tooltip_text = caption
	pair.add_child(Symbol.make(symbol, 23))
	_label(pair, value, 17, SAND).size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _space(parent: Node) -> void:
	var spacer := Control.new()
	parent.add_child(spacer)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = MOUSE_FILTER_IGNORE

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _page(key: String, heading: String) -> void:
	if is_instance_valid(battle_layer):
		remove_child(battle_layer)
		battle_layer.queue_free()
		battle_layer = null
		shell.show()
	current_screen = key
	_apply_display_mode()
	_clear(shell)
	var nav := _row(shell, 8)
	_title(nav, heading, 32)
	_space(nav)
	if not game.state.is_empty() and key in ["town", "arena", "scout", "shop", "result"]:
		var gold := str(int(game.state.gold))
		_token(nav, "coin", gold + " gold" if key == "shop" else gold, "Gold")
	_icon_button(nav, "settings", "Settings", _show_settings)
	if key not in ["menu", "allocate"]:
		_icon_button(nav, "home", "Title screen", show_menu)
	if not notification.is_empty():
		_wrapped(shell, notification, 14, SAND)
		notification = ""
	if not game.save_error.is_empty():
		_wrapped(shell, game.save_error, 14, RED)
	content = _column(shell, 10)
	_fill(content, true)

func _show_settings() -> void:
	if is_instance_valid(settings_popup):
		return
	settings_popup = PopupPanel.new()
	settings_popup.theme = theme
	settings_popup.transient = true
	settings_popup.exclusive = true
	add_child(settings_popup)
	var menu := _card(settings_popup, 14)
	menu.get_parent().set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_title(menu, "Settings", 30)
	var audio := CheckButton.new()
	audio.text = "Game sounds"
	audio.button_pressed = sound.enabled
	menu.add_child(audio)
	var display_row := _row(menu, 12)
	_label(display_row, "Display").size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var display := OptionButton.new()
	display.accessibility_name = "Display"
	display.add_item("Windowed", DisplayMode.WINDOWED)
	display.add_item("Full-screen fights", DisplayMode.FIGHTS)
	display.add_item("Full screen", DisplayMode.FULLSCREEN)
	display.select(display_mode)
	display_row.add_child(display)
	_fill(display)
	var save_notice := _wrapped(menu, "Settings could not be saved.", 15, RED)
	save_notice.hide()
	audio.toggled.connect(func(enabled: bool) -> void:
		sound.enabled = enabled
		if not enabled:
			sound.stop()
		save_notice.visible = not _save_settings())
	display.item_selected.connect(func(index: int) -> void:
		display_mode = display.get_item_id(index)
		save_notice.visible = not _save_settings()
		_apply_display_mode.call_deferred())
	if current_screen == "menu":
		_button(menu, "Simulator", func() -> void:
			settings_popup.hide()
			show_simulator())
		_button(menu, "Playtest balance", func() -> void:
			settings_popup.hide()
			show_balance())
	var done := _button(menu, "Done", settings_popup.hide, true)
	settings_popup.popup_hide.connect(func() -> void:
		settings_popup.queue_free()
		settings_popup = null)
	settings_popup.popup_centered(Vector2i(360, 0))
	done.grab_focus()

func _apply_display_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	var is_fullscreen := window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
	var wants_fullscreen := display_mode == DisplayMode.FULLSCREEN or (display_mode == DisplayMode.FIGHTS and current_screen == "battle")
	if wants_fullscreen and not is_fullscreen:
		window_mode_before_fullscreen = window.mode
		window.mode = Window.MODE_FULLSCREEN
	elif is_fullscreen and not wants_fullscreen:
		window.mode = window_mode_before_fullscreen

func _save_settings() -> bool:
	var settings := ConfigFile.new()
	settings.load(USER_SETTINGS)
	settings.set_value("audio", "enabled", sound.enabled)
	settings.set_value("display", "mode", display_mode)
	return settings.save(USER_SETTINGS) == OK

func _show_progress(parent: Node) -> void:
	var status := _row(parent, 10)
	var level := int(game.state.level)
	var xp := int(game.state.xp)
	var cap := int(game.arena().cap)
	if game.state.complete:
		_token(status, "trophy", "League champion", "Tournament winner")
	elif game.state.pending:
		_token(status, "xp", "Level %d" % (level + 1), "Level up")
	elif level >= cap:
		_token(status, "trophy", "Tournament ready", "Tournament")
	else:
		var threshold := int(data.rules.xp_levels[level])
		_token(status, "xp", "Level %d" % level, "Experience")
		var bar := ProgressBar.new()
		bar.max_value = threshold
		bar.min_value = int(data.rules.xp_levels[level - 1])
		bar.value = xp
		bar.show_percentage = false
		bar.custom_minimum_size.y = 8
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("background", _style(BG, BORDER, 2))
		bar.add_theme_stylebox_override("fill", _style(SAND, SAND, 2))
		status.add_child(bar)
		_fill(bar)

func _stage(parent: Node, kind: String, height: int = 205) -> Control:
	var stage := Stage.new()
	stage.kind = kind
	stage.data = data
	stage.custom_minimum_size.y = height
	parent.add_child(stage)
	_fill(stage, true)
	if not game.state.is_empty():
		stage.left_loadout = game.state.loadout.duplicate(true)
		stage.skin = int(game.state.skin)
		stage.hair = int(game.state.hair)
	return stage

func show_menu() -> void:
	_page("menu", "The Cinder League")
	_stage(content, "town", 310)
	var slots := _row(content)
	for number in range(1, Campaign.SLOT_COUNT + 1):
		var card := _card(slots)
		_fill(card.get_parent())
		var saved: Dictionary = game.read_slot(number)
		if saved.get("invalid", false):
			_label(card, "Save could not be opened", 17, RED)
		elif saved.is_empty():
			_title(card, "Slot %d" % number, 21)
			_button(card, "Create gladiator", _create_character.bind(number), true)
		else:
			_title(card, "%s · Lv. %d" % [saved.name, saved.level], 19)
			if saved.get("fallen", false):
				_label(card, "Fallen", 16, RED)
				_button(card, "New gladiator", _create_character.bind(number), true)
			else:
				_button(card, "Continue", _resume.bind(number), true)

func _resume(number: int) -> void:
	if not game.resume(number):
		notification = "That save could not be opened."
		show_menu()
		return
	if game.is_fallen():
		show_menu()
	elif game.state.pending:
		_allocate_level()
	elif game.has_active_bout():
		_open_bout(game.state.snapshot, game.state.active_bout.practice)
	else:
		show_town()

func _create_character(number: int) -> void:
	selected_slot = number
	draft = data.stats_empty()
	level_mode = false
	draft_skin = 0
	draft_hair = 0
	_page("create", "Create gladiator")
	_character_form()

func _allocate_level() -> void:
	sound.play("level_up")
	draft = data.stats_empty()
	level_mode = true
	_page("allocate", "Level %d" % (int(game.state.level) + 1))
	_character_form()

func _character_form() -> void:
	var row := _row(content, 11)
	_fill(row, true)
	var preview := _card(row)
	_fill(preview.get_parent(), true)
	creation_stage = _stage(preview, "avatar", 340)
	if not level_mode:
		creation_stage.left_loadout = {"weapon": data.rules.starter_weapon}
	character_name = _title(preview, game.state.name if level_mode else "New gladiator", 23)
	var details := _card(row, 7)
	_fill(details.get_parent(), true)
	details.get_parent().custom_minimum_size.x = 470
	if not level_mode:
		name_input = LineEdit.new()
		name_input.placeholder_text = "Gladiator name"
		name_input.max_length = 32
		details.add_child(name_input)
		name_input.text_changed.connect(func(value: String) -> void:
			character_name.text = value.strip_edges() if not value.strip_edges().is_empty() else "New gladiator"
			_update_point_total())
		var looks := _row(details)
		_label(looks, "Skin")
		var skin_choice := OptionButton.new()
		looks.add_child(skin_choice)
		for name in ["Warm", "Light", "Brown", "Deep"]:
			skin_choice.add_item(name)
		skin_choice.item_selected.connect(func(index: int) -> void:
			draft_skin = index
			creation_stage.skin = index
			creation_stage.queue_redraw())
		_label(looks, "Hair tone")
		var hair_choice := OptionButton.new()
		looks.add_child(hair_choice)
		for name in ["Dark", "Copper", "Ash"]:
			hair_choice.add_item(name)
		hair_choice.item_selected.connect(func(index: int) -> void:
			draft_hair = index
			creation_stage.hair = index
			creation_stage.queue_redraw())
	points_notice = _title(details, "", 23)
	allocation_grid = _column(details, 5)
	confirm_button = _button(details, "Confirm level-up" if level_mode else "Enter town", _confirm_character, true)
	creation_error = _wrapped(details, "", 15, RED)
	creation_error.hide()
	_draw_allocations()

func _point_limit() -> int:
	return game.points_to_allocate() if level_mode else int(data.rules.starting_points)

func _points_left() -> int:
	var remaining := _point_limit()
	for value in draft.values():
		remaining -= int(value)
	return remaining

func _draw_allocations() -> void:
	_clear(allocation_grid)
	stat_labels.clear()
	for stat in Data.STATS:
		var row := _row(allocation_grid, 5)
		row.add_child(Symbol.make(STAT_ICONS[stat], 24))
		var title := _label(row, stat, 17)
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_PASS
		_fill(title)
		stat_labels[stat] = title
		var base_value: int = int(game.state.stats[stat]) if level_mode else 0
		var value_label := _label(row, "%d" % (base_value + int(draft[stat])), 16, SAND)
		value_label.custom_minimum_size.x = 29
		var minus := _button(row, "−", _change_point.bind(stat, -1))
		minus.accessibility_name = "Remove %s point" % stat
		minus.disabled = draft[stat] == 0
		var plus := _button(row, "+", _change_point.bind(stat, 1))
		plus.accessibility_name = "Add %s point" % stat
		plus.disabled = _points_left() == 0
	_update_point_total()

func _update_point_total() -> void:
	points_notice.text = "%d points left" % _points_left()
	var values := draft.duplicate()
	var previous_stats := data.stats_empty()
	var previous_level := 1
	var loadout := {"weapon": data.rules.starter_weapon}
	if level_mode:
		previous_stats = game.state.stats
		previous_level = int(game.state.level)
		loadout = game.state.loadout
		for stat in Data.STATS:
			values[stat] += int(previous_stats[stat])
	var rule: Dictionary = data.rules
	var projected: Dictionary = data.fighter("", values, loadout)
	stat_labels.Attack.tooltip_text = "%d%% hit chance · %d%% crit" % [
		roundi(Duel.hit_chance(rule, values, false) * 100), roundi(Duel.crit_chance(rule, values.Attack) * 100)]
	stat_labels.Strength.tooltip_text = "%d weapon damage" % roundi(Duel.strike_damage(rule, projected, false))
	stat_labels.Defence.tooltip_text = "%d%% block chance" % roundi(Duel.block_chance(rule, values.Defence) * 100)
	stat_labels.Magic.tooltip_text = "+%d spell damage" % roundi(values.Magic * rule.damage_per_magic)
	stat_labels.Vitality.tooltip_text = "Health and recovery"
	stat_labels.Stamina.tooltip_text = "Energy for moves"
	stat_labels.Charisma.tooltip_text = "Stronger taunts and more gold"
	var before := {"level": previous_level, "stats": previous_stats}
	var after := {"level": previous_level + int(level_mode), "stats": values}
	var unlocked: Dictionary = {}
	for item in data.items.values():
		var stat: String = data.stat_requirement(item)
		if stat in stat_labels and not data.lock_reason(before, item).is_empty() and data.lock_reason(after, item).is_empty():
			if not unlocked.has(stat):
				unlocked[stat] = PackedStringArray()
			unlocked[stat].append(item.name)
	for stat in unlocked:
		stat_labels[stat].tooltip_text += "\nUnlocks " + ", ".join(unlocked[stat])
	confirm_button.disabled = _points_left() != 0 or (not level_mode and name_input.text.strip_edges().is_empty())

func _change_point(stat: String, delta: int) -> void:
	if draft[stat] + delta < 0 or (delta > 0 and _points_left() < 1):
		return
	draft[stat] += delta
	_draw_allocations()

func _confirm_character() -> void:
	if _points_left() != 0:
		return
	if level_mode:
		if not game.confirm_points(draft):
			return
		if game.state.pending:
			_allocate_level()
			return
	else:
		var chosen := name_input.text.strip_edges()
		if chosen.is_empty():
			return
		if not game.create(selected_slot, chosen, draft_skin, draft_hair, draft):
			creation_error.text = game.save_error
			creation_error.show()
			return
	show_town()

func show_town() -> void:
	if game.is_fallen():
		show_menu()
		return
	if game.state.pending:
		_allocate_level()
		return
	_page("town", "Town square")
	_show_progress(content)
	var map := _stage(content, "town", 350)
	_town_destination(map, Rect2(44, 375, 345, 414), "attack", "Weaponsmith", _enter_shop.bind("weapon"))
	_town_destination(map, Rect2(397, 383, 309, 301), "helmet", "Armory", _enter_shop.bind("armor"))
	_town_destination(map, Rect2(779, 410, 390, 266), "cast", "Magic shop", _enter_shop.bind("spell"))
	_town_destination(map, Rect2(1231, 291, 282, 356), "trophy", "Arena", show_arena)

func _enter_shop(kind: String) -> void:
	shop_type = kind
	selected_item = ""
	show_shop()

func show_shop() -> void:
	if game.is_fallen():
		show_menu()
		return
	if game.state.pending:
		_allocate_level()
		return
	var title: String = {"armor": "Armory", "weapon": "Weaponsmith", "spell": "Magic shop"}[shop_type]
	_page("shop", title)
	var nav := _row(content)
	_button(nav, "Town square", show_town)
	_space(nav)
	for pair in [["Armory", "armor"], ["Weaponsmith", "weapon"], ["Magic shop", "spell"]]:
		_button(nav, pair[0], _enter_shop.bind(pair[1]), shop_type == pair[1])
	var row := _row(content, 10)
	_fill(row, true)
	var rail := _card(row)
	rail.get_parent().custom_minimum_size.x = 400
	if shop_type == "armor":
		var tabs := _row(rail, 4)
		for part in Data.SLOTS:
			var tab := _icon_button(tabs, part, SLOTS[part], _select_armor.bind(part), armor_slot == part)
			_fill(tab)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rail.add_child(scroll)
	_fill(scroll, true)
	var list := _column(scroll, 7)
	_fill(list)
	shop_entries.clear()
	for item in data.items.values():
		if item.kind != shop_type and not (shop_type == "spell" and item.kind in ["potion", "enchant"]):
			continue
		if shop_type == "armor" and item.slot != armor_slot:
			continue
		var locked: String = data.lock_reason(game.state, item)
		var button := _button(list, item.name, _preview_item.bind(item.id))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 58
		button.icon = _item_icon(item)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 49)
		if not locked.is_empty():
			button.tooltip_text = locked
			var lock_icon := Symbol.make("lock", 23)
			button.add_child(lock_icon)
			lock_icon.set_anchors_preset(PRESET_CENTER_RIGHT)
			lock_icon.offset_left = -33
			lock_icon.offset_right = -10
			lock_icon.offset_top = -11.5
			lock_icon.offset_bottom = 11.5
			for color in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
				button.add_theme_color_override(color, Color("#161616"))
		shop_entries[item.id] = button
	var right := _column(row, 9)
	_fill(right, true)
	var display := _card(right, 5)
	_fill(display.get_parent(), true)
	shop_stage = _stage(display, "avatar", 305)
	var detail := _card(right, 10)
	var checkout := _row(detail)
	shop_title = _title(checkout, "", 23)
	shop_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_space(checkout)
	spell_preview_button = _icon_button(checkout, "play", "Replay spell preview", _replay_spell)
	spell_preview_button.hide()
	shop_buy = _button(checkout, "Buy & equip", _buy_item, true)
	shop_buy.add_theme_color_override("font_disabled_color", MUTED)
	shop_stats = HFlowContainer.new()
	shop_stats.add_theme_constant_override("h_separation", 24)
	shop_stats.add_theme_constant_override("v_separation", 8)
	detail.add_child(shop_stats)
	if shop_entries.is_empty():
		shop_buy.disabled = true
		shop_title.text = "No stock available"
		return
	if selected_item not in shop_entries:
		selected_item = str(shop_entries.keys().front())
	_preview_item(selected_item)

func _select_armor(part: String) -> void:
	armor_slot = part
	selected_item = ""
	show_shop()

func _item_icon(item: Dictionary) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	if item.kind == "weapon" or item.kind == "potion":
		atlas.atlas = Stage.STOCK
		atlas.region = Stage._cell(Stage.STOCK, 3, 2, int(item.art))
	elif item.kind in ["spell", "enchant"]:
		atlas.atlas = Stage.SPELLS
		atlas.region = Stage._cell(Stage.SPELLS, 2, 2, int(item.art))
	else:
		var boxes := {"helmet": Rect2(245, 8, 203, 188), "chest": Rect2(91, 175, 412, 376),
			"pants": Rect2(93, 565, 424, 241), "shoes": Rect2(46, 783, 559, 223), "shield": Rect2(1, 331, 302, 376)}
		if item.tier >= 2 and item.slot in ["chest", "shield"]:
			atlas.atlas = Stage.STOCK
			atlas.region = Stage._cell(Stage.STOCK, 3, 2, 4 if item.slot == "chest" else 2)
		else:
			atlas.atlas = Stage.MAIL if item.tier >= 2 else Stage.TRIM if item.tier > 0 else Stage.GEAR
			atlas.region = boxes[item.slot]
	atlas.filter_clip = true
	return atlas

func _equipped(item: Dictionary) -> bool:
	match item.kind:
		"armor": return game.state.loadout.armor.get(item.slot, "") == item.id
		"potion": return game.state.loadout.potion
	return game.state.loadout.get(item.kind, "") == item.id

func _preview_item(id: String) -> void:
	selected_item = id
	var item: Dictionary = data.items[id]
	var lock: String = data.lock_reason(game.state, item)
	var preview: Dictionary = game.state.loadout.duplicate(true)
	shop_stage.kind = "avatar"
	shop_stage.demo = false
	if item.kind == "spell":
		shop_stage.kind = "spell"
		shop_stage.spell_art = int(item.art)
		shop_stage.elapsed = 0
		shop_stage.demo = true
	elif item.kind == "armor":
		preview.armor[item.slot] = id
	elif item.kind == "enchant":
		preview.enchant = id
		shop_stage.demo = true
	elif item.kind == "weapon":
		preview.weapon = id
	shop_stage.left_loadout = preview
	shop_stage.queue_redraw()
	spell_preview_button.visible = item.kind == "spell"
	for entry in shop_entries:
		var button: Button = shop_entries[entry]
		button.add_theme_stylebox_override("normal", _style(PANEL, SAND if entry == id else BORDER, 9))
	shop_title.text = item.name
	var requirement: String = data.stat_requirement(item)
	var owned: bool = id in game.state.owned
	shop_buy.text = "Equipped" if _equipped(item) else ("Equip" if owned else "Buy")
	shop_buy.disabled = not lock.is_empty() or _equipped(item) or (not owned and game.state.gold < item.price)
	if not lock.is_empty():
		shop_buy.text = lock
		if game.state.level < item.level and not requirement.is_empty() and game.state.stats[requirement] < item.minimum:
			shop_buy.text += " and %d %s" % [item.minimum, requirement]
	elif not owned and game.state.gold < item.price:
		shop_buy.text = "Not enough gold"
	_clear(shop_stats)
	if not owned:
		_shop_stat("coin", "Price", "%d gold" % item.price)
	match item.kind:
		"armor":
			var current: Dictionary = data.items.get(game.state.loadout.armor.get(item.slot, ""), {})
			var points := int(current.get("armor", 0))
			var new_points := int(item.armor)
			_shop_stat("armor", "Armor points", "%d → %d" % [points, new_points])
		"weapon", "spell":
			var current: Dictionary = data.items.get(game.state.loadout.get(item.kind, ""), {})
			var damage := str(int(item.damage))
			if not current.is_empty() and current.damage != item.damage:
				damage = "%d → %d" % [current.damage, item.damage]
			_shop_stat("attack", "Base damage", damage)
			_shop_stat("advance", "Reach", "1 space" if item.reach == 1 else "%d spaces" % item.reach)
			var action := "attack" if item.kind == "weapon" else "cast"
			_shop_stat("stamina", "Stamina cost", "%d per %s" % [item.energy, action])
			if item.kind == "spell":
				_shop_stat("cast", "Uses per fight", str(int(item.uses)))
		"enchant":
			var old := int(data.items.get(game.state.loadout.get("enchant", ""), {}).get("damage", 0))
			_shop_stat("attack", "Extra weapon damage", "+%d → +%d" % [old, item.damage])
		"potion":
			_shop_stat("health", "Health restored", "+%d" % data.rules.heal)
			_shop_stat("potion", "Uses per fight", str(int(data.rules.potion_uses)))

func _shop_stat(symbol: String, caption: String, value: String) -> void:
	var stat := _column(shop_stats, 3)
	_label(stat, caption, 15, MUTED)
	var reading := _row(stat, 5)
	reading.add_child(Symbol.make(symbol, 23))
	_label(reading, value, 18, SAND).size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _replay_spell() -> void:
	shop_stage.elapsed = 0.0
	shop_stage.queue_redraw()
	sound.cast(shop_stage.spell_art)

func _buy_item() -> void:
	if selected_item not in data.items:
		return
	var item: Dictionary = data.items[selected_item]
	var gold_before := int(game.state.gold)
	var err: String = game.purchase(item)
	if err.is_empty():
		var paid := gold_before - int(game.state.gold)
		sound.play("buy" if paid > 0 else "equip")
	else:
		notification = err
	show_shop()

func show_arena() -> void:
	if game.is_fallen():
		show_menu()
		return
	if game.state.pending:
		_allocate_level()
		return
	var arena: Dictionary = game.arena()
	_page("arena", arena.name)
	_show_progress(content)
	var stage := _stage(content, "battle", 310)
	stage.arena = game.arena_index()
	stage.arena_width = int(data.rules.arena_size)
	stage.positions = [1, int(data.rules.arena_size) - 1]
	var regular_offer: Dictionary = game.scouted_bout()
	var tournament_offer: Dictionary = game.scouted_bout(true)
	var visible_offer := tournament_offer if regular_offer.is_empty() else regular_offer
	stage.show_rival = not visible_offer.is_empty()
	if stage.show_rival:
		_show_rival(stage, visible_offer.rival)
	var cards := _row(content)
	var regular := _card(cards)
	_fill(regular.get_parent())
	_title(regular, "Random bout", 23)
	var rewards := _row(regular, 10)
	_token(rewards, "coin", str(game.win_gold(game.arena_index())), "Gold for a win")
	_token(rewards, "xp", str(game.regular_win_xp()), "Experience for a win")
	var regular_scout := _button(regular, "Scout rival", _scout_bout.bind(false), true)
	if not regular_offer.is_empty():
		regular_scout.text = regular_offer.rival.name
	regular_scout.disabled = not game.can_scout(false)
	var tournament := _card(cards)
	_fill(tournament.get_parent())
	_title(tournament, "Tournament", 20)
	var round_total: int = arena.tournament.size()
	var tournament_status: String = "League champion" if game.state.complete else (
		"Round %d/%d" % [mini(int(game.state.tournament) + 1, round_total), round_total] if game.can_tournament() else "Level %d" % arena.cap)
	_token(tournament, "trophy", tournament_status, "Tournament progress")
	var tournament_button := _button(tournament, "Scout tournament rival", _scout_bout.bind(true), true)
	if not tournament_offer.is_empty():
		tournament_button.text = tournament_offer.rival.name
	tournament_button.disabled = not game.can_scout(true)
	var nav := _row(content)
	_button(nav, "Town square", show_town)
	_last_bout_button(nav, true)

func _show_rival(stage: Control, fighter: Dictionary) -> void:
	stage.right_loadout = fighter.loadout
	stage.rival_skin = int(fighter.get("skin", 0))
	stage.rival_hair = int(fighter.get("hair", 0))

func _scout_bout(tournament: bool) -> void:
	var offer: Dictionary = game.scout_bout(tournament, randi())
	if offer.is_empty():
		show_arena()
	else:
		_show_faceoff(offer)

func _show_faceoff(offer: Dictionary) -> void:
	var rival: Dictionary = offer.rival
	var player: Dictionary = data.fighter(game.state.name, game.state.stats, game.state.loadout)
	var heading := "Before the fight"
	if offer.tournament:
		heading = "Tournament · Round %d/%d" % [int(offer.round) + 1, int(offer.round_count)]
	_page("scout", heading)
	var names := _row(content, 22)
	_title(names, "%s · Lv. %d" % [player.name, game.state.level], 24)
	_space(names)
	_title(names, "%s · Lv. %d" % [rival.name, rival.level], 24)
	var stage := _stage(content, "battle", 200)
	stage.arena = game.arena_index()
	stage.arena_width = int(data.rules.arena_size)
	stage.positions = [stage.arena_width * .2, stage.arena_width * .8]
	_show_rival(stage, rival)
	var comparisons := _row(content, 14)
	var stats := _card(comparisons, 5)
	var kit := _card(comparisons, 5)
	_fill(stats.get_parent())
	_fill(kit.get_parent())
	_compare_row(stats, "", "Your stats", "Rival stats", "")
	_compare_row(kit, "", "Your kit", "Rival kit", "")
	for stat in Data.STATS:
		_compare_row(stats, stat, player.stats[stat], rival.stats[stat], STAT_ICONS[stat])
	_compare_row(kit, "Health", player.max_hp, rival.max_hp, "health")
	_compare_row(kit, "Armor", player.max_armor, rival.max_armor, "armor")
	_compare_row(kit, "Energy", player.max_energy, rival.max_energy, "stamina")
	_compare_row(kit, "Weapon", player.weapon.name, rival.weapon.name, "attack")
	_compare_row(kit, "Weapon reach", player.weapon.reach, rival.weapon.reach, "advance")
	_compare_row(kit, "Spell", player.spell.get("name", "None"), rival.spell.get("name", "None"), "cast")
	_compare_row(kit, "Spell reach", player.spell.get("reach", "–"), rival.spell.get("reach", "–"), "advance")
	_compare_row(kit, "Spell casts", player.casts, rival.casts, "cast")
	_compare_row(kit, "Potions", player.potions, rival.potions, "potion")
	var actions := _row(content, 10)
	_button(actions, "Back", show_arena)
	_space(actions)
	var loss_fee := mini(int(game.state.gold), int(data.rules.loss_gold))
	if not offer.tournament and loss_fee > 0:
		_token(actions, "coin", "−%d" % loss_fee, "Gold lost on defeat")
	var fight := _button(actions, "Fight to the death" if offer.tournament else "Fight", _new_bout.bind(offer.tournament), true)
	if offer.tournament:
		fight.add_theme_stylebox_override("normal", _style(Color("#512d2a"), RED, 9))
		fight.add_theme_stylebox_override("hover", _style(Color("#663833"), RED, 9))

func _compare_row(parent: Control, caption: String, left: Variant, right: Variant, symbol: String) -> void:
	var line := _row(parent, 8)
	var player := _label(line, str(int(left)) if left is float else str(left), 15)
	_fill(player)
	player.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var category := _row(line, 4)
	category.custom_minimum_size.x = 132
	category.alignment = BoxContainer.ALIGNMENT_CENTER
	if not symbol.is_empty():
		category.add_child(Symbol.make(symbol, 19))
	_label(category, caption, 15, SAND).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rival := _label(line, str(int(right)) if right is float else str(right), 15)
	_fill(rival)
	rival.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if (left is int or left is float) and (right is int or right is float) and left != right:
		if left > right:
			player.add_theme_color_override("font_color", GREEN)
		else:
			rival.add_theme_color_override("font_color", GREEN)

func _new_bout(tournament: bool) -> void:
	var snapshot: Dictionary = game.start_bout(tournament, randi())
	if not snapshot.is_empty():
		_open_bout(snapshot, false)
	elif not game.scouted_bout(tournament).is_empty():
		_show_faceoff(game.scouted_bout(tournament))

func _retry(practice: bool) -> void:
	if game.state.pending:
		_allocate_level()
	elif game.retry_bout(practice):
		_open_bout(game.state.snapshot, practice)

func _open_bout(snapshot: Dictionary, practice: bool) -> void:
	if game.state.pending:
		_allocate_level()
		return
	bout = game.open_bout(snapshot)
	if bout == null:
		notification = "The saved bout could not be resumed."
		show_menu()
		return
	practicing = practice
	bout_result = {}
	fight_locked = bout.active != 0
	fight_generation += 1
	current_screen = "battle"
	shell.hide()
	battle_layer = Control.new()
	add_child(battle_layer)
	battle_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	battle_stage = _stage(battle_layer, "battle", 0)
	battle_stage.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	battle_stage.full_arena = true
	battle_stage.arena = int(snapshot.arena)
	battle_stage.arena_width = int(bout.rules.arena_size)
	battle_stage.bout_items = snapshot.equipment
	battle_stage.left_loadout = bout.fighters[0].loadout
	_show_rival(battle_stage, bout.fighters[1])
	battle_hud = BattleHud.new()
	battle_layer.add_child(battle_hud)
	battle_hud.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	battle_hud.build(snapshot.arena_name, serif)
	battle_hud.action_selected.connect(_player_action)
	battle_hud.settings_requested.connect(_show_settings)
	battle_hud.resized.connect(_place_battle_actions)
	_apply_display_mode()
	_refresh_battle()
	if bout.active == 1:
		_play_opponent_turn(fight_generation)

func _refresh_battle() -> void:
	battle_stage.positions = bout.positions.duplicate()
	battle_stage.queue_redraw()
	battle_hud.refresh(bout, fight_locked)
	battle_hud.show_save_error(game.save_error)
	_place_battle_actions()

func _place_battle_actions() -> void:
	battle_hud.place_actions(battle_stage.fighter_feet(0), battle_stage.fighter_height())

func _player_action(action: String) -> void:
	if is_instance_valid(settings_popup) or fight_locked or bout.active != 0 or not bout.reason(action).is_empty():
		return
	fight_locked = true
	var generation := fight_generation
	await _animate_turn(bout.act(action), generation)
	if current_screen != "battle" or generation != fight_generation:
		return
	if bout.winner != -2:
		_finish_bout()
		return
	await _play_opponent_turn(generation)

func _play_opponent_turn(generation: int) -> void:
	var choice: String = bout.choose(bout.fighters[1].style)
	await _animate_turn(bout.act(choice), generation)
	if current_screen != "battle" or generation != fight_generation:
		return
	if bout.winner != -2:
		_finish_bout()
		return
	fight_locked = false
	_refresh_battle()

func _animate_turn(event: Dictionary, generation: int) -> void:
	bout_result = game.record_turn(event.action, bout.winner)
	battle_hud.action_layer.hide()
	var fighter: Dictionary = bout.fighters[event.side]
	battle_stage.animate(event)
	sound.begin_turn(event, int(fighter.spell.get("art", 0)))
	await battle_stage.impact_reached
	if current_screen != "battle" or generation != fight_generation:
		return
	sound.impact(event, int(fighter.weapon.get("art", 0)))
	_refresh_battle()
	await battle_stage.turn_animation_finished

func _finish_bout() -> void:
	var outcome := bout_result
	var title := "Victory" if bout.winner == 0 else "Defeat"
	sound.play("victory" if bout.winner == 0 else "defeat")
	if outcome.get("complete", false) and bout.winner == 0:
		title = "League champion"
	elif outcome.get("fallen", false):
		title = "%s has fallen" % game.state.name
	_page("result", "Practice " + title.to_lower() if practicing else title)
	_stage(content, "avatar", 290)
	if outcome.get("fallen", false):
		_button(content, "Title screen", show_menu, true)
		return
	if not practicing:
		var rewards := _row(content, 16)
		_token(rewards, "coin", "%+d" % outcome.gold, "Gold")
		if int(outcome.xp) > 0:
			_token(rewards, "xp", "+%d" % outcome.xp, "Experience")
		if outcome.get("unlocked", false):
			_token(rewards, "trophy", game.arena().name, "New arena")
		if not game.state.complete:
			_show_progress(content)
	var controls := _row(content)
	if game.state.pending:
		_button(controls, "Spend level-up points", _allocate_level, true)
	else:
		_button(controls, "Return to town", show_town, true)
		_last_bout_button(controls, false)
		_button(controls, "Arena", show_arena)

func _last_bout_button(parent: Control, in_arena: bool) -> void:
	if game.state.outcome.is_empty():
		return
	if game.state.outcome.winner == 0:
		_button(parent, "Practice last bout", _retry.bind(true))
	elif not game.state.snapshot.tournament and game.scouted_bout().is_empty():
		_button(parent, "Retry last bout" if in_arena else "Retry bout", _retry.bind(false))

func _number(parent: Node, caption: String, minimum: int, maximum: int, initial: int) -> SpinBox:
	_label(parent, caption, 13, MUTED)
	var box := SpinBox.new()
	box.min_value = minimum
	box.max_value = maximum
	box.value = initial
	box.custom_minimum_size.x = 75
	parent.add_child(box)
	return box

func _styles(parent: Node, label: String, initial: int) -> OptionButton:
	_label(parent, label, 13, MUTED)
	var selector := OptionButton.new()
	for style in Simulator.STYLES:
		selector.add_item(style.replace("_", " ").capitalize())
	selector.select(initial)
	parent.add_child(selector)
	return selector

func show_simulator() -> void:
	_page("simulator", "Simulator")
	var buttons := _row(content, 9)
	var left := _styles(buttons, "Fighter", 0)
	var right := _styles(buttons, "Opponent", 2)
	var level := _number(buttons, "Level", 1, data.max_level(), int(data.rules.arena_caps.front()))
	var seeds := _number(buttons, "Seed", 0, 99999999, 42)
	var runs := _number(buttons, "Bouts", 1, 500, 20)
	var actions := _row(content)
	_button(actions, "Run matchup", _simulate.bind(left, right, level, seeds, runs, false), true)
	_button(actions, "Run campaign", _simulate.bind(left, right, level, seeds, runs, true))
	_button(actions, "Playtest balance", show_balance)
	sim_output = TextEdit.new()
	sim_output.editable = false
	content.add_child(sim_output)
	_fill(sim_output, true)

func _simulate(left: OptionButton, right: OptionButton, level: SpinBox, seeds: SpinBox, runs: SpinBox, campaign: bool) -> void:
	var style := Simulator.STYLES[left.selected]
	var result: Dictionary
	if campaign:
		result = simulations.campaign(style, int(seeds.value), int(runs.value))
	else:
		result = simulations.batch(style, Simulator.STYLES[right.selected], int(level.value), int(seeds.value), int(runs.value))
	var lines: Array[String] = []
	if result.has("error"):
		lines.append(result.error)
	elif campaign:
		var status := "All tournaments won" if result.complete else ("Gladiator fell" if result.fallen else "Run ended at the bout limit")
		lines.append("%s  ·  Level %d  ·  Arena %d" % [status, result.level, result.arena])
		for entry in result.bouts:
			var bout_status := "win" if entry.winner == 0 else "draw" if entry.winner == -1 else "loss"
			lines.append("%02d  %s  ·  %s  ·  Lv. %d  ·  %d turns  ·  %d gold" % [
				entry.bout, entry.opponent, bout_status, entry.level, entry.turns, entry.gold])
	else:
		lines.append("%s %d wins  ·  %s %d wins  ·  %d draws" % [result.left.capitalize(), result.left_wins, result.right.capitalize(), result.right_wins, result.draws])
		lines.append("%.1f turns per bout  ·  %d blocks  ·  %d misses" % [float(result.turns) / result.bouts, result.blocks, result.misses])
	if result.has("trace"):
		lines.append("")
		lines.append("First bout trace · Seed %s" % result.seed)
		for event in result.trace:
			lines.append("%02d  %s  [HP %s | Armor %s | Stamina %s]" % [event.turn, event.message, event.health, event.armor, event.energy])
	sim_output.text = "\n".join(lines)

func show_balance() -> void:
	_page("balance", "Playtest balance")
	balance_editor = TextEdit.new()
	balance_editor.text = FileAccess.get_file_as_string(USER_BALANCE if FileAccess.file_exists(USER_BALANCE) else Data.DEFAULT_FILE)
	content.add_child(balance_editor)
	_fill(balance_editor, true)
	balance_notice = _wrapped(content, "")
	var nav := _row(content)
	_button(nav, "Apply and save profile", _save_balance, true)
	_button(nav, "Load bundled draft into editor", func() -> void:
		balance_editor.text = FileAccess.get_file_as_string(Data.DEFAULT_FILE)
		balance_notice.text = "Draft loaded. Apply to use it.")
	_button(nav, "Simulator", show_simulator)
	if not game.state.is_empty():
		_button(nav, "Town", show_town)

func _save_balance() -> void:
	var temp := USER_BALANCE + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		balance_notice.text = "Couldn't write the playtest profile."
		return
	file.store_string(balance_editor.text)
	file.close()
	var candidate := Data.new()
	var err := candidate.load_profile(temp)
	if not err.is_empty():
		balance_notice.text = err
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
		return
	var code := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(USER_BALANCE))
	if code != OK:
		balance_notice.text = "Couldn't save the profile (%d)." % code
		return
	data = candidate
	game.data = data
	simulations = Simulator.new(data)
	balance_notice.text = "Profile applied."
