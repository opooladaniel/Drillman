extends CanvasLayer
## In-game HUD: spaceman portrait + heart bar (top-left), survival time (top-right) and the
## game-over panel shown when the player runs out of lives.

const TITLE_SCENE := "res://Scenes/title_screen.tscn"
## Heart bar for 1, 2 and 3 lives (index = lives - 1).
const HEART_TEXTURES: Array[Texture2D] = [
	preload("res://Sprites/Heart_Sprites/1_heart.webp"),
	preload("res://Sprites/Heart_Sprites/2_hearts.webp"),
	preload("res://Sprites/Heart_Sprites/3_hearts.webp"),
]
## The heart art only fills rows 40-100 of each 128x128 image; show just that strip.
const HEART_REGION := Rect2(0, 40, 128, 60)
const HEART_SCALE := 1.5

var _time := 0.0
var _banner: Label
var _hurt_flash: ColorRect
var _last_lives := -1
var _banner_tween: Tween

@onready var hearts: TextureRect = $LivesBar/Hearts
@onready var ultimate_bar: Control = $UltimateBar
@onready var time_label: Label = $TimeLabel
@onready var game_over: Control = $GameOver
@onready var final_time_label: Label = $GameOver/Panel/Margin/VBox/FinalTime
@onready var retry_button: Button = $GameOver/Panel/Margin/VBox/RetryButton
@onready var menu_button: Button = $GameOver/Panel/Margin/VBox/MenuButton


func _ready() -> void:
	# Keep the HUD working while the game is paused on the game-over screen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	game_over.hide()
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

	var player := get_tree().get_first_node_in_group("player")
	_make_hurt_flash()
	if player:
		_last_lives = player.lives
		_on_lives_changed(player.lives)
		player.lives_changed.connect(_on_lives_changed)
		player.died.connect(_on_player_died)
		player.drill_changed.connect(_on_drill_changed)
		player.ultimate_changed.connect(ultimate_bar.set_charge)
		player.ultimate_changed.connect(_on_ult_charge_for_tip)
		ultimate_bar.set_charge(player.get_ultimate_charge())
	_make_banner()
	_make_cursor()
	_show_tips()


## Control hints shown one after another at the start of a run.
const TIPS := [
	"W / S to move up and down",
	"Aim for the asteroids with your mouse and collect resources",
]
## Shown the first time the ultimate bar fills up.
const ULT_TIP := "Press SPACE to use your Ultimate and kill enemies"

const CURSOR_TEX := preload("res://Sprites/Mouse_sprites/blue_target.webp")
const CURSOR_SCALE := 0.75

var _tips_busy := false
var _ult_tip_shown := false
var _cursor: Sprite2D
var _cursor_layer: CanvasLayer


func _show_tips() -> void:
	# Skip them in the boss test scene (the boss shows up right away there).
	var trigger := get_parent().get_node_or_null("BossTrigger")
	if trigger and trigger.boss_time < 10.0:
		_ult_tip_shown = true
		return
	await _real_wait(1.0)
	if is_inside_tree():
		await _play_tips(TIPS)


func _on_ult_charge_for_tip(charge: float) -> void:
	if _ult_tip_shown or charge < 1.0:
		return
	_ult_tip_shown = true
	while _tips_busy and is_inside_tree():
		await _real_wait(0.2)
	if not is_inside_tree():
		return
	await _play_tips([ULT_TIP], 3.4, Color(0.55, 0.95, 1.0))


func _play_tips(texts: Array, hold: float = 2.6, color: Color = Color(1, 0.95, 0.85)) -> void:
	_tips_busy = true
	var tip := Label.new()
	tip.theme = load("res://Themes/ui_theme.tres")
	tip.add_theme_font_size_override("font_size", 32)
	tip.add_theme_color_override("font_color", color)
	tip.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.03))
	tip.add_theme_constant_override("outline_size", 10)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	tip.offset_left = -560
	tip.offset_right = 560
	tip.offset_top = -130
	tip.offset_bottom = -80
	tip.modulate.a = 0.0
	add_child(tip)
	# Real-time waits, so the pace doesn't change with the game speed.
	for text in texts:
		if not is_instance_valid(tip) or not is_inside_tree():
			break
		tip.text = text
		await _fade(tip, 1.0, 0.35)
		await _real_wait(hold)
		await _fade(tip, 0.0, 0.35)
		await _real_wait(0.25)
	if is_instance_valid(tip):
		tip.queue_free()
	_tips_busy = false


