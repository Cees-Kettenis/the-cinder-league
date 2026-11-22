extends SceneTree

const Data = preload("res://scripts/data.gd")
const Duel = preload("res://scripts/duel.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Simulator = preload("res://scripts/simulator.gd")
const Game = preload("res://cinder_league.tscn")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var data := Data.new()
	var error := data.load_profile()
	if not error.is_empty():
		printerr(error)
		quit(1)
		return
	_check_replay(data)
	_check_starter_weapon(data)
	_check_exhaustion(data)
	_check_rush(data)
	_check_spell_charges(data)
	_check_saved_bout(data)
	_check_scouting(data)
	_check_defeats(data)
	_check_saved_spell_faceoff(data)
	_check_game_buttons()
	await process_frame
	await process_frame
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Playtest regression checks passed.")
	quit(0 if failures.is_empty() else 1)

func _check_replay(data: RefCounted) -> void:
	var simulator := Simulator.new(data)
	var original := simulator.batch("guard", "guard", 4, 42, 1)
	if not _check(not original.has("error"), "The AI bout should complete"):
		return
	var actions: Array = original.trace.map(func(event: Dictionary) -> String: return event.action)
	for count in [3, actions.size()]:
		var replay := simulator.batch("guard", "guard", 4, 42, 1, {"actions": actions.slice(0, count)})
		_check(replay.get("trace", []) == original.trace, "Replaying %d recorded moves should preserve the trace" % count)

func _check_starter_weapon(data: RefCounted) -> void:
	var run := Campaign.new(data)
	var stats: Dictionary = data.build_stats("weapon", int(data.rules.starting_points))
	run.create(0, "Gladiator", 0, 0, stats)
	_check(run.state.loadout.weapon == "dagger" and run.state.owned == ["dagger"], "A new gladiator should own and equip the dagger")
	var snapshot := run.start_bout(false, 42)
	_check(snapshot.fighters[0].weapon.id == "dagger" and snapshot.fighters[0].weapon.damage < data.items.sword.damage,
		"The starter dagger should deal less damage than the short sword in a bout")
	_check(snapshot.fighters[1].weapon.id == "dagger", "Level-one rivals should use the starter weapon")
	run.settle(0)
	var gold := int(run.state.gold)
	_check(run.purchase(data.items.sword).is_empty() and run.state.loadout.weapon == "sword"
		and int(run.state.gold) == gold - int(data.items.sword.price), "The short sword should be available as a paid upgrade")
	var veteran: Dictionary = data.fighter("Veteran", stats, {"weapon": "sword"})
	_check(veteran.weapon.id == "sword", "A weapon explicitly saved as a short sword should stay a short sword")

func _check_exhaustion(data: RefCounted) -> void:
	var fighter: Dictionary = data.fighter("Gladiator", data.stats_empty(), {})
	var duel := Duel.new(data, fighter, fighter, 42)
	duel.fighters[0].energy = 0
	duel.fighters[0].provoked = true
	_check(duel.choose("weapon") == "sleep" and duel.reason("sleep").is_empty(), "An exhausted provoked fighter needs a legal recovery action")
	duel.act("sleep")
	_check(duel.fighters[0].energy > 0, "Sleep must restore stamina")
	var profile: Dictionary = data.profile.duplicate(true)
	profile.moves.sleep = 1
	var path := "user://playtest-%d.json" % Time.get_ticks_usec()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not _check(file != null, "Could not write the temporary profile"):
		return
	file.store_string(JSON.stringify(profile))
	file.close()
	_check(not Data.new().load_profile(path).is_empty(), "A profile that charges stamina to sleep must be rejected")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _check_rush(data: RefCounted) -> void:
	var fighter: Dictionary = data.fighter("Gladiator", data.stats_empty(), {"weapon": "court_mace"})
	var reach := int(fighter.weapon.reach)
	var leap := int(data.distances.jump)
	var duel := Duel.new(data, fighter, fighter, 42, reach + leap)
	var cost := int(fighter.weapon.energy) + int(data.moves.jump)
	duel.fighters[0].energy = cost - 1
	_check(duel.reason("rush").begins_with("Needs"), "A rush needs enough stamina for the leap and weapon attack")
	duel.fighters[0].energy = cost
	var strike := Duel.new(data, fighter, fighter, 42, reach).act("attack")
	var rush := duel.act("rush")
	_check(rush.get("valid", false) and duel.distance() == reach and duel.fighters[0].energy == 0,
		"A rush at the limit should move into weapon reach, then spend its full stamina cost")
	_check(rush.get("damage") == strike.damage and rush.get("miss") == strike.miss and rush.get("critical") == strike.critical,
		"A rush should resolve like the same weapon attack in range")
	_check(not duel.reason("rush").is_empty() and duel.reason("attack").is_empty(), "Use the regular attack once in reach")
	var too_far := Duel.new(data, fighter, fighter, 42, reach + leap + 1)
	_check(not too_far.act("rush").valid and too_far.turn == 0, "An enemy a step beyond rush range can't be attacked")
	var other_side := Duel.new(data, fighter, fighter, 42, reach + leap)
	other_side.act("guard")
	_check(other_side.choose("weapon") == "rush" and other_side.act("rush").valid and other_side.distance() == reach,
		"The opponent can also rush, moving toward the player")

func _check_spell_charges(data: RefCounted) -> void:
	var stats: Dictionary = data.stats_empty()
	var caster: Dictionary = data.fighter("Caster", stats, {"spell": "fireball"})
	var enemy: Dictionary = data.fighter("Gladiator", stats, {})
	var rules: Dictionary = data.rules.duplicate()
	rules.minimum_hit = 0.0
	rules.spell_hit = 0.0
	var duel := Duel.new(data, caster, enemy, 42, 4, {"rules": rules})
	_check(caster.casts == 2 and data.items.lightning.uses == 2 and data.items.arc.uses == 1,
		"Starter spells should have two casts, and heavy spells should have one")
	for remaining in [1, 0]:
		var event := duel.act("cast")
		_check(event.get("miss", false) and duel.fighters[0].casts == remaining, "A cast should spend a charge even if it misses")
		duel.act("guard")
	duel.act("sleep")
	duel.act("guard")
	_check(duel.reason("cast") == "Spell uses spent" and not duel.act("cast").valid, "Sleeping must not restore used casts")
	var fresh := Duel.new(data, caster, enemy, 42, 4)
	_check(fresh.fighters[0].casts == 2, "Spell charges should reset for a new fight")

	var campaign := Campaign.new(data)
	campaign.create(0, "Gladiator", 0, 0, stats)
	campaign.scout_bout(false, 42)
	var rival: Dictionary = campaign.state.scouted_bout.rival
	rival.loadout.spell = "fireball"
	rival.spell = data.items.fireball.duplicate()
	rival.spell.uses = 5
	rival.casts = 5
	var snapshot := campaign.start_bout(false, 42)
	_check(snapshot.fighters[1].name == rival.name and snapshot.fighters[1].casts == 2,
		"A previously scouted rival should keep their identity and start with the current spell charges")
	snapshot.fighters[1].spell = rival.spell
	snapshot.fighters[1].casts = 5
	_check(campaign.open_bout(snapshot).fighters[1].casts == 5, "A saved fight should preserve its original spell charges")

func _check_saved_bout(data: RefCounted) -> void:
	var campaign := Campaign.new(data)
	campaign.create(0, "Gladiator", 0, 0, data.build_stats("weapon", 10))
	var snapshot := campaign.start_bout(false, 42)
	var tie_snapshot := snapshot.duplicate(true)
	tie_snapshot.combat.rules.turn_limit = 2
	var tied: RefCounted = campaign.open_bout(tie_snapshot)
	tied.act("guard")
	tied.act("guard")
	_check(tied.winner == 1, "An equal-health campaign bout should end in defeat at the turn limit")
	var saved_distance := int(data.rules.starting_distance)
	var saved_gold := campaign.win_gold(0)
	var opening: RefCounted = campaign.open_bout(snapshot)
	opening.act("jump")
	campaign.record_turn("jump", opening.winner)
	_check(campaign.open_bout(snapshot).history == opening.history, "Continuing a save should replay its accepted moves")
	_check(campaign.start_bout(false, 99).is_empty(), "Entering a new bout must not overwrite an ongoing one")
	var changed := Data.new()
	changed.load_profile()
	changed.rules.starting_distance = 1
	changed.arenas[0].gold += 100
	changed.rules.points_per_level = 12
	campaign.data = changed
	var reopened: RefCounted = campaign.open_bout(snapshot)
	_check(reopened.history == opening.history, "A resumed bout should keep its original combat rules")
	var loss := campaign.settle(1)
	_check(loss.gold == -int(data.rules.loss_gold) and loss.xp == 0, "A regular loss should charge gold and give no XP")
	var gold_left := int(campaign.state.gold)
	campaign.settle(1)
	_check(campaign.state.gold == gold_left, "Settling the same loss twice must not repeat the fee")
	_check(campaign.retry_bout(false), "A regular defeat should be retryable")
	var win := campaign.settle(0)
	_check(win.gold == saved_gold, "A retry win should keep its original reward")
	var settled := campaign.state.duplicate(true)
	_check(campaign.retry_bout(true), "A practice bout should start after a victory")
	_check(campaign.open_bout(snapshot).distance() == saved_distance, "A practice bout should start at the original distance")
	campaign.record_turn("guard", -2)
	_check(campaign.state.active_bout.practice, "A pending practice bout should persist as practice")
	campaign.record_turn("guard", 0)
	_check(campaign.state == settled, "Practice must leave the campaign untouched")
	var next := campaign.start_bout(false, 43)
	_check(campaign.open_bout(next).distance() == 1, "New bouts should use the active profile")
	campaign.settle(0)
	changed.rules.points_per_level = 14
	_check(campaign.state.pending and campaign.points_to_allocate() == 12, "Balance edits must not change an earned allocation")

func _check_scouting(data: RefCounted) -> void:
	var styles := {}
	var names := {}
	for seed_value in range(40, 64):
		var rival: Dictionary = data.generate_opponent(6, 1, seed_value)
		_check(rival == data.generate_opponent(6, 1, seed_value), "A seed should reproduce the same rival")
		_check(rival.level in [5, 6, 7], "Regular rivals should stay within one level of the player and inside the arena")
		styles[rival.style] = true
		names[rival.name] = true
	_check(styles.size() > 1 and names.size() > 1, "Different seeds should generate varied regular rivals")
	var campaign := Campaign.new(data)
	campaign.create(0, "Gladiator", 0, 0, data.build_stats("weapon", 10))
	campaign.state.level = 4
	campaign.state.xp = data.rules.xp_levels[3]
	var full_gold := campaign.win_gold(0, true)
	var offer := campaign.scout_bout(false, 42)
	_check(campaign.scout_bout(false, 99) == offer, "Returning to a scout should not reroll it")
	var first := campaign.scout_bout(true, 99)
	_check(not first.is_empty() and campaign.scouted_bout() == offer, "Scouting a tournament should preserve the regular rival")
	campaign.purchase(data.items.leather_chest)
	var snapshot := campaign.start_bout(false, 99)
	_check(snapshot.seed == "42" and snapshot.fighters[1] == offer.rival, "The fight should use the scouted rival and seed")
	_check(snapshot.fighters[0].loadout.armor.get("chest") == "leather_chest", "Gear bought before the fight should be equipped")
	var training := campaign.settle(0)
	_check(training.gold == roundi(full_gold * data.rules.capped_gold_multiplier)
		and training.xp == 0 and campaign.state.xp == data.rules.xp_levels[3], "Capped training wins should award reduced gold and no XP")
	_check(campaign.scouted_bout().is_empty(), "Finishing a bout should make the next scout available")
	_check(campaign.scout_bout(true, 20) == first, "Training should preserve the scouted tournament opponent")
	campaign.start_bout(true, 19)
	var preliminary := campaign.settle(0)
	_check(preliminary.xp == 0 and preliminary.gold == full_gold, "A capped preliminary should still pay full tournament gold")
	campaign.start_bout(true, 20)
	campaign.settle(0)
	_check(campaign.state.arena == 1 and campaign.state.pending and campaign.state.xp >= data.rules.xp_levels[4],
		"The Amber champion should open Iron Court and grant level 5 eligibility")
	campaign.state.level = 8
	campaign.state.xp = data.rules.xp_levels[7]
	campaign.state.pending = false
	var round_count: int = data.arenas[1].tournament.size()
	_check(round_count == int(data.arenas[0].tournament.size()) + 1, "Iron Court should add a preliminary fight")
	for round_index in round_count:
		var round := campaign.start_bout(true, 20 + round_index)
		_check(not round.is_empty(), "Each tournament round should be available in order")
		campaign.settle(0)
		_check(campaign.state.complete == (round_index == round_count - 1), "Only the champion should finish the tournament")
	var champion: Dictionary = data.generate_opponent(8, 1, 20, round_count - 1)
	_check(champion == data.generate_opponent(8, 1, 99, round_count - 1), "Changing the seed should not change the champion")

func _check_defeats(data: RefCounted) -> void:
	var campaign := Campaign.new(data)
	var stats: Dictionary = data.build_stats("weapon", 10)
	campaign.create(0, "Gladiator", 0, 0, stats)
	campaign.state.gold = 3
	campaign.start_bout(false, 42)
	_check(campaign.settle(1).gold == -3 and campaign.state.gold == 0 and campaign.can_scout(false),
		"A broke gladiator should lose the remaining gold and still be able to fight")
	campaign.state.level = 4
	campaign.state.xp = data.rules.xp_levels[3]
	campaign.start_bout(true, 43)
	campaign.settle(0)
	campaign.retry_bout(true)
	_check(campaign.settle(1, true).practice and not campaign.is_fallen(), "Tournament practice should stay safe")
	campaign.start_bout(true, 44)
	var defeat := campaign.settle(1)
	_check(defeat.fallen and campaign.is_fallen() and not campaign.has_active_bout(),
		"A tournament loss should permanently end the campaign")
	_check(not campaign.can_scout(false) and not campaign.can_tournament() and not campaign.retry_bout(false)
		and not campaign.purchase(data.items.leather_chest).is_empty(), "A fallen gladiator should be locked out of play")
	campaign.create(0, "Legacy", 0, 0, stats)
	campaign.state.level = 4
	campaign.start_bout(true, 44)
	campaign.state.snapshot.rewards.erase("lethal_defeat")
	campaign.settle(1)
	_check(not campaign.is_fallen() and campaign.can_scout(false) and not campaign.retry_bout(false),
		"A tournament fight started before lethal rules should finish without a surprise death")

func _check_saved_spell_faceoff(data: RefCounted) -> void:
	var number := int(Time.get_unix_time_from_system() * 1000000)
	var save := Campaign.new(data)
	if not _check(save.create(number, "Caster", 0, 0, data.build_stats("mage", 10)), "The caster fixture should save"):
		return
	_check(save.purchase(data.items.fireball).is_empty(), "The caster should equip a spell")
	var offer := save.scout_bout(false, 42)
	_check(offer.rival.spell.is_empty(), "The face-off fixture should have a rival without a spell")
	var ui = Game.instantiate()
	root.add_child(ui)
	ui.sound.enabled = false
	ui._resume(number)
	_find_button(ui, "Arena").pressed.emit()
	_find_button(ui, offer.rival.name).pressed.emit()
	var fight := _find_button(ui, "Fight")
	if _check(fight != null, "A reloaded caster should be able to open a face-off against a rival without a spell"):
		fight.pressed.emit()
		_check(ui.current_screen == "battle" and ui.bout.fighters[0].spell.id == "fireball",
			"Starting the reloaded bout should keep the player's equipped spell")
	ui.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path(number)))

