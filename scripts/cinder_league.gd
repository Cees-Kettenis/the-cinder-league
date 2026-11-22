extends Control

const Data = preload("res://scripts/data.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Duel = preload("res://scripts/duel.gd")
const Simulator = preload("res://scripts/simulator.gd")
const Stage = preload("res://scripts/stage.gd")
const Foley = preload("res://scripts/foley.gd")

const SAND := Color("#e1b880")
const TEXT := Color("#f3e8d6")
const MUTED := Color("#abaca0")
const BG := Color("#121718")
const PANEL := Color("#1a2223")
const BORDER := Color("#343f3d")
const GREEN := Color("#96d4ad")
const RED := Color("#e38d79")
const SLOTS := {"helmet": "Helmet", "chest": "Chest plate", "pants": "Pants", "shoes": "Shoes", "shield": "Shield"}
const OPPONENT_STYLES := {"brute": "Heavy hitter", "guard": "Defensive", "mage": "Spellcaster", "skirmish": "Mobile fighter"}
const USER_BALANCE := "user://balance.override.json"

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
var projected_stats: Label
var confirm_button: Button
var name_input: LineEdit
var creation_stage: Control
var level_mode := false
var shop_type := "armor"
var armor_slot := "chest"
var selected_item := ""
var shop_stage: Control
var shop_note: Label
var shop_title: Label
var stat_compare: Label
var shop_price: Label
var shop_buy: Button
var shop_entries: Dictionary = {}
var bout: RefCounted
var battle_stage: Control
var action_buttons: Dictionary = {}
var player_status: VBoxContainer
var opponent_status: VBoxContainer
var fight_log: RichTextLabel
var fight_heading: Label
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

func _space(parent: Node) -> void:
	var spacer := Control.new()
	parent.add_child(spacer)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = MOUSE_FILTER_IGNORE

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _page(key: String, heading: String, subheading: String = "") -> void:
	current_screen = key
	_clear(shell)
	var nav := _row(shell, 8)
	_title(nav, "The Cinder League", 27)
	_space(nav)
	if not game.state.is_empty() and key not in ["menu", "battle", "allocate", "create"]:
		_label(nav, "%s  ·  Lv. %d    %d gold" % [game.state.name, game.state.level, game.state.gold], 15, SAND)
	var sound_button := _button(nav, "Sound on" if sound.enabled else "Sound off")
	sound_button.pressed.connect(func() -> void:
		sound.toggle()
		sound_button.text = "Sound on" if sound.enabled else "Sound off")
	if key not in ["menu", "battle", "allocate"]:
		_button(nav, "Title screen", show_menu)
	var divider := HSeparator.new()
	shell.add_child(divider)
	if not notification.is_empty():
		_wrapped(shell, notification, 14, SAND)
		notification = ""
	if not game.save_error.is_empty():
		_wrapped(shell, game.save_error, 14, RED)
	if not heading.is_empty():
		_title(shell, heading, 32)
	if not subheading.is_empty():
		_wrapped(shell, subheading, 14)
	content = _column(shell, 10)
	_fill(content, true)

func _show_progress(parent: Node) -> void:
	var status := _row(parent, 10)
	var level := int(game.state.level)
	var xp := int(game.state.xp)
	var cap := int(game.arena().cap)
	if game.state.complete:
		_label(status, "%d XP   ·   Both tournaments won" % xp, 14, GREEN)
	elif game.state.pending:
		_label(status, "%d XP   ·   Level %d ready" % [xp, level + 1], 14, GREEN)
	elif level >= cap:
		_label(status, "%d XP   ·   Level %d tournament ready" % [xp, cap], 14, SAND)
	else:
		var threshold := int(data.rules.xp_levels[level])
		_label(status, "%d / %d XP   ·   Level %d" % [xp, threshold, level + 1], 14, SAND)
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
	_page("menu", "Choose your gladiator")
	_stage(content, "town", 310)
	var slots := _row(content)
	for number in range(1, Campaign.SLOT_COUNT + 1):
		var card := _card(slots)
		_fill(card.get_parent())
		var saved: Dictionary = game.read_slot(number)
		_label(card, "SAVE %d" % number, 13, SAND)
		if saved.get("invalid", false):
			_label(card, "Save could not be opened", 17, RED)
		elif saved.is_empty():
			_button(card, "Create gladiator", _create_character.bind(number), true)
		else:
			_title(card, "%s · Lv. %d" % [saved.name, saved.level], 19)
			_button(card, "Continue", _resume.bind(number), true)
	var bottom := _row(content)
	_button(bottom, "Simulator", show_simulator)
	_button(bottom, "Playtest balance", show_balance)

func _resume(number: int) -> void:
	if not game.resume(number):
		notification = "That save could not be opened."
		show_menu()
		return
	if game.state.pending:
		_allocate_level()
	else:
		show_town()

func _create_character(number: int) -> void:
	selected_slot = number
	draft = data.stats_empty()
	level_mode = false
	draft_skin = 0
	draft_hair = 0
	_page("create", "Create gladiator", "Save slot %d" % number)
	_character_form()

func _allocate_level() -> void:
	sound.play("level_up")
	draft = data.stats_empty()
	level_mode = true
	_page("allocate", "Level %d" % (int(game.state.level) + 1), "Choose how your gladiator improves. Confirmed points are permanent.")
	_character_form()

func _character_form() -> void:
	var row := _row(content, 11)
	_fill(row, true)
	var preview := _card(row)
	_fill(preview.get_parent(), true)
	creation_stage = _stage(preview, "avatar", 370)
	if not level_mode:
		creation_stage.left_loadout = {}
	character_name = _title(preview, game.state.name if level_mode else "New gladiator", 23)
	points_notice = _label(preview, "", 16, SAND)
	projected_stats = _wrapped(preview, "", 14)
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
	_label(details, "Stat points", 16, SAND)
	allocation_grid = _column(details, 5)
	confirm_button = _button(details, "Confirm level-up" if level_mode else "Enter town", _confirm_character, true)
	_draw_allocations()

func _point_limit() -> int:
	return int(data.rules.points_per_level if level_mode else data.rules.starting_points)

func _points_left() -> int:
	var remaining := _point_limit()
	for value in draft.values():
		remaining -= int(value)
	return remaining

func _draw_allocations() -> void:
	_clear(allocation_grid)
	var notes := {"Attack": "accuracy and critical hits", "Strength": "weapon damage and equipment",
		"Defence": "blocking and armor eligibility", "Magic": "spell accuracy, power, and eligibility",
		"Vitality": "health and regeneration", "Stamina": "energy and sleep recovery",
		"Charisma": "gold and taunts"}
	for stat in Data.STATS:
		var row := _row(allocation_grid, 5)
		var column := _column(row, 0)
		_fill(column)
		_label(column, stat, 14)
		_label(column, notes[stat], 12, MUTED)
		var base_value: int = int(game.state.stats[stat]) if level_mode else 0
		var value_label := _label(row, "%d" % (base_value + int(draft[stat])), 16, SAND)
		value_label.custom_minimum_size.x = 29
		var minus := _button(row, "−", _change_point.bind(stat, -1))
		minus.disabled = draft[stat] == 0
		var plus := _button(row, "+", _change_point.bind(stat, 1))
		plus.disabled = _points_left() == 0
	_update_point_total()

func _update_point_total() -> void:
	points_notice.text = "%d points left" % _points_left()
	var values := draft.duplicate()
	if level_mode:
		for stat in Data.STATS:
			values[stat] += int(game.state.stats[stat])
	var health := int(data.rules.base_health + values.Vitality * data.rules.health_per_vitality)
	var energy := int(data.rules.base_energy + values.Stamina * data.rules.energy_per_stamina)
	var hit := roundi(clampf(data.rules.base_hit + values.Attack * data.rules.hit_per_attack,
		data.rules.minimum_hit, data.rules.maximum_hit) * 100)
	projected_stats.text = "%d health  ·  %d stamina  ·  %d%% base hit" % [health, energy, hit]
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
		game.create(selected_slot, chosen, draft_skin, draft_hair, draft)
	show_town()

func show_town() -> void:
	if game.state.pending:
		_allocate_level()
		return
	_page("town", "Town square", "Next arena · %s" % game.arena().name)
	_show_progress(content)
	_stage(content, "town", 350)
	var destinations := _row(content)
	for pair in [["Weaponsmith", "weapon"], ["Armory", "armor"], ["Magic shop", "magic"]]:
		_fill(_button(destinations, pair[0], _enter_shop.bind(pair[1])))
	_fill(_button(destinations, "Arena", show_arena, true))

func _enter_shop(kind: String) -> void:
	shop_type = kind
	selected_item = ""
	show_shop()

func show_shop() -> void:
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
		_label(rail, "ARMOR SLOT", 13, SAND)
		var tabs := _row(rail, 4)
		for part in Data.SLOTS:
			_button(tabs, SLOTS[part], _select_armor.bind(part), armor_slot == part)
	_label(rail, SLOTS[armor_slot] if shop_type == "armor" else ("SPELLS & SUPPLIES" if shop_type == "spell" else "WEAPONS"), 15, SAND)
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
		var badge := "Locked · " + locked if not locked.is_empty() else ("Equipped" if _equipped(item) else ("Owned · Equip" if item.id in game.state.owned else "%d gold" % item.price))
		var stock_label := badge if game.state.level < item.level else "Level %d  ·  %s" % [item.level, badge]
		var button := _button(list, "%s\n%s" % [item.name, stock_label], _preview_item.bind(item.id))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 58
		button.icon = _item_icon(item)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 49)
		if not locked.is_empty():
			for color in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
				button.add_theme_color_override(color, Color("#161616"))
		shop_entries[item.id] = button
	var right := _column(row, 9)
	_fill(right, true)
	var display := _card(right, 5)
	_fill(display.get_parent(), true)
	shop_stage = _stage(display, "avatar", 305)
	var detail := _card(right, 6)
	shop_title = _title(detail, "", 23)
	shop_note = _wrapped(detail, "")
	stat_compare = _wrapped(detail, "", 16, SAND)
	var checkout := _row(detail)
	shop_price = _label(checkout, "")
	_space(checkout)
	spell_preview_button = _button(checkout, "Replay spell preview", _replay_spell)
	spell_preview_button.hide()
	shop_buy = _button(checkout, "Buy & equip", _buy_item, true)
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
	elif item.kind == "armor" and lock.is_empty():
		preview.armor[item.slot] = id
	elif item.kind == "enchant":
		preview.enchant = id
		shop_stage.demo = true
	elif item.kind == "weapon" and lock.is_empty():
		shop_stage.kind = "weapon"
		preview.weapon = id
	shop_stage.left_loadout = preview
	shop_stage.queue_redraw()
	spell_preview_button.visible = item.kind == "spell"
	for entry in shop_entries:
		var button: Button = shop_entries[entry]
		button.add_theme_stylebox_override("normal", _style(PANEL, SAND if entry == id else BORDER, 9))
	shop_title.text = item.name
	var requirement: String = data.stat_requirement(item)
	var info := "Level %d" % item.level
	if not requirement.is_empty():
		info += "  ·  %d %s" % [item.minimum, requirement]
	if not lock.is_empty():
		info += "  ·  " + lock
	shop_note.text = info
	var owned: bool = id in game.state.owned
	shop_price.text = "Owned" if owned else "%d gold" % item.price
	shop_buy.text = "Locked" if not lock.is_empty() else ("Equipped" if _equipped(item) else ("Equip" if owned else "Buy & equip"))
	shop_buy.disabled = not lock.is_empty() or _equipped(item) or (not owned and game.state.gold < item.price)
	if not owned and game.state.gold < item.price and lock.is_empty():
		shop_buy.text = "Not enough gold"
	match item.kind:
		"armor":
			var current: Dictionary = data.items.get(game.state.loadout.armor.get(item.slot, ""), {})
			var points := int(current.get("armor", 0))
			var new_points := int(item.armor)
			stat_compare.text = "Armor points   %d → %d   (%+d)" % [points, new_points, new_points - points]
		"weapon":
			var current: Dictionary = data.items[game.state.loadout.weapon]
			stat_compare.text = "Base damage   %d → %d   (%+d)    ·    Reach %d    ·    Stamina %d" % [
				current.damage, item.damage, int(item.damage - current.damage), item.reach, item.energy]
		"spell":
			var current: Dictionary = data.items.get(game.state.loadout.spell, {})
			var current_damage := int(current.get("damage", 0))
			stat_compare.text = "Base damage   %d → %d   (%+d)    ·    Reach %d    ·    %d casts per bout\nStamina per cast   %d" % [
				current_damage, item.damage, int(item.damage) - current_damage, item.reach, item.uses, item.energy]
		"enchant":
			var old := int(data.items.get(game.state.loadout.get("enchant", ""), {}).get("damage", 0))
			stat_compare.text = "Extra weapon damage   %d → %d   (%+d)" % [old, item.damage, int(item.damage) - old]
		"potion":
			stat_compare.text = "Restores %d health  ·  %d per bout" % [data.rules.heal, data.rules.potion_uses]

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
		notification = "%s equipped." % item.name
		if paid > 0:
			notification += " Paid %d gold." % paid
	else:
		notification = err
	show_shop()

