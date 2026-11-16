extends Node
## Autoload "AudioSettings". Creates three audio buses and keeps the mix
## priority: dialogue loudest, then sound effects, then background music.
## Also stores the SFX / Music on-off switches from the Settings menu
## (saved to user://settings.cfg so they stick between sessions).
##
## Any AudioStreamPlayer left on the Master bus is moved to the SFX bus
## automatically, so new sound effects are covered without extra code.
## Voice lines set `bus = "Voice"` and the music sets `bus = "Music"`.

const VOICE := "Voice"
const SFX := "SFX"
const MUSIC := "Music"

## Bus levels (dB). Change these to rebalance the whole game.
const LEVELS := {
	VOICE: 0.0,
	SFX: -10.0,
	MUSIC: -17.0,
}

const SAVE_PATH := "user://settings.cfg"

var sfx_enabled := true
var music_enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in [VOICE, SFX, MUSIC]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), LEVELS[bus])
	_load()
	_apply()
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is AudioStreamPlayer and node.bus == &"Master":
		node.bus = SFX
	elif node is AudioStreamPlayer2D and node.bus == &"Master":
		node.bus = SFX


func set_sfx_enabled(on: bool) -> void:
	sfx_enabled = on
	_apply()
	_save()


func set_music_enabled(on: bool) -> void:
	music_enabled = on
	_apply()
	_save()


func _apply() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(SFX), not sfx_enabled)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MUSIC), not music_enabled)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		sfx_enabled = cfg.get_value("audio", "sfx", true)
		music_enabled = cfg.get_value("audio", "music", true)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("audio", "sfx", sfx_enabled)
	cfg.set_value("audio", "music", music_enabled)
	cfg.save(SAVE_PATH)
