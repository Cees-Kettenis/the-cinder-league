extends RefCounted
## Selects a single backdrop variant without loading either texture.

const TOWN := "res://game/screens/town/backdrop"
const TITLE := "res://game/screens/title/backdrop"
const COMPACT_MAX_EDGE := 1366

## Use the window's pixel size because Godot keeps a separate logical size for the UI.
static func texture_path(stem: String, window_size: Vector2i) -> String:
	var compact := maxi(window_size.x, window_size.y) <= COMPACT_MAX_EDGE
	return stem + ("-compact.webp" if compact else ".webp")
