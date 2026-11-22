extends RefCounted

const Duel = preload("res://scripts/duel.gd")
const SAVE_VERSION := 1
const SLOT_COUNT := 3
var data: RefCounted
var state: Dictionary = {}
var slot := 0
var save_error := ""

func _init(rules_data: RefCounted) -> void:
	data = rules_data

func path(number: int) -> String:
	return "user://gladiator_%s.json" % number

func read_slot(number: int) -> Dictionary:
	if not FileAccess.file_exists(path(number)):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path(number)))
	if not parsed is Dictionary or parsed.get("version") != SAVE_VERSION or not parsed.get("stats") is Dictionary:
		return {"invalid": true}
	return parsed

func resume(number: int) -> bool:
	var loaded := read_slot(number)
	if loaded.is_empty() or loaded.get("invalid", false):
		return false
	slot = number
	state = loaded
	var migrated := false
	if not state.has("active_bout"):
		state.active_bout = {"actions": [], "practice": false} if not state.snapshot.is_empty() and state.outcome.is_empty() else {}
		migrated = true
	if state.pending and not state.has("pending_points"):
		state.pending_points = int(data.rules.points_per_level)
		migrated = true
	if not state.snapshot.is_empty() and not state.snapshot.has("combat"):
		_record_bout_conditions(state.snapshot)
		migrated = true
	if migrated:
		save()
	return true

func create(number: int, name: String, skin: int, hair: int, stats: Dictionary) -> void:
	slot = number
	state = {
		"version": SAVE_VERSION, "name": name, "skin": skin, "hair": hair, "stats": stats.duplicate(),
		"level": 1, "xp": 0, "gold": int(data.rules.starting_gold), "arena": 0, "complete": false,
		"pending": false, "pending_points": 0, "tournament": 0, "bouts": 0, "snapshot": {}, "outcome": {}, "active_bout": {},
		"owned": [data.rules.starter_weapon],
		"loadout": {"weapon": data.rules.starter_weapon, "armor": data.rules.opening_armour.duplicate(), "spell": "", "potion": false, "enchant": ""},
	}
	for item in state.loadout.armor.values():
		state.owned.append(item)
	save()

func save() -> void:
	if slot < 1:
		return
	var destination := path(slot)
	var temp := "%s.%d.tmp" % [destination, OS.get_process_id()]
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		save_error = "Couldn't open the save file."
		return
	var stored := file.store_string(JSON.stringify(state))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if not stored or write_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
		save_error = "Couldn't write the save file."
		return
	var code := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(destination))
	save_error = "" if code == OK else "Couldn't update the save file (%s)." % code

func arena_index() -> int:
	return int(state.arena)

func arena() -> Dictionary:
	return data.arenas[arena_index()]

func next_opponent(tournament: bool) -> Dictionary:
	var entries: Array = arena().tournament if tournament else arena().opponents
	var position := int(state.tournament if tournament else state.bouts) % entries.size()
	return entries[position]

func can_tournament() -> bool:
	return state.level >= arena().cap and not state.pending and not state.complete

func win_gold(arena_number: int) -> int:
	return roundi(data.arenas[arena_number].gold + state.stats.Charisma * data.rules.gold_per_charisma)

func purchase(item: Dictionary) -> String:
	var reason: String = data.lock_reason(state, item)
	if not reason.is_empty():
		return reason
	if item.id not in state.owned:
		if state.gold < item.price:
			return "Not enough gold."
		state.gold -= int(item.price)
		state.owned.append(item.id)
	match item.kind:
		"armor": state.loadout.armor[item.slot] = item.id
		"weapon": state.loadout.weapon = item.id
		"spell": state.loadout.spell = item.id
		"enchant": state.loadout.enchant = item.id
		"potion": state.loadout.potion = true
	save()
	return ""

func start_bout(tournament: bool, fight_seed: int) -> Dictionary:
	if has_active_bout() or state.pending or (tournament and not can_tournament()):
		return {}
	var definition := next_opponent(tournament)
	var level := int(arena().cap if tournament else state.level)
	var left: Dictionary = data.fighter(state.name, state.stats, state.loadout)
	var right: Dictionary = data.opponent(definition, level, arena_index())
	state.snapshot = {"fighters": [left, right], "seed": str(fight_seed), "arena": arena_index(),
		"tournament": tournament, "opponent": definition.name}
	_record_bout_conditions(state.snapshot)
	state.outcome = {}
	state.active_bout = {"actions": [], "practice": false}
	save()
	return state.snapshot.duplicate(true)

