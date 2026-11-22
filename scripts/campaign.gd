extends RefCounted

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
	return true

func create(number: int, name: String, skin: int, hair: int, stats: Dictionary) -> void:
	slot = number
	state = {
		"version": SAVE_VERSION, "name": name, "skin": skin, "hair": hair, "stats": stats.duplicate(),
		"level": 1, "xp": 0, "gold": int(data.rules.starting_gold), "arena": 0, "complete": false,
		"pending": false, "tournament": 0, "bouts": 0, "snapshot": {}, "outcome": {},
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
	var temp := destination + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		save_error = "Couldn't open the save file."
		return
	file.store_string(JSON.stringify(state))
	file.flush()
	file.close()
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
	if state.pending or (tournament and not can_tournament()):
		return {}
	var definition := next_opponent(tournament)
	var level := int(arena().cap if tournament else state.level)
	var left: Dictionary = data.fighter(state.name, state.stats, state.loadout)
	var right: Dictionary = data.opponent(definition, level, arena_index())
	state.snapshot = {"fighters": [left, right], "seed": str(fight_seed), "arena": arena_index(),
		"tournament": tournament, "opponent": definition.name}
	state.outcome = {}
	save()
	return state.snapshot.duplicate(true)

func confirm_points(allocation: Dictionary) -> bool:
	if not state.pending:
		return false
	var count := 0
	for stat in data.STATS:
		var points := int(allocation.get(stat, -1))
		if points < 0:
			return false
		count += points
	if count != int(data.rules.points_per_level):
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

func settle(winner: int, practice: bool = false) -> Dictionary:
	if practice or state.snapshot.is_empty():
		return {"winner": winner, "gold": 0, "xp": 0, "practice": true}
	if not state.outcome.is_empty() and state.outcome.winner == 0:
		return state.outcome.duplicate(true)
	var snapshot: Dictionary = state.snapshot
	var previous_arena := int(snapshot.arena)
	var event_arena: Dictionary = data.arenas[previous_arena]
	var winning := winner == 0
	var earlier_loss: bool = not state.outcome.is_empty()
	var earned_gold := 0
	var earned_xp := 0
	if winning:
		earned_gold = win_gold(previous_arena)
		earned_xp = int(event_arena.xp)
		if snapshot.tournament:
			state.tournament += 1
			if state.tournament >= event_arena.tournament.size():
				state.tournament = 0
				if previous_arena + 1 < data.arenas.size():
					state.arena += 1
				else:
					state.complete = true
	elif not earlier_loss:
		earned_gold = int(data.rules.loss_gold)
		earned_xp = int(data.rules.loss_xp)
	if not snapshot.tournament and not earlier_loss:
		state.bouts += 1
	state.gold += earned_gold
	var cap_level := int(arena().cap)
	var previous_xp := int(state.xp)
	state.xp += earned_xp
	if cap_level < data.rules.xp_levels.size():
		state.xp = mini(state.xp, int(data.rules.xp_levels[cap_level]) - 1)
	earned_xp = int(state.xp) - previous_xp
	consider_level_up()
	state.outcome = {"winner": winner, "gold": earned_gold, "xp": earned_xp,
		"unlocked": int(state.arena) > previous_arena, "complete": state.complete, "practice": false}
	save()
	return state.outcome.duplicate(true)
