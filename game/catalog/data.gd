extends RefCounted
## Validates balance profiles and builds the fighters and loadouts used by Duel.

const STATS: Array[String] = ["Attack", "Strength", "Defence", "Magic", "Vitality", "Stamina", "Charisma"]
const SLOTS: Array[String] = ["helmet", "chest", "pants", "shoes", "shield"]
const Content = preload("res://game/catalog/content_catalog.gd")
const PREPARED_ITEM_FIELDS := ["effect", "power", "retired"]
const DEFAULT_FILE = Content.BALANCE_PATH
const GIVEN_NAMES := ["Ari", "Bram", "Cleo", "Dara", "Ember", "Finn", "Iona", "Jory", "Lark", "Mara", "Niall", "Quinn", "Rook", "Sera", "Tess", "Wren"]
const FAMILY_NAMES := ["Ash", "Briar", "Copper", "Dale", "Fen", "Flint", "Holt", "Reed", "Rowan", "Slate", "Thorn", "Vale"]
const STAT_PATTERNS := {
	"weapon": ["Strength", "Vitality", "Stamina", "Attack", "Defence"],
	"fast_melee": ["Strength", "Vitality", "Stamina", "Attack", "Defence", "Strength", "Vitality", "Stamina", "Attack", "Defence",
		"Strength", "Vitality", "Stamina", "Attack", "Defence", "Strength", "Stamina", "Stamina", "Attack", "Defence"],
	"brute": ["Strength", "Strength", "Vitality", "Defence", "Stamina", "Attack"],
	"guard": ["Defence", "Vitality", "Strength", "Defence", "Stamina", "Attack"],
	"mage": ["Magic", "Strength", "Attack", "Vitality", "Stamina", "Defence", "Magic", "Strength", "Defence", "Magic"],
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

## Load the assembled defaults or normalize an older override before validating it.
## Callers apply the candidate profile once this returns an empty error string.
func load_profile(path: String = DEFAULT_FILE) -> String:
	var bundled := Content.bundled_profile()
	if bundled.is_empty():
		return "Bundled balance content could not be loaded."
	if path == DEFAULT_FILE or path == ProjectSettings.globalize_path(DEFAULT_FILE):
		profile = bundled.duplicate(true)
	else:
		if not FileAccess.file_exists(path):
			return "Balance file does not exist: " + path
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) != OK:
			return "Balance JSON error on line %s: %s" % [json.get_error_line(), json.get_error_message()]
		if not json.data is Dictionary:
			return "Balance must be a JSON object."
		profile = json.data
	for section in ["rules", "moves", "distances", "items", "arenas"]:
		if not profile.has(section) or typeof(profile[section]) != typeof(bundled[section]):
			return "Missing or invalid balance section: " + section
	var legacy_magic: bool = (profile.rules.has("bout_spell_base_multiplier")
		or profile.rules.has("bout_min_spell_casts") or profile.rules.has("death_match_extra_cast_magic"))
	var old_bout_scale := clampf(float(profile.rules.get("bout_spell_base_multiplier", 0.5)), 0.0, 1.0)
	var old_bout_casts := maxi(1, int(profile.rules.get("bout_min_spell_casts", 2)))
	if profile.rules.has("death_match_extra_cast_magic") and not profile.rules.has("reserve_spell_magic"):
		profile.rules.reserve_spell_magic = profile.rules.death_match_extra_cast_magic
	profile.rules.erase("bout_spell_base_multiplier")
	profile.rules.erase("bout_min_spell_casts")
	profile.rules.erase("death_match_extra_cast_magic")
	profile.rules.erase("bout_ranged_spells_armor_only")
	# Older overrides use the same HP gain for every Vitality point.
	if not profile.rules.has("health_vitality_point_fraction"):
		profile.rules.health_vitality_point_fraction = 1.0
	if not profile.rules.has("health_per_excess_vitality"):
		profile.rules.health_per_excess_vitality = profile.rules.get("health_per_vitality", bundled.rules.health_per_vitality)
	for key in ["spell_close_penalty", "crit_power_cap", "opponent_point_variance", "capped_gold_multiplier",
			"lunge_hit_penalty", "lunge_base_cost", "lunge_cost_per_space", "lunge_max_spaces",
			"stamina_per_extra_space", "stamina_per_extra_leap_space", "max_stamina_move_bonus", "lunge_hit_penalty_per_extra_space",
			"power_hit_penalty", "power_damage_multiplier",
			"power_stamina_extra", "power_strength_per_space", "quick_hit_bonus", "quick_damage_multiplier", "quick_stamina_multiplier",
			"bout_yield_health_percent", "spell_resistance_per_magic", "magic_per_extra_cast", "reserve_spell_magic", "distance_based_spell_movement",
			"strength_damage_floor", "strength_damage_point_fraction", "damage_per_excess_strength",
			"health_potion_base", "health_potion_per_vitality", "armor_potion_fraction", "tournament_scaling_bonus"]:
		if not profile.rules.has(key):
			profile.rules[key] = bundled.rules[key]
	for section in ["rules", "moves", "distances"]:
		for key in bundled[section]:
			if not profile[section].has(key) or typeof(profile[section][key]) != typeof(bundled[section][key]):
				return "Missing or invalid balance field: %s.%s" % [section, key]
			if profile[section][key] is float and profile[section][key] < 0:
				return "Balance values must be non-negative: %s.%s" % [section, key]
	rules = profile.rules
	moves = profile.moves
	distances = profile.distances
	var arena_count: int = rules.arena_caps.size()
	if (arena_count == 0 or rules.arena_caps != bundled.rules.arena_caps.slice(0, arena_count)
			or profile.arenas.size() != arena_count or rules.xp_levels.size() != max_level()):
		return "Keep the bundled arena gates and provide an XP threshold for each level through %d." % int(bundled.rules.arena_caps.back())
	var previous_cap := max_level()
	# Extend old overrides with newly bundled arenas. Carry their last XP offset forward.
	if arena_count < bundled.arenas.size():
		var extra_xp := maxf(0.0, float(rules.xp_levels.back()) - float(bundled.rules.xp_levels[previous_cap - 1]))
		rules.arena_caps.append_array(bundled.rules.arena_caps.slice(arena_count))
		for xp in bundled.rules.xp_levels.slice(previous_cap):
			rules.xp_levels.append(xp + extra_xp)
		profile.arenas.append_array(bundled.arenas.slice(arena_count))
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
	if (rules.lunge_hit_penalty > 1 or rules.lunge_hit_penalty_per_extra_space > 1 or rules.lunge_cost_per_space < 1
			or rules.lunge_max_spaces < 1 or rules.lunge_max_spaces != floor(rules.lunge_max_spaces)):
		return "Check the lunge accuracy penalty, stamina per space, and whole-number travel limit."
	for key in ["stamina_per_extra_space", "stamina_per_extra_leap_space", "max_stamina_move_bonus"]:
		if rules[key] != floor(rules[key]) or (key != "max_stamina_move_bonus" and rules[key] < 1):
			return "Stamina movement thresholds must be positive whole numbers and bonuses must be whole numbers."
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
	if rules.strength_damage_point_fraction > 1:
		return "The Strength damage threshold can use up to all assigned points."
	if rules.health_vitality_point_fraction > 1 or rules.health_per_excess_vitality > rules.health_per_vitality:
		return "The Vitality health threshold can use up to all assigned points and excess Vitality cannot add more health per point."
	if (rules.bout_yield_health_percent < 1 or rules.bout_yield_health_percent >= 100
			or rules.bout_yield_health_percent != floor(rules.bout_yield_health_percent)):
		return "Bout yield health must be a whole percent between 1 and 99."
	if rules.armor_potion_fraction <= 0 or rules.armor_potion_fraction > 1 or rules.health_potion_base < 1:
		return "Potions must restore a positive amount. The armor fraction cannot exceed 1."
	for key in ["magic_per_extra_cast", "reserve_spell_magic"]:
		if rules[key] < 1 or rules[key] != floor(rules[key]):
			return "Magic requirements must be positive whole numbers: " + key
	for move in ["advance", "retreat", "jump"]:
		if distances[move] < 1 or distances[move] != floor(distances[move]):
			return "Movement distances must be positive whole numbers."
	var item_types := {}
	for item in bundled.items:
		item_types[item.kind] = item
	items.clear()
	for item in profile.items:
		if not item is Dictionary or not item_types.has(item.get("kind", "")):
			return "An item has an invalid category."
		for field in item_types[item.kind]:
			if field in PREPARED_ITEM_FIELDS or (item.kind == "enchant" and field == "energy"):
				continue
			if not item.has(field) or typeof(item[field]) != typeof(item_types[item.kind][field]):
				return "Missing or invalid item field: %s / %s" % [item.get("id", "unknown"), field]
		if items.has(item.id) or item.id.is_empty() or item.price < 0 or item.minimum < 0 or item.level < 1:
			return "An item has a duplicate ID or invalid price or requirement."
		if item.kind == "armor" and (item.slot not in SLOTS or item.armor < 0):
			return "Invalid armor slot or armor points: " + item.id
		if item.kind in ["weapon", "spell"] and (item.energy < 0 or item.reach < 0 or item.damage < 0
				or (item.get("effect", "damage") == "damage" and (item.reach <= 0 or item.damage <= 0))):
			return "Invalid cost, reach or damage: " + item.id
		if item.kind == "enchant" and item.damage < 0:
			return "Invalid enchantment damage: " + item.id
		if item.has("retired") and not item.retired is bool:
			return "Invalid retired flag: " + item.id
		if item.has("effect"):
			var effects := ["damage", "shield", "push", "pull"] if item.kind == "spell" else ["enchant"]
			if item.kind not in ["spell", "enchant"] or item.effect not in effects:
				return "Invalid spell effect: " + item.id
			if item.effect != "damage" and (not item.get("power") is float or item.power < 1 or item.power != floor(item.power)):
				return "Utility spells require positive whole-number power: " + item.id
		if item.has("energy") and (not item.energy is float or item.energy < 0):
			return "Invalid stamina cost: " + item.id
		if item.kind == "spell" and item.uses < 1:
			return "A spell needs at least one use: " + item.id
		if legacy_magic and item.kind == "spell" and item.get("effect", "damage") == "damage":
			# Start existing profiles from their previous regular-bout spell values.
			item.damage = maxf(1.0, roundf(item.damage * old_bout_scale))
			item.uses = maxf(item.uses, old_bout_casts)
		items[item.id] = item
	# Import gear above the old cap as arenas are added. Old item IDs and armor slots belong to save data.
	for reference_item in bundled.items:
		if (reference_item.level > previous_cap or reference_item.id in ["magic_shield", "push", "pull", "armor_potion"]) and not items.has(reference_item.id):
			items[reference_item.id] = reference_item
			profile.items.append(reference_item)
		if reference_item.id == "dagger" and not items.has("dagger"):
			var dagger: Dictionary = reference_item.duplicate()
			items.dagger = dagger
			profile.items.push_front(dagger)
		if (not items.has(reference_item.id) or items[reference_item.id].kind != reference_item.kind
				or items[reference_item.id].get("slot", "") != reference_item.get("slot", "")):
			return "Keep the original item IDs, categories, and slots to preserve existing saves."
		# Old overrides can omit the metadata that determines the effect and active shop roster.
		for field in PREPARED_ITEM_FIELDS:
			if reference_item.has(field) and not items[reference_item.id].has(field):
				items[reference_item.id][field] = reference_item[field]
		if reference_item.id == "ember_etching" and not items.ember_etching.has("energy"):
			items.ember_etching.energy = reference_item.energy
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
			arena.opponent_gear_level = bundled.arenas[index].opponent_gear_level
		for field in bundled.arenas[index]:
			if not arena.has(field) or typeof(arena[field]) != typeof(bundled.arenas[index][field]):
				return "Missing or invalid arena field: " + field
		var first_level := 1 if index == 0 else int(rules.arena_caps[index - 1]) + 1
		var has_opening_rival := false
		for field in ["opponents", "tournament"]:
			if arena[field].is_empty():
				return "Every arena needs regular and tournament opponents."
			for entry in arena[field]:
				if not entry is Dictionary or not entry.get("name") is String or not entry.get("style") is String:
					return "Every opponent needs a name and style."
				if entry.has("armor_level") and (not entry.armor_level is float or entry.armor_level < 1 or entry.armor_level != floor(entry.armor_level)):
					return "Opponent armor level must be a positive whole number."
				if entry.has("point_multiplier") and (not entry.point_multiplier is float or entry.point_multiplier <= 0):
					return "Opponent point multiplier must be positive."
				if entry.has("tactics") and not entry.tactics is String:
					return "Opponent tactics must be a style name."
				if entry.has("stats"):
					if not entry.get("boss", false) or not entry.stats is Dictionary:
						return "Only champions can have a fixed stat allocation."
					for stat in STATS:
						var value = entry.stats.get(stat)
						if not value is float or value < 0 or value != floor(value):
							return "Champion stats must be non-negative whole numbers."
				if field == "opponents":
					var minimum = entry.get("minimum_level", 1.0)
					if not minimum is float or minimum < 1 or minimum > arena.cap or minimum != floor(minimum):
						return "Regular rival minimum level must be a whole number within the campaign through that arena."
					has_opening_rival = has_opening_rival or minimum <= first_level
		if not has_opening_rival:
			return "Every arena needs a regular rival available at its first level."
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
	var missing := PackedStringArray()
	if player.level < item.level:
		missing.append("level %d" % item.level)
	var stat := stat_requirement(item)
	if not stat.is_empty() and player.stats[stat] < item.minimum:
		missing.append("%d %s" % [item.minimum, stat])
	return "" if missing.is_empty() else "Requires " + " and ".join(missing)