func show_arena() -> void:
	var arena: Dictionary = game.arena()
	_page("arena", arena.name, arena.descriptor)
	_show_progress(content)
	var stage := _stage(content, "battle", 310)
	stage.arena = game.arena_index()
	stage.arena_width = int(data.rules.arena_size)
	stage.positions = [1, int(data.rules.arena_size) - 1]
	var next: Dictionary = game.next_opponent(false)
	var contender: Dictionary = data.opponent(next, int(game.state.level), game.arena_index())
	stage.right_loadout = contender.loadout
	stage.right_style = contender.style
	var cards := _row(content)
	var regular := _card(cards)
	_fill(regular.get_parent())
	_title(regular, "Regular bout", 20)
	_label(regular, "%s   ·   %s" % [next.name, OPPONENT_STYLES.get(next.style, next.style.capitalize())], 15)
	_label(regular, "Win reward   %d gold   ·   Up to %d XP" % [game.win_gold(game.arena_index()), arena.xp], 13, SAND)
	_button(regular, "Enter the ring", _new_bout.bind(false), true)
	var tournament := _card(cards)
	_fill(tournament.get_parent())
	_title(tournament, "Tournament", 20)
	var winner_label := "Champion of both arenas" if game.state.complete else (
		"Bout %d of %d   ·   %s" % [int(game.state.tournament) + 1, arena.tournament.size(), game.next_opponent(true).name]
		if game.can_tournament() else "Opens at level %d" % arena.cap)
	_label(tournament, winner_label, 14, SAND)
	var tournament_button := _button(tournament, "Fight next tournament bout", _new_bout.bind(true), true)
	tournament_button.disabled = not game.can_tournament()
	var nav := _row(content)
	_button(nav, "Town square", show_town)
	if not game.state.snapshot.is_empty():
		if game.state.outcome.is_empty():
			_button(nav, "Restart open bout", _retry.bind(false))
		elif game.state.outcome.winner == 0:
			_button(nav, "Practice last bout", _retry.bind(true))
		else:
			_button(nav, "Retry last bout", _retry.bind(false))

