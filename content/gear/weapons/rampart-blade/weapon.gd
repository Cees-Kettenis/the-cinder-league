extends RefCounted

# Keep the item ID stable across art or balance edits so existing loadouts still resolve it.
const ITEM := {
	"id": "rampart_blade",
	"name": "Rampart blade",
	"kind": "weapon",
	"level": 13,
	"price": 125,
	"minimum": 17,
	"damage": 34,
	"reach": 2,
	"energy": 8,
	"art": 0,
	"tier": 4,
	"order": 42,
}

# Grip and tip use source-image pixels. Scale sets the displayed length used by the animation.
const PLAYER := {
	"texture": "res://content/gear/weapons/rampart-blade/player.webp",
	"grip": Vector2(106, 394),
	"tip": Vector2(622, 5),
	"scale": .64,
}

# The renderer aligns these two points to the same hand and strike contact as the player sprite.
const RIVAL := {
	"texture": "res://content/gear/weapons/rampart-blade/rival.webp",
	"grip": Vector2(187, 610),
	"tip": Vector2(982, 5),
}
