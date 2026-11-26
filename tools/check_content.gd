extends SceneTree
## Checks the assembled balance and imported asset references before desktop export.

const Data = preload("res://game/catalog/data.gd")
const Content = preload("res://game/catalog/content_catalog.gd")
const Backdrops = preload("res://game/screens/backdrop_art.gd")

var _errors: Array[String] = []

func _initialize() -> void:
	var data := Data.new()
	var problem := data.load_profile()
	if not problem.is_empty():
		printerr(problem)
		quit(1)
		return
	for index in data.arenas.size():
		var arena := Content.arena(index)
		_check_backdrops(arena.backdrop)
		_require_resource(arena.music, "AudioStream")
	_check_backdrops(Backdrops.TOWN)
	_check_backdrops(Backdrops.TITLE)
	for folder in DirAccess.get_directories_at(Content.ARMOR_DIR):
		_check_armor(folder)
	for item in data.items.values():
		if item.kind == "weapon":
			_check_weapon(item.id)
	for message in _errors:
		printerr(message)
	if _errors.is_empty():
		print("Content check passed for %d arenas and %d items." % [data.arenas.size(), data.items.size()])
	quit(0 if _errors.is_empty() else 1)

func _check_backdrops(stem: String) -> void:
	# Exercise both paths selected by the same backdrop helper the game uses.
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		_require_resource(Backdrops.texture_path(stem, size), "Texture2D")

func _check_armor(folder: String) -> void:
	var directory := Content.ARMOR_DIR.path_join(folder)
	var parts := Content.armor_parts(folder)
	if parts.is_empty():
		_errors.append("No armor parts in " + directory)
	for piece in parts.values():
		_require_resource(piece.texture, "Texture2D")
		for section in piece.get("weapon_arm", []):
			_require_resource(section.texture, "Texture2D")

func _check_weapon(id: String) -> void:
	var directory := Content.WEAPON_DIR.path_join(id.replace("_", "-"))
	for rival in [false, true]:
		var path := directory.path_join("rival.webp" if rival else "player.webp")
		var art := Content.weapon_art(id, rival)
		if art.get("texture", "") != path:
			_errors.append("Weapon %s must reference %s." % [id, path])
		elif _require_resource(path, "Texture2D"):
			var texture: Texture2D = load(path)
			# Grip and tip need distinct points in source pixels for the rival sprite to map onto the player animation.
			var bounds := Rect2(Vector2.ZERO, texture.get_size())
			if (not bounds.has_point(art.grip) or not bounds.has_point(art.tip)
					or art.grip == art.tip):
				_errors.append("Invalid grip or striking point in " + path)

func _require_resource(path: String, type: String) -> bool:
	if ResourceLoader.exists(path, type):
		return true
	_errors.append("Missing %s: %s" % [type, path])
	return false
