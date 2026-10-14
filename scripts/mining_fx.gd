extends Node
## Mining / placing feedback: colored debris particles + short procedural SFX.

const BLOCK_COLORS := {
	"grass": Color(0.28, 0.62, 0.22),
	"dirt": Color(0.38, 0.24, 0.13),
	"stone": Color(0.42, 0.45, 0.48),
	"wood": Color(0.42, 0.25, 0.11),
}

var _audio: AudioStreamPlayer3D
var _playback: AudioStreamGeneratorPlayback
var _gen: AudioStreamGenerator
var _sample_rate := 22050.0

func _ready() -> void:
	_gen = AudioStreamGenerator.new()
	_gen.mix_rate = _sample_rate
	_gen.buffer_length = 0.15
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = _gen
	_audio.max_distance = 40.0
	_audio.unit_size = 8.0
	_audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(_audio)

func play_break(world_pos: Vector3, kind: String) -> void:
	_spawn_particles(world_pos, kind, 14, 3.2)
	_play_tone(world_pos, 180.0 if kind == "stone" else 260.0, 0.09, 0.35)

func play_place(world_pos: Vector3, kind: String) -> void:
	_spawn_particles(world_pos, kind, 6, 1.4)
	_play_tone(world_pos, 420.0, 0.05, 0.22)

func _spawn_particles(world_pos: Vector3, kind: String, amount: int, speed: float) -> void:
	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = amount
	particles.lifetime = 0.55
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 55.0
	particles.initial_velocity_min = speed * 0.6
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, -12.0, 0)
	particles.scale_amount_min = 0.08
	particles.scale_amount_max = 0.18
	particles.mesh = BoxMesh.new()
	(particles.mesh as BoxMesh).size = Vector3(0.14, 0.14, 0.14)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BLOCK_COLORS.get(kind, Color(0.5, 0.5, 0.5))
	mat.roughness = 1.0
	particles.material_override = mat
	particles.global_position = world_pos + Vector3(0.5, 0.5, 0.5)
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	host.add_child(particles)
	particles.emitting = true
	var timer := get_tree().create_timer(0.7)
	timer.timeout.connect(particles.queue_free)

func _play_tone(world_pos: Vector3, freq: float, duration: float, volume: float) -> void:
	_audio.global_position = world_pos + Vector3(0.5, 0.5, 0.5)
	if not _audio.playing:
		_audio.play()
	_playback = _audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if _playback == null:
		return
	var frames := int(duration * _sample_rate)
	for i in range(frames):
		if _playback.get_frames_available() <= 0:
			break
		var t := float(i) / _sample_rate
		var env := 1.0 - (t / duration)
		env = clampf(env, 0.0, 1.0)
		var noise := (randf() * 2.0 - 1.0) * 0.35
		var tone := sin(TAU * freq * t) * 0.45 + sin(TAU * freq * 1.7 * t) * 0.15
		var sample := (tone + noise) * env * volume
		_playback.push_frame(Vector2(sample, sample))
