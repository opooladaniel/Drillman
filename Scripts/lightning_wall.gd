extends Node2D
## A vertical lightning wall: strikes from the top and the bottom of the
## screen, leaving one gap. After a short warning it scrolls left toward the
## spaceman; slip through the gap or lose a life. Lives in the boss's
## screen-space arena, so x/y here are screen pixels.

const FRAMES := [
	preload("res://Sprites/Boss_Sprites/Lightning/lighting_strike_1.webp"), preload("res://Sprites/Boss_Sprites/Lightning/lighting_strike_2.webp"),
	preload("res://Sprites/Boss_Sprites/Lightning/lighting_strike_3.webp"), preload("res://Sprites/Boss_Sprites/Lightning/lighting_strike_4.webp"),
	preload("res://Sprites/Boss_Sprites/Lightning/lighting_strike_5.webp"), preload("res://Sprites/Boss_Sprites/Lightning/lighting_strike_6.webp"),
	preload("res://Sprites/Boss_Sprites/Lightning/lgihting_strike_7.webp"), preload("res://Sprites/Boss_Sprites/Lightning/lighting_strike_8.webp"),
	preload("res://Sprites/Boss_Sprites/Lightning/lighting_strike_9.webp"), preload("res://Sprites/Boss_Sprites/Lightning/lighting_strike_10.webp"),
	preload("res://Sprites/Boss_Sprites/Lightning/lighting_strike_11.webp"), preload("res://Sprites/Boss_Sprites/Lightning/lighting_12.webp"),
]
const BUILD_FRAMES := 6          ## frames 0-5 grow the bolt
const HOLD_FRAMES := [6, 7, 8, 9]  ## solid beam, looped while it travels
const FPS := 20.0
const Sfx := preload("res://Scripts/sfx.gd")
const SND_CRACKLE := preload("res://Audio/boss/boss_lightning appears.MP3")
const SND_THUNDER := preload("res://Audio/Mine_explosion/1113.MP3")

var gap_center := 360.0     ## screen y of the middle of the safe gap
var gap_size := 210.0       ## px tall
var speed := 260.0          ## px/s it scrolls toward the player
var warning := 0.7          ## seconds of warning before it strikes
var screen_height := 720.0
var thickness := 1.3        ## beam width scale (64 px art -> ~85 px)
var hit_width := 52.0       ## hitbox width in px (a bit forgiving)

var _t := 0.0
var _state := 0             ## 0 warn, 1 build, 2 hold/travel, 3 fade
var _anim := 0.0
var _top: Sprite2D
var _bottom: Sprite2D
var _warn_line: Line2D
var _arrows: Array[Label] = []
var _hitbox: Area2D
var _travel_sound: AudioStreamPlayer


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Lightning "appearing": quiet high crackle during the warning.
	Sfx.play(get_tree(), SND_CRACKLE, -14.0, 1.3, 0.0, warning)
	var gap_top := gap_center - gap_size / 2.0
	var gap_bottom := gap_center + gap_size / 2.0

	# Warning: a flickering dashed column with the gap marked.
	_warn_line = Line2D.new()
	_warn_line.width = 4.0
	_warn_line.default_color = Color(0.55, 0.75, 1.0, 0.0)
	_warn_line.points = PackedVector2Array([Vector2(0, 0), Vector2(0, gap_top)])
	add_child(_warn_line)
	var lower := Line2D.new()
	lower.width = 4.0
	lower.default_color = Color(0.55, 0.75, 1.0, 0.0)
	lower.points = PackedVector2Array([Vector2(0, gap_bottom), Vector2(0, screen_height)])
	_warn_line.add_child(lower)
	lower.position = Vector2.ZERO
	for y in [gap_top - 6.0, gap_bottom - 50.0]:
		var arrow := Label.new()
		arrow.text = "v" if y < gap_center else "^"
		arrow.add_theme_font_size_override("font_size", 44)
		arrow.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
		arrow.add_theme_color_override("font_outline_color", Color.BLACK)
		arrow.add_theme_constant_override("outline_size", 8)
		arrow.position = Vector2(-14, y)
		arrow.modulate.a = 0.0
		add_child(arrow)
		_arrows.append(arrow)

	# Top bolt grows down from the top edge; bottom bolt grows up from the floor.
	_top = _make_bolt(Vector2(0, 0), gap_top, 0.0)
	_bottom = _make_bolt(Vector2(0, screen_height), screen_height - gap_bottom, PI)

	# Hitbox: two rectangles, leaving the gap open.
	_hitbox = Area2D.new()
	_hitbox.monitorable = false
	_hitbox.monitoring = false
	for seg in [[0.0, gap_top], [gap_bottom, screen_height]]:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(hit_width, seg[1] - seg[0])
		shape.shape = rect
		shape.position = Vector2(0, (seg[0] + seg[1]) / 2.0)
		_hitbox.add_child(shape)
	add_child(_hitbox)


func _make_bolt(origin: Vector2, length: float, rot: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.offset = Vector2(-64, 0)
	s.position = origin
	s.rotation = rot
	s.scale = Vector2(thickness, maxf(length, 1.0) / 128.0)
	s.visible = false
	add_child(s)
	return s


func _physics_process(delta: float) -> void:
	_t += delta
	match _state:
		0:  # warning
			var a := 0.35 + 0.35 * absf(sin(_t * 30.0))
			_warn_line.default_color.a = a
			(_warn_line.get_child(0) as Line2D).default_color.a = a
			for arrow in _arrows:
				arrow.modulate.a = 1.0 if int(_t * 8.0) % 2 == 0 else 0.3
			if _t >= warning:
				_warn_line.visible = false
				for arrow in _arrows:
					arrow.visible = false
				_top.visible = true
				_bottom.visible = true
				_state = 1
				# Strike: thunder-crack, then the wall crackles as it travels.
				Sfx.play(get_tree(), SND_THUNDER, -4.0, 1.9, 0.0, 0.7)
				_travel_sound = Sfx.play(get_tree(), SND_CRACKLE, -6.0, 0.85)
				_anim = 0.0
				var player := get_tree().get_first_node_in_group("player")
				if player and player.has_method("shake"):
					player.shake(10.0, 0.3)
		1:  # bolt builds up
			_anim += delta
			var f := int(_anim * FPS)
			if f >= BUILD_FRAMES:
				_state = 2
				_hitbox.monitoring = true
			else:
				_set_frame(f)
		2:  # solid wall scrolls toward the player
			_anim += delta
			_set_frame(HOLD_FRAMES[int(_anim * FPS) % HOLD_FRAMES.size()])
			position.x -= speed * delta
			for body in _hitbox.get_overlapping_bodies():
				if body.is_in_group("player"):
					body.take_hit()
			if position.x < -60.0:
				_state = 3
				_anim = 0.0
				_hitbox.monitoring = false
				_stop_travel_sound()
		3:  # fade out
			_anim += delta
			var f := 10 + int(_anim * FPS)
			if f >= FRAMES.size():
				queue_free()
			else:
				_set_frame(f)


func _set_frame(f: int) -> void:
	_top.texture = FRAMES[f]
	_bottom.texture = FRAMES[f]


func _stop_travel_sound() -> void:
	if is_instance_valid(_travel_sound) and _travel_sound.is_inside_tree():
		var tw := _travel_sound.create_tween()
		tw.tween_property(_travel_sound, "volume_db", -60.0, 0.2)
		tw.tween_callback(_travel_sound.queue_free)


func _exit_tree() -> void:
	_stop_travel_sound()
