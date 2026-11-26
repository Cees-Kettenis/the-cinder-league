extends Control
## Builds the game screens and routes navigation, settings, and fight outcomes.

const Data = preload("res://game/catalog/data.gd")
const Campaign = preload("res://game/campaign/campaign.gd")
const Duel = preload("res://game/combat/duel.gd")
const Simulator = preload("res://game/simulation/simulator.gd")
const Armor = preload("res://game/combat/armor_art.gd")
const Stage = preload("res://game/combat/stage.gd")
const Foley = preload("res://game/audio/foley.gd")
const FightScreen = preload("res://game/combat/fight_screen.tscn")
const Content = preload("res://game/catalog/content_catalog.gd")
const BackdropArt = preload("res://game/screens/backdrop_art.gd")
const Symbol = preload("res://game/screens/ui_symbol.gd")
const TITLE_THEME = preload("res://game/audio/music/title-theme.ogg")
const TOWN_THEME = preload("res://game/audio/music/town-theme.ogg")
const SHOP_THEMES := {
	"spell": preload("res://game/audio/music/magic-shop.ogg"),
	"weapon": preload("res://game/audio/music/weaponsmith.ogg"),
	"armor": preload("res://game/audio/music/armory.ogg"),
}
const ARENA_LOBBY_THEME = preload("res://game/audio/music/arena-theme.ogg")
const PRE_FIGHT_THEME = preload("res://game/audio/music/before-the-fight.ogg")
const VICTORY_THEME = preload("res://game/audio/music/victory-theme.ogg")
const DEFEAT_THEME = preload("res://game/audio/music/defeat-theme.ogg")

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
const DEFAULT_KEYS := {"back": KEY_ESCAPE, "town": KEY_T, "next": KEY_N}
const CONTROL_NAMES := {"back": "Back", "town": "Return to town", "next": "Next bout or match"}

# Keep the stored IDs for existing windowed and fullscreen preferences. ID 1 was fullscreen for fights.
enum DisplayMode { WINDOWED = 0, FULLSCREEN = 2 }

var data := Data.new()
var game: RefCounted
var simulations: RefCounted
var shell: VBoxContainer
var content: VBoxContainer
var title_art: TextureRect
var music_player := AudioStreamPlayer.new()
var fading_music := AudioStreamPlayer.new()
var music_transition: Tween
var music_enabled := true
var town_music_enabled := true
var venue_music_enabled := true
var quitting := false
var serif: SystemFont
var current_screen := ""
var page_notice := ""
var selected_slot := 0
var replace_revision := ""
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
var shop_requirements: HFlowContainer
var shop_stats: HFlowContainer
var shop_buy: Button
var shop_entries: Dictionary = {}
var fight: Control
var display_mode: int = DisplayMode.WINDOWED
var window_mode_before_fullscreen := Window.MODE_WINDOWED
var settings_popup: PopupPanel
var key_bindings := DEFAULT_KEYS.duplicate()
var binding_buttons: Dictionary = {}
var binding_action := ""
var binding_notice: Label
var result_town_button: Button
var result_next_button: Button
var balance_editor: TextEdit
var balance_notice: Label
var sim_output: TextEdit
var sound := Foley.new()
var spell_preview_button: Button
var reserve_row: HBoxContainer
var reserve_label: Label
var reserve_button: Button
var clear_reserve_button: Button

func _ready() -> void:
	_make_theme()
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(_quit_game)
	add_child(sound)
	var settings := ConfigFile.new()
	if settings.load(USER_SETTINGS) == OK:
		sound.enabled = bool(settings.get_value("audio", "enabled", true))
		if int(settings.get_value("display", "mode", DisplayMode.WINDOWED)) == DisplayMode.FULLSCREEN:
			display_mode = DisplayMode.FULLSCREEN
	elif settings.load("user://audio.cfg") == OK:
		sound.enabled = bool(settings.get_value("audio", "enabled", true))
	music_enabled = bool(settings.get_value("audio", "title_music", sound.enabled))
	town_music_enabled = bool(settings.get_value("audio", "town_music", sound.enabled))
	venue_music_enabled = bool(settings.get_value("audio", "venue_music", town_music_enabled))
	_load_key_bindings(settings)
	_apply_back_binding()
	add_child(music_player)
	add_child(fading_music)
	if get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
		display_mode = DisplayMode.FULLSCREEN
	_apply_display_mode()
	var color := ColorRect.new()
	color.color = BG
	color.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(color)
	color.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	title_art = TextureRect.new()
	title_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	title_art.mouse_filter = MOUSE_FILTER_IGNORE
	title_art.hide()
	add_child(title_art)
	title_art.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	get_window().size_changed.connect(_sync_title_art)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20 if side in ["left", "right"] else 14)
	shell = _column(margin, 9)
	var profile_path := USER_BALANCE if FileAccess.file_exists(USER_BALANCE) else Data.DEFAULT_FILE
	# Fall back to bundled balance if a saved custom profile is invalid.
	var err := data.load_profile(profile_path)
	if not err.is_empty():
		var default_error := data.load_profile()
		if not default_error.is_empty():
			_label(shell, default_error, 20, RED)
			return
		page_notice = "Custom balance couldn't load. %s" % err
	game = Campaign.new(data)
	simulations = Simulator.new(data)
	show_menu()

