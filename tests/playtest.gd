extends SceneTree

const Data = preload("res://game/catalog/data.gd")
const Content = preload("res://game/catalog/content_catalog.gd")
const FightScreen = preload("res://game/combat/fight_screen.tscn")
const Duel = preload("res://game/combat/duel.gd")
const Campaign = preload("res://game/campaign/campaign.gd")
const Simulator = preload("res://game/simulation/simulator.gd")
const Game = preload("res://game/screens/cinder_league.tscn")
const Stage = preload("res://game/combat/stage.gd")
const Rig = preload("res://game/combat/fighter_rig.gd")
const Armor = preload("res://game/combat/armor_art.gd")

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
	_check_stamina_mobility(data)
	_check_tactical_presets(data)
	_check_fast_melee_rival(data)
	_check_legacy_lunge(data)
	_check_strength_damage(data)
	_check_vitality_health(data)
	_check_attack_styles(data)
	_check_first_blood(data)
	_check_arena_view(data)
	_check_fighter_rig()
	_check_sabre_pose()
	_check_rival_weapon_art(data)
	_check_armor_sprites(data)
	_check_hit_feedback()
	_check_fatality_variants(data)
	_check_spell_damage(data)
	_check_yield_bout(data)
	_check_prepared_magic(data)
	_check_previous_save_version(data)
	_check_saved_bout(data)
	_check_legacy_bout_replay(data)
	_check_scouting(data)
	_check_previous_arena_completion(data)
	_check_defeats(data)
	_check_save_replacement(data)
	_check_saved_spell_faceoff(data)
	_check_shop_requirements()
	_check_equipped_shop_selection()
	_check_equipment_shop_controls()
	_check_game_buttons()
	_check_regular_loss_navigation()
	_check_tournament_navigation()
	_check_tournament_practice()
	_check_music_cues()
	_check_display_settings()
	_check_control_settings()
	await _check_fight_turn_flow()
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
	_check(duel.must_sleep(), "Exhaustion should force sleep when it is the only legal turn")
	var with_potion := Duel.new(data, fighter, fighter, 42)
	with_potion.fighters[0].energy = 0
	with_potion.fighters[0].potions = 1
	with_potion.fighters[0].hp -= 1
	_check(not with_potion.must_sleep(), "An exhausted fighter who can drink a potion should keep the choice")
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
	for action in Duel.MOVEMENT:
		var exhausted := Duel.new(data, fighter, fighter, 42)
		exhausted.fighters[0].energy = 0
		_check(not exhausted.act(action).valid and exhausted.positions == opening, "Movement must still cost stamina")
	var escape := Duel.new(data, fighter, fighter, 42, 1)
	escape.positions = [1, 2]
	var leap_back := escape.act("jump_back")
	_check(leap_back.valid and escape.positions == [0, 2] and leap_back.energy_cost == int(data.moves.jump),
		"A backward leap should create distance without crossing into a pit")
	escape.act("guard")
	_check(not escape.act("jump_back").valid, "A gladiator at the edge cannot leap back")
	var mirrored := Duel.new(data, fighter, fighter, 42, 1)
	mirrored.act("guard")
	var gap := mirrored.distance()
	_check(mirrored.act("jump_back").valid and mirrored.distance() == gap + int(data.distances.jump),
		"The right fighter's backward leap should move away too")

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

func _check_stamina_mobility(data: RefCounted) -> void:
	var stats: Dictionary = data.stats_empty()
	stats.Stamina = 5
	var runner: Dictionary = data.fighter("Runner", stats, {"weapon": "dagger"})
	_check(runner.max_energy == 44 and Duel.recovery(data.rules, 5) == 24,
		"Five Stamina points should improve the stamina pool and sleep recovery")
	var chase := Duel.new(data, runner, runner, 42, 4)
	_check(chase.travel("advance") == 2 and chase.travel("retreat") == 2 and chase.travel("jump_back") == 3,
		"Five Stamina points should extend short moves in both directions")
	_check(not chase.in_lunge_range(), "Stamina should never allow lunging from untouched opening positions")
	chase.act("advance")
	chase.act("retreat")
	_check(chase.distance() == 4 and not chase.in_weapon_reach() and chase.in_lunge_range() and chase.cost("lunge") == 26,
		"A moving rival can be three spaces outside weapon reach and still in range of a costly lunge")
	var slower: Dictionary = data.fighter("Pursuer", data.stats_empty(), {"weapon": "dagger"})
	var escape := Duel.new(data, runner, slower, 42, 2)
	_check(escape.act("retreat").valid and escape.distance() == 4 and not escape.in_lunge_range(),
		"A quick retreat should take a fighter outside the lunge range of a slower opponent")

	stats.Stamina = 10
	var sprinter: Dictionary = data.fighter("Sprinter", stats, {"weapon": "dagger"})
	var duel := Duel.new(data, sprinter, sprinter, 42)
	_check(duel.travel("jump") == 4 and duel.travel("jump_back") == 4,
		"Ten Stamina points should extend leaps in both directions")
	var odds := chase.chance("lunge")
	var short_lunge_odds := chase.chance("attack") - float(data.rules.lunge_hit_penalty)
	_check(is_equal_approx(short_lunge_odds - odds, .08) and Duel.lunge_range(data.rules, 100) == 3,
		"The longest lunge should have capped travel and lower accuracy")
	for seed_value in 100:
		chase.random.seed = seed_value
		var roll := chase.random.randf()
		if roll < odds or roll >= short_lunge_odds:
			continue
		chase.random.seed = seed_value
		var long_lunge := chase.act("lunge")
		_check(long_lunge.valid and long_lunge.miss and chase.distance() == 1,
			"A long lunge should use the previewed starting-distance odds and move even on a miss")
		return
	_check(false, "The long lunge test needs a roll between the two hit chances")

func _check_tactical_presets(data: RefCounted) -> void:
	var stats: Dictionary = data.stats_empty()
	stats.Stamina = 10
	var mage: Dictionary = data.fighter("Caster", stats, {"weapon": "dagger", "spell": "fireball"})
	var rival: Dictionary = data.fighter("Pursuer", data.stats_empty(), {"weapon": "dagger"})
	var escape := Duel.new(data, mage, rival, 42, 1)
	_check(escape.choose("keepaway_mage") == "jump_back" and escape.act("jump_back").valid,
		"Keepaway should leap out when a slow pursuer cannot get back into range in one turn")
	escape.act("jump")
	_check(escape.distance() == 2 and escape.choose("keepaway_mage") == "cast",
		"Keepaway should cast from the space it bought")
	var chase := Duel.new(data, rival, mage, 42)
	chase.act("advance")
	chase.act("sleep")
	chase.act("advance")
	chase.act("sleep")
	chase.fighters[0].energy = chase.cost("lunge") + chase.cost("attack")
	_check(chase.choose("weapon") == "lunge" and chase.choose("melee_hunter") == "jump",
		"The hunter should save stamina on the approach if a lunge leaves only one swing")
	var waiting := Duel.new(data, rival, rival, 42)
	waiting.act("guard")
	_check(waiting.choose("duelist") == "taunt", "A duelist should taunt a fighter who opens by waiting")
	var simulator := Simulator.new(data)
	for variant in Simulator.BUILD_PRESETS:
		var sample := simulator.batch(variant, Simulator.BUILD_PRESETS[variant], 4, 42, 1)
		_check(not sample.has("error") and sample.left_stats == sample.right_stats and sample.left_loadout == sample.right_loadout,
			"The %s simulator preset should keep its original build and gear" % variant)

func _check_fast_melee_rival(data: RefCounted) -> void:
	var weapon: Dictionary = data.build_stats("weapon", 40)
	var fast: Dictionary = data.build_stats("fast_melee", 40)
	weapon.Vitality -= 2
	weapon.Stamina += 2
	_check(fast == weapon and fast.Stamina == 10, "Fast Melee should trade two Vitality points for Stamina at level four")
	var caster_stats: Dictionary = data.stats_empty()
	caster_stats.Magic = 24
	caster_stats.Stamina = 10
	var caster: Dictionary = data.fighter("Caster", caster_stats, {"spell": "storm"})
	var found_fast := false
	var found_other := false
	for seed_value in range(40, 80):
		_check(data.generate_opponent(3, 0, seed_value).style != "fast_melee", "Fast melee rivals should start appearing at level four")
		var rival: Dictionary = data.generate_opponent(4, 0, seed_value)
		if rival.style != "fast_melee":
			found_other = true
			continue
		found_fast = true
		_check(rival.level == 4 and rival.stats.Stamina >= 10 and rival.spell.is_empty(),
			"The regular rival should have the four-space leap and a melee loadout")
		var duel := Duel.new(data, caster, rival, seed_value, -1, {"regular_bout": true})
		duel.act("guard")
		var action := duel.choose(rival.style)
		_check(action == "jump" and duel.act(action).valid and duel.distance() == 1 and duel.threatens_cast(duel.fighters[1]),
			"Fast melee rivals should leap into weapon reach against casters on their opening turn")
	_check(found_fast and found_other, "The seeded Amber Ring pool should mix fast pursuers with the other builds")

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
	legacy_rules.erase("stamina_per_extra_space")
	legacy_rules.erase("stamina_per_extra_leap_space")
	legacy_rules.erase("max_stamina_move_bonus")
	legacy_rules.erase("lunge_hit_penalty_per_extra_space")
	var veteran := fighter.duplicate(true)
	veteran.stats.Stamina = 20
	var saved_movement := Duel.new(data, veteran, fighter, 42, 5, {"rules": legacy_rules})
	_check(saved_movement.restore_history(["advance", "guard", "jump_back"])
		and saved_movement.distance() == 7 and Duel.lunge_range(legacy_rules, 20) == 2,
		"Resuming a saved bout must retain its original movement even when the fighter has high Stamina")
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

