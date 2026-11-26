extends RefCounted

# Keep the item ID stable across art or balance edits so existing loadouts still resolve it.
const ITEM := {
	"id": "sword",
	"name": "Short sword",
	"kind": "weapon",
	"level": 1,
	"price": 15,
	"minimum": 0,
	"damage": 10,
	"reach": 1,
	"energy": 4,
	"art": 0,
	"tier": 0,
	"order": 1,
}

# Grip and tip use source-image pixels. Scale sets the displayed length used by the animation.
const PLAYER := {
	"texture": "res://content/gear/weapons/sword/player.webp",
	"grip": Vector2(137, 372),
	"tip": Vector2(463, 35),
	"scale": .51,
}

# The renderer aligns these two points to the same hand and strike contact as the player sprite.
const RIVAL := {
	"texture": "res://content/gear/weapons/sword/rival.webp",
	"grip": Vector2(138, 489),
	"tip": Vector2(644, 5),
}
