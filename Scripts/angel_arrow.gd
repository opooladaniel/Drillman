extends Area2D
## The angel's arrow. Flies in a straight line (screen coordinates); costs
## the spaceman a heart if it hits. Removed once it leaves the screen.

const ARROW_TEX := preload("res://Sprites/Angel_Sprites/arrow/arrow.webp")

var velocity := Vector2.ZERO


func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = ARROW_TEX
	sprite.scale = Vector2(2, 2)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(50, 10)
	shape.shape = rect
	shape.position = Vector2(-2, -1)
	add_child(shape)
	monitorable = false
	body_entered.connect(_on_body_entered)
	# The art points left; rotate it to face where it's flying.
	rotation = velocity.angle() - PI


func _physics_process(delta: float) -> void:
	position += velocity * delta
	if position.x < -100.0 or position.x > 1400.0 or position.y < -100.0 or position.y > 820.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.take_hit()
		queue_free()
