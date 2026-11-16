extends Node2D
## A lightning bolt that crosses the whole screen at one height.
## First a flickering warning line (and a "!" at the far edge), then the
## 12-frame strike plays, stretched from Zeus's hand to the left edge.
## Touching the full beam costs the spaceman a life. The drill can't stop it.

const FRAMES := [
	preload("res://Sprites/Boss_Sprites/Lightning/lighting_strike_1.webp"), preload("res://Sprites/Boss_Sprites/Lightning/lighting_strike_2.webp"),
	preload("res://Sprites/Boss_Sprites/Lightning/lighting_strike_3.webp"), preload("res://Sprites/Boss_Sprites/Lightning/lighting_strike_4.webp"),
	preload("res://Sprites/Boss_Sprites/Lightning/lighting_strike_5.webp"), preload("res://Sprites/Boss_Sprites/Lightning/lighting_strike_6.webp"),
	preload("res://Sprites/Boss_Sprites/Lightning/lgihting_strike_7.webp"), preload("res://Sprites/Boss_Sprites/Lightning/lighting_strike_8.webp"),
	preload("res://Sprites/Boss_Sprites/Lightning/lighting_strike_9.webp"), preload("res://Sprites/Boss_Sprites/Lightning/lighting_strike_10.webp"),
	preload("res://Sprites/Boss_Sprites/Lightning/lighting_strike_11.webp"), preload("res://Sprites/Boss_Sprites/Lightning/lighting_12.webp"),
]
const STRIKE_FPS := 20.0
const Sfx := preload("res://Scripts/sfx.gd")
const SND_CRACKLE := preload("res://Audio/boss/boss_lightning appears.MP3")
const SND_THUNDER := preload("res://Audio/Mine_explosion/1113.MP3")  # pitched up = thunder-crack
const DANGER_FRAMES := [5, 6, 7, 8, 9]  ## frames (0-based) where the beam is solid

var length := 1300.0      ## px from the origin (Zeus's hand) to past the left edge
var thickness := 1.3      ## beam thickness scale (64 px wide art -> ~85 px)
var hit_height := 56.0    ## hitbox thickness in px (a bit forgiving)
var with_sound := true    ## off for extra bolts of a triple strike

var _warn_time := 0.0
var _warn_left := 0.0
var _strike_t := -1.0

var _line: Line2D
var _sign: Label
var _beam: Sprite2D
var _hitbox: Area2D
var _warn_sound: AudioStreamPlayer


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_line = Line2D.new()
	_line.points = PackedVector2Array([Vector2.ZERO, Vector2(-length, 0)])
	_line.width = 4.0
	_line.default_color = Color(0.55, 0.75, 1.0, 0.0)
	add_child(_line)

	_sign = Label.new()
	_sign.text = "!"
	_sign.add_theme_font_size_override("font_size", 56)
	_sign.add_theme_color_override("font_color", Color(1, 0.25, 0.2))
	_sign.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_sign.add_theme_constant_override("outline_size", 10)
	_sign.position = Vector2(-length + 90.0, -42.0)
	_sign.modulate.a = 0.0
	add_child(_sign)

	# Strike art points down; rotate it so it shoots left from the origin.
	_beam = Sprite2D.new()
	_beam.centered = false
	_beam.offset = Vector2(-64, 0)
	_beam.rotation = PI / 2.0
	_beam.scale = Vector2(thickness, length / 128.0)
	_beam.visible = false
	add_child(_beam)

	_hitbox = Area2D.new()
	_hitbox.monitorable = false
	_hitbox.monitoring = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, hit_height)
	shape.shape = rect
	shape.position = Vector2(-length / 2.0, 0)
	_hitbox.add_child(shape)
	add_child(_hitbox)


## Show the warning for `duration` seconds, then strike.
func warn(duration: float) -> void:
	_warn_time = duration
	_warn_left = duration
	if with_sound:
		# Lightning "appearing": a quiet, high, building crackle.
		_warn_sound = Sfx.play(get_tree(), SND_CRACKLE, -14.0, 1.3, 0.0, duration)


func _physics_process(delta: float) -> void:
	if _warn_left > 0.0:
		_warn_left -= delta
		var flicker := 0.35 + 0.35 * absf(sin(_warn_left * 30.0))
		_line.default_color.a = flicker
		_sign.modulate.a = 1.0 if int(_warn_left * 8.0) % 2 == 0 else 0.3
		if _warn_left <= 0.0:
			_line.default_color.a = 0.0
			_sign.modulate.a = 0.0
			_strike_t = 0.0
			_beam.visible = true
			if with_sound:
				# Lightning hitting: loud low crackle + a sharp thunder-crack.
				Sfx.play(get_tree(), SND_CRACKLE, -1.0, 0.8, 0.0, 0.6)
				Sfx.play(get_tree(), SND_THUNDER, -4.0, 1.9, 0.0, 0.7)
			# Each strike rattles the screen.
			var player := get_tree().get_first_node_in_group("player")
			if player and player.has_method("shake"):
				player.shake(10.0, 0.3)
		return
	if _strike_t < 0.0:
		return
	_strike_t += delta
	var frame := int(_strike_t * STRIKE_FPS)
	if frame >= FRAMES.size():
		queue_free()
		return
	_beam.texture = FRAMES[frame]
	var dangerous := frame in DANGER_FRAMES
	_hitbox.monitoring = dangerous
	if dangerous:
		for body in _hitbox.get_overlapping_bodies():
			if body.is_in_group("player"):
				body.take_hit()  # invincibility after a hit stops repeat damage
