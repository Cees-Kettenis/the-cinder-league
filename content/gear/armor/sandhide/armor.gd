extends RefCounted

# This set joins the seeded pool of rival looks at this player level. Armor stats come from the rival loadout.
const RIVAL_LEVEL := 1
const RIVAL_ORDER := 0

const PARTS := {
	"chest": {
		"texture": "res://content/gear/armor/sandhide/chest.webp",
		"offset": Vector2(-212.000, -291.333),
		"size": Vector2(375.333, 403.333),
	},
	"helmet": {
		"texture": "res://content/gear/armor/sandhide/helmet.webp",
		"offset": Vector2(-116, -173),
		"size": Vector2(237, 222),
		"closed": true,
	},
	"pants": {
		"texture": "res://content/gear/armor/sandhide/pants.webp",
		# Sections map armor pixel rows onto the leg pose so the armor bends with the fighter.
		"mesh": [
			{"leg": 0, "rows": [
				[Vector3(238, 373, 10), Vector3(286, 484, 796)],
				[Vector3(224, 373, 62), Vector3(267, 484, 846)],
				[Vector3(185, 373, 126), Vector3(263, 484, 894)],
				[Vector3(150, 373, 191), Vector3(250, 484, 932)],
				[Vector3(127, 373, 245), Vector3(231, 484, 974)],
				[Vector3(117, 346, 311), Vector3(223, 453, 1022)],
				[Vector3(111, 298, 377), Vector3(191, 414, 1075)],
				[Vector3(82, 259, 449), Vector3(161, 378, 1130)],
				[Vector3(36, 211, 526), Vector3(153, 353, 1188)],
				[Vector3(24, 169, 606), Vector3(146, 318, 1243)],
				[Vector3(4, 121, 685), Vector3(140, 258, 1304)],
				[Vector3(11, 89, 754), Vector3(138, 245, 1362)],
			], "joined_rows": 5},
			{"leg": 1, "rows": [
				[Vector3(373, 515, 10), Vector3(484, 687, 796)],
				[Vector3(373, 529, 62), Vector3(484, 711, 846)],
				[Vector3(373, 566, 126), Vector3(484, 714, 894)],
				[Vector3(373, 593, 191), Vector3(484, 724, 932)],
				[Vector3(373, 607, 245), Vector3(484, 737, 974)],
				[Vector3(382, 607, 311), Vector3(503, 748, 1022)],
				[Vector3(421, 623, 377), Vector3(535, 745, 1075)],
				[Vector3(440, 618, 449), Vector3(529, 747, 1130)],
				[Vector3(419, 611, 526), Vector3(551, 763, 1188)],
				[Vector3(434, 598, 606), Vector3(573, 739, 1243)],
				[Vector3(480, 602, 685), Vector3(609, 739, 1304)],
				[Vector3(500, 596, 754), Vector3(619, 735, 1362)],
			], "joined_rows": 5},
		],
	},
	"shield": {
		"texture": "res://content/gear/armor/sandhide/shield.webp",
		"size": Vector2(247, 348),
	},
	"shoes": {
		"texture": "res://content/gear/armor/sandhide/shoes.webp",
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