func _input(event: InputEvent) -> void:
	if is_instance_valid(settings_popup):
		return
	if current_screen == "result" and _plain_key_press(event):
		if event.keycode == key_bindings.town and is_instance_valid(result_town_button):
			get_viewport().set_input_as_handled()
			result_town_button.pressed.emit()
			return
		if event.keycode == key_bindings.next and is_instance_valid(result_next_button):
			get_viewport().set_input_as_handled()
			result_next_button.pressed.emit()
			return
	if not event.is_action_pressed("ui_cancel", false, true):
		return
	var focused := get_viewport().gui_get_focus_owner()
	if event is InputEventKey and event.keycode != KEY_ESCAPE and (focused is LineEdit or focused is TextEdit):
		return
	match current_screen:
		"menu", "town": _show_pause()
		"slots", "hall": show_menu()
		"create": _show_title(true)
		"shop", "arena", "scout", "result":
			if not game.tournament_in_progress():
				show_town()
		_: return
	get_viewport().set_input_as_handled()

func _plain_key_press(event: InputEvent) -> bool:
	return (event is InputEventKey and event.pressed and not event.echo and not event.ctrl_pressed
		and not event.meta_pressed and not event.alt_pressed and not event.shift_pressed)

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

func _button(parent: Node, caption: String, on_pressed: Callable = Callable(), accent: bool = false) -> Button:
	var result := Button.new()
	result.text = caption
	parent.add_child(result)
	if on_pressed.is_valid():
		result.pressed.connect(on_pressed)
	if accent:
		result.add_theme_stylebox_override("normal", _style(Color("#3a2c20"), Color("#986d45"), 9))
		result.add_theme_color_override("font_color", SAND)
	return result

func _icon_button(parent: Node, symbol: String, caption: String, on_pressed: Callable, accent: bool = false) -> Button:
	var button := _button(parent, "", on_pressed, accent)
	button.custom_minimum_size = Vector2(45, 42)
	Symbol.on_button(button, symbol, 26, caption)
	return button

func _town_destination(stage: Control, building: Rect2, symbol: String, caption: String, on_pressed: Callable) -> void:
	var button := _button(stage, "", on_pressed)
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
	# Map the source-art hitbox onto the painted building as the window resizes.
	var place := func() -> void:
		var art: Rect2 = stage.town_art_rect()
		var art_scale := art.size / Stage.TOWN_DESIGN_SIZE
		button.position = art.position + building.position * art_scale
		button.size = building.size * art_scale
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

func _remove_battle() -> void:
	if is_instance_valid(fight):
		remove_child(fight)
		fight.queue_free()
		fight = null
	result_town_button = null
	result_next_button = null

func _sync_title_art() -> void:
	if not title_art.visible:
		title_art.texture = null
		return
	var path := BackdropArt.texture_path(BackdropArt.TITLE, get_window().size)
	if title_art.texture == null or title_art.texture.resource_path != path:
		title_art.texture = load(path)

# Normal screens rebuild the shared shell. Battle has a separate scene and results stay in that scene.
func _page(key: String, heading: String) -> void:
	_remove_battle()
	shell.show()
	current_screen = key
	title_art.visible = key in ["menu", "slots"]
	_sync_title_art()
	_sync_audio.call_deferred()
	_clear(shell)
	var nav := _row(shell, 8)
	if not heading.is_empty():
		_title(nav, heading, 32)
	_space(nav)
	if not game.state.is_empty() and key in ["town", "arena", "scout", "shop"]:
		var gold := str(int(game.state.gold))
		_token(nav, "coin", gold + " gold" if key == "shop" else gold, "Gold")
	if key in ["menu", "town"]:
		_icon_button(nav, "settings", "Pause menu", _show_pause)
	else:
		_icon_button(nav, "settings", "Settings", _show_settings)
	if key not in ["menu", "allocate"] and not game.tournament_in_progress():
		_icon_button(nav, "home", "Title screen", show_menu)
	if not page_notice.is_empty():
		_wrapped(shell, page_notice, 14, SAND)
		page_notice = ""
	if not game.save_error.is_empty():
		_wrapped(shell, game.save_error, 14, RED)
	content = _column(shell, 10)
	_fill(content, true)

func _show_pause() -> void:
	_show_popup("Paused")

func _show_settings() -> void:
	_show_popup("Settings")

func _show_popup(section: String, back: String = "") -> void:
	binding_action = ""
	binding_buttons.clear()
	if is_instance_valid(settings_popup):
		_clear(settings_popup)
	else:
		settings_popup = PopupPanel.new()
		settings_popup.theme = theme
		settings_popup.transient = true
		settings_popup.exclusive = true
		add_child(settings_popup)
		settings_popup.window_input.connect(_popup_input)
		settings_popup.popup_hide.connect(func() -> void:
			settings_popup.queue_free()
			settings_popup = null
			binding_action = ""
			binding_buttons.clear()
			if is_instance_valid(fight):
				fight.set_input_blocked(false))
	if is_instance_valid(fight):
		fight.set_input_blocked(true)
	var menu := _card(settings_popup, 12)
	var panel: Control = menu.get_parent()
	panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_title(menu, section, 30)
	var primary: Button
	match section:
		"Paused":
			primary = _button(menu, "Resume", settings_popup.hide, true)
			_button(menu, "Settings", _show_popup.bind("Settings", section))
			_button(menu, "Audio", _show_popup.bind("Audio", section))
			_button(menu, "Quit", _quit_game)
		"Settings":
			_display_settings(menu)
			_button(menu, "Controls", _show_popup.bind("Controls", section))
			if back.is_empty():
				_button(menu, "Audio", _show_popup.bind("Audio", section))
			if current_screen in ["menu", "slots"]:
				_button(menu, "Simulator", func() -> void:
					settings_popup.hide()
					show_simulator())
				_button(menu, "Playtest balance", func() -> void:
					settings_popup.hide()
					show_balance())
		"Audio":
			_audio_settings(menu)
		"Controls":
			_control_settings(menu)
	if primary == null:
		primary = _button(menu, "Done" if back.is_empty() else "Back", settings_popup.hide if back.is_empty() else _show_popup.bind(back), true)
	settings_popup.popup_centered(Vector2i(360, ceili(panel.get_combined_minimum_size().y)))
	primary.grab_focus()

