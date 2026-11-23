extends RefCounted

const WEAPON_ACTIONS: Array[String] = ["quick", "attack", "power", "lunge"]
const SPELL_ACTIONS: Array[String] = ["cast", "cast_reserve"]
const MOVEMENT: Array[String] = ["advance", "retreat", "jump", "jump_back"]
const ACTIONS: Array[String] = MOVEMENT + WEAPON_ACTIONS + SPELL_ACTIONS + ["guard", "sleep", "taunt", "potion"]
const LABELS := {
	"advance": "Advance", "retreat": "Retreat", "jump": "Leap forward", "attack": "Attack",
	"jump_back": "Leap back",
	"quick": "Quick attack", "power": "Power attack", "lunge": "Lunge", "rush": "Lunge",
	"guard": "Guard", "sleep": "Sleep", "taunt": "Taunt", "cast": "Cast", "cast_reserve": "Cast reserve spell", "potion": "Drink potion",
}

var rules: Dictionary
var moves: Dictionary
var distances: Dictionary
var fighters: Array
var positions: Array[int]
var opening_distance: int
var seed_value: int
var random := RandomNumberGenerator.new()
var strategy_random := RandomNumberGenerator.new()
var turn := 0
var active := 0
var winner := -2
var regular_bout: bool
var first_blood: bool
var defender_wins_ties := false
var history: Array[Dictionary] = []
var _restoring_history := false

func _init(rules_data: RefCounted, left: Dictionary, right: Dictionary, fight_seed: int, opening: int = -1, saved_rules: Dictionary = {}) -> void:
	rules = saved_rules.get("rules", rules_data.rules)
	moves = saved_rules.get("moves", rules_data.moves)
	distances = saved_rules.get("distances", rules_data.distances)
	first_blood = saved_rules.get("first_blood", false)
	regular_bout = saved_rules.get("regular_bout", first_blood)
	fighters = [left.duplicate(true), right.duplicate(true)]
	seed_value = fight_seed
	random.seed = seed_value
	var size := int(rules.arena_size)
	opening_distance = clampi(int(rules.starting_distance) if opening < 0 else opening, 1, size)
	var edge := int((size - opening_distance) * .5)
	positions = [edge, edge + opening_distance]

func distance() -> int:
	return positions[1] - positions[0]

static func stamina_move_bonus(rule: Dictionary, stamina: int, leap: bool = false) -> int:
	var threshold := "stamina_per_extra_leap_space" if leap else "stamina_per_extra_space"
	return mini(int(rule.get("max_stamina_move_bonus", 0)), floori(stamina / float(rule.get(threshold, 1))))

static func lunge_range(rule: Dictionary, stamina: int) -> int:
	return int(rule.get("lunge_max_spaces", 2)) + stamina_move_bonus(rule, stamina)

func travel(action: String) -> int:
	var steps := int(distances["jump" if action == "jump_back" else action])
	steps += stamina_move_bonus(rules, int(fighters[active].stats.Stamina), action in ["jump", "jump_back"])
	if action in ["retreat", "jump_back"]:
		var room := positions[0] if active == 0 else int(rules.arena_size) - positions[1]
		return mini(steps, room)
	return mini(steps, distance() - 1)

static func hit_chance(rule: Dictionary, stats: Dictionary, spell: bool, exposed: bool = false, threatened: bool = false) -> float:
	var hit := float(rule.base_hit + stats.Attack * rule.hit_per_attack)
	if spell:
		hit = float(rule.spell_hit + stats.Magic * rule.hit_per_magic)
	hit = clampf(hit, rule.minimum_hit, rule.maximum_hit)
	if spell and threatened:
		hit -= rule.spell_close_penalty
	if exposed:
		hit += rule.sleep_vulnerability
	return clampf(hit, rule.minimum_hit, rule.maximum_hit)

static func block_chance(rule: Dictionary, defence: float, guarding: bool = false) -> float:
	return clampf(rule.base_block + defence * rule.block_per_defence + (rule.guard_block if guarding else 0.0), 0.0, rule.block_cap)

