extends RefCounted

# Item IDs are saved in loadouts. Armor values here are separate from sprite placement below.
const ITEMS := [
	{"id": "mail_helmet", "name": "Chainmail helmet", "kind": "armor", "level": 5, "price": 34, "minimum": 5, "slot": "helmet", "armor": 8, "tier": 2, "order": 8},
	{"id": "mail_chest", "name": "Chainmail chest plate", "kind": "armor", "level": 4, "price": 37, "minimum": 5, "slot": "chest", "armor": 11, "tier": 2, "order": 12},
	{"id": "mail_pants", "name": "Chainmail pants", "kind": "armor", "level": 5, "price": 34, "minimum": 5, "slot": "pants", "armor": 8, "tier": 2, "order": 16},
	{"id": "mail_shoes", "name": "Chainmail shoes", "kind": "armor", "level": 5, "price": 31, "minimum": 5, "slot": "shoes", "armor": 7, "tier": 2, "order": 20},
	{"id": "mail_shield", "name": "Iron-rimmed shield", "kind": "armor", "level": 4, "price": 33, "minimum": 5, "slot": "shield", "armor": 9, "tier": 2, "order": 24},
]

const PARTS := {
	"chest": {
		"texture": "res://content/gear/armor/mail/chest.webp",
		"offset": Vector2(-211.333, -292.667),
		"size": Vector2(373.333, 404.667),
	},
	"helmet": {
		"texture": "res://content/gear/armor/mail/helmet.webp",
		"offset": Vector2(-112.667, -174.667),
		"size": Vector2(232.000, 200.667),
	},
	"pants": {
		"texture": "res://content/gear/armor/mail/pants.webp",
		# Sections map armor pixel rows onto the leg pose so the armor bends with the fighter.
		"mesh": [
			{"leg": 0, "rows": [
				[Vector3(282, 393, 2), Vector3(286, 484, 796)],
				[Vector3(245, 393, 65), Vector3(267, 484, 846)],
				[Vector3(217, 393, 125), Vector3(263, 484, 894)],
				[Vector3(185, 393, 186), Vector3(250, 484, 932)],
				[Vector3(161, 393, 235), Vector3(231, 484, 974)],
				[Vector3(143, 349, 299), Vector3(223, 453, 1022)],
				[Vector3(123, 304, 368), Vector3(191, 414, 1075)],
				[Vector3(72, 246, 447), Vector3(161, 378, 1130)],
				[Vector3(34, 192, 537), Vector3(153, 353, 1188)],
				[Vector3(18, 131, 622), Vector3(146, 318, 1243)],
				[Vector3(6, 103, 701), Vector3(140, 258, 1304)],
				[Vector3(7, 87, 746), Vector3(138, 245, 1362)],
			], "joined_rows": 5},
			{"leg": 1, "rows": [
				[Vector3(393, 534, 2), Vector3(484, 687, 796)],
				[Vector3(393, 557, 65), Vector3(484, 711, 846)],
				[Vector3(393, 590, 125), Vector3(484, 714, 894)],
				[Vector3(393, 615, 186), Vector3(484, 724, 932)],
				[Vector3(393, 628, 235), Vector3(484, 737, 974)],
				[Vector3(424, 632, 299), Vector3(503, 748, 1022)],
				[Vector3(470, 659, 368), Vector3(535, 745, 1075)],
				[Vector3(499, 646, 447), Vector3(529, 747, 1130)],
				[Vector3(488, 648, 537), Vector3(551, 763, 1188)],
				[Vector3(504, 632, 622), Vector3(573, 739, 1243)],
				[Vector3(526, 635, 701), Vector3(609, 739, 1304)],
				[Vector3(538, 638, 746), Vector3(619, 735, 1362)],
			], "joined_rows": 5},
		],
	},
	"shield": {
		"texture": "res://content/gear/armor/mail/shield.webp",
		"size": Vector2(238, 374),
	},
	"shoes": {
		"texture": "res://content/gear/armor/mail/shoes.webp",
		"mesh": [
			{"leg": 0, "rows": [
				[Vector3(0, 157, 56), Vector3(112, 264, 1339)],
				[Vector3(0, 157, 117), Vector3(112, 264, 1400)],
				[Vector3(0, 157, 170), Vector3(112, 264, 1452)],
				[Vector3(0, 157, 229), Vector3(112, 264, 1511)],
			], "joined_rows": 0},
			{"leg": 1, "rows": [
				[Vector3(427, 768, 57), Vector3(612, 875, 1338)],
				[Vector3(427, 768, 116), Vector3(612, 875, 1395)],
				[Vector3(427, 768, 166), Vector3(612, 875, 1443)],
				[Vector3(427, 768, 223), Vector3(612, 875, 1497)],
			], "joined_rows": 0},
		],
	},
}
