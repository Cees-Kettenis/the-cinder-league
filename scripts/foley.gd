extends Node

const Duel = preload("res://scripts/duel.gd")

const CLIPS := {
	"step": preload("res://audio/step.wav"),
	"leap": preload("res://audio/leap.wav"),
	"swing": preload("res://audio/swing.wav"),
	"blade_hit": preload("res://audio/blade_hit.wav"),
	"mace_hit": preload("res://audio/mace_hit.wav"),
	"block": preload("res://audio/block.wav"),
	"guard": preload("res://audio/guard.wav"),
	"rest": preload("res://audio/rest.wav"),
	"taunt": preload("res://audio/taunt.wav"),
	"potion": preload("res://audio/potion.wav"),
	"fireball": preload("res://audio/fireball.wav"),
	"lightning": preload("res://audio/lightning.wav"),
	"meteor": preload("res://audio/meteor.wav"),
	"hellfire": preload("res://audio/hellfire.wav"),
	"buy": preload("res://audio/buy.wav"),
	"equip": preload("res://audio/equip.wav"),
	"shop_bell": preload("res://audio/shop-bell.wav"),
	"victory": preload("res://audio/victory.wav"),
	"defeat": preload("res://audio/defeat.wav"),
	"level_up": preload("res://audio/level_up.wav"),
}
const SPELLS: Array[String] = ["fireball", "lightning", "meteor", "hellfire"]
const CROWD_LOOP = preload("res://audio/arena-crowd.ogg")
var enabled := true
var _effects: AudioStreamPlayer
var _contact: AudioStreamPlayer
var _crowd: AudioStreamPlayer
var _crowd_requested := false
var _crowd_fade: Tween

func _ready() -> void:
	_effects = _player(-9.0)
	_contact = _player(-12.0)
	_crowd = _player(-80.0)
	_crowd.stream = CROWD_LOOP

func _player(volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.volume_db = volume
	add_child(player)
	return player

func stop() -> void:
	_effects.stop()
	_contact.stop()
	if _crowd_fade != null:
		_crowd_fade.kill()
	_crowd_requested = false
	_crowd.stop()
	_crowd.volume_linear = 0.0

func set_crowd(in_bout: bool) -> void:
	var wanted := in_bout and enabled
	if wanted == _crowd_requested:
		return
	_crowd_requested = wanted
	if _crowd_fade != null:
		_crowd_fade.kill()
	if wanted and not _crowd.playing:
		_crowd.play()
	_crowd_fade = create_tween()
	_crowd_fade.tween_property(_crowd, "volume_linear", db_to_linear(-16.0) if wanted else 0.0, .42)
	if not wanted:
		_crowd_fade.finished.connect(_crowd.stop)

func play(cue: String) -> void:
	_play_on(_effects, cue, 1.0)

func _play_on(player: AudioStreamPlayer, cue: String, pitch: float) -> void:
	if enabled and CLIPS.has(cue):
		player.stop()
		player.stream = CLIPS[cue]
		player.pitch_scale = pitch
		player.play()

func cast(art_index: int) -> void:
	if art_index >= 0 and art_index < SPELLS.size():
		play(SPELLS[art_index])

func begin_turn(event: Dictionary, spell_art: int) -> void:
	if event.action == "cast":
		cast(spell_art)
	else:
		play({
			"advance": "step", "retreat": "step", "jump": "leap", "jump_back": "leap", "lunge": "step",
			"guard": "guard", "sleep": "rest", "taunt": "taunt", "potion": "potion",
		}.get(event.action, ""))

func impact(event: Dictionary, weapon_art: int) -> void:
	var weapon_attack: bool = event.action in Duel.WEAPON_ACTIONS
	if weapon_attack:
		_play_on(_effects, "swing", .88 if weapon_art == 1 else 1.1)
	if event.miss or event.damage + event.armor_hit == 0:
		return
	if event.blocked or (event.armor_hit > 0 and weapon_attack):
		_play_on(_contact, "block", .87 if event.critical else 1.0)
	elif weapon_attack:
		_play_on(_contact, "mace_hit" if weapon_art == 1 else "blade_hit", .86 if event.critical else 1.0)
