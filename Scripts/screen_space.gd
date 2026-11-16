extends Node2D
## A container that follows the camera, so its children can use screen
## coordinates (0..1280, 0..720) while still colliding with the world.

func _physics_process(_delta: float) -> void:
	follow()


func _process(_delta: float) -> void:
	follow()


func follow() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var view := get_viewport_rect().size / cam.zoom
	global_position = cam.get_screen_center_position() - view * 0.5
