extends RefCounted
## Read-only character sheet using the same palette and equipment art as the shops.

const Data = preload("res://game/catalog/data.gd")
const ShopView = preload("res://game/screens/shops/shop_view.gd")
const Symbol = preload("res://game/screens/ui_symbol.gd")

var _palette: ShopView
var _serif: Font

func _init(palette: ShopView, serif: Font) -> void:
	_palette = palette
	_serif = serif

func build(parent: Control, data: RefCounted, state: Dictionary, stat_icons: Dictionary, item_icon: Callable) -> Control:
	var sheet := HBoxContainer.new()
	sheet.add_theme_constant_override("separation", 14)
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(sheet)
	var attributes := _palette.card(sheet, 8)
	_column_width(attributes.get_parent(), 232, .27)
	_heading(attributes, "Attributes")
	for stat in Data.STATS:
		var icon: String = "power" if stat == "Strength" else stat_icons[stat]
		_attribute(attributes, icon, stat, int(state.stats[stat]))
	var portrait := Control.new()
	portrait.clip_contents = true
	sheet.add_child(portrait)
	_column_width(portrait, 240, .42)
	_portrait_light(portrait)
	var figure := VBoxContainer.new()
	portrait.add_child(figure)
	figure.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var summary := VBoxContainer.new()
	summary.add_theme_constant_override("separation", 10)
	sheet.add_child(summary)
	_column_width(summary, 254, .31)
	var fighter: Dictionary = data.fighter(state.name, state.stats, state.loadout)
	var slots: int = data.spell_slots(int(state.stats.Magic))
	_combat_stats(summary, fighter, slots)
	_loadout(summary, fighter, data.items, slots, item_icon)
	return figure

func _column_width(column: Control, minimum: int, weight: float) -> void:
	column.custom_minimum_size.x = minimum
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = weight

func _heading(parent: Control, caption: String) -> void:
	_palette.label(parent, caption, 25).add_theme_font_override("font", _serif)

func _tile(parent: Control, height: int, expand: bool = true) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", _palette.frame(_palette.base.darkened(.06), _palette.edge.darkened(.24), 9))
	tile.custom_minimum_size.y = height
	if expand:
		tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(tile)
	return tile

func _row(parent: Control, spacing: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", spacing)
	parent.add_child(row)
	return row

func _glyph(parent: Control, symbol: String, width: int) -> void:
	var icon := Symbol.make(symbol, width)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(icon)

func _attribute(parent: Control, icon: String, caption: String, value: int) -> void:
	var row := _row(_tile(parent, 48), 10)
	_glyph(row, icon, 26)
	_palette.label(row, caption, 18).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_palette.label(row, str(value), 24, ShopView.GOLD)

func _combat_stats(parent: Control, fighter: Dictionary, slots: int) -> void:
	var combat := _palette.card(parent, 8)
	_heading(combat, "Combat stats")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	combat.add_child(grid)
	for entry in [["health", "Max health", fighter.max_hp], ["stamina", "Max stamina", fighter.max_energy],
			["armor", "Total armor", fighter.max_armor], ["cast", "Spell slots", slots]]:
		var tile := _tile(grid, 66, false)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 3)
		tile.add_child(stack)
		var title := _row(stack, 5)
		_glyph(title, entry[0], 19)
		_palette.label(title, entry[1], 14, ShopView.MUTED)
		_palette.label(stack, str(entry[2]), 25, ShopView.GOLD)

func _loadout(parent: Control, fighter: Dictionary, items: Dictionary, slots: int, item_icon: Callable) -> void:
	var equipment := _palette.card(parent, 8)
	equipment.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	_heading(equipment, "Loadout")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipment.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	_gear_tile(rows, "Weapon", "attack", fighter.weapon, item_icon)
	_gear_tile(rows, "Potion", "potion", items.get(fighter.get("draught", ""), {}), item_icon)
	_palette.label(rows, "Prepared spells", 15, ShopView.MUTED)
	var prepared: Array = fighter.get("prepared", [])
	for index in slots:
		var spell: Dictionary = prepared[index] if index < prepared.size() else {}
		_gear_tile(rows, str(index + 1), "cast", spell, item_icon, true)

func _gear_tile(parent: Control, caption: String, fallback: String, item: Dictionary, item_icon: Callable,
		spell_slot: bool = false) -> void:
	var tile := _tile(parent, 46 if spell_slot else 58)
	var row := _row(tile, 10)
	if spell_slot:
		var number := _palette.label(row, caption, 15, ShopView.MUTED)
		number.custom_minimum_size.x = 19
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var art: Texture2D = item_icon.call(item) if not item.is_empty() else null
	if art == null:
		_glyph(row, fallback, 33 if spell_slot else 38)
	else:
		_palette.icon(row, art, 33 if spell_slot else 38)
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 0)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(copy)
	if not spell_slot:
		_palette.label(copy, caption, 13, ShopView.MUTED)
	var name: String = item.get("name", "Empty")
	var title := _palette.label(copy, name, 17, ShopView.MUTED if item.is_empty() else ShopView.TEXT)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tile.tooltip_text = ("Slot " + caption if spell_slot else caption) + " · " + name

func _portrait_light(parent: Control) -> void:
	# A soft pool of arena-colored light brings the armor forward against the stone.
	_add_portrait_glow(parent, _palette.edge.lightened(.22), .46, Rect2(.03, .03, .90, .93))
	_add_portrait_glow(parent, Color("#110d13"), .70, Rect2(.16, .929, .57, .065))

func _add_portrait_glow(parent: Control, color: Color, opacity: float, bounds: Rect2) -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, .37, 1.0])
	gradient.colors = PackedColorArray([Color(color, opacity), Color(color, opacity * .52), Color(color, 0)])
	var glow := GradientTexture2D.new()
	glow.width = 128
	glow.height = 128
	glow.gradient = gradient
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(.5, .5)
	glow.fill_to = Vector2(1.0, .5)
	var layer := TextureRect.new()
	layer.texture = glow
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(layer)
	layer.anchor_left = bounds.position.x
	layer.anchor_top = bounds.position.y
	layer.anchor_right = bounds.end.x
	layer.anchor_bottom = bounds.end.y
