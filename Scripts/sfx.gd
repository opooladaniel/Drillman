extends RefCounted
## Tiny helper for one-shot sound effects that outlive the node that made
## them (an exploding planet, a finished bolt...). Use:
##   const Sfx := preload("res://Scripts/sfx.gd")
##   Sfx.play(get_tree(), stream, volume_db, pitch, from, max_time)

static func play(tree: SceneTree, stream: AudioStream, volume_db: float = 0.0,
		pitch: float = 1.0, from: float = 0.0, max_time: float = -1.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = "SFX"
	tree.current_scene.add_child(p)
	p.finished.connect(p.queue_free)
	p.play(from)
	if max_time > 0.0:
		# Cut it short with a quick fade.
		tree.create_timer(max_time, false).timeout.connect(func():
			if is_instance_valid(p) and p.is_inside_tree():
				var tw := p.create_tween()
				tw.tween_property(p, "volume_db", -60.0, 0.12)
				tw.tween_callback(p.queue_free))
	return p
