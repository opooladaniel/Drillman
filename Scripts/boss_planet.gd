extends Area2D
## One of the small planets orbiting the boss. The boss positions it while it
## orbits; when fired it flies in a straight line (screen-relative, since the
## boss follows the camera). Hitting the spaceman costs a life; touching the
## drill smashes it.

signal smashed(planet: Area2D)

const Sfx := preload("res://Scripts/sfx.gd")
const SND_HIT := preload("res://Audio/Mine_explosion/1113.MP3")  # pitched up = a crunchy smash

var velocity := Vector2.ZERO
var fired := false
var _time := randf() * 10.0
var _done := false
var _type: Dictionary = {}

@onready var sprite: Sprite2D = $Sprite2D
@onready var burst: CPUParticles2D = $Burst


## Pick which planet this is: one entry from the boss's PLANET_TYPES.
## Call before adding it to the scene.
func setup(type: Dictionary) -> void:
	_type = type


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if not _type.is_empty():
		sprite.texture = _type["texture"]
		# Sheets are laid out 10 frames per row.
		sprite.hframes = mini(_type["frames"], 10)
		sprite.vframes = ceili(_type["frames"] / 10.0)
		sprite.scale = Vector2.ONE * _type["scale"]
		# Hitbox matches the visible planet (own shape, so sizes don't clash).
		var shape := CircleShape2D.new()
		shape.radius = _type["radius"]
		$CollisionShape2D.shape = shape
		var ramp := Gradient.new()
		var c: Color = _type["color"]
		ramp.set_color(0, Color(1, 1, 1, 1))
		ramp.set_color(1, Color(c.r, c.g, c.b, 0))
		ramp.add_point(0.35, c)
		burst.color_ramp = ramp


func _physics_process(delta: float) -> void:
	_time += delta
	sprite.frame = int(_time * 14.0) % (sprite.hframes * sprite.vframes)
	if fired and not _done:
		position += velocity * delta
		# Fired planets live in screen coordinates: remove once off screen.
		if position.x < -150.0 or position.x > 1450.0 or position.y < -150.0 or position.y > 870.0:
			queue_free()


## Warn the player: swell up and glow before being fired.
func telegraph(duration: float) -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "scale", sprite.scale * 1.5, duration)
	tween.tween_property(sprite, "self_modulate", Color(1.8, 1.4, 1.0), duration)


func fire(dir: Vector2, speed: float) -> void:
	fired = true
	velocity = dir.normalized() * speed


func _on_body_entered(body: Node2D) -> void:
	if fired and not _done and body.is_in_group("player"):
		if body.take_hit():
			_break(false)


func _on_area_entered(area: Area2D) -> void:
	# The drill smashes planets (fired or still orbiting).
	if not _done and area.is_in_group("drill"):
		_break(true)


func _break(by_drill: bool) -> void:
	_done = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	burst.emitting = true
	Sfx.play(get_tree(), SND_HIT, -6.0, randf_range(1.5, 1.8), 0.0, 0.9)
	if by_drill:
		smashed.emit(self)
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "scale", sprite.scale * 1.6, 0.18)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.18)
	tween.chain().tween_interval(0.5)
	tween.chain().tween_callback(queue_free)
