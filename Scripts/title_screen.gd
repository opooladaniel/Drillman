extends Control
## Title screen: spinning planet in the background, Play and Settings buttons.

const GAME_SCENE := "res://Scenes/intro_cutscene.tscn"  ## Play starts the intro, which then loads the game

@export var planet_fps: float = 12.0  ## playback speed of the planet spritesheet

var _time := 0.0

@onready var planet: Sprite2D = $Planet
@onready var menu: VBoxContainer = $Menu
@onready var play_button: Button = $Menu/PlayButton
@onready var settings_button: Button = $Menu/SettingsButton
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var volume_slider: HSlider = $SettingsPanel/Margin/VBox/VolumeRow/VolumeSlider
@onready var fullscreen_toggle: CheckButton = $SettingsPanel/Margin/VBox/FullscreenToggle
@onready var sfx_toggle: CheckButton = $SettingsPanel/Margin/VBox/SfxToggle
@onready var music_toggle: CheckButton = $SettingsPanel/Margin/VBox/MusicToggle
@onready var back_button: Button = $SettingsPanel/Margin/VBox/BackButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	back_button.pressed.connect(_close_settings)
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	sfx_toggle.button_pressed = AudioSettings.sfx_enabled
	music_toggle.button_pressed = AudioSettings.music_enabled
	sfx_toggle.toggled.connect(AudioSettings.set_sfx_enabled)
	music_toggle.toggled.connect(AudioSettings.set_music_enabled)

	# Show the current values in the settings panel.
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	fullscreen_toggle.button_pressed = \
			DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

	settings_panel.hide()
	play_button.grab_focus()  # so Enter / arrow keys work straight away


func _process(delta: float) -> void:
	_time += delta
	planet.frame = int(_time * planet_fps) % (planet.hframes * planet.vframes)


func _unhandled_input(event: InputEvent) -> void:
	if settings_panel.visible and event.is_action_pressed("ui_cancel"):
		_close_settings()
		get_viewport().set_input_as_handled()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_settings_pressed() -> void:
	menu.hide()
	settings_panel.show()
	volume_slider.grab_focus()


func _close_settings() -> void:
	settings_panel.hide()
	menu.show()
	settings_button.grab_focus()


func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value))
	AudioServer.set_bus_mute(0, value <= 0.0)


func _on_fullscreen_toggled(on: bool) -> void:
	DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
