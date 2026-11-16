extends Node
## Helpers for Scenes/boss_test.tscn (the boss fight on its own).
## Keys:  L = skip to lightning mode   A = summon an angel   S = exploding sun
##         U = fill the ultimate bar   I = toggle invincibility   R = restart

var _invincible := false
var _label: Label


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	_label.position = Vector2(16, 690)  # bottom-left, clear of the boss health bar
	layer.add_child(_label)
	_update_label()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_L:
			_skip_to_lightning()
		KEY_I:
			_invincible = not _invincible
			var player := get_tree().get_first_node_in_group("player")
			if player:
				player.lives = 999 if _invincible else player.max_lives
				player.lives_changed.emit(player.lives)
			_update_label()
		KEY_A:
			var angels := get_parent().get_node_or_null("AngelSpawner")
			if angels:
				angels.summon()
		KEY_S:
			var suns := get_parent().get_node_or_null("SunSpawner")
			if suns:
				suns.spawn()
		KEY_U:
			# Fill the ultimate bar so Space can be tested right away.
			var player := get_tree().get_first_node_in_group("player")
			if player:
				player.ultimate_points = player.asteroids_per_bar * player.max_bars
				player.ultimate_changed.emit(player.get_ultimate_charge())
		KEY_R:
			get_tree().paused = false
			get_tree().reload_current_scene()


func _skip_to_lightning() -> void:
	var trigger := get_parent().get_node_or_null("BossTrigger")
	if trigger == null or trigger.boss == null:
		return
	var boss: Node2D = trigger.boss
	if boss.mode != 0:  # only from planet mode
		return
	# Remove his planets; the boss switches to lightning once they're gone.
	for p in boss.orbit.get_children():
		p.queue_free()


func _update_label() -> void:
	_label.text = "BOSS TEST   L: lightning   A: angel   S: sun   U: fill ultimate   I: invincible (%s)   R: restart" \
			% ("ON" if _invincible else "off")
