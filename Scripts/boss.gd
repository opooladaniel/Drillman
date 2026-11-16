extends Node2D
## Boss fight with two modes that alternate:
##  - PLANETS: a giant crackling face with 7 planets in orbit. He flings them at
##    the spaceman one at a time; nothing regrows. When all 7 are gone...
##  - LIGHTNING: Zeus appears as a full figure and hurls lightning across the
##    whole screen (single bolts at your height, or a triple strike with one
##    safe lane). After a set number of attacks he goes back to planets.
## The boss follows the camera, so positions here are screen coordinates.

const PLANET_SCENE := preload("res://Scenes/boss_planet.tscn")
const BOLT_SCRIPT := preload("res://Scripts/lightning_bolt.gd")
const WALL_SCRIPT := preload("res://Scripts/lightning_wall.gd")
const Sfx := preload("res://Scripts/sfx.gd")

## Boss sound effects.
const SND_AMBIENCE := preload("res://Audio/boss/boss_ambience.MP3")             # loops all fight
const SND_APPEAR := preload("res://Audio/boss/boss_appears.MP3")                # face form arrives
const SND_SECOND_FORM := preload("res://Audio/boss/boss_appears_Second_form.MP3")  # lightning form
const SND_PLANET_ROTATE := preload("res://Audio/boss/boss_planet_rotate.MP3")   # planets orbiting
const SND_PLANET_THROW := preload("res://Audio/Arrow/Arrow_Swoosh.MP3")         # pitched down = heavy whoosh
const SND_BOOM := preload("res://Audio/Mine_explosion/1113.MP3")                 # defeat explosions

## Planets he can have in orbit. `scale` sets on-screen size, `radius` the
## hitbox (screen px), `color` the burst when it's smashed.
const PLANET_TYPES := [
	{"name": "Terran", "texture": preload("res://Sprites/Star_Sprites/Terran_Spritesheet.png"), "frames": 50, "scale": 0.75, "radius": 33.0, "color": Color(0.4, 0.8, 0.5)},
	{"name": "Ice", "texture": preload("res://Sprites/Star_Sprites/Ice_Spritesheet.png"), "frames": 50, "scale": 0.65, "radius": 29.0, "color": Color(0.75, 0.9, 1.0)},
	{"name": "Lava", "texture": preload("res://Sprites/Star_Sprites/Lava_Planet.png"), "frames": 50, "scale": 0.7, "radius": 31.0, "color": Color(1.0, 0.55, 0.15)},
	{"name": "Moon", "texture": preload("res://Sprites/Star_Sprites/Moon_Spritesheet.png"), "frames": 50, "scale": 0.55, "radius": 24.0, "color": Color(0.7, 0.72, 0.85)},
	{"name": "Star", "texture": preload("res://Sprites/Star_Sprites/Star_Spritesheet.png"), "frames": 50, "scale": 0.6, "radius": 30.0, "color": Color(0.5, 1.0, 0.9)},
]
## Shouted when the spaceman smashes one of his planets. The first one is
## always played first; after that they're picked at random (no repeats).
const SMASH_VOICE_LINES := [
	preload("res://Voice/Voice_lines_exploding/Voice_line_1.MP3"),  # "YOU DARE TO DESTROY THE COSMOS?!"
	preload("res://Voice/Voice_lines_exploding/voice_line_2.MP3"),  # "From the cloud, judgment follows."
	preload("res://Voice/Voice_lines_exploding/voice_line_3.MP3"),  # "Let the sky split open..."
	preload("res://Voice/Voice_lines_exploding/voice_line_4.MP3"),
	preload("res://Voice/Voice_lines_exploding/voice_line_5.MP3"),  # "The sky itself answers me..."
]
const FACE_FRAMES := [
	preload("res://Sprites/Boss_Sprites/zues_1.webp"),
	preload("res://Sprites/Boss_Sprites/zues_2.webp"),
	preload("res://Sprites/Boss_Sprites/zues_3.webp"),
	preload("res://Sprites/Boss_Sprites/zues_4.webp"),
]
const IDLE_FRAMES := [
	preload("res://Sprites/Boss_Sprites/Lightning_attack_mode_zeus/zeus_idle/zues_idle_1.webp"), preload("res://Sprites/Boss_Sprites/Lightning_attack_mode_zeus/zeus_idle/zues_idle_2.webp"),
	preload("res://Sprites/Boss_Sprites/Lightning_attack_mode_zeus/zeus_idle/zues_idle_3.webp"), preload("res://Sprites/Boss_Sprites/Lightning_attack_mode_zeus/zeus_idle/zues_idle_4.webp"),
]
const THROW_FRAMES := [
	preload("res://Sprites/Boss_Sprites/Lightning_attack_mode_zeus/zeus_light/zues_light_1.webp"), preload("res://Sprites/Boss_Sprites/Lightning_attack_mode_zeus/zeus_light/zues_light_2.webp"),
	preload("res://Sprites/Boss_Sprites/Lightning_attack_mode_zeus/zeus_light/zues_light_3.webp"), preload("res://Sprites/Boss_Sprites/Lightning_attack_mode_zeus/zeus_light/zues_light_4.webp"),
	preload("res://Sprites/Boss_Sprites/Lightning_attack_mode_zeus/zeus_light/zues_light_5.webp"),
]
const RAISE_FRAMES := [
	preload("res://Sprites/Boss_Sprites/Lightning_attack_mode_zeus/zeus_raise/zues_raise_1.webp"), preload("res://Sprites/Boss_Sprites/Lightning_attack_mode_zeus/zeus_raise/zues_raise_2.webp"),
	preload("res://Sprites/Boss_Sprites/Lightning_attack_mode_zeus/zeus_raise/zues_raise_3.webp"), preload("res://Sprites/Boss_Sprites/Lightning_attack_mode_zeus/zeus_raise/zues_raise_4.webp"),
	preload("res://Sprites/Boss_Sprites/Lightning_attack_mode_zeus/zeus_raise/zues_raise_5.webp"), preload("res://Sprites/Boss_Sprites/Lightning_attack_mode_zeus/zeus_raise/zues_raise_6.webp"),
]
const BACKGROUND_PLANETS := preload("res://Sprites/Boss_Sprites/Background _for_boss/Background-3.webp")
const BACKGROUND_LIGHTNING := preload("res://Sprites/Boss_Sprites/Background _for_boss/space_galaxy_sheet.webp")