func _check_strength_damage(data: RefCounted) -> void:
	var stats: Dictionary = data.stats_empty()
	stats.Strength = 28
	stats.Vitality = 52
	var fighter: Dictionary = data.fighter("Gladiator", stats, {"weapon": "warden_sword"})
	var base: float = fighter.weapon.damage
	var normal_rate: float = data.rules.damage_per_strength
	var extra_rate: float = data.rules.damage_per_excess_strength
	_check(is_equal_approx(Duel.strike_damage(data.rules, fighter, false), base + 20 * normal_rate + 8 * extra_rate),
		"Strength above a quarter of 80 assigned points should give less damage")
	fighter.stats.Vitality += 40
	_check(is_equal_approx(Duel.strike_damage(data.rules, fighter, false), base + 28 * normal_rate),
		"The full Strength damage bonus should apply up to 30 with 120 assigned points")
	fighter.stats.Strength = 16
	fighter.stats.Vitality = 24
	_check(is_equal_approx(Duel.strike_damage(data.rules, fighter, false), base + 12 * normal_rate + 4 * extra_rate),
		"The minimum Strength threshold should apply when fewer than 48 points are assigned")
	var legacy_rules: Dictionary = data.rules.duplicate()
	for field in ["strength_damage_floor", "strength_damage_point_fraction", "damage_per_excess_strength"]:
		legacy_rules.erase(field)
	fighter.stats.Strength = 40
	_check(is_equal_approx(Duel.strike_damage(legacy_rules, fighter, false), base + 40 * normal_rate),
		"Saved duel rules without the Strength threshold should preserve the original damage")

