extends Node2D
## Sends the next drill on the upgrade path floating in with the asteroids.
## Bronze -> Green -> Red -> Purple -> Blue (tiers live in player.gd).
## Collect it to switch drills; miss it and the same drill comes back later.

const PICKUP_SCENE := preload("res://Scenes/drill_pickup.tscn")

@export var first_delay: float = 12.0          ## seconds before the first upgrade appears
@export var delay_after_collect: float = 20.0  ## wait before the next upgrade
@export var delay_after_miss: float = 6.0      ## wait before a missed upgrade comes back
@export var approach_speed: float = 110.0      ## on-screen px/s
@export var edge_margin: float = 90.0          ## keep it this far from the top/bottom

var _until_next: float
var _active: Area2D


func _ready() -> void:
	_until_next = first_delay


func _physics_process(delta: float) -> void:
	if is_instance_valid(_active):
		return  # only one upgrade on screen at a time
	var player := get_tree().get_first_node_in_group("player")
	if player == null or player.is_max_drill():
		return
	_until_next -= delta
	if _until_next <= 0.0:
		_spawn(player.drill_tier + 1)


func _spawn(tier: int) -> void:
	var cam := get_viewport().get_camera_2d()
	var player := get_tree().get_first_node_in_group("player")
	if cam == null or player == null:
		return
	var half := get_viewport_rect().size * 0.5 / cam.zoom
	var center := cam.get_screen_center_position()

	var pickup := PICKUP_SCENE.instantiate()
	pickup.tier = tier
	pickup.frames = player.DRILL_TIERS[tier]["frames"]
	pickup.approach_speed = approach_speed
	pickup.global_position = Vector2(
		center.x + half.x + 100.0,
		randf_range(center.y - half.y + edge_margin, center.y + half.y - edge_margin))
	pickup.collected.connect(_on_collected)
	pickup.missed.connect(_on_missed)
	add_child(pickup)
	_active = pickup


func _on_collected(pickup: Area2D) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.set_drill_tier(pickup.tier)
	_active = null
	_until_next = delay_after_collect


func _on_missed(_pickup: Area2D) -> void:
	_active = null
	_until_next = delay_after_miss
