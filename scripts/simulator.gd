extends RefCounted

const Duel = preload("res://scripts/duel.gd")
const Campaign = preload("res://scripts/campaign.gd")
const STYLES: Array[String] = ["weapon", "guard", "mage", "skirmish", "charisma", "hybrid", "all_attack", "brute"]
var data: RefCounted

func _init(rules_data: RefCounted) -> void:
	data = rules_data

func batch(left: String, right: String, level: int, start_seed: int, count: int, options: Dictionary = {}) -> Dictionary:
	var points := int(data.rules.starting_points + (level - 1) * data.rules.points_per_level)
	var problem := _validate_scenario(options, level, points)
	if not problem.is_empty():
		return {"error": problem}
	var left_stats: Dictionary = options.get("left_stats", data.build_stats(left, points))
	var right_stats: Dictionary = options.get("right_stats", data.build_stats(right, points))
	var left_items: Dictionary = options.get("left_loadout", data.eligible_loadout(level, left_stats, left))
	var right_items: Dictionary = options.get("right_loadout", data.eligible_loadout(level, right_stats, right))
	var first_blood: bool = not options.get("death_match", false)
	var left_fighter: Dictionary = data.fighter(left.capitalize(), left_stats, left_items, left, not first_blood)
	var right_fighter: Dictionary = data.fighter(right.capitalize(), right_stats, right_items, right, not first_blood)
	var summary := {"mode": "duel", "left": left, "right": right, "seed": str(start_seed), "level": level,
		"bouts": count, "left_wins": 0, "right_wins": 0, "draws": 0, "turns": 0, "damage": 0, "blocks": 0, "misses": 0,
		"left_stats": left_stats, "right_stats": right_stats, "left_loadout": left_items, "right_loadout": right_items,
		"first_blood": first_blood, "trace": []}
	for index in count:
		var match_seed := start_seed + index
		var bout := Duel.new(data, left_fighter, right_fighter, match_seed, int(options.get("distance", -1)), {"first_blood": first_blood})
		var scripted: Array = options.get("actions", [])
		while bout.winner == -2:
			var action := str(scripted[bout.turn]) if bout.turn < scripted.size() else bout.choose(left if bout.active == 0 else right)
			var event := bout.act(action)
			if not event.valid:
				return {"error": "Seed %s, turn %d, %s: %s" % [match_seed, bout.turn + 1, action, event.message]}
			summary.damage += event.damage + event.armor_hit
			summary.blocks += int(event.blocked)
			summary.misses += int(event.miss)
		summary.turns += bout.turn
		if bout.winner == 0:
			summary.left_wins += 1
		elif bout.winner == 1:
			summary.right_wins += 1
		else:
			summary.draws += 1
		if index == 0:
			summary.trace = bout.history
	return summary

func campaign(style: String, seed_value: int, limit: int) -> Dictionary:
	var run := Campaign.new(data)
	run.create(0, style.capitalize(), 0, 0, data.build_stats(style, int(data.rules.starting_points)))
	var results: Array[Dictionary] = []
	var first_trace: Array[Dictionary] = []
	for step in limit:
		_shop(run, style)
		var snapshot := run.start_bout(run.can_tournament(), seed_value + step)
		var bout: RefCounted = run.open_bout(snapshot)
		while bout.winner == -2:
			var action: String = bout.choose(style if bout.active == 0 else str(bout.fighters[1].style))
			var event: Dictionary = bout.act(action)
			if not event.valid:
				return {"error": "Seed %s, turn %d, %s: %s" % [snapshot.seed, bout.turn + 1, action, event.message]}
		if step == 0:
			first_trace = bout.history
		var result := run.settle(bout.winner)
		while run.state.pending:
			var invested := 0
			for points in run.state.stats.values():
				invested += int(points)
			if not run.confirm_points(data.build_stats(style, run.points_to_allocate(), invested)):
				return {"error": "Could not allocate the earned points."}
		results.append({"bout": step + 1, "seed": snapshot.seed, "opponent_seed": snapshot.opponent_seed,
			"opponent": snapshot.opponent, "opponent_level": snapshot.fighters[1].level, "winner": bout.winner,
			"arena": run.state.arena + 1, "tournament": snapshot.tournament, "level": run.state.level, "turns": bout.turn,
			"gold": run.state.gold, "xp": run.state.xp, "result": result})
		if run.state.complete or run.is_fallen():
			break
	return {"mode": "campaign", "style": style, "seed": str(seed_value), "complete": run.state.complete,
		"fallen": run.is_fallen(),
		"level": run.state.level, "arena": run.state.arena + 1, "gold": run.state.gold, "xp": run.state.xp,
		"bouts": results, "trace": first_trace}

func _shop(run: RefCounted, style: String) -> void:
	var candidate: Dictionary = data.eligible_loadout(int(run.state.level), run.state.stats, style)
	var choices: Array = [candidate.weapon, candidate.spell, candidate.enchant, "potion" if candidate.potion else ""]
	choices.append_array(candidate.armor.values())
	for id in choices:
		if not id.is_empty() and data.items.has(id):
			run.purchase(data.items[id])

func _validate_scenario(options: Dictionary, level: int, points: int) -> String:
	if options.has("death_match") and not options.death_match is bool:
		return "The death_match field must be true or false."
	if options.has("actions"):
		if not options.actions is Array:
			return "Scenario actions must be an array of action names."
		for action in options.actions:
			if action not in Duel.ACTIONS:
				return "Unknown scripted action: " + str(action)
	if options.has("distance") and (not _whole_number(options.distance) or options.distance < 1 or options.distance > data.rules.arena_size):
		return "Scenario distance must be a whole number within the arena."
	for side in ["left", "right"]:
		var stats_key: String = side + "_stats"
		var loadout_key: String = side + "_loadout"
		if options.has(stats_key):
			if not options[stats_key] is Dictionary:
				return stats_key + " must be an object."
			var stats: Dictionary = options[stats_key]
			var spent := 0
			for name in data.STATS:
				if not stats.has(name) or not _whole_number(stats[name]):
					return "Provide a whole, non-negative value for " + stats_key + "." + name
				spent += int(stats[name])
			if spent > points:
				return "%s exceeds the %d-point budget at level %d." % [stats_key, points, level]
		if options.has(loadout_key):
			if not options[loadout_key] is Dictionary:
				return loadout_key + " must be an object."
			var loadout: Dictionary = options[loadout_key]
			for kind in ["weapon", "spell", "enchant"]:
				var id = loadout.get(kind, "")
				if not id is String or (not id.is_empty() and data.items.get(id, {}).get("kind") != kind):
					return "Unknown %s item in %s." % [kind, loadout_key]
			var reserve = loadout.get("reserve_spell", "")
			if not reserve is String or (not reserve.is_empty() and (data.items.get(reserve, {}).get("kind") != "spell"
					or reserve == loadout.get("spell", "") or str(loadout.get("spell", "")).is_empty())):
				return "Reserve spell in %s must differ from the equipped main spell." % loadout_key
			if loadout.has("potion") and not loadout.potion is bool:
				return "The potion field must be true or false."
			if loadout.has("armor"):
				if not loadout.armor is Dictionary:
					return "The armor field must map slots to item IDs."
				for slot in loadout.armor:
					var item: Dictionary = data.items.get(loadout.armor[slot], {})
					if slot not in data.SLOTS or item.get("slot") != slot:
						return "Invalid armor slot or item in " + loadout_key
	return ""

func _whole_number(value: Variant) -> bool:
	return (value is int or value is float) and value >= 0 and value == floor(value)