func _check_vitality_health(data: RefCounted) -> void:
	var stats: Dictionary = data.stats_empty()
	stats.Strength = 136
	stats.Vitality = 24
	var rules: Dictionary = data.rules
	var full_health := int(rules.base_health + 24 * rules.health_per_vitality)
	_check(data.fighter("Gladiator", stats, {}).max_hp == full_health,
		"Vitality at 15% of an endgame point budget should give full max health")
	stats.Strength = 72
	stats.Vitality = 88
	var specialist: Dictionary = data.fighter("Gladiator", stats, {})
	_check(specialist.max_hp == int(full_health + 64 * rules.health_per_excess_vitality)
		and specialist.hp == specialist.max_hp,
		"Excess Vitality should still add max health at the lower rate")

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
		var opening_positions := duel.positions.duplicate()
		var event := duel.act(action)
		damage.append(event.get("damage", 0))
		_check(duel.positions[1] == opening_positions[1] + (1 if action == "power" else 0),
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

func _check_first_blood(data: RefCounted) -> void:
	var stats: Dictionary = data.stats_empty()
	var attacker: Dictionary = data.fighter("Attacker", stats, {"weapon": "sword", "spell": "fireball"})
	var defender: Dictionary = data.fighter("Defender", stats, {"weapon": "sword", "potion": true})
	var rules: Dictionary = data.rules.duplicate()
	rules.minimum_hit = 1.0
	rules.maximum_hit = 1.0
	rules.power_hit_penalty = 0.0
	rules.base_crit = 0.0
	rules.block_cap = 0.0
	rules.taunt_provoke = 0.0
	var mode := {"rules": rules, "first_blood": true}
	defender.armor = int(attacker.weapon.damage)
	var duel := Duel.new(data, attacker, defender, 42, 1, mode)
	var absorbed := duel.act("attack")
	_check(absorbed.damage == 0 and absorbed.armor[1] == 0 and not absorbed.has("yielded") and duel.winner == -2,
		"Removing the last armor point should leave a first-blood bout running")
	duel.act("guard")
	var blood := duel.act("attack")
	_check(blood.damage > 0 and blood.health[1] > 0 and blood.first_blood and blood.yielded == 1
		and duel.winner == 0 and not duel.act("guard").valid, "The first health damage should end the bout and make the opponent yield")

	var reply := Duel.new(data, attacker, defender, 42, 1, mode)
	reply.act("guard")
	var lost := reply.act("attack")
	_check(lost.get("yielded", -1) == 0 and reply.winner == 1, "An opponent should win by first blood on the same terms")
	var heavy_hit := Duel.new(data, attacker, attacker, 42, 1, mode)
	heavy_hit.fighters[1].hp = 3
	var cut := heavy_hit.act("power")
	_check(cut.get("first_blood", false) and cut.health[1] == 1 and heavy_hit.winner == 0,
		"A finishing hit should leave the yielding fighter alive even if the blow would otherwise be fatal")
	for action in ["cast", "taunt"]:
		var special := Duel.new(data, attacker, attacker, 42, 1, mode)
		var event := special.act(action)
		_check(event.damage > 0 and event.get("yielded", -1) == 1, "%s should win by dealing health damage" % action)

	defender.armor = 100
	var protected := Duel.new(data, attacker, defender, 42, 1, mode)
	var edge := int(rules.arena_size)
	protected.positions = [edge - 1, edge]
	var shove := protected.act("power")
	_check(shove.damage == 0 and not shove.has("ring_out") and protected.winner == -2 and protected.positions[1] == edge,
		"An armored fighter should stop at the edge in a first-blood bout")

	var lethal := Duel.new(data, attacker, attacker, 42, 1, {"rules": rules})
	var wound := lethal.act("attack")
	_check(wound.damage > 0 and wound.health[1] > 0 and not wound.has("yielded") and lethal.winner == -2,
		"A death match should continue after a non-fatal hit")

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

func _check_armor_sprites(data: RefCounted) -> void:
	var player_sets := {}
	for item in data.items.values():
		if item.kind != "armor":
			continue
		var sprite := Armor.equipped(item)
		var texture: Texture2D = sprite.get("texture")
		var family: String = item.id.get_slice("_", 0)
		player_sets[family] = true
		var path := "res://content/gear/armor/%s/%s.webp" % [family, item.slot]
		_check(texture != null and texture.resource_path == path, "%s should use its own sprite" % item.name)
		_check(sprite.has("mesh") == (item.slot in ["pants", "shoes"]),
			"Only the lower-body pieces should use a bending mesh")
		if item.slot == "chest":
			var pieces: Array = sprite.get("weapon_arm", [])
			var plated := family in ["court", "glassguard", "bastion"]
			_check(pieces.size() == (3 if plated else 0), "%s should have its intended arm coverage" % item.name)
			if plated and pieces.size() == 3:
				_check(pieces[0].joint == Rig.WEAPON_SHOULDER and pieces[1].joint == Rig.WEAPON_ELBOW
					and pieces[2].joint == Rig.WEAPON_WRIST, "Arm plates must follow the shoulder, elbow, and weapon grip")
	_check(Armor.ANCHORS.helmet == Rig.HEAD and Armor.ANCHORS.shield == Rig.OFF_WRIST,
		"Helmets and shields should move with their respective joints")
	_check(Content.rival_armor_levels().size() >= player_sets.size(), "Rivals should have at least as many sets as the player")
	var rival_textures := {}
	for family in Content.rival_armor_levels():
		for slot in data.SLOTS:
			var texture: Texture2D = Armor.rival_piece(slot, family).get("texture")
			_check(texture != null and not rival_textures.has(texture), "Each rival set should have its own art in every slot")
			rival_textures[texture] = true
	var stage := Stage.new()
	stage.data = data
	for family in ["court", "glassguard", "bastion"]:
		var armor := {"helmet": family + "_helmet"}
		_check(stage._closed_helmet(armor, {}), "A closed %s helmet should cover the base head" % family)
		_check(not stage._closed_helmet(armor, {"armor": {"helmet": "rival_1"}}),
			"An open rival helmet must retain its visible face")
	var outfit := {"armor": {"chest": "riveted", "helmet": "blackened", "shield": "blackened",
		"pants": "riveted", "shoes": "riveted"}}
	var equipment := {}
	for slot in data.SLOTS:
		equipment[slot] = "bastion_" + slot
		_check(stage._armor_piece(equipment, outfit, slot) == Armor.rival_piece(slot, outfit.armor[slot]),
			"Every equipped rival slot should draw its own artwork")
		_check(stage._armor_piece({}, outfit, slot).is_empty(), "An empty armor slot should stay visible as cloth or skin")
	_check(stage._closed_helmet(equipment, outfit), "A closed rival helmet must hide the covered face")
	_check(not stage._closed_helmet({"helmet": "leather_helmet"}, {}), "An open helmet must retain the visible face")
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
	var strike_wrist := Vector2(882, 564)
	pose.spine = .14
	pose.weapon_arm = Rig.aim_weapon_arm(strike_wrist, .92)
	posed = Rig.transforms(pose)
	_check((posed[Rig.WEAPON_WRIST] * Rig.local(Rig.PIVOTS[Rig.WEAPON_WRIST])).is_equal_approx(
		posed[Rig.SPINE] * Rig.local(strike_wrist)) and is_equal_approx(posed[Rig.WEAPON_WRIST].get_rotation(), 1.06),
		"A strike should reach its authored wrist pose as the torso turns")
	pose.spine = 0.0
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

func _check_sabre_pose() -> void:
	var stage := Stage.new()
	var pose := stage._rest_pose({"weapon": "glass_sabre"})
	var bones := Rig.transforms(pose)
	var sprite := Content.weapon_art("glass_sabre")
	var grip_angle := stage._weapon_rotation({"weapon": "glass_sabre"})
	var blade: Vector2 = bones[Rig.WEAPON_WRIST].basis_xform(((sprite.tip - sprite.grip) * sprite.scale).rotated(grip_angle))
	_check(blade.y < 0.0 and absf(blade.x) < absf(blade.y) * .05, "The Glass sabre should rest upright in the hand")
	var fist := bones[Rig.WEAPON_WRIST].basis_xform(Vector2.RIGHT)
	_check(fist.x > .95 and absf(fist.y) < .05 and pose.weapon_arm.y < -.5,
		"The sabre guard should keep its raised forearm and face the knuckles forward")
	stage.size = Vector2(680, 760)
	stage.left_loadout = {"weapon": "glass_sabre"}
	var tip: Vector2 = bones[Rig.WEAPON_WRIST] * Rig.local(Rig.GRIP) + blade
	_check(stage.size.y * .96 + tip.y * stage._portrait_height() / 1024.0 >= stage.size.y * .04,
		"The portrait should show the entire upright sabre")
	_check(stage._rest_pose({"weapon": "sword"}).weapon_arm.is_equal_approx(Vector3.ZERO), "The sword should retain its resting grip")
	for recovery in [0.0, 1.0]:
		var arm := stage._swing_arm(Vector3(752, 516, -1.31), Vector3(891, 568, .94),
			Vector3(825, 672, 1.48), Vector3(63, -61, 0), recovery, recovery, recovery,
			stage._rest_hand({"weapon": "glass_sabre"}), grip_angle)
		_check(arm.is_equal_approx(pose.weapon_arm), "The swing should start and finish at the sabre's upright grip")
	stage.free()

func _check_rival_weapon_art(data: RefCounted) -> void:
	var textures := {}
	for item in data.items.values():
		if item.kind != "weapon":
			continue
		var sprite := Content.weapon_art(item.id, true)
		if not _check(not sprite.is_empty(), "%s should have rival weapon art" % item.name):
			continue
		var texture: Texture2D = load(sprite.texture)
		var bounds := Rect2(Vector2.ZERO, texture.get_size())
		_check(texture != Stage.weapon_icon(item).atlas and not textures.has(texture.resource_path),
			"%s should use its own rival sprite" % item.name)
		_check(bounds.has_point(sprite.grip) and bounds.has_point(sprite.tip) and sprite.grip != sprite.tip,
			"%s should have distinct grip and contact points inside its texture" % item.name)
		textures[texture.resource_path] = true

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
	var finished := [0]
	stage.impact_reached.connect(func() -> void: impacts[0] += 1)
	stage.turn_animation_finished.connect(func() -> void: finished[0] += 1)
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
	strike.action = "quick"
	stage.animate(strike)
	_check(stage._knockout() and stage.action_time > strike_time, "A standard knockout should leave time for the full collapse")
	stage._process(stage.impact_time + .01)
	# This frame time used to round elapsed below the impact threshold during hit-stop.
	for frame in 400:
		stage._process(.005037)
	_check(impacts[0] == 3 and finished[0] == 1 and is_equal_approx(stage.elapsed, stage.action_time),
		"A knockout must play its impact and finish once even when hit-stop crosses a floating-point boundary")
	strike.action = "attack"
	strike.ring_out = true
	strike.positions = [29, 31]
	stage.animate(strike)
	_check(not stage._knockout() and not stage._bloodied_hit(), "A ring-out should use the fall into the pit")
	stage.free()

func _check_fatality_variants(data: RefCounted) -> void:
	var stage := Stage.new()
	stage.data = data
	stage.lethal_bout = true
	var fatal := {"action": "cast", "side": 0, "critical": false, "blocked": false, "miss": false, "damage": 5, "armor_hit": 0,
		"positions": [14, 15], "health": [44, 0]}
	for spell in ["fireball", "lightning", "meteor", "hellfire", "storm", "arc", "verdigris_bolt", "sunseal"]:
		stage.left_loadout = {"spell": spell}
		stage.animate(fatal)
		var art := int(data.items[spell].art)
		_check(stage.finisher == ("ash" if art in [1, 7] else "burn") and stage.finishing_spell_art == art,
			"%s should choose its own fatal effect" % spell)
	var survived := fatal.duplicate()
	survived.health = [44, 1]
	stage.animate(survived)
	_check(stage.finisher.is_empty() and stage.finishing_spell_art == -1, "An ordinary spell hit should clear any previous fatal effect")
	var yielded := survived.duplicate()
	yielded.yielded = 1
	stage.lethal_bout = false
	stage.animate(yielded)
	_check(stage.finisher.is_empty(), "A first-blood spell hit should still finish with a yield")
	stage.lethal_bout = true
	fatal.action = "power"
	stage.right_loadout = {"weapon": "sword"}
	fatal.side = 1
	fatal.health = [0, 44]
	stage.animate(fatal)
	_check(stage.finisher == "arm", "Fatal blade power attacks should detach the weapon arm on either side")
	fatal.action = "attack"
	stage.animate(fatal)
	_check(stage.finisher == "decapitation", "Normal fatal blade attacks should still decapitate")
	stage.right_loadout.weapon = "mace"
	stage.animate(fatal)
	_check(stage.finisher == "heart", "Blunt weapons should retain their existing finisher")
	stage.free()

func _check_spell_damage(data: RefCounted) -> void:
	var mage: Dictionary = data.fighter("Mage", data.build_stats("mage", 40), {"spell": "storm"})
	var rival: Dictionary = data.fighter("Rival", data.stats_empty(), {})
	rival.stats.Magic = 10
	rival.armor = 4
	var rules: Dictionary = data.rules.duplicate()
	rules.minimum_hit = 1.0
	rules.maximum_hit = 1.0
	rules.block_cap = 0.0
	var regular := Duel.new(data, mage, rival, 42, 5, {"rules": rules, "regular_bout": true})
	var lethal := Duel.new(data, mage, rival, 42, 5, {"rules": rules})
	var raw := regular.action_damage("cast", mage)
	var resisted := regular.action_damage("cast", mage, rival)
	var combat_damage := roundi(resisted) - int(rival.armor)
	_check(is_equal_approx(raw - resisted, 10 * float(rules.spell_resistance_per_magic)),
		"Defender Magic should subtract damage before armor")
	_check(regular.act("cast").damage == combat_damage and lethal.act("cast").damage == combat_damage,
		"Both fight types should use the same spell damage and agree with the preview")
	_check(is_equal_approx(regular.action_damage("attack", mage), regular.action_damage("attack", mage, rival)),
		"Magic resistance should only affect spells")

	var veteran := mage.duplicate(true)
	veteran.stats.Magic += 1
	var bonus := regular.action_damage("cast", veteran, rival) - resisted
	_check(is_equal_approx(bonus, float(rules.damage_per_magic)), "One Magic point should increase spell damage by the configured amount")
	_check(regular.cost("cast", 0) == int(mage.spell.energy) and lethal.cost("cast", 0) == int(mage.spell.energy),
		"Spell stamina cost should be the same in both fight types")

	var previous_rules := rules.duplicate()
	previous_rules.bout_spell_base_multiplier = 0.5
	previous_rules.damage_per_magic = 0.72
	previous_rules.erase("spell_resistance_per_magic")
	var legacy_mage := mage.duplicate(true)
	legacy_mage.spell.damage = 29
	var saved := Duel.new(data, legacy_mage, rival, 42, 5, {"rules": previous_rules, "first_blood": true})
	_check(saved.act("cast").damage == roundi(14.5 + mage.stats.Magic * 0.72) - 4 and saved.winner == 0,
		"An old bout should retain its half base damage and ignore the new resistance")
	rival.armor = 2
	var legacy_rules := rules.duplicate()
	legacy_rules.bout_ranged_spells_armor_only = true
	var mode := {"rules": legacy_rules, "first_blood": true}
	var edge_hit := Duel.new(data, mage, rival, 42, 3, mode)
	var chip := edge_hit.act("cast")
	_check(chip.armor_hit == 2 and chip.damage == 0 and edge_hit.winner == -2,
		"A saved armor-only ranged spell should stop at the last armor point")
	rival.armor = 0
	var opener := Duel.new(data, mage, rival, 42, 5, mode)
	_check(not opener.act("cast").valid and opener.fighters[0].casts == mage.casts,
		"A ranged cast against an unarmored rival should be unavailable and preserve the charge")
	rival.weapon = data.items.court_mace
	var inside_reach := Duel.new(data, mage, rival, 42, 2, mode)
	_check(inside_reach.act("cast").damage > 0 and inside_reach.winner == 0,
		"An old first-blood spell inside the rival's weapon reach can still win immediately")

func _check_yield_bout(data: RefCounted) -> void:
	var stats: Dictionary = data.stats_empty()
	stats.Magic = 80
	var mage: Dictionary = data.fighter("Mage", stats, {"spell": "lightning"})
	mage.spell = mage.spell.duplicate()
	mage.spell.damage = 55 # Isolate the ranged yield rule from balance changes.
	var rival: Dictionary = data.fighter("Rival", data.stats_empty(), {})
	rival.hp = 50
	rival.max_hp = 50
	rival.armor = 2
	var rules: Dictionary = data.rules.duplicate()
	rules.minimum_hit = 1.0
	rules.maximum_hit = 1.0
	rules.block_cap = 0.0
	var mode := {"rules": rules, "regular_bout": true}
	var bout := Duel.new(data, mage, rival, 42, 5, mode)
	var preview_damage := bout.health_damage("cast", roundi(bout.action_damage("cast", mage)), rival)
	var opening := bout.act("cast")
	_check(opening.armor_hit == 2 and opening.damage == preview_damage and opening.health[1] == 10
		and bout.winner == -2, "A full-health rival should survive a ranged hit at exactly 20 percent")
	bout.act("guard")
	var followup := bout.act("cast")
	_check(followup.health[1] > 0 and followup.health[1] < 10 and followup.get("yielded", -1) == 1
		and followup.get("yield_threshold_reached", false) and bout.winner == 0 and bout.distance() == 5,
		"A second ranged cast should be able to win without killing the rival")
	var death_match := Duel.new(data, mage, rival, 42, 5, {"rules": rules})
	_check(death_match.act("cast").health[1] == 0 and death_match.winner == 0,
		"A fatal ranged hit should still be possible in a death match")

func _check_prepared_magic(data: RefCounted) -> void:
	var stats: Dictionary = data.stats_empty()
	stats.Magic = 16
	stats.Vitality = 8
	var run := Campaign.new(data)
	var slot := int(Time.get_unix_time_from_system() * 1000000)
	run.create(slot, "Caster", 0, 0, stats)
	run.state.level = 13
	run.state.gold = 500
	var fireball: Dictionary = data.items.fireball
	var shield: Dictionary = data.items.magic_shield
	_check(data.spell_slots(0) == 2 and data.spell_slots(9) == 2 and data.spell_slots(10) == 3
		and data.spell_slots(20) == 4, "Prepared capacity should increase only at ten-point Magic thresholds")
	_check(run.purchase(fireball).is_empty() and run.purchase(shield).is_empty(), "Spells should be bought directly into free slots")
	var gold := int(run.state.gold)
	run.purchase(fireball, 2)
	_check(run.state.loadout.spells == ["fireball", "magic_shield"] and run.state.gold == gold, "Preparing a duplicate must not charge gold or waste a slot")
	run.purchase(data.items.push, 0)
	_check(run.state.loadout.spells[0] == "push" and run.state.gold == gold - int(data.items.push.price), "A paid swap should replace just the selected slot")
	run.clear_spell(0)
	gold = int(run.state.gold)
	run.purchase(fireball, 0)
	_check(run.state.gold == gold - int(fireball.price), "Buying a previously replaced spell should charge again")
	run.purchase(data.items.potion)
	run.purchase(data.items.armor_potion)
	_check(run.state.loadout.draught == "armor_potion" and run.state.loadout.spells.size() == 2, "A potion should occupy its own single pouch")
	var snapshot := run.start_bout(false, 42)
	var saved := run.open_bout(snapshot) as Duel
	var ward_action := Duel.slot_action(1)
	var ward := saved.act(ward_action)
	run.record_turn(ward_action, -2)
	var reopened := Campaign.new(data)
	_check(reopened.resume(slot), "The new-format save should reopen mid-bout")
	var resumed := reopened.open_bout(reopened.state.snapshot) as Duel
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run.path(slot)))
	_check(resumed != null and ward.get("utility") == "shield" and resumed.history.size() == 1
		and resumed.history[0].action == ward_action and resumed.history[0].positions == ward.positions
		and int(resumed.history[0].energy[0]) == int(ward.energy[0])
		and Duel.spell_charges(resumed.fighters[0], ward_action) == 0
		and resumed.fighters[0].magic_shield == shield.power, "A recorded slot cast should replay its exact ward and charge")

	var enemy: Dictionary = data.fighter("Rival", data.stats_empty(), {"weapon": "sword"})
	var kit := {"weapon": "sword", "armor": {}, "spells": ["magic_shield", "push", "pull"], "draught": "armor_potion"}
	var caster: Dictionary = data.fighter("Caster", stats, kit)
	caster.max_armor = 41
	caster.armor = 41
	var rules: Dictionary = data.rules.duplicate()
	rules.minimum_hit = 1.0
	rules.maximum_hit = 1.0
	rules.regen_per_vitality = 0.0
	var duel := Duel.new(data, caster, enemy, 42, 1, {"rules": rules, "regular_bout": true})
	var plain := Duel.new(data, caster, enemy, 42, 1, {"rules": rules, "regular_bout": true})
	duel.act(Duel.slot_action(0))
	plain.act("guard")
	plain.fighters[0].guarding = false
	var strike := duel.act("attack")
	var reference := plain.act("attack")
	_check(strike.get("shield_absorbed", 0) > 0 and strike.armor_hit == reference.armor_hit - strike.shield_absorbed
		and duel.fighters[0].magic_shield == 0, "A ward should absorb the next hit before armor and then expire")
	duel.fighters[0].armor = 23
	var potion := duel.act("potion")
	_check(potion.valid and potion.armor[0] == 36 and duel.fighters[0].potions == 0, "An Armor Potion should restore 30 percent of starting armor rounded up in a regular bout")
	var naked := Duel.new(data, data.fighter("Caster", stats, kit), enemy, 42)
	_check(not naked.act("potion").valid and naked.fighters[0].potions == 1, "A fighter without armor should keep an unusable Armor Potion")
	var health: Dictionary = caster.duplicate(true)
	health.draught = "potion"
	var health_duel := Duel.new(data, health, enemy, 42, 1, {"rules": rules})
	health_duel.fighters[0].hp -= 4
	_check(health_duel.act("potion").health[0] == health.max_hp and Duel.potion_amount(rules, health) == 16,
		"A Health Potion should scale with Vitality and stop at max health")

	var movement := Duel.new(data, caster, enemy, 42, 2)
	var push := Duel.slot_action(1)
	var pull := Duel.slot_action(2)
	for side in [0, 1]:
		var pair := [caster, enemy] if side == 0 else [enemy, caster]
		for gap in [1, 3, int(data.items.push.reach)]:
			var pushed_at_range := Duel.new(data, pair[0], pair[1], 42, gap)
			pushed_at_range.active = side
			var start := pushed_at_range.positions[side]
			_check(pushed_at_range.act(push).valid and pushed_at_range.distance() == gap * 2
				and pushed_at_range.positions[side] == start, "Push should double the gap on either side")
		var pulled_at_range := Duel.new(data, pair[0], pair[1], 42, int(data.items.pull.reach))
		pulled_at_range.active = side
		var start := pulled_at_range.positions[side]
		_check(pulled_at_range.act(pull).valid and pulled_at_range.distance() == 1
			and pulled_at_range.positions[side] == start, "Pull should bring the rival directly in front at maximum range")
		var edge := int(data.rules.arena_size)
		var near_edge := Duel.new(data, pair[0], pair[1], 42, 2)
		near_edge.active = side
		near_edge.positions.assign([edge - 3, edge - 1] if side == 0 else [1, 3])
		var capped := near_edge.act(push)
		_check(capped.valid and near_edge.positions[1 - side] == (edge if side == 0 else 0)
			and not capped.get("ring_out", false), "Push should stop at either edge without causing a ring-out")
	movement.positions = [int(data.rules.arena_size) - 3, int(data.rules.arena_size) - 1]
	var pushed := movement.act(push)
	_check(pushed.get("utility") == "push" and movement.positions[1] == data.rules.arena_size,
		"Push should stop at the edge, even next to the pit")
	movement.act("guard")
	var pulled := movement.act(pull)
	_check(pulled.get("utility") == "pull" and movement.distance() == 1, "Pull should stop at adjacent")
	var adjacent := Duel.new(data, caster, enemy, 42, 1)
	_check(not adjacent.act(pull).valid and Duel.spell_charges(adjacent.fighters[0], pull) == 1,
		"An impossible pull should spend neither the turn nor the prepared slot")
	var far := Duel.new(data, caster, enemy, 42, int(data.items.pull.reach) + 1)
	_check(not far.act(pull).valid and not far.act(push).valid and far.turn == 0,
		"Neither movement spell should spend a turn outside its casting range")
	var legacy_rules := rules.duplicate()
	legacy_rules.erase("distance_based_spell_movement")
	var legacy := Duel.new(data, caster, enemy, 42, 5, {"rules": legacy_rules})
	_check(legacy.restore_history([push]) and legacy.distance() == 7,
		"An unfinished bout without the new rule should replay its original two-space Push")
	var legacy_pull := Duel.new(data, caster, enemy, 42, 5, {"rules": legacy_rules})
	_check(legacy_pull.restore_history([pull]) and legacy_pull.distance() == 3,
		"An unfinished bout without the new rule should replay its original two-space Pull")

	var etching: Dictionary = data.items.ember_etching
	var enchanted: Dictionary = data.fighter("Enchanter", stats, {"weapon": "sword", "spells": ["ember_etching"]})
	var training: Dictionary = enemy.duplicate(true)
	training.max_hp = 999
	training.hp = 999
	var weapon := Duel.new(data, enchanted, training, 42, 1, {"rules": rules})
	_check(weapon.act(Duel.slot_action(0)).get("utility") == "enchant" and weapon.fighters[0].enchant_damage == etching.power,
		"Ember Etching should grant its starting bonus when cast")
	var ranks := {"stats": {"Magic": int(etching.minimum) + 20}}
	_check(Duel.enchant_bonus(etching, ranks) == etching.power + 2, "Ember Etching should improve across three ranks")
	for remaining in [2, 1, 0]:
		weapon.act("guard")
		var hit := weapon.act("quick")
		_check(hit.get("enchant_used", false) and weapon.fighters[0].enchant_hits == remaining, "A weapon hit should spend one enchantment hit")
	_check(weapon.fighters[0].enchant_damage == 0, "The enchantment bonus should expire after the third weapon hit")
	var miss_rules := rules.duplicate()
	miss_rules.minimum_hit = 0.0
	miss_rules.maximum_hit = 0.0
	var fire: Dictionary = data.fighter("Caster", stats, {"spells": ["fireball"]})
	var miss := Duel.new(data, fire, enemy, 42, 3, {"rules": miss_rules})
	_check(miss.act(Duel.slot_action(0)).miss and Duel.spell_charges(miss.fighters[0], Duel.slot_action(0)) == 0,
		"A missed damage cast should still spend its slot")
	var fresh := Duel.new(data, fire, enemy, 42, 3)
	_check(Duel.spell_charges(fresh.fighters[0], Duel.slot_action(0)) == 1, "A new fight should refresh all prepared slots")