static func crit_chance(rule: Dictionary, attack: float) -> float:
	return minf(rule.crit_chance_cap, rule.base_crit + attack * rule.crit_per_attack)

static func crit_multiplier(rule: Dictionary, attack: float) -> float:
	return minf(rule.crit_power_cap, rule.crit_power + attack * rule.crit_power_per_attack)

static func spell_resistance(rule: Dictionary, magic: float) -> float:
	return magic * float(rule.get("spell_resistance_per_magic", 0.0))

static func spell_for_action(fighter: Dictionary, action: String) -> Dictionary:
	return fighter.get("reserve_spell" if action == "cast_reserve" else "spell", {})

static func spell_charges(fighter: Dictionary, action: String) -> int:
	return int(fighter.get("reserve_casts" if action == "cast_reserve" else "casts", 0))

static func strike_damage(rule: Dictionary, fighter: Dictionary, spell: bool, is_bout: bool = false, action: String = "cast") -> float:
	if spell:
		# Old fight snapshots retain their original bout-only base damage.
		var scale := float(rule.get("bout_spell_base_multiplier", 1.0)) if is_bout else 1.0
		return spell_for_action(fighter, action).damage * scale + fighter.stats.Magic * rule.damage_per_magic
	return fighter.weapon.damage + fighter.stats.Strength * rule.damage_per_strength + fighter.get("enchant_damage", 0)

static func recovery(rule: Dictionary, stamina: float) -> int:
	return roundi(rule.base_rest + stamina * rule.rest_per_stamina)

static func regeneration(rule: Dictionary, vitality: float) -> int:
	return roundi(vitality * rule.regen_per_vitality)

static func taunt_chance(rule: Dictionary, charisma: float) -> float:
	return clampf(rule.taunt_provoke + charisma * rule.taunt_provoke_per_charisma, 0.0, rule.taunt_provoke_cap)

static func taunt_damage(rule: Dictionary, charisma: float) -> int:
	return roundi(rule.taunt_base_damage + charisma * rule.taunt_per_charisma)

func cost(action: String, side: int = -1) -> int:
	var fighter: Dictionary = fighters[active if side < 0 else side]
	match action:
		"attack": return int(fighter.weapon.energy)
		"quick": return _quick_cost(fighter)
		"power": return int(fighter.weapon.energy) + ceili(rules.get("power_stamina_extra", 0.0))
		"lunge", "rush":
			# The old action ID is only used to reconstruct recorded turns.
			if action == "rush" and not rules.has("lunge_base_cost"):
				return int(fighter.weapon.energy) + int(moves.jump)
			var extra: float = rules.get("lunge_base_cost", 7.0) + lunge_spaces(side) * rules.get("lunge_cost_per_space", 5.0)
			return int(fighter.weapon.energy) + ceili(extra)
		"cast", "cast_reserve": return int(spell_for_action(fighter, action).get("energy", 0))
		"jump_back": return int(moves.jump)
	return int(moves.get(action, 0))

func _quick_cost(fighter: Dictionary) -> int:
	return maxi(1, ceili(fighter.weapon.energy * rules.get("quick_stamina_multiplier", 1.0)))

func in_weapon_reach() -> bool:
	return distance() <= fighters[active].weapon.reach

func lunge_spaces(side: int = -1) -> int:
	var fighter: Dictionary = fighters[active if side < 0 else side]
	return maxi(0, distance() - int(fighter.weapon.reach))

func in_lunge_range() -> bool:
	if fighters[active].weapon.reach < 1 or in_weapon_reach():
		return false
	# Older snapshots required the gap itself to shrink before a lunge.
	if not rules.has("stamina_per_extra_space") and distance() >= opening_distance:
		return false
	var opening_left := int((int(rules.arena_size) - opening_distance) * .5)
	if positions[0] == opening_left and positions[1] == opening_left + opening_distance:
		return false
	return lunge_spaces() <= lunge_range(rules, int(fighters[active].stats.Stamina))

func has_attack_styles() -> bool:
	return rules.has("power_damage_multiplier")

func power_push() -> int:
	var push := 1 + floori(fighters[active].stats.Strength / float(rules.power_strength_per_space))
	return mini(push, _edge_distance()) if regular_bout else push

