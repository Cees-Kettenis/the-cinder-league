extends RefCounted
## Animates the painted base sprite with a joint hierarchy and a weighted 2D mesh.

class Pose:
	var pelvis := 0.0
	var spine := 0.0
	var neck := 0.0
	var head := 0.0
	# Each chain stores rotations relative to its parent joint.
	var weapon_arm := Vector3.ZERO
	var off_arm := Vector3.ZERO
	var rear_leg := Vector3.ZERO
	var lead_leg := Vector3.ZERO
	var rigid_feet := false

enum {PELVIS, SPINE, NECK, HEAD, WEAPON_SHOULDER, WEAPON_ELBOW, WEAPON_WRIST,
	OFF_SHOULDER, OFF_ELBOW, OFF_WRIST, REAR_HIP, REAR_KNEE, REAR_ANKLE, LEAD_HIP, LEAD_KNEE, LEAD_ANKLE}

const SPRITE_PATH := "res://game/combat/rig/gladiator-base.png"
const ORIGIN := Vector2(-341, -1024)
const PIXEL_SCALE := 2.0 / 3.0
const GRIP := Vector2(855, 649)
const HIPS := [Vector2(362, 935), Vector2(592, 932)]
const KNEES := [Vector2(259, 1127), Vector2(648, 1122)]
const ANKLES := [Vector2(179, 1362), Vector2(679, 1359)]
const PIVOTS := [
	Vector2(493, 709), Vector2(493, 675), Vector2(490, 311), Vector2(494, 251),
	Vector2(672, 462), Vector2(665, 575), Vector2(801, 642),
	Vector2(285, 368), Vector2(211, 560), Vector2(178, 766),
	HIPS[0], KNEES[0], ANKLES[0], HIPS[1], KNEES[1], ANKLES[1],
]
const PARENTS := [-1, PELVIS, SPINE, NECK, SPINE, WEAPON_SHOULDER, WEAPON_ELBOW,
	SPINE, OFF_SHOULDER, OFF_ELBOW, PELVIS, REAR_HIP, REAR_KNEE, PELVIS, LEAD_HIP, LEAD_KNEE]
const SKIN_TINTS := [Color.WHITE, Color(1.12, 1.09, 1.08), Color("#d2ad94"), Color("#a57862")]
const HAIR_TINTS := [Color.WHITE, Color(1.23, .86, .65), Color(.95, 1.05, 1.25)]
const ROW_HEIGHT := 24
const BOOT_REPLACEMENT_LINE := 1368
const NECK_CUT := Vector2(482, 264)
const ARM_CUT := Vector2(665, 552)
const ARM_END := 744
enum SkinPart { WHOLE, BODY, HEAD_ONLY, WITHOUT_ARM, ARM_ONLY }
# These cuts run through the spaces between the arms and the coat.
const OFF_ARM_CUT := [
	Vector2(365, 0), Vector2(365, 480), Vector2(334, 521), Vector2(303, 544), Vector2(300, 624),
	Vector2(275, 720), Vector2(270, 816), Vector2(269, 848), Vector2(264, 867), Vector2(258, 880),
	Vector2(245, 900),
]
const WEAPON_ARM_CUT := [
	Vector2(662, 0), Vector2(662, 472), Vector2(633, 531), Vector2(611, 577), Vector2(610, 592),
	Vector2(621, 610), Vector2(627, 637), Vector2(657, 672), Vector2(711, 704), Vector2(759, 740),
]

# Build and cache the mesh on first draw so headless balance tools can use joint constants without importing textures.
static var _sprite: Texture2D
static var _points := PackedVector2Array()
static var _uv := PackedVector2Array()
static var _indices := PackedInt32Array()
static var _head_indices := PackedInt32Array()
static var _body_indices := PackedInt32Array()
static var _arm_indices := PackedInt32Array()
static var _without_arm_indices := PackedInt32Array()
static var _bindings := PackedVector3Array()
static var _rigid_feet_bindings := PackedVector3Array()
static var _tint_weights := PackedVector2Array()
static var _starter_shoe_vertices := PackedInt32Array()
static var _tunic_hem_vertices := PackedInt32Array()
static var _covered_head_vertices := PackedInt32Array()
static var _weapon_arm_vertices := PackedInt32Array()
static var _palettes: Dictionary = {}

## Convert a point in the base sprite's source pixels to fighter-local coordinates with the feet near the origin.
static func local(point: Vector2) -> Vector2:
	return ORIGIN + point * PIXEL_SCALE

