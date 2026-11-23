extends RefCounted

const Duel = preload("res://scripts/duel.gd")
const SAVE_VERSION := 1
const SLOT_COUNT := 3
const FALLEN_DIR := "user://fallen"
const RETIRED_DIR := "user://retired"
var data: RefCounted
var state: Dictionary = {}
var slot := 0
var save_error := ""

func _init(rules_data: RefCounted) -> void:
	data = rules_data

func path(number: int) -> String:
	return "user://gladiator_%s.json" % number

func read_slot(number: int) -> Dictionary:
	return _read_save(path(number))

func _read_save(file: String) -> Dictionary:
	if not FileAccess.file_exists(file):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(file))
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
	if state.get("scouted_bout", {}).get("tournament", false):
		state.scouted_tournament = state.scouted_bout
		state.scouted_bout = {}
		migrated = true
	if migrated:
		save()
	return true

func slot_revision(number: int) -> String:
	return FileAccess.get_sha256(path(number)) if FileAccess.file_exists(path(number)) else ""

func create(number: int, name: String, skin: int, hair: int, stats: Dictionary, replace_revision: String = "") -> bool:
	if number >= 1 and FileAccess.file_exists(path(number)):
		var revision := slot_revision(number)
		if revision.is_empty() or revision != replace_revision:
			save_error = "This slot changed. Choose Replace save again."
			return false
		if not _archive_save(number, revision):
			return false
	var previous_slot := slot
	var previous_state := state
	slot = number
	state = {
		"version": SAVE_VERSION, "name": name, "skin": skin, "hair": hair, "stats": stats.duplicate(),
		"career_id": Crypto.new().generate_random_bytes(16).hex_encode() if number >= 1 else "",
		"level": 1, "xp": 0, "gold": int(data.rules.starting_gold), "arena": 0, "complete": false,
		"pending": false, "pending_points": 0, "tournament": 0, "bouts": 0, "snapshot": {}, "outcome": {}, "active_bout": {},
		"scouted_bout": {}, "scouted_tournament": {}, "tournament_seed": "", "fallen": false,
		"owned": [data.rules.starter_weapon],
		"loadout": {"weapon": data.rules.starter_weapon, "armor": data.rules.opening_armour.duplicate(), "spell": "", "potion": false, "enchant": ""},
	}
	for item in state.loadout.armor.values():
		state.owned.append(item)
	save()
	if not save_error.is_empty():
		slot = previous_slot
		state = previous_state
		return false
	return true

func _archive_save(number: int, fingerprint: String) -> bool:
	var source := ProjectSettings.globalize_path(path(number))
	var directory := ProjectSettings.globalize_path(FALLEN_DIR if read_slot(number).get("fallen", false) else RETIRED_DIR)
	var destination := directory.path_join("gladiator_%d_%s.json" % [number, fingerprint])
	if not fingerprint.is_empty() and FileAccess.file_exists(destination) and FileAccess.get_sha256(destination) == fingerprint:
		return true
	if (fingerprint.is_empty() or DirAccess.make_dir_recursive_absolute(directory) != OK
			or DirAccess.copy_absolute(source, destination) != OK or FileAccess.get_sha256(destination) != fingerprint):
		save_error = "Couldn't archive the previous save."
		return false
	return true

func hall_of_fame() -> Array[Dictionary]:
	var scores: Array[Dictionary] = []
	var seen := {}
	for number in range(1, SLOT_COUNT + 1):
		_add_record(path(number), false, seen, scores)
	for directory in [FALLEN_DIR, RETIRED_DIR]:
		var archive := DirAccess.open(directory)
		if archive == null:
			continue
		for file in archive.get_files():
			if file.ends_with(".json"):
				_add_record(directory.path_join(file), true, seen, scores)
	scores.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		for field in ["crowns", "level", "xp"]:
			if left[field] != right[field]:
				return left[field] > right[field]
		return left.name.naturalnocasecmp_to(right.name) < 0)
	return scores

func _add_record(file: String, archived: bool, seen: Dictionary, scores: Array[Dictionary]) -> void:
	var saved := _read_save(file)
	if saved.is_empty() or saved.get("invalid", false):
		return
	var career: String = saved.get("career_id", "")
	if career.is_empty():
		career = FileAccess.get_sha256(file)
	if seen.has(career):
		return
	seen[career] = true
	var complete := bool(saved.get("complete", false))
	var status := "Retired" if archived else "Active"
	if saved.get("fallen", false):
		status = "Fallen"
	elif complete:
		status = "Champion"
	scores.append({"name": str(saved.get("name", "Gladiator")), "level": int(saved.get("level", 1)),
		"xp": int(saved.get("xp", 0)), "crowns": int(saved.get("arena", 0)) + int(complete), "status": status})

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

func is_fallen() -> bool:
	return state.get("fallen", false)

func can_tournament() -> bool:
	return not is_fallen() and state.level >= arena().cap and not state.pending and not state.complete