func _edge_distance() -> int:
	return int(rules.arena_size) - positions[1] if active == 0 else positions[0]

func restore_history(actions: Array) -> bool:
	_restoring_history = true
	var valid := true
	for action in actions:
		if not act(action).valid:
			valid = false
			break
	_restoring_history = false
	return valid

func chance(action: String) -> float:
	var fighter: Dictionary = fighters[active]
	var target: Dictionary = fighters[1 - active]
	var accuracy := hit_chance(rules, fighter.stats, action in SPELL_ACTIONS, target.exposed, threatens_cast(target))
	match action:
		"lunge":
			var extra := maxi(0, lunge_spaces() - int(rules.get("lunge_max_spaces", 2)))
			var penalty: float = rules.get("lunge_hit_penalty", .20) + extra * rules.get("lunge_hit_penalty_per_extra_space", 0.0)
			return maxf(0.0, accuracy - penalty)
		"rush": return maxf(0.0, accuracy - float(rules.get("lunge_hit_penalty", 0.0)))
		"power": return maxf(0.0, accuracy - float(rules.get("power_hit_penalty", 0.0)))
		"quick": return minf(1.0, accuracy + float(rules.get("quick_hit_bonus", 0.0)))
	return accuracy

func threatens_cast(fighter: Dictionary) -> bool:
	var stamina := int(fighter.weapon.energy)
	if has_attack_styles():
		stamina = mini(stamina, _quick_cost(fighter))
	return distance() <= fighter.weapon.reach and fighter.energy >= stamina

func spell_armor_only(target: Dictionary) -> bool:
	return (first_blood and rules.get("bout_ranged_spells_armor_only", false)
		and distance() > int(target.weapon.reach))

func yield_health(target: Dictionary) -> int:
	if not regular_bout or first_blood:
		return 0
	var boundary := int(target.max_hp) * int(rules.bout_yield_health_percent)
	return clampi(ceili(boundary / 100.0) - 1, 0, int(target.max_hp) - 1)

func health_damage(action: String, damage: int, target: Dictionary) -> int:
	if action in SPELL_ACTIONS and spell_armor_only(target):
		return 0
	var hp := int(target.hp)
	var threshold := yield_health(target)
	var remaining := int(first_blood or threshold > 0)
	if (regular_bout and not first_blood and hp == int(target.max_hp) and distance() > int(target.weapon.reach)
			and (action in SPELL_ACTIONS or action == "taunt")):
		remaining = threshold + 1
	return mini(maxi(0, hp - remaining), maxi(0, damage - int(target.armor)))

func health_hit_wins(target: Dictionary, loss: int) -> bool:
	return loss > 0 if first_blood else int(target.hp) - loss <= yield_health(target)

func _spell_reason(action: String, fighter: Dictionary, target: Dictionary) -> String:
	var spell := spell_for_action(fighter, action)
	if spell.is_empty():
		return "Equip a spell"
	if spell_charges(fighter, action) <= 0:
		return "Spell uses spent"
	if distance() > spell.reach:
		return "Out of spell range"
	if spell_armor_only(target) and target.armor <= 0:
		return "Get within the rival's weapon reach to draw first blood"
	return ""

