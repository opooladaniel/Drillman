extends Node2D
## Sends an exploding sun every `interval` real seconds. Follows the camera,
## so the suns inside it use screen coordinates.

const SUN_SCRIPT := preload("res://Scripts/exploding_sun.gd")

@export var interval: float = 10.0     ## real seconds between suns
@export var first_delay: float = 10.0  ## real seconds before the first one
@export var radius: float = 170.0      ## blast radius (px)
@export var fuse_time: float = 1.5     ## warning before it explodes
@export var stop_min_x: float = 480.0  ## where it can stop to blow (screen x)
@export var stop_max_x: float = 980.0
@export var top: float = 80.0          ## spawn height range (screen y)
@export var bottom: float = 640.0

var _until_next: float
var auto_spawn := true   ## off during the boss fight


func _ready() -> void:
	_until_next = first_delay


func _physics_process(delta: float) -> void:
	_follow_camera()
	if not auto_spawn:
		return
	_until_next -= delta / Engine.time_scale
	if _until_next <= 0.0:
		spawn()


## Send a sun now (also used by the boss test's "S" key).
func spawn() -> void:
	_until_next = interval
	var sun := Node2D.new()
	sun.set_script(SUN_SCRIPT)
	sun.radius = radius
	sun.fuse_time = fuse_time
	sun.stop_x = randf_range(stop_min_x, stop_max_x)
	sun.position = Vector2(1360, randf_range(top, bottom))
	add_child(sun)


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
