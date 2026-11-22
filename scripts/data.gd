extends RefCounted

const STATS: Array[String] = ["Attack", "Strength", "Defence", "Magic", "Vitality", "Stamina", "Charisma"]
const SLOTS: Array[String] = ["helmet", "chest", "pants", "shoes", "shield"]
const DEFAULT_FILE = "res://balance.json"

var profile: Dictionary
var rules: Dictionary
var moves: Dictionary
var distances: Dictionary
var items: Dictionary = {}
var arenas: Array

func load_profile(path: String = DEFAULT_FILE) -> String:
	if not FileAccess.file_exists(path):
		return "Balance file does not exist: " + path
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return "Balance JSON error on line %s: %s" % [json.get_error_line(), json.get_error_message()]
	if not json.data is Dictionary:
		return "Balance must be a JSON object."
	profile = json.data
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DEFAULT_FILE))
	for section in ["rules", "moves", "distances", "items", "arenas"]:
		if not profile.has(section) or typeof(profile[section]) != typeof(reference[section]):
			return "Missing or invalid balance section: " + section
	for section in ["rules", "moves", "distances"]:
		for key in reference[section]:
			if not profile[section].has(key) or typeof(profile[section][key]) != typeof(reference[section][key]):
				return "Missing or invalid balance field: %s.%s" % [section, key]
			if profile[section][key] is float and profile[section][key] < 0:
				return "Balance values must be non-negative: %s.%s" % [section, key]
	rules = profile.rules
	moves = profile.moves
	distances = profile.distances
	if rules.arena_caps != [4.0, 8.0] or profile.arenas.size() != 2 or rules.xp_levels.size() != 8:
		return "The playtest requires two arenas and level thresholds for levels 1–8."
	var previous_xp := -1
	for xp in rules.xp_levels:
		if not xp is float or xp <= previous_xp:
			return "XP thresholds must be increasing numbers."
		previous_xp = int(xp)
	if rules.base_health < 1 or rules.base_energy < 1 or rules.arena_size < 5 or rules.turn_limit < 2 or rules.minimum_hit > rules.maximum_hit:
		return "Check starting resources, arena size, turn limit, and hit chance limits."
	var item_types := {}
	for item in reference.items:
		item_types[item.kind] = item
	items.clear()
	for item in profile.items:
		if not item is Dictionary or not item_types.has(item.get("kind", "")):
			return "An item has an invalid category."
		for field in item_types[item.kind]:
			if not item.has(field) or typeof(item[field]) != typeof(item_types[item.kind][field]):
				return "Missing or invalid item field: %s / %s" % [item.get("id", "unknown"), field]
		if items.has(item.id) or item.id.is_empty() or item.price < 0 or item.minimum < 0 or item.level < 1:
			return "An item has a duplicate ID or invalid price or requirement."
		if item.kind == "armor" and (item.slot not in SLOTS or item.armor < 0):
			return "Invalid armor slot or armor points: " + item.id
		if item.kind in ["weapon", "spell"] and (item.energy < 0 or item.reach <= 0 or item.damage <= 0):
			return "Invalid cost, reach or damage: " + item.id
		if item.kind == "enchant" and item.damage < 0:
			return "Invalid enchantment damage: " + item.id
		if item.kind == "spell" and item.uses < 1:
			return "A spell needs at least one use: " + item.id
		items[item.id] = item
	for reference_item in reference.items:
		if (not items.has(reference_item.id) or items[reference_item.id].kind != reference_item.kind
				or items[reference_item.id].get("slot", "") != reference_item.get("slot", "")):
			return "Keep the original item IDs, categories, and slots to preserve existing saves."
	for slot in rules.opening_armour:
		if slot not in SLOTS or not items.has(rules.opening_armour[slot]) or items[rules.opening_armour[slot]].get("slot", "") != slot:
			return "Invalid starting armor for slot " + slot
	if not items.has(rules.starter_weapon) or items[rules.starter_weapon].kind != "weapon":
		return "A valid starter weapon is required."
	arenas = profile.arenas
	for index in arenas.size():
		var arena = arenas[index]
		if not arena is Dictionary:
			return "Arena must be an object."
		for field in reference.arenas[index]:
			if not arena.has(field) or typeof(arena[field]) != typeof(reference.arenas[index][field]):
				return "Missing or invalid arena field: " + field
		for field in ["opponents", "tournament"]:
			if arena[field].is_empty():
				return "Every arena needs regular and tournament opponents."
			for fighter in arena[field]:
				if not fighter is Dictionary or not fighter.get("name") is String or not fighter.get("style") is String:
					return "Every opponent needs a name and style."
		if arena.cap != rules.arena_caps[index] or arena.xp <= 0 or arena.gold < 0:
			return "An arena has invalid progression or rewards."
	return ""

