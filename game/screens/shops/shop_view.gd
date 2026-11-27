extends RefCounted
## Shop layout and the arena palette shared by shops, town, and the character screen.

const Symbol = preload("res://game/screens/ui_symbol.gd")
const STONE = preload("res://game/screens/town/backdrop-compact.webp")
const TEXT := Color("#f5e8d4")
const GOLD := Color("#efc586")
const MUTED := Color("#dcc8ac")
const PALETTES := {
	"amber-ring": [Color("#433026"), Color("#956a48")],
	"iron-court": [Color("#262f3a"), Color("#677c90")],
	"glass-crucible": [Color("#35283e"), Color("#896795")],
	"suncrest-bastion": [Color("#41351f"), Color("#94794d")],
}

var base: Color
var edge: Color
var stock: VBoxContainer
var stock_scroll: ScrollContainer
var tabs: HBoxContainer
var headings: HBoxContainer
var preview: VBoxContainer
var details: VBoxContainer
var kit_panel: VBoxContainer
var kit: VBoxContainer
var kit_scroll: ScrollContainer
var kit_footer: HBoxContainer

func _init(arena_id: String) -> void:
	var palette: Array = PALETTES.get(arena_id, PALETTES["amber-ring"])
	base = palette[0]
	edge = palette[1]

func backdrop(parent: Control) -> void:
	var shade := ColorRect.new()
	shade.color = base.darkened(.40)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Use the cobblestone at the bottom of the existing town art.
	var crop := AtlasTexture.new()
	crop.atlas = STONE
	crop.region = Rect2(112, 682, 806, 169)
	crop.filter_clip = true
	var surface := TextureRect.new()
	surface.texture = crop
	surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	surface.stretch_mode = TextureRect.STRETCH_SCALE
	surface.self_modulate = Color(edge.lightened(.18), .37)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func build(parent: Control, has_tabs: bool, catalog_share: float) -> void:
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 14)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)
	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 8)
	grid.add_child(rail)
	_size_column(rail, 448, catalog_share)
	var catalog := card(rail, 8)
	catalog.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	catalog.add_child(tabs)
	tabs.visible = has_tabs
	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left", 9)
	inset.add_theme_constant_override("margin_right", 9)
	catalog.add_child(inset)
	headings = HBoxContainer.new()
	headings.add_theme_constant_override("separation", 5)
	inset.add_child(headings)
	stock_scroll = ScrollContainer.new()
	stock_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stock_scroll.follow_focus = true
	stock_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog.add_child(stock_scroll)
	var bar := stock_scroll.get_v_scroll_bar()
	# Keep the headers over their columns when stock needs a scrollbar.
	var align_headers := func() -> void:
		var gutter := ceili(bar.get_combined_minimum_size().x) if bar.visible else 0
		inset.add_theme_constant_override("margin_right", 9 + gutter)
	bar.visibility_changed.connect(align_headers)
	align_headers.call()
	stock = VBoxContainer.new()
	stock.add_theme_constant_override("separation", 4)
	stock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stock.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stock_scroll.add_child(stock)
	details = card(rail, 7)
	details.get_parent().custom_minimum_size.y = 96
	preview = VBoxContainer.new()
	preview.clip_contents = true
	grid.add_child(preview)
	_size_column(preview, 218, .79 - catalog_share)
	kit_panel = card(grid, 8)
	_size_column(kit_panel.get_parent(), 210, .21)
	kit_scroll = ScrollContainer.new()
	kit_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	kit_scroll.follow_focus = true
	kit_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kit_panel.add_child(kit_scroll)
	kit = VBoxContainer.new()
	kit.add_theme_constant_override("separation", 5)
	kit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kit_scroll.add_child(kit)
	kit_panel.add_child(HSeparator.new())
	kit_footer = HBoxContainer.new()
	kit_panel.add_child(kit_footer)

func _size_column(column: Control, minimum: int, weight: float) -> void:
	column.custom_minimum_size.x = minimum
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = weight

