extends SceneTree

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_capture")


func _clear_review_tree_occluders(gameplay: Node3D) -> int:
	var world_blocks: Dictionary = gameplay.get("blocks")
	var removed_positions: Array[Vector3i] = []
	var rebuild_chunks: Dictionary = {}
	for position_variant in world_blocks.keys():
		var position: Vector3i = position_variant
		var kind := str(world_blocks[position])
		if kind not in ["wood", "leaves"]:
			continue
		# Preserve bridge deck framing, girders and rails. This is a review-only
		# copy of the world, so non-bridge tree voxels can be removed to expose
		# the complete river corridor without changing gameplay generation.
		var is_bridge_timber := position.x >= -2 and position.x <= 2 \
			and position.y >= 3 and position.y <= 8 \
			and position.z >= -24 and position.z <= -10
		if is_bridge_timber:
			continue
		removed_positions.append(position)

	var loaded_chunks: Dictionary = gameplay.get("loaded_chunks")
	for position in removed_positions:
		world_blocks.erase(position)
		var chunk_key: Vector2i = gameplay.call("_chunk_key_from_world", position.x, position.z)
		if loaded_chunks.has(chunk_key):
			rebuild_chunks[chunk_key] = true
	for chunk_variant in rebuild_chunks:
		gameplay.call("_rebuild_chunk", chunk_variant)
	print("GAMEPLAY_WORLD_REVIEW_TREE_OCCLUDERS_REMOVED=", removed_positions.size(),
		" rebuilt_chunks=", rebuild_chunks.size())
	return removed_positions.size()


func _capture() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("Could not load scenes/main.tscn")
		quit(2)
		return

	var scene := packed.instantiate() as Node3D
	if scene == null:
		push_error("Gameplay root is not Node3D")
		quit(3)
		return
	root.add_child(scene)
	current_scene = scene

	var ready := false
	for _frame in range(600):
		await process_frame
		if scene.world_initialized and scene.loaded_chunks.size() >= 12:
			ready = true
			break
	if not ready:
		push_error("Gameplay capture timed out before terrain/chunk streaming completed")
		quit(4)
		return

	# Lock the visual review to a clear midday state so weather RNG cannot
	# make screenshots appear dark or fogged between CI runs.
	var survival := scene.get_node_or_null("Survival")
	if survival:
		survival.set("time_of_day", 0.5)
		survival.set("weather", 0)
		survival.set("_target_weather", 0)
		survival.set("_weather_blend", 1.0)
		survival.set("_weather_timer", 999.0)
		survival.call("_update_day_night", 0.0)
		survival.call("_update_weather", 0.0)
		var rain_particles := survival.get("_rain") as GPUParticles3D
		if rain_particles:
			rain_particles.emitting = false
			rain_particles.restart()

	var toast_label := scene.get("toast_label") as Label
	if toast_label:
		toast_label.text = ""
		toast_label.modulate.a = 0.0

	# Remove tree voxels only from this disposable review scene. The production
	# gameplay camera is captured separately with its normal flora and HUD.
	var removed_tree_voxels := _clear_review_tree_occluders(scene)
	if removed_tree_voxels < 1:
		push_error("Gameplay world review found no tree occluders to clear")
		quit(8)
		return

	var player := scene.get_node_or_null("Player") as CharacterBody3D
	if player:
		player.hide()
	var hidden_animals := 0
	for animal in scene.find_children("Animal_*", "CharacterBody3D", true, false):
		var animal_model := animal as Node3D
		if animal_model:
			animal_model.hide()
			hidden_animals += 1

	# This is a geometry-review frame, not a UI test. Keep the dedicated
	# gameplay-camera artifact as the separate screenshot with player and HUD.
	var hidden_controls := 0
	for control_node in scene.find_children("*", "Control", true, false):
		var control := control_node as Control
		if control and control.visible:
			control.visible = false
			hidden_controls += 1

	var river_cells := 0
	for water_x in range(-12, 13):
		for water_z in range(-30, -8):
			if str(scene.blocks.get(Vector3i(water_x, 2, water_z), "")) == "water":
				river_cells += 1
	if river_cells < 20:
		push_error("Gameplay review corridor contains too few real water cells: %d" % river_cells)
		quit(9)
		return

	var review_camera := Camera3D.new()
	review_camera.name = "RiverBridgeReviewCamera"
	scene.add_child(review_camera)
	review_camera.global_position = Vector3(20.0, 12.0, -16.0)
	review_camera.look_at(Vector3(0.0, 3.0, -16.0), Vector3.UP)
	review_camera.fov = 55.0
	review_camera.current = true
	print("GAMEPLAY_WORLD_REVIEW_CAMERA position=", review_camera.global_position,
		" target=", Vector3(0.0, 3.0, -16.0),
		" river_cells=", river_cells,
		" animals_hidden=", hidden_animals,
		" controls_hidden=", hidden_controls)

	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.is_empty():
		push_error("Gameplay capture returned an empty image")
		quit(5)
		return
	if image.get_width() != 1280 or image.get_height() != 720:
		push_error("Unexpected capture size: %sx%s" % [image.get_width(), image.get_height()])
		quit(6)
		return

	var output_path := ProjectSettings.globalize_path("res://gameplay_world_capture.png")
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Could not save gameplay screenshot: %s" % error)
		quit(7)
		return

	print("GAMEPLAY_WORLD_CAPTURE=", output_path, " blocks=", scene.blocks.size(),
		" animals=", hidden_animals, " chunks=", scene.loaded_chunks.size(),
		" review_tree_voxels_removed=", removed_tree_voxels)
	quit(0)
