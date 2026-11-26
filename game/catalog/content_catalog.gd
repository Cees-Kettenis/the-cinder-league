extends RefCounted
## Combines the arena and gear definitions with the shared balance rules.

const BALANCE_PATH := "res://content/balance.json"
const ARENA_DIR := "res://content/arenas"
const ARMOR_DIR := "res://content/gear/armor"
const WEAPON_DIR := "res://content/gear/weapons"

static var _arena_definitions: Array[Dictionary] = []
static var _armor_definitions: Dictionary = {}
static var _weapon_definitions: Dictionary = {}
static var _rival_levels: Dictionary = {}
static var _profile: Dictionary = {}

## Return a separate copy for the game or simulator to validate and edit.
static func bundled_profile() -> Dictionary:
	if not _profile.is_empty():
		return _profile.duplicate(true)
	var base = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
	var arenas := _arenas()
	if not base is Dictionary or arenas.is_empty():
		return {}
	base.arenas = []
	base.rules.arena_caps = []
	base.rules.xp_levels = []
	for entry in arenas:
		base.arenas.append(entry.balance)
		base.rules.arena_caps.append(entry.balance.cap)
		base.rules.xp_levels.append_array(entry.xp_levels)
	_load_armor()
	for definition in _armor_definitions.values():
		base.items.append_array(definition.get("ITEMS", []).duplicate(true))
	for definition in _weapons().values():
		base.items.append(definition.ITEM.duplicate(true))
	# Preserve the existing order when automatic loadouts compare equally ranked items.
	base.items.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_order: int = int(left.get("order", 9999))
		var right_order: int = int(right.get("order", 9999))
		return str(left.id) < str(right.id) if left_order == right_order else left_order < right_order)
	for item in base.items:
		item.erase("order")
	# Bundled content and externally edited profiles share JSON's numeric types.
	_profile = JSON.parse_string(JSON.stringify(base, "", false))
	return _profile.duplicate(true)

static func arena(index: int) -> Dictionary:
	var entries := _arenas()
	return entries[index] if index >= 0 and index < entries.size() else {}

static func armor_parts(family: String) -> Dictionary:
	_load_armor()
	return _armor_definitions.get(family, {}).get("PARTS", {})

static func weapon_art(id: String, rival: bool = false) -> Dictionary:
	return _weapons().get(id, {}).get("RIVAL" if rival else "PLAYER", {})

static func rival_armor_levels() -> Dictionary:
	_load_armor()
	return _rival_levels.duplicate()

static func _arenas() -> Array[Dictionary]:
	if not _arena_definitions.is_empty():
		return _arena_definitions
	var entries: Array[Dictionary] = []
	for folder in DirAccess.get_directories_at(ARENA_DIR):
		var directory := ARENA_DIR.path_join(folder)
		var entry = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("arena.json")))
		if (not entry is Dictionary or not entry.has_all(["order", "xp_levels", "balance"])
				or not entry.order is float or not entry.xp_levels is Array or not entry.balance is Dictionary):
			push_error("Invalid arena definition: " + directory.path_join("arena.json"))
			return []
		# Each arena folder uses the same asset names, so its manifest can omit resource paths.
		entry.id = folder
		entry.backdrop = directory.path_join("backdrop")
		entry.music = directory.path_join("fight.ogg")
		entries.append(entry)
	# Saves store the arena's position and tournament seeds depend on it. Append new arenas.
	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return left.order < right.order)
	for index in entries.size():
		if entries[index].order != index:
			push_error("Arena definitions must have consecutive, unique order values starting at 0.")
			return []
	_arena_definitions = entries
	return _arena_definitions

static func _load_armor() -> void:
	if not _armor_definitions.is_empty():
		return
	_armor_definitions = _load_definitions(ARMOR_DIR, "armor.gd")
	var rivals: Array[String] = []
	for family in _armor_definitions:
		if _armor_definitions[family].has("RIVAL_LEVEL"):
			rivals.append(family)
	# The seeded outfit roll favors the later sets in this order.
	rivals.sort_custom(func(left: String, right: String) -> bool:
		return _armor_definitions[left].RIVAL_ORDER < _armor_definitions[right].RIVAL_ORDER)
	for family in rivals:
		_rival_levels[family] = _armor_definitions[family].RIVAL_LEVEL

static func _weapons() -> Dictionary:
	if _weapon_definitions.is_empty():
		_weapon_definitions = _load_definitions(WEAPON_DIR, "weapon.gd")
	return _weapon_definitions

static func _load_definitions(directory: String, filename: String) -> Dictionary:
	var definitions := {}
	for folder in DirAccess.get_directories_at(directory):
		var path := directory.path_join(folder).path_join(filename)
		# File names use hyphens. Loadouts and saves use the original underscore item IDs.
		var id := folder.replace("-", "_")
		if definitions.has(id):
			push_error("Duplicate gear folder ID: " + path)
			return {}
		var definition: Script = load(path)
		if definition != null:
			definitions[id] = definition.get_script_constant_map()
	return definitions
