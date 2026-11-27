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
const ShopView = preload("res://game/screens/shops/shop_view.gd")
const CharacterView = preload("res://game/screens/character/character_view.gd")
const ArenaView = preload("res://game/screens/arena/arena_view.gd")
const ResultCoinStack = preload("res://game/screens/arena/result_coin_stack.gd")
const Symbol = preload("res://game/screens/ui_symbol.gd")
const TITLE_LOGO = preload("res://game/screens/title/league-logo.webp")
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
const PAGE_INSET_X := 20
const PAGE_INSET_Y := 14
const PAGE_GAP := 9
const SHOP_NAV_HEIGHT := 60
const BOUT_REWARDS_DELAY := .42
const VICTORY_GREEN := Color("#8ff0ae")
const STAT_ICONS := {"Attack": "attack", "Strength": "strength", "Defence": "armor", "Magic": "cast",
	"Vitality": "health", "Stamina": "stamina", "Charisma": "taunt"}
const USER_BALANCE := "user://balance.override.json"
const USER_SETTINGS := "user://settings.cfg"
const DEFAULT_KEYS := {
	"back": KEY_ESCAPE, "town": KEY_T, "next": KEY_N, "character": KEY_C, "settings": KEY_K,
	"armory": KEY_A, "weaponsmith": KEY_W, "magic_shop": KEY_M, "arena": KEY_B,
	"scout_regular": KEY_R, "scout_tournament": KEY_U, "fight_confirm": KEY_F,
	"shop_up": KEY_UP, "shop_down": KEY_DOWN, "shop_buy": KEY_P,
	"shop_tab_1": KEY_1, "shop_tab_2": KEY_2, "shop_tab_3": KEY_3, "shop_tab_4": KEY_4, "shop_tab_5": KEY_5,
	"magic_clear": KEY_DELETE,
}
const NAVIGATION_CONTROLS := {
	"back": "Back / Pause", "town": "Return to town", "next": "Next bout or match", "character": "Character", "settings": "Settings",
	"armory": "Armory", "weaponsmith": "Weaponsmith", "magic_shop": "Magic shop", "arena": "Arena",
}
const ARENA_CONTROLS := {"scout_regular": "Regular bout", "scout_tournament": "Tournament", "fight_confirm": "Confirm fight"}
const SHOP_CONTROLS := {
	"shop_up": "Previous item", "shop_down": "Next item", "shop_buy": "Buy or equip",
	"magic_clear": "Clear prepared spell",
}
const SHOP_TAB_CONTROLS := {
	"shop_tab_1": "Tab 1 · Helmet / Damage", "shop_tab_2": "Tab 2 · Chest / Utility",
	"shop_tab_3": "Tab 3 · Legs / Potions", "shop_tab_4": "Tab 4 · Boots", "shop_tab_5": "Tab 5 · Shield",
}
const LEGACY_SHOP_TAB_BINDINGS := {
	"shop_tab_1": ["armor_helmet", "magic_damage"], "shop_tab_2": ["armor_chest", "magic_utility"],
	"shop_tab_3": ["armor_pants", "magic_potions"], "shop_tab_4": ["armor_shoes"], "shop_tab_5": ["armor_shield"],
}
const ARMOR_FILTERS := {"helmet": "shop_tab_1", "chest": "shop_tab_2", "pants": "shop_tab_3", "shoes": "shop_tab_4", "shield": "shop_tab_5"}
const ARMOR_TAB_NAMES := {"helmet": "Helmet", "chest": "Chest", "pants": "Legs", "shoes": "Boots", "shield": "Shield"}
const MAGIC_FILTERS := {"Damage": "shop_tab_1", "Utility": "shop_tab_2", "Potions": "shop_tab_3"}
const SHOP_FILTERS := {"armor": ARMOR_FILTERS, "spell": MAGIC_FILTERS}
const SHOP_KIT_TITLES := {"armor": "Equipped armor", "weapon": "Equipped weapon", "spell": "Prepared loadout"}

# Keep the stored IDs for existing windowed and fullscreen preferences. ID 1 was fullscreen for fights.
enum DisplayMode { WINDOWED = 0, FULLSCREEN = 2 }
enum SpellCheckout { CLOSED, PICK_SLOT, CLEAR }

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
var allocation_controls: Dictionary = {}
var allocation_metrics: Dictionary = {}
var confirm_button: Button
var creation_error: Label
var name_input: LineEdit
var creation_stage: Control
var level_mode := false
var shop_type := "armor"
var shop_view: ShopView
var shop_backdrop: Control
var magic_category := "Damage"
var shop_spell_slot := 0
var spell_slot_chosen := false
var character_return := "town"
var faceoff_tournament := false
var arena_actions: Dictionary = {}
var shortcut_labels: Array[Dictionary] = []
var armor_slot := "chest"
var selected_item := ""
var shop_stage: Control
var shop_title: Label
var shop_requirements: HFlowContainer
var shop_stats: Container
var shop_buy: Button
var shop_entries: Dictionary = {}
var fight: Control
var display_mode: int = DisplayMode.WINDOWED
var window_mode_before_fullscreen := Window.MODE_WINDOWED
var settings_popup: PopupPanel
var settings_shade: ColorRect
var _paused_for_settings := false
var _was_paused_before_settings := false
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
var spell_slot_notice: Label
var clear_spell_button: Button
var spell_checkout := SpellCheckout.CLOSED
var spell_checkout_slot := -1
var spell_checkout_prompt: Label

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
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	fading_music.process_mode = Node.PROCESS_MODE_ALWAYS
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
	var fade := Gradient.new()
	fade.set_color(0, Color("#0e0b11", .55))
	fade.set_color(1, Color("#0e0b11", 0.0))
	fade.set_offset(1, .65)
	fade.add_point(.34, Color("#0e0b11", .36))
	var shade := GradientTexture2D.new()
	shade.gradient = fade
	shade.width = 256
	shade.height = 2
	var title_shade := TextureRect.new()
	title_shade.texture = shade
	title_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_shade.mouse_filter = MOUSE_FILTER_IGNORE
	title_art.add_child(title_shade)
	title_shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	get_window().size_changed.connect(_sync_title_art)
	shop_backdrop = Control.new()
	shop_backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	shop_backdrop.hide()
	add_child(shop_backdrop)
	shop_backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	shell = _column(margin, PAGE_GAP)
	settings_shade = ColorRect.new()
	settings_shade.color = Color(0, 0, 0, .55)
	settings_shade.z_index = 10
	settings_shade.hide()
	add_child(settings_shade)
	settings_shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
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

func _exit_tree() -> void:
	_restore_pause_state()

func _input(event: InputEvent) -> void:
	if is_instance_valid(settings_popup):
		return
	if spell_checkout != SpellCheckout.CLOSED:
		if _spell_checkout_input(event):
			get_viewport().set_input_as_handled()
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
		if _plain_key_press(event) and _navigation_shortcut(event.keycode):
			get_viewport().set_input_as_handled()
		return
	var focused := get_viewport().gui_get_focus_owner()
	if event is InputEventKey and event.keycode != KEY_ESCAPE and (focused is LineEdit or focused is TextEdit):
		return
	match current_screen:
		"menu", "town": _show_pause()
		"slots", "hall": show_menu()
		"create": _show_title(true)
		"character": _close_character()
		"scout":
			if not game.tournament_in_progress():
				show_arena()
		"shop", "arena", "result":
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

func _town_destination(stage: Control, palette: ShopView, building: Rect2, symbol: String,
		caption: String, on_pressed: Callable, action: String) -> void:
	var button := _button(stage, "", on_pressed)
	button.accessibility_name = caption
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var highlight := palette.frame(Color(palette.edge, .15), Color(palette.edge.lightened(.25), .8), 0)
	button.add_theme_stylebox_override("hover", highlight)
	button.add_theme_stylebox_override("pressed", highlight)
	var sign_position := CenterContainer.new()
	button.add_child(sign_position)
	sign_position.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	sign_position.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sign_panel := PanelContainer.new()
	sign_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign_panel.add_theme_stylebox_override("panel", palette.frame(
		Color(palette.base.darkened(.20), .95), palette.edge, 7))
	sign_position.add_child(sign_panel)
	var contents := _row(sign_panel)
	contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.add_child(Symbol.make(symbol, 22))
	palette.label(contents, caption, 16).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var keycap := palette.keycap(contents, _key_name(action))
	_track_shortcut(button, caption, action, keycap)
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
func _page(key: String, heading: String, palette: ShopView = null) -> void:
	_remove_battle()
	shell.show()
	current_screen = key
	var full_bleed := key in ["town", "arena", "scout", "tournament"]
	var margin: MarginContainer = shell.get_parent()
	if palette == null:
		_page_insets(margin)
	else:
		_page_insets(margin, 0, 0, 0)
	shell.add_theme_constant_override("separation", 0 if full_bleed else PAGE_GAP)
	spell_checkout = SpellCheckout.CLOSED
	title_art.visible = key in ["menu", "slots"]
	_sync_title_art()
	_sync_audio.call_deferred()
	_clear(shell)
	_reset_shortcuts_and_backdrop()
	var body := shell
	if palette == null:
		_page_header(key, heading)
	else:
		palette.backdrop(shop_backdrop)
		shop_backdrop.show()
		# Keep the status bar aligned even when the content has its own margins.
		_status_bar(shell, palette)
		if not full_bleed:
			var body_margin := MarginContainer.new()
			shell.add_child(body_margin)
			_page_insets(body_margin, PAGE_INSET_X, 0)
			_fill(body_margin, true)
			body = _column(body_margin, PAGE_GAP)
	if not page_notice.is_empty():
		_wrapped(body, page_notice, 14, SAND)
		page_notice = ""
	if not game.save_error.is_empty():
		_wrapped(body, game.save_error, 14, RED)
	content = _column(body, 0 if full_bleed else 10)
	_fill(content, true)

func _page_insets(margin: MarginContainer, horizontal: int = PAGE_INSET_X, top: int = PAGE_INSET_Y,
		bottom: int = PAGE_INSET_Y) -> void:
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_right", horizontal)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", bottom)

func _reset_shortcuts_and_backdrop() -> void:
	shortcut_labels.clear()
	arena_actions.clear()
	shop_backdrop.hide()
	_clear(shop_backdrop)

func _page_header(key: String, heading: String) -> void:
	var nav := _row(shell, 8)
	if not heading.is_empty():
		_title(nav, heading, 32)
	_space(nav)
	if key in ["menu", "town"]:
		_icon_button(nav, "settings", "Pause menu", _show_pause)
	else:
		_icon_button(nav, "settings", "Settings", _show_settings)
	if key not in ["menu", "allocate"] and not game.tournament_in_progress():
		_icon_button(nav, "home", "Title screen", show_menu)

func _show_pause() -> void:
	_show_popup("Paused")

func _show_settings() -> void:
	if spell_checkout != SpellCheckout.CLOSED:
		_cancel_spell_checkout()
	_show_popup("Settings")