func _new_bout(tournament: bool) -> void:
	var snapshot: Dictionary = game.start_bout(tournament, int(Time.get_unix_time_from_system() * 1000) ^ int(Time.get_ticks_usec()))
	if not snapshot.is_empty():
		_open_bout(snapshot, false)

func _retry(practice: bool) -> void:
	_open_bout(game.state.snapshot, practice)

func _open_bout(snapshot: Dictionary, practice: bool) -> void:
	bout = Duel.new(data, snapshot.fighters[0], snapshot.fighters[1], int(snapshot.seed))
	practicing = practice
	bout_result = {}
	fight_locked = false
	fight_generation += 1
	var title: String = data.arenas[int(snapshot.arena)].name
	_page("battle", title, "Practice duel" if practice else ("Tournament bout" if snapshot.tournament else "Regular bout"))
	var status := _row(content, 9)
	player_status = _card(status, 3)
	opponent_status = _card(status, 3)
	_fill(player_status.get_parent())
	_fill(opponent_status.get_parent())
	battle_stage = _stage(content, "battle", 220)
	battle_stage.arena = int(snapshot.arena)
	battle_stage.arena_width = int(data.rules.arena_size)
	battle_stage.left_loadout = bout.fighters[0].loadout
	battle_stage.right_loadout = bout.fighters[1].loadout
	battle_stage.right_style = bout.fighters[1].style
	fight_heading = _label(content, "", 17, SAND)
	var box := GridContainer.new()
	box.columns = 5
	content.add_child(box)
	_fill(box)
	box.add_theme_constant_override("h_separation", 6)
	box.add_theme_constant_override("v_separation", 6)
	action_buttons.clear()
	for action in Duel.ACTIONS:
		var button := _button(box, Duel.LABELS[action], _player_action.bind(action))
		_fill(button)
		button.custom_minimum_size.y = 37
		action_buttons[action] = button
	var log_panel := _card(content)
	fight_log = RichTextLabel.new()
	fight_log.fit_content = false
	fight_log.scroll_following = true
	fight_log.custom_minimum_size.y = 58
	log_panel.add_child(fight_log)
	fight_log.add_text("Bout opens. Choose your move.")
	var bottom := _row(content)
	_button(bottom, "Leave bout", _leave_bout)
	_space(bottom)
	_label(bottom, "Seed %s" % snapshot.seed, 13, MUTED)
	_refresh_battle()