func _popup_input(event: InputEvent) -> void:
	if not binding_action.is_empty() and event is InputEventKey and event.pressed:
		settings_popup.set_input_as_handled()
		if _plain_key_press(event) and event.keycode not in [KEY_NONE, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			var other = key_bindings.find_key(event.keycode)
			if other != null:
				key_bindings[other] = key_bindings[binding_action]
			key_bindings[binding_action] = event.keycode
			binding_action = ""
			_apply_back_binding()
			_refresh_control_settings()
			binding_notice.visible = not _save_settings()
		return
	if event.is_action_pressed("ui_cancel", false, true):
		settings_popup.set_input_as_handled()
		settings_popup.hide()

func _control_settings(menu: VBoxContainer) -> void:
	for action in CONTROL_NAMES:
		var row := _row(menu, 12)
		_label(row, CONTROL_NAMES[action]).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_space(row)
		var button := _button(row, "", func() -> void:
			binding_action = "" if binding_action == action else action
			_refresh_control_settings())
		button.custom_minimum_size.x = 132
		button.accessibility_name = "Rebind " + CONTROL_NAMES[action]
		binding_buttons[action] = button
	_button(menu, "Reset defaults", func() -> void:
		key_bindings = DEFAULT_KEYS.duplicate()
		binding_action = ""
		_apply_back_binding()
		_refresh_control_settings()
		binding_notice.visible = not _save_settings())
	binding_notice = _settings_notice(menu)
	_refresh_control_settings()

func _refresh_control_settings() -> void:
	for action in binding_buttons:
		binding_buttons[action].text = "Press a key…" if binding_action == action else OS.get_keycode_string(key_bindings[action])
	if is_instance_valid(result_town_button):
		result_town_button.tooltip_text = "Shortcut · " + OS.get_keycode_string(key_bindings.town)
	if is_instance_valid(result_next_button):
		result_next_button.tooltip_text = "Shortcut · " + OS.get_keycode_string(key_bindings.next)

func _load_key_bindings(settings: ConfigFile) -> void:
	var choices := {}
	for action in DEFAULT_KEYS:
		var code = settings.get_value("controls", action, DEFAULT_KEYS[action])
		if not code is int or code == KEY_NONE or OS.get_keycode_string(code).is_empty() or code in choices.values():
			return
		choices[action] = code
	key_bindings = choices

func _apply_back_binding() -> void:
	for input in InputMap.action_get_events("ui_cancel"):
		if input is InputEventKey:
			InputMap.action_erase_event("ui_cancel", input)
	var key := InputEventKey.new()
	key.keycode = key_bindings.back
	InputMap.action_add_event("ui_cancel", key)

func _settings_notice(menu: VBoxContainer) -> Label:
	var notice := _wrapped(menu, "Settings could not be saved.", 15, RED)
	notice.hide()
	return notice

func _display_settings(menu: VBoxContainer) -> void:
	var display_row := _row(menu, 12)
	_label(display_row, "Display").size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var display := OptionButton.new()
	display.accessibility_name = "Display"
	display.add_item("Windowed", DisplayMode.WINDOWED)
	display.add_item("Fullscreen", DisplayMode.FULLSCREEN)
	display.select(display.get_item_index(display_mode))
	display_row.add_child(display)
	_fill(display)
	var save_notice := _settings_notice(menu)
	display.item_selected.connect(func(index: int) -> void:
		display_mode = display.get_item_id(index)
		save_notice.visible = not _save_settings()
		_apply_display_mode.call_deferred())

func _audio_settings(menu: VBoxContainer) -> void:
	var effects := CheckButton.new()
	effects.text = "Game sounds"
	effects.button_pressed = sound.enabled
	menu.add_child(effects)
	var music := CheckButton.new()
	music.text = "Title music"
	music.button_pressed = music_enabled
	menu.add_child(music)
	var town := CheckButton.new()
	town.text = "Town music"
	town.button_pressed = town_music_enabled
	menu.add_child(town)
	var venues := CheckButton.new()
	venues.text = "Shop and arena music"
	venues.button_pressed = venue_music_enabled
	menu.add_child(venues)
	var save_notice := _settings_notice(menu)
	effects.toggled.connect(func(enabled: bool) -> void:
		sound.enabled = enabled
		if not enabled:
			sound.stop()
		_sync_audio()
		save_notice.visible = not _save_settings())
	music.toggled.connect(func(enabled: bool) -> void:
		music_enabled = enabled
		_sync_audio()
		save_notice.visible = not _save_settings())
	town.toggled.connect(func(enabled: bool) -> void:
		town_music_enabled = enabled
		_sync_audio()
		save_notice.visible = not _save_settings())
	venues.toggled.connect(func(enabled: bool) -> void:
		venue_music_enabled = enabled
		_sync_audio()
		save_notice.visible = not _save_settings())

func _music_for_screen() -> AudioStream:
	if town_music_enabled and current_screen in ["town", "allocate"]:
		return TOWN_THEME
	if music_enabled and current_screen in ["menu", "slots", "hall", "create"]:
		return TITLE_THEME
	if not venue_music_enabled:
		return null
	match current_screen:
		"shop": return SHOP_THEMES.get(shop_type)
		"arena": return ARENA_LOBBY_THEME
		"scout", "tournament": return PRE_FIGHT_THEME
		"battle": return fight.music()
		"result": return VICTORY_THEME if fight.bout.winner == 0 else DEFEAT_THEME
	return null

func _sync_audio() -> void:
	if quitting or is_queued_for_deletion() or DisplayServer.get_name() == "headless":
		return
	sound.set_crowd(current_screen == "battle")
	var wanted := _music_for_screen()
	if music_player.stream == wanted:
		return
	if music_transition != null:
		music_transition.kill()
	var incoming := fading_music
	var outgoing := music_player
	# During an interrupted fade, keep the louder track as the outgoing one when replacing a stream.
	if incoming.stream != wanted and incoming.playing and incoming.volume_linear > outgoing.volume_linear:
		incoming = music_player
		outgoing = fading_music
	if incoming.stream != wanted:
		incoming.stop()
		incoming.stream = wanted
		incoming.volume_linear = 0.0
	if wanted != null and not incoming.playing:
		incoming.play()
	music_player = incoming
	fading_music = outgoing
	var fade_time := .18 if current_screen == "result" else (.28 if current_screen == "battle" else .55)
	music_transition = create_tween().set_parallel()
	music_transition.tween_property(incoming, "volume_linear", db_to_linear(-5.0) if wanted != null else 0.0, fade_time)
	music_transition.tween_property(outgoing, "volume_linear", 0.0, fade_time)
	music_transition.finished.connect(func() -> void:
		outgoing.stop()
		outgoing.stream = null)

func _quit_game() -> void:
	if quitting:
		return
	quitting = true
	if music_transition != null:
		music_transition.kill()
	music_player.stop()
	fading_music.stop()
	sound.stop()
	# The mixer releases the looping stream after playback stops.
	await get_tree().create_timer(.30).timeout
	get_tree().quit()

func _apply_display_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	var is_fullscreen := window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
	var wants_fullscreen := display_mode == DisplayMode.FULLSCREEN
	if wants_fullscreen and not is_fullscreen:
		window_mode_before_fullscreen = window.mode
		window.mode = Window.MODE_FULLSCREEN
	elif is_fullscreen and not wants_fullscreen:
		window.mode = window_mode_before_fullscreen

func _save_settings() -> bool:
	var settings := ConfigFile.new()
	settings.load(USER_SETTINGS)
	settings.set_value("audio", "enabled", sound.enabled)
	settings.set_value("audio", "title_music", music_enabled)
	settings.set_value("audio", "town_music", town_music_enabled)
	settings.set_value("audio", "venue_music", venue_music_enabled)
	if settings.has_section_key("display", "fullscreen_bouts"):
		settings.erase_section_key("display", "fullscreen_bouts")
	settings.set_value("display", "mode", display_mode)
	for action in key_bindings:
		settings.set_value("controls", action, key_bindings[action])
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
	_show_title(false)

func _show_title(selecting_slot: bool) -> void:
	_page("slots" if selecting_slot else "menu", "")
	var hero := Control.new()
	content.add_child(hero)
	_fill(hero, true)
	var lockup := _column(hero, 20)
	lockup.anchor_left = .06
	lockup.anchor_top = .29
	var nameplate := _title(lockup, "The Cinder\nLeague", 86)
	nameplate.add_theme_color_override("font_color", Color("#ffe2ad"))
	nameplate.add_theme_color_override("font_shadow_color", Color("#150f14"))
	nameplate.add_theme_constant_override("shadow_offset_y", 4)
	nameplate.add_theme_constant_override("line_spacing", -12)
	if not selecting_slot:
		var play := _button(lockup, "Play", _show_title.bind(true), true)
		play.custom_minimum_size = Vector2(186, 56)
		play.size_flags_horizontal = SIZE_SHRINK_BEGIN
		play.add_theme_font_size_override("font_size", 23)
		play.grab_focus()
		var hall := _button(lockup, "Hall of Fame", show_hall_of_fame)
		hall.custom_minimum_size = Vector2(186, 43)
		hall.size_flags_horizontal = SIZE_SHRINK_BEGIN
		return
	var slots := _row(content)
	for number in range(1, Campaign.SLOT_COUNT + 1):
		var card := _card(slots)
		_fill(card.get_parent())
		var saved: Dictionary = game.read_slot(number)
		if saved.get("invalid", false):
			_title(card, "Slot %d" % number, 21)
			_label(card, "Save could not be opened", 17, RED)
			_button(card, "Replace save", _confirm_replace.bind(number))
		elif saved.is_empty():
			_title(card, "Slot %d" % number, 21)
			_button(card, "Create gladiator", _create_character.bind(number), true)
		else:
			_title(card, "%s · Lv. %d" % [saved.name, saved.level], 19)
			if saved.get("fallen", false):
				_label(card, "Fallen", 16, RED)
			else:
				_button(card, "Continue", _resume.bind(number), true)
			_button(card, "Replace save", _confirm_replace.bind(number))

func show_hall_of_fame() -> void:
	_page("hall", "Hall of Fame")
	var records: Array = game.hall_of_fame()
	if records.is_empty():
		_label(_card(content), "No gladiators yet.", 18)
		return
	_hall_row(_card(content, 0), "Gladiator", "Level", "Tournaments won", "Status", SAND)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_fill(scroll, true)
	var list := _column(scroll, 5)
	_fill(list)
	for index in records.size():
		var record: Dictionary = records[index]
		_hall_row(_card(list, 0), "%d. %s" % [index + 1, record.name], str(record.level), str(record.crowns),
			record.status, SAND if record.status == "Champion" else TEXT)

func _hall_row(parent: Control, gladiator: String, level: String, tournaments: String, status: String, color: Color) -> void:
	var row := _row(parent, 10)
	var label := _label(row, gladiator, 17, color)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_fill(label)
	_label(row, level, 17, color).custom_minimum_size.x = 84
	_label(row, tournaments, 17, color).custom_minimum_size.x = 162
	_label(row, status, 17, color).custom_minimum_size.x = 100

func _confirm_replace(number: int) -> void:
	var revision: String = game.slot_revision(number)
	if revision.is_empty():
		_show_title(true)
		return
	var saved: Dictionary = game.read_slot(number)
	var dialog := ConfirmationDialog.new()
	dialog.theme = theme
	dialog.title = "Replace save?"
	if saved.get("invalid", false):
		dialog.dialog_text = "Start a new gladiator in Slot %d? A copy of the previous save will be archived." % number
	else:
		dialog.dialog_text = "Start a new gladiator in Slot %d? %s's record will stay in the Hall of Fame." % [number, saved.name]
	dialog.get_ok_button().text = "Replace save"
	dialog.transient = true
	dialog.exclusive = true
	add_child(dialog)
	dialog.confirmed.connect(_create_character.bind(number, revision))
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			dialog.queue_free())
	dialog.popup_centered()