func _show_popup(section: String, back: String = "") -> void:
	binding_action = ""
	binding_buttons.clear()
	if is_instance_valid(settings_popup):
		_clear(settings_popup)
	else:
		settings_popup = PopupPanel.new()
		settings_popup.transient = true
		settings_popup.exclusive = true
		settings_popup.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(settings_popup)
		settings_popup.window_input.connect(_popup_input)
		settings_popup.popup_hide.connect(_close_settings_popup)
		# Freeze the game under both menu pages while keeping the modal controls responsive.
		_was_paused_before_settings = get_tree().paused
		_paused_for_settings = true
		get_tree().paused = true
		settings_shade.show()
	if is_instance_valid(fight):
		fight.set_input_blocked(true)
	var palette := ShopView.new("amber-ring") if game.state.is_empty() or current_screen == "create" else _arena_palette()
	settings_popup.theme = _arena_controls_theme(palette)
	var menu := palette.card(settings_popup, 12)
	var panel: Control = menu.get_parent()
	panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_title(menu, section, 30)
	var popup_size := Vector2i(360, 0)
	var primary: Button
	match section:
		"Paused":
			primary = _button(menu, "Resume", settings_popup.hide)
			_button(menu, "Settings", _show_popup.bind("Settings", section))
			_button(menu, "Quit", _quit_game)
		"Settings":
			var scroll := _settings_contents(menu, palette)
			var footer := _row(menu, 12)
			_button(footer, "Reset defaults", _reset_control_bindings)
			_space(footer)
			primary = _settings_close_button(footer, back)
			var available := get_viewport_rect().size - Vector2(32, 32)
			# Fit the control groups before scrolling, with room for the footer to stay visible.
			var columns: Control = scroll.get_child(0)
			var height := panel.get_combined_minimum_size().y + columns.get_combined_minimum_size().y
			height -= scroll.get_combined_minimum_size().y
			popup_size = Vector2i(minf(1024.0, available.x), ceilf(minf(height + 12.0, available.y)))
	if primary == null:
		primary = _settings_close_button(menu, back)
	palette.style_button(primary, true)
	popup_size.y = maxi(popup_size.y, ceili(panel.get_combined_minimum_size().y))
	settings_popup.popup_centered(popup_size)
	primary.grab_focus()

func _close_settings_popup() -> void:
	settings_popup.queue_free()
	settings_popup = null
	binding_action = ""
	binding_buttons.clear()
	settings_shade.hide()
	_restore_pause_state()
	if is_instance_valid(fight):
		fight.set_input_blocked(false)

func _restore_pause_state() -> void:
	if _paused_for_settings:
		_paused_for_settings = false
		get_tree().paused = _was_paused_before_settings

func _settings_close_button(parent: Control, back: String) -> Button:
	return _button(parent, "Done" if back.is_empty() else "Back",
		settings_popup.hide if back.is_empty() else _show_popup.bind(back))

func _arena_controls_theme(palette: ShopView) -> Theme:
	var themed := theme.duplicate() as Theme
	themed.set_stylebox("panel", "PopupPanel", StyleBoxEmpty.new())
	themed.set_stylebox("panel", "PopupMenu", palette.frame(palette.base.darkened(.32), palette.edge, 6))
	themed.set_stylebox("hover", "PopupMenu", palette.frame(palette.base.lightened(.12), palette.edge, 6))
	for type in ["Button", "OptionButton", "CheckButton"]:
		themed.set_stylebox("normal", type, palette.frame(palette.base, palette.edge.darkened(.22), 8))
		themed.set_stylebox("hover", type, palette.frame(palette.base.lightened(.12), palette.edge, 8))
		themed.set_stylebox("pressed", type, palette.frame(palette.base.lightened(.18), ShopView.GOLD, 8))
		themed.set_stylebox("hover_pressed", type, palette.frame(palette.base.lightened(.20), ShopView.GOLD, 8))
		themed.set_stylebox("focus", type, palette.frame(Color.TRANSPARENT, ShopView.GOLD, 0))
	return themed

