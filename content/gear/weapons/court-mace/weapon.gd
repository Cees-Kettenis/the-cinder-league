extends RefCounted

# Keep the item ID stable across art or balance edits so existing loadouts still resolve it.
const ITEM := {
	"id": "court_mace",
	"name": "Court mace",
	"kind": "weapon",
	"level": 7,
	"price": 56,
	"minimum": 7,
	"damage": 24,
	"reach": 2,
	"energy": 7,
	"art": 1,
	"tier": 2,
	"order": 4,
}

# Grip and tip use source-image pixels. Scale sets the displayed length used by the animation.
const PLAYER := {
	"texture": "res://content/gear/weapons/court-mace/player.webp",
	"grip": Vector2(169, 341),
	"tip": Vector2(449, 37),
	"scale": .62,
}

# The renderer aligns these two points to the same hand and strike contact as the player sprite.
const RIVAL := {
	"texture": "res://content/gear/weapons/court-mace/rival.webp",
	"grip": Vector2(150, 527),
	"tip": Vector2(629, 53),
}
