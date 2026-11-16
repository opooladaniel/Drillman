extends CanvasLayer
## A short talking cutscene: the game pauses, the screen dims, and a text
## box shows each line with a portrait beside it while its voice line plays.
## The text types out at the speed it's spoken. Click / Space / Enter skips
## to the next line, Esc skips the whole thing. Emits `finished` at the end.
##
##   var cs := CanvasLayer.new()
##   cs.set_script(preload("res://Scripts/dialogue_cutscene.gd"))
##   cs.lines = [{"voice": stream, "portrait": tex, "right": false,
##       "from": 0.0, "to": -1.0,          # optional: play only part of the file
##       "pages": [{"t": 0.0, "name": "GOD", "text": "...", "silhouette": false}, ...]}]
## Each page appears at time `t` (seconds into the clip) and types out until
## the next page starts. A line can use "text" instead of "pages".
##   cs.finished.connect(...)
##   get_tree().current_scene.add_child(cs)

signal finished

const THEME := preload("res://Themes/ui_theme.tres")

var lines: Array = []
var gap_after_line := 0.45    ## real seconds of pause after each line ends
var dim_alpha := 0.55

var _index := -1
var _t := 0.0                 ## real time into the current line
var _line_len := 1.0
var _hold := 0.0
var _done := false
var _was_paused := false

var _root: Control
var _dim: ColorRect
var _box: PanelContainer
var _hbox: HBoxContainer
var _portrait_frame: Control
var _portrait: TextureRect
var _text: Label
var _name: Label
var _pages: Array = []
var _page := -1
var _voice: AudioStreamPlayer


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	get_tree().paused = true
	_build()
	var tw := create_tween().set_parallel()
	tw.tween_property(_dim, "color:a", dim_alpha, 0.3)
	tw.tween_property(_box, "modulate:a", 1.0, 0.3)
	_next_line()


func _process(delta: float) -> void:
	if _done or _index < 0:
		return
	var real := delta  # the tree is paused and time_scale doesn't apply to us here
	if Engine.time_scale > 0.0:
		real = delta / Engine.time_scale
	_t += real
	if _voice.playing and _t >= _line_len:
		_voice.stop()  # clip end reached
	# Move to the page whose time has come.
	while _page + 1 < _pages.size() and _t >= float(_pages[_page + 1].get("t", 0.0)):
		_show_page(_page + 1)
	var start := float(_pages[_page].get("t", 0.0))
	var end := _line_len
	if _page + 1 < _pages.size():
		end = float(_pages[_page + 1].get("t", 0.0))
	_text.visible_ratio = clampf((_t - start) / maxf((end - start) * 0.85, 0.05), 0.0, 1.0)
	# Portrait bobs while talking.
	_portrait.position.y = sin(_t * 18.0) * 3.0 if _voice.playing else 0.0
	if _t >= _line_len:
		_hold += real
		if _hold >= gap_after_line:
			_next_line()


func _input(event: InputEvent) -> void:
	if _done:
		return
	var skip_all: bool = event.is_action_pressed("ui_cancel")
	var skip_line: bool = event.is_action_pressed("ui_accept") \
			or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if skip_all:
		get_viewport().set_input_as_handled()
		_finish()
	elif skip_line:
		get_viewport().set_input_as_handled()
		_next_line()


func _next_line() -> void:
	_index += 1
	if _index >= lines.size():
		_finish()
		return
	var line: Dictionary = lines[_index]
	_t = 0.0
	_hold = 0.0
	_pages = line.get("pages", [{"t": 0.0, "text": line.get("text", ""), "name": line.get("name", "")}])
	_page = -1
	_show_page(0)
	_portrait.texture = line.get("portrait")
	# Portrait on the left or right side of the box.
	_hbox.move_child(_portrait_frame, -1 if line.get("right", false) else 0)
	var align := HORIZONTAL_ALIGNMENT_RIGHT if line.get("right", false) else HORIZONTAL_ALIGNMENT_LEFT
	_text.horizontal_alignment = align
	_name.horizontal_alignment = align
	var stream: AudioStream = line.get("voice")
	_voice.stop()
	_line_len = 2.5
	if stream:
		var from := float(line.get("from", 0.0))
		var to := float(line.get("to", -1.0))
		if to <= from:
			to = stream.get_length()
		_voice.stream = stream
		_voice.play(from)
		_line_len = to - from


func _show_page(i: int) -> void:
	_page = i
	var pg: Dictionary = _pages[i]
	_text.text = pg.get("text", "")
	_text.visible_ratio = 0.0
	_name.text = pg.get("name", "")
	_name.visible = _name.text != ""
	# "???" speaker: show the portrait as a black silhouette.
	_portrait.modulate = Color(0, 0, 0) if pg.get("silhouette", false) else Color.WHITE


func _finish() -> void:
	if _done:
		return
	_done = true
	_voice.stop()
	var tw := create_tween().set_parallel()
	tw.tween_property(_dim, "color:a", 0.0, 0.25)
	tw.tween_property(_box, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(func():
		# Always resume (a dialogue never runs on the game-over screen), so
		# the game can't be left stuck paused.
		get_tree().paused = false
		finished.emit()
		queue_free())


func _build() -> void:
	_root = Control.new()
	_root.theme = THEME
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)

	_box = PanelContainer.new()
	_box.modulate.a = 0.0
	_box.anchor_left = 0.0
	_box.anchor_right = 1.0
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_left = 40
	_box.offset_right = -40
	_box.offset_top = -200
	_box.offset_bottom = -24
	_root.add_child(_box)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	_box.add_child(margin)

	_hbox = HBoxContainer.new()
	_hbox.add_theme_constant_override("separation", 22)
	margin.add_child(_hbox)

	_portrait_frame = Control.new()
	_portrait_frame.custom_minimum_size = Vector2(140, 140)
	_portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hbox.add_child(_portrait_frame)
	_portrait = TextureRect.new()
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.size = Vector2(140, 140)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_frame.add_child(_portrait)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_hbox.add_child(text_col)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 22)
	_name.add_theme_color_override("font_color", Color(1, 0.6, 0.25))
	text_col.add_child(_name)
	_text = Label.new()
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_text.add_theme_font_size_override("font_size", 26)
	text_col.add_child(_text)

	var hint := Label.new()
	hint.text = "Click / Space: next     Esc: skip"
	hint.modulate.a = 0.55
	hint.add_theme_font_size_override("font_size", 16)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)  # just above the text box
	hint.offset_left = -400
	hint.offset_right = -44
	hint.offset_top = -228
	hint.offset_bottom = -204
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(hint)

	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice"
	_voice.volume_db = 2.0
	add_child(_voice)
