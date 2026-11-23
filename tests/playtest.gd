extends SceneTree

const Data = preload("res://scripts/data.gd")
const Duel = preload("res://scripts/duel.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Simulator = preload("res://scripts/simulator.gd")
const Game = preload("res://cinder_league.tscn")
const Stage = preload("res://scripts/stage.gd")
const Rig = preload("res://scripts/fighter_rig.gd")

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
	_check_movement(data)
	_check_lunge(data)
	_check_legacy_lunge(data)
	_check_attack_styles(data)
	_check_arena_view(data)
	_check_fighter_rig()
	_check_hit_feedback()
	_check_spell_charges(data)
	_check_saved_bout(data)
	_check_scouting(data)
	_check_defeats(data)
	_check_save_replacement(data)
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

func _check_movement(data: RefCounted) -> void:
	var fighter: Dictionary = data.fighter("Gladiator", data.stats_empty(), {"weapon": "dagger"})
	var duel := Duel.new(data, fighter, fighter, 42)
	var opening := duel.positions.duplicate()
	_check(duel.distance() == 5, "New bouts should start five spaces apart")
	for action in ["attack", "quick", "power", "lunge", "rush"]:
		_check(not duel.act(action).valid and duel.turn == 0 and duel.positions == opening,
			"A melee attack from the opening distance must spend no turn and move neither fighter")
	var jump := duel.act("jump")
	_check(jump.valid and duel.distance() == 2 and duel.active == 1 and jump.damage == 0
		and duel.fighters[0].energy == fighter.energy - duel.cost("jump"),
		"A jump should spend stamina and a turn on movement alone")
	var retreat := duel.act("retreat")
	_check(retreat.valid and duel.distance() == 3, "A retreat should reopen the gap on the defender's turn")
	duel.fighters[0].energy = duel.cost("lunge") - 1
	_check(duel.choose("weapon") == "advance", "The AI should step when a jump would land in melee reach")
	var approach := Duel.new(data, fighter, fighter, 42)
	_check(approach.choose("weapon") == "jump", "The AI should leap across safe open ground")
	approach.act("guard")
	_check(approach.choose("weapon") == "jump" and approach.act("jump").damage == 0,
		"The opponent also has to spend a turn closing the gap")
	for action in ["advance", "retreat", "jump"]:
		var exhausted := Duel.new(data, fighter, fighter, 42)
		exhausted.fighters[0].energy = 0
		_check(not exhausted.act(action).valid and exhausted.positions == opening, "Movement must still cost stamina")

func _check_lunge(data: RefCounted) -> void:
	var fighter: Dictionary = data.fighter("Gladiator", data.stats_empty(), {"weapon": "dagger"})
	var duel := Duel.new(data, fighter, fighter, 42)
	duel.act("advance")
	_check(duel.distance() == 4 and duel.reason("lunge") == "Too far to lunge", "A lunge must close at most two spaces")
	duel.act("advance")
	var cost := int(fighter.weapon.energy) + 7 + 5 * 2
	_check(duel.in_lunge_range() and duel.cost("lunge") == cost and duel.chance("lunge") < duel.chance("attack"),
		"A short lunge should cost extra stamina and be less accurate than a normal attack")
	var starting_positions := duel.positions.duplicate()
	for stamina in [0, cost - 1]:
		duel.fighters[0].energy = stamina
		_check(not duel.act("lunge").valid and duel.positions == starting_positions and duel.turn == 2,
			"A lunge without enough stamina must spend no turn and move neither fighter")
	duel.fighters[0].energy = cost
	var lunge := duel.act("lunge")
	_check(lunge.valid and duel.positions[0] == starting_positions[0] + 2 and duel.distance() == fighter.weapon.reach
		and duel.fighters[0].energy == 0 and duel.active == 1, "A lunge should move into reach and spend the full cost")
	_check(duel.in_weapon_reach() and not duel.act("lunge").valid, "Within weapon reach the fighter should use a regular attack")

	var long_weapon: Dictionary = data.fighter("Gladiator", data.stats_empty(), {"weapon": "court_mace"})
	var nearer_opening := Duel.new(data, long_weapon, long_weapon, 42, 4)
	nearer_opening.act("guard")
	_check(nearer_opening.reason("lunge") == "Too far to lunge", "Even a long weapon needs a shorter gap than the opening")
	nearer_opening.act("advance")
	nearer_opening.act("advance")
	_check(nearer_opening.in_weapon_reach(), "Moving all the way into weapon reach should also allow an attack")

	var rival_lunge := Duel.new(data, fighter, fighter, 42)
	rival_lunge.act("jump")
	_check(rival_lunge.choose("weapon") == "lunge" and rival_lunge.act("lunge").valid and rival_lunge.distance() == 1,
		"A rival can take a short lunge after the gap closes")

func _check_legacy_lunge(data: RefCounted) -> void:
	var fighter: Dictionary = data.fighter("Gladiator", data.stats_empty(), {"weapon": "dagger"})
	var legacy_rules: Dictionary = data.rules.duplicate()
	legacy_rules.lunge_base_cost = 7.0
	legacy_rules.lunge_cost_per_space = 5.0
	legacy_rules.lunge_hit_penalty = .2
	var resolved := Duel.new(data, fighter, fighter, 42, 4, {"rules": legacy_rules})
	_check(resolved.restore_history(["rush", "guard"]) and resolved.distance() == fighter.weapon.reach
		and resolved.history[0].energy_cost == 26 and resolved.turn == 2,
		"A saved lunge should restore its original cost, positions, and turn")
	_check(resolved.reason("rush") == "Unknown action", "Lunge must stay disabled after restoring a saved bout")
	legacy_rules.erase("lunge_base_cost")
	legacy_rules.erase("lunge_hit_penalty")
	legacy_rules.erase("lunge_cost_per_space")
	legacy_rules.erase("lunge_max_spaces")
	var free_moves: Dictionary = data.moves.duplicate()
	free_moves.jump = 0
	var free_weapon := fighter.duplicate(true)
	free_weapon.weapon.energy = 0
	free_weapon.energy = 0
	var oldest := Duel.new(data, free_weapon, fighter, 42, 2, {"rules": legacy_rules, "moves": free_moves})
	_check(oldest.restore_history(["rush"]) and oldest.fighters[0].energy == 0 and oldest.distance() == 1,
		"An already-recorded lunge from an older save should still replay with its saved cost")
	var continued := Duel.new(data, fighter, fighter, 42, 5, {"rules": legacy_rules})
	continued.act("advance")
	continued.act("advance")
	var new_lunge := continued.act("lunge")
	var reloaded := Duel.new(data, fighter, fighter, 42, 5, {"rules": legacy_rules})
	_check(new_lunge.valid and new_lunge.energy_cost == 21 and reloaded.restore_history(["advance", "advance", "lunge"])
		and reloaded.history == continued.history, "A new short lunge in an older bout should reload with the same cost and result")

func _check_attack_styles(data: RefCounted) -> void:
	var stats: Dictionary = data.stats_empty()
	var attacker: Dictionary = data.fighter("Gladiator", stats, {"weapon": "sword"})
	var target: Dictionary = attacker.duplicate(true)
	target.max_hp = 500
	target.hp = 500
	var comparison := Duel.new(data, attacker, target, 42, 1)
	_check(comparison.chance("power") < comparison.chance("attack") and comparison.chance("attack") < comparison.chance("quick")
		and comparison.cost("quick") < comparison.cost("attack") and comparison.cost("attack") < comparison.cost("power"),
		"Quick and Power should trade accuracy and stamina around Normal")
	comparison.fighters[0].energy = comparison.cost("quick")
	_check(comparison.threatens_cast(comparison.fighters[0]) and not comparison.reason("attack").is_empty(),
		"A close opponent who can still use Quick should pressure a caster")

	var rules: Dictionary = data.rules.duplicate()
	rules.base_hit = 1.0
	rules.maximum_hit = 1.0
	rules.power_hit_penalty = 0.0
	rules.base_crit = 0.0
	rules.base_block = 0.0
	var damage: Array[int] = []
	for action in ["quick", "attack", "power"]:
		var duel := Duel.new(data, attacker, target, 42, 1, {"rules": rules})
		var before := duel.positions.duplicate()
		var event := duel.act(action)
		damage.append(event.get("damage", 0))
		_check(duel.positions[1] == before[1] + (1 if action == "power" else 0),
			"Only a Power hit should move a surviving defender")
	_check(damage[0] > 0 and damage[0] < damage[1] and damage[1] < damage[2],
		"Quick, Normal, and Power should deal increasing damage")

	attacker.stats.Strength = 24
	var strong := Duel.new(data, attacker, target, 42, 1, {"rules": rules})
	var start := strong.positions[1]
	strong.act("power")
	_check(strong.positions[1] == start + 3, "Strength should increase Power knockback")

	var edge := int(rules.arena_size)
	for side in [0, 1]:
		var duel := Duel.new(data, attacker, attacker, 42, 1, {"rules": rules})
		duel.fighters[1 - side].hp = 500
		duel.active = side
		duel.positions[0] = edge - 2 if side == 0 else 1
		duel.positions[1] = edge - 1 if side == 0 else 2
		var event := duel.act("power")
		_check(event.get("ring_out", false) and duel.winner == side and duel.fighters[1 - side].hp == 0
			and duel.positions[1 - side] == (edge + 1 if side == 0 else -1),
			"A Power hit past either edge must immediately end the bout")

	rules.base_block = 1.0
	rules.block_cap = 1.0
	var blocked := Duel.new(data, attacker, target, 42, 1, {"rules": rules})
	var before := blocked.positions.duplicate()
	_check(blocked.act("power").get("blocked", false) and blocked.positions == before, "A block should prevent knockback")
	rules.power_hit_penalty = 1.0
	var missed := Duel.new(data, attacker, target, 42, 1, {"rules": rules})
	_check(missed.act("power").get("miss", false) and missed.positions == before, "A miss should prevent knockback")
	rules.erase("power_damage_multiplier")
	var legacy := Duel.new(data, attacker, target, 42, 1, {"rules": rules})
	_check(not legacy.act("power").valid and legacy.act("attack").valid, "Older snapshots should retain Normal without the new styles")

func _check_arena_view(data: RefCounted) -> void:
	var edge := int(data.rules.arena_size)
	_check(edge == 30, "New bouts should use a 30-space arena")
	var stage := Stage.new()
	stage.full_arena = true
	stage.arena_width = edge
	for viewport in [Vector2(1200, 800), Vector2(1920, 800)]:
		stage.size = viewport
		stage.positions = [13, 17]
		var gap := stage.fighter_feet(1).x - stage.fighter_feet(0).x
		_check(is_equal_approx(gap / stage.fighter_height(), 4.0 * Stage.SPACE_PER_FIGHTER_HEIGHT),
			"A combat space should stay the same size relative to the fighters when the viewport changes")
		stage.positions = [0, edge]
		var view := stage._battle_view(stage.positions)
		_check((view * Vector2(-1, 0)).x > 0 and (view * Vector2(edge + 1, 0)).x < viewport.x,
			"The view should fit both fighters and their nearby pits at maximum separation")
		stage.positions = [0, 1]
		view = stage._battle_view(stage.positions)
		_check((view * Vector2(-1, 0)).x > 0 and (view * Vector2(edge + 1, 0)).x > viewport.x,
			"The camera should show the left pit when the fighters are near it")
		stage.positions = [edge - 1, edge]
		view = stage._battle_view(stage.positions)
		_check((view * Vector2(-1, 0)).x < 0 and (view * Vector2(edge + 1, 0)).x < viewport.x,
			"The camera should show the right pit when the fighters are near it")
	stage.free()

func _check_fighter_rig() -> void:
	var pose := Rig.Pose.new()
	var rest := Rig.transforms(pose)
	pose.weapon_arm.z = .45
	pose.head = -.30
	var posed := Rig.transforms(pose)
	_check(posed[Rig.WEAPON_ELBOW] == rest[Rig.WEAPON_ELBOW] and posed[Rig.OFF_WRIST] == rest[Rig.OFF_WRIST]
		and not (posed[Rig.WEAPON_WRIST] * Rig.local(Rig.GRIP)).is_equal_approx(Rig.local(Rig.GRIP)),
		"The weapon wrist should turn the grip without moving either elbow or the off hand")
	_check(posed[Rig.HEAD] != rest[Rig.HEAD] and posed[Rig.SPINE] == rest[Rig.SPINE],
		"The head should move independently of the spine")
	var lift := Vector2(42, -92)
	pose.rear_leg = Rig.walk_leg(0, lift, .16)
	pose.lead_leg = Rig.walk_leg(1, -lift * Vector2(.5, -.8), -.12)
	posed = Rig.transforms(pose)
	var rear_target := Rig.local(Rig.ANKLES[0] + lift)
	var lead_target := Rig.local(Rig.ANKLES[1] - lift * Vector2(.5, -.8))
	_check((posed[Rig.REAR_ANKLE] * Rig.local(Rig.ANKLES[0])).is_equal_approx(rear_target)
		and (posed[Rig.LEAD_ANKLE] * Rig.local(Rig.ANKLES[1])).is_equal_approx(lead_target),
		"The two ankles should reach their own walking targets")
	_check(is_equal_approx(posed[Rig.REAR_ANKLE].get_rotation(), .16)
		and is_equal_approx(posed[Rig.LEAD_ANKLE].get_rotation(), -.12), "Each foot should keep its own angle")
	pose.rear_leg = Rig.walk_leg(0, Vector2(-300, -30), 0.0)
	posed = Rig.transforms(pose)
	_check(is_equal_approx((posed[Rig.REAR_ANKLE] * Rig.local(Rig.ANKLES[0])).y, Rig.local(Rig.ANKLES[0] - Vector2(0, 30)).y),
		"A stride beyond the leg's reach should still keep the planted foot at its floor height")

func _check_hit_feedback() -> void:
	var stage := Stage.new()
	var guard_pose := Rig.Pose.new()
	stage._brace(guard_pose, 1.0, true)
	var guard_bones := Rig.transforms(guard_pose)
	var raised_shield := guard_bones[Rig.OFF_WRIST] * Stage.SHIELD_CENTER
	_check(raised_shield.x > Stage.SHIELD_CENTER.x and raised_shield.y < Stage.SHIELD_CENTER.y,
		"A shielded block should lift the shield toward the incoming blow")
	var strike := {"action": "attack", "side": 0, "critical": false, "blocked": false, "damage": 0, "armor_hit": 5,
		"positions": [14, 15], "health": [44, 44]}
	stage.animate(strike)
	var strike_time := stage.action_time
	var armor_recoil := stage._hit_recoil(.13)
	_check(not stage._bloodied_hit() and not stage._knockout(), "A hit absorbed by armor should not draw blood or topple the fighter")
	strike.damage = 5
	strike.armor_hit = 0
	strike.health = [44, 39]
	stage.animate(strike)
	_check(stage._bloodied_hit() and stage._hit_recoil(.13) > armor_recoil, "A health hit should add blood and a stronger flinch")
	stage.full_arena = true
	stage.kind = "battle"
	var impacts := [0]
	stage.impact_reached.connect(func() -> void: impacts[0] += 1)
	stage._process(stage.impact_time + .01)
	stage._process(.02)
	_check(impacts[0] == 1 and is_equal_approx(stage.elapsed, stage.impact_time) and stage.contact_hold_elapsed > 0.0,
		"Landed strikes should signal impact once and hold the pose while the particles move")
	stage._process(.10)
	_check(impacts[0] == 1 and stage.elapsed > stage.impact_time, "The strike should recover after the hold")
	var miss := strike.duplicate()
	miss.miss = true
	miss.damage = 0
	stage.animate(miss)
	stage._process(stage.impact_time + .01)
	_check(impacts[0] == 2 and stage.contact_hold_left == 0.0 and stage.elapsed > stage.impact_time,
		"A missed swing should keep moving through its follow-through")
	strike.health = [44, 0]
	stage.animate(strike)
	_check(stage._knockout() and stage.action_time > strike_time, "A standard knockout should leave time for the full collapse")
	strike.ring_out = true
	strike.positions = [29, 31]
	stage.animate(strike)
	_check(not stage._knockout() and not stage._bloodied_hit(), "A ring-out should use the fall into the pit")
	stage.free()

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
	var narrow_snapshot := snapshot.duplicate(true)
	narrow_snapshot.combat.rules.arena_size = 10
	narrow_snapshot.combat.rules.starting_distance = 4
	_check(campaign.open_bout(narrow_snapshot).positions == [3, 7], "An older bout should keep its narrower arena")
	var opening: RefCounted = campaign.open_bout(snapshot)
	opening.act("jump")
	campaign.record_turn("jump", opening.winner)
	_check(campaign.open_bout(snapshot).history == opening.history, "Continuing a save should replay its accepted moves")
	_check(campaign.start_bout(false, 99).is_empty(), "Entering a new bout must not overwrite an ongoing one")
	var changed := Data.new()
	changed.load_profile()
	changed.rules.starting_distance = 1
	changed.rules.arena_size = 10
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
	var outfits := {}
	for seed_value in range(40, 64):
		var rival: Dictionary = data.generate_opponent(6, 1, seed_value)
		_check(rival == data.generate_opponent(6, 1, seed_value), "A seed should reproduce the same rival")
		_check(rival.level in [5, 6, 7], "Regular rivals should stay within one level of the player and inside the arena")
		styles[rival.style] = true
		names[rival.name] = true
		outfits[Vector3i(rival.look.chest, rival.look.helmet, rival.look.palette)] = true
	_check(styles.size() > 1 and names.size() > 1, "Different seeds should generate varied regular rivals")
	_check(outfits.size() >= 12, "Regular rivals should mix many visible cosmetic outfits")
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

func _check_save_replacement(data: RefCounted) -> void:
	var campaign := Campaign.new(data)
	var number := int(Time.get_unix_time_from_system() * 1000000)
	var gladiator := "Retired %d" % number
	var stats: Dictionary = data.build_stats("weapon", 10)
	if not _check(campaign.create(number, gladiator, 0, 0, stats), "The replacement fixture should save"):
		return
	campaign.state.level = 5
	campaign.state.arena = 1
	campaign.save()
	var previous := campaign.slot_revision(number)
	_check(not campaign.create(number, "Newcomer", 0, 0, stats), "An occupied slot needs confirmation before replacement")
	campaign.state.xp += 1
	campaign.save()
	_check(not campaign.create(number, "Newcomer", 0, 0, stats, previous), "A changed save must be confirmed again")
	var current := campaign.slot_revision(number)
	var archive := Campaign.RETIRED_DIR.path_join("gladiator_%d_%s.json" % [number, current])
	_check(campaign.create(number, "Newcomer", 0, 0, stats, current), "A confirmed replacement should start a new career")
	_check(campaign.read_slot(number).name == "Newcomer" and FileAccess.get_sha256(archive) == current,
		"Replacing a save should keep an exact copy of the previous career")
	var records := campaign.hall_of_fame().filter(func(entry: Dictionary) -> bool: return entry.name == gladiator)
	_check(records.size() == 1 and records[0].crowns == 1 and records[0].status == "Retired",
		"The retired career should retain its tournament win in the Hall of Fame")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(archive))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(campaign.path(number)))

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
	_find_button(ui, "Play").pressed.emit()
	_check(ui.current_screen == "slots" and _find_button(ui, "Create gladiator") != null, "Play should open the save slots")
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
	_press_escape()
	_check(ui.current_screen == "town", "Escape should return from a shop to town")
	_press_escape()
	if _check(is_instance_valid(ui.settings_popup), "Escape in town should open the pause menu"):
		_check(_find_button(ui.settings_popup, "Settings") != null and _find_button(ui.settings_popup, "Audio") != null
			and _find_button(ui.settings_popup, "Quit") != null, "Pause should offer settings, audio, and quit")
		_find_button(ui.settings_popup, "Resume").pressed.emit()
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
	_press_escape()
	_check(ui.current_screen == "battle" and not is_instance_valid(ui.settings_popup), "Escape should keep the player in the bout")
	var attack: Button = ui.battle_hud.action_buttons.attack
	_check(not ui.battle_hud.action_buttons.has("lunge") and attack.disabled
		and attack.tooltip_text.contains("Move closer"), "The HUD should require movement from the starting gap")
	attack.pressed.emit()
	_check(ui.bout.turn == 0, "Pressing Attack out of range must not spend a turn")
	_check(not ui.battle_hud.action_buttons.quick.visible and not ui.battle_hud.action_buttons.power.visible,
		"Quick and Power should be hidden outside weapon reach")
	_check(ui.battle_hud.action_buttons.jump.tooltip_text.contains("3 spaces") and not ui.battle_hud.action_buttons.jump.disabled,
		"The leap button should show the available movement distance")
	var rival_start: int = ui.bout.positions[1]
	ui.bout.positions[1] = ui.bout.positions[0] + 2
	ui._refresh_battle()
	_check(attack.accessibility_name == "Lunge" and not attack.disabled and attack.tooltip_text.contains("16 stamina"),
		"The sword button should become Lunge in short range and show the stamina cost")
	ui.bout.positions[1] = ui.bout.positions[0] + 1
	ui._refresh_battle()
	_check(ui.battle_hud.action_buttons.quick.visible and ui.battle_hud.action_buttons.power.visible
		and not attack.disabled and attack.accessibility_name == "Normal attack", "Close range should expose all three attack styles")
	var starting_stamina: int = ui.bout.fighters[0].energy
	ui.bout.fighters[0].energy = 0
	ui._refresh_battle()
	_check(attack.disabled and attack.tooltip_text.contains("Not enough stamina"), "The HUD should explain why an exhausted attack is disabled")
	attack.pressed.emit()
	_check(ui.bout.turn == 0, "The fight must reject an exhausted attack even if the button signal fires")
	ui.bout.fighters[0].energy = starting_stamina
	ui.bout.positions[1] = rival_start
	ui._refresh_battle()
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
	_press_escape()
	_check(ui.current_screen == "allocate", "Escape from results should respect a pending level-up")
	ui._retry(true)
	_check(ui.current_screen == "allocate", "A pending level-up should block practice")
	ui.queue_free()

func _press_escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

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