func _resume(number: int) -> void:
	if not game.resume(number):
		page_notice = "That save could not be opened."
		show_menu()
		return
	if game.is_fallen():
		show_menu()
	elif game.state.pending:
		_allocate_level()
	# An active bout takes precedence over tournament navigation when loading a save.
	elif game.has_active_bout():
		_open_bout(game.state.snapshot)
	elif game.tournament_in_progress():
		_scout_bout(true)
	else:
		show_town()

func _create_character(number: int, revision: String = "") -> void:
	selected_slot = number
	replace_revision = revision
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
	else:
		_title(preview, game.state.name, 23)
	var details := _card(row, 7)
	_fill(details.get_parent(), true)
	details.get_parent().custom_minimum_size.x = 470
	if not level_mode:
		name_input = LineEdit.new()
		name_input.placeholder_text = "Gladiator name"
		name_input.max_length = 32
		details.add_child(name_input)
		name_input.text_changed.connect(func(_value: String) -> void: _update_point_total())
		var looks := _row(details)
		_label(looks, "Skin")
		var skin_choice := OptionButton.new()
		looks.add_child(skin_choice)
		for tone in ["Warm", "Light", "Brown", "Deep"]:
			skin_choice.add_item(tone)
		skin_choice.item_selected.connect(func(index: int) -> void:
			draft_skin = index
			creation_stage.skin = index
			creation_stage.queue_redraw())
		_label(looks, "Hair tone")
		var hair_choice := OptionButton.new()
		looks.add_child(hair_choice)
		for tone in ["Dark", "Copper", "Ash"]:
			hair_choice.add_item(tone)
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
	if rule.damage_per_excess_strength < rule.damage_per_strength:
		stat_labels.Strength.tooltip_text += ". Strength adds less damage above %s points." % String.num(
			Duel.strength_damage_threshold(rule, values), 2)
	stat_labels.Defence.tooltip_text = "%d%% block chance" % roundi(Duel.block_chance(rule, values.Defence) * 100)
	stat_labels.Magic.tooltip_text = "+%.1f spell damage · %.1f spell resistance\n+%d casts · One more every %d Magic\nReserve spell at %d Magic" % [
		values.Magic * rule.damage_per_magic, Duel.spell_resistance(rule, values.Magic),
		data.bonus_spell_casts(int(values.Magic)), int(rule.magic_per_extra_cast), int(rule.reserve_spell_magic)]
	stat_labels.Vitality.tooltip_text = "Health and recovery"
	var stamina := int(values.Stamina)
	var move_bonus := Duel.stamina_move_bonus(rule, stamina)
	var leap_bonus := Duel.stamina_move_bonus(rule, stamina, true)
	stat_labels.Stamina.tooltip_text = "%d max stamina · Sleep restores %d\nStep %d · Retreat %d · Leap %d spaces\nLunge up to %d spaces" % [
		projected.max_energy, Duel.recovery(rule, stamina), int(data.distances.advance) + move_bonus,
		int(data.distances.retreat) + move_bonus, int(data.distances.jump) + leap_bonus, Duel.lunge_range(rule, stamina)]
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
		if not game.create(selected_slot, chosen, draft_skin, draft_hair, draft, replace_revision):
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
	if game.tournament_in_progress():
		show_arena()
		return
	_page("town", "Town square")
	_show_progress(content)
	var map := _stage(content, "town", 350)
	_town_destination(map, Rect2(44, 375, 345, 414), "attack", "Weaponsmith", _enter_shop.bind("weapon"))
	_town_destination(map, Rect2(397, 383, 309, 301), "helmet", "Armory", _enter_shop.bind("armor"))
	_town_destination(map, Rect2(779, 410, 390, 266), "cast", "Magic shop", _enter_shop.bind("spell"))
	_town_destination(map, Rect2(1231, 291, 282, 356), "trophy", "Arena", show_arena)