func tournament_in_progress() -> bool:
	if state.is_empty() or is_fallen() or state.complete:
		return false
	return int(state.tournament) > 0 or (has_active_bout() and state.snapshot.get("tournament", false)
		and not state.active_bout.get("practice", false))

func scouted_bout(tournament: bool = false) -> Dictionary:
	var offer: Dictionary = state.get("scouted_tournament" if tournament else "scouted_bout", {})
	if offer.is_empty() or offer.rival.spell.is_empty():
		return offer
	var spell: Dictionary = data.items.get(offer.rival.spell.id, offer.rival.spell)
	var casts: int = data.spell_casts(spell, int(offer.rival.stats.Magic), tournament)
	if spell == offer.rival.spell and casts == int(offer.rival.casts):
		return offer
	# A scout locks the opponent and gear. Only an entered bout locks their spell stats.
	var updated := offer.duplicate(true)
	updated.rival.spell = spell.duplicate()
	updated.rival.casts = casts
	return updated

func can_scout(tournament: bool) -> bool:
	return (not is_fallen() and not has_active_bout() and not state.pending
		and (can_tournament() if tournament else not tournament_in_progress()))

func win_gold(arena_number: int, tournament: bool = false) -> int:
	var venue: Dictionary = data.arenas[arena_number]
	var reward: float = venue.gold + state.stats.Charisma * data.rules.gold_per_charisma
	if not tournament and state.level >= venue.cap:
		reward *= data.rules.capped_gold_multiplier
	return roundi(reward)

func regular_win_xp() -> int:
	if state.level >= arena().cap:
		return 0
	return mini(int(arena().xp), maxi(0, _xp_cap() - int(state.xp)))

func _xp_cap() -> int:
	return int(data.rules.xp_levels[int(arena().cap) - 1])

func purchase(item: Dictionary, reserve: bool = false) -> String:
	if is_fallen():
		return "This gladiator has fallen."
	if tournament_in_progress():
		return "Finish the tournament before shopping."
	var reason: String = data.lock_reason(state, item)
	if not reason.is_empty():
		return reason
	if reserve:
		if item.kind != "spell" or not data.has_reserve_slot(int(state.stats.Magic)):
			return "The reserve spell slot is locked."
		if state.loadout.spell.is_empty() or state.loadout.spell == item.id:
			return "Equip a different spell in the main slot first."
	if item.id not in state.owned:
		if state.gold < item.price:
			return "Not enough gold."
		state.gold -= int(item.price)
		state.owned.append(item.id)
	match item.kind:
		"armor": state.loadout.armor[item.slot] = item.id
		"weapon": state.loadout.weapon = item.id
		"spell":
			if reserve:
				state.loadout.reserve_spell = item.id
			else:
				if state.loadout.get("reserve_spell", "") == item.id:
					state.loadout.reserve_spell = state.loadout.spell
				state.loadout.spell = item.id
		"enchant": state.loadout.enchant = item.id
		"potion": state.loadout.potion = true
	save()
	return ""

func clear_reserve_spell() -> void:
	if not is_fallen() and not tournament_in_progress():
		state.loadout.erase("reserve_spell")
		save()

func scout_bout(tournament: bool, seed_value: int) -> Dictionary:
	if not can_scout(tournament):
		return {}
	var scout_key := "scouted_tournament" if tournament else "scouted_bout"
	var offer := scouted_bout(tournament)
	if not offer.is_empty():
		return offer.duplicate(true)
	var round_index := -1
	var round_count: int = arena().tournament.size()
	var previous_seed: String = state.get("tournament_seed", "")
	var opponent_seed := seed_value ^ 0x5619b1e5
	if tournament:
		if previous_seed.is_empty():
			state.tournament_seed = str(seed_value)
		round_index = mini(int(state.tournament), round_count - 1)
		opponent_seed = int(state.tournament_seed) ^ ((arena_index() + 1) * 0x9e3779b9) ^ ((round_index + 1) * 0x85ebca6b)
	var rival: Dictionary = data.generate_opponent(int(state.level), arena_index(), opponent_seed, round_index)
	state[scout_key] = {
		"tournament": tournament, "round": round_index, "round_count": round_count,
		"seed": str(seed_value), "opponent_seed": str(opponent_seed), "rival": rival,
	}
	save()
	if not save_error.is_empty():
		state[scout_key] = {}
		state.tournament_seed = previous_seed
		return {}
	return scouted_bout(tournament).duplicate(true)

func start_bout(tournament: bool, fight_seed: int) -> Dictionary:
	var offer := scout_bout(tournament, fight_seed)
	if offer.is_empty():
		return {}
	var previous_snapshot: Dictionary = state.snapshot
	var previous_outcome: Dictionary = state.outcome
	var scout_key := "scouted_tournament" if tournament else "scouted_bout"
	var left: Dictionary = data.fighter(state.name, state.stats, state.loadout, "weapon", tournament)
	var right: Dictionary = offer.rival
	state.snapshot = {"fighters": [left, right], "seed": offer.seed, "opponent_seed": offer.opponent_seed,
		"arena": arena_index(), "tournament": tournament, "opponent": right.name}
	_record_bout_conditions(state.snapshot)
	state.snapshot.combat.first_blood = not tournament
	state.snapshot.rewards.tournament_size = offer.round_count
	state.snapshot.rewards.lethal_defeat = tournament
	state.outcome = {}
	state.active_bout = {"actions": [], "practice": false}
	state[scout_key] = {}
	save()
	if not save_error.is_empty():
		state.snapshot = previous_snapshot
		state.outcome = previous_outcome
		state.active_bout = {}
		state[scout_key] = offer
		return {}
	return state.snapshot.duplicate(true)