func _fighter_status(panel: VBoxContainer, fighter: Dictionary) -> void:
	_clear(panel)
	_title(panel, fighter.name, 19)
	var attributes := _row(panel, 10)
	for status in [["hp", "max_hp", "Health", RED], ["armor", "max_armor", "Armor", SAND], ["energy", "max_energy", "Stamina", GREEN]]:
		var column := _column(attributes, 2)
		_fill(column)
		_label(column, "%s  %d / %d" % [status[2], fighter[status[0]], fighter[status[1]]], 13, status[3])
		var meter := ProgressBar.new()
		meter.show_percentage = false
		meter.custom_minimum_size.y = 6
		meter.max_value = maxi(1, int(fighter[status[1]]))
		meter.value = fighter[status[0]]
		meter.add_theme_stylebox_override("background", _style(BG, BORDER, 2))
		meter.add_theme_stylebox_override("fill", _style(status[3], status[3], 2))
		column.add_child(meter)

func _refresh_battle() -> void:
	_fighter_status(player_status, bout.fighters[0])
	_fighter_status(opponent_status, bout.fighters[1])
	battle_stage.positions = bout.positions.duplicate()
	battle_stage.queue_redraw()
	var side: String = "Your turn" if bout.active == 0 else bout.fighters[1].name + " takes a turn"
	fight_heading.text = "%s   ·   Distance %d" % [side, bout.distance()]
	for action in Duel.ACTIONS:
		var button: Button = action_buttons[action]
		var why: String = bout.reason(action) if bout.active == 0 else "Opponent's turn"
		var title: String = Duel.LABELS[action]
		if action == "cast" and not bout.fighters[0].spell.is_empty():
			title = "%s (%d)" % [bout.fighters[0].spell.name, bout.fighters[0].casts]
		button.disabled = fight_locked or not why.is_empty()
		var description := why if not why.is_empty() else ("%d stamina" % bout.cost(action, 0) if bout.cost(action, 0) > 0 else "")
		if why.is_empty() and action in ["attack", "cast"]:
			description += " · %d%% hit" % roundi(bout.chance(action) * 100)
		button.text = title if description.is_empty() else title + "\n" + description
		button.tooltip_text = why

