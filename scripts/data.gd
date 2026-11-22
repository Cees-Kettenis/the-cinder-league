extends RefCounted

const STATS: Array[String] = ["Attack", "Strength", "Defence", "Magic", "Vitality", "Stamina", "Charisma"]
const SLOTS: Array[String] = ["helmet", "chest", "pants", "shoes", "shield"]
const DEFAULT_FILE = "res://balance.json"
const GIVEN_NAMES := ["Ari", "Bram", "Cleo", "Dara", "Ember", "Finn", "Iona", "Jory", "Lark", "Mara", "Niall", "Quinn", "Rook", "Sera", "Tess", "Wren"]
const FAMILY_NAMES := ["Ash", "Briar", "Copper", "Dale", "Fen", "Flint", "Holt", "Reed", "Rowan", "Slate", "Thorn", "Vale"]
const STAT_PATTERNS := {
	"weapon": ["Strength", "Vitality", "Stamina", "Attack", "Defence"],
	"brute": ["Strength", "Strength", "Vitality", "Defence", "Stamina", "Attack"],
	"guard": ["Defence", "Vitality", "Strength", "Defence", "Stamina", "Attack"],
	"mage": ["Magic", "Strength", "Attack", "Vitality", "Stamina", "Defence", "Magic", "Strength", "Attack", "Magic"],
	"skirmish": ["Stamina", "Strength", "Attack", "Vitality", "Defence", "Magic"],
	"charisma": ["Charisma", "Charisma", "Stamina", "Vitality", "Defence"],
	"hybrid": ["Magic", "Strength", "Stamina", "Defence", "Vitality", "Attack"],
	"all_attack": ["Attack"],
}

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
	for key in ["spell_close_penalty", "crit_power_cap", "opponent_point_variance", "capped_gold_multiplier",
			"power_hit_penalty", "power_damage_multiplier",
			"power_stamina_extra", "power_strength_per_space", "quick_hit_bonus", "quick_damage_multiplier", "quick_stamina_multiplier"]:
		if not profile.rules.has(key):
			profile.rules[key] = reference.rules[key]
	for section in ["rules", "moves", "distances"]:
		for key in reference[section]:
			if not profile[section].has(key) or typeof(profile[section][key]) != typeof(reference[section][key]):
				return "Missing or invalid balance field: %s.%s" % [section, key]
			if profile[section][key] is float and profile[section][key] < 0:
				return "Balance values must be non-negative: %s.%s" % [section, key]
	rules = profile.rules
	moves = profile.moves
	distances = profile.distances
	if rules.arena_caps != reference.rules.arena_caps or profile.arenas.size() != reference.arenas.size() or rules.xp_levels.size() != max_level():
		return "Keep the bundled arena gates and provide an XP threshold for each level through %d." % int(reference.rules.arena_caps.back())
	var previous_xp := -1
	for xp in rules.xp_levels:
		if not xp is float or xp <= previous_xp:
			return "XP thresholds must be increasing numbers."
		previous_xp = int(xp)
	if rules.base_health < 1 or rules.base_energy < 1 or rules.arena_size < 5 or rules.turn_limit < 2 or rules.minimum_hit > rules.maximum_hit:
		return "Check starting resources, arena size, turn limit, and hit chance limits."
	if moves.sleep != 0 or rules.base_rest < 1:
		return "Sleep must be free and restore at least 1 stamina."
	if rules.crit_power_cap < 1 or rules.maximum_hit > 1 or rules.spell_close_penalty > 1:
		return "Check the critical multiplier cap and hit probabilities."
	if (rules.power_hit_penalty <= 0 or rules.power_hit_penalty > 1 or rules.power_damage_multiplier <= 1
			or rules.power_stamina_extra < 1 or rules.power_strength_per_space < 1):
		return "Power attacks need an accuracy penalty, extra damage and stamina cost, and a positive Strength threshold."
	if (rules.quick_hit_bonus <= 0 or rules.quick_hit_bonus > 1 or rules.quick_damage_multiplier <= 0
			or rules.quick_damage_multiplier >= 1 or rules.quick_stamina_multiplier <= 0 or rules.quick_stamina_multiplier > 1):
		return "Quick attacks need an accuracy bonus, reduced damage, and a stamina multiplier between 0 and 1."
	if rules.opponent_point_variance > 0.25:
		return "Opponent point variance must be 0.25 or less."
	if rules.capped_gold_multiplier > 1:
		return "Capped bout gold must be between 0 and 1 times the usual reward."
	for move in ["advance", "retreat", "jump"]:
		if distances[move] < 1 or distances[move] != floor(distances[move]):
			return "Movement distances must be positive whole numbers."
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
		if reference_item.id == "dagger" and not items.has("dagger"):
			var dagger: Dictionary = reference_item.duplicate()
			items.dagger = dagger
			profile.items.push_front(dagger)
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
		if not arena.has("opponent_gear_level"):
			arena.opponent_gear_level = reference.arenas[index].opponent_gear_level
		for field in reference.arenas[index]:
			if not arena.has(field) or typeof(arena[field]) != typeof(reference.arenas[index][field]):
				return "Missing or invalid arena field: " + field
		for field in ["opponents", "tournament"]:
			if arena[field].is_empty():
				return "Every arena needs regular and tournament opponents."
			for fighter in arena[field]:
				if not fighter is Dictionary or not fighter.get("name") is String or not fighter.get("style") is String:
					return "Every opponent needs a name and style."
				if fighter.has("armor_level") and (not fighter.armor_level is float or fighter.armor_level < 1 or fighter.armor_level != floor(fighter.armor_level)):
					return "Opponent armor level must be a positive whole number."
				if fighter.has("point_multiplier") and (not fighter.point_multiplier is float or fighter.point_multiplier <= 0):
					return "Opponent point multiplier must be positive."
		if arena.cap != rules.arena_caps[index] or arena.xp <= 0 or arena.gold < 0 or arena.opponent_gear_level < 1:
			return "An arena has invalid progression or rewards."
	return ""