func _popup_input(event: InputEvent) -> void:
	if not binding_action.is_empty() and event is InputEventKey and event.pressed:
		settings_popup.set_input_as_handled()
		if _plain_key_press(event) and event.keycode not in [KEY_NONE, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			var code: int = event.keycode
			var conflicts := _key_conflicts(binding_action, code, key_bindings)
			var updated := key_bindings.duplicate()
			updated[binding_action] = code
			if conflicts.size() == 1:
				# Preserve the existing swap behavior when the old key fits the other action.
				var other := conflicts[0]
				var old_code: int = key_bindings[binding_action]
				if _key_conflicts(other, old_code, updated).is_empty():
					updated[other] = old_code
			if not _key_conflicts(binding_action, code, updated).is_empty():
				var action := conflicts[0]
				var caption := _binding_caption(action)
				binding_notice.text = "Already assigned to %s. Choose another key." % caption
				binding_notice.show()
				return
			key_bindings = updated
			binding_action = ""
			_apply_back_binding()
			_refresh_control_settings()
			binding_notice.text = "Settings could not be saved."
			binding_notice.visible = not _save_settings()
		return
	if event.is_action_pressed("ui_cancel", false, true):
		settings_popup.set_input_as_handled()
		settings_popup.hide()

func _settings_contents(menu: VBoxContainer, palette: ShopView) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	menu.add_child(scroll)
	_fill(scroll, true)
	var columns := _row(scroll, 10)
	_fill(columns)
	var general := palette.card(columns, 9)
	_fill(general.get_parent())
	general.get_parent().size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_title(general, "Display", 23)
	_display_settings(general)
	_title(general, "Audio", 23)
	_audio_settings(general)
	_binding_group(general, "Arena shortcuts", ARENA_CONTROLS)
	if current_screen in ["menu", "slots"]:
		_title(general, "Playtesting", 23)
		_button(general, "Simulator", func() -> void:
			settings_popup.hide()
			show_simulator())
		_button(general, "Playtest balance", func() -> void:
			settings_popup.hide()
			show_balance())
	var navigation := palette.card(columns, 7)
	_fill(navigation.get_parent())
	_binding_group(navigation, "Navigation", NAVIGATION_CONTROLS)
	var shops := palette.card(columns, 7)
	_fill(shops.get_parent())
	_binding_group(shops, "Shops", SHOP_CONTROLS)
	_binding_group(shops, "Shop tabs", SHOP_TAB_CONTROLS)
	binding_notice = _settings_notice(menu)
	_refresh_control_settings()
	return scroll

func _binding_group(list: VBoxContainer, heading: String, actions: Dictionary) -> void:
	_title(list, heading, 23)
	for action in actions:
		var row := _row(list, 9)
		_label(row, actions[action], 15).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_space(row)
		var button := _button(row, "", func() -> void:
			binding_action = "" if binding_action == action else action
			binding_notice.hide()
			_refresh_control_settings())
		button.custom_minimum_size = Vector2(94, 36)
		button.accessibility_name = "Rebind " + actions[action]
		binding_buttons[action] = button

func _binding_caption(action: String) -> String:
	for group in [NAVIGATION_CONTROLS, ARENA_CONTROLS, SHOP_CONTROLS, SHOP_TAB_CONTROLS]:
		if action in group:
			return group[action]
	return action

func _reset_control_bindings() -> void:
	key_bindings = DEFAULT_KEYS.duplicate()
	binding_action = ""
	_apply_back_binding()
	_refresh_control_settings()
	binding_notice.text = "Settings could not be saved."
	binding_notice.visible = not _save_settings()

func _refresh_control_settings() -> void:
	for action in binding_buttons:
		binding_buttons[action].text = "Press a key…" if binding_action == action else OS.get_keycode_string(key_bindings[action])

	for entry in shortcut_labels:
		_update_shortcut_label(entry)
	if current_screen == "shop" and shop_view != null and selected_item in shop_entries:
		_set_shop_buy_caption(data.items[selected_item])

# The last two tabs are Armory-only. The first three are shared by both shops.
func _control_scope(action: String) -> String:
	if action in ["shop_tab_4", "shop_tab_5"]:
		return "armor"
	if action == "magic_clear":
		return "magic"
	return "global"

func _key_conflicts(action: String, code: int, bindings: Dictionary) -> Array[String]:
	var conflicts: Array[String] = []
	for other in bindings:
		if other == action or bindings[other] != code:
			continue
		# Next bout is only active on results. Town and Back also work there.
		if action == "next" or other == "next":
			if action not in ["town", "back"] and other not in ["town", "back"]:
				continue
		var scope := _control_scope(action)
		var other_scope := _control_scope(other)
		if scope == "global" or other_scope == "global" or scope == other_scope:
			conflicts.append(other)
	return conflicts

func _load_key_bindings(settings: ConfigFile) -> void:
	var choices := {}
	# Keep existing player choices when introducing new shortcut defaults.
	for action in DEFAULT_KEYS:
		var candidates := [settings.get_value("controls", action, KEY_NONE)]
		# Prefer a customized legacy binding to a default. Armory wins when both tabs had different custom keys.
		for legacy in LEGACY_SHOP_TAB_BINDINGS.get(action, []):
			var previous = settings.get_value("controls", legacy, KEY_NONE)
			if previous != DEFAULT_KEYS[action]:
				candidates.append(previous)
		for code in candidates:
			if code is int and code != KEY_NONE and not OS.get_keycode_string(code).is_empty() and _key_conflicts(action, code, choices).is_empty():
				choices[action] = code
				break
	for action in DEFAULT_KEYS:
		if action in choices:
			continue
		var code: int = DEFAULT_KEYS[action]
		while not _key_conflicts(action, code, choices).is_empty():
			code = KEY_F1 if code < KEY_F1 or code > KEY_F35 else code + 1
		choices[action] = code
	key_bindings = choices

func _key_name(action: String) -> String:
	match int(key_bindings[action]):
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
		KEY_PAGEUP: return "PgUp"
		KEY_PAGEDOWN: return "PgDn"
		KEY_ENTER, KEY_KP_ENTER: return "↵"
		KEY_DELETE: return "Del"
		KEY_ESCAPE: return "Esc"
		KEY_BACKSPACE: return "⌫"
	return OS.get_keycode_string(key_bindings[action])

func _shortcut_caption(caption: String, action: String) -> String:
	return "%s  (%s)" % [caption, _key_name(action)]

func _track_shortcut(target: Control, caption: String, action: String, keycap: Label = null) -> void:
	shortcut_labels.append({"target": target, "caption": caption, "action": action, "keycap": keycap})
	_update_shortcut_label(shortcut_labels.back())

func _update_shortcut_label(entry: Dictionary) -> void:
	var target: Control = entry.target
	if is_instance_valid(entry.keycap):
		entry.keycap.text = _key_name(entry.action)
	target.tooltip_text = _shortcut_caption(entry.caption, entry.action)

func _navigation_shortcut(code: int) -> bool:
	if current_screen == "allocate" and code == key_bindings.settings:
		_show_settings()
		return true
	if current_screen not in ["town", "shop", "character", "arena", "scout", "tournament"]:
		return false
	if code == key_bindings.character:
		if current_screen == "character":
			_close_character()
		else:
			show_character()
		return true
	if code == key_bindings.settings and current_screen != "town":
		_show_settings()
		return true
	if code == key_bindings.settings:
		_show_popup("Settings", "Paused")
		return true
	if code == key_bindings.town and current_screen != "town":
		if not game.tournament_in_progress():
			show_town()
		return true
	if code == key_bindings.arena and current_screen == "town":
		show_arena()
		return true
	if current_screen in ["arena", "scout", "tournament"]:
		for action in arena_actions:
			if code == key_bindings[action]:
				var button: Button = arena_actions[action]
				if not button.disabled:
					button.pressed.emit()
				return true
		return false
	if game.tournament_in_progress():
		return false
	for entry in [["armory", "armor"], ["weaponsmith", "weapon"], ["magic_shop", "spell"]]:
		if code == key_bindings[entry[0]]:
			if current_screen != "shop" or shop_type != entry[1]:
				_enter_shop(entry[1])
			return true
	return current_screen == "shop" and shop_view != null and _equipment_shortcut(code)

func _equipment_shortcut(code: int) -> bool:
	var filters: Dictionary = SHOP_FILTERS.get(shop_type, {})
	for filter in filters:
		if code == key_bindings[filters[filter]]:
			if shop_type == "armor":
				_select_armor(filter)
			else:
				_select_magic(filter)
			return true
	if code == key_bindings.shop_buy:
		# Return and Space keep their usual behavior when a button has keyboard focus.
		if code in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and get_viewport().gui_get_focus_owner() is BaseButton:
			return false
		if shop_buy.visible and not shop_buy.disabled:
			_buy_item()
		return true
	if code == key_bindings.shop_up or code == key_bindings.shop_down:
		var stock := shop_entries.keys()
		var index := stock.find(selected_item)
		if index >= 0:
			var target = stock[clampi(index + (-1 if code == key_bindings.shop_up else 1), 0, stock.size() - 1)]
			if target != selected_item:
				_select_stock_item(target)
		return true
	if shop_type == "spell" and code == key_bindings.magic_clear and clear_spell_button.visible:
		_clear_spell()
		return true
	return false

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
	var display := OptionButton.new()
	display.accessibility_name = "Display"
	display.add_item("Windowed", DisplayMode.WINDOWED)
	display.add_item("Fullscreen", DisplayMode.FULLSCREEN)
	display.select(display.get_item_index(display_mode))
	menu.add_child(display)
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
	if current_screen == "character":
		match character_return:
			"shop": return SHOP_THEMES.get(shop_type) if venue_music_enabled else null
			"arena": return ARENA_LOBBY_THEME if venue_music_enabled else null
			"scout", "tournament": return PRE_FIGHT_THEME if venue_music_enabled else null
	if town_music_enabled and current_screen in ["town", "allocate", "character"]:
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
	# Audio settings can change the music even while the game animation clock is paused.
	music_transition = music_player.create_tween().set_parallel()
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
	if settings.has_section_key("controls", "magic_preview"):
		settings.erase_section_key("controls", "magic_preview")
	for legacy_keys in LEGACY_SHOP_TAB_BINDINGS.values():
		for legacy in legacy_keys:
			if settings.has_section_key("controls", legacy):
				settings.erase_section_key("controls", legacy)
	for action in key_bindings:
		settings.set_value("controls", action, key_bindings[action])
	return settings.save(USER_SETTINGS) == OK

func _xp_bar(parent: Node, palette: ShopView) -> void:
	var level := int(game.state.level)
	var bar := ProgressBar.new()
	bar.max_value = int(data.rules.xp_levels[level])
	bar.min_value = int(data.rules.xp_levels[level - 1])
	bar.value = int(game.state.xp)
	bar.show_percentage = false
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(bar)
	bar.custom_minimum_size = Vector2(90, 6)
	bar.add_theme_stylebox_override("background", palette.frame(palette.base.darkened(.38), palette.edge, 0))
	bar.add_theme_stylebox_override("fill", palette.frame(SAND, SAND, 0))
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	bar.tooltip_text = "%d / %d XP toward level %d" % [bar.value - bar.min_value, bar.max_value - bar.min_value, level + 1]
	bar.accessibility_name = bar.tooltip_text

func _stage(parent: Node, kind: String, height: int = 205, arena: int = 0) -> Stage:
	var stage := Stage.new()
	stage.kind = kind
	stage.arena = arena
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
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(hero)
	_fill(hero, true)
	var lockup := _column(hero, 16)
	lockup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lockup.anchor_left = .025
	lockup.anchor_right = .51
	lockup.anchor_bottom = .92
	lockup.alignment = BoxContainer.ALIGNMENT_CENTER
	var logo := TextureRect.new()
	logo.texture = TITLE_LOGO
	logo.custom_minimum_size.y = 196 if not selecting_slot else 168
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.accessibility_name = "The Cinder League"
	lockup.add_child(logo)
	if not selecting_slot:
		var play := _button(lockup, "Play", _show_title.bind(true), true)
		play.custom_minimum_size = Vector2(244, 60)
		play.size_flags_horizontal = SIZE_SHRINK_CENTER
		play.add_theme_font_size_override("font_size", 23)
		play.add_theme_color_override("font_color", Color("#ffe8bc"))
		play.add_theme_stylebox_override("normal", _style(Color("#4c301d"), Color("#ca9a59"), 10))
		play.add_theme_stylebox_override("hover", _style(Color("#664426"), Color("#f3c780"), 10))
		play.add_theme_stylebox_override("pressed", _style(Color("#352016"), Color("#e8b875"), 10))
		play.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		play.grab_focus()
		var hall := _button(lockup, "Hall of Fame", show_hall_of_fame)
		hall.custom_minimum_size = Vector2(244, 46)
		hall.size_flags_horizontal = SIZE_SHRINK_CENTER
		hall.add_theme_color_override("font_color", Color("#dec7a8"))
		hall.add_theme_stylebox_override("normal", _style(Color("#1c1819", .94), Color("#705742"), 9))
		hall.add_theme_stylebox_override("hover", _style(Color("#382a23"), SAND, 9))
		hall.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		return
	var slots := _row(content)
	for number in range(1, Campaign.SLOT_COUNT + 1):
		var card := _card(slots)
		_fill(card.get_parent())
		var saved: Dictionary = game.read_slot(number)
		if saved.get("invalid", false):
			_title(card, "Slot %d" % number, 21)
			_label(card, "Previous alpha save" if saved.get("incompatible", false) else "Save could not be opened", 17, RED)
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
	var palette := ShopView.new("amber-ring")
	_page("create", "", palette)
	_character_form(palette)

func _allocate_level() -> void:
	sound.play("level_up")
	draft = data.stats_empty()
	level_mode = true
	var palette := _arena_palette()
	_page("allocate", "", palette)
	_character_form(palette)

func _character_form(palette: ShopView) -> void:
	var heading := "Level %d" % (int(game.state.level) + 1) if level_mode else "Create gladiator"
	_title(content, heading, 31)
	var row := _row(content, 14)
	_fill(row, true)
	var preview := _column(row, 9)
	_fill(preview, true)
	preview.custom_minimum_size.x = 352
	preview.size_flags_stretch_ratio = .43
	var view := CharacterView.new(palette, serif)
	if level_mode:
		var name := _title(preview, game.state.name, 26)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	else:
		_character_appearance(preview, palette)
	var figure := view.portrait_slot(preview)
	figure.get_parent().custom_minimum_size.y = 280
	creation_stage = _stage(figure, "avatar", 280)
	creation_stage.open_preview = true
	if not level_mode:
		creation_stage.left_loadout = {"weapon": data.rules.starter_weapon}
		creation_stage.skin = draft_skin
		creation_stage.hair = draft_hair
	var metrics := _row(preview, 8)
	allocation_metrics = {
		"health": view.metric(metrics, "health", "Max health"),
		"energy": view.metric(metrics, "stamina", "Max stamina"),
		"slots": view.metric(metrics, "cast", "Spell slots"),
	}
	var details := palette.card(row, 9)
	var panel: PanelContainer = details.get_parent()
	_fill(panel, true)
	panel.custom_minimum_size.x = 420
	panel.size_flags_stretch_ratio = .57
	var top := _row(details)
	_title(top, "Attributes", 24)
	_space(top)
	points_notice = palette.label(top, "", 20, ShopView.GOLD)
	allocation_grid = _column(details, 6)
	_fill(allocation_grid, true)
	confirm_button = _button(details, "Confirm level-up" if level_mode else "Enter town", _confirm_character)
	palette.style_button(confirm_button, false, true)
	confirm_button.custom_minimum_size.y = 46
	creation_error = _wrapped(details, "", 15, RED)
	creation_error.hide()
	_draw_allocations(palette)

func _character_appearance(preview: Control, palette: ShopView) -> void:
	preview.theme = _arena_controls_theme(palette)
	name_input = LineEdit.new()
	name_input.placeholder_text = "Gladiator name"
	name_input.accessibility_name = "Gladiator name"
	name_input.max_length = 32
	name_input.custom_minimum_size.y = 42
	name_input.add_theme_stylebox_override("normal", palette.frame(palette.base, palette.edge, 9))
	name_input.add_theme_stylebox_override("focus", palette.frame(Color.TRANSPARENT, ShopView.GOLD, 0))
	preview.add_child(name_input)
	name_input.text_changed.connect(func(_value: String) -> void: _update_point_total())
	var looks := _row(preview, 10)
	palette.label(looks, "Skin", 15)
	var skin_choice := OptionButton.new()
	skin_choice.accessibility_name = "Skin tone"
	looks.add_child(skin_choice)
	_fill(skin_choice)
	for tone in ["Warm", "Light", "Brown", "Deep"]:
		skin_choice.add_item(tone)
	skin_choice.item_selected.connect(func(index: int) -> void:
		draft_skin = index
		creation_stage.skin = index
		creation_stage.queue_redraw())
	palette.label(looks, "Hair", 15)
	var hair_choice := OptionButton.new()
	hair_choice.accessibility_name = "Hair tone"
	looks.add_child(hair_choice)
	_fill(hair_choice)
	for tone in ["Dark", "Copper", "Ash"]:
		hair_choice.add_item(tone)
	hair_choice.item_selected.connect(func(index: int) -> void:
		draft_hair = index
		creation_stage.hair = index
		creation_stage.queue_redraw())

func _point_limit() -> int:
	return game.points_to_allocate() if level_mode else int(data.rules.starting_points)

func _points_left() -> int:
	var remaining := _point_limit()
	for value in draft.values():
		remaining -= int(value)
	return remaining

func _draw_allocations(palette: ShopView) -> void:
	stat_labels.clear()
	allocation_controls.clear()
	for stat in Data.STATS:
		var tile := PanelContainer.new()
		tile.add_theme_stylebox_override("panel", palette.frame(palette.base.darkened(.06), palette.edge.darkened(.24), 8))
		tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tile.custom_minimum_size.y = 57
		allocation_grid.add_child(tile)
		var row := _row(tile, 8)
		var glyph := Symbol.make("power" if stat == "Strength" else STAT_ICONS[stat], 27)
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
		var copy := _column(row, 1)
		copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_fill(copy)
		var title := palette.label(copy, stat, 18)
		title.mouse_filter = Control.MOUSE_FILTER_PASS
		stat_labels[stat] = title
		var summary := palette.label(copy, "", 14, ShopView.MUTED)
		summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		summary.mouse_filter = Control.MOUSE_FILTER_PASS
		var value := palette.label(row, "", 22, ShopView.GOLD)
		value.custom_minimum_size.x = 93 if level_mode else 36
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var minus := _button(row, "−", _change_point.bind(stat, -1))
		minus.accessibility_name = "Remove %s point" % stat
		var plus := _button(row, "+", _change_point.bind(stat, 1))
		plus.accessibility_name = "Add %s point" % stat
		for button in [minus, plus]:
			palette.style_button(button)
			button.add_theme_font_size_override("font_size", 22)
			button.custom_minimum_size = Vector2(40, 40)
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		allocation_controls[stat] = {"value": value, "summary": summary, "minus": minus, "plus": plus}
	_update_point_total()

func _update_point_total() -> void:
	var remaining := _points_left()
	points_notice.text = "1 point left" if remaining == 1 else "%d points left" % remaining
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
	var starting: Dictionary = data.fighter("", previous_stats, loadout) if level_mode else projected
	var before_metrics := {"health": starting.max_hp, "energy": starting.max_energy,
		"slots": data.spell_slots(int(previous_stats.Magic))}
	var after_metrics := {"health": projected.max_hp, "energy": projected.max_energy,
		"slots": data.spell_slots(int(values.Magic))}
	for metric in after_metrics:
		var before_value: int = before_metrics[metric]
		var after_value: int = after_metrics[metric]
		allocation_metrics[metric].text = "%d → %d" % [before_value, after_value] if level_mode and before_value != after_value else str(after_value)
	stat_labels.Attack.tooltip_text = "%d%% hit chance · %d%% crit" % [
		roundi(Duel.hit_chance(rule, values, false) * 100), roundi(Duel.crit_chance(rule, values.Attack) * 100)]
	var weapon_damage := "%d weapon damage" % roundi(Duel.strike_damage(rule, projected, false))
	stat_labels.Strength.tooltip_text = weapon_damage
	if rule.damage_per_excess_strength < rule.damage_per_strength:
		stat_labels.Strength.tooltip_text += ". Strength adds less damage above %s points." % String.num(
			Duel.strength_damage_threshold(rule, values), 2)
	stat_labels.Defence.tooltip_text = "%d%% block chance" % roundi(Duel.block_chance(rule, values.Defence) * 100)
	stat_labels.Magic.tooltip_text = "+%.1f spell damage · %.1f spell resistance\n%d prepared slots · One more every %d Magic" % [
		values.Magic * rule.damage_per_magic, Duel.spell_resistance(rule, values.Magic),
		data.spell_slots(int(values.Magic)), int(rule.magic_per_extra_cast)]
	stat_labels.Vitality.tooltip_text = "%d max health · %d HP recovered after your turn" % [
		projected.max_hp, Duel.regeneration(rule, values.Vitality)]
	var stamina := int(values.Stamina)
	var move_bonus := Duel.stamina_move_bonus(rule, stamina)
	var leap_bonus := Duel.stamina_move_bonus(rule, stamina, true)
	var step := int(data.distances.advance) + move_bonus
	var leap := int(data.distances.jump) + leap_bonus
	var lunge := Duel.lunge_range(rule, stamina)
	stat_labels.Stamina.tooltip_text = "%d max stamina · Sleep restores %d\nStep %d · Retreat %d · Leap %d spaces\nLunge up to %d spaces" % [
		projected.max_energy, Duel.recovery(rule, stamina), step, int(data.distances.retreat) + move_bonus, leap, lunge]
	stat_labels.Charisma.tooltip_text = "Stronger taunts and more gold"
	var summaries := {"Attack": stat_labels.Attack.tooltip_text, "Strength": weapon_damage,
		"Defence": stat_labels.Defence.tooltip_text, "Magic": stat_labels.Magic.tooltip_text.get_slice("\n", 0),
		"Vitality": "%d HP recovered after your turn" % Duel.regeneration(rule, values.Vitality),
		"Stamina": "Step %d · Leap %d · Lunge %d" % [step, leap, lunge], "Charisma": stat_labels.Charisma.tooltip_text}
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
	for stat in Data.STATS:
		var row: Dictionary = allocation_controls[stat]
		var base_value: int = previous_stats[stat]
		var value: int = values[stat]
		row.value.text = "%d → %d" % [base_value, value] if level_mode and base_value != value else str(value)
		row.summary.text = summaries[stat]
		row.summary.tooltip_text = stat_labels[stat].tooltip_text
		row.minus.disabled = draft[stat] == 0
		row.plus.disabled = remaining == 0
	confirm_button.disabled = remaining != 0 or (not level_mode and name_input.text.strip_edges().is_empty())

func _change_point(stat: String, delta: int) -> void:
	if draft[stat] + delta < 0 or (delta > 0 and _points_left() < 1):
		return
	draft[stat] += delta
	_update_point_total()

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
	var palette := _arena_palette()
	_page("town", "", palette)
	var map := _stage(content, "town", 350)
	_town_destination(map, palette, Rect2(44, 375, 345, 414), "attack", "Weaponsmith", _enter_shop.bind("weapon"), "weaponsmith")
	_town_destination(map, palette, Rect2(397, 383, 309, 301), "helmet", "Armory", _enter_shop.bind("armor"), "armory")
	_town_destination(map, palette, Rect2(779, 410, 390, 266), "cast", "Magic shop", _enter_shop.bind("spell"), "magic_shop")
	_town_destination(map, palette, Rect2(1231, 291, 282, 356), "trophy", "Arena", show_arena, "arena")

func _arena_palette() -> ShopView:
	return ShopView.new(str(Content.arena(game.arena_index()).get("id", "")))

func _status_bar(parent: Control, palette: ShopView) -> void:
	var town := current_screen == "town"
	var creating := current_screen == "create"
	var allocating := current_screen == "allocate"
	var inset := MarginContainer.new()
	inset.name = "StatusBar"
	_page_insets(inset, PAGE_INSET_X, 4, 4)
	parent.add_child(inset)
	var lane := _row(inset, 8)
	var level := "Character · Lv. %d" % (1 if creating else int(game.state.level))
	if creating or allocating:
		palette.label(lane, level, 16)
	else:
		var toggle: Callable = _close_character if current_screen == "character" else show_character
		var character := _button(lane, "", toggle)
		character.accessibility_name = "Character"
		palette.style_button(character, current_screen == "character")
		_track_shortcut(character, level, "character", palette.button_copy(character, level, _key_name("character")))
	var tournament_ready := false
	if not creating:
		_token(lane, "coin", str(int(game.state.gold)), "Gold")
		tournament_ready = int(game.state.level) >= int(game.arena().cap)
		if not game.state.complete and not tournament_ready:
			var progress := _row(lane, 5)
			palette.label(progress, "XP", 13, ShopView.MUTED)
			_xp_bar(progress, palette)
	_space(lane)
	palette.label(lane, data.arenas[0].name if creating else game.arena().name, 16, SAND)
	if not creating and (game.state.complete or tournament_ready):
		_league_status(lane, palette, "League champion" if game.state.complete else "Tournament ready")
	var gear := _icon_button(lane, "settings", "Settings", _show_pause if town else _show_settings)
	if not creating:
		_track_shortcut(gear, "Settings", "settings")
	gear.custom_minimum_size = Vector2(38, 35)
	palette.style_button(gear)
	if creating or (not allocating and not game.tournament_in_progress()):
		var home := _icon_button(lane, "home", "Title screen", show_menu)
		home.custom_minimum_size = Vector2(38, 35)
		palette.style_button(home)

func _league_status(parent: Control, palette: ShopView, caption: String) -> void:
	var line := _row(parent, 4)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(Symbol.make("trophy", 16))
	palette.label(line, caption, 14, SAND)

func show_character() -> void:
	if current_screen not in ["shop", "town", "arena", "scout", "tournament"]:
		return
	character_return = current_screen
	var palette := _arena_palette()
	_page("character", "", palette)
	var heading := _row(content)
	_title(heading, game.state.name, 34)
	_space(heading)
	var back := _button(heading, "", _close_character)
	back.accessibility_name = "Back"
	palette.style_button(back)
	_track_shortcut(back, "Back", "back", palette.button_copy(back, "Back", _key_name("back")))
	var view := CharacterView.new(palette, serif)
	var figure := view.build(content, data, game.state, STAT_ICONS, _item_icon)
	var portrait := _stage(figure, "avatar", 275)
	portrait.open_preview = true

func _close_character() -> void:
	match character_return:
		"shop": show_shop()
		"arena": show_arena()
		"scout": _scout_bout(faceoff_tournament)
		"tournament": _scout_bout(true)
		_: show_town()


func _enter_shop(kind: String) -> void:
	var entering := current_screen != "shop" or shop_type != kind
	if kind == "spell" and entering:
		magic_category = "Damage"
		shop_spell_slot = 0
		spell_slot_chosen = false
		for id in game.state.loadout.spells:
			if not str(id).is_empty():
				magic_category = _spell_shop_category(data.items[id])
				break
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
	shop_view = _arena_palette()
	_page("shop", "", shop_view)
	var doors := _row(content, 6)
	_shop_tab(doors, "Town", "town", show_town, false, SHOP_NAV_HEIGHT)
	_shop_tab(doors, "Armory", "armory", _enter_shop.bind("armor"), shop_type == "armor", SHOP_NAV_HEIGHT)
	_shop_tab(doors, "Weaponsmith", "weaponsmith", _enter_shop.bind("weapon"), shop_type == "weapon", SHOP_NAV_HEIGHT)
	_shop_tab(doors, "Magic shop", "magic_shop", _enter_shop.bind("spell"), shop_type == "spell", SHOP_NAV_HEIGHT)
	var filters: Dictionary = SHOP_FILTERS.get(shop_type, {})
	shop_view.build(content, not filters.is_empty(), .45 if shop_type == "weapon" else .43)
	var armor := shop_type == "armor"
	for filter in filters:
		var caption: String = ARMOR_TAB_NAMES[filter] if armor else filter
		var action: Callable = _select_armor.bind(filter) if armor else _select_magic.bind(filter)
		_shop_tab(shop_view.tabs, caption, filters[filter], action, filter == (armor_slot if armor else magic_category))
	var columns := _stock_columns()
	shop_view.headings.add_theme_constant_override("separation", 5)
	var name_heading := shop_view.label(shop_view.headings, "Item", 14, ShopView.MUTED)
	_fill(name_heading)
	for column in columns:
		shop_view.column_cell(shop_view.headings, column[0], column[1], 14, ShopView.MUTED)
	shop_view.column_cell(shop_view.headings, "Price", _stock_price_width(), 14, ShopView.MUTED)
	shop_entries.clear()
	var stock: Array[Dictionary] = []
	for item in data.items.values():
		if _shop_stocks(item):
			stock.append(item)
	if shop_type != "weapon":
		stock.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return left.level < right.level)
	var equipped_id := ""
	for item in stock:
		_add_stock_row(item, columns)
		if equipped_id.is_empty() and _equipped(item):
			equipped_id = item.id
	shop_stage = _stage(shop_view.preview, "avatar", 180)
	shop_stage.open_preview = true
	var kit_header := _title(shop_view.kit_panel, SHOP_KIT_TITLES[shop_type], 24)
	shop_view.kit_panel.move_child(kit_header, 0)
	var magic_shop := shop_type == "spell"
	if magic_shop:
		spell_checkout_prompt = _wrapped(shop_view.kit_panel, "", 15, ShopView.TEXT)
		shop_view.kit_panel.move_child(spell_checkout_prompt, 1)
		spell_checkout_prompt.hide()
	var header := _row(shop_view.details, 12)
	var title_area := _column(header, 2)
	_fill(title_area)
	shop_title = _title(title_area, "", 24)
	shop_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	shop_requirements = HFlowContainer.new()
	shop_requirements.add_theme_constant_override("h_separation", 9)
	title_area.add_child(shop_requirements)
	var actions := _column(header, 3)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	var buttons := _row(actions, 6)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var notice_parent: BoxContainer = title_area if magic_shop else actions
	spell_slot_notice = shop_view.label(notice_parent, "", 14, ShopView.MUTED)
	if not magic_shop:
		spell_slot_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clear_spell_button = _button(buttons, "", _clear_spell)
	_style_shop_action(clear_spell_button, "Clear slot", "magic_clear")
	shop_buy = _button(buttons, "", _buy_item)
	shop_buy.custom_minimum_size.y = 38
	shop_stats = _row(shop_view.details, 7)
	shop_view.style_button(shop_buy, true, true)
	clear_spell_button.hide()
	shop_buy.hide()
	shop_requirements.hide()
	if shop_entries.is_empty():
		shop_title.text = "No stock available"
		_refresh_shop_kit()
		return
	if selected_item not in shop_entries:
		selected_item = equipped_id if not equipped_id.is_empty() else stock[0].id
	_preview_item(selected_item)

