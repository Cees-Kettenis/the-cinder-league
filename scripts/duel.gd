extends RefCounted

const ACTIONS: Array[String] = ["advance", "retreat", "jump", "attack", "guard", "sleep", "taunt", "cast", "potion"]
const LABELS := {
	"advance": "Advance", "retreat": "Retreat", "jump": "Leap forward", "attack": "Attack",
	"guard": "Guard", "sleep": "Sleep", "taunt": "Taunt", "cast": "Cast", "potion": "Drink potion",
}

var data: RefCounted
var fighters: Array
var positions: Array[int]
var seed_value: int
var random := RandomNumberGenerator.new()
var turn := 0
var active := 0
var winner := -2
var history: Array[Dictionary] = []

func _init(rules_data: RefCounted, left: Dictionary, right: Dictionary, fight_seed: int, opening: int = -1) -> void:
	data = rules_data
	fighters = [left.duplicate(true), right.duplicate(true)]
	seed_value = fight_seed
	random.seed = seed_value
	var size := int(data.rules.arena_size)
	var start := clampi(int(data.rules.starting_distance) if opening < 0 else opening, 1, size)
	var edge := int((size - start) * .5)
	positions = [edge, edge + start]

func distance() -> int:
	return positions[1] - positions[0]

func cost(action: String, side: int = -1) -> int:
	var fighter: Dictionary = fighters[active if side < 0 else side]
	match action:
		"attack": return int(fighter.weapon.energy)
		"cast": return int(fighter.spell.get("energy", 0))
	return int(data.moves.get(action, 0))

func chance(action: String) -> float:
	var fighter: Dictionary = fighters[active]
	var target: Dictionary = fighters[1 - active]
	var hit := float(data.rules.base_hit + fighter.stats.Attack * data.rules.hit_per_attack)
	if action == "cast":
		hit = float(data.rules.spell_hit + fighter.stats.Magic * data.rules.hit_per_magic)
	if target.exposed:
		hit += data.rules.sleep_vulnerability
	return clampf(hit, data.rules.minimum_hit, data.rules.maximum_hit)

