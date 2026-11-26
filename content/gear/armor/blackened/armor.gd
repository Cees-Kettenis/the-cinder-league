extends RefCounted

const Rig = preload("res://game/combat/fighter_rig.gd")
# This set joins the seeded pool of rival looks at this player level. Armor stats come from the rival loadout.
const RIVAL_LEVEL := 7
const RIVAL_ORDER := 3

const PARTS := {
	"chest": {
		"texture": "res://content/gear/armor/blackened/chest.webp",
		"sleeve_tint": Color(.22, .14, .13),
		"offset": Vector2(-212.000, -291.333),
		"size": Vector2(375.333, 403.333),
		# Map the sleeve and plate textures onto shoulder, elbow, and wrist joints.
		"weapon_arm": [
			{"joint": Rig.WEAPON_SHOULDER, "texture": "res://content/gear/armor/blackened/upper-arm.webp",
				"fit": Transform2D(Vector2(0.165187, -0.004587), Vector2(0.019690, 0.105174), Vector2(57.558667, -711.313333))},
			{"joint": Rig.WEAPON_ELBOW, "texture": "res://content/gear/armor/blackened/forearm.webp",
				"fit": Transform2D(Vector2(0.190782, -0.044229), Vector2(-0.048989, 0.263995), Vector2(77.248667, -672.746667))},
			{"joint": Rig.WEAPON_WRIST, "texture": "res://content/gear/armor/blackened/gauntlet.webp",
				"fit": Transform2D(Vector2(0.135417, 0), Vector2(0, 0.154562), Vector2(175.666667, -642.666667))},
		],
	},
	"helmet": {
		"texture": "res://content/gear/armor/blackened/helmet.webp",
		"offset": Vector2(-114.000, -186.000),
		"size": Vector2(239.333, 235.333),
		"closed": true,
	},
	"pants": {
		"texture": "res://content/gear/armor/blackened/pants.webp",
		# Sections map armor pixel rows onto the leg pose so the armor bends with the fighter.
		"mesh": [
			{"leg": 0, "rows": [
				[Vector3(231, 370, 8), Vector3(286, 484, 796)],
				[Vector3(200, 370, 62), Vector3(267, 484, 846)],
				[Vector3(164, 370, 126), Vector3(263, 484, 894)],
				[Vector3(136, 370, 191), Vector3(250, 484, 932)],
				[Vector3(110, 370, 245), Vector3(231, 484, 974)],
				[Vector3(128, 344, 311), Vector3(223, 453, 1022)],
				[Vector3(122, 302, 377), Vector3(191, 414, 1075)],
				[Vector3(75, 268, 449), Vector3(161, 378, 1130)],
				[Vector3(36, 224, 526), Vector3(153, 353, 1188)],
				[Vector3(28, 177, 606), Vector3(146, 318, 1243)],
				[Vector3(1, 135, 685), Vector3(140, 258, 1304)],
				[Vector3(27, 94, 754), Vector3(138, 245, 1362)],
			], "joined_rows": 5},
			{"leg": 1, "rows": [
				[Vector3(370, 493, 8), Vector3(484, 687, 796)],
				[Vector3(370, 539, 62), Vector3(484, 711, 846)],
				[Vector3(370, 572, 126), Vector3(484, 714, 894)],
				[Vector3(370, 596, 191), Vector3(484, 724, 932)],
				[Vector3(370, 607, 245), Vector3(484, 737, 974)],
				[Vector3(394, 601, 311), Vector3(503, 748, 1022)],
				[Vector3(427, 617, 377), Vector3(535, 745, 1075)],
				[Vector3(448, 608, 449), Vector3(529, 747, 1130)],
				[Vector3(430, 610, 526), Vector3(551, 763, 1188)],
				[Vector3(451, 601, 606), Vector3(573, 739, 1243)],
				[Vector3(487, 607, 685), Vector3(609, 739, 1304)],
				[Vector3(515, 599, 754), Vector3(619, 735, 1362)],
			], "joined_rows": 5},
		],
	},
	"shield": {
		"texture": "res://content/gear/armor/blackened/shield.webp",
		"size": Vector2(263, 374),
	},
	"shoes": {
		"texture": "res://content/gear/armor/blackened/shoes.webp",
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