func _shop_tab(parent: Control, caption: String, action: String, callback: Callable, active: bool = false,
		height: int = 44) -> void:
	var tab := _button(parent, "", callback)
	_fill(tab)
	var keycap := shop_view.shortcut(tab, caption, _key_name(action), active, height)
	_track_shortcut(tab, caption, action, keycap)

func _shop_stocks(item: Dictionary) -> bool:
	match shop_type:
		"weapon": return item.kind == "weapon"
		"armor": return item.kind == "armor" and item.slot == armor_slot
	return (data.is_prepared_spell(item) or item.kind == "potion") and _spell_shop_category(item) == magic_category

func _stock_columns() -> Array:
	match shop_type:
		"armor": return [["Armor", 48], ["Level", 43], ["Defence", 63]]
		"weapon": return [["Damage", 53], ["Stamina", 56], ["Reach", 40]]
	match magic_category:
		"Damage": return [["Damage", 53], ["Stamina", 56], ["Level", 38], ["Magic", 39]]
		"Utility": return [["Stamina", 56], ["Level", 38], ["Magic", 39]]
	return []

func _stock_price_width() -> int:
	return 82 if shop_type == "armor" else 76

func _add_stock_row(item: Dictionary, columns: Array) -> void:
	var button := _button(shop_view.stock, "", _select_stock_item.bind(item.id))
	button.accessibility_name = item.name
	var locked: String = data.lock_reason(game.state, item)
	button.tooltip_text = locked
	button.custom_minimum_size.y = 54
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var line := shop_view.inset_row(button)
	shop_view.icon(line, _item_icon(item), 34)
	var name_parent: Control = line
	var show_weapon_lock: bool = item.kind == "weapon" and not locked.is_empty()
	if item.kind == "potion" or show_weapon_lock:
		name_parent = _column(line, 3)
		name_parent.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_fill(name_parent)
	var item_name := shop_view.label(name_parent, item.name, 17 if item.kind == "weapon" else 18)
	item_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_fill(item_name)
	if item.kind == "potion" or show_weapon_lock:
		var secondary := _weapon_lock(item) if show_weapon_lock else _magic_effect(item)
		var secondary_color := RED if show_weapon_lock else ShopView.MUTED
		var note := shop_view.label(name_parent, secondary, 14, secondary_color)
		note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for column in columns:
		var value := _stock_value(item, column[0])
		var color := ShopView.TEXT
		if column[0] == "Level" and game.state.level < item.level:
			color = RED
		if column[0] in ["Magic", "Defence"] and game.state.stats[column[0]] < item.minimum:
			color = RED
		shop_view.column_cell(line, value, column[1], 16, color)
	var price_width := _stock_price_width()
	if _equipped(item):
		button.accessibility_description = "Equipped"
		shop_view.column_cell(line, "Prepared" if data.is_prepared_spell(item) else "Equipped", price_width, 14, GREEN)
	elif item.id in game.state.owned and not data.is_prepared_spell(item):
		shop_view.column_cell(line, "Owned", price_width, 14, ShopView.MUTED)
	else:
		shop_view.price(line, int(item.price), price_width)
	shop_view.ignore_mouse(line)
	shop_entries[item.id] = button