func _check_previous_save_version(data: RefCounted) -> void:
	var run := Campaign.new(data)
	var slot := int(Time.get_unix_time_from_system() * 1000000)
	run.create(slot, "Earlier alpha", 0, 0, data.stats_empty())
	run.state.version = Campaign.SAVE_VERSION - 1
	run.save()
	var revision := run.slot_revision(slot)
	var next := Campaign.new(data)
	_check(next.read_slot(slot).get("incompatible", false) and not next.resume(slot)
		and next.slot_revision(slot) == revision, "An earlier alpha save should be flagged without rewriting it")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run.path(slot)))

func _check_saved_bout(data: RefCounted) -> void:
	var campaign := Campaign.new(data)
	campaign.create(0, "Gladiator", 0, 0, data.build_stats("weapon", 10))
	var snapshot := campaign.start_bout(false, 42)
	_check(campaign.open_bout(snapshot).regular_bout and not campaign.open_bout(snapshot).first_blood,
		"New regular bouts should save the yield rules")
	var legacy_snapshot := snapshot.duplicate(true)
	legacy_snapshot.combat.erase("regular_bout")
	_check(not campaign.open_bout(legacy_snapshot).regular_bout, "A bout saved before nonlethal rules should retain its original win condition")
	var tie_snapshot := snapshot.duplicate(true)
	tie_snapshot.combat.rules.turn_limit = 2
	var tied: RefCounted = campaign.open_bout(tie_snapshot)
	tied.act("guard")
	tied.act("guard")
	_check(tied.winner == 1, "An equal-health campaign bout should end in defeat at the turn limit")
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
	changed.rules.loss_gold += 4
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
	campaign.state.xp = int(changed.rules.xp_levels[1]) - 1
	var next := campaign.start_bout(false, 43)
	_check(next.seed == "43" and campaign.open_bout(next).distance() == 1,
		"A new bout after a loss should use a new seed and the active profile")
	campaign.settle(0)
	changed.rules.points_per_level = 14
	_check(campaign.state.pending and campaign.points_to_allocate() == 12, "Balance edits must not change an earned allocation")

func _check_legacy_bout_replay(data: RefCounted) -> void:
	var campaign := Campaign.new(data)
	var slot := int(Time.get_unix_time_from_system() * 1000000)
	campaign.create(slot, "Older save", 0, 0, data.build_stats("weapon", 10))
	for winner in [1, 0]:
		campaign.start_bout(false, 42 + winner)
		campaign.settle(winner)
		var settled := campaign.read_slot(slot)
		campaign.state.active_bout = {"actions": ["guard"], "practice": winner == 0}
		campaign.save()
		var resumed := Campaign.new(data)
		if _check(resumed.resume(slot), "Older saves with an active replay should open"):
			_check(resumed.state == settled and resumed.read_slot(slot) == settled and resumed.can_scout(false),
				"Discard an old replay and keep the original result, rewards, and career progress")
			campaign = resumed
	DirAccess.remove_absolute(ProjectSettings.globalize_path(campaign.path(slot)))