static func transforms(pose: Pose) -> Array[Transform2D]:
	var angles := [pose.pelvis, pose.spine, pose.neck, pose.head,
		pose.weapon_arm.x, pose.weapon_arm.y, pose.weapon_arm.z, pose.off_arm.x, pose.off_arm.y, pose.off_arm.z,
		pose.rear_leg.x, pose.rear_leg.y, pose.rear_leg.z, pose.lead_leg.x, pose.lead_leg.y, pose.lead_leg.z]
	var bones: Array[Transform2D] = []
	for bone in PIVOTS.size():
		var pivot := local(PIVOTS[bone])
		var angle: float = angles[bone]
		# Rotate around the painted joint position before composing with its parent.
		var joint := Transform2D(angle, pivot - pivot.rotated(angle))
		bones.append(joint if PARENTS[bone] < 0 else bones[PARENTS[bone]] * joint)
	return bones

static func walk_leg(side: int, offset: Vector2, foot_angle: float) -> Vector3:
	var thigh: Vector2 = KNEES[side] - HIPS[side]
	var calf: Vector2 = ANKLES[side] - KNEES[side]
	var target: Vector2 = ANKLES[side] - HIPS[side] + offset
	var longest := thigh.length() + calf.length() - 1.0
	# Shorten an overlong stride horizontally so the planted foot stays at floor level.
	var horizontal_room := sqrt(maxf(0.0, longest * longest - target.y * target.y))
	target.x = clampf(target.x, -horizontal_room, horizontal_room)
	return _solve_chain(thigh, calf, target, foot_angle)

static func aim_weapon_arm(wrist: Vector2, weapon_angle: float) -> Vector3:
	var shoulder: Vector2 = PIVOTS[WEAPON_SHOULDER]
	var elbow: Vector2 = PIVOTS[WEAPON_ELBOW]
	return _solve_chain(elbow - shoulder, PIVOTS[WEAPON_WRIST] - elbow, wrist - shoulder, weapon_angle)

# Solve two joints toward the target while preserving the painted bend direction.
# The last rotation makes the wrist or foot land at the requested angle.
static func _solve_chain(upper: Vector2, lower: Vector2, target: Vector2, end_angle: float) -> Vector3:
	var length_a := upper.length()
	var length_b := lower.length()
	var reach := clampf(target.length(), absf(length_a - length_b) + 1.0, length_a + length_b - 1.0)
	var bend := signf(upper.angle_to(lower))
	var first := target.angle() - bend * acos(clampf(
		(length_a * length_a + reach * reach - length_b * length_b) / (2.0 * length_a * reach), -1.0, 1.0)) - upper.angle()
	var second := bend * acos(clampf(
		(reach * reach - length_a * length_a - length_b * length_b) / (2.0 * length_a * length_b), -1.0, 1.0)) - upper.angle_to(lower)
	return Vector3(first, second, end_angle - first - second)

static func draw_skin(canvas: CanvasItem, bones: Array[Transform2D], skin: int, hair: int,
		firm_weapon_arm: bool = false, part: SkinPart = SkinPart.WHOLE, tint: Color = Color.WHITE,
		wearing_boots: bool = false, wearing_pants: bool = false, closed_helmet: bool = false,
		sleeve_tint: Color = Color.WHITE, rigid_feet: bool = false) -> void:
	if _points.is_empty():
		_build_mesh()
	var vertices := PackedVector2Array()
	vertices.resize(_points.size())
	var weapon_turns := PackedFloat32Array()
	if firm_weapon_arm:
		for bone in [WEAPON_SHOULDER, WEAPON_ELBOW, WEAPON_WRIST]:
			weapon_turns.append(angle_difference(bones[PARENTS[bone]].get_rotation(), bones[bone].get_rotation()))
	var bindings := _rigid_feet_bindings if rigid_feet else _bindings
	for index in _points.size():
		var point := _points[index]
		var binding := bindings[index]
		var joint := int(binding.y)
		if firm_weapon_arm and binding.z > 0.0 and binding.z < 1.0 and joint >= WEAPON_SHOULDER and joint <= WEAPON_WRIST:
			# Rotate blended vertices around the hinge so the bend doesn't pinch the painted arm.
			var pivot := local(PIVOTS[joint])
			point = pivot + (point - pivot).rotated(weapon_turns[joint - WEAPON_SHOULDER] * binding.z)
			vertices[index] = bones[int(binding.x)] * point
		else:
			vertices[index] = _deform(point, binding, bones)
	var indices := _indices
	match part:
		SkinPart.BODY: indices = _body_indices
		SkinPart.HEAD_ONLY: indices = _head_indices
		SkinPart.WITHOUT_ARM: indices = _without_arm_indices
		SkinPart.ARM_ONLY: indices = _arm_indices
	var colors := _colors(skin, hair)
	if tint != Color.WHITE or wearing_boots or wearing_pants or closed_helmet or sleeve_tint != Color.WHITE:
		colors = colors.duplicate()
	if sleeve_tint != Color.WHITE:
		for index in _weapon_arm_vertices:
			# Dark fitted padding remains visible between the articulated plates.
			colors[index] = sleeve_tint
	if tint != Color.WHITE:
		for index in colors.size():
			colors[index] *= tint
	if wearing_boots:
		for index in _starter_shoe_vertices:
			colors[index] = Color(colors[index], 0.0)
	if wearing_pants:
		for index in _tunic_hem_vertices:
			colors[index] = Color(colors[index], 0.0)
	if closed_helmet:
		for index in _covered_head_vertices:
			colors[index] = Color(colors[index], 0.0)
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), indices, vertices, colors, _uv,
		PackedInt32Array(), PackedFloat32Array(), _sprite.get_rid())

