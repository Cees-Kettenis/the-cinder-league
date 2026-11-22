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
	_check(loss.gold == data.rules.loss_gold, "A first loss should pay its saved consolation")
	_check(campaign.settle(1).gold == 0, "A repeated loss must not pay again")
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
	ui._new_bout(false)
	_check(ui.current_screen == "battle" and not ui.shell.visible and _find_button(ui, "Leave bout") == null,
		"Combat must occupy the game view and offer no way back during the bout")
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
	if node is Button and node.text == caption:
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