func _select_stock_item(id: String) -> void:
	var item: Dictionary = data.items[id]
	if data.is_prepared_spell(item) and _equipped(item):
		spell_slot_chosen = false
	_preview_item(id)

func _stock_value(item: Dictionary, column: String) -> String:
	match column:
		"Armor": return str(int(item.armor))
		"Damage": return _weapon_damage(item) if item.kind == "weapon" else _spell_damage(item)
		"Stamina": return str(int(item.energy))
		"Reach": return str(int(item.reach))
		"Level": return str(int(item.level))
	return str(int(item.minimum))

func _weapon_lock(item: Dictionary) -> String:
	var missing := PackedStringArray()
	if game.state.level < item.level:
		missing.append("Lv. %d" % item.level)
	if game.state.stats.Strength < item.minimum:
		missing.append("%d Str." % item.minimum)
	return "Needs " + " · ".join(missing)

func _weapon_damage(weapon: Dictionary) -> String:
	# Show a normal attack using the current build, before temporary buffs and rival defenses.
	var fighter := {"weapon": weapon, "stats": game.state.stats}
	return String.num(Duel.strike_damage(data.rules, fighter, false), 1)

func _style_shop_action(button: Button, caption: String, action: String) -> void:
	shop_view.style_button(button)
	button.accessibility_name = caption
	_track_shortcut(button, caption, action, shop_view.button_copy(button, caption, _key_name(action)))

func _total_armor(loadout: Dictionary) -> int:
	var total := 0
	for id in loadout.armor.values():
		total += int(data.items.get(id, {}).get("armor", 0))
	return total

func _refresh_shop_kit() -> void:
	_clear(shop_view.kit)
	_clear(shop_view.kit_footer)
	var loadout: Dictionary = game.state.loadout
	if shop_type == "weapon":
		_show_equipped_weapon(data.items[loadout.weapon])
		return
	if shop_type == "armor":
		for part in Data.SLOTS:
			var id: String = loadout.armor.get(part, "")
			var piece: Dictionary = data.items.get(id, {})
			var armor := str(int(piece.armor)) if not piece.is_empty() else ""
			_kit_row(ARMOR_TAB_NAMES[part], piece, armor, part == armor_slot, _select_armor.bind(part))
		_kit_row("Weapon", data.items.get(loadout.weapon, {}))
		shop_view.label(shop_view.kit_footer, "Total armor  %d" % _total_armor(loadout), 15)
		_space(shop_view.kit_footer)
		shop_view.label(shop_view.kit_footer, "Defence  %d" % game.state.stats.Defence, 15)
		return
	var choosing := spell_checkout != SpellCheckout.CLOSED
	spell_checkout_prompt.visible = choosing
	if spell_checkout == SpellCheckout.PICK_SLOT:
		spell_checkout_prompt.text = "Choose a slot for %s.\n%s / %s to move." % [
			shop_title.text, _key_name("shop_up"), _key_name("shop_down")]
	elif spell_checkout == SpellCheckout.CLEAR:
		spell_checkout_prompt.text = "Clear %s from slot %d?" % [shop_title.text, spell_checkout_slot + 1]
	var active_slot := spell_checkout_slot if choosing else shop_spell_slot
	for index in data.spell_slots(int(game.state.stats.Magic)):
		var prepared: Dictionary = data.items.get(_spell_at(index), {})
		var active := index == active_slot and magic_category != "Potions"
		var tile := _magic_loadout_tile(prepared, active, _select_spell_slot.bind(index), index + 1)
		if spell_checkout == SpellCheckout.CLEAR:
			if active:
				tile.add_theme_stylebox_override("disabled", tile.get_theme_stylebox("normal"))
			tile.disabled = true
		elif choosing and active:
			_focus_spell_slot(tile)
	if choosing:
		_show_spell_checkout_actions()
		return
	var potion: Dictionary = data.items.get(loadout.get("draught", ""), {})
	_magic_loadout_tile(potion, magic_category == "Potions", _select_potion_pouch)
	shop_view.label(shop_view.kit_footer, "Your Magic  %d" % game.state.stats.Magic, 16)

func _magic_loadout_tile(item: Dictionary, active: bool, action: Callable, number: int = 0) -> Button:
	var tile := _button(shop_view.kit, "", action)
	shop_view.style_button(tile, active)
	tile.custom_minimum_size.y = 82
	tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var caption := "Slot %d" % number if number > 0 else "Potion pouch"
	var title: String = item.get("name", "Empty")
	tile.accessibility_name = "%s, %s" % [caption, title]
	var row := shop_view.inset_row(tile)
	if number > 0:
		var index_label := shop_view.label(row, str(number), 20, SAND)
		index_label.custom_minimum_size.x = 28
		index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var divider := VSeparator.new()
		var rule := StyleBoxLine.new()
		rule.vertical = true
		rule.color = shop_view.edge.darkened(.25)
		divider.add_theme_stylebox_override("separator", rule)
		divider.custom_minimum_size.y = 40
		divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(divider)
	var caption_box := _column(row, 3)
	_fill(caption_box)
	caption_box.alignment = BoxContainer.ALIGNMENT_CENTER
	if not item.is_empty():
		var icon := shop_view.icon(caption_box, _item_icon(item), 44)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var name_label := shop_view.label(caption_box, title, 16, ShopView.TEXT if not item.is_empty() else ShopView.MUTED)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	shop_view.ignore_mouse(row)
	return tile

