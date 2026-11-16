extends Area2D
## A floating drill upgrade. Drifts in from the right with the asteroids,
## bobbing and glowing. Touching it (spaceman or drill) emits `collected`;
## letting it float off the left side emits `missed`.

signal collected(pickup: Area2D)
signal missed(pickup: Area2D)

var tier: int = 1
var frames: Array = []
var approach_speed: float = 110.0  ## on-screen px/s, like the asteroids

var _time := 0.0
var _base_y := 0.0
var _player: Node2D
var _done := false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_player = get_tree().get_first_node_in_group("player")
	_base_y = position.y
	if not frames.is_empty():
		sprite.texture = frames[0]


func _physics_process(delta: float) -> void:
	_time += delta
	var vx := -approach_speed
	if is_instance_valid(_player):
		vx = _player.velocity.x * (1.0 - approach_speed / _player.run_speed)
	position.x += vx * delta
	position.y = _base_y + sin(_time * 3.0) * 14.0  # bob
	if _done:
		return
	sprite.rotation = sin(_time * 2.0) * 0.25        # wobble
	var glow := 1.0 + 0.5 * (0.5 + 0.5 * sin(_time * 6.0))
	sprite.self_modulate = Color(glow, glow, glow)  # pulse brighter
	if frames.size() > 1:
		sprite.texture = frames[int(_time * 8.0) % frames.size()]

	var cam := get_viewport().get_camera_2d()
	if cam:
		var screen_left := cam.get_screen_center_position().x \
				- get_viewport_rect().size.x * 0.5 / cam.zoom.x
		if global_position.x < screen_left - 120.0:
			_done = true
			missed.emit(self)
			queue_free()


func _collect() -> void:
	if _done:
		return
	_done = true
	collected.emit(self)
	set_deferred("monitoring", false)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", scale * 1.8, 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(queue_free)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_collect()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("drill"):
		_collect()
