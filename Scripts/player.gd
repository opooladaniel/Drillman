extends CharacterBody2D
## Endless-runner movement.
## The player always runs forward at `run_speed`, so the camera (a child of
## the player) and the parallax background scroll on their own.
## W/S (or Up/Down) move up and down within the screen; there is no
## forward/backward control.
## The drill in the spaceman's hand always points at the mouse, and throws
## sparks while it is grinding into an asteroid.
## The player has `max_lives`; each asteroid hit costs one, followed by a short
## blinking invincibility. Losing the last life emits `died`.

signal lives_changed(lives: int)
signal died
signal drill_changed(tier: int)
signal ultimate_changed(charge: float)  ## charge in bars (1.0 = one full bar)
signal ultimate_activated
signal ultimate_fired

## Drill upgrade path, in order. `power` is how fast it drills (1.0 = normal).
## Drills with several frames are animated.
const DRILL_TIERS := [
	{"name": "Bronze", "power": 1.0, "frames": [preload("res://Sprites/Drill_Sprites/brown_drill.webp")]},
	{"name": "Green", "power": 1.5, "frames": [preload("res://Sprites/Drill_Sprites/green_drill.webp")]},
	{"name": "Red", "power": 2.0, "frames": [preload("res://Sprites/Drill_Sprites/red_drill.webp")]},
	{"name": "Purple", "power": 2.5, "frames": [preload("res://Sprites/Drill_Sprites/purple_drill.webp")]},
	{"name": "Blue", "power": 3.0, "frames": [
		preload("res://Sprites/Drill_Sprites/blue_drill_1.webp"),
		preload("res://Sprites/Drill_Sprites/blue_drill_2.webp"),
		preload("res://Sprites/Drill_Sprites/blue_drill_3.webp")]},
]
const DRILL_ANIM_FPS := 8.0

## Drill sounds: a hum while idle, a grind while it's cutting into something.
const DRILL_HUM := preload("res://Audio/Drill_hum/1113.MP3")
const DRILL_IMPACT := preload("res://Audio/Drill_hum/Drill_impact.MP3")
const IMPACT_START := 5.0  ## seconds into the grind file where it's already loud

## Ultimate: Space spends one full bar -> cutscene -> powered-up form that
## can fire the giant drill (left-click or Space again).
const ULT_BODY_TEX := preload("res://Sprites/Human_Sprites/Ultmate_drill/spaceman_ult.webp")
const ULT_DRILL_TEX := preload("res://Sprites/Drill_Sprites/Ultimate_drill/ult_drill.webp")
const ULT_CUTSCENE := preload("res://Scripts/ultimate_cutscene.gd")
const ULT_SHOT := preload("res://Scripts/ultimate_shot.gd")
const SCREEN_SPACE := preload("res://Scripts/screen_space.gd")
const SND_ULT_FIRE := preload("res://Audio/Arrow/Arrow_Swoosh.MP3")
enum Ult { READY, CUTSCENE, ARMED, FIRED }

## Said when the spaceman loses a life (random, never the same twice in a row).
const HURT_VOICE_LINES := [
	preload("res://Voice/Voice_lines_main_character_hurt/voice_hurt.MP3"),    # "Woah!"
	preload("res://Voice/Voice_lines_main_character_hurt/voice_hurt_2.MP3"),  # "Ouch."
	preload("res://Voice/Voice_lines_main_character_hurt/voice_hurt_3.MP3"),  # "Good thing I have insurance."
	preload("res://Voice/Voice_lines_main_character_hurt/voice_hurt_4.MP3"),  # "They don't pay me enough for this."
]

@export var run_speed: float = 300.0     ## steady forward speed (sets background scroll)
@export var vertical_speed: float = 300.0
@export var top_limit: float = 45.0      ## highest the player can go (screen y)
@export var bottom_limit: float = 675.0  ## lowest the player can go (screen y)

@export_group("Lives")
@export var max_lives: int = 3
@export var invincible_time: float = 1.5  ## seconds of blinking after a hit

@export_group("Screen shake")
@export var mine_shake: float = 12.0  ## px of shake when you mine an asteroid
@export var shake_time: float = 0.25  ## seconds a shake lasts
@export var hit_shake: float = 22.0   ## px of shake when you lose a life
@export var hit_shake_time: float = 0.45
@export var drill_shake: float = 4.0  ## px of constant rumble while the drill is grinding something

