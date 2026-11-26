extends RefCounted

# Keep the item ID stable across art or balance edits so existing loadouts still resolve it.
const ITEM := {
	"id": "warden_sword",
	"name": "Warden blade",
	"kind": "weapon",
	"level": 8,
	"price": 62,
	"minimum": 11,
	"damage": 28,
	"reach": 2,
	"energy": 8,
	"art": 0,
	"tier": 2,
	"order": 5,
}

# Grip and tip use source-image pixels. Scale sets the displayed length used by the animation.
const PLAYER := {
	"texture": "res://content/gear/weapons/warden-sword/player.webp",
	"grip": Vector2(123, 380),
	"tip": Vector2(487, 23),
	"scale": .70,
}

# The renderer aligns these two points to the same hand and strike contact as the player sprite.
const RIVAL := {
	"texture": "res://content/gear/weapons/warden-sword/rival.webp",
	"grip": Vector2(119, 557),
	"tip": Vector2(669, 8),
}
