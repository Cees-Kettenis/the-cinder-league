extends RefCounted

# This set joins the seeded pool of rival looks at this player level. Armor stats come from the rival loadout.
const RIVAL_LEVEL := 4
const RIVAL_ORDER := 2

const PARTS := {
	"chest": {
		"texture": "res://content/gear/armor/ashmail/chest.webp",
		"offset": Vector2(-212.000, -291.333),
		"size": Vector2(375.333, 403.333),
	},
	"helmet": {
		"texture": "res://content/gear/armor/ashmail/helmet.webp",
		"offset": Vector2(-116, -185),
		"size": Vector2(235, 234),
		"closed": true,
	},
	"pants": {
		"texture": "res://content/gear/armor/ashmail/pants.webp",
		# Sections map armor pixel rows onto the leg pose so the armor bends with the fighter.
		"mesh": [
			{"leg": 0, "rows": [
				[Vector3(217, 373, 10), Vector3(286, 484, 796)],
				[Vector3(197, 373, 62), Vector3(267, 484, 846)],
				[Vector3(176, 373, 126), Vector3(263, 484, 894)],
				[Vector3(160, 373, 191), Vector3(250, 484, 932)],
				[Vector3(142, 373, 245), Vector3(231, 484, 974)],
				[Vector3(125, 350, 311), Vector3(223, 453, 1022)],
				[Vector3(97, 311, 377), Vector3(191, 414, 1075)],
				[Vector3(78, 271, 449), Vector3(161, 378, 1130)],
				[Vector3(31, 213, 526), Vector3(153, 353, 1188)],
				[Vector3(27, 166, 606), Vector3(146, 318, 1243)],
				[Vector3(16, 121, 685), Vector3(140, 258, 1304)],
				[Vector3(9, 99, 754), Vector3(138, 245, 1362)],
			], "joined_rows": 5},
			{"leg": 1, "rows": [
				[Vector3(373, 504, 10), Vector3(484, 687, 796)],
				[Vector3(373, 533, 62), Vector3(484, 711, 846)],
				[Vector3(373, 557, 126), Vector3(484, 714, 894)],
				[Vector3(373, 594, 191), Vector3(484, 724, 932)],
				[Vector3(373, 610, 245), Vector3(484, 737, 974)],
				[Vector3(388, 622, 311), Vector3(503, 748, 1022)],
				[Vector3(413, 613, 377), Vector3(535, 745, 1075)],
				[Vector3(438, 591, 449), Vector3(529, 747, 1130)],
				[Vector3(424, 599, 526), Vector3(551, 763, 1188)],
				[Vector3(445, 587, 606), Vector3(573, 739, 1243)],
				[Vector3(476, 586, 685), Vector3(609, 739, 1304)],
				[Vector3(488, 590, 754), Vector3(619, 735, 1362)],
			], "joined_rows": 5},
		],
	},
	"shield": {
		"texture": "res://content/gear/armor/ashmail/shield.webp",
		"size": Vector2(233, 375),
	},
	"shoes": {
		"texture": "res://content/gear/armor/ashmail/shoes.webp",
		"mesh": [
			{"leg": 0, "rows": [
				[Vector3(0, 147, 11), Vector3(112, 264, 1285)],
				[Vector3(0, 147, 65), Vector3(112, 264, 1339)],
				[Vector3(0, 147, 125), Vector3(112, 264, 1400)],
				[Vector3(0, 147, 176), Vector3(112, 264, 1452)],
				[Vector3(0, 147, 234), Vector3(112, 264, 1511)],
			], "joined_rows": 0},
			{"leg": 1, "rows": [
				[Vector3(450, 768, 2), Vector3(612, 875, 1288)],
				[Vector3(450, 768, 57), Vector3(612, 875, 1338)],
				[Vector3(450, 768, 119), Vector3(612, 875, 1395)],
				[Vector3(450, 768, 172), Vector3(612, 875, 1443)],
				[Vector3(450, 768, 232), Vector3(612, 875, 1497)],
			], "joined_rows": 0},
		],
	},
}