func _enter_shop(kind: String) -> void:
	var entering := current_screen != "shop" or shop_type != kind
	shop_type = kind
	selected_item = ""
	show_shop()
	if entering and current_screen == "shop":
		sound.play("shop_bell")

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
	var equipped_id := ""
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
		if shop_type != "spell" and _equipped(item):
			equipped_id = item.id
			button.accessibility_description = "Equipped"
			var badge := _label(button, "Equipped", 14, GREEN)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.set_anchors_preset(PRESET_CENTER_RIGHT)
			var badge_size := badge.get_combined_minimum_size()
			badge.offset_left = -12 - badge_size.x
			badge.offset_right = -12
			badge.offset_top = -badge_size.y * .5
			badge.offset_bottom = badge_size.y * .5
		elif not locked.is_empty():
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
	shop_requirements = HFlowContainer.new()
	shop_requirements.add_theme_constant_override("h_separation", 14)
	detail.add_child(shop_requirements)
	shop_requirements.hide()
	shop_stats = HFlowContainer.new()
	shop_stats.add_theme_constant_override("h_separation", 24)
	shop_stats.add_theme_constant_override("v_separation", 8)
	detail.add_child(shop_stats)
	reserve_row = _row(detail)
	reserve_label = _label(reserve_row, "", 15, SAND)
	_space(reserve_row)
	reserve_button = _button(reserve_row, "Equip as reserve", _buy_item.bind(true))
	clear_reserve_button = _button(reserve_row, "Clear reserve", _clear_reserve_spell)
	reserve_row.hide()
	if shop_entries.is_empty():
		shop_buy.disabled = true
		shop_title.text = "No stock available"
		return
	if selected_item not in shop_entries:
		selected_item = equipped_id if not equipped_id.is_empty() else str(shop_entries.keys().front())
	_preview_item(selected_item)
	if not equipped_id.is_empty():
		scroll.ensure_control_visible.call_deferred(shop_entries[selected_item])