func _check_scouting(data: RefCounted) -> void:
	var styles := {}
	var names := {}
	var outfits := {}
	for seed_value in range(40, 64):
		var rival: Dictionary = data.generate_opponent(6, 1, seed_value)
		_check(rival == data.generate_opponent(6, 1, seed_value), "A seed should reproduce the same rival")
		_check(rival.level in [5, 6, 7], "Regular rivals should stay within one level of the player and inside the arena")
		_check(rival.look == Data.rival_look(seed_value, 6), "The outfit should use the player's level even when the rival is stronger")
		styles[rival.style] = true
		names[rival.name] = true
		outfits[JSON.stringify(rival.look.armor) + str(rival.look.palette)] = true
	_check(styles.size() > 1 and names.size() > 1, "Different seeds should generate varied regular rivals")
	_check(outfits.size() >= 12, "Regular rivals should mix many visible cosmetic outfits")
	for player_level in range(1, data.max_level() + 1):
		var expected := Content.rival_armor_levels().keys().filter(func(family: String) -> bool:
			return Content.rival_armor_levels()[family] <= player_level)
		var seen := {}
		var mixed := 0
		for seed_value in range(96):
			var pieces: Array = Data.rival_look(seed_value, player_level).armor.values()
			var used := {}
			for family in pieces:
				used[family] = true
				seen[family] = true
			mixed += int(used.size() > 1)
		_check(seen.keys().all(func(family: String) -> bool: return family in expected) and seen.size() == expected.size(),
			"Level %d should use every available armor set and respect the unlocks" % player_level)
		_check(mixed >= 80, "Most outfits at level %d should mix pieces from different sets" % player_level)
	for index in data.arenas.size():
		var level: int = data.arenas[index].cap
		for seed_value in range(40, 64):
			var rival: Dictionary = data.generate_opponent(level, index, seed_value)
			var points := 0
			for item_id in rival.loadout.armor.values():
				points += int(data.items[item_id].armor)
			_check(rival.max_armor == points, "Rival cosmetics must leave the equipment's armor total intact")
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
		var round_snapshot := campaign.start_bout(true, 20 + round_index)
		_check(not round_snapshot.is_empty(), "Each tournament round should be available in order")
		campaign.settle(0)
		_check(campaign.arena_index() == (1 if round_index < round_count - 1 else 2) and not campaign.state.complete,
			"Only the Iron Court champion should open the Glass Crucible")
	var champion: Dictionary = data.generate_opponent(8, 1, 20, round_count - 1)
	_check(champion == data.generate_opponent(8, 1, 99, round_count - 1), "Changing the seed should not change the champion")
	_check(campaign.state.pending and campaign.state.xp >= data.rules.xp_levels[8], "The Glass Crucible should grant level 9 eligibility")
	campaign.state.level = 12
	campaign.state.xp = data.rules.xp_levels[11]
	campaign.state.pending = false
	var glass_rounds: int = campaign.arena().tournament.size()
	_check(glass_rounds == round_count + 1, "The Glass Crucible should add a third preliminary bout")
	for round_index in glass_rounds:
		var snapshot_glass := campaign.start_bout(true, 120 + round_index)
		_check(not snapshot_glass.is_empty(), "Every Glass Crucible round should open in order")
		var duel := campaign.open_bout(snapshot_glass) as Duel
		_check(duel.distance() == 5, "The Glass Crucible should use the shared opening distance")
		campaign.settle(0)
		_check(campaign.arena_index() == (2 if round_index < glass_rounds - 1 else 3) and not campaign.state.complete,
			"Only the Crucible champion should open the Bastion")
	var crucible_champion: Dictionary = data.generate_opponent(12, 2, 20, glass_rounds - 1)
	_check(crucible_champion == data.generate_opponent(12, 2, 99, glass_rounds - 1)
		and not Duel.spell_actions(crucible_champion).is_empty(), "The mage champion should have a fixed build and a spell")
	_check(campaign.state.pending and campaign.state.xp >= data.rules.xp_levels[12], "The Bastion should grant level 13 eligibility")
	campaign.state.level = 16
	campaign.state.xp = data.rules.xp_levels[15]
	campaign.state.pending = false
	var bastion_rounds: int = campaign.arena().tournament.size()
	_check(bastion_rounds == glass_rounds + 1, "The Bastion should add a fourth preliminary bout")
	for round_index in bastion_rounds:
		var snapshot_bastion := campaign.start_bout(true, 230 + round_index)
		_check(not snapshot_bastion.is_empty() and snapshot_bastion.arena == 3, "Bastion rounds should use the new arena")
		campaign.settle(0)
		_check(campaign.state.complete == (round_index == bastion_rounds - 1), "Only the Bastion champion should complete the playtest")
	var stoneward: Dictionary = data.generate_opponent(16, 3, 42, bastion_rounds - 1)
	_check(stoneward == data.generate_opponent(16, 3, 99, bastion_rounds - 1)
		and Content.rival_armor_levels().has(stoneward.look.armor.chest) and stoneward.loadout.armor.chest == "bastion_chest",
		"Stoneward should have a fixed rival outfit and keep the Bastion armor stats")

func _check_previous_arena_completion(data: RefCounted) -> void:
	var legacy: Dictionary = data.profile.duplicate(true)
	legacy.arenas = legacy.arenas.slice(0, 2)
	legacy.rules.arena_caps = legacy.rules.arena_caps.slice(0, 2)
	legacy.rules.xp_levels = legacy.rules.xp_levels.slice(0, 8)
	legacy.rules.xp_levels[7] = 410
	legacy.rules.erase("health_vitality_point_fraction")
	legacy.rules.erase("health_per_excess_vitality")
	legacy.items = legacy.items.filter(func(item: Dictionary) -> bool: return item.level <= 8)
	var path := "user://legacy-iron-profile.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not _check(file != null, "The test should be able to write the legacy profile"):
		return
	file.store_string(JSON.stringify(legacy))
	file.close()
	var extended := Data.new()
	_check(extended.load_profile(path).is_empty() and extended.max_level() == 16
		and extended.rules.xp_levels[7] == 410 and extended.rules.xp_levels[8] > 410
		and extended.rules.health_vitality_point_fraction == 1.0
		and extended.rules.health_per_excess_vitality == legacy.rules.health_per_vitality
		and extended.items.has("pocket_anvil") and extended.items.has("sunseal"),
		"Earlier balance profiles should keep their XP thresholds and health scaling and gain the new arena and stock")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var campaign := Campaign.new(data)
	campaign.create(0, "Iron winner", 0, 0, data.build_stats("weapon", 80))
	campaign.slot = 2
	campaign.state.arena = 1
	campaign.state.level = 8
	campaign.state.xp = data.rules.xp_levels[7]
	campaign.state.complete = true
	campaign.save()
	var continued := Campaign.new(data)
	if not _check(continued.resume(2), "The completed Iron Court save should reopen"):
		return
	_check(continued.arena_index() == 2 and not continued.state.complete
		and continued.state.pending and continued.points_to_allocate() == int(data.rules.points_per_level)
		and continued.state.gold == campaign.state.gold,
		"A completed Iron Court save should continue to level 9 without changing gold")
	for stat in data.STATS:
		_check(continued.state.stats[stat] == campaign.state.stats[stat], "The continuation should preserve %s" % stat)
	_check(continued.resume(2) and continued.arena_index() == 2 and continued.state.xp == data.rules.xp_levels[8],
		"The Iron Court continuation should only grant its new level once")
	campaign.state.arena = 2
	campaign.state.level = 12
	campaign.state.xp = data.rules.xp_levels[11]
	campaign.save()
	_check(continued.resume(2) and continued.arena_index() == 3 and not continued.state.complete
		and continued.state.pending and continued.points_to_allocate() == int(data.rules.points_per_level)
		and continued.state.xp == data.rules.xp_levels[12] and continued.state.gold == campaign.state.gold,
		"A completed Crucible save should reopen at the Bastion's level-up gate with its gold")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(campaign.path(2)))

func _check_defeats(data: RefCounted) -> void:
	var campaign := Campaign.new(data, false)
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
	campaign.start_bout(true, 44)
	var defeat := campaign.settle(1)
	_check(defeat.fallen and campaign.is_fallen() and not campaign.has_active_bout(),
		"A tournament loss should permanently end the campaign")
	_check(not campaign.can_scout(false) and not campaign.can_tournament()
		and not campaign.purchase(data.items.leather_chest).is_empty(), "A fallen gladiator should be locked out of play")
	campaign.create(0, "Legacy", 0, 0, stats)
	campaign.state.level = 4
	campaign.start_bout(true, 44)
	campaign.state.snapshot.rewards.erase("lethal_defeat")
	campaign.settle(1)
	_check(not campaign.is_fallen() and campaign.can_scout(false),
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
	_check(Duel.spell_actions(offer.rival).is_empty(), "The face-off fixture should have a rival without a spell")
	var ui = Game.instantiate()
	root.add_child(ui)
	ui.sound.enabled = false
	ui._resume(number)
	_find_button(ui, "Arena").pressed.emit()
	_find_button(ui, offer.rival.name).pressed.emit()
	var fight := _find_button(ui, "Fight")
	if _check(fight != null, "A reloaded caster should be able to open a face-off against a rival without a spell"):
		fight.pressed.emit()
		_check(ui.current_screen == "battle" and Duel.spell_for_action(ui.fight.bout.fighters[0], Duel.slot_action(0)).get("id") == "fireball"
			and ui.fight.hud.pack.visible and ui.fight.hud.charges[Duel.slot_action(0)].text == "1",
			"Starting the reloaded bout should keep the player's equipped spell")
	ui.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path(number)))

func _check_shop_requirements() -> void:
	var ui = Game.instantiate()
	root.add_child(ui)
	ui.sound.enabled = false
	ui.game.create(0, "Gladiator", 0, 0, ui.data.stats_empty())
	var warden_price: int = ui.data.items.warden_sword.price
	ui.game.state.gold = warden_price
	for entry in [[5, 5], [5, 11], [8, 5], [8, 11]]:
		ui.game.state.level = entry[0]
		ui.game.state.stats.Strength = entry[1]
		ui._enter_shop("weapon")
		ui.shop_entries.warden_sword.pressed.emit()
		var shown := {}
		for label in ui.shop_requirements.find_children("*", "Label", true, false):
			shown[label.text] = label.accessibility_name
		var level_met: bool = entry[0] == 8
		var strength_met: bool = entry[1] == 11
		var level_label := "Level 8" if level_met else "Level 5 / 8"
		var strength_label := "Strength 11" if strength_met else "Strength 5 / 11"
		_check(ui.shop_requirements.visible and shown.get(level_label) == "Level. You have %d. Requires 8. %s" % [entry[0], "Met" if level_met else "Locked"]
			and shown.get(strength_label) == "Strength. You have %d. Requires 11. %s" % [entry[1], "Met" if strength_met else "Locked"],
			"The Warden blade should shorten met requirements and show both values for unmet requirements")
		var can_buy := level_met and strength_met
		_check(ui.shop_buy.accessibility_name.begins_with("Buy & equip" if can_buy else "Locked") and ui.shop_buy.disabled != can_buy,
			"The Buy button should unlock when both requirements are met")
	ui.game.state.gold = warden_price - 1
	ui._preview_item("warden_sword")
	_check(ui.shop_buy.disabled and ui.spell_slot_notice.text == "Not enough gold", "The shop should explain affordability separately")
	ui.shop_entries.sword.pressed.emit()
	_check(not ui.shop_requirements.visible and not ui.shop_buy.disabled, "The starter sword should hide the requirements row")
	ui.queue_free()