static func bend_armor(point: Vector2, bones: Array[Transform2D], side: int, rigid_feet: bool = false) -> Vector2:
	var source := (point - ORIGIN) / PIXEL_SCALE
	var binding := _leg_binding(source, side)
	return _deform(point, _rigid_foot_binding(source.y, binding) if rigid_feet else binding, bones)

static func _rigid_foot_binding(source_y: float, binding: Vector3) -> Vector3:
	var ankle := int(binding.y)
	if ankle == REAR_ANKLE or ankle == LEAD_ANKLE:
		# Blend across the lower shin and leave the shape of the shoe attached to the ankle.
		var y: float = PIVOTS[ankle].y
		return Vector3(binding.x, binding.y, smoothstep(y - 72.0, y, source_y))
	return binding

static func _deform(point: Vector2, binding: Vector3, bones: Array[Transform2D]) -> Vector2:
	var first := bones[int(binding.x)] * point
	if binding.z <= 0.0:
		return first
	return first.lerp(bones[int(binding.y)] * point, binding.z)

static func _build_mesh() -> void:
	_sprite = load(SPRITE_PATH)
	var extent := _sprite.get_size()
	var image := _sprite.get_image()
	var rows := floori(extent.y / ROW_HEIGHT) + 1
	for strip in 3:
		var columns: int = [12, 19, 12][strip]
		var first_vertex := _points.size()
		for row in rows:
			var y := float(row * ROW_HEIGHT)
			var edges := [0.0, _cut_at(OFF_ARM_CUT, y), _cut_at(WEAPON_ARM_CUT, y), extent.x]
			for column in columns:
				var pixel := Vector2(lerpf(edges[strip], edges[strip + 1], float(column) / (columns - 1)), y)
				var binding := _skin_binding(pixel, strip, edges)
				if strip == 2 and y >= 480 and y < ARM_END:
					_weapon_arm_vertices.append(_points.size())
				if y >= BOOT_REPLACEMENT_LINE:
					_starter_shoe_vertices.append(_points.size())
				# The tunic flares sooner on the weapon side. Leave the off hand intact.
				var hem_top := 792.0 if pixel.x >= 630.0 else 840.0
				if y >= hem_top and y <= 960 and (strip != 0 or y >= 912):
					_tunic_hem_vertices.append(_points.size())
				_points.append(local(pixel))
				_uv.append(pixel / extent)
				_bindings.append(binding)
				_rigid_feet_bindings.append(_rigid_foot_binding(y, binding))
				# Color sampling is baked into the cached mesh for skin and hair tinting.
				var color := image.get_pixel(mini(int(pixel.x), image.get_width() - 1), mini(int(pixel.y), image.get_height() - 1))
				# Hide the head and trailing hair, preserving the neck and shirt under a closed helmet.
				if (y <= 264 or y <= 336 and pixel.x < 450) and color.r > color.b + .03:
					_covered_head_vertices.append(_points.size())
				_tint_weights.append(_tint_at(pixel, color, binding))
		for row in rows - 1:
			for column in columns - 1:
				var corner := first_vertex + row * columns + column
				var triangles := PackedInt32Array([corner, corner + 1, corner + columns,
					corner + 1, corner + columns + 1, corner + columns])
				_indices.append_array(triangles)
				if row * ROW_HEIGHT < NECK_CUT.y:
					_head_indices.append_array(triangles)
				else:
					_body_indices.append_array(triangles)
				if strip == 2 and row * ROW_HEIGHT >= ARM_CUT.y and row * ROW_HEIGHT < ARM_END:
					_arm_indices.append_array(triangles)
				else:
					_without_arm_indices.append_array(triangles)