func reason(action: String, ignore_provoke: bool = false) -> String:
	if winner != -2:
		return "Bout finished"
	if action not in ACTIONS and not (_restoring_history and action == "rush"):
		return "Unknown action"
	if action in ["quick", "power"] and not has_attack_styles():
		return "Unavailable in this saved bout"
	var fighter: Dictionary = fighters[active]
	if not ignore_provoke and fighter.provoked:
		var demanded := "attack" if reason("attack", true).is_empty() else "advance"
		if not reason(demanded, true).is_empty():
			demanded = "sleep"
		if action != demanded:
			return "Provoked. Choose %s." % LABELS[demanded]
	match action:
		"quick", "attack", "power":
			if not in_weapon_reach():
				return "Out of weapon reach"
		"lunge":
			if in_weapon_reach():
				return "Use Attack at this distance"
			if not in_lunge_range():
				return "Too far to lunge"
		"rush":
			if in_weapon_reach():
				return "Use Attack at this distance"
			if fighter.weapon.reach < 1 or (not rules.has("lunge_base_cost") and distance() > fighter.weapon.reach + distances.jump):
				return "Too far to lunge"
		"cast", "cast_reserve":
			var blocked := _spell_reason(action, fighter, fighters[1 - active])
			if not blocked.is_empty():
				return blocked
		"taunt":
			if fighter.energy < rules.taunt_minimum:
				return "Needs %d current stamina" % rules.taunt_minimum
		"advance", "jump":
			if distance() <= 1:
				return "Already face to face"
		"retreat", "jump_back":
			if positions[active] == (0 if active == 0 else int(rules.arena_size)):
				return "At the arena edge"
		"potion":
			if regular_bout:
				return "Potions are for death matches"
			if fighter.potions <= 0:
				return "No draught available"
			if fighter.hp == fighter.max_hp:
				return "Health is full"
	var stamina_cost := cost(action)
	if fighter.energy < stamina_cost:
		return "Needs %d stamina" % stamina_cost
	return ""

func must_sleep() -> bool:
	if not reason("sleep").is_empty():
		return false
	for action in ACTIONS:
		if action != "sleep" and reason(action).is_empty():
			return false
	return true

func act(action: String) -> Dictionary:
	var blocked := reason(action)
	if not blocked.is_empty():
		return {"valid": false, "message": blocked}
	var side := active
	var fighter: Dictionary = fighters[side]
	var enemy: Dictionary = fighters[1 - side]
	var spell_action := action in SPELL_ACTIONS
	var title: String = spell_for_action(fighter, action).name if spell_action else LABELS[action]
	var event := {"valid": true, "side": side, "action": action, "title": title, "damage": 0, "armor_hit": 0,
		"critical": false, "blocked": false, "miss": false, "turn": turn + 1, "energy_cost": cost(action),
		"message": "%s uses %s." % [fighter.name, title.to_lower()]}
	fighter.energy -= event.energy_cost
	fighter.guarding = false
	fighter.exposed = false
	fighter.provoked = false
	match action:
		"advance", "jump", "retreat", "jump_back":
			var toward := 1 if side == 0 else -1
			positions[side] += toward * travel(action) * (-1 if action in ["retreat", "jump_back"] else 1)
		"guard":
			fighter.guarding = true
			event.message = "%s raises their guard." % fighter.name
		"sleep":
			var before: int = fighter.energy
			fighter.energy = mini(fighter.max_energy, before + recovery(rules, fighter.stats.Stamina))
			fighter.exposed = true
			event.message = "%s recovers %d stamina and is exposed." % [fighter.name, fighter.energy - before]
		"potion":
			var before: int = fighter.hp
			fighter.hp = mini(fighter.max_hp, before + int(rules.heal))
			fighter.potions -= 1
			event.message = "%s restores %d health." % [fighter.name, fighter.hp - before]
		"quick", "attack", "power", "lunge", "rush", "cast", "cast_reserve":
			var accuracy := chance(action)
			if spell_action:
				var charges := "reserve_casts" if action == "cast_reserve" else "casts"
				fighter[charges] -= 1
				event.spell_art = int(spell_for_action(fighter, action).get("art", 0))
			elif action in ["lunge", "rush"]:
				positions[side] += (1 if side == 0 else -1) * lunge_spaces()
			_strike(action, fighter, enemy, event, accuracy)
			if action == "power" and not event.miss and not event.blocked and not _decisive_hit(enemy, event):
				_knock_back(enemy, event)
		"taunt":
			var provoke := taunt_chance(rules, fighter.stats.Charisma)
			if random.randf() < provoke:
				enemy.provoked = true
				event.message = "%s provokes %s into an aggressive move." % [fighter.name, enemy.name]
			else:
				_injure(taunt_damage(rules, fighter.stats.Charisma), enemy, event)
				event.message = "%s rattles %s. %s" % [fighter.name, enemy.name, _impact(event)]
	if _decisive_hit(enemy, event):
		winner = side
		if regular_bout and not first_blood:
			event.yield_threshold_reached = true
	else:
		fighter.hp = mini(fighter.max_hp, fighter.hp + regeneration(rules, fighter.stats.Vitality))
	turn += 1
	if winner == -2 and turn >= int(rules.turn_limit):
		var left: float = float(fighters[0].hp) / fighters[0].max_hp
		var right: float = float(fighters[1].hp) / fighters[1].max_hp
		event.message += " The bout reached its turn limit."
		if is_equal_approx(left, right):
			winner = 1 if defender_wins_ties else -1
			if defender_wins_ties:
				event.message += " The defender wins ties."
		else:
			winner = 0 if left > right else 1
	if regular_bout and winner >= 0:
		event.yielded = 1 - winner
		event.message += " %s yields." % fighters[event.yielded].name
	active = 1 - side
	event.positions = positions.duplicate()
	event.health = [fighters[0].hp, fighters[1].hp]
	event.armor = [fighters[0].armor, fighters[1].armor]
	event.energy = [fighters[0].energy, fighters[1].energy]
	history.append(event)
	return event

