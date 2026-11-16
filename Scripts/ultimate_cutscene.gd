extends CanvasLayer
## The ultimate activation cutscene: freezes the game for a moment, bursts
## speed lines, slams in the giant drill behind the powered-up spaceman and
## slides a "DRILLMAN OVERDRIVE!" banner across. Emits `finished` at the end.

signal finished

const BODY_TEX := preload("res://Sprites/Human_Sprites/Ultmate_drill/spaceman_ult.webp")
const DRILL_TEX := preload("res://Sprites/Drill_Sprites/Ultimate_drill/ult_drill.webp")
const SND_REV := preload("res://Audio/Drill_hum/Drill_impact.MP3")
const SND_BOOM := preload("res://Audio/Mine_explosion/1113.MP3")
const VOICE_LINE := preload("res://Audio/Ultimate_line/ult_line_again.MP3")  # "I've been promoted!"

const TITLE := "DRILLMAN OVERDRIVE!"
const CENTER := Vector2(640, 300)

var duration := 2.2   ## real seconds

var _t := 0.0
var _was_paused := false
var _dim: ColorRect
var _lines: Control
var _drill: Sprite2D
var _body: Sprite2D
var _strip: ColorRect
var _title: Label
var _flash: ColorRect
var _line_seeds: Array = []
var _rev: AudioStreamPlayer
var _boomed := false
var _voice: AudioStreamPlayer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	get_tree().paused = true

	_dim = _rect(Color(0.02, 0.02, 0.08, 0.0))
	_lines = Control.new()
	_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.draw.connect(_draw_lines)
	add_child(_lines)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 64:
		_line_seeds.append(Vector3(rng.randf() * TAU, rng.randf(), rng.randf_range(2.0, 7.0)))

	_drill = _sprite(DRILL_TEX, 5.0)
	_drill.self_modulate = Color(0.75, 1.25, 1.3)  # cold cyan sheen
	_body = _sprite(BODY_TEX, 2.6)

	_strip = ColorRect.new()
	_strip.color = Color(0.02, 0.05, 0.08, 0.9)
	_strip.position = Vector2(0, 560)
	_strip.size = Vector2(1280, 110)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip)
	for y in [0.0, 106.0]:
		var edge := ColorRect.new()
		edge.color = Color(0.3, 1.0, 0.95, 0.9)
		edge.position = Vector2(0, y)
		edge.size = Vector2(1280, 4)
		_strip.add_child(edge)
	_title = Label.new()
	_title.text = TITLE
	_title.add_theme_font_size_override("font_size", 72)
	_title.add_theme_color_override("font_color", Color(0.55, 1.0, 0.95))
	_title.add_theme_color_override("font_outline_color", Color(0.0, 0.25, 0.3))
	_title.add_theme_constant_override("outline_size", 16)
	_title.size = Vector2(1280, 110)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_strip.add_child(_title)
	_strip.position.x = 1400

	_flash = _rect(Color(1, 1, 1, 0))

	_rev = AudioStreamPlayer.new()
	_rev.stream = SND_REV
	_rev.pitch_scale = 1.35
	_rev.volume_db = -8.0  # kept under the voice line
	add_child(_rev)
	_rev.play(5.0)

	# The spaceman's ultimate line.
	_voice = AudioStreamPlayer.new()
	_voice.stream = VOICE_LINE
	_voice.bus = "Voice"
	_voice.volume_db = 3.0
	add_child(_voice)
	_voice.play()


func _process(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.01)  # real time, even if the game is sped up
	_t += rd
	var k := _t / duration

	_dim.color.a = minf(_t / 0.15, 1.0) * 0.8
	_lines.queue_redraw()

	# Giant drill slams in from the left behind the spaceman.
	var d := clampf(_t / 0.45, 0.0, 1.0)
	_drill.position = Vector2(lerpf(-500.0, CENTER.x - 60.0, 1.0 - pow(1.0 - d, 3.0)), CENTER.y - 10)
	_drill.position += Vector2(randf_range(-4, 4), randf_range(-4, 4)) * (1.0 - d * 0.5)
	_drill.frame = int(_t * 14.0) % 3

	# Spaceman pops in.
	var b := clampf((_t - 0.25) / 0.35, 0.0, 1.0)
	_body.scale = Vector2.ONE * 2.6 * _ease_back(b)
	_body.position = CENTER + Vector2(0, 40)
	_body.frame = int(_t * 8.0) % 4

	# Title banner slides across.
	var s := clampf((_t - 0.5) / 0.3, 0.0, 1.0)
	_strip.position.x = lerpf(1400.0, 0.0, 1.0 - pow(1.0 - s, 3.0))
	_title.modulate = Color(1, 1, 1) * (1.0 + 0.4 * absf(sin(_t * 12.0)))

	if _t >= 0.45 and not _boomed:
		_boomed = true
		var boom := AudioStreamPlayer.new()
		boom.stream = SND_BOOM
		boom.pitch_scale = 0.8
		add_child(boom)
		boom.play()

	# White flash out.
	var f := clampf((_t - (duration - 0.25)) / 0.25, 0.0, 1.0)
	_flash.color.a = f
	if k >= 1.0:
		_finish()


func _finish() -> void:
	set_process(false)
	get_tree().paused = _was_paused
	finished.emit()
	# Let the voice line finish even though the cutscene is going away.
	if is_instance_valid(_voice) and _voice.playing:
		_voice.reparent(get_tree().current_scene)
		_voice.finished.connect(_voice.queue_free)
	# Fade the white flash back into the game.
	var tw := create_tween()
	for n in [_dim, _lines, _drill, _body, _strip]:
		n.visible = false
	tw.tween_property(_flash, "color:a", 0.0, 0.3 * Engine.time_scale)
	tw.tween_callback(queue_free)


func _draw_lines() -> void:
	# Speed lines bursting out from behind the spaceman.
	for seed_v in _line_seeds:
		var sd: Vector3 = seed_v
		var dir := Vector2.RIGHT.rotated(sd.x)
		var r := fposmod(sd.y * 900.0 + _t * 1700.0, 900.0) + 60.0
		var length := 120.0 + sd.y * 220.0
		var col := Color(1, 1, 1, 0.75) if int(sd.z) % 2 == 0 else Color(0.45, 1.0, 0.95, 0.75)
		_lines.draw_line(CENTER + dir * r, CENTER + dir * (r + length), col, sd.z)


func _rect(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _sprite(tex: Texture2D, s: float) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.hframes = 2
	sp.vframes = 2
	sp.scale = Vector2.ONE * s
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	return sp


func _ease_back(x: float) -> float:
	var c := 1.70158
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3) + c * pow(x - 1.0, 2)