func _select_armor(part: String) -> void:
	armor_slot = part
	selected_item = ""
	show_shop()

func _item_icon(item: Dictionary) -> AtlasTexture:
	if item.kind == "weapon":
		return Stage.weapon_icon(item)
	var atlas := AtlasTexture.new()
	if item.kind == "potion":
		atlas.atlas = Stage.STOCK
		atlas.region = Stage._cell(Stage.STOCK, 3, 2, int(item.art))
	elif item.kind in ["spell", "enchant"]:
		match int(item.art):
			4:
				atlas.atlas = Stage.GLASSGUARD
				atlas.region = Stage._cell(Stage.GLASSGUARD, 3, 2, 5)
			5:
				atlas.atlas = Stage.POCKET_ANVIL
				atlas.region = Rect2(Vector2.ZERO, atlas.atlas.get_size())
			7, 8:
				atlas.atlas = Stage.BASTION_SPELLS[int(item.art)]
				atlas.region = Rect2(Vector2.ZERO, atlas.atlas.get_size())
			_:
				atlas.atlas = Stage.SPELLS
				atlas.region = Stage._cell(Stage.SPELLS, 2, 2, mini(3, int(item.art)))
	else:
		var sprite := Armor.equipped(item)
		atlas.atlas = sprite.texture
		atlas.region = Rect2(Vector2.ZERO, atlas.atlas.get_size())
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
	# Try on the highlighted item in the preview without mutating the current loadout.
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
		shop_buy.text = "Locked"
	elif not owned and game.state.gold < item.price:
		shop_buy.text = "Not enough gold"
	_clear(shop_requirements)
	var requires_stat: bool = not requirement.is_empty() and item.minimum > 0
	shop_requirements.visible = item.level > 1 or requires_stat
	if shop_requirements.visible:
		_label(shop_requirements, "Requirements", 15, MUTED)
		if item.level > 1:
			_shop_requirement("Level", int(game.state.level), int(item.level))
		if requires_stat:
			_shop_requirement(requirement, int(game.state.stats[requirement]), int(item.minimum))
	var reserve_id := str(game.state.loadout.get("reserve_spell", ""))
	reserve_row.visible = item.kind == "spell" and data.has_reserve_slot(int(game.state.stats.Magic))
	if reserve_row.visible:
		reserve_label.text = "Reserve · " + data.item_name(reserve_id)
		reserve_button.text = "Equip as reserve" if owned else "Buy for reserve"
		reserve_button.disabled = (not lock.is_empty() or _equipped(item) or reserve_id == item.id
			or game.state.loadout.spell.is_empty() or (not owned and game.state.gold < item.price))
		clear_reserve_button.visible = not reserve_id.is_empty()
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
			var damage := String.num(item.damage, 2).trim_suffix(".0")
			if not current.is_empty() and current.damage != item.damage:
				damage = String.num(current.damage, 2).trim_suffix(".0") + " → " + damage
			_shop_stat("attack", "Base damage", damage)
			_shop_stat("advance", "Reach", "1 space" if item.reach == 1 else "%d spaces" % item.reach)
			var action := "attack" if item.kind == "weapon" else "cast"
			_shop_stat("stamina", "Stamina cost", "%d per %s" % [item.energy, action])
			if item.kind == "spell":
				var magic := int(game.state.stats.Magic)
				var casts: int = data.spell_casts(item, magic, not reserve_id.is_empty())
				_shop_stat("cast", "Main casts", str(casts))
		"enchant":
			var old := int(data.items.get(game.state.loadout.get("enchant", ""), {}).get("damage", 0))
			_shop_stat("attack", "Extra weapon damage", "+%d → +%d" % [old, item.damage])
		"potion":
			_shop_stat("health", "Health restored", "+%d" % data.rules.heal)
			_shop_stat("potion", "Uses per death match", str(int(data.rules.potion_uses)))

func _shop_requirement(caption: String, current: int, required: int) -> void:
	var entry := _row(shop_requirements, 5)
	var met := current >= required
	entry.add_child(Symbol.make("check" if met else "lock", 18))
	var label := _label(entry, "%s %d / %d" % [caption, current, required], 16, GREEN if met else SAND)
	label.accessibility_name = "%s. You have %d. Requires %d. %s" % [caption, current, required, "Met" if met else "Locked"]

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

func _buy_item(reserve: bool = false) -> void:
	if selected_item not in data.items:
		return
	var item: Dictionary = data.items[selected_item]
	var gold_before := int(game.state.gold)
	var err: String = game.purchase(item, reserve)
	if err.is_empty():
		var paid := gold_before - int(game.state.gold)
		sound.play("buy" if paid > 0 else "equip")
	else:
		page_notice = err
	show_shop()

func _clear_reserve_spell() -> void:
	game.clear_reserve_spell()
	show_shop()

func show_arena() -> void:
	if game.is_fallen():
		show_menu()
		return
	if game.state.pending:
		_allocate_level()
		return
	if game.tournament_in_progress():
		if not game.has_active_bout():
			_scout_bout(true)
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
		stage.set_rival(visible_offer.rival, int(game.state.get("level", 1)))
	var cards := _row(content)
	var regular := _card(cards)
	_fill(regular.get_parent())
	_title(regular, "Regular bout", 23)
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

