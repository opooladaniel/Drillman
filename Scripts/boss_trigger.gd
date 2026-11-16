extends Node
## Starts the boss fight after `boss_time` seconds of real play time:
## stops new asteroids, shows a warning, locks the game speed, and brings in
## the boss. When he's defeated, the normal run picks up again.

signal boss_started
signal boss_defeated

const BOSS_SCENE := preload("res://Scenes/boss.tscn")
const DIALOGUE := preload("res://Scripts/dialogue_cutscene.gd")
const EMPLOYEE_FACE := preload("res://Sprites/Human_Sprites/spaceman_head.webp")
const GOD_FACE := preload("res://Sprites/Boss_Sprites/zues_1.webp")

const V1 := preload("res://Voice/boss_intro_cutscene/boss_cutscene_1.MP3")
const V2 := preload("res://Voice/boss_intro_cutscene/boss_cutscene_2.MP3")
const V3 := preload("res://Voice/boss_intro_cutscene/boss_cutscene_3.MP3")
const V4 := preload("res://Voice/boss_intro_cutscene/boss_cutscene_4.MP3")

## Played when the boss arrives (before the fight starts). Page times are
## seconds into each voice clip, matched to when the words are spoken.
var intro_lines := [
	{"voice": V1, "portrait": EMPLOYEE_FACE, "right": false, "pages": [
		{"t": 0.0, "text": "Congratulations, employee! You have officially extracted 0.00001% of the universe's natural resources!"},
		{"t": 7.3, "text": "At this rate, we expect total cosmic resource depletion in just 400 trillion years!"},
	]},
	{"voice": V2, "portrait": GOD_FACE, "right": true, "pages": [
		{"t": 0.0, "name": "???", "silhouette": true, "text": "WHO..."},
		{"t": 0.64, "name": "???", "silhouette": true, "text": "...DARES..."},
		{"t": 1.3, "name": "???", "silhouette": true, "text": "...TO DEFACE MY CREATION?"},
		{"t": 3.3, "name": "GOD", "text": "FOR BILLIONS OF YEARS, I HAVE CRAFTED THE HEAVENS!"},
		{"t": 6.4, "name": "GOD", "text": "I PLACED EVERY STAR! EVERY PLANET! EVERY ASTEROID!"},
		{"t": 11.2, "name": "GOD", "text": "AND YOU..."},
		{"t": 11.7, "name": "GOD", "text": "...HAVE BEEN BREAKING THEM APART FOR POCKET CHANGE?!"},
	]},
]
## Played after he's defeated. Voice line 4 is split in two so his
## "you have defeated me?" comes before the announcement.
var outro_lines := [
	{"voice": V4, "to": 2.6, "portrait": GOD_FACE, "right": true, "pages": [
		{"t": 0.0, "name": "GOD", "text": "YOU... YOU HAVE DEFEATED ME?"},
	]},
	{"voice": V3, "portrait": EMPLOYEE_FACE, "right": false, "pages": [
		{"t": 0.0, "text": "Congratulations, employee! You have successfully acquired a controlling interest in Heaven."},
		{"t": 5.4, "text": "CosmoCorp™ is pleased to announce our newest subsidiary...\nHEAVEN™ — NOW UNDER NEW MANAGEMENT"},
		{"t": 9.0, "text": "Eternal salvation. Subscription required."},
	]},
	{"voice": V4, "from": 2.9, "portrait": GOD_FACE, "right": true, "pages": [
		{"t": 0.0, "name": "GOD", "text": "I'M GOING TO START OVER."},
	]},
]
@export var boss_time: float = 120.0        ## real seconds of survival before the boss (2:00)
@export var boss_game_speed: float = 1.4    ## game speed held during the fight
@export var warning_text := "WARNING: CEO INCOMING!"
@export var victory_text := "ZEUS DEFEATED!"
@export var play_cutscenes := true

var _real_time := 0.0
var boss: Node2D
var boss_done := false   ## true once he's been beaten (he doesn't come back)
var _starting := false


func _process(delta: float) -> void:
	if boss_done or boss != null or _starting:
		return
	_real_time += delta / Engine.time_scale
	if _real_time >= boss_time:
		start_boss()


func start_boss() -> void:
	if boss != null or _starting:
		return
	_starting = true
	var main := get_parent()
	# No more asteroids (the ones already flying finish their path).
	var spawner := main.get_node_or_null("AsteroidSpawner")
	if spawner:
		spawner.set_physics_process(false)
	_set_hazards(false)  # no angels or exploding suns during the fight
	# Hold the game at a readable speed for the fight.
	var speed := main.get_node_or_null("GameSpeed")
	if speed:
		speed.process_mode = Node.PROCESS_MODE_DISABLED
	Engine.time_scale = boss_game_speed

	# Intro dialogue first (the game is paused while it plays).
	if play_cutscenes and not intro_lines.is_empty():
		await _play_dialogue(intro_lines)
	_starting = false

	var hud := main.get_node_or_null("HUD")
	if hud and hud.has_method("show_banner"):
		hud.show_banner(warning_text, Color(1, 0.3, 0.2), 2.5)

	boss = BOSS_SCENE.instantiate()
	boss.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boss.defeated.connect(_on_boss_defeated)
	main.add_child(boss)
	boss_started.emit()


func _on_boss_defeated() -> void:
	boss_done = true
	var main := get_parent()
	# Let his fade-out finish, then the closing dialogue.
	if play_cutscenes and not outro_lines.is_empty():
		await get_tree().create_timer(1.6, false).timeout
		await _play_dialogue(outro_lines)
	var hud := main.get_node_or_null("HUD")
	if hud and hud.has_method("show_banner"):
		hud.show_banner(victory_text, Color(1, 0.85, 0.3), 3.0)
	# Back to the normal run: asteroids and the speed ramp resume.
	var spawner := main.get_node_or_null("AsteroidSpawner")
	if spawner:
		spawner.set_physics_process(true)
	_set_hazards(true)
	var speed := main.get_node_or_null("GameSpeed")
	if speed:
		speed.process_mode = Node.PROCESS_MODE_INHERIT
	boss_defeated.emit()


func _set_hazards(on: bool) -> void:
	for n in ["AngelSpawner", "SunSpawner"]:
		var s := get_parent().get_node_or_null(n)
		if s and s.has_method("set_auto_spawn"):
			s.set_auto_spawn(on)


func _play_dialogue(lines: Array) -> void:
	var cs := CanvasLayer.new()
	cs.set_script(DIALOGUE)
	cs.lines = lines
	# Music cuts out for the dialogue and comes back after.
	var music := get_parent().get_node_or_null("Music")
	if music:
		music.fade_out()
	get_parent().add_child(cs)
	await cs.finished
	if music:
		music.fade_in()