func _check_equipped_shop_selection() -> void:
	var ui = Game.instantiate()
	root.add_child(ui)
	ui.sound.enabled = false
	ui.game.create(0, "Gladiator", 0, 0, ui.data.build_stats("weapon", 10))
	for id in ["sword", "leather_chest", "leather_pants"]:
		ui.game.purchase(ui.data.items[id])

	ui._enter_shop("weapon")
	var sword: Button = ui.shop_entries.sword
	var highlight: StyleBoxFlat = sword.get_theme_stylebox("normal")
	_check(ui.selected_item == "sword" and highlight.border_color == ui.shop_view.GOLD and ui.shop_buy.disabled,
		"The Weaponsmith should open with the equipped weapon highlighted")
	ui.shop_entries.mace.pressed.emit()
	_check(ui.selected_item == "mace" and sword.accessibility_description == "Equipped"
		and sword.find_children("*", "Label", true, false).any(func(label: Label) -> bool: return label.text == "Equipped"),
		"Browsing weapons should keep the equipped weapon marked")
	_check(_find_button(ui.shop_view.kit, "Short sword") != null and ui.shop_stage.left_loadout.weapon == "mace",
		"The Weaponsmith should keep the equipped weapon in the comparison panel when trying another weapon")
	ui.shop_entries.dagger.pressed.emit()
	_press_key(KEY_P)
	_check(ui.selected_item == "dagger" and ui.shop_entries.dagger.accessibility_description == "Equipped"
		and ui.shop_entries.sword.accessibility_description.is_empty() and _find_button(ui.shop_view.kit, "Dagger") != null,
		"Equipping another weapon should move the equipped marker")

	ui._enter_shop("armor")
	_check(ui.selected_item == "leather_chest" and ui.shop_entries.leather_chest.accessibility_description == "Equipped",
		"The Armory should open with the equipped chest plate selected and marked")
	ui._select_armor("pants")
	_check(ui.selected_item == "leather_pants" and ui.shop_buy.text == "Equipped",
		"Each armor tab should select the gear equipped in that slot")
	ui._select_armor("helmet")
	_check(ui.selected_item == "leather_helmet" and ui.shop_entries.leather_helmet.accessibility_description.is_empty(),
		"An empty armor slot should show the first item without an equipped marker")
	ui.queue_free()

func _check_equipment_shop_controls() -> void:
	var ui = Game.instantiate()
	root.add_child(ui)
	ui.sound.enabled = false
	ui.game.create(0, "Shop test", 0, 0, ui.data.build_stats("weapon", 10))
	ui.game.state.level = 16
	ui.game.state.gold = 300
	ui.game.state.stats.Magic = 17
	ui.show_town()
	_press_key(KEY_A)
	_press_key(KEY_4)
	_check(ui.current_screen == "shop" and ui.armor_slot == "shoes" and ui.shop_entries.has("leather_shoes"),
		"Town and armor category shortcuts should open the requested stock")
	_press_key(KEY_C)
	_check(ui.current_screen == "character" and ui.find_children("*", "Label", true, false).any(
		func(label: Label) -> bool: return label.text == "Shop test"), "Character should show the current gladiator")
	_press_escape()
	_check(ui.current_screen == "shop" and ui.shop_type == "armor" and ui.armor_slot == "shoes",
		"Closing Character should return to the same armor category")
	_press_key(KEY_M)
	_press_key(KEY_2)
	_check(ui.magic_category == "Utility" and ui.shop_entries.has("magic_shield"),
		"Magic should use its own numbered tabs")
	ui.shop_entries.magic_shield.pressed.emit()
	var preview: Control = ui.shop_stage
	_check(preview._spell_preview_casting(), "Selecting a spell should start its preview automatically")
	preview._process(4.99)
	_check(not preview._spell_preview_casting(), "The preview should rest before the next cast")
	preview._process(.02)
	_check(preview._spell_preview_casting() and is_equal_approx(preview.elapsed, .01),
		"The preview should cast again five seconds after the first cast started")
	_press_key(KEY_P)
	_check(ui._spell_at(0) == "magic_shield", "Buying a spell should use the first open slot")
	var slot_tile: Button = ui.shop_view.kit.get_child(0)
	var slot_labels: Array[Node] = slot_tile.find_children("*", "Label", true, false)
	_check(slot_tile.accessibility_name == "Slot 1, Magic Shield" and slot_labels.size() == 2
		and slot_labels[0].text == "1" and slot_labels[1].text == "Magic Shield",
		"A prepared spell tile should show its number and name without repeating its stats")
	ui._select_spell_slot(2)
	_press_key(KEY_1)
	ui.shop_entries.fireball.pressed.emit()
	_check(ui.shop_spell_slot == 2, "A chosen empty spell slot should stay selected while browsing")
	ui._select_spell_slot(0)
	var gold: int = ui.game.state.gold
	_press_key(KEY_P)
	_check(ui.spell_checkout == ui.SpellCheckout.PICK_SLOT and ui.game.state.gold == gold and ui._spell_at(0) == "magic_shield",
		"An occupied spell slot should open the loadout picker before spending gold")
	_press_key(KEY_DOWN)
	_check(ui.spell_checkout_slot == 1 and _find_button(ui.shop_view.kit_footer, "Prepare") != null,
		"The picker should offer a free slot as an alternative to replacement")
	_press_escape()
	_check(ui.spell_checkout == ui.SpellCheckout.CLOSED and ui.current_screen == "shop" and ui.selected_item == "fireball"
		and ui._spell_at(0) == "magic_shield" and ui.game.state.gold == gold, "Back should cancel checkout and keep the current shop selection")
	_press_key(KEY_P)
	_press_key(KEY_DOWN)
	_press_key(KEY_P)
	_check(ui._spell_at(0) == "magic_shield" and ui._spell_at(1) == "fireball"
		and ui.game.state.gold == gold - int(ui.data.items.fireball.price), "Preparing in the alternative slot should preserve other spells")

	_check(ui.game.purchase(ui.data.items.push, 2).is_empty(), "The replacement fixture should fill the remaining slot")
	ui.show_shop()
	ui.shop_entries.pocket_anvil.pressed.emit()
	gold = int(ui.game.state.gold)
	_press_key(KEY_P)
	_press_key(KEY_DOWN)
	_press_key(KEY_DOWN)
	_press_key(KEY_UP)
	_check(ui.spell_checkout_slot == 1 and _find_button(ui.shop_view.kit_footer, "Replace") != null,
		"Both arrows should move the replacement target within the prepared loadout")
	_press_key(KEY_P)
	_check(ui._spell_at(0) == "magic_shield" and ui._spell_at(1) == "pocket_anvil" and ui._spell_at(2) == "push"
		and ui.game.state.gold == gold - int(ui.data.items.pocket_anvil.price), "Confirming should replace only the highlighted spell and charge once")
	_press_key(KEY_DELETE)
	_check(ui.spell_checkout == ui.SpellCheckout.CLEAR and ui._spell_at(1) == "pocket_anvil",
		"Clearing a prepared spell should wait for in-panel confirmation")
	_find_button(ui.shop_view.kit_footer, "Cancel").pressed.emit()
	_check(ui.spell_checkout == ui.SpellCheckout.CLOSED and ui._spell_at(1) == "pocket_anvil", "Cancel should preserve the prepared spell")
	_press_key(KEY_DELETE)
	_press_key(KEY_P)
	_check(ui._spell_at(1).is_empty(), "Confirming Clear slot should remove the prepared spell")
	_press_key(KEY_3)
	ui.shop_entries.armor_potion.pressed.emit()
	_press_key(KEY_P)
	_check(ui.game.state.loadout.draught == "armor_potion" and ui._spell_at(1).is_empty(),
		"Potions should equip in the pouch without taking a spell slot")
	ui.free()

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
	_check(ui.shop_buy.disabled and ui.shop_buy.accessibility_name.begins_with("Locked") and ui.shop_requirements.visible,
		"The mace's unlock requirement should be visible")
	_press_escape()
	_check(ui.current_screen == "town", "Escape should return from a shop to town")
	_press_escape()
	if _check(is_instance_valid(ui.settings_popup), "Escape in town should open the pause menu"):
		_check(_find_button(ui.settings_popup, "Settings") != null and _find_button(ui.settings_popup, "Audio") == null
			and _find_button(ui.settings_popup, "Quit") != null, "Pause should offer Settings and Quit, with Audio inside Settings")
		_find_button(ui.settings_popup, "Resume").pressed.emit()
	ui.game.state.xp = int(ui.data.rules.xp_levels[1]) - 1
	ui.show_arena()
	_press_key(KEY_U)
	_check(ui.current_screen == "arena" and ui.game.scouted_bout(true).is_empty(),
		"The tournament shortcut should respect the level requirement")
	_press_key(KEY_R)
	_check(ui.current_screen == "scout" and not ui.game.has_active_bout(), "Scouting should open the face-off before combat")
	var offer: Dictionary = ui.game.scouted_bout().duplicate(true)
	_find_button(ui, "Back").pressed.emit()
	_check(ui.current_screen == "arena", "Players should be able to leave the face-off")
	_find_button(ui, offer.rival.name).pressed.emit()
	_check(ui.game.scouted_bout() == offer, "Reopening the face-off should keep its opponent")
	_press_key(KEY_F)
	_check(ui.current_screen == "battle" and not ui.shell.visible and _find_button(ui, "Leave bout") == null,
		"Combat must occupy the game view and offer no way back during the bout")
	_press_escape()
	_check(ui.current_screen == "battle" and not is_instance_valid(ui.settings_popup), "Escape should keep the player in the bout")
	var attack: Button = ui.fight.hud.action_buttons.attack
	_check(not ui.fight.hud.pack.visible, "A starter fight should only show Pack when something is equipped")
	_check(not ui.fight.hud.action_buttons.has("lunge") and attack.disabled
		and attack.accessibility_description.contains("Out of weapon reach"), "The HUD should require movement from the starting gap")
	attack.pressed.emit()
	_check(ui.fight.bout.turn == 0, "Pressing Attack out of range must not spend a turn")
	_check(not ui.fight.hud.action_buttons.quick.visible and not ui.fight.hud.action_buttons.power.visible,
		"Quick and Power should be hidden outside weapon reach")
	_check(ui.fight.hud.action_buttons.jump.accessibility_description.contains("3 spaces toward") and not ui.fight.hud.action_buttons.jump.disabled,
		"The leap button should show the available movement distance")
	_check(ui.fight.hud.action_buttons.jump_back.accessibility_description.contains("3 spaces away") and not ui.fight.hud.action_buttons.jump_back.disabled,
		"The backward leap should be available at the starting position")
	var player: Dictionary = ui.fight.bout.fighters[0]
	var rival_start: int = ui.fight.bout.positions[1]
	var original_stamina := int(player.stats.Stamina)
	player.stats.Stamina = 10
	ui.fight.bout.positions[1] = rival_start - 1
	ui.fight.refresh()
	_check(attack.accessibility_name == "Lunge" and not attack.disabled
		and attack.accessibility_description.contains("26 stamina · Moves 3 spaces")
		and ui.fight.hud.action_buttons.jump_back.accessibility_description.contains("4 spaces away"),
		"The battle HUD should preview the longer lunge and leap at ten Stamina")
	player.stats.Stamina = original_stamina
	ui.fight.bout.positions[1] = ui.fight.bout.positions[0] + 2
	ui.fight.refresh()
	_check(attack.accessibility_name == "Lunge" and not attack.disabled and attack.accessibility_description.contains("16 stamina"),
		"The sword button should become Lunge in short range and show the stamina cost")
	ui.fight.bout.positions[1] = ui.fight.bout.positions[0] + 1
	ui.fight.refresh()
	_check(ui.fight.hud.action_buttons.quick.visible and ui.fight.hud.action_buttons.power.visible
		and not attack.disabled and attack.accessibility_name == "Normal attack", "Close range should expose all three attack styles")
	var rival: Dictionary = ui.fight.bout.fighters[1]
	rival.armor = 2
	rival.max_armor = 6
	rival.guarding = true
	ui.fight.refresh()
	var power = ui.fight.hud.action_buttons.power
	var hit := roundi(ui.fight.bout.chance("power") * 100.0)
	var block := roundi(Duel.block_chance(ui.fight.bout.rules, rival.stats.Defence, true) * 100.0)
	_check(power.summary.text.contains("%d%% hit" % hit) and power.accessibility_description.contains("%d%% block" % block)
		and power.accessibility_description.contains("2 armor and"), "Power should show its live hit chance, block chance, and armor absorption")
	rival.exposed = true
	ui.fight.refresh()
	_check(power.accessibility_description.contains("0% block"), "An exposed rival cannot block")
	var starting_stamina: int = ui.fight.bout.fighters[0].energy
	ui.fight.bout.fighters[0].energy = 0
	ui.fight.refresh()
	_check(attack.disabled and attack.accessibility_description.contains("Requires 4 stamina"), "The HUD should explain why an exhausted attack is disabled")
	_check(ui.fight.hud.fighter_cards[0].bars[2].readout.text == "0/%d" % player.max_energy,
		"Depleted stamina should show zero and the full capacity")
	_check(ui.fight.hud.fighter_cards[1].bars[1].readout.text == "2/6", "Armor readouts should show the rival's current and maximum points")
	attack.pressed.emit()
	_check(ui.fight.bout.turn == 0, "The fight must reject an exhausted attack even if the button signal fires")
	ui.fight.bout.fighters[0].energy = starting_stamina
	ui.fight.bout.positions[1] = rival_start
	ui.fight.refresh()
	for action_button in ui.fight.hud.action_buttons.values():
		_check(not action_button.caption.text.is_empty() and not action_button.accessibility_name.is_empty(),
			"Combat actions should have visible captions and accessible names")
	ui.fight.hud.settings_button.pressed.emit()
	if _check(is_instance_valid(ui.settings_popup), "Settings should open from combat"):
		_check(_find_button(ui.settings_popup, "Simulator") == null, "Combat settings should keep the player in the bout")
		var turn: int = ui.fight.bout.turn
		ui.fight.play_action("advance")
		_check(ui.fight.bout.turn == turn, "Settings should block combat actions while open")
		ui.settings_popup.hide()
	ui.fight.bout.winner = 0
	var outcome: Dictionary = ui.game.record_turn("attack", 0)
	var arena_layer: Control = ui.fight
	var arena_stage: Control = ui.fight.stage
	ui.fight.finished.emit(outcome)
	_check(ui.current_screen == "result" and ui.fight == arena_layer and ui.fight.stage == arena_stage
		and not ui.shell.visible and arena_stage.result_winner == 0 and not ui.fight.hud.action_layer.visible,
		"The result should celebrate the winner in the original arena and hide the combat controls")
	var result_panel := arena_layer.get_node_or_null("BoutResults")
	_check(result_panel != null and _find_button(result_panel, "Spend level-up points") != null,
		"The results bar should show the required allocation")
	_press_escape()
	_check(ui.current_screen == "allocate", "Escape from results should respect a pending level-up")
	_check(ui.stat_labels.Stamina.tooltip_text.contains("Leap 3 spaces"), "The Stamina tooltip should show the current leap")
	var stamina_button: Button = ui.allocation_controls.Stamina.plus
	for point in 8:
		ui._change_point("Stamina", 1)
	_check(ui.stat_labels.Stamina.tooltip_text.contains("Leap 4 spaces"), "The Stamina tooltip should update after reaching the threshold")
	_check(ui.allocation_controls.Stamina.plus == stamina_button and ui.allocation_metrics.energy.text.contains("→"),
		"Level-up should update the Stamina projection without replacing its controls")
	ui.queue_free()

