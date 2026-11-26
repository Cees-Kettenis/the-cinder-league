extends RefCounted

# Item IDs are saved in loadouts. Armor values here are separate from sprite placement below.
const ITEMS := [
	{"id": "studded_helmet", "name": "Reinforced helmet", "kind": "armor", "level": 3, "price": 18, "minimum": 3, "slot": "helmet", "armor": 5, "tier": 1, "order": 7},
	{"id": "studded_chest", "name": "Reinforced chest plate", "kind": "armor", "level": 3, "price": 24, "minimum": 3, "slot": "chest", "armor": 8, "tier": 1, "order": 11},
	{"id": "studded_pants", "name": "Reinforced pants", "kind": "armor", "level": 3, "price": 18, "minimum": 3, "slot": "pants", "armor": 5, "tier": 1, "order": 15},
	{"id": "studded_shoes", "name": "Reinforced shoes", "kind": "armor", "level": 3, "price": 16, "minimum": 3, "slot": "shoes", "armor": 4, "tier": 1, "order": 19},
	{"id": "studded_shield", "name": "Bronze-rimmed shield", "kind": "armor", "level": 3, "price": 21, "minimum": 3, "slot": "shield", "armor": 6, "tier": 1, "order": 23},
]

const PARTS := {
	"chest": {
		"texture": "res://content/gear/armor/studded/chest.webp",
		"offset": Vector2(-208.0, -280.667),
		"size": Vector2(368.0, 394.667),
	},
	"helmet": {
		"texture": "res://content/gear/armor/studded/helmet.webp",
		"offset": Vector2(-110.000, -164.000),
		"size": Vector2(227.333, 190.000),
	},
	"pants": {
		"texture": "res://content/gear/armor/studded/pants.webp",
		# Sections map armor pixel rows onto the leg pose so the armor bends with the fighter.
		"mesh": [
			{"leg": 0, "rows": [
				[Vector3(265, 384, 2), Vector3(286, 484, 796)],
				[Vector3(228, 384, 64), Vector3(267, 484, 846)],
				[Vector3(194, 384, 124), Vector3(263, 484, 894)],
				[Vector3(160, 384, 184), Vector3(250, 484, 932)],
				[Vector3(161, 384, 232), Vector3(231, 484, 974)],
				[Vector3(138, 346, 296), Vector3(223, 453, 1022)],
				[Vector3(128, 292, 365), Vector3(191, 414, 1075)],
				[Vector3(76, 249, 445), Vector3(161, 378, 1130)],
				[Vector3(33, 206, 536), Vector3(153, 353, 1188)],
				[Vector3(23, 142, 621), Vector3(146, 318, 1243)],
				[Vector3(0, 106, 701), Vector3(140, 258, 1304)],
				[Vector3(38, 69, 765), Vector3(138, 245, 1362)],
			], "joined_rows": 5},
			{"leg": 1, "rows": [
				[Vector3(384, 493, 2), Vector3(484, 687, 796)],
				[Vector3(384, 528, 64), Vector3(484, 711, 846)],
				[Vector3(384, 569, 124), Vector3(484, 714, 894)],
				[Vector3(384, 610, 184), Vector3(484, 724, 932)],
				[Vector3(384, 609, 232), Vector3(484, 737, 974)],
				[Vector3(420, 620, 296), Vector3(503, 748, 1022)],
				[Vector3(460, 637, 365), Vector3(535, 745, 1075)],
				[Vector3(481, 651, 445), Vector3(529, 747, 1130)],
				[Vector3(473, 648, 536), Vector3(551, 763, 1188)],
				[Vector3(507, 638, 621), Vector3(573, 739, 1243)],
				[Vector3(526, 642, 701), Vector3(609, 739, 1304)],
				[Vector3(551, 620, 765), Vector3(619, 735, 1362)],
			], "joined_rows": 5},
		],
	},
	"shield": {
		"texture": "res://content/gear/armor/studded/shield.webp",
		"size": Vector2(276, 374),
	},
	"shoes": {
		"texture": "res://content/gear/armor/studded/shoes.webp",
		"mesh": [
			{"leg": 0, "rows": [
				[Vector3(0, 150, 1), Vector3(112, 264, 1285)],
				[Vector3(0, 150, 58), Vector3(112, 264, 1339)],
				[Vector3(0, 150, 122), Vector3(112, 264, 1400)],
				[Vector3(0, 150, 176), Vector3(112, 264, 1452)],
				[Vector3(0, 150, 238), Vector3(112, 264, 1511)],
			], "joined_rows": 0},
			{"leg": 1, "rows": [
				[Vector3(449, 768, 17), Vector3(612, 875, 1288)],
				[Vector3(449, 768, 69), Vector3(612, 875, 1338)],
				[Vector3(449, 768, 128), Vector3(612, 875, 1395)],
				[Vector3(449, 768, 178), Vector3(612, 875, 1443)],
				[Vector3(449, 768, 234), Vector3(612, 875, 1497)],
			], "joined_rows": 0},
		],
	},
}
