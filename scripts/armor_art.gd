extends RefCounted

const Rig = preload("res://scripts/fighter_rig.gd")
const Placements = preload("res://art/armor/placements.gd")
const ANCHORS := {
	"helmet": Rig.HEAD,
	"chest": Rig.SPINE,
	"shield": Rig.OFF_WRIST,
	"pants": Rig.PELVIS,
	"shoes": Rig.PELVIS,
}
const LEGACY_SETS := ["leather", "studded", "mail"]
const SHIELD_CENTER := Rig.ORIGIN + Vector2(196, 658) * Rig.PIXEL_SCALE

static func equipped(item: Dictionary) -> Dictionary:
	if item.is_empty():
		return {}
	var family := str(item.id).get_slice("_", 0)
	if family == "rival" or not Placements.SETS.has(family):
		family = LEGACY_SETS[clampi(int(item.get("tier", 0)), 0, LEGACY_SETS.size() - 1)]
	return Placements.SETS[family].get(item.slot, {})

static func rival_piece(slot: String, design: String) -> Dictionary:
	if design.begins_with("rival_"):
		return Placements.SETS.rival.get("%s_%s" % [slot, design.trim_prefix("rival_")], {})
	return Placements.SETS.get(design, {}).get(slot, {})

static func draw_weapon_arm(canvas: CanvasItem, chest: Dictionary, body: Transform2D,
		bones: Array[Transform2D], tint: Color, skin_part: Rig.SkinPart = Rig.SkinPart.WHOLE) -> void:
	for piece in chest.get("weapon_arm", []):
		var joint: int = piece.joint
		var texture: Texture2D = piece.texture
		var fit: Transform2D = piece.fit
		var source := Rect2(Vector2.ZERO, texture.get_size())
		if joint == Rig.WEAPON_SHOULDER and skin_part in [Rig.SkinPart.WITHOUT_ARM, Rig.SkinPart.ARM_ONLY]:
			# The upper sleeve crosses the elbow cut used by the blade finisher.
			var cut := clampf((fit.affine_inverse() * Rig.local(Rig.ARM_CUT)).y / source.size.y, 0.0, 1.0)
			if skin_part == Rig.SkinPart.WITHOUT_ARM:
				source.size.y *= cut
			else:
				source.position.y = source.size.y * cut
				source.size.y *= 1.0 - cut
		elif skin_part == Rig.SkinPart.WITHOUT_ARM:
			continue
		canvas.draw_set_transform_matrix(body * bones[joint] * fit)
		canvas.draw_texture_rect_region(texture, source, source, tint)

static func draw(canvas: CanvasItem, sprite: Dictionary, slot: String, bones: Array[Transform2D], tint: Color) -> void:
	if sprite.is_empty():
		return
	var texture: Texture2D = sprite.texture
	if not sprite.has("mesh"):
		var size: Vector2 = sprite.get("size", texture.get_size())
		if slot == "shield":
			canvas.draw_texture_rect(texture, Rect2(SHIELD_CENTER - size * .5, size), false, tint)
			return
		var origin: Vector2 = Rig.local(Rig.PIVOTS[ANCHORS[slot]]) + sprite.offset
		canvas.draw_texture_rect(texture, Rect2(origin, size), false, tint)
		return
	for part in sprite.mesh:
		_draw_leg(canvas, texture, part, bones, tint)

static func _draw_leg(canvas: CanvasItem, texture: Texture2D, part: Dictionary, bones: Array[Transform2D], tint: Color) -> void:
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	var extent := texture.get_size()
	var side: int = part.leg
	var joined_rows: int = part.get("joined_rows", 0)
	for row_index in part.rows.size():
		var source: Vector3 = part.rows[row_index][0]
		var rest: Vector3 = part.rows[row_index][1]
		for edge in 2:
			var point := Rig.local(Vector2(rest[edge], rest.z))
			# The inner edges of the waistband meet on the pelvis as the legs move apart.
			vertices.append(bones[Rig.PELVIS] * point if row_index < joined_rows and edge != side else Rig.bend_armor(point, bones, side))
			uv.append(Vector2(source[edge], source.z) / extent)
		if row_index > 0:
			var corner: int = row_index * 2
			indices.append_array([corner - 2, corner - 1, corner, corner - 1, corner + 1, corner])
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), indices, vertices,
		PackedColorArray([tint]), uv, PackedInt32Array(), PackedFloat32Array(), texture.get_rid())