func item_name(id: String) -> String:
	return items.get(id, {}).get("name", "None")

func bonus_spell_casts(magic: int) -> int:
	return floori(float(magic) / float(rules.magic_per_extra_cast))

func spell_casts(spell: Dictionary, magic: int, reserve_equipped: bool = false) -> int:
	if spell.is_empty():
		return 0
	return int(spell.uses) + bonus_spell_casts(magic) - int(reserve_equipped and has_reserve_slot(magic))

func has_reserve_slot(magic: int) -> bool:
	return magic >= int(rules.reserve_spell_magic) and bonus_spell_casts(magic) > 0

func spell_slots(magic: int) -> int:
	return 2 + bonus_spell_casts(magic)

func is_prepared_spell(item: Dictionary) -> bool:
	return item.get("kind") in ["spell", "enchant"] and not item.get("retired", false)

func _spell_options(level: int, stats: Dictionary, effect: String) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for item in items.values():
		if (is_prepared_spell(item) and item.get("effect", "damage") == effect
				and lock_reason({"level": level, "stats": stats}, item).is_empty()):
			available.append(item)
	available.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return left.damage > right.damage)
	return available

## Prepare a fighter with resolved equipment and starting resources for a new bout.
func fighter(name: String, stats: Dictionary, loadout: Dictionary, style: String = "weapon") -> Dictionary:
	var weapon: Dictionary = items.get(loadout.get("weapon", ""), items[rules.starter_weapon])
	var spell: Dictionary = items.get(loadout.get("spell", ""), {})
	var reserve: Dictionary = {}
	if has_reserve_slot(int(stats.Magic)) and not spell.is_empty() and loadout.get("reserve_spell", "") != spell.id:
		reserve = items.get(loadout.get("reserve_spell", ""), {})
	var protection := 0
	for id in loadout.get("armor", {}).values():
		protection += int(items.get(id, {}).get("armor", 0))
	# The threshold grows with the fighter's point budget so leveling naturally raises it.
	var points := 0.0
	for stat in STATS:
		points += float(stats.get(stat, 0))
	var full_vitality := minf(stats.Vitality, points * rules.health_vitality_point_fraction)
	var excess_vitality: float = stats.Vitality - full_vitality
	var health := int(rules.base_health + full_vitality * rules.health_per_vitality + excess_vitality * rules.health_per_excess_vitality)
	var energy := int(rules.base_energy + stats.Stamina * rules.energy_per_stamina)
	var fighter_state := {
		"name": name, "stats": stats.duplicate(), "loadout": loadout.duplicate(true), "style": style,
		"hp": health, "max_hp": health, "armor": protection, "max_armor": protection,
		"energy": energy, "max_energy": energy, "weapon": weapon, "spell": spell,
		"casts": spell_casts(spell, int(stats.Magic), not reserve.is_empty()),
		"reserve_spell": reserve, "reserve_casts": int(not reserve.is_empty()),
		"enchant_damage": int(items.get(loadout.get("enchant", ""), {}).get("damage", 0)),
		"potions": int(rules.potion_uses) if loadout.get("potion", false) else 0,
		"guarding": false, "exposed": false, "provoked": false,
	}
	if loadout.has("spells"):
		var prepared: Array[Dictionary] = []
		for id in loadout.spells.slice(0, spell_slots(int(stats.Magic))):
			var item: Dictionary = items.get(id, {})
			prepared.append(item if is_prepared_spell(item) else {})
		fighter_state.prepared = prepared
		fighter_state.spent_slots = []
		fighter_state.magic_shield = 0
		fighter_state.enchant_hits = 0
		fighter_state.enchant_damage = 0
		fighter_state.draught = str(loadout.get("draught", ""))
		fighter_state.potions = int(not fighter_state.draught.is_empty())
	return fighter_state