enum Mode { PLANETS, LIGHTNING, CHANGING, DEFEATED }

signal defeated

@export var screen_position := Vector2(1010, 330)  ## where the face settles (screen px)
@export var face_scale := 3.6                      ## 128 px sprite -> ~460 px face
@export var figure_scale := 3.4                    ## 128 px sprite -> ~435 px figure
@export var entrance_time := 2.5                   ## seconds to slide in
@export var voice_gap: float = 2.5                 ## real seconds of quiet between voice lines

@export_group("Health")
@export var max_health: int = 5              ## ultimate drill hits to defeat him
@export var hurtbox_radius: float = 175.0    ## how big a target he is for the ultimate drill

@export_group("Sound")
@export var ambience_enabled: bool = false  ## background loop for the whole fight (off)
@export var ambience_db: float = -10.0
@export var rotate_db: float = -12.0         ## planet-orbit whirl with all planets up

@export_group("Planets")
@export var planet_count: int = 7            ## planets per planet phase (no regrowing)
@export var orbit_radius: float = 285.0
@export var orbit_speed: float = 0.55        ## radians per second

@export_group("Planet attacks")
@export var first_shot_delay: float = 2.0    ## after the entrance / mode change
@export var shoot_interval: float = 2.0      ## seconds between shots
@export var telegraph_time: float = 0.6      ## planet swells/glows this long before firing
@export var shot_speed: float = 420.0        ## px/s (screen)

@export_group("Lightning")
@export var lightning_attacks: int = 6       ## attacks before switching back to planets
@export var bolt_warning: float = 0.8        ## warning before a single bolt strikes
@export var triple_warning: float = 1.1      ## warning before a triple strike
@export var attack_gap: float = 1.2          ## idle time between lightning attacks
@export var play_top: float = 60.0           ## screen y range bolts can strike
@export var play_bottom: float = 660.0

@export_group("Lightning walls")
@export var wall_chance: float = 0.35        ## chance an attack is a vertical wall
@export var walls_per_attack: int = 2        ## walls in a row
@export var wall_gap: float = 210.0          ## px tall safe gap
@export var wall_speed: float = 260.0        ## px/s it scrolls toward you
@export var wall_spacing: float = 1.4        ## seconds between walls

