extends RefCounted
## Places the lobby choices and the face-off comparison over the arena preview.

const Data = preload("res://game/catalog/data.gd")
const Duel = preload("res://game/combat/duel.gd")
const ShopView = preload("res://game/screens/shops/shop_view.gd")
const Stage = preload("res://game/combat/stage.gd")
const Symbol = preload("res://game/screens/ui_symbol.gd")

var _palette: ShopView
var _serif: Font

func _init(palette: ShopView, serif: Font) -> void:
	_palette = palette
	_serif = serif

func lobby_choice(stage: Control, center: float) -> VBoxContainer:
	var slot := CenterContainer.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(slot)
	_anchor(slot, Rect2(center - .12, .27, .24, .37))
	var card := _palette.card(slot, 6)
	card.get_parent().custom_minimum_size.x = 208
	return card

func corner(stage: Control) -> HBoxContainer:
	var corner := HBoxContainer.new()
	stage.add_child(corner)
	corner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	corner.offset_left = 20
	corner.offset_top = -14
	corner.offset_bottom = -14
	return corner

func fighter_name(stage: Stage, side: int, fighter: Dictionary, level: int) -> void:
	var card := _palette.card(stage, 0)
	var panel: PanelContainer = card.get_parent()
	panel.add_theme_stylebox_override("panel", _palette.frame(Color(_palette.base.darkened(.38), .93), _palette.edge, 8))
	var name := _palette.label(card, "%s · Lv. %d" % [fighter.name, level], 19)
	name.add_theme_font_override("font", _serif)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.tooltip_text = name.text
	var place := func() -> void:
		var feet := stage.preview_feet(side)
		var width := minf(stage.size.x * .28, name.get_theme_font("font").get_string_size(name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 30)
		panel.size.x = width
		panel.position = Vector2(feet.x - width * .5, maxf(12.0, feet.y - stage.preview_fighter_height() * 1.10 - 40.0))
	stage.resized.connect(place)
	place.call()

func faceoff(stage: Control, caption: String, player: Dictionary, rival: Dictionary, data: RefCounted,
		stat_icons: Dictionary, item_icon: Callable) -> VBoxContainer:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := _palette.card(center, 8)
	var panel: PanelContainer = card.get_parent()
	panel.name = "FaceoffComparison"
	var title := _palette.label(card, caption, 26)
	title.add_theme_font_override("font", _serif)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	var list := _column(scroll, 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compare(list, "Combat stats", "You", "Rival")
	_compare(list, "Health", player.max_hp, rival.max_hp, "health")
	_compare(list, "Armor", player.max_armor, rival.max_armor, "armor")
	_compare(list, "Stamina", player.max_energy, rival.max_energy, "stamina")
	var details := Button.new()
	details.text = "Show all stats"
	_palette.style_button(details)
	list.add_child(details)
	var extra := _column(list, 4)
	for stat in Data.STATS:
		_compare(extra, stat, player.stats[stat], rival.stats[stat], "power" if stat == "Strength" else stat_icons[stat])
	var step := int(data.distances.advance)
	var leap := int(data.distances.jump)
	_compare(extra, "Step", step + Duel.stamina_move_bonus(data.rules, player.stats.Stamina),
		step + Duel.stamina_move_bonus(data.rules, rival.stats.Stamina), "advance")
	_compare(extra, "Leap", leap + Duel.stamina_move_bonus(data.rules, player.stats.Stamina, true),
		leap + Duel.stamina_move_bonus(data.rules, rival.stats.Stamina, true), "jump")
	_compare(extra, "Lunge", Duel.lunge_range(data.rules, player.stats.Stamina),
		Duel.lunge_range(data.rules, rival.stats.Stamina), "lunge")
	var reach := _compare(extra, "Weapon reach", player.weapon.reach, rival.weapon.reach, "attack")
	reach.tooltip_text = "%s / %s" % [player.weapon.name, rival.weapon.name]
	extra.hide()
	var kit_title := _palette.label(list, "Spells & potions", 15, ShopView.MUTED)
	kit_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var kits := _row(list, 7)
	_kit(kits, player, data.items, item_icon)
	_kit(kits, rival, data.items, item_icon)
	var actions := _column(card, 6)
	var fit := func() -> void:
		panel.custom_minimum_size.x = clampf(stage.size.x * .33, 326.0, 470.0)
		var chrome := title.get_combined_minimum_size().y + actions.get_combined_minimum_size().y + 36.0
		scroll.custom_minimum_size.y = minf(list.get_combined_minimum_size().y, maxf(96.0, stage.size.y * .90 - chrome))
	stage.resized.connect(fit)
	actions.minimum_size_changed.connect(fit)
	list.minimum_size_changed.connect(fit)
	details.pressed.connect(func() -> void:
		extra.visible = not extra.visible
		details.text = "Hide extra stats" if extra.visible else "Show all stats"
		scroll.scroll_vertical = 0
		fit.call())
	fit.call()
	return actions

func _compare(parent: Control, caption: String, left: Variant, right: Variant, icon: String = "") -> HBoxContainer:
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", _palette.frame(_palette.base, _palette.edge.darkened(.24), 3))
	parent.add_child(tile)
	var row := _row(tile, 6)
	var player := _score(row, left)
	var center := _row(row, 5)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not icon.is_empty():
		center.add_child(Symbol.make(icon, 19))
	_palette.label(center, caption, 15)
	var rival := _score(row, right)
	if (left is int or left is float) and left != right:
		var higher := player if left > right else rival
		higher.add_theme_color_override("font_color", Color("#96d4ad"))
	return row

func _score(row: HBoxContainer, value: Variant) -> Label:
	var score := _palette.label(row, str(int(value)) if value is float else str(value), 16, ShopView.GOLD)
	score.custom_minimum_size.x = 57
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return score

func _kit(parent: Control, fighter: Dictionary, items: Dictionary, item_icon: Callable) -> void:
	var kit := _palette.card(parent, 4)
	kit.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spells := Duel.spell_actions(fighter)
	if spells.is_empty():
		_kit_item(kit, {}, "cast", "No spells", item_icon)
	for action in spells:
		_kit_item(kit, Duel.spell_for_action(fighter, action), "cast", "No spells", item_icon)
	# Keep the two potions opposite one another regardless of how many spells are prepared.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kit.add_child(spacer)
	var potion: Dictionary = items.get(fighter.get("draught", "potion"), {}) if fighter.potions > 0 else {}
	_kit_item(kit, potion, "potion", "No potion", item_icon)

func _kit_item(parent: Control, item: Dictionary, symbol: String, empty: String, item_icon: Callable) -> void:
	var row := _row(parent, 6)
	var art: Texture2D = item_icon.call(item) if not item.is_empty() else null
	if art == null:
		var mark := Symbol.make(symbol, 23)
		mark.modulate.a = .6
		row.add_child(mark)
	else:
		_palette.icon(row, art, 24)
	var name := _palette.label(row, item.get("name", empty), 14, ShopView.MUTED if item.is_empty() else ShopView.TEXT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.tooltip_text = name.text

func _anchor(control: Control, area: Rect2) -> void:
	control.anchor_left = area.position.x
	control.anchor_right = area.end.x
	control.anchor_top = area.position.y
	control.anchor_bottom = area.end.y

func _column(parent: Node, gap: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	parent.add_child(box)
	return box

func _row(parent: Node, gap: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", gap)
	parent.add_child(row)
	return row