func build_stats(style: String, points: int, offset: int = 0) -> Dictionary:
	var stats := stats_empty()
	var pattern: Array = STAT_PATTERNS.get(style, STAT_PATTERNS.weapon)
	for index in points:
		stats[pattern[(offset + index) % pattern.size()]] += 1
	return stats

func eligible_loadout(level: int, stats: Dictionary, style: String, armor_level: int = -1) -> Dictionary:
	var loadout := {"weapon": rules.starter_weapon, "armor": {}, "spells": [], "draught": ""}
	# Most builds trade some damage for reach. Brutes compare weapons by damage alone.
	var reach_value := 0 if style == "brute" else 7
	for item in items.values():
		if item.kind == "armor" and armor_level >= 0 and item.level > armor_level:
			continue
		if not lock_reason({"level": level, "stats": stats}, item).is_empty():
			continue
		match item.kind:
			"weapon":
				var current: Dictionary = items[loadout.weapon]
				if item.damage + item.reach * reach_value >= current.damage + current.reach * reach_value:
					loadout.weapon = item.id
			"armor":
				var current: Dictionary = items.get(loadout.armor.get(item.slot, ""), {})
				if item.armor >= current.get("armor", 0):
					loadout.armor[item.slot] = item.id
	return _prepared_loadout(loadout, level, stats, style)