var mode := Mode.CHANGING
var _time := 0.0
var _mode_time := 0.0
var _orbit_angle := 0.0
var _until_shot := 0.0
var _arena: Node2D             ## fired planets + bolts live here (follows the camera)
var _voice: AudioStreamPlayer
var _last_line := -1
var _voice_cooldown := 0.0
var _figure_anim: Array = IDLE_FRAMES
var _figure_anim_t := 0.0
var _figure_loop := true
var _bg_layer: CanvasLayer
var _bg: TextureRect
var _ambience: AudioStreamPlayer
var _rotate: AudioStreamPlayer
var _rotate_level := 0.0
var health := 5
var _hurtbox: Area2D
var _bar_layer: CanvasLayer
var _pips: Array[ColorRect] = []

@onready var face: Sprite2D = $Face
@onready var orbit: Node2D = $Orbit
var figure: Sprite2D  ## full-body Zeus for lightning mode (made in code if the scene lacks it)


func _ready() -> void:
	figure = get_node_or_null("Figure")
	if figure == null:
		figure = Sprite2D.new()
		figure.name = "Figure"
		figure.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		figure.texture = IDLE_FRAMES[0]
		figure.position = Vector2(60, 20)
		add_child(figure)
	face.scale = Vector2.ONE * face_scale
	figure.scale = Vector2.ONE * figure_scale
	figure.modulate.a = 0.0
	_voice = AudioStreamPlayer.new()
	_voice.volume_db = 2.0
	_voice.bus = "Voice"
	add_child(_voice)
	_arena = Node2D.new()
	_arena.name = "Shots"
	_arena.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	get_parent().add_child.call_deferred(_arena)
	_make_background()
	_setup_sounds()
	_follow_camera()
	_spawn_planet_ring()
	_make_health()
	mode = Mode.PLANETS
	_mode_time = 0.0
	_until_shot = entrance_time + first_shot_delay


func _physics_process(delta: float) -> void:
	_time += delta
	_mode_time += delta
	_follow_camera()

	# Slide in from the right, then bob.
	var enter := clampf(_time / entrance_time, 0.0, 1.0)
	var slide := lerpf(700.0, 0.0, 1.0 - pow(1.0 - enter, 3.0))
	var bob := sin(_time * 1.3) * 12.0
	face.texture = FACE_FRAMES[int(_time * 8.0) % FACE_FRAMES.size()]
	face.position = Vector2(slide, bob)
	figure.position = Vector2(slide + 60.0, 20.0 + bob * 0.5)
	_animate_figure(delta)

	# While he talks: pulse and shake a little.
	var talk := 1.0
	if _voice.playing:
		talk = 1.0 + 0.05 * absf(sin(_time * 14.0))
		face.position += Vector2(randf_range(-3, 3), randf_range(-3, 3))
	else:
		_voice_cooldown -= delta / Engine.time_scale
	face.scale = Vector2.ONE * face_scale * talk
	orbit.position = face.position
	# The ultimate drill's target follows whichever form is showing.
	_hurtbox.position = figure.position if figure.modulate.a > 0.5 else face.position

	if mode == Mode.DEFEATED:
		_update_sounds(delta)
		return
	if mode == Mode.PLANETS:
		_update_planets(delta, enter >= 1.0)
	_update_sounds(delta)


# ------------------------------------------------------------ planet mode --

func _spawn_planet_ring() -> void:
	# Shuffled so every planet type shows up.
	var order := range(PLANET_TYPES.size())
	order.shuffle()
	for i in planet_count:
		_make_planet(PLANET_TYPES[order[i % order.size()]], i)


func _make_planet(type: Dictionary, slot: int) -> Area2D:
	var p: Area2D = PLANET_SCENE.instantiate()
	p.setup(type)
	p.set_meta("slot", slot)
	p.smashed.connect(_on_planet_smashed)
	orbit.add_child(p)
	p.scale = Vector2.ZERO
	create_tween().tween_property(p, "scale", Vector2.ONE, 0.5) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return p


func _update_planets(delta: float, can_attack: bool) -> void:
	_orbit_angle += orbit_speed * delta
	for p in orbit.get_children():
		if not p.fired:
			var a: float = _orbit_angle + TAU * p.get_meta("slot") / planet_count
			p.position = Vector2(cos(a), sin(a) * 0.85) * orbit_radius

	if can_attack:
		_until_shot -= delta
		if _until_shot <= 0.0:
			_shoot_planet()
			_until_shot = shoot_interval

	# All 7 used up (thrown or smashed) and none still flying -> lightning.
	if orbit.get_child_count() == 0 and _planets_in_flight() == 0:
		_switch_to_lightning()


