extends Node

# Background music and the mission-complete jingle.
# The pause menu (ui/menu.gd) sets the music and voice volumes; they're saved in user://settings.cfg
# (in the browser's storage on the web build), so a restart or reload keeps it.
# Both players pause with the game, so opening the menu pauses the music.

const BACKGROUND = preload("res://sounds/background-music.mp3")
const MISSION_COMPLETE = preload("res://sounds/mission-complete.mp3")
const SETTINGS = "user://settings.cfg"

@export var volume := 0.5         # 0 to 1, until the player picks one in the menu
@export var voice_volume := 1.0   # the dialogue blips (ui/voice.gd); voice.gd keeps them quiet already

var music := AudioStreamPlayer.new()
var jingle := AudioStreamPlayer.new()
var voice   # ui/voice.gd, set by main

func _ready() -> void:
	var background: AudioStreamMP3 = BACKGROUND   # a const can't be changed directly
	background.loop = true
	music.stream = background
	add_child(music)
	jingle.stream = MISSION_COMPLETE
	add_child(jingle)

	var config := ConfigFile.new()
	if config.load(SETTINGS) == OK:
		volume = clampf(config.get_value("audio", "music_volume", volume), 0.0, 1.0)
		voice_volume = clampf(config.get_value("audio", "voice_volume", voice_volume), 0.0, 1.0)
	_apply_volume()
	music.play()

func play_mission_complete() -> void:
	jingle.play()

func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	_save()

func set_voice_volume(value: float) -> void:
	voice_volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	_save()

func _save() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS)   # keep any other settings already there
	config.set_value("audio", "music_volume", volume)
	config.set_value("audio", "voice_volume", voice_volume)
	config.save(SETTINGS)

func _apply_volume() -> void:
	music.volume_db = linear_to_db(volume)
	if voice:
		voice.set_volume(voice_volume)
