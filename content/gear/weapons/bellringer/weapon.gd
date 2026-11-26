extends RefCounted

# Keep the item ID stable across art or balance edits so existing loadouts still resolve it.
const ITEM := {
	"id": "bellringer",
	"name": "Bellringer",
	"kind": "weapon",
	"level": 11,
	"price": 115,
	"minimum": 15,
	"damage": 38,
	"reach": 1,
	"energy": 9,
	"art": 1,
	"tier": 3,
	"order": 33,
}

# Grip and tip use source-image pixels. Scale sets the displayed length used by the animation.
const PLAYER := {
	"texture": "res://content/gear/weapons/bellringer/player.webp",
	"grip": Vector2(385, 656),
	"tip": Vector2(1440, 485),
	"scale": .245,
}

# The renderer aligns these two points to the same hand and strike contact as the player sprite.
const RIVAL := {
	"texture": "res://content/gear/weapons/bellringer/rival.webp",
	"grip": Vector2(167, 569),
	"tip": Vector2(786, 154),
}