func _decisive_hit(enemy: Dictionary, event: Dictionary) -> bool:
	return enemy.hp <= yield_health(enemy) or event.get("first_blood", false)

func _strike(action: String, fighter: Dictionary, enemy: Dictionary, event: Dictionary, accuracy: float) -> void:
	if random.randf() >= accuracy:
		event.miss = true
		event.message = "%s misses with %s." % [fighter.name, event.title.to_lower()]
		return
	var spell := action in SPELL_ACTIONS
	var damage := action_damage(action, fighter, enemy)
	if not spell and random.randf() < crit_chance(rules, fighter.stats.Attack):
		event.critical = true
		damage *= crit_multiplier(rules, fighter.stats.Attack)
	if not enemy.exposed and random.randf() < block_chance(rules, enemy.stats.Defence, enemy.guarding):
		event.blocked = true
		damage *= rules.guard_damage_factor
	_injure(maxi(1, roundi(damage)), enemy, event)
	var marker := " Critical hit." if event.critical else ""
	if event.blocked:
		marker += " Blocked in part."
	event.message = "%s uses %s.%s %s" % [fighter.name, event.title.to_lower(), marker, _impact(event)]

func action_damage(action: String, fighter: Dictionary, target: Dictionary = {}) -> float:
	var spell := action in SPELL_ACTIONS
	var damage := strike_damage(rules, fighter, spell, regular_bout, action)
	if spell and not target.is_empty():
		return maxf(1.0, damage - spell_resistance(rules, target.stats.Magic))
	match action:
		"power": return damage * rules.power_damage_multiplier
		"quick": return damage * rules.quick_damage_multiplier
	return damage

func _knock_back(enemy: Dictionary, event: Dictionary) -> void:
	var target := 1 - active
	var steps := power_push()
	var edge := int(rules.arena_size)
	var destination := positions[target] + steps * (1 if active == 0 else -1)
	positions[target] = clampi(destination, -1, edge + 1)
	if destination < 0 or destination > edge:
		enemy.hp = 0
		event.ring_out = true
		event.message += " %s falls into the pit." % enemy.name
	elif steps > 0:
		event.message += " %s is pushed back %d." % [enemy.name, steps]

func _injure(damage: int, target: Dictionary, event: Dictionary) -> void:
	event.armor_hit = mini(damage, int(target.armor))
	event.damage = health_damage(event.action, damage, target)
	if first_blood and damage > event.armor_hit and not (event.action in SPELL_ACTIONS and spell_armor_only(target)):
		event.first_blood = true
	target.armor -= event.armor_hit
	target.hp -= event.damage

func _impact(event: Dictionary) -> String:
	return "%d health, %d armor lost." % [event.damage, event.armor_hit]

