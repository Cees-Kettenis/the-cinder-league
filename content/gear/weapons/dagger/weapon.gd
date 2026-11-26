extends RefCounted

# Keep the item ID stable across art or balance edits so existing loadouts still resolve it.
const ITEM := {
	"id": "dagger",
	"name": "Dagger",
	"kind": "weapon",
	"level": 1,
	"price": 0,
	"minimum": 0,
	"damage": 7,
	"reach": 1,
	"energy": 4,
	"art": 0,
	"tier": 0,
	"order": 0,
}

# Grip and tip use source-image pixels. Scale sets the displayed length used by the animation.
const PLAYER := {
	"texture": "res://content/gear/weapons/dagger/player.webp",
	"grip": Vector2(171, 350),
	"tip": Vector2(441, 73),
	"scale": .37,
}

# The renderer aligns these two points to the same hand and strike contact as the player sprite.
const RIVAL := {
	"texture": "res://content/gear/weapons/dagger/rival.webp",
	"grip": Vector2(136, 358),
	"tip": Vector2(492, 5),
}
