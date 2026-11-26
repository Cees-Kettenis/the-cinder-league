extends RefCounted

const Rig = preload("res://game/combat/fighter_rig.gd")
# Item IDs are saved in loadouts. Armor values here are separate from sprite placement below.
const ITEMS := [
	{"id": "glassguard_chest", "name": "Glassguard chest plate", "kind": "armor", "slot": "chest", "level": 10, "price": 82, "minimum": 11, "armor": 17, "tier": 3, "order": 34},
	{"id": "glassguard_shield", "name": "Glassguard shield", "kind": "armor", "slot": "shield", "level": 10, "price": 74, "minimum": 11, "armor": 15, "tier": 3, "order": 35},
	{"id": "glassguard_helmet", "name": "Glassguard helmet", "kind": "armor", "slot": "helmet", "level": 9, "price": 67, "minimum": 10, "armor": 13, "tier": 3, "order": 36},
	{"id": "glassguard_pants", "name": "Glassguard pants", "kind": "armor", "slot": "pants", "level": 9, "price": 67, "minimum": 10, "armor": 13, "tier": 3, "order": 37},
	{"id": "glassguard_shoes", "name": "Glassguard boots", "kind": "armor", "slot": "shoes", "level": 11, "price": 63, "minimum": 11, "armor": 12, "tier": 3, "order": 38},
]

const PARTS := {
	"chest": {
		"texture": "res://content/gear/armor/glassguard/chest.webp",
		"sleeve_tint": Color(.29, .125, .85),
		"offset": Vector2(-212.000, -291.333),
		"size": Vector2(375.333, 403.333),
		# Map the sleeve and plate textures onto shoulder, elbow, and wrist joints.
		"weapon_arm": [
			{"joint": Rig.WEAPON_SHOULDER, "texture": "res://content/gear/armor/glassguard/upper-arm.webp",
				"fit": Transform2D(Vector2(0.165187, -0.004587), Vector2(0.019690, 0.105174), Vector2(57.558667, -711.313333))},
			{"joint": Rig.WEAPON_ELBOW, "texture": "res://content/gear/armor/glassguard/forearm.webp",
				"fit": Transform2D(Vector2(0.190782, -0.044229), Vector2(-0.048989, 0.263995), Vector2(77.248667, -672.746667))},
			{"joint": Rig.WEAPON_WRIST, "texture": "res://content/gear/armor/glassguard/gauntlet.webp",
				"fit": Transform2D(Vector2(0.135417, 0), Vector2(0, 0.154562), Vector2(175.666667, -642.666667))},
		],
	},
	"helmet": {
		"texture": "res://content/gear/armor/glassguard/helmet.webp",
		"offset": Vector2(-114.000, -170.000),
		"size": Vector2(235.333, 219.333),
		"closed": true,
	},
	"pants": {
		"texture": "res://content/gear/armor/glassguard/pants.webp",
		# Sections map armor pixel rows onto the leg pose so the armor bends with the fighter.
		"mesh": [
			{"leg": 0, "rows": [
				[Vector3(246, 381, 2), Vector3(286, 484, 796)],
				[Vector3(229, 381, 72), Vector3(267, 484, 846)],
				[Vector3(187, 381, 139), Vector3(263, 484, 894)],
				[Vector3(169, 381, 206), Vector3(250, 484, 932)],
				[Vector3(149, 381, 260), Vector3(231, 484, 974)],
				[Vector3(126, 322, 321), Vector3(223, 453, 1022)],
				[Vector3(108, 281, 386), Vector3(191, 414, 1075)],
				[Vector3(62, 246, 462), Vector3(161, 378, 1130)],
				[Vector3(30, 204, 548), Vector3(153, 353, 1188)],
				[Vector3(25, 140, 629), Vector3(146, 318, 1243)],
				[Vector3(6, 106, 704), Vector3(140, 258, 1304)],
				[Vector3(2, 83, 746), Vector3(138, 245, 1362)],
			], "joined_rows": 5},
			{"leg": 1, "rows": [
				[Vector3(381, 530, 2), Vector3(484, 687, 796)],
				[Vector3(381, 552, 72), Vector3(484, 711, 846)],
				[Vector3(381, 576, 139), Vector3(484, 714, 894)],
				[Vector3(381, 605, 206), Vector3(484, 724, 932)],
				[Vector3(381, 605, 260), Vector3(484, 737, 974)],
				[Vector3(404, 611, 321), Vector3(503, 748, 1022)],
				[Vector3(447, 620, 386), Vector3(535, 745, 1075)],
				[Vector3(464, 615, 462), Vector3(529, 747, 1130)],
				[Vector3(443, 624, 548), Vector3(551, 763, 1188)],
				[Vector3(474, 606, 629), Vector3(573, 739, 1243)],
				[Vector3(498, 608, 704), Vector3(609, 739, 1304)],
				[Vector3(517, 611, 746), Vector3(619, 735, 1362)],
			], "joined_rows": 5},
		],
	},
	"shield": {
		"texture": "res://content/gear/armor/glassguard/shield.webp",
		"size": Vector2(253, 374),
	},
	"shoes": {
		"texture": "res://content/gear/armor/glassguard/shoes.webp",
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
