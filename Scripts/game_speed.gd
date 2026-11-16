extends Node
## Speeds the whole game up over time by raising Engine.time_scale.
## Everything (scrolling, asteroids, player movement, drilling, animations)
## speeds up together. Resets to normal speed when the scene is left.

@export var start_speed: float = 1.4
@export var max_speed: float = 2.5
@export var speed_increase: float = 0.009  ## added per real second (1.4 -> 2.5 in ~2 min)

var _real_time := 0.0


func _ready() -> void:
	Engine.time_scale = start_speed


func _process(delta: float) -> void:
	# delta is already scaled by time_scale; undo that to count real seconds.
	_real_time += delta / Engine.time_scale
	Engine.time_scale = minf(start_speed + _real_time * speed_increase, max_speed)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
