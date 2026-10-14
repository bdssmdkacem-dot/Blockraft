extends Node
## Mining / placing feedback: debris particles with gravity + procedural SFX.

const BLOCK_COLORS := {
	"grass": Color(0.30, 0.58, 0.24),
	"dirt": Color(0.40, 0.26, 0.14),
	"stone": Color(0.48, 0.50, 0.52),
	"wood": Color(0.42, 0.25, 0.11),
	"sand": Color(0.82, 0.72, 0.48),
	"water": Color(0.22, 0.48, 0.72),
	"gravel": Color(0.55, 0.52, 0.48),
	"rock": Color(0.35, 0.36, 0.38),
	"coal": Color(0.12, 0.12, 0.14),
	"iron": Color(0.72, 0.58, 0.48),
	"gold": Color(0.92, 0.78, 0.22),
	"crystal": Color(0.45, 0.85, 0.95),
	"chest": Color(0.55, 0.32, 0.12),
	"leaves": Color(0.20, 0.58, 0.22),
}

const SAMPLE_RATE := 22050

var _players: Array = []
var _dig_streams: Dictionary = {}
var _place_stream: AudioStreamWAV
var _swing_stream: AudioStreamWAV
var _hit_stream: AudioStreamWAV
var _pool_index := 0

func _ready() -> void:
	_dig_streams["stone"] = _make_dig_wav(0.14, 0.55, 90.0, 0.85)
	_dig_streams["rock"] = _make_dig_wav(0.15, 0.6, 80.0, 0.9)
	_dig_streams["dirt"] = _make_dig_wav(0.11, 0.45, 140.0, 0.7)
	_dig_streams["grass"] = _make_dig_wav(0.09, 0.4, 180.0, 0.55)
	_dig_streams["leaves"] = _make_dig_wav(0.08, 0.35, 200.0, 0.5)
	_dig_streams["wood"] = _make_dig_wav(0.12, 0.5, 220.0, 0.65)
	_dig_streams["sand"] = _make_dig_wav(0.1, 0.5, 160.0, 0.6)
	_dig_streams["gravel"] = _make_dig_wav(0.11, 0.55, 120.0, 0.7)
	_dig_streams["coal"] = _make_dig_wav(0.11, 0.4, 100.0, 0.7)
	_dig_streams["iron"] = _make_dig_wav(0.13, 0.5, 95.0, 0.8)
	_dig_streams["gold"] = _make_dig_wav(0.12, 0.45, 150.0, 0.75)
	_dig_streams["crystal"] = _make_dig_wav(0.1, 0.3, 400.0, 0.7)
	_dig_streams["chest"] = _make_dig_wav(0.14, 0.5, 180.0, 0.8)
	_place_stream = _make_place_wav()
	_swing_stream = _make_swing_wav()
	_hit_stream = _make_hit_wav()
	for i in range(6):
		var p := AudioStreamPlayer3D.new()
		p.max_distance = 48.0
		p.unit_size = 10.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.volume_db = 2.0
		add_child(p)
		_players.append(p)

func play_break(world_pos: Vector3, kind: String) -> void:
	_spawn_debris(world_pos + Vector3(0.5, 0.5, 0.5), kind, 14)
	var stream: AudioStreamWAV = _dig_streams.get(kind, _dig_streams.get("stone"))
	_play_at(world_pos, stream, randf_range(0.9, 1.12))

func play_place(world_pos: Vector3, kind: String) -> void:
	_spawn_debris(world_pos + Vector3(0.5, 0.5, 0.5), kind, 6)
	_play_at(world_pos, _place_stream, randf_range(0.95, 1.1))

func play_swing(world_pos: Vector3) -> void:
	_play_at(world_pos, _swing_stream, randf_range(0.92, 1.08))

func play_hit(world_pos: Vector3) -> void:
	_play_at(world_pos, _hit_stream, randf_range(0.9, 1.1))

func _spawn_debris(origin: Vector3, kind: String, amount: int) -> void:
	var particles := CPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.amount = amount
	particles.lifetime = 0.85
	particles.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 55.0
	particles.initial_velocity_min = 2.2
	particles.initial_velocity_max = 5.5
	particles.gravity = Vector3(0, -14.0, 0)
	particles.damping_min = 1.5
	particles.damping_max = 3.5
	particles.scale_amount_min = 0.08
	particles.scale_amount_max = 0.18
	particles.angular_velocity_min = -180.0
	particles.angular_velocity_max = 180.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BLOCK_COLORS.get(kind, Color(0.5, 0.5, 0.5))
	mat.roughness = 0.9
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.14, 0.14, 0.14)
	particles.mesh = mesh
	particles.material_override = mat
	add_child(particles)
	particles.global_position = origin
	var timer := get_tree().create_timer(1.2)
	timer.timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)

func _play_at(pos: Vector3, stream: AudioStream, pitch: float) -> void:
	if stream == null or _players.is_empty():
		return
	var p: AudioStreamPlayer3D = _players[_pool_index]
	_pool_index = (_pool_index + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.global_position = pos
	p.play()

func _make_dig_wav(dur: float, noise_amt: float, tone_hz: float, volume: float) -> AudioStreamWAV:
	var n := int(dur * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var prev := 0.0
	for i in range(n):
		var tt := float(i) / SAMPLE_RATE
		var env := exp(-tt * (8.0 / maxf(dur, 0.05)))
		var noise := (randf() * 2.0 - 1.0)
		prev = prev * 0.6 + noise * 0.4
		var tone := sin(TAU * tone_hz * tt) * 0.35
		var sample := clampf((prev * noise_amt + tone) * env * volume, -1.0, 1.0)
		var s16 := int(sample * 30000.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav

func _make_place_wav() -> AudioStreamWAV:
	return _make_dig_wav(0.08, 0.35, 160.0, 0.55)

func _make_swing_wav() -> AudioStreamWAV:
	var n := int(0.12 * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var tt := float(i) / SAMPLE_RATE
		var env := exp(-tt * 22.0)
		var s := sin(TAU * (90.0 + tt * 400.0) * tt) * 0.4 * env
		var s16 := int(clampf(s, -1.0, 1.0) * 28000.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav

func _make_hit_wav() -> AudioStreamWAV:
	return _make_dig_wav(0.1, 0.5, 120.0, 0.7)
