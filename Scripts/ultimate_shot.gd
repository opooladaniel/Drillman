extends Area2D
## The fired ultimate drill. Flies where it was aimed (screen coordinates,
## lives in a camera-following container), smashing asteroids and planets in
## its way. Hitting the boss costs him one health pip, then it blows up.

const DRILL_TEX := preload("res://Sprites/Drill_Sprites/Ultimate_drill/ult_drill.webp")
const Sfx := preload("res://Scripts/sfx.gd")
const SND_BOOM := preload("res://Audio/Mine_explosion/1113.MP3")

## Overall size of the fired drill (sprite, hitbox and trail scale with it).
const SIZE := 3.0

var velocity := Vector2.ZERO
var _time := 0.0
var _done := false
var _sprite: Sprite2D
var _trail: CPUParticles2D
var _burst: CPUParticles2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rotation = velocity.angle()
	_sprite = Sprite2D.new()
	_sprite.texture = DRILL_TEX
	_sprite.hframes = 2
	_sprite.vframes = 2
	_sprite.scale = Vector2(1.4, 1.4) * SIZE
	_sprite.self_modulate = Color(0.85, 1.15, 1.2)
	add_child(_sprite)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 70.0 * SIZE
	shape.shape = circle
	add_child(shape)
	monitorable = false
	area_entered.connect(_on_area_entered)

	_trail = _particles(Color(0.5, 1.0, 0.95), 90, 0.4, 60.0, 180.0)
	_trail.position = Vector2(-70 * SIZE, 0)
	_trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_trail.emission_sphere_radius = 20.0 * SIZE
	_trail.scale_amount_min = 4.0 * SIZE * 0.6
	_trail.scale_amount_max = 9.0 * SIZE * 0.6
	_trail.direction = Vector2(-1, 0)
	_trail.spread = 25.0
	_trail.emitting = true
	_burst = _particles(Color(1, 0.9, 0.6), 120, 0.7, 200.0, 700.0)
	_burst.one_shot = true
	_burst.explosiveness = 1.0
	_burst.spread = 180.0
	_burst.emitting = false


func _physics_process(delta: float) -> void:
	_time += delta
	_sprite.frame = int(_time * 20.0) % 3
	if _done:
		return
	position += velocity * delta
	var m := 90.0 * SIZE  # fully off screen before it's removed
	if position.x < -m or position.x > 1280.0 + m or position.y < -m or position.y > 720.0 + m:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if _done:
		return
	if area.is_in_group("boss_hurtbox"):
		area.get_parent().take_ult_hit()
		_explode()
	elif area.is_in_group("angel_hurtbox"):
		area.get_parent().kill()
		_smash_fx()
	elif area.has_method("destroy"):      # asteroid
		if not area.has_method("is_intact") or area.is_intact():
			area.destroy()
			_smash_fx()
	elif area.has_method("_break"):       # boss planet
		if not area.get("_done"):
			area._break(false)
			_smash_fx()


## Small kick when it plows through an asteroid or planet.
func _smash_fx() -> void:
	Sfx.play(get_tree(), SND_BOOM, -4.0, randf_range(1.1, 1.4), 0.0, 0.5)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.shake(10.0, 0.15)


func _explode() -> void:
	_done = true
	set_deferred("monitoring", false)
	_sprite.visible = false
	_trail.emitting = false
	_burst.restart()
	Sfx.play(get_tree(), SND_BOOM, 2.0, 0.75)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.shake(24.0, 0.5)
	get_tree().create_timer(1.0, false).timeout.connect(queue_free)


func _particles(color: Color, amount: int, life: float, vmin: float, vmax: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.scale_amount_min = 4.0
	p.scale_amount_max = 9.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(color.r, color.g, color.b, 0))
	ramp.add_point(0.3, color)
	p.color_ramp = ramp
	add_child(p)
	return p
