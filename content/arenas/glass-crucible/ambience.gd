extends RefCounted

const DESIGN_SIZE := Vector2(1000, 563)
const BANNERS := [
	Rect2(356, 183, 37, 80), Rect2(606, 182, 38, 81),
	Rect2(120, 166, 12, 46), Rect2(867, 166, 12, 46),
	Rect2(112, 263, 79, 12), Rect2(811, 263, 78, 12),
]
const FLAMES := [Rect2(307, 259, 41, 57), Rect2(651, 258, 46, 58)]
# Center, size, and color of each painted lantern's glow.
const LIGHTS := [
	[Vector2(48, 125), Vector2(39, 55), Color("#e674ff")],
	[Vector2(260, 126), Vector2(46, 62), Color("#e674ff")],
	[Vector2(739, 126), Vector2(46, 62), Color("#e674ff")],
	[Vector2(952, 125), Vector2(39, 55), Color("#e674ff")],
]
const WALKWAYS := [
	[Vector2(150, 164), Vector2(224, 171), 11.0, Color("#33242a")],
	[Vector2(798, 102), Vector2(838, 94), 8.0, Color("#342638")],
	[Vector2(685, 175), Vector2(716, 171), 9.0, Color("#32252f")],
	[Vector2(798, 172), Vector2(854, 163), 10.0, Color("#352429")],
]
