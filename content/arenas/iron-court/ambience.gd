extends RefCounted

const DESIGN_SIZE := Vector2(1000, 331)
const BANNERS := [
	Rect2(399, 72, 32, 66), Rect2(599, 72, 30, 66),
	Rect2(278, 135, 48, 11), Rect2(707, 135, 49, 11),
	Rect2(276, 20, 82, 11), Rect2(327, 49, 9, 30),
]
const FLAMES := [
	Rect2(367, 151, 21, 22), Rect2(640, 151, 25, 22),
	Rect2(57, 54, 14, 17), Rect2(935, 58, 14, 18),
	Rect2(296, 96, 9, 13), Rect2(732, 95, 10, 13),
]
# Walkway endpoints follow the top of the parapet. Height is the part of a spectator visible above it.
const WALKWAYS := [
	[Vector2(150, 102), Vector2(222, 113), 7.0, Color("#363232")],
	[Vector2(793, 113), Vector2(881, 101), 8.0, Color("#303335")],
]