func _record_bout_conditions(snapshot: Dictionary) -> void:
	var event_arena: Dictionary = data.arenas[int(snapshot.arena)]
	snapshot.arena_name = event_arena.name
	snapshot.combat = {"rules": data.rules.duplicate(true), "moves": data.moves.duplicate(), "distances": data.distances.duplicate()}
	snapshot.rewards = {
		"win_gold": win_gold(int(snapshot.arena), snapshot.tournament), "win_xp": int(event_arena.xp),
		"loss_gold": int(data.rules.loss_gold),
		"tournament_size": event_arena.tournament.size(),
	}
	snapshot.equipment = {}
	for fighter in snapshot.fighters:
		var gear: Dictionary = fighter.loadout
		var ids: Array = gear.get("armor", {}).values()
		ids.append_array([gear.get("weapon", ""), gear.get("spell", ""), gear.get("reserve_spell", ""), gear.get("enchant", "")])
		for id in ids:
			if data.items.has(id):
				snapshot.equipment[id] = data.items[id].duplicate()
		for kind in ["weapon", "spell", "reserve_spell"]:
			var item: Dictionary = fighter.get(kind, {})
			if not item.is_empty():
				snapshot.equipment[item.id] = item.duplicate()

func has_active_bout() -> bool:
	return not state.active_bout.is_empty()

func retry_bout(practice: bool) -> bool:
	if is_fallen() or state.pending or has_active_bout() or tournament_in_progress() or state.snapshot.is_empty() or state.outcome.is_empty():
		return false
	if practice != (state.outcome.winner == 0):
		return false
	if not practice and (state.snapshot.tournament or not scouted_bout().is_empty()):
		return false
	state.active_bout = {"actions": [], "practice": practice}
	save()
	return true

func open_bout(snapshot: Dictionary) -> RefCounted:
	var bout := Duel.new(data, snapshot.fighters[0], snapshot.fighters[1], int(snapshot.seed), -1, snapshot.combat)
	bout.defender_wins_ties = true
	return bout if bout.restore_history(state.active_bout.get("actions", [])) else null

func record_turn(action: String, winner: int) -> Dictionary:
	if winner != -2:
		return settle(winner, state.active_bout.get("practice", false))
	state.active_bout.actions.append(action)
	save()
	return {}

func points_to_allocate() -> int:
	return int(state.pending_points)

func confirm_points(allocation: Dictionary) -> bool:
	if is_fallen() or not state.pending:
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
	state.pending = not is_fallen() and level < int(arena().cap) and state.xp >= data.rules.xp_levels[level]
	state.pending_points = int(data.rules.points_per_level) if state.pending else 0

func settle(winner: int, practice: bool = false) -> Dictionary:
	if practice:
		if has_active_bout() and state.active_bout.practice:
			state.active_bout = {}
			save()
		return {"winner": winner, "gold": 0, "xp": 0, "practice": true}
	if state.snapshot.is_empty():
		return {"winner": winner, "gold": 0, "xp": 0, "practice": true}
	if not has_active_bout():
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
		if state.level < arena().cap:
			earned_xp = int(rewards.win_xp)
		if snapshot.tournament:
			state.tournament += 1
			if state.tournament >= int(rewards.tournament_size):
				state.tournament = 0
				if previous_arena + 1 < data.arenas.size():
					state.arena += 1
					state.scouted_bout = {}
					var next_level_xp := int(data.rules.xp_levels[int(data.arenas[previous_arena].cap)])
					earned_xp = maxi(int(rewards.win_xp), next_level_xp - int(state.xp))
				else:
					state.complete = true
	elif rewards.get("lethal_defeat", false):
		state.fallen = true
		state.scouted_bout = {}
		state.scouted_tournament = {}
	else:
		earned_gold = -mini(int(state.gold), int(rewards.loss_gold))
	if not snapshot.tournament and not earlier_loss:
		state.bouts += 1
	state.gold += earned_gold
	var previous_xp := int(state.xp)
	earned_xp = mini(earned_xp, maxi(0, _xp_cap() - previous_xp))
	state.xp += earned_xp
	consider_level_up()
	state.outcome = {"winner": winner, "gold": earned_gold, "xp": earned_xp,
		"unlocked": int(state.arena) > previous_arena, "complete": state.complete,
		"fallen": is_fallen(), "practice": false}
	state.active_bout = {}
	save()
	return state.outcome.duplicate(true)
