extends Node
## Background music. The Genos theme plays by default. Activating the
## ultimate crossfades to the Dragon Ball Z track; once you stop using the
## ultimate for a while it fades back to the Genos theme (picking up where
## it left off). Keeps playing through cutscenes and pauses.

const TRACK_DEFAULT := preload("res://Audio/Backing_Track/One Punch Man OST - The Cyborg Fight (Genos' Theme).mp3")
const TRACK_ULTIMATE := preload("res://Audio/Backing_Track/Dragon Ball Z Dokkan Battle_ STR Super Saiyan 3 Goku Finish Skill OST (Extended).mp3")

@export var volume_db: float = 0.0   ## on top of the Music bus level
@export var crossfade_time: float = 1.0          ## real seconds
## Real seconds after the last ultimate shot before returning to Genos.
@export var ultimate_hold_time: float = 20.0

## Loop points (seconds) so the silence at the start/end of a file is skipped.
var _loops := {}
var _resume := {}               ## track -> playback position to resume from
var _a: AudioStreamPlayer       ## current track
var _b: AudioStreamPlayer       ## spare, used for fading in
var _ultimate_on := false
var _hold := -1.0               ## real-time countdown back to Genos (-1 = off)
var _tw: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_loops[TRACK_DEFAULT] = Vector2(0.55, 106.6)
	_loops[TRACK_ULTIMATE] = Vector2(0.0, 609.4)
	_a = _make_player()
	_b = _make_player()
	_start(_a, TRACK_DEFAULT)
	_a.volume_db = volume_db
	var player := get_tree().get_first_node_in_group("player")
	if player:
		if player.has_signal("ultimate_activated"):
			player.ultimate_activated.connect(_on_ultimate_activated)
		if player.has_signal("ultimate_fired"):
			player.ultimate_fired.connect(_on_ultimate_fired)


func _process(delta: float) -> void:
	# Loop between the loop points.
	for p in [_a, _b]:
		if p.playing and _loops.has(p.stream):
			var lp: Vector2 = _loops[p.stream]
			if p.get_playback_position() >= lp.y:
				p.seek(lp.x)
	# Count down (in real time) to the switch back to Genos.
	if _hold > 0.0 and not get_tree().paused:
		_hold -= delta / maxf(Engine.time_scale, 0.001)
		if _hold <= 0.0:
			_hold = -1.0
			_ultimate_on = false
			crossfade_to(TRACK_DEFAULT)


## Fade all music out and pause it (e.g. for a dialogue cutscene).
func fade_out(time: float = 0.6) -> void:
	_fade_bus(-60.0, time, true)


## Bring the music back in from where it paused.
func fade_in(time: float = 0.8) -> void:
	for p in [_a, _b]:
		p.stream_paused = false
	_fade_bus(_bus_level(), time, false)


var _fade_tw: Tween

func _fade_bus(to_db: float, time: float, pause_after: bool) -> void:
	var bus := AudioServer.get_bus_index("Music")
	if bus == -1:
		return
	if _fade_tw and _fade_tw.is_valid():
		_fade_tw.kill()
	_fade_tw = create_tween()
	_fade_tw.tween_method(func(db: float): AudioServer.set_bus_volume_db(bus, db),
			AudioServer.get_bus_volume_db(bus), to_db, time * Engine.time_scale)
	if pause_after:
		_fade_tw.tween_callback(func():
			for p in [_a, _b]:
				p.stream_paused = true)


func _bus_level() -> float:
	var settings := get_node_or_null("/root/AudioSettings")
	if settings:
		return settings.LEVELS.get("Music", -17.0)
	return -17.0


func _on_ultimate_activated() -> void:
	_hold = -1.0
	if _ultimate_on:
		return
	_ultimate_on = true
	crossfade_to(TRACK_ULTIMATE, true)


func _on_ultimate_fired() -> void:
	if _ultimate_on:
		_hold = ultimate_hold_time


## Fade the current track out while the new one fades in.
func crossfade_to(track: AudioStream, from_start := false) -> void:
	if _a.stream == track and _a.playing:
		return
	if _a.playing:
		_resume[_a.stream] = _a.get_playback_position()
	if from_start:
		_resume.erase(track)
	_start(_b, track)
	_b.volume_db = -60.0
	var t := crossfade_time * Engine.time_scale  # tweens run in game time
	if _tw and _tw.is_valid():
		_tw.kill()
	var tw := create_tween().set_parallel()
	_tw = tw
	tw.tween_property(_b, "volume_db", volume_db, t)
	tw.tween_property(_a, "volume_db", -60.0, t)
	var old := _a
	tw.chain().tween_callback(func(): if old != _a: old.stop())
	_a = _b
	_b = old


func _start(p: AudioStreamPlayer, track: AudioStream) -> void:
	p.stream = track
	var start: float = _loops[track].x if _loops.has(track) else 0.0
	p.play(float(_resume.get(track, start)))


func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = -60.0
	p.bus = "Music"
	add_child(p)
	return p
