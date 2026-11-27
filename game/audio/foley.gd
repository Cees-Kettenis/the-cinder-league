extends Node
## Plays interface and combat cues. The fight controller calls it at windup and contact.

const Duel = preload("res://game/combat/duel.gd")

const CLIPS := {
	"step": preload("res://game/audio/sfx/combat/step.wav"),
	"leap": preload("res://game/audio/sfx/combat/leap.wav"),
	"swing": preload("res://game/audio/sfx/combat/swing.wav"),
	"blade_hit": preload("res://game/audio/sfx/combat/blade_hit.wav"),
	"mace_hit": preload("res://game/audio/sfx/combat/mace_hit.wav"),
	"block": preload("res://game/audio/sfx/combat/block.wav"),
	"guard": preload("res://game/audio/sfx/combat/guard.wav"),
	"rest": preload("res://game/audio/sfx/combat/rest.wav"),
	"taunt": preload("res://game/audio/sfx/combat/taunt.wav"),
	"potion": preload("res://game/audio/sfx/combat/potion.wav"),
	"fireball": preload("res://content/spells/fireball/cast.wav"),
	"lightning": preload("res://content/spells/lightning/cast.wav"),
	"meteor": preload("res://content/spells/meteor/cast.wav"),
	"hellfire": preload("res://content/spells/hellfire/cast.wav"),
	"prism-pop": preload("res://content/spells/prism-pop/cast.wav"),
	"pocket-anvil": preload("res://content/spells/pocket-anvil/cast.wav"),
	"royal-tantrum": preload("res://content/spells/royal-tantrum/cast.wav"),
	"dawnbolt": preload("res://content/spells/dawnbolt/cast.wav"),
	"sunseal": preload("res://content/spells/sunseal/cast.wav"),
	"buy": preload("res://game/audio/sfx/ui/buy.wav"),
	"equip": preload("res://game/audio/sfx/ui/equip.wav"),
	"shop_bell": preload("res://game/audio/sfx/ui/shop-bell.wav"),
	"victory": preload("res://game/audio/sfx/ui/victory.wav"),
	"defeat": preload("res://game/audio/sfx/ui/defeat.wav"),
	"level_up": preload("res://game/audio/sfx/ui/level_up.wav"),
}
# Spell art indexes are stored in bout events and select the same entry for sound.
const SPELLS: Array[String] = ["fireball", "lightning", "meteor", "hellfire", "prism-pop", "pocket-anvil", "royal-tantrum",
	"dawnbolt", "sunseal"]
const CROWD_LOOP = preload("res://game/audio/ambience/arena-crowd.ogg")
var enabled := true
var _effects: AudioStreamPlayer
var _contact: AudioStreamPlayer
var _crowd: AudioStreamPlayer
var _crowd_requested := false
var _crowd_fade: Tween

func _ready() -> void:
	# Separate the swing and contact players so an impact can overlap the swing.
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
	# Let the crowd fade out before stopping it. A new request cancels the previous tween.
	if not wanted:
		_crowd_fade.finished.connect(_crowd.stop)

func play(cue: String) -> void:
	_play_on(_effects, cue, 1.0)

func play_victory() -> void:
	# Raise the cue two semitones so its fanfare lands in the key of the victory music.
	_play_on(_effects, "victory", pow(2.0, 2.0 / 12.0))

func _play_on(player: AudioStreamPlayer, cue: String, pitch: float) -> void:
	if enabled and CLIPS.has(cue):
		player.stop()
		player.stream = CLIPS[cue]
		player.pitch_scale = pitch
		player.play()

func cast(art_index: int, utility: String = "") -> void:
	if not utility.is_empty():
		play({"shield": "guard", "push": "leap", "pull": "lightning", "enchant": "equip"}.get(utility, ""))
		return
	if art_index >= 0 and art_index < SPELLS.size():
		play(SPELLS[art_index])

func begin_turn(event: Dictionary, spell_art: int) -> void:
	if event.action == "cast":
		cast(spell_art, event.get("utility", ""))
	else:
		play({
			"advance": "step", "retreat": "step", "jump": "leap", "jump_back": "leap", "lunge": "step",
			"guard": "guard", "sleep": "rest", "taunt": "taunt", "potion": "potion",
		}.get(event.action, ""))

func impact(event: Dictionary, weapon_art: int) -> void:
	var weapon_attack: bool = event.action in Duel.WEAPON_ACTIONS
	if weapon_attack:
		_play_on(_effects, "swing", .88 if weapon_art == 1 else 1.1)
	if event.has("shield_absorbed"):
		_play_on(_contact, "block", 1.25)
		return
	if event.miss or (event.damage + event.armor_hit == 0 and not event.get("first_blood", false)):
		return
	if event.blocked or (event.armor_hit > 0 and weapon_attack):
		_play_on(_contact, "block", .87 if event.critical else 1.0)
	elif int(event.get("spell_art", -1)) == 5:
		_play_on(_contact, "mace_hit", .74)
	elif weapon_attack:
		_play_on(_contact, "mace_hit" if weapon_art == 1 else "blade_hit", .86 if event.critical else 1.0)
