extends RefCounted

# Item IDs are saved in loadouts. Armor values here are separate from sprite placement below.
const ITEMS := [
	{"id": "leather_helmet", "name": "Leather helmet", "kind": "armor", "level": 1, "price": 9, "minimum": 1, "slot": "helmet", "armor": 3, "tier": 0, "order": 6},
	{"id": "leather_chest", "name": "Leather chest plate", "kind": "armor", "level": 1, "price": 15, "minimum": 1, "slot": "chest", "armor": 6, "tier": 0, "order": 10},
	{"id": "leather_pants", "name": "Leather pants", "kind": "armor", "level": 1, "price": 9, "minimum": 1, "slot": "pants", "armor": 3, "tier": 0, "order": 14},
	{"id": "leather_shoes", "name": "Leather shoes", "kind": "armor", "level": 1, "price": 7, "minimum": 1, "slot": "shoes", "armor": 2, "tier": 0, "order": 18},
	{"id": "leather_shield", "name": "Wood shield", "kind": "armor", "level": 1, "price": 12, "minimum": 1, "slot": "shield", "armor": 4, "tier": 0, "order": 22},
]

const PARTS := {
	"chest": {
		"texture": "res://content/gear/armor/leather/chest.webp",
		"offset": Vector2(-208.0, -280.667),
		"size": Vector2(368.0, 394.667),
	},
	"helmet": {
		"texture": "res://content/gear/armor/leather/helmet.webp",
		"offset": Vector2(-108.667, -161.333),
		"size": Vector2(214.667, 182.000),
	},
	"pants": {
		"texture": "res://content/gear/armor/leather/pants.webp",
		# Sections map armor pixel rows onto the leg pose so the armor bends with the fighter.
		"mesh": [
			{"leg": 0, "rows": [
				[Vector3(263, 377, 3), Vector3(286, 484, 796)],
				[Vector3(224, 377, 75), Vector3(267, 484, 846)],
				[Vector3(183, 377, 145), Vector3(263, 484, 894)],
				[Vector3(169, 377, 214), Vector3(250, 484, 932)],
				[Vector3(146, 377, 270), Vector3(231, 484, 974)],
				[Vector3(133, 328, 329), Vector3(223, 453, 1022)],
				[Vector3(112, 278, 394), Vector3(191, 414, 1075)],
				[Vector3(59, 225, 468), Vector3(161, 378, 1130)],
				[Vector3(47, 195, 552), Vector3(153, 353, 1188)],
				[Vector3(22, 139, 631), Vector3(146, 318, 1243)],
				[Vector3(4, 102, 706), Vector3(140, 258, 1304)],
				[Vector3(52, 73, 765), Vector3(138, 245, 1362)],
			], "joined_rows": 5},
			{"leg": 1, "rows": [
				[Vector3(377, 498, 3), Vector3(484, 687, 796)],
				[Vector3(377, 544, 75), Vector3(484, 711, 846)],
				[Vector3(377, 581, 145), Vector3(484, 714, 894)],
				[Vector3(377, 594, 214), Vector3(484, 724, 932)],
				[Vector3(377, 606, 270), Vector3(484, 737, 974)],
				[Vector3(424, 608, 329), Vector3(503, 748, 1022)],
				[Vector3(450, 628, 394), Vector3(535, 745, 1075)],
				[Vector3(463, 623, 468), Vector3(529, 747, 1130)],
				[Vector3(471, 633, 552), Vector3(551, 763, 1188)],
				[Vector3(502, 623, 631), Vector3(573, 739, 1243)],
				[Vector3(519, 633, 706), Vector3(609, 739, 1304)],
				[Vector3(534, 615, 765), Vector3(619, 735, 1362)],
			], "joined_rows": 5},
		],
	},
	"shield": {
		"texture": "res://content/gear/armor/leather/shield.webp",
		"size": Vector2(249, 374),
	},
	"shoes": {
		"texture": "res://content/gear/armor/leather/shoes.webp",
		"mesh": [
			{"leg": 0, "rows": [
				[Vector3(0, 152, 3), Vector3(112, 264, 1285)],
				[Vector3(0, 152, 58), Vector3(112, 264, 1339)],
				[Vector3(0, 152, 121), Vector3(112, 264, 1400)],
				[Vector3(0, 152, 174), Vector3(112, 264, 1452)],
				[Vector3(0, 152, 234), Vector3(112, 264, 1511)],
			], "joined_rows": 0},
			{"leg": 1, "rows": [
				[Vector3(457, 768, 2), Vector3(612, 875, 1288)],
				[Vector3(457, 768, 57), Vector3(612, 875, 1338)],
				[Vector3(457, 768, 119), Vector3(612, 875, 1395)],
				[Vector3(457, 768, 172), Vector3(612, 875, 1443)],
				[Vector3(457, 768, 232), Vector3(612, 875, 1497)],
			], "joined_rows": 0},
		],
	},
}