func _planets_in_flight() -> int:
	var n := 0
	if is_instance_valid(_arena):
		for c in _arena.get_children():
			if c.has_method("fire"):
				n += 1
	return n


func _shoot_planet() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	# Use the orbiting planet closest to the player (the one "in front").
	var planet: Area2D = null
	var best_d := INF
	for p in orbit.get_children():
		if not p.fired and not p.has_meta("launching"):
			var d: float = p.global_position.distance_to(player.global_position)
			if d < best_d:
				best_d = d
				planet = p
	if planet == null:
		return
	planet.set_meta("launching", true)
	planet.telegraph(telegraph_time)
	await get_tree().create_timer(telegraph_time, false).timeout
	if mode == Mode.DEFEATED or not is_instance_valid(planet) or not is_instance_valid(player):
		return
	# Move it into the arena and fire at where the spaceman is right now.
	var gp := planet.global_position
	planet.reparent(_arena)
	planet.global_position = gp
	planet.fire(player.global_position - gp, shot_speed)
	Sfx.play(get_tree(), SND_PLANET_THROW, -2.0, randf_range(0.5, 0.6), 0.15)


func _on_planet_smashed(_planet: Area2D) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.add_ultimate()
		player.shake()
	_say_smash_line()


## React to a smashed planet with a voice line (never overlapping).
func _say_smash_line() -> void:
	if _voice.playing or _voice_cooldown > 0.0:
		return
	var line := 0
	if _last_line >= 0:
		line = randi() % SMASH_VOICE_LINES.size()
		if line == _last_line:
			line = (line + 1 + randi() % (SMASH_VOICE_LINES.size() - 1)) % SMASH_VOICE_LINES.size()
	_last_line = line
	_voice.stream = SMASH_VOICE_LINES[line]
	_voice.play()
	_voice_cooldown = voice_gap


# --------------------------------------------------------- lightning mode --

func _switch_to_lightning() -> void:
	mode = Mode.CHANGING
	_flash_swap(face, figure)
	_set_background(BACKGROUND_LIGHTNING)
	Sfx.play(get_tree(), SND_SECOND_FORM, 0.0)
	await _wait(1.2)
	if mode == Mode.DEFEATED:
		return
	mode = Mode.LIGHTNING
	_mode_time = 0.0
	for i in lightning_attacks:
		var roll := randf()
		if roll < wall_chance:
			await _attack_walls()
		elif roll < wall_chance + (1.0 - wall_chance) * 0.45:
			await _attack_triple()
		else:
			await _attack_single()
		if mode == Mode.DEFEATED:
			return
		await _wait(attack_gap)
		if mode == Mode.DEFEATED:
			return
	_switch_to_planets()


func _attack_single() -> void:
	_play_figure(THROW_FRAMES, false)
	await _wait(0.25)  # arm wound back with the bolt
	if mode == Mode.DEFEATED:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var y := screen_y_of(player) if player else 360.0
	_spawn_bolt(y, bolt_warning)
	await _wait(bolt_warning + 0.6)
	_play_figure(IDLE_FRAMES, true)


func _attack_triple() -> void:
	_play_figure(RAISE_FRAMES, false)
	# Four lanes across the play area; strike three, leave one safe.
	var lanes := 4
	var lane_h := (play_bottom - play_top) / lanes
	var safe := randi() % lanes
	var first := true
	for i in lanes:
		if i != safe:
			# One set of sounds for the whole triple strike, not three.
			_spawn_bolt(play_top + lane_h * (i + 0.5), triple_warning, first)
			first = false
	await _wait(triple_warning + 0.6)
	_play_figure(IDLE_FRAMES, true)


## Vertical walls of lightning with a gap, scrolling toward the spaceman.
func _attack_walls() -> void:
	_play_figure(RAISE_FRAMES, false)
	var half := wall_gap / 2.0
	var last := -1000.0
	for i in walls_per_attack:
		# Pick a gap well away from the previous one so you have to move.
		var center := randf_range(play_top + half, play_bottom - half)
		for tries in 10:
			if absf(center - last) >= 200.0:
				break
			center = randf_range(play_top + half, play_bottom - half)
		last = center
		var wall := Node2D.new()
		wall.set_script(WALL_SCRIPT)
		wall.gap_center = center
		wall.gap_size = wall_gap
		wall.speed = wall_speed
		wall.position = Vector2(screen_position.x - 60.0, 0)  # just in front of Zeus
		_arena.add_child(wall)
		if i < walls_per_attack - 1:
			await _wait(wall_spacing)
			if mode == Mode.DEFEATED:
				return
	await _wait(1.6)
	_play_figure(IDLE_FRAMES, true)


