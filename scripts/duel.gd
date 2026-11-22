extends RefCounted

const ACTIONS: Array[String] = ["advance", "retreat", "jump", "quick", "attack", "power", "rush", "guard", "sleep", "taunt", "cast", "potion"]
const WEAPON_ACTIONS: Array[String] = ["quick", "attack", "power", "rush"]
const LABELS := {
	"advance": "Advance", "retreat": "Retreat", "jump": "Leap forward", "attack": "Attack",
	"quick": "Quick attack", "power": "Power attack", "rush": "Lunge",
	"guard": "Guard", "sleep": "Sleep", "taunt": "Taunt", "cast": "Cast", "potion": "Drink potion",
}

var rules: Dictionary
var moves: Dictionary
var distances: Dictionary
var fighters: Array
var positions: Array[int]
var seed_value: int
var random := RandomNumberGenerator.new()
var strategy_random := RandomNumberGenerator.new()
var turn := 0
var active := 0
var winner := -2
var defender_wins_ties := false
var history: Array[Dictionary] = []
var _restoring_history := false

func _init(rules_data: RefCounted, left: Dictionary, right: Dictionary, fight_seed: int, opening: int = -1, saved_rules: Dictionary = {}) -> void:
	rules = saved_rules.get("rules", rules_data.rules)
	moves = saved_rules.get("moves", rules_data.moves)
	distances = saved_rules.get("distances", rules_data.distances)
	fighters = [left.duplicate(true), right.duplicate(true)]
	seed_value = fight_seed
	random.seed = seed_value
	var size := int(rules.arena_size)
	var start := clampi(int(rules.starting_distance) if opening < 0 else opening, 1, size)
	var edge := int((size - start) * .5)
	positions = [edge, edge + start]

func distance() -> int:
	return positions[1] - positions[0]

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

static func strike_damage(rule: Dictionary, fighter: Dictionary, spell: bool) -> float:
	if spell:
		return fighter.spell.damage + fighter.stats.Magic * rule.damage_per_magic
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
		"rush":
			if not rules.has("lunge_base_cost"):
				var saved_cost := int(fighter.weapon.energy) + int(moves.jump)
				return saved_cost if _restoring_history else maxi(1, saved_cost)
			var spaces := maxi(0, distance() - int(fighter.weapon.reach))
			return int(fighter.weapon.energy) + ceili(rules.lunge_base_cost + spaces * rules.lunge_cost_per_space)
		"cast": return int(fighter.spell.get("energy", 0))
	return int(moves.get(action, 0))

func _quick_cost(fighter: Dictionary) -> int:
	return maxi(1, ceili(fighter.weapon.energy * rules.get("quick_stamina_multiplier", 1.0)))

func weapon_action() -> String:
	return "attack" if distance() <= fighters[active].weapon.reach else "rush"

func has_attack_styles() -> bool:
	return rules.has("power_damage_multiplier")

func power_push() -> int:
	return 1 + floori(fighters[active].stats.Strength / float(rules.power_strength_per_space))

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
	var accuracy := hit_chance(rules, fighter.stats, action == "cast", target.exposed, threatens_cast(target))
	match action:
		"rush": return maxf(0.0, accuracy - float(rules.get("lunge_hit_penalty", 0.0)))
		"power": return maxf(0.0, accuracy - float(rules.get("power_hit_penalty", 0.0)))
		"quick": return minf(1.0, accuracy + float(rules.get("quick_hit_bonus", 0.0)))
	return accuracy

func threatens_cast(fighter: Dictionary) -> bool:
	var stamina := int(fighter.weapon.energy)
	if has_attack_styles():
		stamina = mini(stamina, _quick_cost(fighter))
	return distance() <= fighter.weapon.reach and fighter.energy >= stamina

func reason(action: String, ignore_provoke: bool = false) -> String:
	if winner != -2:
		return "Bout finished"
	if action not in ACTIONS:
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
			if distance() > fighter.weapon.reach:
				return "Out of weapon reach"
		"rush":
			if distance() <= fighter.weapon.reach:
				return "Use Attack at this distance"
			if fighter.weapon.reach < 1 or (not rules.has("lunge_base_cost") and distance() > fighter.weapon.reach + distances.jump):
				return "Too far to lunge"
		"cast":
			if fighter.spell.is_empty():
				return "Equip a spell"
			if fighter.casts <= 0:
				return "Spell uses spent"
			if distance() > fighter.spell.reach:
				return "Out of spell range"
		"taunt":
			if fighter.energy < rules.taunt_minimum:
				return "Needs %d current stamina" % rules.taunt_minimum
		"advance", "jump":
			if distance() <= 1:
				return "Already face to face"
		"retreat":
			if positions[active] == (0 if active == 0 else int(rules.arena_size)):
				return "At the arena edge"
		"potion":
			if fighter.potions <= 0:
				return "No draught available"
			if fighter.hp == fighter.max_hp:
				return "Health is full"
	var stamina_cost := cost(action)
	if fighter.energy < stamina_cost:
		return "Needs %d stamina" % stamina_cost
	return ""