func _focus_spell_slot(tile: Button) -> void:
	tile.grab_focus()
	# The new row has its final position after the containers finish laying out.
	await get_tree().process_frame
	if is_instance_valid(tile) and tile.is_inside_tree() and tile.has_focus():
		shop_view.kit_scroll.ensure_control_visible(tile)

func _show_spell_checkout_actions() -> void:
	var footer := _column(shop_view.kit_footer, 6)
	_fill(footer)
	var previous := _spell_at(spell_checkout_slot)
	var clearing := spell_checkout == SpellCheckout.CLEAR
	if not previous.is_empty():
		_wrapped(footer, "%s must be bought again to prepare it." % data.item_name(previous), 14, ShopView.MUTED)
	var action := "Clear slot"
	if not clearing:
		action = "Prepare" if previous.is_empty() else "Replace"
		var price := _row(footer, 4)
		shop_view.label(price, "Cost", 14, ShopView.MUTED)
		_space(price)
		shop_view.price(price, int(data.items[selected_item].price))
	var confirm := _button(footer, "", _confirm_spell_checkout)
	confirm.accessibility_name = action
	confirm.custom_minimum_size.y = 38
	shop_view.style_button(confirm, false, true)
	shop_view.button_copy(confirm, action, _key_name("shop_buy"))
	var cancel := _button(footer, "", _cancel_spell_checkout)
	cancel.accessibility_name = "Cancel"
	shop_view.style_button(cancel)
	shop_view.button_copy(cancel, "Cancel", _key_name("back"))
	if clearing:
		cancel.grab_focus()

func _show_equipped_weapon(weapon: Dictionary) -> void:
	var art := shop_view.icon(shop_view.kit, _item_icon(weapon))
	art.custom_minimum_size = Vector2(0, 120)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inspect := _button(shop_view.kit, weapon.name, _select_stock_item.bind(weapon.id))
	shop_view.style_button(inspect, selected_item == weapon.id)
	inspect.tooltip_text = "Select equipped weapon"
	_weapon_kit_metric("attack", "Damage", _weapon_damage(weapon))
	_weapon_kit_metric("stamina", "Stamina", str(int(weapon.energy)))
	_weapon_kit_metric("advance", "Reach", str(int(weapon.reach)))
	shop_view.label(shop_view.kit_footer, "Your Strength  %d" % game.state.stats.Strength, 16)

func _weapon_kit_metric(symbol: String, caption: String, value: String) -> void:
	var line := _row(shop_view.kit, 8)
	line.custom_minimum_size.y = 32
	line.add_child(Symbol.make(symbol, 24))
	_label(line, caption, 17).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_space(line)
	_label(line, value, 17, SAND).size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _kit_row(caption: String, item: Dictionary, value: String = "", active: bool = false, callback: Callable = Callable()) -> void:
	var line: HBoxContainer
	var tile: Button
	if callback.is_valid():
		tile = _button(shop_view.kit, "", callback)
		shop_view.style_button(tile, active)
		tile.custom_minimum_size.y = 60
		tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tile.accessibility_name = caption + (", empty" if item.is_empty() else ", " + item.name)
		line = shop_view.inset_row(tile)
	else:
		line = _row(shop_view.kit)
		line.custom_minimum_size.y = 60
		line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if not item.is_empty():
		shop_view.icon(line, _item_icon(item), 34)
	var copy := _column(line, 1)
	_fill(copy)
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shop_view.label(copy, caption, 14, ShopView.MUTED)
	var name := shop_view.label(copy, item.get("name", "Empty"), 16)
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if not value.is_empty():
		shop_view.label(line, value, 16)
	shop_view.ignore_mouse(line)

func _spell_damage(item: Dictionary) -> String:
	return String.num(item.damage + float(game.state.stats.Magic) * data.rules.damage_per_magic, 1)

func _magic_effect(item: Dictionary) -> String:
	if item.is_empty():
		return ""
	if item.kind == "potion":
		var fighter: Dictionary = data.fighter(game.state.name, game.state.stats, game.state.loadout)
		fighter.draught = item.id
		var resource_name := "armor" if item.id == "armor_potion" else "health"
		return "Restores up to %d %s" % [Duel.potion_amount(data.rules, fighter), resource_name]
	match item.get("effect", "damage"):
		"shield": return "Absorbs %d damage" % item.power
		"push":
			return "Doubles the gap up to the edge" if data.rules.distance_based_spell_movement else "Pushes up to %d spaces" % item.power
		"pull":
			return "Brings the rival next to you" if data.rules.distance_based_spell_movement else "Pulls up to %d spaces" % item.power
		"enchant":
			return "+%d damage on the next 3 hits" % Duel.enchant_bonus(item, {"stats": game.state.stats})
	return ""

func _select_magic(category: String) -> void:
	if magic_category == category:
		return
	magic_category = category
	selected_item = ""
	show_shop()

func _select_potion_pouch() -> void:
	magic_category = "Potions"
	selected_item = game.state.loadout.get("draught", "")
	show_shop()

func _select_spell_slot(index: int) -> void:
	if spell_checkout == SpellCheckout.PICK_SLOT:
		spell_checkout_slot = index
		_refresh_shop_kit()
		return
	if spell_checkout != SpellCheckout.CLOSED:
		return
	shop_spell_slot = index
	spell_slot_chosen = true
	var id := _spell_at(index)
	var browsing_spell: bool = (selected_item in data.items
		and data.is_prepared_spell(data.items[selected_item]) and not _equipped(data.items[selected_item]))
	if browsing_spell:
		_refresh_equipment_detail(data.items[selected_item])
		return
	if not id.is_empty():
		selected_item = id
		magic_category = _spell_shop_category(data.items[id])
	elif magic_category == "Potions":
		magic_category = "Damage"
		selected_item = ""
	show_shop()

func _refresh_equipment_detail(item: Dictionary) -> void:
	for id in shop_entries:
		shop_view.style_button(shop_entries[id], id == item.id)
	shop_title.text = item.name
	_clear(shop_requirements)
	shop_requirements.hide()
	_clear(shop_stats)
	var locked: String = data.lock_reason(game.state, item)
	var gear: bool = item.kind in ["armor", "weapon"]
	var equipped := _equipped(item)
	var prepared: bool = data.is_prepared_spell(item)
	var owned: bool = item.id in game.state.owned and not prepared
	var affordable: bool = owned or game.state.gold >= item.price
	var choosing := spell_checkout != SpellCheckout.CLOSED
	clear_spell_button.visible = prepared and equipped and not choosing
	shop_buy.disabled = equipped or not locked.is_empty() or not affordable
	var prepared_slot: int = game.state.loadout.spells.find(item.id) if prepared and equipped else -1
	if prepared and not spell_slot_chosen:
		if prepared_slot >= 0:
			shop_spell_slot = prepared_slot
		else:
			# Prefer an empty slot until the player explicitly chooses a replacement target.
			shop_spell_slot = 0
			for index in data.spell_slots(int(game.state.stats.Magic)):
				if _spell_at(index).is_empty():
					shop_spell_slot = index
					break
	var replacing := prepared and not equipped and not _spell_at(shop_spell_slot).is_empty()
	_set_shop_buy_caption(item)
	spell_slot_notice.text = ""
	spell_slot_notice.tooltip_text = ""
	if prepared and equipped:
		spell_slot_notice.text = "Prepared · Slot %d" % (prepared_slot + 1)
	elif equipped:
		spell_slot_notice.text = "Equipped"
	elif locked.is_empty() and not affordable:
		spell_slot_notice.text = "Not enough gold"
	elif prepared and locked.is_empty() and not replacing and not choosing:
		spell_slot_notice.text = "Prepare in slot %d" % (shop_spell_slot + 1)
	spell_slot_notice.visible = not spell_slot_notice.text.is_empty()
	var notice_color := ShopView.MUTED
	if equipped:
		notice_color = GREEN
	elif not affordable:
		notice_color = RED
	spell_slot_notice.add_theme_color_override("font_color", notice_color)
	if item.kind == "armor":
		var current: Dictionary = data.items.get(game.state.loadout.armor.get(item.slot, ""), {})
		var old := int(current.get("armor", 0))
		var total := _total_armor(game.state.loadout)
		_gear_comparison("armor", "Piece armor", str(old), str(int(item.armor)))
		_gear_comparison("armor", "Total armor", str(total), str(total - old + int(item.armor)))
	elif item.kind == "weapon":
		var current: Dictionary = data.items[game.state.loadout.weapon]
		_gear_comparison("attack", "Damage", _weapon_damage(current), _weapon_damage(item))
		_gear_comparison("stamina", "Stamina", str(int(current.energy)), str(int(item.energy)), true)
		_gear_comparison("advance", "Reach", str(int(current.reach)), str(int(item.reach)))
	elif prepared and item.get("effect", "damage") == "damage":
		_shop_stat("attack", "Damage", _spell_damage(item))
		_shop_stat("stamina", "Stamina", str(int(item.energy)))
	else:
		var metric := _shop_metric("potion" if item.kind == "potion" else "cast", "Effect")
		metric.get_parent().size_flags_stretch_ratio = 2.0
		_wrapped(metric, _magic_effect(item), 16, ShopView.TEXT)
		if prepared:
			_shop_stat("stamina", "Stamina", str(int(item.energy)))
	if gear or not locked.is_empty():
		if game.state.level < item.level or (gear and item.level > 1):
			_shop_requirement("Level", int(game.state.level), int(item.level))
		var requirement: String = data.stat_requirement(item)
		if not requirement.is_empty() and (game.state.stats[requirement] < item.minimum or (gear and item.minimum > 0)):
			_shop_requirement(requirement, int(game.state.stats[requirement]), int(item.minimum))
		shop_requirements.visible = shop_requirements.get_child_count() > 0
	_refresh_shop_kit()
	_reveal_shop_item(item.id, shop_view.stock_scroll)

func _reveal_shop_item(id: String, scroll: ScrollContainer) -> void:
	# A new shop or a change in the checkout height can resize the viewport after selection.
	await get_tree().process_frame
	if is_instance_valid(scroll) and scroll.is_inside_tree() and selected_item == id:
		scroll.ensure_control_visible(shop_entries[id])