func _spawn_bolt(screen_y: float, warning: float, with_sound: bool = true) -> void:
	var bolt := Node2D.new()
	bolt.set_script(BOLT_SCRIPT)
	bolt.with_sound = with_sound
	# Starts at Zeus's raised hand, crosses the whole screen to the left.
	bolt.length = screen_position.x + 20.0 + 60.0
	bolt.position = Vector2(screen_position.x + 20.0, screen_y)
	_arena.add_child(bolt)
	bolt.warn(warning)


func _switch_to_planets() -> void:
	mode = Mode.CHANGING
	_flash_swap(figure, face)
	_set_background(BACKGROUND_PLANETS)
	Sfx.play(get_tree(), SND_APPEAR, -2.0)
	await _wait(0.8)
	if mode == Mode.DEFEATED:
		return
	_spawn_planet_ring()
	mode = Mode.PLANETS
	_mode_time = 0.0
	_until_shot = first_shot_delay


func screen_y_of(node: Node2D) -> float:
	return node.get_global_transform_with_canvas().origin.y


func _play_figure(frames: Array, loop: bool) -> void:
	_figure_anim = frames
	_figure_anim_t = 0.0
	_figure_loop = loop


func _animate_figure(delta: float) -> void:
	_figure_anim_t += delta
	var fps := 7.0 if _figure_loop else 12.0
	var f := int(_figure_anim_t * fps)
	f = f % _figure_anim.size() if _figure_loop else mini(f, _figure_anim.size() - 1)
	figure.texture = _figure_anim[f]


## Flash out one sprite and flash in the other.
func _flash_swap(from: Sprite2D, to: Sprite2D) -> void:
	var tween := create_tween()
	tween.tween_property(from, "modulate", Color(3, 3, 3, 1), 0.15)
	tween.tween_property(from, "modulate", Color(3, 3, 3, 0), 0.25)
	tween.tween_callback(func(): to.modulate = Color(3, 3, 3, 0))
	tween.tween_property(to, "modulate", Color(3, 3, 3, 1), 0.15)
	tween.tween_property(to, "modulate", Color(1, 1, 1, 1), 0.35)
	_play_figure(IDLE_FRAMES, true)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


# --------------------------------------------------------------- backdrop --

func _make_background() -> void:
	# Sits in front of the scrolling space background, behind everything else.
	_bg_layer = CanvasLayer.new()
	_bg_layer.layer = -50
	add_child(_bg_layer)
	_bg = TextureRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.modulate.a = 0.0
	_bg_layer.add_child(_bg)
	_set_background(BACKGROUND_PLANETS)


func _set_background(tex: Texture2D) -> void:
	var tween := create_tween()
	if _bg.modulate.a > 0.0:
		tween.tween_property(_bg, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): _bg.texture = tex)
	tween.tween_property(_bg, "modulate:a", 1.0, 0.8)


func _follow_camera() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var view := get_viewport_rect().size / cam.zoom
	var top_left := cam.get_screen_center_position() - view * 0.5
	global_position = top_left + screen_position
	if is_instance_valid(_arena):
		_arena.global_position = top_left


# ------------------------------------------------------------------ sound --

func _setup_sounds() -> void:
	var amb: AudioStreamMP3 = SND_AMBIENCE
	amb.loop = true
	var rot: AudioStreamMP3 = SND_PLANET_ROTATE
	rot.loop = true
	_ambience = AudioStreamPlayer.new()
	_ambience.stream = amb
	_ambience.volume_db = -60.0
	add_child(_ambience)
	if ambience_enabled:
		_ambience.play()
		create_tween().tween_property(_ambience, "volume_db", ambience_db, 2.5)
	_rotate = AudioStreamPlayer.new()
	_rotate.stream = rot
	_rotate.volume_db = -80.0
	add_child(_rotate)
	_rotate.play()
	Sfx.play(get_tree(), SND_APPEAR, 0.0)


