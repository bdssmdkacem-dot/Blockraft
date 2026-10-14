extends Node
## Mining / placing / combat feedback: debris + procedural SFX.

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
	for i in range(4):
		var p := AudioStreamPlayer3D.new()
		p.max_distance = 48.0
		p.unit_size = 10.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.volume_db = 2.0
		add_child(p)
		_players.append(p)

func play_break(world_pos: Vector3, kind: String) -> void:
	_spawn_particles(world_pos, kind, 14, 3.2)
	var stream: AudioStreamWAV = _dig_streams.get(kind, _dig_streams["dirt"])
	_play_at(world_pos, stream, 0.0)

func play_place(world_pos: Vector3, kind: String) -> void:
	_spawn_particles(world_pos, kind, 6, 1.4)
	_play_at(world_pos, _place_stream, -2.0)

func play_swing(world_pos: Vector3) -> void:
	_play_at(world_pos, _swing_stream, -4.0)

func play_combat_hit(world_pos: Vector3) -> void:
	_spawn_particles(world_pos, "stone", 8, 2.0)
	_play_at(world_pos, _hit_stream, -1.0)

func _play_at(world_pos: Vector3, stream: AudioStream, volume_db: float) -> void:
	if _players.is_empty() or stream == null:
		return
	var p: AudioStreamPlayer3D = _players[_pool_index]
	_pool_index = (_pool_index + 1) % _players.size()
	p.stop()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.92, 1.08)
	p.global_position = world_pos + Vector3(0.5, 0.5, 0.5)
	p.play()

func _make_dig_wav(duration: float, noise_amt: float, base_hz: float, volume: float) -> AudioStreamWAV:
	var n := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var prev := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 18.0)
		var body := sin(TAU * base_hz * t) * 0.35 * env
		body += sin(TAU * base_hz * 1.5 * t) * 0.15 * env
		var noise := (randf() * 2.0 - 1.0)
		prev = prev * 0.65 + noise * 0.35
		var grit := prev * noise_amt * env
		var tick := 0.0
		if t < 0.012:
			tick = sin(TAU * 1800.0 * t) * (1.0 - t / 0.012) * 0.4
		var sample := clampf((body + grit + tick) * volume, -1.0, 1.0)
		var s16 := int(sample * 32767.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav

func _make_place_wav() -> AudioStreamWAV:
	var n := int(0.07 * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 28.0)
		var sample := sin(TAU * 380.0 * t) * 0.4 * env + sin(TAU * 520.0 * t) * 0.2 * env
		sample += (randf() * 2.0 - 1.0) * 0.08 * env
		sample = clampf(sample * 0.7, -1.0, 1.0)
		var s16 := int(sample * 32767.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav

func _make_swing_wav() -> AudioStreamWAV:
	var n := int(0.12 * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 22.0) * (1.0 if t > 0.01 else t / 0.01)
		var whoosh := (randf() * 2.0 - 1.0) * 0.25 * env
		whoosh += sin(TAU * (400.0 - t * 800.0) * t) * 0.15 * env
		var s16 := int(clampf(whoosh, -1.0, 1.0) * 28000.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav

func _make_hit_wav() -> AudioStreamWAV:
	var n := int(0.1 * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var prev := 0.0
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 25.0)
		var body := sin(TAU * 180.0 * t) * 0.45 * env + sin(TAU * 90.0 * t) * 0.3 * env
		var noise := (randf() * 2.0 - 1.0)
		prev = prev * 0.5 + noise * 0.5
		var sample := clampf((body + prev * 0.3 * env) * 0.9, -1.0, 1.0)
		var s16 := int(sample * 32767.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav

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