func max_level() -> int:
	return int(rules.arena_caps.back())

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

func build_stats(style: String, points: int, offset: int = 0) -> Dictionary:
	var stats := stats_empty()
	var pattern: Array = STAT_PATTERNS.get(style, STAT_PATTERNS.weapon)
	for index in points:
		stats[pattern[(offset + index) % pattern.size()]] += 1
	return stats

func eligible_loadout(level: int, stats: Dictionary, style: String, armor_level: int = -1) -> Dictionary:
	var loadout := {"weapon": rules.starter_weapon, "armor": {}, "spell": "", "potion": false, "enchant": ""}
	for item in items.values():
		if item.kind == "armor" and armor_level >= 0 and item.level > armor_level:
			continue
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

func generate_opponent(player_level: int, arena: int, seed_value: int, round_index: int = -1) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var venue: Dictionary = arenas[arena]
	var level := int(venue.cap)
	if round_index >= 0:
		var definition: Dictionary = venue.tournament[round_index]
		var boss: bool = definition.get("boss", false)
		var entrant := opponent(definition, level, arena, null if boss else random)
		entrant.look = rival_look(str(definition.name).hash() if boss else seed_value)
		if boss:
			entrant.look.chest = 0 if arena == 0 else 2
			entrant.look.helmet = entrant.look.chest
		return entrant
	var level_floor := 1 if arena == 0 else int(arenas[arena - 1].cap) + 1
	var candidates: Array = venue.opponents
	var style: Dictionary = candidates[random.randi_range(0, candidates.size() - 1)].duplicate()
	var given: String = GIVEN_NAMES[random.randi_range(0, GIVEN_NAMES.size() - 1)]
	var family: String = FAMILY_NAMES[random.randi_range(0, FAMILY_NAMES.size() - 1)]
	style.name = given + " " + family
	# Most rivals are peers. The opening bout uses the player's exact level.
	if player_level > level_floor and random.randf() < .45:
		player_level += -1 if random.randf() < .5 else 1
	level = clampi(player_level, level_floor, level)
	var rival := opponent(style, level, arena, random)
	rival.look = rival_look(seed_value)
	return rival

static func rival_look(seed_value: int) -> Dictionary:
	# Keep the cosmetic draws independent of the stat and gear draws.
	var outfit := RandomNumberGenerator.new()
	outfit.seed = seed_value ^ 0x74c163bd
	return {"chest": outfit.randi_range(0, 2), "helmet": outfit.randi_range(-1, 2),
		"palette": outfit.randi_range(0, 4), "build": outfit.randi_range(90, 117)}

func opponent(definition: Dictionary, level: int, arena: int, random: RandomNumberGenerator = null) -> Dictionary:
	var scaling: float = rules.encounter_scaling
	if definition.get("boss", false):
		scaling += rules.boss_scaling_bonus
	var budget: float = rules.starting_points * rules.encounter_creation_factor + (level - 1) * rules.points_per_level * scaling
	var point_multiplier := float(definition.get("point_multiplier", 1.0))
	if random != null:
		var variance := float(rules.opponent_point_variance)
		point_multiplier *= random.randf_range(1.0 - variance, 1.0 + variance)
	var points := roundi(budget * point_multiplier)
	var stats: Dictionary
	if random == null:
		stats = build_stats(definition.style, points)
	else:
		var pattern: Array = STAT_PATTERNS.get(definition.style, STAT_PATTERNS.weapon)
		var varied := roundi(points * .25)
		stats = build_stats(definition.style, points - varied, random.randi_range(0, pattern.size() - 1))
		for index in varied:
			stats[pattern[random.randi_range(0, pattern.size() - 1)]] += 1
	var loadout := eligible_loadout(level, stats, definition.style, int(definition.get("armor_level", -1)))
	if level == 1 and not definition.get("boss", false):
		loadout.weapon = rules.starter_weapon
	if level < arenas[arena].opponent_gear_level and not definition.get("boss", false):
		loadout.armor = {}
		loadout.potion = false
	var rival := fighter(definition.name, stats, loadout, definition.style)
	rival.level = level
	rival.skin = random.randi_range(0, 3) if random != null else clampi(int(definition.get("skin", 0)), 0, 3)
	rival.hair = random.randi_range(0, 2) if random != null else clampi(int(definition.get("hair", 0)), 0, 2)
	return rival
