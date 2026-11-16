extends Control
## Intro cutscene. Everything on screen is driven by the narration's playback
## time `t`, so visuals and the typewriter text stay in sync with the voice.
## Enter / Space / Esc / click skips to the game.

const GAME_SCENE := "res://Scenes/main.tscn"
const ASTEROID_TEXTURES := [
	preload("res://Sprites/Asteriod_Sprites/Purple_Astroid.webp"),
	preload("res://Sprites/Asteriod_Sprites/blue_astroid.webp"),
	preload("res://Sprites/Asteriod_Sprites/green_astroid.webp"),
	preload("res://Sprites/Asteriod_Sprites/red_astroid.webp"),
	preload("res://Sprites/Asteriod_Sprites/regular_astroid.webp"),
]

## [start, end, text] - start/end are when the line is spoken in the audio
## (seconds), used to type the text out at the speed it is read.
const LINES := [
	[3.78, 7.76, "Since the beginning of time, mankind has looked to the cosmos with wonder."],
	[8.46, 14.72, "We dreamed of distant worlds. Of discovering new life. Of exploring the infinite mysteries of the universe."],
	[15.42, 21.06, "And now, after thousands of years of human progress, we finally have the technology to reach the stars."],
	[21.76, 24.82, "...IT'S TIME TO MAKE A PROFIT!"],
	[25.84, 30.90, "Introducing OREBIT™! Humanity's first fully privatized asteroid extraction initiative!"],
	[31.48, 35.06, "Why waste your time admiring the beauty of the universe when you could be monetizing it?"],
	[35.32, 41.60, "With billions of unclaimed asteroids, endless mineral deposits, and absolutely no environmental regulations..."],
	[42.14, 45.58, "THE SKY IS NO LONGER THE LIMIT. IT'S AN UNTAPPED MARKET!"],
	[46.14, 53.20, "And YOU, valued employee #48271, have been selected for the opportunity of a lifetime!"],
	[53.28, 59.12, "Explore the cosmos! Extract valuable resources! Meet exciting new people!"],
	[60.60, 67.70, "Exciting new people not guaranteed. Oxygen sold separately. Death voids employment contract."],
	[68.32, 69.90, "THE COMPANY'S FUTURE IS IN YOUR HANDS!"],
	[70.50, 72.48, "...Your future, however, remains company property."],
]

## Moments that get a white flash + screen shake: [time, strength]
const IMPACTS := [[23.10, 1.0], [42.14, 0.8], [68.32, 0.9]]

const END_TIME := 73.6     ## start fading to black
const FADE_TIME := 1.2

var t := 0.0
var _leaving := false
var _next_asteroid := 0.0

@onready var audio: AudioStreamPlayer = $Narration
@onready var visuals: Node2D = $Visuals
@onready var stars: Sprite2D = $Visuals/Stars
@onready var galaxy: Sprite2D = $Visuals/Galaxy
@onready var ship: Sprite2D = $Visuals/Ship
@onready var profit_bg: ColorRect = $Visuals/ProfitBg
@onready var logo: Node2D = $Visuals/Logo
@onready var logo_planet: Sprite2D = $Visuals/Logo/Planet
@onready var logo_title: Label = $Visuals/Logo/Title
@onready var asteroids: Node2D = $Visuals/Asteroids
@onready var spaceman: Sprite2D = $Visuals/Spaceman
@onready var drill: Sprite2D = $Visuals/Spaceman/Drill
@onready var dim: ColorRect = $Visuals/Dim
@onready var fine_print: Label = $FinePrint
@onready var flash: ColorRect = $Flash
@onready var dialog: PanelContainer = $DialogBox
@onready var dialog_text: Label = $DialogBox/Margin/HBox/Text
@onready var portrait: TextureRect = $DialogBox/Margin/HBox/Portrait
@onready var fade: ColorRect = $Fade


func _ready() -> void:
	Engine.time_scale = 1.0
	audio.play()


func _process(delta: float) -> void:
	if _leaving:
		return
	# Follow the audio clock (falls back to our own if audio isn't running).
	t += delta
	if audio.playing:
		var p := audio.get_playback_position() + AudioServer.get_time_since_last_mix()
		if absf(p - t) > 0.1:
			t = p
	_update_visuals(delta)
	_update_dialog()
	if t >= END_TIME + FADE_TIME:
		_go_to_game()


func _unhandled_input(event: InputEvent) -> void:
	var skip: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") \
			or (event is InputEventMouseButton and event.pressed)
	if skip:
		get_viewport().set_input_as_handled()
		_go_to_game()


func _go_to_game() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file(GAME_SCENE)


# ---------------------------------------------------------------- visuals --