func reason(action: String, ignore_provoke: bool = false) -> String:
	if winner != -2:
		return "Bout finished"
	if action not in ACTIONS:
		return "Unknown action"
	var fighter: Dictionary = fighters[active]
	if not ignore_provoke and fighter.provoked:
		var demanded := "attack" if reason("attack", true).is_empty() else "advance"
		if not reason(demanded, true).is_empty():
			demanded = "sleep"
		if action != demanded:
			return "Provoked. Choose %s." % LABELS[demanded]
	match action:
		"attack":
			if distance() > fighter.weapon.reach:
				return "Out of weapon reach"
		"cast":
			if fighter.spell.is_empty():
				return "Equip a spell"
			if fighter.casts <= 0:
				return "Spell uses spent"
			if distance() > fighter.spell.reach:
				return "Out of spell range"
		"taunt":
			if fighter.energy < data.rules.taunt_minimum:
				return "Needs %d current stamina" % data.rules.taunt_minimum
		"advance", "jump":
			if distance() <= 1:
				return "Already face to face"
		"retreat":
			if positions[active] == (0 if active == 0 else int(data.rules.arena_size)):
				return "At the arena edge"
		"potion":
			if fighter.potions <= 0:
				return "No draught available"
			if fighter.hp == fighter.max_hp:
				return "Health is full"
	if fighter.energy < cost(action):
		return "Needs %d stamina" % cost(action)
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
			var steps := int(data.distances[action])
			if action == "retreat":
				positions[side] = clampi(positions[side] - toward * steps, 0, int(data.rules.arena_size))
			else:
				positions[side] += toward * mini(steps, distance() - 1)
		"guard":
			fighter.guarding = true
			event.message = "%s raises their guard." % fighter.name
		"sleep":
			var before: int = fighter.energy
			fighter.energy = mini(fighter.max_energy, before + roundi(data.rules.base_rest + fighter.stats.Stamina * data.rules.rest_per_stamina))
			fighter.exposed = true
			event.message = "%s recovers %d stamina and is exposed." % [fighter.name, fighter.energy - before]
		"potion":
			var before: int = fighter.hp
			fighter.hp = mini(fighter.max_hp, before + int(data.rules.heal))
			fighter.potions -= 1
			event.message = "%s restores %d health." % [fighter.name, fighter.hp - before]
		"attack", "cast":
			if action == "cast":
				fighter.casts -= 1
			_strike(action, fighter, enemy, event)
		"taunt":
			var provoke := clampf(data.rules.taunt_provoke + fighter.stats.Charisma * data.rules.taunt_provoke_per_charisma, 0.0, data.rules.taunt_provoke_cap)
			if random.randf() < provoke:
				enemy.provoked = true
				event.message = "%s provokes %s into an aggressive move." % [fighter.name, enemy.name]
			else:
				_injure(roundi(data.rules.taunt_base_damage + fighter.stats.Charisma * data.rules.taunt_per_charisma), enemy, event)
				event.message = "%s rattles %s. %s" % [fighter.name, enemy.name, _impact(event)]
	if enemy.hp <= 0:
		winner = side
	else:
		fighter.hp = mini(fighter.max_hp, fighter.hp + roundi(fighter.stats.Vitality * data.rules.regen_per_vitality))
	turn += 1
	if winner == -2 and turn >= int(data.rules.turn_limit):
		var left: float = float(fighters[0].hp) / fighters[0].max_hp
		var right: float = float(fighters[1].hp) / fighters[1].max_hp
		winner = -1 if is_equal_approx(left, right) else (0 if left > right else 1)
		event.message += " The bout reached its turn limit."
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
	var damage := float(fighter.weapon.damage + fighter.stats.Strength * data.rules.damage_per_strength + fighter.get("enchant_damage", 0))
	if action == "cast":
		damage = fighter.spell.damage + fighter.stats.Magic * data.rules.damage_per_magic
	else:
		var critical := minf(data.rules.crit_chance_cap, data.rules.base_crit + fighter.stats.Attack * data.rules.crit_per_attack)
		if random.randf() < critical:
			event.critical = true
			damage *= data.rules.crit_power + fighter.stats.Attack * data.rules.crit_power_per_attack
	var block := float(data.rules.base_block + enemy.stats.Defence * data.rules.block_per_defence)
	if enemy.guarding:
		block += data.rules.guard_block
	if not enemy.exposed and random.randf() < clampf(block, 0.0, data.rules.block_cap):
		event.blocked = true
		damage *= data.rules.guard_damage_factor
	_injure(maxi(1, roundi(damage)), enemy, event)
	var marker := " Critical hit." if event.critical else ""
	if event.blocked:
		marker += " Blocked in part."
	event.message = "%s uses %s.%s %s" % [fighter.name, event.title.to_lower(), marker, _impact(event)]

func _injure(damage: int, target: Dictionary, event: Dictionary) -> void:
	event.armor_hit = mini(damage, int(target.armor))
	target.armor -= event.armor_hit
	event.damage = mini(int(target.hp), damage - event.armor_hit)
	target.hp -= event.damage

func _impact(event: Dictionary) -> String:
	return "%d health, %d armor lost." % [event.damage, event.armor_hit]

func choose(profile: String) -> String:
	var fighter: Dictionary = fighters[active]
	var legal: Array[String] = []
	for action in ACTIONS:
		if reason(action).is_empty():
			legal.append(action)
	if "potion" in legal and fighter.hp <= fighter.max_hp - int(data.rules.heal):
		return "potion"
	if profile == "charisma" and "taunt" in legal:
		return "taunt"
	if "cast" in legal and profile in ["mage", "hybrid", "skirmish"] and (profile == "mage" or distance() > 1 or random.randf() < .52):
		return "cast"
	if "attack" in legal:
		if profile == "guard" and "guard" in legal and not fighter.guarding and random.randf() < .18:
			return "guard"
		return "attack"
	if "cast" in legal:
		return "cast"
	if "jump" in legal and distance() > 2:
		return "jump"
	if "advance" in legal:
		return "advance"
	return "sleep" if "sleep" in legal else legal.front()
