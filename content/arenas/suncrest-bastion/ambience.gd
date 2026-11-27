extends RefCounted

const DESIGN_SIZE := Vector2(1000, 563)
const BANNERS := [
	Rect2(351, 179, 42, 75), Rect2(608, 180, 42, 74),
	Rect2(117, 164, 21, 43), Rect2(862, 163, 21, 45),
]
# Each column marks the top and bottom of the cloth at a given x, inside the painted edge.
const DRAPES := [
	[
		Vector3(0, 247, 263), Vector3(10, 252, 277), Vector3(21, 256, 290),
		Vector3(34, 258, 299), Vector3(47, 257, 295), Vector3(59, 254, 285), Vector3(68, 252, 268),
	],
	[
		Vector3(105, 256, 264), Vector3(116, 260, 281), Vector3(130, 263, 293),
		Vector3(145, 264, 301), Vector3(158, 264, 301), Vector3(173, 263, 293),
		Vector3(188, 261, 278), Vector3(195, 260, 267),
	],
	[
		Vector3(226, 263, 274), Vector3(238, 266, 288), Vector3(251, 267, 296),
		Vector3(264, 267, 295), Vector3(278, 266, 285), Vector3(290, 262, 273),
	],
	[
		Vector3(709, 263, 273), Vector3(721, 266, 285), Vector3(735, 267, 294),
		Vector3(749, 267, 295), Vector3(763, 265, 287), Vector3(776, 261, 272),
	],
	[
		Vector3(803, 259, 268), Vector3(815, 262, 283), Vector3(829, 264, 294),
		Vector3(843, 264, 301), Vector3(857, 263, 299), Vector3(873, 260, 290),
		Vector3(887, 257, 277), Vector3(898, 254, 265),
	],
	[
		Vector3(931, 254, 267), Vector3(941, 257, 283), Vector3(952, 259, 294),
		Vector3(966, 259, 300), Vector3(979, 256, 295), Vector3(991, 252, 285), Vector3(1000, 249, 273),
	],
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