func _leave_bout() -> void:
	fight_generation += 1
	sound.stop()
	show_arena()

func _player_action(action: String) -> void:
	if fight_locked or bout.active != 0 or not bout.reason(action).is_empty():
		return
	fight_locked = true
	var generation := fight_generation
	await _animate_turn(bout.act(action), generation)
	if current_screen != "battle" or generation != fight_generation:
		return
	if bout.winner != -2:
		_finish_bout()
		return
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
	if bout.winner != -2 and bout_result.is_empty():
		bout_result = game.settle(bout.winner, practicing)
	for button: Button in action_buttons.values():
		button.disabled = true
	var fighter: Dictionary = bout.fighters[event.side]
	fight_heading.text = "%s   ·   %s" % [fighter.name, event.title]
	battle_stage.animate(event)
	sound.begin_turn(event, int(fighter.spell.get("art", 0)))
	await get_tree().create_timer(Stage.IMPACT_TIME).timeout
	if current_screen != "battle" or generation != fight_generation:
		return
	sound.impact(event, int(fighter.weapon.get("art", 0)))
	fight_log.add_text("\n%02d   %s" % [event.turn, event.message])
	_refresh_battle()
	await get_tree().create_timer(Stage.ACTION_TIME - Stage.IMPACT_TIME).timeout

