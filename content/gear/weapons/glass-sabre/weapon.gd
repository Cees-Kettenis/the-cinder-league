extends RefCounted

# Keep the item ID stable across art or balance edits so existing loadouts still resolve it.
const ITEM := {
	"id": "glass_sabre",
	"name": "Glass sabre",
	"kind": "weapon",
	"level": 9,
	"price": 90,
	"minimum": 13,
	"damage": 32,
	"reach": 2,
	"energy": 8,
	"art": 0,
	"tier": 3,
	"order": 32,
}

# Grip and tip use source-image pixels. Scale sets the displayed length used by the animation.
const PLAYER := {
	"texture": "res://content/gear/weapons/glass-sabre/player.webp",
	"grip": Vector2(249, 786),
	"tip": Vector2(1480, 50),
	"scale": .29,
	"rest_hand": Vector3(815, 515, 0),
	"rotation": -PI / 3.0,
}

# The renderer aligns these two points to the same hand and strike contact as the player sprite.
const RIVAL := {
	"texture": "res://content/gear/weapons/glass-sabre/rival.webp",
	"grip": Vector2(186, 640),
	"tip": Vector2(1117, 13),
}
