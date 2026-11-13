extends SceneTree

const MIN_CAPTURE_CHUNKS := 12
const MAX_WAIT_FRAMES := 600

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_capture_gameplay")

func _capture_gameplay() -> void:
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	if packed_scene == null:
		push_error("Could not load gameplay scene.")
		quit(1)
		return

	var gameplay := packed_scene.instantiate() as Node3D
	if gameplay == null:
		push_error("Gameplay scene root is not Node3D.")
		quit(1)
		return
	root.add_child(gameplay)
	current_scene = gameplay

	var ready := false
	for _frame in range(MAX_WAIT_FRAMES):
		await process_frame
		var loaded_chunks: Dictionary = gameplay.get("loaded_chunks")
		if gameplay.get("world_initialized") == true and loaded_chunks.size() >= MIN_CAPTURE_CHUNKS:
			ready = true
			break
	if not ready:
		var blocks: Dictionary = gameplay.get("blocks")
		var loaded_chunks: Dictionary = gameplay.get("loaded_chunks")
		push_error("Gameplay screenshot timed out before the real world loaded: blocks=%d chunks=%d" % [blocks.size(), loaded_chunks.size()])
		quit(2)
		return

	# Regression guard: keep the immediate landing pocket clear and the
	# actual narrow bridge sightline unobstructed, while allowing the nearby
	# forest to remain visible outside the player's close camera envelope.
	var world_blocks: Dictionary = gameplay.get("blocks")
	for x in range(-8, 9):
		for z in range(-8, 9):
			if Vector2(float(x), float(z)).length() > 8.0:
				continue
			for y in range(5, 31):
				var kind := str(world_blocks.get(Vector3i(x, y, z), ""))
				if kind in ["wood", "leaves"]:
					push_error("Near spawn landing view remains obstructed by %s at %s" % [kind, Vector3i(x, y, z)])
					quit(8)
					return
	for x in range(-10, 11):
		for z in range(-28, -8):
			var view_half_width := lerpf(2.5, 4.5, inverse_lerp(-9.0, -28.0, float(z)))
			if absf(float(x) - 0.5) > view_half_width:
				continue
			for y in range(5, 31):
				var kind := str(world_blocks.get(Vector3i(x, y, z), ""))
				if kind in ["wood", "leaves"]:
					push_error("Spawn bridge sightline remains obstructed by %s at %s" % [kind, Vector3i(x, y, z)])
					quit(7)
					return

	# Deterministic visual baseline: clear midday, while preserving the
	# production third-person camera and gameplay scene.
	var survival := gameplay.get_node_or_null("Survival")
	if survival:
		survival.set("time_of_day", 0.5)
		survival.set("weather", 0)
		survival.set("_target_weather", 0)
		survival.set("_weather_blend", 1.0)
		survival.set("_weather_timer", 999.0)
		survival.call("_update_day_night", 0.0)
		# Synchronize particle emission and flush already-spawned rain streaks;
		# disabling emission alone leaves particles visible for their lifetime.
		survival.call("_update_weather", 0.0)
		var rain_particles := survival.get("_rain") as GPUParticles3D
		if rain_particles:
			rain_particles.emitting = false
			rain_particles.restart()

	var toast_label := gameplay.get("toast_label") as Label
	if toast_label:
		toast_label.text = ""
		toast_label.modulate.a = 0.0

	var player := gameplay.get_node_or_null("Player") as CharacterBody3D
	var camera := player.get_node_or_null("PlayerCamera") as Camera3D if player else null
	if camera == null:
		push_error("Gameplay screenshot could not find the player's active camera.")
		quit(3)
		return
	player.set_physics_process(false)
	camera.make_current()
	print("GAMEPLAY_CAMERA_CAPTURE=third_person player=", player.global_position, " camera=", camera.global_position)

	# Observe fauna in the real generated gameplay world, not only the isolated
	# animal gallery. Save a before/after pair so roaming is visually reviewable.
	var animals := gameplay.find_children("Animal_*", "CharacterBody3D", true, false)
	if animals.size() < 3:
		push_error("Gameplay fauna capture expected at least three spawned animals; found %d" % animals.size())
		quit(9)
		return
	var animal_start_positions: Dictionary = {}
	for animal in animals:
		animal_start_positions[animal.get_instance_id()] = animal.global_position

	# Use a temporary observer camera inside the same live gameplay world.
	# Frame the four animals nearest the player so their movement is visible
	# instead of relying on tiny distant silhouettes in the third-person view.
	# Frame the single animal nearest the player at a readable distance.
	# A centroid of several widely separated animals previously aimed the camera
	# at empty ground, making the movement capture useless despite a passing test.
	var focus_animal: CharacterBody3D = animals[0] as CharacterBody3D
	for candidate in animals:
		var candidate_animal := candidate as CharacterBody3D
		if candidate_animal.global_position.distance_squared_to(player.global_position) < focus_animal.global_position.distance_squared_to(player.global_position):
			focus_animal = candidate_animal
	var fauna_camera := Camera3D.new()
	fauna_camera.name = "FaunaObservationCamera"
	fauna_camera.fov = 48.0
	gameplay.add_child(fauna_camera)
	# A spawn-facing three-quarter view keeps the animal model large enough
	# to inspect. The separate movement assertion verifies its real world motion.
	var observer_offset := player.global_position - focus_animal.global_position
	observer_offset.y = 0.0
	if observer_offset.length_squared() < 0.01:
		observer_offset = Vector3(0.0, 0.0, 1.0)
	observer_offset = observer_offset.normalized()
	fauna_camera.global_position = focus_animal.global_position - observer_offset * 6.0 + Vector3.UP * 7.0
	fauna_camera.look_at(focus_animal.global_position + Vector3(0.0, 0.72, 0.0), Vector3.UP)
	fauna_camera.make_current()
	print("GAMEPLAY_FAUNA_FOCUS name=", focus_animal.name, " kind=", focus_animal.get("kind"), " start=", focus_animal.global_position, " camera=", fauna_camera.global_position)
	await process_frame
	await RenderingServer.frame_post_draw
	var before_image := root.get_texture().get_image()
	var fauna_output_dir := ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(fauna_output_dir)
	var before_path := fauna_output_dir.path_join("gameplay-animals-before.png")
	if before_image.save_png(before_path) != OK:
		push_error("Could not save pre-roaming gameplay fauna screenshot.")
		quit(10)
		return
	for _frame in range(180):
		await physics_frame
	var moved_animals := 0
	for animal in animals:
		if not is_instance_valid(animal):
			continue
		var start_position: Vector3 = animal_start_positions.get(animal.get_instance_id(), animal.global_position)
		if Vector2(animal.global_position.x - start_position.x, animal.global_position.z - start_position.z).length() >= 0.15:
			moved_animals += 1
	if moved_animals == 0:
		push_error("No spawned gameplay animal visibly roamed during the 180-frame observation window.")
		quit(11)
		return
	print("GAMEPLAY_FAUNA_ROAMING_PASS animals=", animals.size(), " moved=", moved_animals, " observation_frames=180")
	await process_frame
	await RenderingServer.frame_post_draw
	var after_image := root.get_texture().get_image()
	var after_path := fauna_output_dir.path_join("gameplay-animals-after.png")
	if after_image.save_png(after_path) != OK:
		push_error("Could not save post-roaming gameplay fauna screenshot.")
		quit(12)
		return
	# Restore the production third-person view for the gameplay baseline.
	fauna_camera.queue_free()
	camera.make_current()
	# Keep the final player-camera baseline unobstructed. The live fauna has
	# already been observed and captured above; aggressive chickens/foxes can
	# otherwise walk directly into the camera during the observation interval.
	for animal in animals:
		if is_instance_valid(animal):
			animal.visible = false

	await process_frame
	await RenderingServer.frame_post_draw
	var viewport_image := root.get_texture().get_image()
	if viewport_image.is_empty():
		push_error("Gameplay viewport returned an empty image.")
		quit(4)
		return
	if viewport_image.get_width() != 1280 or viewport_image.get_height() != 720:
		push_error("Unexpected gameplay screenshot size: %sx%s" % [viewport_image.get_width(), viewport_image.get_height()])
		quit(5)
		return
	# Visual regression guard: at midday the open-sky sample must retain a
	# distinctly blue channel; this catches the grey fallback seen in CI.
	var sky_sample := viewport_image.get_pixel(640, 100)
	if sky_sample.b < sky_sample.r * 1.05 or sky_sample.b < sky_sample.g * 1.08:
		push_error("Gameplay sky is not rendering the expected blue midday tint: %s" % sky_sample)
		quit(7)
		return

	var output_dir := ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var output_path := output_dir.path_join("gameplay-camera.png")
	var error := viewport_image.save_png(output_path)
	if error != OK:
		push_error("Could not save gameplay screenshot: %s" % error)
		quit(6)
		return

	print("GAMEPLAY_SCREENSHOT=%s SIZE=%sx%s BLOCKS=%d CHUNKS=%d" % [
		output_path, viewport_image.get_width(), viewport_image.get_height(),
		gameplay.blocks.size(), gameplay.loaded_chunks.size()
	])
	quit(0)
