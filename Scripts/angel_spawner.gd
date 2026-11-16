extends Node2D
## Sends an archer angel every `interval` real seconds (paused during the
## boss fight). Follows the camera, so the angels, reticles and arrows
## inside it use screen coordinates.

const ANGEL_SCRIPT := preload("res://Scripts/angel.gd")

@export var interval: float = 20.0      ## real seconds between angels
@export var first_delay: float = 20.0   ## real seconds before the first one
@export var hover_x: float = 1110.0     ## where the angel hovers (screen px)
@export var hover_top: float = 110.0    ## hover height range (screen px)
@export var hover_bottom: float = 560.0

var _until_next: float
var auto_spawn := true   ## off during the boss fight


func _ready() -> void:
	_until_next = first_delay
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _physics_process(delta: float) -> void:
	_follow_camera()
	if not auto_spawn:
		return
	_until_next -= delta / Engine.time_scale
	if _until_next <= 0.0:
		summon()


## Send an angel now (also used by the boss test's "A" key).
func summon() -> void:
	_until_next = interval
	var angel := Node2D.new()
	angel.set_script(ANGEL_SCRIPT)
	angel.hover_position = Vector2(hover_x, randf_range(hover_top, hover_bottom))
	add_child(angel)


## Stop/restart the timed spawns. Stopping also clears anything on screen.
func set_auto_spawn(on: bool) -> void:
	auto_spawn = on
	_until_next = interval
	if not on:
		for c in get_children():
			c.queue_free()


func _follow_camera() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var view := get_viewport_rect().size / cam.zoom
	global_position = cam.get_screen_center_position() - view * 0.5