@export_group("Drill sound")
@export var hum_volume_db: float = -12.0    ## idle hum
@export var impact_volume_db: float = -2.0  ## grinding into an asteroid / planet
@export var sound_fade_time: float = 0.12   ## seconds to cross-fade between them

@export_group("Ultimate")
@export var asteroids_per_bar: int = 10  ## drilled asteroids to fill the bar once
@export var max_bars: int = 4            ## how many times it can spill over (match the bar's colours)
@export var ult_shot_speed: float = 1000.0  ## px/s of the fired ultimate drill
@export var ult_auto_fire: float = 8.0      ## seconds in ultimate form before it fires by itself

var lives: int = 3
var drill_tier: int = 0
var drill_power: float = 1.0
var ultimate_points: int = 0  ## drilled asteroids counted toward the ultimate
var ult_state := Ult.READY
var _ult_time := 0.0
var _ult_body: Sprite2D
## Size of the ultimate drill while it's held (1.0 = original size).
@export var ult_drill_hand_scale: float = 1.5
var _ult_drill: Sprite2D
var _invincible_left: float = 0.0
var _drill_anim_time: float = 0.0
var _drill_base_scale: Vector2
var _shake_strength := 0.0
var _shake_left := 0.0
var _shake_total := 0.0
var _limit_top := 0
var _limit_bottom := 0
var _hurt_voice: AudioStreamPlayer
var _hum: AudioStreamPlayer
var _impact: AudioStreamPlayer
var _hum_level := 1.0     ## 0..1 cross-fade levels
var _impact_level := 0.0
var _last_hurt_line := -1

@onready var drill_pivot: Node2D = $AnimatedSprite2D/DrillPivot
@onready var drill_hitbox: Area2D = $AnimatedSprite2D/DrillPivot/Drill/DrillHitbox
@onready var drill_sparks: CPUParticles2D = $AnimatedSprite2D/DrillPivot/Drill/Sparks
@onready var drill_sprite: Sprite2D = $AnimatedSprite2D/DrillPivot/Drill
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("player")
	lives = max_lives
	_drill_base_scale = drill_sprite.scale
	_setup_drill_sounds()
	_hurt_voice = AudioStreamPlayer.new()
	_hurt_voice.bus = "Voice"
	_hurt_voice.process_mode = Node.PROCESS_MODE_ALWAYS  # still heard on the game-over screen
	add_child(_hurt_voice)
	_limit_top = camera.limit_top
	_limit_bottom = camera.limit_bottom
	set_drill_tier(0, false)


func _physics_process(delta: float) -> void:
	velocity.x = run_speed
	velocity.y = Input.get_axis("move_up", "move_down") * vertical_speed
	move_and_slide()
	position.y = clampf(position.y, top_limit, bottom_limit)

	if _invincible_left > 0.0:
		_invincible_left -= delta
		# Blink while invincible.
		modulate.a = 0.3 if int(_invincible_left * 10.0) % 2 == 0 else 1.0
		if _invincible_left <= 0.0:
			modulate.a = 1.0


func _process(_delta: float) -> void:
	aim_drill(get_global_mouse_position())
	_update_ultimate(_delta)
	var drilling := _is_drilling()
	drill_sparks.emitting = drilling
	_update_drill_sounds(_delta, drilling)
	if drilling:
		shake(drill_shake, 0.1)  # keeps topping up, so it rumbles for as long as you drill
	_update_shake(_delta)

	# Animate multi-frame drills (the blue one).
	var frames: Array = DRILL_TIERS[drill_tier]["frames"]
	if frames.size() > 1:
		_drill_anim_time += _delta
		drill_sprite.texture = frames[int(_drill_anim_time * DRILL_ANIM_FPS) % frames.size()]


## True while the drill is grinding into at least one intact asteroid.
func _is_drilling() -> bool:
	for area in drill_hitbox.get_overlapping_areas():
		if area.has_method("is_intact") and area.is_intact():
			return true
	return false


func aim_drill(target: Vector2) -> void:
	drill_pivot.look_at(target)
	# Mirror the drill when aiming left so its handle stays on top.
	var aiming_left := absf(wrapf(drill_pivot.rotation, -PI, PI)) > PI / 2.0
	drill_pivot.scale.y = -1.0 if aiming_left else 1.0


func is_invincible() -> bool:
	return _invincible_left > 0.0