func _set_shop_buy_caption(item: Dictionary) -> void:
	var prepared: bool = data.is_prepared_spell(item)
	var owned: bool = item.id in game.state.owned and not prepared
	var equipped := _equipped(item)
	var needs_slot := prepared and not _spell_at(shop_spell_slot).is_empty()
	var has_price := not equipped and not owned and (not needs_slot or shop_buy.disabled)
	var action := "Equip" if owned else ("Choose slot" if needs_slot else "Buy")
	var caption := "Buy & equip" if action == "Buy" and item.kind in ["armor", "weapon"] else action
	if equipped:
		caption = "Prepared" if prepared else "Equipped"
	elif not data.lock_reason(game.state, item).is_empty():
		caption = "Locked"
	elif not owned and game.state.gold < item.price:
		caption = "Need"
	shop_buy.visible = not equipped and spell_checkout == SpellCheckout.CLOSED
	shop_view.style_button(shop_buy, true, not shop_buy.disabled)
	var amount := " %d" % item.price if has_price else ""
	shop_buy.accessibility_name = caption + amount
	_clear(shop_buy)
	if equipped:
		shop_buy.text = caption
		return
	var key := "" if shop_buy.disabled else _key_name("shop_buy")
	shop_view.button_copy(shop_buy, caption + amount, key, has_price)

func _select_armor(part: String) -> void:
	if armor_slot == part:
		return
	armor_slot = part
	selected_item = ""
	show_shop()

func _spell_shop_category(item: Dictionary) -> String:
	if item.kind == "potion":
		return "Potions"
	return "Damage" if item.get("effect", "damage") == "damage" else "Utility"

func _item_icon(item: Dictionary) -> Texture2D:
	if item.kind == "weapon":
		return Stage.weapon_icon(item)
	var magic_icon: Texture2D = Content.MAGIC_ICONS.get(item.id)
	if magic_icon != null:
		return magic_icon
	if item.kind == "potion":
		return Content.MAGIC_ICONS.potion
	var atlas := AtlasTexture.new()
	if item.kind in ["spell", "enchant"]:
		if item.get("effect", "damage") != "damage":
			return null
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
		"potion": return game.state.loadout.get("draught", "") == item.id
		"spell", "enchant": return item.id in game.state.loadout.get("spells", [])
	return game.state.loadout.get(item.kind, "") == item.id

func _preview_item(id: String) -> void:
	spell_checkout = SpellCheckout.CLOSED
	selected_item = id
	var item: Dictionary = data.items[id]
	# Try on the highlighted item in the preview without mutating the current loadout.
	var preview: Dictionary = game.state.loadout.duplicate(true)
	shop_stage.kind = "avatar"
	var prepared: bool = data.is_prepared_spell(item)
	if prepared:
		shop_stage.kind = "spell"
		shop_stage.preview_spell_effect = item.get("effect", "damage")
		shop_stage.preview_spell_power = int(item.get("power", 0))
		if shop_stage.preview_spell_effect == "enchant":
			shop_stage.preview_etching_rank = Duel.enchant_rank(item, {"stats": game.state.stats})
		shop_stage.spell_art = int(item.art)
		shop_stage.preview_spell_icon = _item_icon(item)
		shop_stage.elapsed = 0
	elif item.kind == "armor":
		preview.armor[item.slot] = id
	elif item.kind == "weapon":
		preview.weapon = id
	shop_stage.left_loadout = preview
	shop_stage.queue_redraw()
	_refresh_equipment_detail(item)

func _spell_at(index: int) -> String:
	var equipped: Array = game.state.loadout.spells
	return str(equipped[index]) if index >= 0 and index < equipped.size() else ""

func _shop_requirement(caption: String, current: int, required: int) -> void:
	var met := current >= required
	var entry := _row(shop_requirements, 4)
	entry.add_child(Symbol.make("check" if met else "lock", 15))
	var text := "%s %d" % [caption, required] if met else "%s %d / %d" % [caption, current, required]
	var label := _label(entry, text, 14, GREEN if met else RED)
	label.accessibility_name = "%s. You have %d. Requires %d. %s" % [caption, current, required, "Met" if met else "Locked"]
	entry.tooltip_text = label.accessibility_name

func _shop_metric(symbol: String, caption: String) -> VBoxContainer:
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", shop_view.frame(shop_view.base.darkened(.10), shop_view.edge.darkened(.38), 7))
	shop_stats.add_child(tile)
	_fill(tile)
	var body := _column(tile, 2)
	var heading := _row(body, 4)
	heading.add_child(Symbol.make(symbol, 16))
	shop_view.label(heading, caption, 14, ShopView.MUTED)
	return body

func _gear_comparison(symbol: String, caption: String, before: String, after: String, lower_is_better: bool = false) -> void:
	var body := _shop_metric(symbol, caption)
	var reading := _row(body, 5)
	var color := SAND
	if before != after:
		shop_view.label(reading, before, 16, ShopView.MUTED)
		shop_view.label(reading, "→", 15, ShopView.MUTED)
		# Lower stamina cost is an improvement. Damage and reach favor higher values.
		var delta := after.to_float() - before.to_float()
		var improved := delta < 0.0 if lower_is_better else delta > 0.0
		color = GREEN if improved else RED
	shop_view.label(reading, after, 20, color)
	body.get_parent().tooltip_text = "%s is %s with your equipped gear and %s with the selected item." % [caption, before, after]

func _shop_stat(symbol: String, caption: String, value: String) -> void:
	shop_view.label(_shop_metric(symbol, caption), value, 20, SAND)

func _buy_item() -> void:
	if selected_item not in data.items or shop_buy.disabled or spell_checkout != SpellCheckout.CLOSED:
		return
	var item: Dictionary = data.items[selected_item]
	var index := shop_spell_slot if data.is_prepared_spell(item) else -1
	if not _spell_at(index).is_empty():
		_open_spell_checkout(SpellCheckout.PICK_SLOT, index)
		return
	_purchase_shop_item(item, index)

func _purchase_shop_item(item: Dictionary, index: int) -> void:
	var gold_before := int(game.state.gold)
	var err: String = game.purchase(item, index)
	if err.is_empty():
		var paid := gold_before - int(game.state.gold)
		sound.play("buy" if paid > 0 else "equip")
	else:
		page_notice = err
	show_shop()

func _clear_spell() -> void:
	var index: int = game.state.loadout.spells.find(selected_item)
	if index >= 0 and spell_checkout == SpellCheckout.CLOSED:
		_open_spell_checkout(SpellCheckout.CLEAR, index)

func _clear_prepared_slot(index: int) -> void:
	page_notice = game.clear_spell(index)
	shop_spell_slot = index
	spell_slot_chosen = true
	show_shop()

func _open_spell_checkout(mode: SpellCheckout, index: int) -> void:
	# The candidate spell stays selected while the right panel browses its destination.
	spell_checkout = mode
	spell_checkout_slot = index
	_refresh_equipment_detail(data.items[selected_item])

func _cancel_spell_checkout() -> void:
	var focus := clear_spell_button if spell_checkout == SpellCheckout.CLEAR else shop_buy
	spell_checkout = SpellCheckout.CLOSED
	_refresh_equipment_detail(data.items[selected_item])
	focus.grab_focus()

func _confirm_spell_checkout() -> void:
	match spell_checkout:
		SpellCheckout.PICK_SLOT:
			spell_slot_chosen = false
			_purchase_shop_item(data.items[selected_item], spell_checkout_slot)
		SpellCheckout.CLEAR:
			_clear_prepared_slot(spell_checkout_slot)

func _spell_checkout_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel", false, true):
		_cancel_spell_checkout()
		return true
	if not _plain_key_press(event):
		return false
	var code: int = event.keycode
	if code == key_bindings.shop_buy:
		# Keep Enter or Space available for the focused footer button if either is rebound to Buy.
		var focus := get_viewport().gui_get_focus_owner()
		if code in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and focus is Button and shop_view.kit_footer.is_ancestor_of(focus):
			return false
		_confirm_spell_checkout()
		return true
	if spell_checkout == SpellCheckout.PICK_SLOT and code in [key_bindings.shop_up, key_bindings.shop_down]:
		var direction := -1 if code == key_bindings.shop_up else 1
		var last: int = data.spell_slots(int(game.state.stats.Magic)) - 1
		var next := clampi(spell_checkout_slot + direction, 0, last)
		if next != spell_checkout_slot:
			_select_spell_slot(next)
		return true
	return false

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
	var palette := _arena_palette()
	_page("arena", "", palette)
	var stage := _stage(content, "arena_preview", 350, game.arena_index())
	stage.show_rival = false
	var view := ArenaView.new(palette, serif)
	var regular := view.lobby_choice(stage, .46)
	var tournament := view.lobby_choice(stage, .72)
	_arena_scout_choice(regular, palette, false)
	_arena_scout_choice(tournament, palette, true)
	_arena_button(view.corner(stage), palette, "Town square", "town", show_town)

