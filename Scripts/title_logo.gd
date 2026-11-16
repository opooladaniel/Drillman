extends Control
## The DRILLMAN title logo: pops in, glows, pulses, bobs and gets a shine
## sweep every few seconds, with little sparkles around it.

const TITLE_TEX := preload("res://Sprites/Title_Sprites/Drillman_title.webp")
const TEXT_REGION := Rect2i(0, 20, 128, 38)  ## where the letters are in the image
const PAD := 10                               ## transparent border for the glow (source px)

@export var pixel_scale: float = 4.0
@export var glow_color := Color(1.0, 0.55, 0.15)
@export var shine_every: float = 3.2          ## seconds between shine sweeps

const TEXT_SHADER := """
shader_type canvas_item;
uniform float shine_pos = -1.0;   // -0.3 .. 1.3 sweeps across
uniform float brightness = 1.7;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb *= brightness;
	// Vertical colour ramp: hotter at the top.
	c.rgb = mix(c.rgb * vec3(1.6, 1.35, 0.9), c.rgb, smoothstep(0.25, 0.75, UV.y));
	// Diagonal shine band.
	float d = abs((UV.x + UV.y * 0.35) - shine_pos * 1.35);
	float band = smoothstep(0.09, 0.0, d);
	c.rgb = mix(c.rgb, vec3(1.0, 0.97, 0.85), band * 0.85 * c.a);
	COLOR = c;
}
"""

