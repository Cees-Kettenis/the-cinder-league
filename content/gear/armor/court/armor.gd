extends RefCounted

const Rig = preload("res://game/combat/fighter_rig.gd")
# Item IDs are saved in loadouts. Armor values here are separate from sprite placement below.
const ITEMS := [
	{"id": "court_helmet", "name": "Court helmet", "kind": "armor", "level": 7, "price": 51, "minimum": 8, "slot": "helmet", "armor": 11, "tier": 2, "order": 9},
	{"id": "court_chest", "name": "Court chest plate", "kind": "armor", "level": 7, "price": 58, "minimum": 8, "slot": "chest", "armor": 14, "tier": 2, "order": 13},
	{"id": "court_pants", "name": "Court pants", "kind": "armor", "level": 7, "price": 51, "minimum": 8, "slot": "pants", "armor": 11, "tier": 2, "order": 17},
	{"id": "court_shoes", "name": "Court shoes", "kind": "armor", "level": 7, "price": 47, "minimum": 8, "slot": "shoes", "armor": 10, "tier": 2, "order": 21},
	{"id": "court_shield", "name": "Court shield", "kind": "armor", "level": 7, "price": 54, "minimum": 8, "slot": "shield", "armor": 12, "tier": 2, "order": 25},
]

const PARTS := {
	"chest": {
		"texture": "res://content/gear/armor/court/chest.webp",
		"sleeve_tint": Color(.12, .26, .9),
		"offset": Vector2(-213.333, -292.667),
		"size": Vector2(374.667, 407.333),
		# Map the sleeve and plate textures onto shoulder, elbow, and wrist joints.
		"weapon_arm": [
			{"joint": Rig.WEAPON_SHOULDER, "texture": "res://content/gear/armor/court/upper-arm.webp",
				"fit": Transform2D(Vector2(0.164614, -0.007216), Vector2(0.024002, 0.104535), Vector2(53.672667, -711.388667))},
			{"joint": Rig.WEAPON_ELBOW, "texture": "res://content/gear/armor/court/forearm.webp",
				"fit": Transform2D(Vector2(0.187365, -0.045244), Vector2(-0.045867, 0.257596), Vector2(79.674000, -679.568667))},
			{"joint": Rig.WEAPON_WRIST, "texture": "res://content/gear/armor/court/gauntlet.webp",
				"fit": Transform2D(Vector2(0.135417, 0), Vector2(0, 0.169474), Vector2(175.666667, -642.666667))},
		],
	},
	"helmet": {
		"texture": "res://content/gear/armor/court/helmet.webp",
		"offset": Vector2(-115.333, -169.333),
		"size": Vector2(237.333, 217.333),
		"closed": true,
	},
	"pants": {
		"texture": "res://content/gear/armor/court/pants.webp",
		# Sections map armor pixel rows onto the leg pose so the armor bends with the fighter.
		"mesh": [
			{"leg": 0, "rows": [
				[Vector3(247, 383, 2), Vector3(286, 484, 796)],
				[Vector3(228, 383, 63), Vector3(267, 484, 846)],
				[Vector3(190, 383, 122), Vector3(263, 484, 894)],
				[Vector3(160, 383, 181), Vector3(250, 484, 932)],
				[Vector3(150, 383, 228), Vector3(231, 484, 974)],
				[Vector3(123, 340, 292), Vector3(223, 453, 1022)],
				[Vector3(104, 282, 362), Vector3(191, 414, 1075)],
				[Vector3(70, 231, 443), Vector3(161, 378, 1130)],
				[Vector3(27, 199, 534), Vector3(153, 353, 1188)],
				[Vector3(21, 142, 620), Vector3(146, 318, 1243)],
				[Vector3(4, 101, 701), Vector3(140, 258, 1304)],
				[Vector3(57, 88, 765), Vector3(138, 245, 1362)],
			], "joined_rows": 5},
			{"leg": 1, "rows": [
				[Vector3(383, 505, 2), Vector3(484, 687, 796)],
				[Vector3(383, 527, 63), Vector3(484, 711, 846)],
				[Vector3(383, 578, 122), Vector3(484, 714, 894)],
				[Vector3(383, 597, 181), Vector3(484, 724, 932)],
				[Vector3(383, 610, 228), Vector3(484, 737, 974)],
				[Vector3(412, 630, 292), Vector3(503, 748, 1022)],
				[Vector3(445, 630, 362), Vector3(535, 745, 1075)],
				[Vector3(483, 641, 443), Vector3(529, 747, 1130)],
				[Vector3(476, 651, 534), Vector3(551, 763, 1188)],
				[Vector3(511, 632, 620), Vector3(573, 739, 1243)],
				[Vector3(535, 630, 701), Vector3(609, 739, 1304)],
				[Vector3(547, 586, 765), Vector3(619, 735, 1362)],
			], "joined_rows": 5},
		],
	},
	"shield": {
		"texture": "res://content/gear/armor/court/shield.webp",
		"size": Vector2(275, 374),
	},
	"shoes": {
		"texture": "res://content/gear/armor/court/shoes.webp",
		"mesh": [
			{"leg": 0, "rows": [
				[Vector3(0, 138, 1), Vector3(112, 264, 1285)],
				[Vector3(0, 138, 53), Vector3(112, 264, 1339)],
				[Vector3(0, 138, 111), Vector3(112, 264, 1400)],
				[Vector3(0, 138, 160), Vector3(112, 264, 1452)],
				[Vector3(0, 138, 216), Vector3(112, 264, 1511)],
			], "joined_rows": 0},
			{"leg": 1, "rows": [
				[Vector3(441, 768, 12), Vector3(612, 875, 1288)],
				[Vector3(441, 768, 61), Vector3(612, 875, 1338)],
				[Vector3(441, 768, 116), Vector3(612, 875, 1395)],
				[Vector3(441, 768, 163), Vector3(612, 875, 1443)],
				[Vector3(441, 768, 216), Vector3(612, 875, 1497)],
			], "joined_rows": 0},
		],
	},
}