func card(parent: Node, spacing: int) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", frame(base.darkened(.32), edge.darkened(.15), 10))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", spacing)
	panel.add_child(content)
	return content

func frame(fill: Color, line: Color, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = line
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, padding)
	return style

func style_button(button: Button, selected: bool = false, primary: bool = false) -> void:
	var fill := base.lerp(edge, .40) if selected else base
	var border := GOLD if selected else edge.darkened(.22)
	button.add_theme_stylebox_override("normal", frame(GOLD if primary else fill, border, 8))
	button.add_theme_stylebox_override("hover", frame(GOLD.lightened(.13) if primary else fill.lerp(edge, .30), GOLD, 8))
	button.add_theme_stylebox_override("pressed", frame(GOLD.darkened(.12) if primary else fill.lightened(.13), GOLD, 8))
	button.add_theme_stylebox_override("disabled", frame(base.darkened(.10), edge.darkened(.36), 8))
	var focus := frame(Color.TRANSPARENT, GOLD.lightened(.24), 0)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_color", base.darkened(.55) if primary else TEXT)
	button.add_theme_color_override("font_hover_color", base.darkened(.55) if primary else TEXT)
	button.add_theme_color_override("font_pressed_color", base.darkened(.55) if primary else TEXT)
	button.add_theme_color_override("font_focus_color", base.darkened(.55) if primary else TEXT)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_font_size_override("font_size", 16)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func keycap(parent: Node, key: String) -> Label:
	var cap := PanelContainer.new()
	var border := frame(base.darkened(.42), edge, 4)
	border.set_corner_radius_all(4)
	border.set_content_margin(SIDE_TOP, 2)
	border.set_content_margin(SIDE_BOTTOM, 2)
	cap.add_theme_stylebox_override("panel", border)
	cap.custom_minimum_size = Vector2(24, 24)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(cap)
	var glyph := label(cap, key, 13, GOLD)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ignore_mouse(cap)
	return glyph

func shortcut(button: Button, caption: String, key: String, selected: bool, height: int) -> Label:
	style_button(button, selected)
	button.accessibility_name = caption
	button.custom_minimum_size.y = height
	return button_copy(button, caption, key, false, 15)

func button_copy(button: Button, caption: String, key: String = "", coin: bool = false, font_size: int = 16) -> Label:
	button.text = ""
	var center := CenterContainer.new()
	button.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 7)
	center.add_child(line)
	if coin:
		var symbol := Symbol.make("coin", 17)
		symbol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(symbol)
	var color := button.get_theme_color("font_disabled_color" if button.disabled else "font_color")
	label(line, caption, font_size, color)
	var glyph: Label
	if not key.is_empty():
		glyph = keycap(line, key)
	var minimum_height := button.custom_minimum_size.y
	var fit := func() -> void:
		if center.get_parent() != button:
			return
		# The Button owns input and focus. Its centered caption supplies the minimum size.
		var required := line.get_combined_minimum_size() + Vector2(12, 10)
		button.custom_minimum_size = Vector2(required.x, maxf(minimum_height, required.y))
	line.minimum_size_changed.connect(fit)
	fit.call()
	ignore_mouse(center)
	return glyph

func label(parent: Node, caption: String, font_size: int, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = caption
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(result)
	return result

func inset_row(button: Button) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 9
	row.offset_right = -9
	return row

func column_cell(row: HBoxContainer, caption: String, width: int, font_size: int, color: Color = TEXT) -> Label:
	var cell := label(row, caption, font_size, color)
	cell.custom_minimum_size.x = width
	cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return cell

func icon(parent: Node, texture: Texture2D, width: int = 38) -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture
	art.custom_minimum_size = Vector2(width, width)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(art)
	return art

func price(parent: Node, amount: int, width: int = 0) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	line.alignment = BoxContainer.ALIGNMENT_END
	line.custom_minimum_size.x = width
	parent.add_child(line)
	var coin := Symbol.make("coin", 16)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(coin)
	label(line, str(amount), 15, GOLD)

func ignore_mouse(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			ignore_mouse(child)