# ---------------------------------------------------------------- cursor --
## Blue target reticle in place of the mouse pointer while playing.
func _make_cursor() -> void:
	_cursor_layer = CanvasLayer.new()
	_cursor_layer.layer = 50   # above everything, cutscenes included
	add_child(_cursor_layer)
	_cursor = Sprite2D.new()
	_cursor.texture = CURSOR_TEX
	_cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cursor.scale = Vector2.ONE * CURSOR_SCALE
	# Centre of the target's ring in the image (it isn't centred in the file).
	_cursor.offset = Vector2(0.0, 8.0)
	# Light outline + brighter blue so it shows up on the dark background.
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float o = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = 6.2831853 * float(i) / 8.0;
		o = max(o, texture(TEXTURE, UV + vec2(cos(a), sin(a)) * TEXTURE_PIXEL_SIZE * 2.0).a);
	}
	vec4 outline = vec4(0.85, 0.95, 1.0, o * 0.9);
	vec4 body = vec4(c.rgb * vec3(1.3, 1.6, 2.2), c.a);
	COLOR = mix(outline, body, c.a);
}
"""
	_cursor.material = mat
	_cursor_layer.add_child(_cursor)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _update_cursor() -> void:
	if _cursor == null:
		return
	var over_menu := game_over.visible
	_cursor.visible = not over_menu
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if over_menu else Input.MOUSE_MODE_HIDDEN
	_cursor.position = get_viewport().get_mouse_position()
	# Slow spin and a little pulse.
	_cursor.rotation += get_process_delta_time() * 1.2
	var pulse := 1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.008)
	_cursor.scale = Vector2.ONE * CURSOR_SCALE * pulse


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## These may still be running when the scene is left (retry / menu), so
## they quietly stop once the HUD is out of the tree.
func _real_wait(seconds: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(seconds, true, false, true).timeout


func _fade(node: CanvasItem, to: float, seconds: float) -> void:
	var from := node.modulate.a
	var t := 0.0
	while t < seconds:
		if not is_inside_tree() or not is_instance_valid(node):
			return
		await get_tree().process_frame
		t += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
		node.modulate.a = lerpf(from, to, clampf(t / seconds, 0.0, 1.0))


func _process(delta: float) -> void:
	_update_cursor()
	if get_tree().paused:
		return
	# Count real seconds even while the game is sped up.
	_time += delta / Engine.time_scale
	time_label.text = _format_time(_time)


func _on_lives_changed(lives: int) -> void:
	if _last_lives >= 0 and lives < _last_lives:
		_flash_red()
	var healed := _last_lives > 0 and lives > _last_lives
	_last_lives = lives
	# 0 lives: show the 1-heart bar greyed out (the game-over panel covers it).
	var atlas := AtlasTexture.new()
	atlas.atlas = HEART_TEXTURES[clampi(lives, 1, HEART_TEXTURES.size()) - 1]
	atlas.region = HEART_REGION
	hearts.texture = atlas
	hearts.custom_minimum_size = HEART_REGION.size * HEART_SCALE
	hearts.modulate = Color.WHITE if lives > 0 else Color(0.3, 0.3, 0.3, 1)
	if healed:
		# Green pulse on the hearts so the heal is noticeable.
		hearts.pivot_offset = hearts.size * 0.5
		var tw := hearts.create_tween()
		hearts.modulate = Color(0.4, 2.0, 0.6)
		hearts.scale = Vector2(1.25, 1.25)
		tw.set_parallel().tween_property(hearts, "modulate", Color.WHITE, 0.45)
		tw.tween_property(hearts, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)


func _on_player_died() -> void:
	get_tree().paused = true
	Engine.time_scale = 1.0
	final_time_label.text = "You survived " + _format_time(_time)
	game_over.show()
	retry_button.grab_focus()


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


func _format_time(seconds: float) -> String:
	return "%d:%02d" % [int(seconds / 60.0), int(seconds) % 60]


## Big text that briefly announces a drill upgrade.
func _make_banner() -> void:
	_banner = Label.new()
	_banner.theme = load("res://Themes/ui_theme.tres")
	_banner.add_theme_font_size_override("font_size", 48)
	_banner.add_theme_color_override("font_color", Color(1, 0.75, 0.35))
	_banner.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.03))
	_banner.add_theme_constant_override("outline_size", 12)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -400
	_banner.offset_right = 400
	_banner.offset_top = 110
	_banner.modulate.a = 0.0
	add_child(_banner)


func _on_drill_changed(tier: int) -> void:
	var player := get_tree().get_first_node_in_group("player")
	show_banner("%s DRILL!" % String(player.DRILL_TIERS[tier]["name"]).to_upper())


## Big centred announcement that fades out after `hold` seconds.
func show_banner(text: String, color: Color = Color(1, 0.75, 0.35), hold: float = 1.2) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	if _banner_tween:
		_banner_tween.kill()
	_banner.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_interval(hold)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)


## Full-screen red overlay used when the spaceman loses a life.
func _make_hurt_flash() -> void:
	_hurt_flash = ColorRect.new()
	_hurt_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt_flash.color = Color(1, 0, 0, 0)
	_hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hurt_flash)
	move_child(_hurt_flash, game_over.get_index())  # under the game-over panel


func _flash_red() -> void:
	_hurt_flash.color.a = 0.45
	# Tweens speed up with the game speed; stretch it so it always lasts ~0.4 s.
	var tween := create_tween()
	tween.tween_property(_hurt_flash, "color:a", 0.0, 0.4 * Engine.time_scale)