func _prepared_loadout(loadout: Dictionary, level: int, stats: Dictionary, style: String) -> Dictionary:
	var mage := style in ["mage", "hybrid", "skirmish"]
	var prepared: Array[String] = []
	var damage := _spell_options(level, stats, "damage")
	if mage and not damage.is_empty():
		prepared.append(damage.pop_front().id)
		if style == "mage":
			# Leave room for control and defense when there are more damage spells than slots.
			while not damage.is_empty() and prepared.size() < spell_slots(int(stats.Magic)) - 2:
				prepared.append(damage.pop_front().id)
	for effect in (["push", "shield", "enchant", "pull"] if mage else ["enchant", "shield", "pull", "push"]):
		var utility := _spell_options(level, stats, effect)
		if not utility.is_empty():
			prepared.append(utility[0].id)
	if mage:
		for item in damage:
			prepared.append(item.id)
	loadout.spells = prepared.slice(0, spell_slots(int(stats.Magic)))
	var armor := 0
	for id in loadout.armor.values():
		armor += int(items[id].armor)
	loadout.draught = "armor_potion" if armor * rules.armor_potion_fraction > rules.health_potion_base + stats.Vitality * rules.health_potion_per_vitality else "potion"
	return loadout

func generate_opponent(player_level: int, arena: int, seed_value: int, round_index: int = -1) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var venue: Dictionary = arenas[arena]
	# Tournament opponents are built at the arena cap. Regular rivals scale around the player.
	var level := int(venue.cap)
	if round_index >= 0:
		var definition: Dictionary = venue.tournament[round_index]
		var boss: bool = definition.get("boss", false)
		var entrant := opponent(definition, level, arena, null if boss else random, true)
		entrant.look = rival_look(str(definition.name).hash() if boss else seed_value, player_level)
		return entrant
	var level_floor := 1 if arena == 0 else int(arenas[arena - 1].cap) + 1
	var candidates: Array = venue.opponents.filter(func(entry: Dictionary) -> bool:
		return int(entry.get("minimum_level", 1)) <= maxi(level_floor, player_level))
	var style: Dictionary = candidates[random.randi_range(0, candidates.size() - 1)].duplicate()
	var given: String = GIVEN_NAMES[random.randi_range(0, GIVEN_NAMES.size() - 1)]
	var family: String = FAMILY_NAMES[random.randi_range(0, FAMILY_NAMES.size() - 1)]
	style.name = given + " " + family
	# Most rivals are peers. The opening bout uses the player's exact level.
	var nearby_level := player_level
	if nearby_level > level_floor and random.randf() < .45:
		nearby_level += -1 if random.randf() < .5 else 1
	level = clampi(nearby_level, maxi(level_floor, int(style.get("minimum_level", 1))), level)
	var rival := opponent(style, level, arena, random)
	rival.look = rival_look(seed_value, player_level)
	return rival

