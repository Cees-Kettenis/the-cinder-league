extends RefCounted

# Keep the item ID stable across art or balance edits so existing loadouts still resolve it.
const ITEM := {
	"id": "gatebreaker",
	"name": "Gatebreaker",
	"kind": "weapon",
	"level": 15,
	"price": 155,
	"minimum": 20,
	"damage": 44,
	"reach": 1,
	"energy": 10,
	"art": 1,
	"tier": 4,
	"order": 43,
}

# Grip and tip use source-image pixels. Scale sets the displayed length used by the animation.
const PLAYER := {
	"texture": "res://content/gear/weapons/gatebreaker/player.webp",
	"grip": Vector2(109, 397),
	"tip": Vector2(510, 146),
	"scale": .64,
}

# The renderer aligns these two points to the same hand and strike contact as the player sprite.
const RIVAL := {
	"texture": "res://content/gear/weapons/gatebreaker/rival.webp",
	"grip": Vector2(279, 518),
	"tip": Vector2(741, 292),
}