func _update_visuals(delta: float) -> void:
	# 1. Stars fade in, then a galaxy fills the screen (slow zoom).
	stars.modulate.a = maxf(_env(0.5, 3.5, 15.0, 16.0), _env(34.8, 35.6, 67.7, 70.5))
	stars.position.x = -fposmod(t * 25.0, 1280.0)  # slow drift; the sprite tiles 2x wide
	var galaxy_a := maxf(_env(4.0, 9.0, 15.0, 16.0), _env(31.3, 31.9, 35.0, 35.8))
	galaxy.modulate.a = galaxy_a
	galaxy.frame = int(t / 0.07) % (galaxy.hframes * galaxy.vframes)
	var gz := 1.0 + 0.25 * clampf(t / 15.4, 0.0, 1.0) if t < 25.0 else 1.1 + 0.1 * clampf((t - 31.3) / 4.0, 0.0, 1.0)
	galaxy.scale = Vector2.ONE * 2.0 * gz
	# "Monetizing": the galaxy turns gold.
	var gold := clampf((t - 32.5) / 2.0, 0.0, 1.0) if t > 25.0 else 0.0
	galaxy.self_modulate = Color(1, 1, 1).lerp(Color(1.4, 1.05, 0.35), gold)

	# 2. Spaceship launch, slow push-in and a building rumble.
	ship.modulate.a = _env(15.0, 16.0, 21.70, 21.76)
	var sp := clampf((t - 15.0) / 6.7, 0.0, 1.0)
	ship.scale = Vector2.ONE * (1280.0 / 1536.0) * (1.0 + 0.12 * sp)
	ship.position = Vector2(640, 360 + 30.0 * sp)

	# 3. "IT'S TIME TO MAKE A PROFIT!" corporate orange, then the logo card.
	profit_bg.modulate.a = _env(23.05, 23.10, 30.9, 31.6)
	logo.modulate.a = _env(25.80, 26.10, 30.9, 31.5)
	var pop := clampf((t - 25.84) / 0.35, 0.0, 1.0)
	logo_title.scale = Vector2.ONE * (0.4 + 0.6 * _ease_back(pop))
	logo_planet.frame = int(t * 12.0) % (logo_planet.hframes * logo_planet.vframes)

	# 4. Billions of unclaimed asteroids.
	if t > 35.0 and t < 45.8:
		_next_asteroid -= delta
		if _next_asteroid <= 0.0:
			_spawn_asteroid()
			_next_asteroid = randf_range(0.12, 0.3)
	for a in asteroids.get_children():
		a.position += a.get_meta("vel") * delta
		a.rotation += a.get_meta("spin") * delta
		if a.position.x < -200:
			a.queue_free()
	asteroids.modulate.a = _env(35.0, 35.4, 45.6, 46.2)

	# 5. "And YOU, valued employee" - the spaceman, then his drill.
	spaceman.modulate.a = _env(46.7, 47.1, 72.0, 73.4)
	var sm := clampf((t - 46.84) / 0.4, 0.0, 1.0)
	var hands := clampf((t - 68.32) / 0.5, 0.0, 1.0) * (1.0 - clampf((t - 70.5) / 1.5, 0.0, 1.0))
	spaceman.scale = Vector2.ONE * 4.0 * (0.3 + 0.7 * _ease_back(sm)) * (1.0 + 0.25 * hands)
	spaceman.position = Vector2(640, 300 + sin(t * 2.0) * 8.0)
	drill.modulate.a = _env(53.2, 53.6, 100.0, 101.0)
	drill.rotation = -PI / 2.0 + sin(t * 3.0) * 0.08

	# 6. Disclaimer dims everything; the ending goes dark.
	dim.color.a = 0.45 * _env(60.4, 60.8, 67.8, 68.2) + 0.75 * _env(70.4, 72.4, 999.0, 999.0)
	fine_print.modulate.a = _env(60.5, 60.6, 67.7, 68.2)

	# Flashes + shake on the big moments, rumble under the launch.
	var shake := 6.0 * _env(17.5, 21.0, 21.70, 21.76)
	var flash_a := 0.0
	for impact in IMPACTS:
		var since: float = t - impact[0]
		if since >= 0.0 and since < 0.8:
			shake = maxf(shake, 22.0 * impact[1] * (1.0 - since / 0.8))
			flash_a = maxf(flash_a, impact[1] * (1.0 - since / 0.35))
	visuals.position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	flash.color.a = clampf(flash_a, 0.0, 1.0)

	fade.color.a = clampf(1.0 - t / 0.8, 0.0, 1.0) + clampf((t - END_TIME) / FADE_TIME, 0.0, 1.0)


func _spawn_asteroid() -> void:
	var a := Sprite2D.new()
	a.texture = ASTEROID_TEXTURES.pick_random()
	a.scale = Vector2.ONE * randf_range(1.2, 3.0)
	a.position = Vector2(1400, randf_range(40, 540))
	a.rotation = randf() * TAU
	a.set_meta("vel", Vector2(-randf_range(350, 750), randf_range(-40, 40)))
	a.set_meta("spin", randf_range(-2.5, 2.5))
	asteroids.add_child(a)


# ----------------------------------------------------------------- dialog --

func _update_dialog() -> void:
	dialog.modulate.a = _env(3.3, 3.7, 72.9, 73.6)
	var line: Array = []
	for l in LINES:
		if t >= l[0] - 0.05:
			line = l
	if line.is_empty():
		dialog_text.text = ""
		return
	if dialog_text.text != line[2]:
		dialog_text.text = line[2]
	# Type the text out at the speed it's spoken.
	var reveal := clampf((t - line[0]) / maxf(line[1] - line[0], 0.1), 0.0, 1.0)
	dialog_text.visible_ratio = reveal
	# Portrait bobs while "talking".
	var talking := reveal < 1.0
	portrait.position.y = (sin(t * 18.0) * 2.0) if talking else 0.0


# ---------------------------------------------------------------- helpers --

## 0 before a, fades in a->b, holds, fades out c->d.
func _env(a: float, b: float, c: float, d: float) -> float:
	if t < a or t > d:
		return 0.0
	if t < b:
		return (t - a) / maxf(b - a, 0.001)
	if t > c:
		return 1.0 - (t - c) / maxf(d - c, 0.001)
	return 1.0


func _ease_back(x: float) -> float:
	var c := 1.70158
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3) + c * pow(x - 1.0, 2)