static func rival_look(seed_value: int, player_level: int) -> Dictionary:
	# Keep the cosmetic draws independent of the stat and gear draws.
	var outfit := RandomNumberGenerator.new()
	outfit.seed = seed_value ^ 0x74c163bd
	var available := PackedStringArray()
	var levels := Content.rival_armor_levels()
	for family in levels:
		if levels[family] <= maxi(1, player_level):
			available.append(family)
	var recent := maxi(0, available.size() - 3)
	var armor := {}
	for slot in SLOTS:
		var first := recent if outfit.randf() < .7 else 0
		armor[slot] = available[outfit.randi_range(first, available.size() - 1)]
	return {
		"armor": armor,
		"palette": outfit.randi_range(0, 4), "build": outfit.randi_range(90, 117),
	}

func opponent(definition: Dictionary, level: int, arena: int, random: RandomNumberGenerator = null, tournament: bool = false) -> Dictionary:
	var scaling: float = rules.encounter_scaling
	if definition.get("boss", false):
		scaling += rules.boss_scaling_bonus
	elif tournament:
		scaling += float(rules.get("tournament_scaling_bonus", 0.0))
	var budget: float = rules.starting_points * rules.encounter_creation_factor + (level - 1) * rules.points_per_level * scaling
	var point_multiplier := float(definition.get("point_multiplier", 1.0))
	if random != null:
		var variance := float(rules.opponent_point_variance)
		point_multiplier *= random.randf_range(1.0 - variance, 1.0 + variance)
	var points := roundi(budget * point_multiplier)
	var stats: Dictionary
	if definition.has("stats"):
		stats = definition.stats.duplicate()
	elif random == null:
		stats = build_stats(definition.style, points)
	else:
		var pattern: Array = STAT_PATTERNS.get(definition.style, STAT_PATTERNS.weapon)
		var varied := roundi(points * .25)
		stats = build_stats(definition.style, points - varied, random.randi_range(0, pattern.size() - 1))
		for index in varied:
			stats[pattern[random.randi_range(0, pattern.size() - 1)]] += 1
	if definition.style == "fast_melee" and rules.max_stamina_move_bonus > 0:
		# Generated rivals have smaller point budgets than simulator presets.
		var leap_threshold := mini(int(rules.stamina_per_extra_leap_space), floori(points / 2.0))
		for stat in ["Vitality", "Attack", "Defence", "Strength"]:
			var moved := mini(int(stats[stat]), maxi(0, leap_threshold - int(stats.Stamina)))
			stats[stat] -= moved
			stats.Stamina += moved
	var loadout := eligible_loadout(level, stats, definition.style, int(definition.get("armor_level", -1)))
	if level == 1 and not definition.get("boss", false):
		loadout.weapon = rules.starter_weapon
	if level < arenas[arena].opponent_gear_level and not definition.get("boss", false):
		loadout.armor = {}
		loadout.draught = ""
	var rival := fighter(definition.name, stats, loadout, definition.get("tactics", definition.style))
	rival.level = level
	rival.skin = random.randi_range(0, 3) if random != null else clampi(int(definition.get("skin", 0)), 0, 3)
	rival.hair = random.randi_range(0, 2) if random != null else clampi(int(definition.get("hair", 0)), 0, 2)
	return rival
