extends Node2D
## An archer angel. Flies in, says its line while aiming at the spaceman with
## a red reticle, locks on as the line ends, and fires once it has finished
## speaking. Move out of the locked spot to dodge. Lives in the AngelSpawner, which follows the
## camera, so positions here are screen pixels.

signal finished

const FRAMES := [
	preload("res://Sprites/Angel_Sprites/arrow_angel_1.webp"),
	preload("res://Sprites/Angel_Sprites/arrow_angel_2.webp"),
]
const TARGET_TEX := preload("res://Sprites/Angel_Sprites/lock_on/target.webp")
const VOICE := preload("res://Voice/Voice_lines_angel/angel_voice.MP3")  # "Be afraid of my arrows!"
const ARROW_SCRIPT := preload("res://Scripts/angel_arrow.gd")
const SWOOSH := preload("res://Audio/Arrow/Arrow_Swoosh.MP3")
const SWOOSH_START := 0.15  ## skip the near-silent start so it lines up with the shot
const Sfx := preload("res://Scripts/sfx.gd")
const SND_DEATH := preload("res://Audio/Mine_explosion/1113.MP3")

enum State { ENTER, AIM, LOCK, FIRED, LEAVE, DEAD }

var hover_position := Vector2(1110, 200)
var enter_time := 0.8
var aim_time := 1.2        ## minimum time the reticle follows the spaceman
var lock_time := 0.7       ## reticle stops and blinks - move now!
                           ## (timed to end as the voice line ends; it fires after)
var arrow_speed := 950.0

var _state := State.ENTER
var _t := 0.0
var _time := 0.0
var _start := Vector2.ZERO
var _sprite: Sprite2D
var _target: Sprite2D
var _voice: AudioStreamPlayer


func _ready() -> void:
	_start = Vector2(1400, hover_position.y - 120)
	position = _start
	_sprite = Sprite2D.new()
	_sprite.texture = FRAMES[0]
	_sprite.scale = Vector2(2, 2)
	add_child(_sprite)
	# The reticle sits in the spawner's space (doesn't bob with the angel).
	_target = Sprite2D.new()
	_target.texture = TARGET_TEX
	_target.scale = Vector2(2, 2)
	_target.visible = false
	get_parent().add_child.call_deferred(_target)
	_voice = AudioStreamPlayer.new()
	_voice.stream = VOICE
	_voice.bus = "Voice"
	add_child(_voice)
	_voice.play()
	# Hitbox the ultimate drill can hit (one shot kills).
	var hurtbox := Area2D.new()
	hurtbox.add_to_group("angel_hurtbox")
	hurtbox.monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 48.0
	shape.shape = circle
	hurtbox.add_child(shape)
	add_child(hurtbox)


func _physics_process(delta: float) -> void:
	_t += delta
	_time += delta
	_sprite.texture = FRAMES[int(_time * 8.0) % FRAMES.size()]  # flap
	var bob := Vector2(0, sin(_time * 4.0) * 6.0)
	match _state:
		State.ENTER:
			var k := clampf(_t / enter_time, 0.0, 1.0)
			position = _start.lerp(hover_position, 1.0 - pow(1.0 - k, 3.0))
			if k >= 1.0:
				_next(State.AIM)
				_target.visible = true
				_target.position = _player_screen_pos()
		State.AIM:
			position = hover_position + bob
			# Track the spaceman.
			_target.position = _target.position.lerp(_player_screen_pos(), minf(delta * 12.0, 1.0))
			_target.rotation += delta * 2.0
			# Keep aiming while he talks; lock on so the lock ends with the line.
			if _t >= aim_time and _voice_left() <= lock_time:
				_next(State.LOCK)
		State.LOCK:
			position = hover_position + bob
			# Locked: stops moving, blinks fast and tightens.
			_target.modulate.a = 1.0 if int(_t * 14.0) % 2 == 0 else 0.35
			_target.scale = Vector2.ONE * lerpf(2.4, 1.8, _t / lock_time)
			# Only fire once the voice line has finished.
			if _t >= lock_time and not _voice.playing:
				_fire()
				_next(State.FIRED)
		State.FIRED:
			# Small recoil, then leave.
			position = hover_position + bob + Vector2(lerpf(18.0, 0.0, minf(_t * 4.0, 1.0)), 0)
			_target.modulate.a = maxf(0.0, 1.0 - _t * 3.0)
			if _t >= 0.6:
				_next(State.LEAVE)
		State.LEAVE:
			position += Vector2(320, -380) * delta
			if position.y < -120.0 or position.x > 1400.0:
				if is_instance_valid(_target):
					_target.queue_free()
				finished.emit()
				queue_free()
		State.DEAD:
			# Tumble down and fade out.
			_sprite.texture = FRAMES[0]
			position += Vector2(60, 520 * _t) * delta
			_sprite.rotation += delta * 9.0
			_sprite.modulate.a = maxf(0.0, 1.0 - _t * 1.2)
			if _t >= 0.9:
				finished.emit()
				queue_free()


## Hit by the ultimate drill: dies instantly (no arrow if it hasn't fired yet).
func kill() -> void:
	if _state == State.DEAD:
		return
	_next(State.DEAD)
	_voice.stop()
	for c in get_children():
		if c is Area2D:
			c.queue_free()
	if is_instance_valid(_target):
		_target.queue_free()
	Sfx.play(get_tree(), SND_DEATH, -2.0, 1.3)
	# White flash + feather burst.
	_sprite.self_modulate = Color(3, 3, 3)
	create_tween().tween_property(_sprite, "self_modulate", Color.WHITE, 0.25)
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 40
	burst.lifetime = 0.8
	burst.spread = 180.0
	burst.gravity = Vector2(0, 300)
	burst.initial_velocity_min = 150.0
	burst.initial_velocity_max = 420.0
	burst.scale_amount_min = 4.0
	burst.scale_amount_max = 8.0
	burst.color = Color(1, 0.95, 0.75)
	burst.position = position
	get_parent().add_child(burst)
	burst.emitting = true
	get_tree().create_timer(1.2, false).timeout.connect(burst.queue_free)


func _fire() -> void:
	var bow := position + Vector2(-56, -10)
	var arrow := Area2D.new()
	arrow.set_script(ARROW_SCRIPT)
	arrow.position = bow
	arrow.velocity = (_target.position - bow).normalized() * arrow_speed
	get_parent().add_child(arrow)
	# Swoosh: lives in the spawner so it isn't cut off when the arrow or
	# angel disappears; removes itself when done.
	var swoosh := AudioStreamPlayer.new()
	swoosh.stream = SWOOSH
	get_parent().add_child(swoosh)
	swoosh.finished.connect(swoosh.queue_free)
	swoosh.play(SWOOSH_START)


## Real seconds of the voice line still to play.
func _voice_left() -> float:
	if not _voice.playing:
		return 0.0
	return VOICE.get_length() - _voice.get_playback_position()


func _player_screen_pos() -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return Vector2(320, 360)
	return player.get_global_transform_with_canvas().origin


func _next(s: State) -> void:
	_state = s
	_t = 0.0


func _exit_tree() -> void:
	if is_instance_valid(_target):
		_target.queue_free()
