extends Control
## Ultimate meter drawn inside the empty bar sprite.
## `charge` is in bars: 0.5 = half full, 1.0 = full, 1.3 = full and 30% of the
## way through the darker "spill-over" layer, and so on. Each extra layer
## refills the bar in the next (darker) colour.
## Once the bar is full, the "ULTIMATE" text appears on it and the bar starts
## shaking - harder with every extra layer.

const FRAME := preload("res://Sprites/Ultimate_Sprite/ultimate_bar_empty.webp")
const TEXT := preload("res://Sprites/Ultimate_Sprite/ultimate_text.webp")  ## drawn to fit inside the frame
const FRAME_REGION := Rect2(0, 30, 128, 30)  ## where the bar sits in the 128x128 image
const INNER := Rect2(2, 2, 124, 26)          ## inside of the frame, in sprite pixels

## One colour per layer, brightest first. The number of colours is the
## number of times the bar can fill up.
@export var level_colors: Array[Color] = [
	Color(1.0, 0.72, 0.2),
	Color(0.85, 0.45, 0.1),
	Color(0.65, 0.26, 0.06),
	Color(0.45, 0.12, 0.04),
]
@export var fill_speed: float = 1.5  ## bars per second the fill slides at
@export var min_shake: float = 1.0   ## px of shake when the bar is first full
@export var max_shake: float = 3.0   ## px of shake at the final layer
@export var shake_rate: float = 15.0 ## times per second the bar jumps to a new spot

var target := 0.0
var shown := 0.0
var _flash := 0.0
var _text_pop := 0.0   ## 1 -> 0 after the text first appears
var _shake := Vector2.ZERO
var _shake_timer := 0.0


func set_charge(value: float) -> void:
	target = clampf(value, 0.0, level_colors.size())


func _process(delta: float) -> void:
	# Use real time so the bar animates the same whatever the game speed.
	var real_delta := delta / Engine.time_scale
	if shown != target:
		var before := int(shown)
		shown = move_toward(shown, target, fill_speed * real_delta)
		if int(shown) > before:
			_flash = 1.0  # a layer just filled up
			_text_pop = 1.0
		queue_redraw()
	if _flash > 0.0:
		_flash = maxf(_flash - real_delta * 3.0, 0.0)
		queue_redraw()
	if _text_pop > 0.0:
		_text_pop = maxf(_text_pop - real_delta * 4.0, 0.0)
	# Full: shake, harder the more layers are filled.
	if shown >= 1.0:
		var layers := float(level_colors.size())
		var amount := lerpf(min_shake, max_shake, clampf((shown - 1.0) / maxf(layers - 1.0, 1.0), 0.0, 1.0))
		_shake_timer -= real_delta
		if _shake_timer <= 0.0:
			_shake_timer = 1.0 / shake_rate
			_shake = Vector2(randf_range(-amount, amount), randf_range(-amount, amount)).round()
			queue_redraw()
	elif _shake != Vector2.ZERO:
		_shake = Vector2.ZERO
		queue_redraw()


func _draw() -> void:
	draw_set_transform(_shake)
	var px := size / FRAME_REGION.size  # screen pixels per sprite pixel
	var inner := Rect2(INNER.position * px, INNER.size * px)
	draw_rect(inner, Color(0, 0, 0, 0.55))  # dark backing so the bar reads

	var full_layers := int(shown)
	var frac := shown - full_layers
	if full_layers >= level_colors.size():
		full_layers = level_colors.size()
		frac = 0.0
	if full_layers > 0:
		_draw_fill(inner, 1.0, _color(full_layers - 1), px)
	if frac > 0.0:
		_draw_fill(inner, frac, _color(full_layers), px)
	if _flash > 0.0:
		draw_rect(inner, Color(1, 1, 1, _flash * 0.6))

	draw_texture_rect_region(FRAME, Rect2(Vector2.ZERO, size), FRAME_REGION)

	if shown >= 1.0:
		_draw_text(px)


## "ULTIMATE" over the bar, with a thin light edge so it reads on every layer,
## and a little pop when a layer fills.
func _draw_text(px: Vector2) -> void:
	var pop := 1.0 + 0.35 * _text_pop
	var center := size / 2.0
	draw_set_transform(_shake + center * (1.0 - pop), 0.0, Vector2(pop, pop))
	var rect := Rect2(Vector2.ZERO, size)
	var edge := Color(1, 0.9, 0.75, 0.75)
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_texture_rect_region(TEXT, Rect2(rect.position + o * px.x, rect.size), FRAME_REGION, edge)
	draw_texture_rect_region(TEXT, rect, FRAME_REGION)
	draw_set_transform(Vector2.ZERO)


func _draw_fill(inner: Rect2, amount: float, color: Color, px: Vector2) -> void:
	# Snap to whole sprite pixels so the fill stays pixel-art crisp.
	var width := floorf(INNER.size.x * amount) * px.x
	if width <= 0.0:
		return
	draw_rect(Rect2(inner.position, Vector2(width, inner.size.y)), color)
	# Light strip along the top for a bit of shine.
	draw_rect(Rect2(inner.position, Vector2(width, 3.0 * px.y)), Color(1, 1, 1, 0.18))


func _color(layer: int) -> Color:
	return level_colors[clampi(layer, 0, level_colors.size() - 1)]