## Called when an asteroid touches the spaceman. Returns true if the hit
## counted (false while invincible or already dead).
func take_hit() -> bool:
	if is_invincible() or lives <= 0:
		return false
	lives -= 1
	shake(hit_shake, hit_shake_time)
	_say_hurt_line()
	lives_changed.emit(lives)
	if lives <= 0:
		died.emit()
	else:
		_invincible_left = invincible_time
	return true


## Regain one life (up to max_lives). Returns true if a heart was restored.
func heal(amount: int = 1) -> bool:
	if lives <= 0 or lives >= max_lives:
		return false
	lives = mini(lives + amount, max_lives)
	lives_changed.emit(lives)
	return true


## Switch to a drill on the upgrade path (0 = bronze ... 4 = blue).
func set_drill_tier(tier: int, announce: bool = true) -> void:
	drill_tier = clampi(tier, 0, DRILL_TIERS.size() - 1)
	drill_power = DRILL_TIERS[drill_tier]["power"]
	_drill_anim_time = 0.0
	drill_sprite.texture = DRILL_TIERS[drill_tier]["frames"][0]
	if announce:
		heal()  # every new drill restores a heart
		# Quick "pop" so the swap is noticeable.
		drill_sprite.scale = _drill_base_scale * 1.4
		create_tween().tween_property(drill_sprite, "scale", _drill_base_scale, 0.25) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		drill_changed.emit(drill_tier)


func is_max_drill() -> bool:
	return drill_tier >= DRILL_TIERS.size() - 1


## Called for every asteroid the drill breaks.
func add_ultimate(points: int = 1) -> void:
	ultimate_points = mini(ultimate_points + points, asteroids_per_bar * max_bars)
	ultimate_changed.emit(get_ultimate_charge())


func get_ultimate_charge() -> float:
	return float(ultimate_points) / asteroids_per_bar


## Shake the screen by `strength` px, fading out over `duration` seconds.
func shake(strength: float = mine_shake, duration: float = shake_time) -> void:
	var current := _shake_strength * (_shake_left / maxf(_shake_total, 0.001))
	if strength < current:
		return  # a bigger shake is already playing
	_shake_strength = strength
	_shake_left = duration
	_shake_total = duration


