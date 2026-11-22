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
	_check_exhaustion(data)
	_check_saved_bout(data)
	_check_scouting(data)
	_check_defeats(data)
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
