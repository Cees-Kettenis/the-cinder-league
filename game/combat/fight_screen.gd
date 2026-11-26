extends Control
## Presents a single bout. Duel applies the combat rules and Campaign records each turn.

signal settings_requested
signal finished(outcome: Dictionary)

const Stage = preload("res://game/combat/stage.gd")
const BattleHud = preload("res://game/combat/battle_hud.gd")
const Campaign = preload("res://game/campaign/campaign.gd")
const Duel = preload("res://game/combat/duel.gd")
const Foley = preload("res://game/audio/foley.gd")
const Content = preload("res://game/catalog/content_catalog.gd")

@onready var stage: Stage = $CombatStage
@onready var hud: BattleHud = $BattleHud

var bout: Duel
var _campaign: Campaign
var _sound: Foley
var _locked := false
var _input_blocked := false

## Configure the stage before it enters the tree so it loads the correct arena on its first draw.
func configure(campaign: Campaign, duel: Duel, snapshot: Dictionary, sound: Foley) -> void:
	_campaign = campaign
	bout = duel
	_sound = sound
	_locked = bout.active != 0
	var combat_stage: Stage = $CombatStage
	combat_stage.kind = "battle"
	combat_stage.full_arena = true
	combat_stage.data = _campaign.data
	combat_stage.skin = int(_campaign.state.skin)
	combat_stage.hair = int(_campaign.state.hair)
	combat_stage.has_pits = bout.has_attack_styles()
	combat_stage.lethal_bout = snapshot.rewards.get("lethal_defeat", false)
	combat_stage.arena = int(snapshot.arena)
	combat_stage.arena_width = int(bout.rules.arena_size)
	combat_stage.bout_items = snapshot.equipment
	combat_stage.left_loadout = bout.fighters[0].loadout
	combat_stage.set_rival(bout.fighters[1], int(_campaign.state.get("level", 1)))

func start(font: Font, input_blocked: bool) -> void:
	_input_blocked = input_blocked
	hud.build(font)
	hud.action_selected.connect(play_action)
	hud.settings_requested.connect(func() -> void: settings_requested.emit())
	hud.resized.connect(_place_actions)
	refresh()
	# A resumed bout can open after the player has acted, with the rival's turn still pending.
	if bout.active == 1:
		_play_opponent_turn()
	else:
		_offer_auto_sleep()

func music() -> AudioStream:
	var path: String = Content.arena(stage.arena).get("music", "")
	return load(path) if not path.is_empty() else null

func refresh() -> void:
	stage.positions = bout.positions.duplicate()
	stage.queue_redraw()
	hud.refresh(bout, _locked)
	hud.show_save_error(_campaign.save_error)
	_place_actions()

func set_input_blocked(blocked: bool) -> void:
	_input_blocked = blocked
	if not blocked:
		_offer_auto_sleep()

func celebrate() -> void:
	_locked = true
	refresh()
	hud.show_save_error("")
	stage.celebrate(bout.winner)

func _place_actions() -> void:
	hud.place_actions(stage.fighter_feet(0), stage.fighter_height())

func _offer_auto_sleep() -> void:
	if _input_blocked or _locked or bout.active != 0 or not bout.must_sleep():
		return
	var turn := bout.turn
	await get_tree().create_timer(.60).timeout
	# The action may have changed or the player may have left the fight during the delay.
	if is_inside_tree() and turn == bout.turn and bout.must_sleep():
		play_action("sleep")

func play_action(action: String) -> void:
	if _input_blocked or _locked or bout.active != 0 or not bout.reason(action).is_empty():
		return
	# Keep controls locked through both animations so rapid input cannot spend another turn.
	_locked = true
	await _play_turn(action)
	if is_inside_tree() and bout.winner == -2:
		await _play_opponent_turn()

func _play_opponent_turn() -> void:
	await _play_turn(bout.choose(bout.fighters[1].style))
	if not is_inside_tree() or bout.winner != -2:
		return
	_locked = false
	refresh()
	_offer_auto_sleep()

func _play_turn(action: String) -> void:
	var event := bout.act(action)
	# Save the resolved turn before waiting for animation so closing mid-strike can still resume it.
	var outcome := _campaign.record_turn(event.action, bout.winner)
	hud.action_layer.hide()
	var fighter: Dictionary = bout.fighters[event.side]
	var presentation := event
	if event.action == "cast_reserve":
		# Reserve spells share the cast animation and keep their own action in the saved history.
		presentation = event.duplicate()
		presentation.action = "cast"
	stage.animate(presentation)
	_sound.begin_turn(presentation, int(event.get("spell_art", 0)))
	await stage.impact_reached
	if not is_inside_tree():
		return
	# Play the impact sound and reveal the resolved damage together on contact.
	_sound.impact(presentation, int(fighter.weapon.get("art", 0)))
	refresh()
	await stage.turn_animation_finished
	if is_inside_tree() and bout.winner != -2:
		finished.emit(outcome)