## The orbit whirl follows the planets: quieter and higher-pitched as he
## runs out, silent outside planet mode.
func _update_sounds(delta: float) -> void:
	var target := 0.0
	var left := orbit.get_child_count()
	if mode == Mode.PLANETS and left > 0:
		target = 0.35 + 0.65 * float(left) / planet_count
	_rotate_level = move_toward(_rotate_level, target, delta / Engine.time_scale * 1.5)
	_rotate.volume_db = rotate_db + linear_to_db(maxf(_rotate_level, 0.0001))
	_rotate.pitch_scale = 1.0 + 0.3 * (1.0 - float(left) / planet_count)


# ----------------------------------------------------------------- health --

func _make_health() -> void:
	health = max_health
	# Target for the ultimate drill.
	_hurtbox = Area2D.new()
	_hurtbox.add_to_group("boss_hurtbox")
	_hurtbox.monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = hurtbox_radius
	shape.shape = circle
	_hurtbox.add_child(shape)
	add_child(_hurtbox)

	# Health pips at the top of the screen.
	_bar_layer = CanvasLayer.new()
	_bar_layer.layer = 5
	add_child(_bar_layer)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.position = Vector2(640 - (max_health * 64 + 120) / 2.0, 14)
	_bar_layer.add_child(box)
	var name_label := Label.new()
	name_label.text = "ZEUS"
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.55))
	name_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	name_label.add_theme_constant_override("outline_size", 8)
	box.add_child(name_label)
	for i in max_health:
		var frame := ColorRect.new()
		frame.custom_minimum_size = Vector2(56, 22)
		frame.color = Color(0.08, 0.05, 0.02, 0.9)
		frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(frame)
		var pip := ColorRect.new()
		pip.color = Color(1, 0.85, 0.3)
		pip.position = Vector2(3, 3)
		pip.size = Vector2(50, 16)
		frame.add_child(pip)
		_pips.append(pip)
	box.modulate.a = 0.0
	create_tween().tween_property(box, "modulate:a", 1.0, 1.0)


## Hit by the spaceman's ultimate drill: lose one health pip.
func take_ult_hit() -> void:
	if mode == Mode.DEFEATED or health <= 0:
		return
	health -= 1
	var pip := _pips[health]
	var tw := create_tween()
	tw.tween_property(pip, "color", Color(1, 1, 1), 0.08)
	tw.tween_property(pip, "color", Color(0.25, 0.08, 0.05), 0.3)
	# Flash white and reel back.
	for spr in [face, figure]:
		if spr.modulate.a > 0.5:
			var f := create_tween()
			f.tween_property(spr, "self_modulate", Color(3, 3, 3), 0.06)
			f.tween_property(spr, "self_modulate", Color(1, 1, 1), 0.35)
	_say_smash_line()
	if health <= 0:
		_defeat()


func _defeat() -> void:
	mode = Mode.DEFEATED
	_hurtbox.set_deferred("monitorable", false)
	_voice.stop()
	# Clear his attacks.
	for p in orbit.get_children():
		p._break(false)
	if is_instance_valid(_arena):
		for c in _arena.get_children():
			if c.has_method("_break"):
				c._break(false)
			else:
				c.queue_free()
	# A chain of explosions, then he fades away.
	var player := get_tree().get_first_node_in_group("player")
	var spr: Sprite2D = figure if figure.modulate.a > 0.5 else face
	for i in 7:
		if not is_inside_tree():
			return
		Sfx.play(get_tree(), SND_BOOM, -2.0 + i, randf_range(0.6, 1.0))
		if player:
			player.shake(10.0 + i * 3.0, 0.3)
		var flash := create_tween()
		flash.tween_property(spr, "self_modulate", Color(3, 2.5, 2), 0.05)
		flash.tween_property(spr, "self_modulate", Color(1, 1, 1), 0.15)
		spr.position += Vector2(randf_range(-14, 14), randf_range(-14, 14))
		await _wait(0.22)
	var out := create_tween().set_parallel()
	out.tween_property(spr, "modulate:a", 0.0, 1.0)
	out.tween_property(spr, "scale", spr.scale * 1.4, 1.0)
	out.tween_property(_bg, "modulate:a", 0.0, 1.5)
	out.tween_property(_bar_layer.get_child(0), "modulate:a", 0.0, 1.0)
	out.tween_property(_rotate, "volume_db", -60.0, 1.0)
	defeated.emit()
	await _wait(1.6)
	if is_instance_valid(_arena):
		_arena.queue_free()
	queue_free()