func choose(profile: String) -> String:
	var fighter: Dictionary = fighters[active]
	var enemy: Dictionary = fighters[1 - active]
	var legal: Array[String] = []
	for action in ACTIONS:
		if reason(action).is_empty():
			legal.append(action)
	if "potion" in legal and fighter.hp <= fighter.max_hp - int(rules.heal):
		return "potion"
	if profile == "charisma" and "taunt" in legal:
		return "taunt"
	var cast := _preferred_cast(fighter, enemy)
	if cast not in legal:
		cast = ""
	var enemy_cast := _preferred_cast(enemy, fighter)
	var protection: int = enemy.armor + (1 if first_blood else int(enemy.hp) - yield_health(enemy))
	if "power" in legal and not enemy.guarding:
		var finish := action_damage("attack", fighter) < protection and action_damage("power", fighter) >= protection
		if power_push() > _edge_distance() or (finish and chance("power") >= .50):
			return "power"
	if "attack" in legal:
		if not cast.is_empty():
			var melee := _expected_strike(fighter, enemy, "attack")
			var spell := _expected_strike(fighter, enemy, cast)
			var stamina_ratio := float(maxi(1, cost(cast))) / maxi(1, cost("attack"))
			if spell > melee * maxf(1.0, pow(stamina_ratio, .5)):
				return cast
		strategy_random.seed = seed_value ^ ((turn + 1) * 0x9e3779b9)
		if profile == "guard" and "guard" in legal and not enemy.exposed and strategy_random.randf() < .10:
			return "guard"
		if "quick" in legal and action_damage("quick", fighter) >= protection:
			return "quick"
		return "attack"
	if not cast.is_empty() and not _should_close(fighter, enemy, cast, enemy_cast):
		return cast
	if "quick" in legal:
		return "quick"
	if regular_bout and "guard" in legal and _can_guard_against_cast(fighter, enemy, enemy_cast):
		return "guard"
	if "lunge" in legal and not enemy.guarding:
		return "lunge"
	if "jump" in legal:
		var step_gap := distance() - travel("advance")
		var jump_gap := distance() - travel("jump")
		var close_on_caster: bool = not enemy_cast.is_empty() and jump_gap <= fighter.weapon.reach
		if "advance" not in legal or (jump_gap < step_gap and step_gap > fighter.weapon.reach
				and (jump_gap > enemy.weapon.reach or close_on_caster)):
			return "jump"
	if "advance" in legal:
		return "advance"
	if not cast.is_empty():
		return cast
	if fighter.energy == fighter.max_energy and "taunt" in legal:
		return "taunt"
	return "sleep"

func _preferred_cast(fighter: Dictionary, target: Dictionary) -> String:
	if fighter.provoked:
		return ""
	var best := ""
	var damage := -1.0
	for action in SPELL_ACTIONS:
		if not _spell_reason(action, fighter, target).is_empty() or fighter.energy < spell_for_action(fighter, action).energy:
			continue
		var expected := _expected_strike(fighter, target, action)
		if expected > damage:
			damage = expected
			best = action
	return best

func _can_guard_against_cast(fighter: Dictionary, enemy: Dictionary, cast: String) -> bool:
	if cast.is_empty() or spell_armor_only(fighter) or block_chance(rules, fighter.stats.Defence, true) <= 0.0:
		return false
	var damage := action_damage(cast, enemy, fighter)
	return (health_hit_wins(fighter, health_damage(cast, roundi(damage), fighter))
		and not health_hit_wins(fighter, health_damage(cast, maxi(1, roundi(damage * rules.guard_damage_factor)), fighter)))

func _should_close(fighter: Dictionary, enemy: Dictionary, cast: String, enemy_cast: String) -> bool:
	return (not enemy_cast.is_empty()
		and _expected_strike(enemy, fighter, enemy_cast) > _expected_strike(fighter, enemy, cast)
		and _expected_strike(fighter, enemy, "attack") > _expected_strike(enemy, fighter, "attack"))

func _expected_strike(fighter: Dictionary, enemy: Dictionary, action: String) -> float:
	var spell := action in SPELL_ACTIONS
	var damage := action_damage(action, fighter, enemy)
	if spell:
		if spell_armor_only(enemy):
			damage = minf(damage, float(enemy.armor))
	else:
		var attack: float = fighter.stats.Attack
		damage *= 1.0 + crit_chance(rules, attack) * (crit_multiplier(rules, attack) - 1.0)
	return damage * hit_chance(rules, fighter.stats, spell, enemy.exposed, threatens_cast(enemy))
