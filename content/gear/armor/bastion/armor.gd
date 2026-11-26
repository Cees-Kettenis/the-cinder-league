extends RefCounted

const Rig = preload("res://game/combat/fighter_rig.gd")
# Item IDs are saved in loadouts. Armor values here are separate from sprite placement below.
const ITEMS := [
	{"id": "bastion_helmet", "name": "Suncrest helmet", "kind": "armor", "slot": "helmet", "level": 13, "price": 85, "minimum": 14, "armor": 16, "tier": 4, "order": 44},
	{"id": "bastion_pants", "name": "Suncrest pants", "kind": "armor", "slot": "pants", "level": 13, "price": 85, "minimum": 14, "armor": 16, "tier": 4, "order": 45},
	{"id": "bastion_chest", "name": "Suncrest chest plate", "kind": "armor", "slot": "chest", "level": 14, "price": 102, "minimum": 15, "armor": 21, "tier": 4, "order": 46},
	{"id": "bastion_shield", "name": "Suncrest shield", "kind": "armor", "slot": "shield", "level": 14, "price": 92, "minimum": 15, "armor": 18, "tier": 4, "order": 47},
	{"id": "bastion_shoes", "name": "Suncrest boots", "kind": "armor", "slot": "shoes", "level": 15, "price": 80, "minimum": 15, "armor": 15, "tier": 4, "order": 48},
]

const PARTS := {
	"chest": {
		"texture": "res://content/gear/armor/bastion/chest.webp",
		"sleeve_tint": Color(.22, .20, .17),
		"offset": Vector2(-212.000, -291.333),
		"size": Vector2(375.333, 403.333),
		# Map the sleeve and plate textures onto shoulder, elbow, and wrist joints.
		"weapon_arm": [
			{"joint": Rig.WEAPON_SHOULDER, "texture": "res://content/gear/armor/bastion/upper-arm.webp",
				"fit": Transform2D(Vector2(0.165187, -0.004587), Vector2(0.019690, 0.105174), Vector2(57.558667, -711.313333))},
			{"joint": Rig.WEAPON_ELBOW, "texture": "res://content/gear/armor/bastion/forearm.webp",
				"fit": Transform2D(Vector2(0.190782, -0.044229), Vector2(-0.048989, 0.263995), Vector2(77.248667, -672.746667))},
			{"joint": Rig.WEAPON_WRIST, "texture": "res://content/gear/armor/bastion/gauntlet.webp",
				"fit": Transform2D(Vector2(0.135417, 0), Vector2(0, 0.154562), Vector2(175.666667, -642.666667))},
		],
	},
	"helmet": {
		"texture": "res://content/gear/armor/bastion/helmet.webp",
		"offset": Vector2(-116.000, -194.000),
		"size": Vector2(239.333, 243.333),
		"closed": true,
	},
	"pants": {
		"texture": "res://content/gear/armor/bastion/pants.webp",
		# Sections map armor pixel rows onto the leg pose so the armor bends with the fighter.
		"mesh": [
			{"leg": 0, "rows": [
				[Vector3(223, 375, 7), Vector3(286, 484, 796)],
				[Vector3(219, 375, 62), Vector3(267, 484, 846)],
				[Vector3(171, 375, 126), Vector3(263, 484, 894)],
				[Vector3(149, 375, 191), Vector3(250, 484, 932)],
				[Vector3(143, 377, 245), Vector3(231, 484, 974)],
				[Vector3(111, 343, 311), Vector3(223, 453, 1022)],
				[Vector3(122, 303, 377), Vector3(191, 414, 1075)],
				[Vector3(88, 249, 449), Vector3(161, 378, 1130)],
				[Vector3(29, 222, 526), Vector3(153, 353, 1188)],
				[Vector3(28, 167, 606), Vector3(146, 318, 1243)],
				[Vector3(6, 119, 685), Vector3(140, 258, 1304)],
				[Vector3(21, 90, 755), Vector3(138, 245, 1362)],
			], "joined_rows": 5},
			{"leg": 1, "rows": [
				[Vector3(375, 538, 7), Vector3(484, 687, 796)],
				[Vector3(375, 548, 62), Vector3(484, 711, 846)],
				[Vector3(375, 592, 126), Vector3(484, 714, 894)],
				[Vector3(375, 613, 191), Vector3(484, 724, 932)],
				[Vector3(377, 612, 245), Vector3(484, 737, 974)],
				[Vector3(400, 620, 311), Vector3(503, 748, 1022)],
				[Vector3(432, 617, 377), Vector3(535, 745, 1075)],
				[Vector3(446, 615, 449), Vector3(529, 747, 1130)],
				[Vector3(441, 623, 526), Vector3(551, 763, 1188)],
				[Vector3(461, 613, 606), Vector3(573, 739, 1243)],
				[Vector3(493, 614, 685), Vector3(609, 739, 1304)],
				[Vector3(514, 603, 755), Vector3(619, 735, 1362)],
			], "joined_rows": 5},
		],
	},
	"shield": {
		"texture": "res://content/gear/armor/bastion/shield.webp",
		"size": Vector2(263, 374),
	},
	"shoes": {
		"texture": "res://content/gear/armor/bastion/shoes.webp",
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