const GLOW_SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform vec4 glow_color : source_color = vec4(1.0, 0.55, 0.15, 1.0);
uniform float radius = 4.0;      // in source pixels
uniform float strength = 1.0;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float a = 0.0;
	float total = 0.0;
	for (int r = 1; r <= 3; r++) {
		float rr = radius * float(r) / 3.0;
		for (int i = 0; i < 12; i++) {
			float ang = 6.2831853 * float(i) / 12.0;
			a += texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * rr * px).a / float(r);
			total += 1.0 / float(r);
		}
	}
	a /= total;
	COLOR = vec4(glow_color.rgb * a * strength, a * strength);
}
"""

var _time := 0.0
var _holder: Control          ## everything scales / bobs together
var _glow: TextureRect
var _glow_mat: ShaderMaterial
var _text: TextureRect
var _text_mat: ShaderMaterial
var _sparkles: CPUParticles2D
var _shine_t := 0.0
var _intro_done := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := _padded_texture()
	var size_px := Vector2(tex.get_size()) * pixel_scale
	# Layout size = the letters only (padding hangs over the edges).
	custom_minimum_size = Vector2(TEXT_REGION.size) * pixel_scale + Vector2(0, 20)

	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.size = size_px
	_holder.position = -Vector2(PAD, PAD) * pixel_scale + Vector2(0, 10)
	_holder.pivot_offset = size_px * 0.5
	add_child(_holder)

	_glow_mat = ShaderMaterial.new()
	_glow_mat.shader = _shader(GLOW_SHADER)
	_glow_mat.set_shader_parameter("glow_color", glow_color)
	_glow = _rect(tex, size_px, _glow_mat)
	# A second, wider and softer glow behind the first.
	var halo_mat := ShaderMaterial.new()
	halo_mat.shader = _glow_mat.shader
	halo_mat.set_shader_parameter("glow_color", Color(1.0, 0.3, 0.05))
	halo_mat.set_shader_parameter("radius", 9.0)
	halo_mat.set_shader_parameter("strength", 1.1)
	var halo := _rect(tex, size_px, halo_mat)
	_holder.move_child(halo, 0)

	# Dark drop shadow so it reads on any background.
	var shadow := _rect(tex, size_px, null)
	shadow.modulate = Color(0.08, 0.02, 0.0, 0.85)
	shadow.position = Vector2(0, pixel_scale * 2)
	_holder.move_child(shadow, 1)

	_text_mat = ShaderMaterial.new()
	_text_mat.shader = _shader(TEXT_SHADER)
	_text = _rect(tex, size_px, _text_mat)

	_sparkles = CPUParticles2D.new()
	_sparkles.position = size_px * 0.5
	_sparkles.amount = 26
	_sparkles.lifetime = 1.4
	_sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_sparkles.emission_rect_extents = Vector2(TEXT_REGION.size) * pixel_scale * 0.5
	_sparkles.gravity = Vector2(0, -25)
	_sparkles.initial_velocity_min = 5.0
	_sparkles.initial_velocity_max = 25.0
	_sparkles.spread = 180.0
	_sparkles.scale_amount_min = 2.0
	_sparkles.scale_amount_max = 5.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0.9, 0.5, 0))
	ramp.add_point(0.25, Color(1, 0.85, 0.4, 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 0.4, 0.1, 0))
	_sparkles.color_ramp = ramp
	_sparkles.emitting = false
	_holder.add_child(_sparkles)

	_pop_in()


func _process(delta: float) -> void:
	_time += delta
	if not _intro_done:
		return
	# Gentle bob, tilt and "breathing" scale.
	_holder.position.y = -PAD * pixel_scale + 10 + sin(_time * 1.6) * 6.0
	_holder.rotation = sin(_time * 1.1) * 0.02
	_holder.scale = Vector2.ONE * (1.0 + sin(_time * 2.2) * 0.015)
	# Pulsing glow with a little flicker.
	var pulse := 1.5 + 0.4 * sin(_time * 3.0) + randf_range(-0.04, 0.04)
	_glow_mat.set_shader_parameter("strength", pulse)
	_glow_mat.set_shader_parameter("radius", 4.0 + sin(_time * 3.0) * 1.0)
	# Shine sweep.
	_shine_t += delta
	var sweep := _shine_t / 0.7
	_text_mat.set_shader_parameter("shine_pos", lerpf(-0.3, 1.3, sweep) if sweep <= 1.0 else -1.0)
	if _shine_t >= shine_every:
		_shine_t = 0.0


func _pop_in() -> void:
	# Slam in from big + white flash, bounce to size, then start the loop.
	_holder.scale = Vector2(2.4, 2.4)
	_holder.modulate = Color(1, 1, 1, 0)
	_text_mat.set_shader_parameter("brightness", 4.0)
	var tw := create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(_holder, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(_holder, "scale", Vector2(0.92, 0.92), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_sparkles.emitting = true
		_burst())
	tw.tween_property(_holder, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(b: float): _text_mat.set_shader_parameter("brightness", b), 4.0, 1.7, 0.5)
	tw.tween_callback(func():
		_intro_done = true
		_shine_t = shine_every - 0.2)


func _burst() -> void:
	var b := CPUParticles2D.new()
	b.position = _holder.size * 0.5
	b.one_shot = true
	b.explosiveness = 1.0
	b.amount = 60
	b.lifetime = 0.8
	b.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	b.emission_rect_extents = Vector2(TEXT_REGION.size) * pixel_scale * 0.45
	b.spread = 180.0
	b.gravity = Vector2(0, 200)
	b.initial_velocity_min = 120.0
	b.initial_velocity_max = 380.0
	b.scale_amount_min = 3.0
	b.scale_amount_max = 7.0
	b.color = Color(1, 0.75, 0.3)
	_holder.add_child(b)
	b.emitting = true
	get_tree().create_timer(1.2).timeout.connect(b.queue_free)


func _rect(tex: Texture2D, size_px: Vector2, mat: Material) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = size_px
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = mat
	_holder.add_child(r)
	return r


func _shader(code: String) -> Shader:
	var s := Shader.new()
	s.code = code
	return s


## The letters cut out of the image with a transparent border around them,
## so the glow has room to spread.
func _padded_texture() -> Texture2D:
	var src := TITLE_TEX.get_image()
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var out := Image.create(TEXT_REGION.size.x + PAD * 2, TEXT_REGION.size.y + PAD * 2, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(src, TEXT_REGION, Vector2i(PAD, PAD))
	return ImageTexture.create_from_image(out)