func _record_bout_conditions(snapshot: Dictionary) -> void:
	var event_arena: Dictionary = data.arenas[int(snapshot.arena)]
	snapshot.arena_name = event_arena.name
	snapshot.combat = {"rules": data.rules.duplicate(true), "moves": data.moves.duplicate(), "distances": data.distances.duplicate()}
	snapshot.rewards = {
		"win_gold": win_gold(int(snapshot.arena)), "win_xp": int(event_arena.xp),
		"loss_gold": int(data.rules.loss_gold), "loss_xp": int(data.rules.loss_xp),
		"tournament_size": event_arena.tournament.size(),
	}
	snapshot.equipment = {}
	for fighter in snapshot.fighters:
		var gear: Dictionary = fighter.loadout
		var ids: Array = gear.get("armor", {}).values()
		ids.append_array([gear.get("weapon", ""), gear.get("spell", ""), gear.get("enchant", "")])
		for id in ids:
			if data.items.has(id):
				snapshot.equipment[id] = data.items[id].duplicate()
		for kind in ["weapon", "spell"]:
			var item: Dictionary = fighter[kind]
			if not item.is_empty():
				snapshot.equipment[item.id] = item.duplicate()

func has_active_bout() -> bool:
	return not state.active_bout.is_empty()

func retry_bout(practice: bool) -> bool:
	if state.pending or has_active_bout() or state.snapshot.is_empty() or state.outcome.is_empty():
		return false
	if practice != (state.outcome.winner == 0):
		return false
	state.active_bout = {"actions": [], "practice": practice}
	save()
	return true

func open_bout(snapshot: Dictionary) -> RefCounted:
	var bout := Duel.new(data, snapshot.fighters[0], snapshot.fighters[1], int(snapshot.seed), -1, snapshot.combat)
	bout.defender_wins_ties = true
	for action in state.active_bout.get("actions", []):
		if not bout.act(action).valid:
			return null
	return bout

func record_turn(action: String, winner: int) -> Dictionary:
	if winner != -2:
		return settle(winner, state.active_bout.practice)
	state.active_bout.actions.append(action)
	save()
	return {}

func points_to_allocate() -> int:
	return int(state.pending_points)

func confirm_points(allocation: Dictionary) -> bool:
	if not state.pending:
		return false
	var count := 0
	for stat in data.STATS:
		var points := int(allocation.get(stat, -1))
		if points < 0:
			return false
		count += points
	if count != points_to_allocate():
		return false
	for stat in data.STATS:
		state.stats[stat] += int(allocation[stat])
	state.level += 1
	state.pending = false
	consider_level_up()
	save()
	return true

func consider_level_up() -> void:
	var level := int(state.level)
	state.pending = level < int(arena().cap) and state.xp >= data.rules.xp_levels[level]
	state.pending_points = int(data.rules.points_per_level) if state.pending else 0

func settle(winner: int, practice: bool = false) -> Dictionary:
	if practice:
		if has_active_bout() and state.active_bout.practice:
			state.active_bout = {}
			save()
		return {"winner": winner, "gold": 0, "xp": 0, "practice": true}
	if state.snapshot.is_empty():
		return {"winner": winner, "gold": 0, "xp": 0, "practice": true}
	if not state.outcome.is_empty() and state.outcome.winner == 0:
		return state.outcome.duplicate(true)
	var snapshot: Dictionary = state.snapshot
	var previous_arena := int(snapshot.arena)
	var rewards: Dictionary = snapshot.rewards
	var winning := winner == 0
	var earlier_loss: bool = not state.outcome.is_empty()
	var earned_gold := 0
	var earned_xp := 0
	if winning:
		earned_gold = int(rewards.win_gold)
		earned_xp = int(rewards.win_xp)
		if snapshot.tournament:
			state.tournament += 1
			if state.tournament >= int(rewards.tournament_size):
				state.tournament = 0
				if previous_arena + 1 < data.arenas.size():
					state.arena += 1
				else:
					state.complete = true
	elif not earlier_loss:
		earned_gold = int(rewards.loss_gold)
		earned_xp = int(rewards.loss_xp)
	if not snapshot.tournament and not earlier_loss:
		state.bouts += 1
	state.gold += earned_gold
	var cap_level := int(arena().cap)
	var previous_xp := int(state.xp)
	state.xp += earned_xp
	if cap_level < data.rules.xp_levels.size():
		state.xp = mini(state.xp, maxi(previous_xp, int(data.rules.xp_levels[cap_level]) - 1))
	earned_xp = int(state.xp) - previous_xp
	consider_level_up()
	state.outcome = {"winner": winner, "gold": earned_gold, "xp": earned_xp,
		"unlocked": int(state.arena) > previous_arena, "complete": state.complete, "practice": false}
	state.active_bout = {}
	save()
	return state.outcome.duplicate(true)
