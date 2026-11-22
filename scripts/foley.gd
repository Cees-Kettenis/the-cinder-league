extends Node

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
	"victory": preload("res://audio/victory.wav"),
	"defeat": preload("res://audio/defeat.wav"),
	"level_up": preload("res://audio/level_up.wav"),
}
const SPELLS: Array[String] = ["fireball", "lightning", "meteor", "hellfire"]
const SETTINGS := "user://audio.cfg"
var enabled := true
var _effects: AudioStreamPlayer
var _contact: AudioStreamPlayer

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS) == OK:
		enabled = bool(config.get_value("audio", "enabled", true))
	_effects = _player(-9.0)
	_contact = _player(-12.0)

func _player(volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.volume_db = volume
	add_child(player)
	return player

func toggle() -> void:
	enabled = not enabled
	if not enabled:
		stop()
	var config := ConfigFile.new()
	config.set_value("audio", "enabled", enabled)
	config.save(SETTINGS)

func stop() -> void:
	_effects.stop()
	_contact.stop()

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
			"advance": "step", "retreat": "step", "jump": "leap", "attack": "swing",
			"guard": "guard", "sleep": "rest", "taunt": "taunt", "potion": "potion",
		}.get(event.action, ""))

func impact(event: Dictionary, weapon_art: int) -> void:
	if event.miss or event.damage + event.armor_hit == 0:
		return
	if event.blocked or (event.armor_hit > 0 and event.action == "attack"):
		_play_on(_contact, "block", .87 if event.critical else 1.0)
	elif event.action == "attack":
		_play_on(_contact, "mace_hit" if weapon_art == 1 else "blade_hit", .86 if event.critical else 1.0)