func _arena_scout_choice(card: VBoxContainer, palette: ShopView, tournament: bool) -> void:
	var caption := "Tournament" if tournament else "Regular bout"
	var action := "scout_tournament" if tournament else "scout_regular"
	var offer: Dictionary = game.scouted_bout(tournament)
	var button := _arena_button(card, palette, caption, action, _scout_bout.bind(tournament))
	button.accessibility_name = offer.rival.name if not offer.is_empty() else (
		"Scout tournament rival" if tournament else "Scout rival")
	button.disabled = not game.can_scout(tournament)
	if not offer.is_empty() and not button.disabled:
		var name := palette.label(card, offer.rival.name, 14, ShopView.MUTED)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return
	if tournament:
		var status := "League champion" if game.state.complete else (
			"Round 1 of %d" % game.arena().tournament.size() if game.can_tournament() else "Level %d required" % game.arena().cap)
		palette.label(card, status, 14, ShopView.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		var rewards := _row(card, 10)
		rewards.alignment = BoxContainer.ALIGNMENT_CENTER
		_token(rewards, "coin", "+%d" % game.win_gold(game.arena_index()), "Gold for a win")
		if game.regular_win_xp() > 0:
			_token(rewards, "xp", "+%d XP" % game.regular_win_xp(), "Experience for a win")

func _arena_button(parent: Control, palette: ShopView, caption: String, action: String, callback: Callable,
		primary: bool = false, lethal: bool = false) -> Button:
	var button := _button(parent, "", callback)
	button.accessibility_name = caption
	button.custom_minimum_size.y = 54 if primary else 44
	palette.style_button(button, false, primary and not lethal)
	if lethal:
		button.add_theme_stylebox_override("normal", palette.frame(Color("#774236"), palette.edge, 9))
		button.add_theme_stylebox_override("hover", palette.frame(Color("#915346"), ShopView.GOLD, 9))
		button.add_theme_stylebox_override("pressed", palette.frame(Color("#683a31"), ShopView.GOLD, 9))
	_track_shortcut(button, caption, action, palette.button_copy(button, caption, _key_name(action), false, 19 if primary else 16))
	arena_actions[action] = button
	return button

func _scout_bout(tournament: bool) -> void:
	if game.has_active_bout():
		return
	var offer: Dictionary = game.scout_bout(tournament, randi())
	if not offer.is_empty():
		_show_faceoff(offer)
	elif game.tournament_in_progress():
		var palette := _arena_palette()
		_page("tournament", "", palette)
		var stage := _stage(content, "arena_preview", 350, game.arena_index())
		stage.show_rival = false
		var view := ArenaView.new(palette, serif)
		_arena_button(view.lobby_choice(stage, .55), palette, "Next Match", "scout_tournament", _scout_bout.bind(true), true)
	else:
		show_arena()

func _show_faceoff(offer: Dictionary) -> void:
	var rival: Dictionary = offer.rival
	var player: Dictionary = data.fighter(game.state.name, game.state.stats, game.state.loadout)
	faceoff_tournament = offer.tournament
	var palette := _arena_palette()
	_page("scout", "", palette)
	var stage := _stage(content, "arena_preview", 350, game.arena_index())
	stage.set_rival(rival, int(game.state.level))
	var view := ArenaView.new(palette, serif)
	view.fighter_name(stage, 0, player, int(game.state.level))
	view.fighter_name(stage, 1, rival, int(rival.level))
	var caption := "Tournament · Round %d/%d" % [int(offer.round) + 1, int(offer.round_count)] if offer.tournament else "Regular bout"
	var actions := view.faceoff(stage, caption, player, rival, data, STAT_ICONS, _item_icon)
	var fight_caption := "Fight to the death" if offer.tournament else "Fight"
	_arena_button(actions, palette, fight_caption, "fight_confirm", _new_bout.bind(offer.tournament), true, offer.tournament)
	if not offer.tournament:
		var stakes := _row(actions, 12)
		stakes.alignment = BoxContainer.ALIGNMENT_CENTER
		palette.label(stakes, "Yield below %d%% HP" % int(data.rules.bout_yield_health_percent), 14, ShopView.MUTED)
		var loss_fee := mini(int(game.state.gold), int(data.rules.loss_gold))
		if loss_fee > 0:
			_token(stakes, "coin", "−%d on defeat" % loss_fee, "Gold lost on defeat")
	if not game.tournament_in_progress():
		_arena_button(view.corner(stage), palette, "Back", "back", show_arena)

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
	shortcut_labels.clear()
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
	var won := bout.winner == 0
	var fallen: bool = outcome.get("fallen", false)
	var practice_defeat: bool = outcome.get("practice_defeat", false)
	var detail := ""
	if not won and not venue_music_enabled:
		sound.play("defeat")
	var last: Dictionary = bout.history.back() if not bout.history.is_empty() else {}
	if outcome.get("complete", false) and won:
		detail = "League champion"
	elif fallen:
		detail = "%s has fallen" % game.state.name
	elif outcome.get("unlocked", false):
		detail = "%s unlocked" % game.arena().name
	elif practice_defeat:
		detail = "Practice round · Gladiator survives"
	elif last.get("ring_out", false):
		detail = "Ring-out"
	elif last.get("first_blood", false) and won:
		detail = "First blood"
	var tournament_locked: bool = game.tournament_in_progress()
	current_screen = "result"
	_sync_audio()
	fight.celebrate()
	_announce_bout_result(won, detail)
	# Match the visible arena even when the win has already unlocked the next one.
	var palette := ShopView.new(str(Content.arena(fight.stage.arena).get("id", "")))
	var result := palette.card(fight, 8)
	var panel: PanelContainer = result.get_parent()
	panel.name = "BoutResults"
	panel.add_theme_stylebox_override("panel", palette.frame(Color(palette.base.darkened(.32), .97), palette.edge, 12))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_top = -20
	panel.offset_bottom = -20
	var strip := HFlowContainer.new()
	strip.add_theme_constant_override("h_separation", 18)
	strip.add_theme_constant_override("v_separation", 8)
	strip.alignment = FlowContainer.ALIGNMENT_CENTER
	result.add_child(strip)
	var motion := panel.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	panel.modulate.a = 0.0
	motion.tween_property(panel, "modulate:a", 1.0, .25).set_delay(.27)
	if not fallen:
		_show_bout_rewards(strip, palette, outcome, motion)
	var controls := _row(strip, 8)
	controls.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if fallen:
		_result_button(controls, palette, "Title screen", show_menu, true)
	elif game.state.pending:
		_result_button(controls, palette, "Spend level-up points", _allocate_level, true)
	else:
		if not tournament_locked:
			result_town_button = _result_button(controls, palette, "Return to town", show_town, false, "town")
		var next_tournament := tournament_locked or practice_defeat
		result_next_button = _result_button(controls, palette, "Next Match" if next_tournament else "Next Bout",
			_scout_bout.bind(next_tournament), true, "next")
	if not game.save_error.is_empty():
		_wrapped(result, game.save_error, 15, RED)
	var fit_width := func() -> void:
		var width := panel.get_theme_stylebox("panel").get_minimum_size().x
		for block in strip.get_children():
			width += block.get_combined_minimum_size().x
		width += (strip.get_child_count() - 1) * strip.get_theme_constant("h_separation")
		var half := minf(width, maxf(0.0, fight.size.x - 40.0)) * .5
		panel.offset_left = -half
		panel.offset_right = half
	# Fit the actual labels and buttons. Wrap groups together if the window narrows.
	for block in strip.get_children():
		block.minimum_size_changed.connect(fit_width)
	fight.resized.connect(fit_width)
	fit_width.call()

func _announce_bout_result(won: bool, detail: String) -> void:
	var overlay := CenterContainer.new()
	overlay.name = "BoutAnnouncement"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fight.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var text := _column(overlay, 3)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption := _label(text, "VICTORY" if won else "DEFEAT", 76,
		Color("#e3ffed") if won else Color("#efb1a4"))
	var engraved := FontVariation.new()
	engraved.base_font = serif
	engraved.spacing_glyph = 6
	engraved.variation_embolden = .6
	caption.add_theme_font_override("font", engraved)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_outline_color", Color("#152b20") if won else Color("#22161a"))
	caption.add_theme_constant_override("outline_size", 5)
	caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .75))
	caption.add_theme_constant_override("shadow_offset_y", 4)
	caption.add_theme_constant_override("shadow_outline_size", 7)
	if not detail.is_empty():
		var subtitle := _label(text, detail, 18)
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.add_theme_color_override("font_outline_color", Color("#22161a"))
		subtitle.add_theme_constant_override("outline_size", 4)
	var center_pivot := func() -> void: overlay.pivot_offset = overlay.size * .5
	overlay.resized.connect(center_pivot)
	center_pivot.call()
	overlay.modulate.a = 0.0
	overlay.position.y = 16 if won else -16
	overlay.scale = Vector2.ONE * (.84 if won else 1.16)
	var reveal := overlay.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal.tween_property(overlay, "modulate:a", 1.0, .29)
	reveal.tween_property(overlay, "position:y", 0.0, .38)
	if won:
		# Let the word crest with the fanfare, then settle into its emerald color.
		reveal.tween_property(overlay, "scale", Vector2.ONE * 1.09, .25)
		reveal.tween_callback(sound.play_victory).set_delay(.18)
		reveal.tween_method(func(tint: Color) -> void: caption.add_theme_color_override("font_color", tint),
			caption.get_theme_color("font_color"), VICTORY_GREEN, .32).set_delay(.18)
		reveal.tween_property(overlay, "scale", Vector2.ONE, .29).set_delay(.25)
	else:
		reveal.tween_property(overlay, "scale", Vector2.ONE, .38)
	reveal.chain().tween_property(overlay, "modulate:a", 0.0, .38).set_delay(1.04)

func _result_button(parent: Control, palette: ShopView, caption: String, callback: Callable,
		primary: bool, action: String = "") -> Button:
	var button := _button(parent, "", callback)
	button.accessibility_name = caption
	button.custom_minimum_size.y = 42
	palette.style_button(button, false, primary)
	var cap := palette.button_copy(button, caption, _key_name(action) if not action.is_empty() else "")
	if not action.is_empty():
		_track_shortcut(button, caption, action, cap)
	return button

func _show_bout_rewards(parent: Control, palette: ShopView, outcome: Dictionary, motion: Tween) -> void:
	_show_bout_xp(parent, palette, int(outcome.xp), motion)
	var gained_gold := int(outcome.gold)
	if gained_gold != 0:
		var gold := int(game.state.gold)
		var before := gold - gained_gold
		var wallet := _row(parent, 5)
		wallet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var stack := ResultCoinStack.new(before, gold)
		wallet.add_child(stack)
		var amounts := _column(wallet, 2)
		amounts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		palette.label(amounts, "%+d gold" % gained_gold, 17, RED if gained_gold < 0 else ShopView.GOLD)
		var gold_total := palette.label(amounts, "%d total" % before, 14, ShopView.MUTED)
		gold_total.accessibility_name = "Total gold"
		motion.tween_method(func(time: float) -> void:
			stack.elapsed = time
			gold_total.text = "%d total" % (before + roundi(gained_gold * stack.transfer_fraction())),
			0.0, ResultCoinStack.DURATION, ResultCoinStack.DURATION).set_trans(Tween.TRANS_LINEAR).set_delay(BOUT_REWARDS_DELAY)

func _show_bout_xp(parent: Control, palette: ShopView, gained_xp: int, motion: Tween) -> void:
	var progress := _column(parent, 4)
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.custom_minimum_size.x = 160
	var stats := _row(progress, 6)
	_token(stats, "xp", "+%d XP" % gained_xp if gained_xp > 0 else "XP", "Experience")
	_space(stats)
	var level := int(game.state.level)
	var capped: bool = level >= int(game.arena().cap)
	var pending: bool = game.state.pending
	var caption := "Lv. %d ready" % (level + 1) if pending else "Lv. %d" % level
	if not game.tournament_in_progress() and game.can_tournament():
		caption = "Tournament ready"
	palette.label(stats, caption, 13, ShopView.MUTED)
	var floor_index := maxi(0, level - (2 if capped else 1))
	var target_index := level - (1 if capped else 0)
	var bar := ProgressBar.new()
	bar.min_value = int(data.rules.xp_levels[floor_index])
	bar.max_value = maxi(int(data.rules.xp_levels[target_index]), int(bar.min_value) + 1)
	var xp := int(game.state.xp)
	# Campaign already granted the XP. Animate from the balance before the bout.
	bar.value = bar.max_value if capped else xp - gained_xp
	bar.show_percentage = false
	bar.tooltip_text = "Arena level cap reached" if capped else "%d / %d XP toward level %d" % [
		mini(xp, int(bar.max_value)) - bar.min_value, bar.max_value - bar.min_value, level + 1]
	bar.accessibility_name = bar.tooltip_text
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	bar.custom_minimum_size.y = 10
	bar.add_theme_stylebox_override("background", palette.frame(palette.base.darkened(.38), palette.edge, 0))
	bar.add_theme_stylebox_override("fill", palette.frame(SAND, SAND, 0))
	progress.add_child(bar)
	if gained_xp > 0 and not capped:
		motion.tween_property(bar, "value", minf(xp, bar.max_value), .78).set_delay(BOUT_REWARDS_DELAY)

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