func _scout_bout(tournament: bool) -> void:
	if game.has_active_bout():
		return
	var offer: Dictionary = game.scout_bout(tournament, randi())
	if not offer.is_empty():
		_show_faceoff(offer)
	elif game.tournament_in_progress():
		_page("tournament", "Tournament")
		_button(content, "Next Match", _scout_bout.bind(true), true)
	else:
		show_arena()

func _show_faceoff(offer: Dictionary) -> void:
	var rival: Dictionary = offer.rival
	var player: Dictionary = data.fighter(game.state.name, game.state.stats, game.state.loadout)
	var heading := "Bout · Yield below %d%% HP" % int(data.rules.bout_yield_health_percent)
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
	stage.set_rival(rival, int(game.state.get("level", 1)))
	var comparisons := _row(content, 14)
	var stats := _card(comparisons, 5)
	var kit := _card(comparisons, 5)
	_fill(stats.get_parent())
	_fill(kit.get_parent())
	_compare_row(stats, "", "Your stats", "Rival stats", "")
	_compare_row(kit, "", "Your kit", "Rival kit", "")
	for stat in Data.STATS:
		_compare_row(stats, stat, player.stats[stat], rival.stats[stat], STAT_ICONS[stat])
	var player_stamina := int(player.stats.Stamina)
	var rival_stamina := int(rival.stats.Stamina)
	var step := int(data.distances.advance)
	var leap := int(data.distances.jump)
	_compare_row(stats, "Step travel", step + Duel.stamina_move_bonus(data.rules, player_stamina),
		step + Duel.stamina_move_bonus(data.rules, rival_stamina), "advance")
	_compare_row(stats, "Leap travel", leap + Duel.stamina_move_bonus(data.rules, player_stamina, true),
		leap + Duel.stamina_move_bonus(data.rules, rival_stamina, true), "jump")
	_compare_row(stats, "Lunge travel", Duel.lunge_range(data.rules, player_stamina), Duel.lunge_range(data.rules, rival_stamina), "lunge")
	_compare_row(kit, "Health", player.max_hp, rival.max_hp, "health")
	_compare_row(kit, "Armor", player.max_armor, rival.max_armor, "armor")
	_compare_row(kit, "Energy", player.max_energy, rival.max_energy, "stamina")
	_compare_row(kit, "Weapon", player.weapon.name, rival.weapon.name, "attack")
	_compare_row(kit, "Weapon reach", player.weapon.reach, rival.weapon.reach, "advance")
	_compare_row(kit, "Spell", player.spell.get("name", "None"), rival.spell.get("name", "None"), "cast")
	_compare_row(kit, "Spell reach", player.spell.get("reach", "–"), rival.spell.get("reach", "–"), "advance")
	_compare_row(kit, "Spell casts", player.casts, rival.casts, "cast")
	var player_reserve: Dictionary = player.get("reserve_spell", {})
	var rival_reserve: Dictionary = rival.get("reserve_spell", {})
	if not player_reserve.is_empty() or not rival_reserve.is_empty():
		_compare_row(kit, "Reserve · 1 cast", player_reserve.get("name", "–"), rival_reserve.get("name", "–"), "cast")
	if offer.tournament:
		_compare_row(kit, "Potions", player.potions, rival.potions, "potion")
	var actions := _row(content, 10)
	if not game.tournament_in_progress():
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
		_open_bout(snapshot)
	elif not game.scouted_bout(tournament).is_empty():
		_show_faceoff(game.scouted_bout(tournament))

func _open_bout(snapshot: Dictionary) -> void:
	if game.state.pending:
		_allocate_level()
		return
	var bout: Duel = game.open_bout(snapshot)
	if bout == null:
		page_notice = "The saved bout could not be resumed."
		show_menu()
		return
	_remove_battle()
	current_screen = "battle"
	title_art.hide()
	_sync_title_art()
	shell.hide()
	fight = FightScreen.instantiate()
	fight.configure(game, bout, snapshot, sound)
	fight.settings_requested.connect(_show_settings)
	# The fight controller saves the final turn and signals the resolved outcome after animation.
	fight.finished.connect(_finish_bout)
	add_child(fight)
	_sync_audio.call_deferred()
	fight.start(serif, is_instance_valid(settings_popup))