func _update_shake(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left -= delta
	if _shake_left <= 0.0:
		camera.offset = Vector2.ZERO
		camera.limit_top = _limit_top
		camera.limit_bottom = _limit_bottom
		return
	var s := _shake_strength * (_shake_left / _shake_total)
	camera.offset = Vector2(randf_range(-s, s), randf_range(-s, s))
	# The camera is locked vertically by its limits; loosen them by the shake
	# amount so it can shake up/down too.
	camera.limit_top = _limit_top - ceili(s)
	camera.limit_bottom = _limit_bottom + ceili(s)


func _say_hurt_line() -> void:
	var line := randi() % HURT_VOICE_LINES.size()
	if line == _last_hurt_line:
		line = (line + 1 + randi() % (HURT_VOICE_LINES.size() - 1)) % HURT_VOICE_LINES.size()
	_last_hurt_line = line
	_hurt_voice.stream = HURT_VOICE_LINES[line]
	_hurt_voice.play()


func _setup_drill_sounds() -> void:
	# Both sounds loop seamlessly.
	var hum: AudioStreamMP3 = DRILL_HUM
	hum.loop = true
	var grind: AudioStreamMP3 = DRILL_IMPACT
	grind.loop = true
	_hum = AudioStreamPlayer.new()
	_hum.stream = hum
	_hum.volume_db = hum_volume_db
	add_child(_hum)
	_hum.play()
	_impact = AudioStreamPlayer.new()
	_impact.stream = grind
	_impact.volume_db = -80.0
	add_child(_impact)


## Hum while idle; fade to the grind while the drill is cutting something.
func _update_drill_sounds(delta: float, drilling: bool) -> void:
	var step := (delta / Engine.time_scale) / maxf(sound_fade_time, 0.01)
	_hum_level = move_toward(_hum_level, 0.0 if drilling else 1.0, step)
	_impact_level = move_toward(_impact_level, 1.0 if drilling else 0.0, step)
	if drilling and not _impact.playing:
		_impact.play(IMPACT_START)
	elif _impact_level <= 0.0 and _impact.playing:
		_impact.stop()
	_hum.volume_db = hum_volume_db + linear_to_db(maxf(_hum_level, 0.0001))
	_impact.volume_db = impact_volume_db + linear_to_db(maxf(_impact_level, 0.0001))


# --------------------------------------------------------------- ultimate --

func _unhandled_input(event: InputEvent) -> void:
	if lives <= 0:
		return
	var space: bool = event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_SPACE
	var click: bool = event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT
	if space and ult_state == Ult.READY:
		activate_ultimate()
		get_viewport().set_input_as_handled()
	elif (space or click) and ult_state == Ult.ARMED:
		fire_ultimate()
		get_viewport().set_input_as_handled()


func can_use_ultimate() -> bool:
	return ult_state == Ult.READY and ultimate_points >= asteroids_per_bar and lives > 0


## Spend one full bar: cutscene, then the powered-up form.
func activate_ultimate() -> void:
	if not can_use_ultimate():
		return
	ultimate_points -= asteroids_per_bar
	ultimate_changed.emit(get_ultimate_charge())
	ult_state = Ult.CUTSCENE
	heal()  # using the ultimate restores a heart
	_set_ult_look(true)
	ultimate_activated.emit()
	var cutscene := CanvasLayer.new()
	cutscene.set_script(ULT_CUTSCENE)
	cutscene.finished.connect(_on_ult_cutscene_done)
	get_tree().current_scene.add_child(cutscene)


func _on_ult_cutscene_done() -> void:
	ult_state = Ult.ARMED
	_ult_time = 0.0


## Launch the giant drill where it's aimed.
func fire_ultimate() -> void:
	if ult_state != Ult.ARMED:
		return
	ult_state = Ult.FIRED
	var shot := Area2D.new()
	shot.set_script(ULT_SHOT)
	var dir := Vector2.RIGHT.rotated(drill_pivot.global_rotation)
	shot.velocity = dir * ult_shot_speed
	_screen_space().add_child(shot)
	shot.position = _ult_drill.get_global_transform_with_canvas().origin
	_ult_drill.visible = false
	shake(14.0, 0.3)
	var whoosh := AudioStreamPlayer.new()
	whoosh.stream = SND_ULT_FIRE
	whoosh.pitch_scale = 0.45
	whoosh.volume_db = 2.0
	get_tree().current_scene.add_child(whoosh)
	whoosh.finished.connect(whoosh.queue_free)
	whoosh.play(0.15)
	ultimate_fired.emit()
	await get_tree().create_timer(0.6, false).timeout
	_set_ult_look(false)
	ult_state = Ult.READY


func _update_ultimate(delta: float) -> void:
	if ult_state == Ult.READY:
		return
	_ult_time += delta / Engine.time_scale
	if _ult_body:
		_ult_body.frame = int(_ult_time * 8.0) % 4
		_ult_body.position = Vector2(0, -8) + Vector2(randf_range(-1, 1), randf_range(-1, 1))
	if _ult_drill:
		_ult_drill.frame = int(_ult_time * 18.0) % 3
	if ult_state == Ult.ARMED and _ult_time >= ult_auto_fire:
		fire_ultimate()


## Swap to the powered-up spaceman + giant drill (or back).
func _set_ult_look(on: bool) -> void:
	if _ult_body == null:
		_ult_body = Sprite2D.new()
		_ult_body.texture = ULT_BODY_TEX
		_ult_body.hframes = 2
		_ult_body.vframes = 2
		_ult_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_ult_body)
		_ult_drill = Sprite2D.new()
		_ult_drill.texture = ULT_DRILL_TEX
		_ult_drill.hframes = 2
		_ult_drill.vframes = 2
		_ult_drill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_ult_drill.scale = Vector2(0.65, 0.65) * ult_drill_hand_scale
		_ult_drill.position = Vector2(46, 0) * ult_drill_hand_scale  # base of the drill at the hand
		drill_pivot.add_child(_ult_drill)
	$AnimatedSprite2D.self_modulate.a = 0.0 if on else 1.0
	drill_sprite.self_modulate.a = 0.0 if on else 1.0
	_ult_body.visible = on
	_ult_drill.visible = on


func _screen_space() -> Node2D:
	var scene := get_tree().current_scene
	var layer := scene.get_node_or_null("UltimateShots") as Node2D
	if layer == null:
		layer = Node2D.new()
		layer.name = "UltimateShots"
		layer.set_script(SCREEN_SPACE)
		scene.add_child(layer)
		layer.follow()
	return layer
