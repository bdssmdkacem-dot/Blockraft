extends SceneTree

const SESSION_FRAMES := 1800
const WAIT_PER_STOP := 90
const ROUTE := [
	Vector3(0.5, 7.0, 0.5),
	Vector3(34.5, 16.0, 0.5),
	Vector3(66.5, 12.0, 34.5),
	Vector3(34.5, 14.0, 66.5),
	Vector3(-34.5, 13.0, 34.5),
	Vector3(-66.5, 11.0, -34.5),
	Vector3(-34.5, 15.0, -66.5),
	Vector3(0.5, 7.0, 0.5)
]

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_run")

func _fail(message: String, code: int) -> void:
	push_error("Long session acceptance: " + message)
	quit(code)

func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("gameplay scene could not load", 2)
		return
	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	var player := scene.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		_fail("player is missing", 3)
		return
	var ready := false
	for _i in range(240):
		await process_frame
		if scene.world_initialized and scene.loaded_chunks.size() >= 5:
			ready = true
			break
	if not ready:
		_fail("world did not initialize before stress route", 4)
		return

	var memory_start := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var memory_peak := memory_start
	var object_peak := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var frames := 0
	var route_index := 0
	var max_loaded: int = scene.loaded_chunks.size()
	var chunk_build_start := int(scene.chunk_build_count)
	while frames < SESSION_FRAMES:
		if frames % WAIT_PER_STOP == 0:
			var stop: Vector3 = ROUTE[route_index % ROUTE.size()]
			player.global_position = stop
			player.velocity = Vector3.ZERO
			route_index += 1
		await process_frame
		frames += 1
		max_loaded = maxi(max_loaded, scene.loaded_chunks.size())
		memory_peak = maxi(memory_peak, int(Performance.get_monitor(Performance.MEMORY_STATIC)))
		object_peak = maxi(object_peak, int(Performance.get_monitor(Performance.OBJECT_COUNT)))
		if scene.loaded_chunks.size() > 49:
			_fail("loaded chunk residency exceeded the 7x7 streaming window", 5)
			return

	# Let queued chunk frees and deferred builds settle before comparing residency.
	for _i in range(12):
		await process_frame
	var memory_end := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var object_end := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var built := int(scene.chunk_build_count) - chunk_build_start
	var peak_ms := float(scene.chunk_build_ms_peak)
	var peak_chunks := int(scene.chunk_peak_loaded)
	print("LONG_SESSION_METRICS frames=", frames,
		" route_stops=", route_index,
		" chunk_builds=", built,
		" loaded_peak=", max_loaded,
		" lifetime_loaded_peak=", peak_chunks,
		" chunk_build_peak_ms=", peak_ms,
		" memory_start_bytes=", memory_start,
		" memory_peak_bytes=", memory_peak,
		" memory_end_bytes=", memory_end,
		" object_peak=", object_peak,
		" object_end=", object_end)
	if built < 40:
		_fail("stress route did not exercise enough chunk rebuild/stream operations: %d" % built, 6)
		return
	if scene.loaded_chunks.size() > 49 or peak_chunks > 49:
		_fail("chunk residency exceeded the expected streaming window", 7)
		return
	if memory_end > 0 and memory_peak > 0 and memory_end > memory_peak:
		_fail("invalid memory monitor readings", 8)
		return
	print("LONG_SESSION_ACCEPTANCE_PASS: repeated navigation, bounded chunk residency, memory/object sampling and chunk build timings verified")
	quit(0)