func stats_empty() -> Dictionary:
	var stats := {}
	for stat in STATS:
		stats[stat] = 0
	return stats

func stat_requirement(item: Dictionary) -> String:
	return {"weapon": "Strength", "armor": "Defence", "spell": "Magic", "enchant": "Magic"}.get(item.kind, "")

func lock_reason(player: Dictionary, item: Dictionary) -> String:
	if player.level < item.level:
		return "Requires level %d" % item.level
	var stat := stat_requirement(item)
	if not stat.is_empty() and player.stats[stat] < item.minimum:
		return "Requires %d %s" % [item.minimum, stat]
	return ""

func item_name(id: String) -> String:
	return items.get(id, {}).get("name", "None")

func fighter(name: String, stats: Dictionary, loadout: Dictionary, style: String = "weapon") -> Dictionary:
	var weapon: Dictionary = items.get(loadout.get("weapon", ""), items[rules.starter_weapon])
	var spell: Dictionary = items.get(loadout.get("spell", ""), {})
	var protection := 0
	for id in loadout.get("armor", {}).values():
		protection += int(items.get(id, {}).get("armor", 0))
	var health := int(rules.base_health + stats.Vitality * rules.health_per_vitality)
	var energy := int(rules.base_energy + stats.Stamina * rules.energy_per_stamina)
	return {
		"name": name, "stats": stats.duplicate(), "loadout": loadout.duplicate(true), "style": style,
		"hp": health, "max_hp": health, "armor": protection, "max_armor": protection,
		"energy": energy, "max_energy": energy, "weapon": weapon, "spell": spell,
		"casts": int(spell.get("uses", 0)),
		"enchant_damage": int(items.get(loadout.get("enchant", ""), {}).get("damage", 0)),
		"potions": int(rules.potion_uses) if loadout.get("potion", false) else 0,
		"guarding": false, "exposed": false, "provoked": false,
	}

func build_stats(style: String, points: int) -> Dictionary:
	var stats := stats_empty()
	var patterns := {
		"weapon": ["Strength", "Vitality", "Stamina", "Attack", "Defence"],
		"brute": ["Strength", "Strength", "Vitality", "Defence", "Stamina", "Attack"],
		"guard": ["Defence", "Vitality", "Strength", "Defence", "Stamina", "Attack"],
		"mage": ["Magic", "Magic", "Stamina", "Vitality", "Defence", "Magic"],
		"skirmish": ["Stamina", "Strength", "Attack", "Vitality", "Defence", "Magic"],
		"charisma": ["Charisma", "Charisma", "Stamina", "Vitality", "Defence"],
		"hybrid": ["Magic", "Strength", "Stamina", "Defence", "Vitality", "Attack"],
		"all_attack": ["Attack"],
	}
	var pattern: Array = patterns.get(style, patterns.weapon)
	for index in points:
		stats[pattern[index % pattern.size()]] += 1
	return stats

func eligible_loadout(level: int, stats: Dictionary, style: String) -> Dictionary:
	var loadout := {"weapon": rules.starter_weapon, "armor": {}, "spell": "", "potion": false, "enchant": ""}
	for item in items.values():
		if not lock_reason({"level": level, "stats": stats}, item).is_empty():
			continue
		match item.kind:
			"weapon":
				if item.damage >= items[loadout.weapon].damage:
					loadout.weapon = item.id
			"armor":
				var current: Dictionary = items.get(loadout.armor.get(item.slot, ""), {})
				if item.armor >= current.get("armor", 0):
					loadout.armor[item.slot] = item.id
			"spell":
				if style in ["mage", "hybrid", "skirmish"]:
					var current: Dictionary = items.get(loadout.spell, {})
					if item.damage >= current.get("damage", 0):
						loadout.spell = item.id
			"potion":
				loadout.potion = true
			"enchant":
				if style in ["hybrid", "skirmish", "mage"]:
					loadout.enchant = item.id
	return loadout

func opponent(definition: Dictionary, level: int, arena: int) -> Dictionary:
	var points := int(rules.starting_points * rules.encounter_creation_factor + (level - 1) * rules.points_per_level * (rules.encounter_scaling + (rules.boss_scaling_bonus if definition.get("boss", false) else 0.0)))
	var stats := build_stats(definition.style, points)
	var loadout := eligible_loadout(level, stats, definition.style)
	if arena == 0 and not definition.get("boss", false):
		loadout.armor = {}
		loadout.potion = false
	return fighter(definition.name, stats, loadout, definition.style)
