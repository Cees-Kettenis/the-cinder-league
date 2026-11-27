extends RefCounted

const DESIGN_SIZE := Vector2(1000, 563)
const BANNERS := [
	Rect2(351, 179, 42, 75), Rect2(608, 180, 42, 74),
	Rect2(117, 164, 21, 43), Rect2(862, 163, 21, 45),
	Rect2(113, 269, 60, 17), Rect2(837, 269, 52, 17),
]
const FLAMES := [Rect2(300, 287, 32, 36), Rect2(667, 285, 34, 38)]
const LIGHTS := [
	[Vector2(46, 120), Vector2(57, 74), Color("#ffbd62")],
	[Vector2(260, 126), Vector2(55, 70), Color("#ffc46a")],
	[Vector2(740, 126), Vector2(55, 70), Color("#ffc46a")],
	[Vector2(954, 122), Vector2(57, 74), Color("#ffbd62")],
]
const WALKWAYS := [
	[Vector2(151, 169), Vector2(220, 175), 11.0, Color("#2d2527")],
	[Vector2(295, 176), Vector2(331, 181), 9.0, Color("#2d2527")],
	[Vector2(663, 180), Vector2(718, 174), 10.0, Color("#302527")],
	[Vector2(789, 177), Vector2(838, 173), 11.0, Color("#2e2526")],
]
