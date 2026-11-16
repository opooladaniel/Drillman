extends Area2D
## A single asteroid. Flies toward the player from the right, spins, and
## deletes itself once it is well past the left edge of the screen.
## Touching the spaceman emits `hit_player`.
## While the drill is touching it, it is held back, flashes white, shakes and
## shrinks; after `drill_time` seconds of drilling it breaks apart and emits
## `drilled`.

signal hit_player(asteroid: Area2D)
signal drilled(asteroid: Area2D)

@export var drill_time: float = 1.2       ## seconds of drilling to break it with the bronze drill
@export var flash_interval: float = 0.06  ## seconds per white/normal flash
@export var drilled_speed: float = 0.15   ## fraction of its speed while being drilled
@export var min_drilled_size: float = 0.5 ## how small it gets just before breaking
@export var shake: float = 2.0            ## px of jitter while being drilled

## How fast it crosses the screen (px/s) while the player runs at run_speed.
var approach_speed: float = 120.0
var drift: float = 0.0  ## vertical px/s
var spin: float = 0.0
var normal_texture: Texture2D
var white_texture: Texture2D

var _player: Node2D
var _destroyed := false
var _drill_contacts := 0
var _drilled_for := 0.0
var _texture_scale := 1.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	_player = get_tree().get_first_node_in_group("player")
	_set_white(false)


func _physics_process(delta: float) -> void:
	var vx := -approach_speed
	if is_instance_valid(_player):
		# Screen speed scales with the player's current speed, so it always
		# moves toward the player and never drifts backwards.
		var player_vx: float = _player.velocity.x
		vx = player_vx * (1.0 - approach_speed / _player.run_speed)
	var motion := Vector2(vx, drift)
	if _drill_contacts > 0 and not _destroyed:
		# The drill holds it back: keep pace with the player, approach slowly.
		var player_vx: float = _player.velocity.x if is_instance_valid(_player) else 0.0
		motion = Vector2(lerpf(player_vx, vx, drilled_speed), drift * drilled_speed)
	position += motion * delta
	rotation += spin * delta

	if not _destroyed:
		if _drill_contacts > 0:
			# Better drills (higher drill_power) get through faster.
			var power: float = _player.drill_power if is_instance_valid(_player) else 1.0
			_drilled_for += delta * power
			# Alternate white / normal every flash_interval while being drilled.
			_set_white(int(_drilled_for / flash_interval) % 2 == 0)
			_update_drill_visuals()
			sprite.position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
			if _drilled_for >= drill_time:
				drilled.emit(self)
				destroy()
		else:
			_set_white(false)
			sprite.position = Vector2.ZERO

	var cam := get_viewport().get_camera_2d()
	if cam:
		var screen_left := cam.get_screen_center_position().x \
				- get_viewport_rect().size.x * 0.5 / cam.zoom.x
		if global_position.x < screen_left - 200.0:
			queue_free()


## True until the asteroid starts breaking apart.
func is_intact() -> bool:
	return not _destroyed


## Pop and remove the asteroid. Safe to call more than once.
func destroy() -> void:
	if _destroyed:
		return
	_destroyed = true
	_set_white(true)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", scale * 1.4, 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)


func _set_white(on: bool) -> void:
	var tex := white_texture if on and white_texture else normal_texture
	if tex == null or sprite.texture == tex:
		return
	sprite.texture = tex
	# The white sprites are drawn at 2x (128 px), so scale every texture to
	# the same 64 px on-screen size.
	_texture_scale = 64.0 / tex.get_width()
	_update_drill_visuals()


## Shrink the sprite as drilling progresses.
func _update_drill_visuals() -> void:
	var progress := clampf(_drilled_for / drill_time, 0.0, 1.0)
	sprite.scale = Vector2.ONE * _texture_scale * lerpf(1.0, min_drilled_size, progress)


func _on_body_entered(body: Node2D) -> void:
	if not _destroyed and body.is_in_group("player"):
		hit_player.emit(self)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("drill"):
		_drill_contacts += 1


func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group("drill"):
		_drill_contacts = maxi(_drill_contacts - 1, 0)