func _finish_bout() -> void:
	var snapshot: Dictionary = game.state.snapshot.duplicate(true)
	var outcome: Dictionary = game.settle(bout.winner, practicing) if bout_result.is_empty() else bout_result
	var title := "Victory" if bout.winner == 0 else "Draw" if bout.winner == -1 else "Defeat"
	if bout.winner != -1:
		sound.play("victory" if bout.winner == 0 else "defeat")
	_page("result", title, "Practice result" if practicing else snapshot.opponent)
	var card := _card(content)
	_title(card, "Bout results", 22)
	if not practicing:
		_label(card, "+%d gold    +%d XP" % [outcome.gold, outcome.xp], 19, SAND)
		_show_progress(card)
	if outcome.get("unlocked", false):
		_wrapped(card, "You won the tournament. The Iron Court is open.", 17, GREEN)
	if outcome.get("complete", false) and bout.winner == 0:
		_wrapped(card, "You won both tournaments. You're the Cinder League champion.", 17, GREEN)
	if not bout.history.is_empty():
		var messages := RichTextLabel.new()
		messages.custom_minimum_size.y = 240
		card.add_child(messages)
		messages.add_text("\n".join(bout.history.map(func(event: Dictionary) -> String: return "%d  %s" % [event.turn, event.message])))
	var controls := _row(content)
	if game.state.pending:
		_button(controls, "Spend level-up points", _allocate_level, true)
	else:
		_button(controls, "Return to town", show_town, true)
		_button(controls, "Practice last bout" if game.state.outcome.get("winner", -2) == 0 else "Retry bout", _retry.bind(game.state.outcome.get("winner", -2) == 0))
		_button(controls, "Arena", show_arena)

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
	_page("simulator", "Simulator", "Run a seeded matchup or test how a build progresses through both arenas.")
	var buttons := _row(content, 9)
	var left := _styles(buttons, "Fighter", 0)
	var right := _styles(buttons, "Opponent", 2)
	var level := _number(buttons, "Level", 1, 8, 4)
	var seeds := _number(buttons, "Seed", 0, 99999999, 42)
	var runs := _number(buttons, "Bouts", 1, 500, 20)
	var actions := _row(content)
	_button(actions, "Run matchup", _simulate.bind(left, right, level, seeds, runs, false), true)
	_button(actions, "Run campaign", _simulate.bind(left, right, level, seeds, runs, true))
	_button(actions, "Playtest balance", show_balance)
	sim_output = TextEdit.new()
	sim_output.editable = false
	sim_output.placeholder_text = "Results and the first bout's turn-by-turn trace will appear here."
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
		var status := "Both tournaments won" if result.complete else "Run ended at the bout limit"
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
	_page("balance", "Playtest balance", "Combat, item, and economy values are editable. Changes apply to new bouts and simulations.")
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