func _check_regular_loss_navigation() -> void:
	var ui = Game.instantiate()
	root.add_child(ui)
	ui.game.create(0, "After a loss", 0, 0, ui.data.build_stats("weapon", 10))
	ui.game.state.xp = int(ui.data.rules.xp_levels[1]) - 1
	ui._open_bout(ui.game.start_bout(false, 42))
	ui.fight.bout.winner = 1
	ui.fight.bout.history.append({"yield_threshold_reached": true})
	var outcome: Dictionary = ui.game.record_turn("attack", 1)
	ui.fight.finished.emit(outcome)
	var result_panel: Node = ui.fight.get_node("BoutResults")
	var meters := result_panel.find_children("*", "ProgressBar", true, false)
	var labels := result_panel.find_children("*", "Label", true, false)
	var announcement: Node = ui.fight.get_node("BoutAnnouncement")
	var announcement_labels := announcement.find_children("*", "Label", true, false)
	_check(meters.size() == 1 and is_equal_approx(meters[0].value, float(ui.game.state.xp)),
		"A regular loss should keep the current XP visible")
	_check(announcement_labels.size() == 1 and announcement_labels[0].text == "DEFEAT",
		"A yield should have a plain defeat announcement")
	_check(labels.any(func(label: Label) -> bool: return label.text == "%+d gold" % outcome.gold),
		"A regular loss should show the gold penalty in the reward bar")
	_check(_find_button(ui.fight, "Retry bout") == null and _find_button(ui.fight, "Return to town") != null
		and _find_button(ui.fight, "Next Bout") != null, "Results after a loss should offer town and the next bout")
	ui.show_arena()
	_check(ui.current_screen == "arena" and _find_button(ui, "Retry last bout") == null,
		"The arena should offer scouting without a retry")
	var scout := _find_button(ui, "Scout rival")
	if _check(scout != null and not scout.disabled, "Scouting should be available after defeat"):
		scout.pressed.emit()
		_check(ui.current_screen == "scout" and not ui.game.scouted_bout().is_empty() and not ui.game.has_active_bout(),
			"Scouting should open a fresh face-off after defeat")
	ui.queue_free()

func _press_escape() -> void:
	_press_key(KEY_ESCAPE)

func _press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func _check_tournament_navigation() -> void:
	var ui = Game.instantiate()
	root.add_child(ui)
	ui.game.create(3, "Contender", 0, 0, ui.data.build_stats("weapon", 10))
	ui.game.state.level = 4
	ui.game.state.xp = ui.data.rules.xp_levels[3]
	ui.show_arena()
	_press_key(KEY_U)
	_check(_find_button(ui, "Back") != null and not ui.game.tournament_in_progress(), "Scouting should leave the first tournament optional")
	_find_button(ui, "Fight to the death").pressed.emit()
	_check(ui.current_screen == "battle" and ui.game.tournament_in_progress(), "Entering the first round should lock the tournament")
	ui.fight.bout.winner = 0
	var outcome: Dictionary = ui.game.record_turn("attack", 0)
	ui.fight.finished.emit(outcome)
	_check(_find_button(ui.fight, "Next Match") != null and _find_button(ui.fight, "Return to town") == null
		and not ui.game.can_scout(false), "Between rounds the only destination should be the next tournament match")
	_press_key(KEY_T)
	_press_escape()
	_check(ui.current_screen == "result", "Town and Back shortcuts should respect the tournament lock")
	_press_key(KEY_N)
	_check(ui.current_screen == "scout" and _find_button(ui, "Back") == null and _find_button(ui, "Title screen") == null,
		"Next Match should open a locked face-off")
	var next_offer: Dictionary = ui.game.scouted_bout(true)
	_press_key(KEY_C)
	_check(ui.current_screen == "character" and _find_button(ui, "Title screen") == null,
		"The shared header should offer read-only character access during a tournament")
	_press_key(KEY_A)
	_check(ui.current_screen == "character", "A locked character sheet should block shop navigation")
	_press_escape()
	_check(ui.current_screen == "scout" and ui.game.scouted_bout(true) == next_offer,
		"Leaving Character should return to the same locked face-off")
	ui._resume(3)
	var restored_offer: Dictionary = ui.game.scouted_bout(true)
	_check(ui.current_screen == "scout" and not restored_offer.is_empty()
		and restored_offer.opponent_seed == next_offer.opponent_seed and restored_offer.rival.name == next_offer.rival.name,
		"Reloading between rounds should return to the same face-off")
	_press_escape()
	_check(ui.current_screen == "scout", "Back must keep the player in the tournament face-off")
	_find_button(ui, "Fight to the death").pressed.emit()
	ui.fight.bout.winner = 0
	outcome = ui.game.record_turn("attack", 0)
	ui.fight.finished.emit(outcome)
	_check(not ui.game.tournament_in_progress() and _find_button(ui.fight, "Spend level-up points") != null,
		"Beating the champion should release the lock and offer the required level-up")
	ui.free()

