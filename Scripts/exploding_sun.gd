extends Node2D
## A small unstable sun. Drifts in from the right, stops somewhere in front of
## the spaceman, swells and flashes with a red ring showing its blast radius,
## then explodes - hurting everything inside the ring: the spaceman loses a
## heart, asteroids and the boss's planets are destroyed.
## Lives in the SunSpawner, which follows the camera: positions are screen px.

const FRAMES_TEX := preload("res://Sprites/Hazard_sprites/exploding_star_frames.png")
const FRAME_COUNT := 48
const BOOM_SOUND := preload("res://Audio/Mine_explosion/1113.MP3")

var drift_speed := 170.0     ## px/s it floats toward the player
var stop_x := 700.0          ## screen x where it stops and starts to blow
var fuse_time := 1.5         ## warning before it explodes
var radius := 170.0          ## blast radius (px)
var scale_px := 2.0          ## sun sprite scale (42 px -> 84 px)

enum State { DRIFT, FUSE, BOOM }
var _state := State.DRIFT
var _t := 0.0
var _time := 0.0
var _boom_t := 0.0
var _sprite: Sprite2D
var _burst: CPUParticles2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite = Sprite2D.new()
	_sprite.texture = FRAMES_TEX
	_sprite.hframes = FRAME_COUNT
	_sprite.scale = Vector2.ONE * scale_px
	add_child(_sprite)

	_burst = CPUParticles2D.new()
	_burst.emitting = false
	_burst.one_shot = true
	_burst.explosiveness = 1.0
	_burst.amount = 90
	_burst.lifetime = 0.7
	_burst.spread = 180.0
	_burst.gravity = Vector2.ZERO
	_burst.initial_velocity_min = 150.0
	_burst.initial_velocity_max = radius * 2.6
	_burst.damping_min = 150.0
	_burst.damping_max = 260.0
	_burst.scale_amount_min = 4.0
	_burst.scale_amount_max = 10.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 0.85, 1))
	ramp.set_color(1, Color(0.7, 0.1, 0.0, 0))
	ramp.add_point(0.35, Color(1, 0.55, 0.1, 1))
	_burst.color_ramp = ramp
	add_child(_burst)


func _physics_process(delta: float) -> void:
	_t += delta
	_time += delta
	_sprite.frame = int(_time * 16.0) % FRAME_COUNT
	match _state:
		State.DRIFT:
			position.x -= drift_speed * delta
			position.y += sin(_time * 2.0) * 10.0 * delta
			if position.x <= stop_x:
				_state = State.FUSE
				_t = 0.0
		State.FUSE:
			# Swell, flash faster and faster.
			var k := _t / fuse_time
			var flash_rate := lerpf(4.0, 22.0, k)
			var hot := int(_t * flash_rate) % 2 == 0
			_sprite.scale = Vector2.ONE * scale_px * lerpf(1.0, 1.6, k)
			_sprite.self_modulate = Color(2.2, 2.2, 2.2) if hot else Color(1, 1, 1)
			_sprite.position = Vector2(randf_range(-k, k), randf_range(-k, k)) * 3.0
			queue_redraw()
			if _t >= fuse_time:
				_explode()
		State.BOOM:
			_boom_t += delta
			queue_redraw()
			if _boom_t >= 0.8:
				queue_free()


func _draw() -> void:
	if _state == State.FUSE:
		# Blast radius warning: pulsing red ring + faint fill.
		var k := _t / fuse_time
		var a := 0.35 + 0.35 * absf(sin(_t * lerpf(5.0, 18.0, k)))
		draw_circle(Vector2.ZERO, radius, Color(1, 0.1, 0.05, 0.10 + 0.08 * k))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1, 0.2, 0.1, a), 4.0)
	elif _state == State.BOOM:
		# White-hot flash, then an expanding shockwave ring.
		var f := clampf(1.0 - _boom_t / 0.25, 0.0, 1.0)
		if f > 0.0:
			draw_circle(Vector2.ZERO, radius * (0.6 + 0.4 * (1.0 - f)), Color(1, 0.9, 0.6, 0.85 * f))
		var r := radius * (0.3 + 1.2 * _boom_t / 0.8)
		var ring_a := clampf(1.0 - _boom_t / 0.8, 0.0, 1.0)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(1, 0.6, 0.2, ring_a), 10.0 * ring_a + 2.0)


func _explode() -> void:
	_state = State.BOOM
	_boom_t = 0.0
	_sprite.visible = false
	_burst.restart()
	# Lives in the spawner so it plays out after the sun is gone.
	var boom := AudioStreamPlayer.new()
	boom.stream = BOOM_SOUND
	get_parent().add_child(boom)
	boom.finished.connect(boom.queue_free)
	boom.play()
	var tree := get_tree()
	var player := tree.get_first_node_in_group("player") as Node2D
	if player:
		player.shake(16.0, 0.4)
		if _screen_pos(player).distance_to(position) <= radius:
			player.take_hit()
	# Everything else in the blast: asteroids and the boss's planets.
	var main := tree.current_scene
	var hit := []
	var spawner := main.get_node_or_null("AsteroidSpawner")
	if spawner:
		hit.append_array(spawner.get_children())
	var shots := main.get_node_or_null("Shots")
	if shots:
		hit.append_array(shots.get_children())
	var trigger := main.get_node_or_null("BossTrigger")
	if trigger and is_instance_valid(trigger.boss):
		hit.append_array(trigger.boss.orbit.get_children())
	for n in hit:
		if not is_instance_valid(n) or not (n is Node2D):
			continue
		if _screen_pos(n).distance_to(position) > radius:
			continue
		if n.has_method("destroy"):          # asteroid
			n.destroy()
		elif n.has_method("_break"):         # boss planet
			n._break(false)


func _screen_pos(n: Node2D) -> Vector2:
	return n.get_global_transform_with_canvas().origin