static func _cut_at(cut: Array, y: float) -> float:
	for index in range(1, cut.size()):
		var end: Vector2 = cut[index]
		if y <= end.y:
			var start: Vector2 = cut[index - 1]
			return lerpf(start.x, end.x, inverse_lerp(start.y, end.y, y))
	return cut.back().x

static func _skin_binding(point: Vector2, strip: int, edges: Array) -> Vector3:
	var y := point.y
	var x := point.x
	if y < 298:
		return Vector3(HEAD, NECK, smoothstep(245.0, 298.0, y))
	if y < 358:
		return Vector3(NECK, SPINE, smoothstep(298.0, 352.0, y))
	if strip == 0 and y < 912:
		if y < 554:
			var shoulder := maxf(smoothstep(0.0, 68.0, edges[1] - x), smoothstep(529.0, 554.0, y))
			var blend := smoothstep(356.0, 469.0, y) * shoulder
			return Vector3(SPINE, OFF_SHOULDER, blend)
		if y < 635:
			return Vector3(OFF_SHOULDER, OFF_ELBOW, smoothstep(554.0, 620.0, y))
		return Vector3(OFF_ELBOW, OFF_WRIST, smoothstep(722.0, 808.0, y))
	if strip == 2 and y < 746:
		if y < 585 and x < 705:
			var shoulder := maxf(smoothstep(0.0, 55.0, x - edges[2]), smoothstep(548.0, 585.0, y))
			return Vector3(SPINE, WEAPON_SHOULDER, smoothstep(412.0, 495.0, y) * shoulder)
		if x < 741:
			var elbow_progress := (point - PIVOTS[WEAPON_ELBOW]).dot(Vector2(.65, .76))
			return Vector3(WEAPON_SHOULDER, WEAPON_ELBOW, smoothstep(-12.0, 67.0, elbow_progress))
		return Vector3(WEAPON_ELBOW, WEAPON_WRIST, smoothstep(762.0, 832.0, x))
	if y < 827:
		return Vector3(SPINE, PELVIS, smoothstep(638.0, 789.0, y))
	return _leg_binding(point, int(x >= 485.0))

static func _leg_binding(point: Vector2, side: int) -> Vector3:
	var hip_bone := REAR_HIP if side == 0 else LEAD_HIP
	var knee: Vector2 = KNEES[side]
	var ankle: Vector2 = ANKLES[side]
	if point.y < 1010:
		return Vector3(PELVIS, hip_bone, smoothstep(890.0, 1010.0, point.y))
	if point.y < 1250:
		return Vector3(hip_bone, hip_bone + 1, smoothstep(knee.y - 58.0, knee.y + 62.0, point.y))
	return Vector3(hip_bone + 1, hip_bone + 2, smoothstep(ankle.y - 45.0, ankle.y + 50.0, point.y))

static func _tint_at(point: Vector2, color: Color, binding: Vector3) -> Vector2:
	# Warm pixels in these regions are skin or hair. The blue shirt and brown trousers use their original colors.
	var warm := smoothstep(.03, .18, color.r - color.b) * smoothstep(.01, .13, color.a)
	var head := point.y < 332.0
	var arm := binding.y in [OFF_SHOULDER, OFF_ELBOW, OFF_WRIST, WEAPON_SHOULDER, WEAPON_ELBOW, WEAPON_WRIST]
	var hair := warm * (1.0 - smoothstep(.27, .40, color.g)) if head else 0.0
	var skin := warm * smoothstep(.30, .48, color.g) if head or arm else 0.0
	return Vector2(skin, hair)

static func _colors(skin: int, hair: int) -> PackedColorArray:
	var key := Vector2i(skin, hair)
	if not _palettes.has(key):
		var colors := PackedColorArray()
		for weight in _tint_weights:
			colors.append(Color.WHITE.lerp(SKIN_TINTS[skin], weight.x).lerp(HAIR_TINTS[hair], weight.y))
		_palettes[key] = colors
	return _palettes[key]
