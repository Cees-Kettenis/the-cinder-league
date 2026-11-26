extends RefCounted

# Keep the item ID stable across art or balance edits so existing loadouts still resolve it.
const ITEM := {
	"id": "smith_sword",
	"name": "Forged short sword",
	"kind": "weapon",
	"level": 5,
	"price": 50,
	"minimum": 6,
	"damage": 19,
	"reach": 1,
	"energy": 6,
	"art": 0,
	"tier": 2,
	"order": 3,
}

# Grip and tip use source-image pixels. Scale sets the displayed length used by the animation.
const PLAYER := {
	"texture": "res://content/gear/weapons/smith-sword/player.webp",
	"grip": Vector2(126, 378),
	"tip": Vector2(466, 36),
	"scale": .58,
}

# The renderer aligns these two points to the same hand and strike contact as the player sprite.
const RIVAL := {
	"texture": "res://content/gear/weapons/smith-sword/rival.webp",
	"grip": Vector2(119, 516),
	"tip": Vector2(652, 9),
}
