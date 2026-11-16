extends Node2D
## Spawns asteroids just off the right edge of the screen at random heights.
## The longer the run lasts, the more often they spawn and the faster they fly.

signal player_hit
signal asteroid_drilled

const ASTEROID_SCENE := preload("res://Scenes/asteroid.tscn")

## Sprites to pick from at random.
@export var textures: Array[Texture2D] = []
## White "hit flash" version of each sprite, in the same order as `textures`.
@export var white_textures: Array[Texture2D] = []

@export_group("Spawn rate")
@export var start_interval: float = 2.5      ## seconds between spawns at the start
@export var min_interval: float = 0.8        ## fastest spawn rate allowed
@export var interval_decrease: float = 0.01  ## seconds taken off the interval per second of play

@export_group("Speed")
## Speeds are how fast asteroids cross the SCREEN.
@export var start_speed: float = 120.0       ## on-screen px/s at the start
@export var max_speed: float = 400.0
@export var speed_increase: float = 2.0      ## px/s added per second of play
@export var speed_variation: float = 0.25    ## each asteroid is randomly +/- this fraction

@export_group("Look")
@export var min_scale: float = 1.6
@export var max_scale: float = 2.6
@export var max_spin: float = 2.0            ## radians per second
@export var edge_margin: float = 70.0        ## keep spawns this far from the top/bottom edge

var elapsed: float = 0.0
var _until_next: float = 0.5


func current_interval() -> float:
	return maxf(start_interval - elapsed * interval_decrease, min_interval)


func current_speed() -> float:
	return minf(start_speed + elapsed * speed_increase, max_speed)


func _physics_process(delta: float) -> void:
	elapsed += delta
	# Spawn timer runs at the player's speed relative to run_speed (1.0 unless
	# the player's speed is changed by other code), keeping spacing consistent.
	var pace := 1.0
	var player := get_tree().get_first_node_in_group("player")
	if player:
		pace = player.velocity.x / player.run_speed
	_until_next -= delta * pace
	while _until_next <= 0.0:
		_spawn()
		_until_next += current_interval()


func _spawn() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or textures.is_empty():
		return

	var half := get_viewport_rect().size * 0.5 / cam.zoom
	var center := cam.get_screen_center_position()
	var size_scale := randf_range(min_scale, max_scale)

	var asteroid := ASTEROID_SCENE.instantiate()
	var pick := randi() % textures.size()
	asteroid.normal_texture = textures[pick]
	if pick < white_textures.size():
		asteroid.white_texture = white_textures[pick]
	asteroid.scale = Vector2.ONE * size_scale
	asteroid.rotation = randf() * TAU
	asteroid.global_position = Vector2(
		center.x + half.x + 64.0 * size_scale,
		randf_range(center.y - half.y + edge_margin, center.y + half.y - edge_margin))

	var speed := current_speed() * randf_range(1.0 - speed_variation, 1.0 + speed_variation)
	asteroid.approach_speed = speed
	asteroid.drift = randf_range(-0.1, 0.1) * speed
	asteroid.spin = randf_range(-max_spin, max_spin)
	asteroid.hit_player.connect(_on_asteroid_hit_player)
	asteroid.drilled.connect(_on_asteroid_drilled)
	add_child(asteroid)


func _on_asteroid_hit_player(asteroid: Area2D) -> void:
	var player := get_tree().get_first_node_in_group("player")
	# take_hit() ignores hits while the player is blinking/invincible.
	if player and player.take_hit():
		asteroid.destroy()
		player_hit.emit()


func _on_asteroid_drilled(_asteroid: Area2D) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.add_ultimate()
		player.shake()
	asteroid_drilled.emit()
