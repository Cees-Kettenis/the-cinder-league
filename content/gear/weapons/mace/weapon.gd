extends RefCounted

# Keep the item ID stable across art or balance edits so existing loadouts still resolve it.
const ITEM := {
	"id": "mace",
	"name": "Iron mace",
	"kind": "weapon",
	"level": 3,
	"price": 41,
	"minimum": 3,
	"damage": 15,
	"reach": 1,
	"energy": 6,
	"art": 1,
	"tier": 1,
	"order": 2,
}

# Grip and tip use source-image pixels. Scale sets the displayed length used by the animation.
const PLAYER := {
	"texture": "res://content/gear/weapons/mace/player.webp",
	"grip": Vector2(164, 361),
	"tip": Vector2(447, 39),
	"scale": .53,
}

# The renderer aligns these two points to the same hand and strike contact as the player sprite.
const RIVAL := {
	"texture": "res://content/gear/weapons/mace/rival.webp",
	"grip": Vector2(122, 494),
	"tip": Vector2(568, 56),
}