func _check_game_buttons() -> void:
	var ui = Game.instantiate()
	root.add_child(ui)
	ui.sound.enabled = false
	ui.game.create(0, "Gladiator", 0, 0, ui.data.build_stats("weapon", 10))
	ui.show_town()
	var button := _find_button(ui, "Magic shop")
	if _check(button != null, "Town should have a Magic shop button"):
		button.pressed.emit()
		_check(ui.current_screen == "shop" and ui.shop_entries.has("fireball"), "Town's Magic shop button should open spell stock")
	_find_button(ui, "Weaponsmith").pressed.emit()
	_find_button(ui, "Iron mace").pressed.emit()
	_check(ui.shop_stage.left_loadout.weapon == "mace" and ui.game.state.loadout.weapon == ui.data.rules.starter_weapon,
		"The locked mace should appear in the preview without changing the equipped weapon")
	_check(ui.shop_buy.disabled and ui.shop_buy.text.begins_with("Requires level"), "The mace's unlock requirement should be visible")
	ui.game.state.xp = int(ui.data.rules.xp_levels[1]) - 1
	ui.show_arena()
	_find_button(ui, "Scout rival").pressed.emit()
	_check(ui.current_screen == "scout" and not ui.game.has_active_bout(), "Scouting should open the face-off before combat")
	var offer: Dictionary = ui.game.scouted_bout().duplicate(true)
	_find_button(ui, "Back").pressed.emit()
	_check(ui.current_screen == "arena", "Players should be able to leave the face-off")
	_find_button(ui, offer.rival.name).pressed.emit()
	_check(ui.game.scouted_bout() == offer, "Reopening the face-off should keep its opponent")
	_find_button(ui, "Fight").pressed.emit()
	_check(ui.current_screen == "battle" and not ui.shell.visible and _find_button(ui, "Leave bout") == null,
		"Combat must occupy the game view and offer no way back during the bout")
	_check(not ui.battle_hud.action_buttons.rush.disabled and ui.battle_hud.action_buttons.attack.disabled,
		"The HUD should offer a rush when the fighter can close the gap, with a normal attack still out of reach")
	for action_button: Button in ui.battle_hud.action_buttons.values():
		_check(action_button.text.is_empty() and not action_button.accessibility_name.is_empty(),
			"Combat actions should use icons and accessible names")
	for fighter in ui.battle_hud.fighter_cards:
		for bar: ProgressBar in fighter.bars:
			_check(not bar.show_percentage and bar.max_value == 1.0, "Combat bars should only display fill")
	ui.battle_hud.settings_button.pressed.emit()
	if _check(is_instance_valid(ui.settings_popup), "Settings should open from combat"):
		_check(_find_button(ui.settings_popup, "Simulator") == null, "Combat settings should keep the player in the bout")
		var turn: int = ui.bout.turn
		ui._player_action("advance")
		_check(ui.bout.turn == turn, "Settings should block combat actions while open")
		ui.settings_popup.hide()
	ui.bout.winner = 0
	ui.bout_result = ui.game.record_turn("attack", 0)
	ui._finish_bout()
	_check(ui.current_screen == "result" and _find_button(ui, "Spend level-up points") != null, "Finishing a bout should show the required allocation")
	ui.show_arena()
	_check(ui.current_screen == "allocate", "A pending level-up should block the arena")
	ui._retry(true)
	_check(ui.current_screen == "allocate", "A pending level-up should block practice")
	ui.queue_free()

func _find_button(node: Node, caption: String) -> Button:
	if node is Button and (node.text == caption or node.accessibility_name == caption):
		return node
	for child in node.get_children():
		var match_button := _find_button(child, caption)
		if match_button != null:
			return match_button
	return null

func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
	return condition