func act(action: String) -> Dictionary:
	var blocked := reason(action)
	if not blocked.is_empty():
		return {"valid": false, "message": blocked}
	var side := active
	var fighter: Dictionary = fighters[side]
	var enemy: Dictionary = fighters[1 - side]
	var title: String = LABELS[action] if action != "cast" else fighter.spell.name
	var event := {"valid": true, "side": side, "action": action, "title": title, "damage": 0, "armor_hit": 0,
		"critical": false, "blocked": false, "miss": false, "turn": turn + 1, "energy_cost": cost(action),
		"message": "%s uses %s." % [fighter.name, title.to_lower()]}
	fighter.energy -= event.energy_cost
	fighter.guarding = false
	fighter.exposed = false
	fighter.provoked = false
	match action:
		"advance", "jump", "retreat":
			var toward := 1 if side == 0 else -1
			var steps := int(distances[action])
			if action == "retreat":
				positions[side] = clampi(positions[side] - toward * steps, 0, int(rules.arena_size))
			else:
				positions[side] += toward * mini(steps, distance() - 1)
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
		"quick", "attack", "power", "rush", "cast":
			if action == "cast":
				fighter.casts -= 1
			elif action == "rush":
				positions[side] += (1 if side == 0 else -1) * (distance() - int(fighter.weapon.reach))
			_strike(action, fighter, enemy, event)
			if action == "power" and not event.miss and not event.blocked and enemy.hp > 0:
				_knock_back(enemy, event)
		"taunt":
			var provoke := taunt_chance(rules, fighter.stats.Charisma)
			if random.randf() < provoke:
				enemy.provoked = true
				event.message = "%s provokes %s into an aggressive move." % [fighter.name, enemy.name]
			else:
				_injure(taunt_damage(rules, fighter.stats.Charisma), enemy, event)
				event.message = "%s rattles %s. %s" % [fighter.name, enemy.name, _impact(event)]
	if enemy.hp <= 0:
		winner = side
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
	active = 1 - side
	event.positions = positions.duplicate()
	event.health = [fighters[0].hp, fighters[1].hp]
	event.armor = [fighters[0].armor, fighters[1].armor]
	event.energy = [fighters[0].energy, fighters[1].energy]
	history.append(event)
	return event

func _strike(action: String, fighter: Dictionary, enemy: Dictionary, event: Dictionary) -> void:
	if random.randf() >= chance(action):
		event.miss = true
		event.message = "%s misses with %s." % [fighter.name, event.title.to_lower()]
		return
	var spell := action == "cast"
	var damage := _action_damage(action, fighter)
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

func _action_damage(action: String, fighter: Dictionary) -> float:
	var damage := strike_damage(rules, fighter, action == "cast")
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
	else:
		event.message += " %s is pushed back %d." % [enemy.name, steps]

func _injure(damage: int, target: Dictionary, event: Dictionary) -> void:
	event.armor_hit = mini(damage, int(target.armor))
	target.armor -= event.armor_hit
	event.damage = mini(int(target.hp), damage - event.armor_hit)
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
	if "power" in legal and not enemy.guarding:
		var edge_distance := int(rules.arena_size) - positions[1] if active == 0 else positions[0]
		var protection: float = enemy.hp + enemy.armor
		var finish := _action_damage("attack", fighter) < protection and _action_damage("power", fighter) >= protection
		if power_push() > edge_distance or (finish and chance("power") >= .50):
			return "power"
	if "attack" in legal:
		if "cast" in legal:
			var melee := _expected_strike(fighter, enemy, false)
			var spell := _expected_strike(fighter, enemy, true)
			var stamina_ratio := float(maxi(1, cost("cast"))) / maxi(1, cost("attack"))
			if spell > melee * maxf(1.0, pow(stamina_ratio, .5)):
				return "cast"
		strategy_random.seed = seed_value ^ ((turn + 1) * 0x9e3779b9)
		if profile == "guard" and "guard" in legal and not enemy.exposed and strategy_random.randf() < .10:
			return "guard"
		if "quick" in legal and _action_damage("quick", fighter) >= enemy.hp + enemy.armor:
			return "quick"
		return "attack"
	if "cast" in legal and not _should_close(fighter, enemy):
		return "cast"
	if "quick" in legal:
		return "quick"
	if "rush" in legal:
		return "rush"
	if "jump" in legal and distance() > fighter.weapon.reach + int(distances.advance):
		return "jump"
	if "advance" in legal:
		return "advance"
	if "cast" in legal:
		return "cast"
	if fighter.energy == fighter.max_energy and "taunt" in legal:
		return "taunt"
	return "sleep"

func _should_close(fighter: Dictionary, enemy: Dictionary) -> bool:
	return (enemy.casts > 0 and distance() <= enemy.spell.reach
		and _expected_strike(enemy, fighter, true) > _expected_strike(fighter, enemy, true)
		and _expected_strike(fighter, enemy, false) > _expected_strike(enemy, fighter, false))

func _expected_strike(fighter: Dictionary, enemy: Dictionary, spell: bool) -> float:
	var damage := strike_damage(rules, fighter, spell)
	if not spell:
		var attack: float = fighter.stats.Attack
		damage *= 1.0 + crit_chance(rules, attack) * (crit_multiplier(rules, attack) - 1.0)
	return damage * hit_chance(rules, fighter.stats, spell, enemy.exposed, threatens_cast(enemy))