func _finish_bout(outcome: Dictionary) -> void:
	if current_screen != "battle":
		return
	var bout: Duel = fight.bout
	var title := "Victory" if bout.winner == 0 else "Defeat"
	if not venue_music_enabled:
		sound.play("victory" if bout.winner == 0 else "defeat")
	if outcome.get("complete", false) and bout.winner == 0:
		title = "League champion"
	elif outcome.get("fallen", false):
		title = "%s has fallen" % game.state.name
	elif not bout.history.is_empty() and bout.history.back().get("ring_out", false):
		title = "Ring-out victory" if bout.winner == 0 else "Ring-out defeat"
	elif not bout.history.is_empty() and bout.history.back().get("first_blood", false):
		title = "First blood victory" if bout.winner == 0 else "Defeat · Yielded"
	elif not bout.history.is_empty() and bout.history.back().get("yield_threshold_reached", false):
		title = "Victory · Rival yielded" if bout.winner == 0 else "Defeat · Yielded"
	current_screen = "result"
	_sync_audio()
	fight.celebrate()
	var result := _card(fight, 10)
	var panel: PanelContainer = result.get_parent()
	panel.name = "BoutResults"
	panel.add_theme_stylebox_override("panel", _style(Color("#2d2329f8"), Color("#bd895c"), 15))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -484
	panel.offset_right = 484
	var summary := _row(result, 22)
	var heading := _title(summary, title, 30)
	heading.add_theme_color_override("font_color", SAND if bout.winner == 0 else TEXT)
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var motion := panel.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not outcome.get("fallen", false):
		_show_bout_rewards(summary, outcome, motion)
	if not game.save_error.is_empty():
		_wrapped(result, game.save_error, 15, RED)
	var controls := _row(result, 8)
	var unlocked: bool = outcome.get("unlocked", false)
	if unlocked:
		_token(controls, "trophy", game.arena().name + " unlocked", "New arena")
	_space(controls)
	if outcome.get("fallen", false):
		_button(controls, "Title screen", show_menu, true)
	elif game.state.pending:
		_button(controls, "Spend level-up points", _allocate_level, true)
	else:
		var tournament_locked: bool = game.tournament_in_progress()
		if not tournament_locked:
			result_town_button = _button(controls, "Return to town", show_town)
		result_next_button = _button(controls, "Next Match" if tournament_locked else "Next Bout",
			_scout_bout.bind(tournament_locked), true)
		_refresh_control_settings()
	var height := panel.get_combined_minimum_size().y
	panel.offset_top = 8
	panel.offset_bottom = height + 8
	motion.tween_property(panel, "offset_top", -height - 20, .32)
	motion.tween_property(panel, "offset_bottom", -20.0, .32)

func _show_bout_rewards(parent: HBoxContainer, outcome: Dictionary, motion: Tween) -> void:
	var levels: Array = data.rules.xp_levels
	var level := int(game.state.level)
	var capped: bool = level >= int(game.arena().cap)
	var floor_index := maxi(0, level - (2 if capped else 1))
	var ceiling_index := mini(level - (1 if capped else 0), levels.size() - 1)
	var xp := int(game.state.xp)
	var gained_xp := int(outcome.xp)
	var progress := _column(parent, 5)
	_fill(progress)
	var stat := _row(progress, 6)
	_token(stat, "xp", "+%d XP" % gained_xp if gained_xp > 0 else "XP", "Experience")
	_space(stat)
	if capped and not game.state.complete:
		_label(stat, "Tournament ready", 14, MUTED)
	var bar := ProgressBar.new()
	bar.max_value = maxi(int(levels[ceiling_index]), int(levels[floor_index]) + 1)
	bar.min_value = int(levels[floor_index])
	# Campaign has already granted the reward. Start the bar at the previous XP for the animation.
	bar.value = xp - gained_xp
	bar.show_percentage = false
	bar.accessibility_name = "Experience"
	bar.custom_minimum_size.y = 12
	bar.add_theme_stylebox_override("background", _style(Color("#18151b"), Color("#604a48"), 2))
	bar.add_theme_stylebox_override("fill", _style(SAND, SAND.lightened(.15), 2))
	progress.add_child(bar)
	if gained_xp > 0:
		motion.tween_property(bar, "value", minf(xp, bar.max_value), .86).set_delay(.22)
	var wallet := _column(parent, 1)
	wallet.custom_minimum_size.x = 90
	var gold := int(game.state.gold)
	var gained_gold := int(outcome.gold)
	var gold_row := _row(wallet, 6)
	gold_row.add_child(Symbol.make("coin", 23))
	var gold_total := _label(gold_row, str(gold - gained_gold), 19, SAND)
	gold_total.accessibility_name = "Total gold"
	_label(wallet, "%+d gold" % gained_gold if gained_gold != 0 else "Gold", 14, RED if gained_gold < 0 else MUTED)
	if gained_gold != 0:
		motion.tween_method(func(value: float) -> void: gold_total.text = str(roundi(value)),
			float(gold - gained_gold), float(gold), .72).set_delay(.33)

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
	_button(actions, "Run regular bout", _simulate.bind(left, right, level, seeds, runs, false), true)
	_button(actions, "Run death match", _simulate.bind(left, right, level, seeds, runs, false, true))
	_button(actions, "Run campaign", _simulate.bind(left, right, level, seeds, runs, true))
	_button(actions, "Playtest balance", show_balance)
	sim_output = TextEdit.new()
	sim_output.editable = false
	content.add_child(sim_output)
	_fill(sim_output, true)

func _simulate(left: OptionButton, right: OptionButton, level: SpinBox, seeds: SpinBox, runs: SpinBox, campaign: bool, death_match: bool = false) -> void:
	var style := Simulator.STYLES[left.selected]
	var result: Dictionary
	if campaign:
		result = simulations.campaign(style, int(seeds.value), int(runs.value))
	else:
		result = simulations.batch(style, Simulator.STYLES[right.selected], int(level.value), int(seeds.value), int(runs.value),
			{"death_match": death_match})
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
	balance_editor.text = FileAccess.get_file_as_string(USER_BALANCE) if FileAccess.file_exists(USER_BALANCE) else _bundled_balance_draft()
	content.add_child(balance_editor)
	_fill(balance_editor, true)
	balance_notice = _wrapped(content, "")
	var nav := _row(content)
	_button(nav, "Apply and save profile", _save_balance, true)
	_button(nav, "Load bundled draft into editor", func() -> void:
		balance_editor.text = _bundled_balance_draft()
		balance_notice.text = "Draft loaded. Apply to use it.")
	_button(nav, "Simulator", show_simulator)
	if not game.state.is_empty():
		_button(nav, "Town", show_town)

func _bundled_balance_draft() -> String:
	return JSON.stringify(Content.bundled_profile(), "  ", false) + "\n"

func _save_balance() -> void:
	var temp := USER_BALANCE + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		balance_notice.text = "Couldn't write the playtest profile."
		return
	file.store_string(balance_editor.text)
	file.close()
	# Validate the temporary draft before replacing the active profile or the saved override.
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
