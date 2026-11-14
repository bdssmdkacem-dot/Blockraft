extends SceneTree

const SESSION_FRAMES := 1800
const WAIT_PER_STOP := 90
const MAX_MEMORY_GROWTH_BYTES := 48 * 1024 * 1024
const MAX_OBJECT_GROWTH := 2500
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
	var object_start := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var object_peak := object_start
	var frames := 0
	var route_index := 0
	var max_loaded: int = scene.loaded_chunks.size()
	var chunk_build_start := int(scene.chunk_build_count)
	var render_triangles_start := int(scene.chunk_render_triangle_count_total)
	var full_cube_triangles_start := int(scene.chunk_render_full_cube_triangle_equivalent_total)
	var render_bytes_start := int(scene.chunk_render_vertex_bytes_total)
	var render_quads_start := int(scene.chunk_render_face_quads_total)
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

	# Let the final streaming queue drain before measuring retained resources.
	for _i in range(240):
		await process_frame
		var pending_chunks: Array = scene.get("_chunk_queue")
		if pending_chunks.is_empty():
			break
	# Allow deferred node destruction to complete before the final sample.
	for _i in range(12):
		await process_frame
	var memory_end := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var object_end := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var built := int(scene.chunk_build_count) - chunk_build_start
	var peak_ms := float(scene.chunk_build_ms_peak)
	var peak_chunks := int(scene.chunk_peak_loaded)
	var render_triangles := int(scene.chunk_render_triangle_count_total) - render_triangles_start
	var full_cube_triangles := int(scene.chunk_render_full_cube_triangle_equivalent_total) - full_cube_triangles_start
	var render_bytes := int(scene.chunk_render_vertex_bytes_total) - render_bytes_start
	var render_quads := int(scene.chunk_render_face_quads_total) - render_quads_start
	var triangle_ratio := float(render_triangles) / maxf(1.0, float(full_cube_triangles))
	print("LONG_SESSION_METRICS frames=", frames,
		" route_stops=", route_index,
		" chunk_builds=", built,
		" loaded_peak=", max_loaded,
		" lifetime_loaded_peak=", peak_chunks,
		" chunk_build_peak_ms=", peak_ms,
		" indexed_render_triangles=", render_triangles,
		" full_cube_triangle_equivalent=", full_cube_triangles,
		" triangle_ratio=", snappedf(triangle_ratio, 0.001),
		" exposed_face_quads=", render_quads,
		" cumulative_render_buffer_bytes=", render_bytes,
		" memory_start_bytes=", memory_start,
		" memory_peak_bytes=", memory_peak,
		" memory_end_bytes=", memory_end,
		" object_start=", object_start,
		" object_peak=", object_peak,
		" object_end=", object_end)
	if full_cube_triangles <= 0 or render_triangles <= 0 or triangle_ratio >= 0.8:
		_fail("culled mesh did not reduce triangles by at least 20%% versus full-cube instancing: ratio=%.3f" % triangle_ratio, 12)
		return
	if built < 40:
		_fail("stress route did not exercise enough chunk rebuild/stream operations: %d" % built, 6)
		return
	if scene.loaded_chunks.size() > 49 or peak_chunks > 49:
		_fail("chunk residency exceeded the expected streaming window", 7)
		return
	if memory_start <= 0 or memory_end <= 0 or object_start <= 0 or object_end <= 0:
		_fail("memory/object monitors returned invalid readings", 8)
		return
	var retained_memory_growth := memory_end - memory_start
	var retained_object_growth := object_end - object_start
	if retained_memory_growth > MAX_MEMORY_GROWTH_BYTES:
		_fail("retained static memory grew by %d bytes (limit %d)" % [retained_memory_growth, MAX_MEMORY_GROWTH_BYTES], 9)
		return
	if retained_object_growth > MAX_OBJECT_GROWTH:
		_fail("retained object count grew by %d (limit %d)" % [retained_object_growth, MAX_OBJECT_GROWTH], 10)
		return
	if peak_ms > 120.0:
		_fail("a single chunk build exceeded the 120ms desktop acceptance budget: %.1fms" % peak_ms, 11)
		return
	print("LONG_SESSION_ACCEPTANCE_PASS: repeated navigation, bounded chunk residency, retained memory/object growth and chunk build timings verified")
	quit(0)