func _check_tournament_practice() -> void:
	var ui = Game.instantiate()
	root.add_child(ui)
	ui.game.create(0, "Practice contender", 0, 0, ui.data.build_stats("weapon", 40))
	ui.game.state.level = 4
	ui.game.state.xp = ui.data.rules.xp_levels[3]
	var snapshot: Dictionary = ui.game.start_bout(true, 42)
	var gold: int = ui.game.state.gold
	ui._open_bout(snapshot)
	_check(snapshot.rewards.lethal_defeat and not ui.fight.bout.regular_bout,
		"Practice should keep tournament combat rules and the saved bout's original conditions")
	ui.fight.bout.winner = 1
	var outcome: Dictionary = ui.game.record_turn("attack", 1)
	ui.fight.finished.emit(outcome)
	if not OS.is_debug_build():
		_check(outcome.fallen and not outcome.practice_defeat, "Release defeats should end the career")
		ui.free()
		return
	_check(outcome.practice_defeat and not outcome.fallen and not ui.game.has_active_bout()
		and ui.game.state.gold == gold and ui.game.state.tournament == 0,
		"Debug defeats should automatically preserve the career, gold, and tournament round")
	var next := _find_button(ui.fight, "Next Match")
	if _check(next != null, "A first-round practice defeat should offer the next tournament match"):
		next.pressed.emit()
		var offer: Dictionary = ui.game.scouted_bout(true)
		_check(ui.current_screen == "scout" and offer.get("round") == 0
			and offer.get("opponent_seed") == snapshot.opponent_seed,
			"Continuing after a practice defeat should scout the same tournament rival")
	ui.free()

func _check_fight_turn_flow() -> void:
	var ui = Game.instantiate()
	root.add_child(ui)
	ui.game.create(0, "Turn flow", 0, 0, ui.data.build_stats("weapon", 10))
	var snapshot: Dictionary = ui.game.start_bout(false, 42)
	ui._open_bout(snapshot)
	_check(ui.fight.stage.kind == "battle" and ui.fight.stage.full_arena, "The fight scene should initialize a full arena stage")
	ui.fight.play_action("advance")
	if not _check(ui.game.state.active_bout.actions == ["advance"], "Save the player's action as soon as the turn resolves"):
		ui.queue_free()
		return
	await ui.fight.stage.turn_animation_finished
	await process_frame
	_check(ui.game.state.active_bout.actions.size() == 2 and not ui.fight.hud.action_layer.visible,
		"The opponent should commit one reply while the action controls are locked")
	await ui.fight.stage.turn_animation_finished
	await process_frame
	_check(ui.fight.bout.active == 0 and ui.fight.hud.action_layer.visible,
		"The action controls should reopen after the opponent's animation")
	var history: Array = ui.fight.bout.history.duplicate(true)
	ui._open_bout(snapshot)
	_check(ui.fight.bout.history == history, "Reopening the fight scene should replay both recorded turns")
	ui.queue_free()

func _check_music_cues() -> void:
	var ui = Game.instantiate()
	root.add_child(ui)
	ui.venue_music_enabled = true
	ui.town_music_enabled = true
	ui.current_screen = "town"
	_check(ui._music_for_screen() == ui.TOWN_THEME, "The town should select its own theme")
	ui.current_screen = "shop"
	for kind in ["armor", "weapon", "spell"]:
		ui.shop_type = kind
		_check(ui._music_for_screen() == ui.SHOP_THEMES[kind], "Each shop should select its own cue")
	ui.current_screen = "scout"
	_check(ui._music_for_screen() == ui.PRE_FIGHT_THEME, "A face-off should select the pre-fight cue")
	ui.fight = FightScreen.instantiate()
	ui.add_child(ui.fight)
	ui.current_screen = "battle"
	for arena in ui.data.arenas.size():
		ui.fight.stage.arena = arena
		var track: AudioStreamOggVorbis = ui._music_for_screen()
		_check(track.resource_path == Content.arena(arena).music and track.loop, "Each arena should select a looping combat track")
	var stats: Dictionary = ui.data.stats_empty()
	var fighter: Dictionary = ui.data.fighter("Music test", stats, {})
	ui.fight.bout = Duel.new(ui.data, fighter, fighter, 42)
	ui.current_screen = "result"
	for winner in [0, 1]:
		ui.fight.bout.winner = winner
		var track: AudioStreamOggVorbis = ui._music_for_screen()
		_check(track == (ui.VICTORY_THEME if winner == 0 else ui.DEFEAT_THEME)
			and track.loop and track.loop_offset > 0, "A result should select its own cue and play its intro once")
	ui.venue_music_enabled = false
	_check(ui._music_for_screen() == null, "The shop and arena toggle should mute result music")
	ui.free()

func _check_display_settings() -> void:
	var path := "user://settings.cfg"
	var had_settings := FileAccess.file_exists(path)
	var previous := FileAccess.get_file_as_bytes(path) if had_settings else PackedByteArray()
	for stored_mode in [-1, 0, 1, 2]:
		var settings := ConfigFile.new()
		if stored_mode < 0:
			settings.set_value("display", "fullscreen_bouts", true)
		else:
			settings.set_value("display", "mode", stored_mode)
		_check(settings.save(path) == OK, "The display settings fixture should be writable")
		var ui = Game.instantiate()
		root.add_child(ui)
		ui._show_settings()
		var display := _find_button(ui.settings_popup, "Display") as OptionButton
		if _check(display != null and display.item_count == 2, "Settings should offer only two display modes"):
			_check(display.get_item_text(0) == "Windowed" and display.get_item_text(1) == "Fullscreen",
				"The display choices should read Windowed and Fullscreen")
			var expected_index := 1 if stored_mode == 2 else 0
			_check(display.selected == expected_index,
				"Display mode %d should reopen with the correct selection" % stored_mode)
			var next_index := 1 - expected_index
			display.select(next_index)
			display.item_selected.emit(next_index)
			var saved := ConfigFile.new()
			_check(saved.load(path) == OK and saved.get_value("display", "mode", -1) == display.get_item_id(next_index)
				and not saved.has_section_key("display", "fullscreen_bouts"),
				"Changing the display setting should save the selected mode and remove the legacy key")
		ui.free()
	if had_settings:
		_check(FileAccess.open(path, FileAccess.WRITE).store_buffer(previous), "Restore the previous settings after the display test")
	else:
		DirAccess.remove_absolute(path)

func _check_control_settings() -> void:
	var ui = Game.instantiate()
	root.add_child(ui)
	ui.game.create(0, "Controls test", 0, 0, ui.data.build_stats("weapon", 10))
	var legacy := ConfigFile.new()
	legacy.set_value("controls", "armor_helmet", KEY_1)
	legacy.set_value("controls", "magic_damage", KEY_G)
	legacy.set_value("controls", "armor_pants", KEY_H)
	legacy.set_value("controls", "magic_potions", KEY_L)
	ui._load_key_bindings(legacy)
	_check(ui.key_bindings.shop_tab_1 == KEY_G and ui.key_bindings.shop_tab_3 == KEY_H,
		"Shared shop tabs should keep a customized legacy key, preferring Armory if both keys were customized")
	ui._load_key_bindings(ConfigFile.new())
	ui.show_town()
	ui._show_pause()
	_find_button(ui.settings_popup, "Settings").pressed.emit()
	_check(paused and ui.settings_shade.visible and not ui.content.can_process() and ui.settings_popup.can_process(),
		"Settings should dim and freeze the screen while its controls stay active")
	_check(_find_button(ui.settings_popup, "Display") != null and _find_button(ui.settings_popup, "Town music") != null,
		"Controls should be shown alongside display and audio settings")
	var choices := {"Back / Pause": KEY_B, "Return to town": KEY_J, "Next bout or match": KEY_M, "Tab 2 · Chest / Utility": KEY_5}
	for caption in choices:
		_find_button(ui.settings_popup, "Rebind " + caption).pressed.emit()
		_press_key(choices[caption])
	_press_key(KEY_B)
	_check(ui.settings_popup == null and not paused and not ui.settings_shade.visible,
		"The new Back key should close Settings, lift the shade, and resume the game")
	ui._enter_shop("armor")
	_press_key(KEY_4)
	_press_key(KEY_5)
	_check(ui.armor_slot == "chest", "The shared key should select Chest in the Armory")
	ui._enter_shop("spell")
	_press_key(KEY_5)
	_check(ui.magic_category == "Utility", "The shared key should select Utility in the Magic shop")
	ui.show_arena()
	_press_escape()
	_check(ui.current_screen == "arena", "The old Back key should stop navigating after a rebind")
	_press_key(KEY_B)
	_check(ui.current_screen == "town", "The new Back key should navigate to town")
	var snapshot: Dictionary = ui.game.start_bout(false, 42)
	ui._open_bout(snapshot)
	ui.fight.bout.winner = 0
	var outcome: Dictionary = ui.game.record_turn("attack", 0)
	ui.fight.finished.emit(outcome)
	_check(_find_button(ui.fight, "Next Bout") != null, "Regular victories should offer the next bout")
	_press_key(KEY_N)
	_check(ui.current_screen == "result", "The old Next key should stop navigating after a rebind")
	_press_key(KEY_M)
	_check(ui.current_screen == "scout" and not ui.game.scouted_bout().is_empty(), "The new Next key should scout the regular rival")
	ui.game.state.xp = 0
	_find_button(ui, "Fight").pressed.emit()
	ui.fight.bout.winner = 0
	outcome = ui.game.record_turn("attack", 0)
	ui.fight.finished.emit(outcome)
	_press_key(KEY_T)
	_check(ui.current_screen == "result", "The old Town key should stop navigating after a rebind")
	_press_key(KEY_J)
	_check(ui.current_screen == "town", "The new Town key should leave a regular result for town")
	ui.free()
	var reloaded = Game.instantiate()
	root.add_child(reloaded)
	_check(reloaded.key_bindings.back == KEY_B and reloaded.key_bindings.town == KEY_J and reloaded.key_bindings.next == KEY_M,
		"Changed navigation and result bindings should survive restarting the game")
	_check(reloaded.key_bindings.shop_tab_2 == KEY_5 and reloaded.key_bindings.shop_tab_5 == KEY_2,
		"Shared shop tabs and their swapped keys should survive restarting the game")
	reloaded._show_settings()
	_find_button(reloaded.settings_popup, "Reset defaults").pressed.emit()
	_check(reloaded.key_bindings == reloaded.DEFAULT_KEYS, "Reset should restore every shortcut default")
	reloaded.free()

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
