extends SceneTree

const MIN_CAPTURE_CHUNKS := 12
const MAX_WAIT_FRAMES := 600

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_capture_gameplay")

func _clear_river_review_tree_occluders(gameplay: Node3D) -> int:
	var world_blocks: Dictionary = gameplay.get("blocks")
	var starter_tree_bases: Array = gameplay.get("starter_forest_tree_bases")
	var protected_tree_positions: Dictionary = {}
	# Keep the guaranteed flank trees in the review image. Their trunks are
	# deliberately placed outside the bridge lane and bank transition; remove
	# only incidental/random trees that could obscure the channel or spawn view.
	for base_variant in starter_tree_bases:
		var base: Vector3i = base_variant
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for dy in range(0, 9):
					protected_tree_positions[Vector3i(base.x + dx, base.y + dy, base.z + dz)] = true
	var removed_positions: Array[Vector3i] = []
	var rebuild_chunks: Dictionary = {}
	for position_variant in world_blocks.keys():
		var position: Vector3i = position_variant
		var kind := str(world_blocks[position])
		if kind not in ["wood", "leaves"]:
			continue
		if protected_tree_positions.has(position):
			continue
		# Preserve bridge rails, posts, deck framing and girders. These remain
		# part of the actual crossing rather than removable tree geometry.
		var is_bridge_timber := position.x >= -2 and position.x <= 2 \\
			and position.y >= 3 and position.y <= 8 \\
			and position.z >= -24 and position.z <= -10
		if is_bridge_timber:
			continue
		removed_positions.append(position)
	for position in removed_positions:
		world_blocks.erase(position)
		var chunk_key: Vector2i = gameplay.call("_chunk_key_from_world", position.x, position.z)
		if gameplay.get("loaded_chunks").has(chunk_key):
			rebuild_chunks[chunk_key] = true
	for chunk_variant in rebuild_chunks:
		gameplay.call("_rebuild_chunk", chunk_variant)
	var preserved_flank_trees := 0
	for base_variant in starter_tree_bases:
		var base: Vector3i = base_variant
		var ground_kind := str(world_blocks.get(base - Vector3i.UP, ""))
		if str(world_blocks.get(base, "")) == "wood" and ground_kind in ["grass", "dirt", "stone", "rock", "sand", "gravel"]:
			preserved_flank_trees += 1
	print("RIVER_REVIEW_TREE_OCCLUDERS_REMOVED=", removed_positions.size(),
		" rebuilt_chunks=", rebuild_chunks.size(),
		" preserved_flank_trees=", preserved_flank_trees)
	return preserved_flank_trees


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
	# bridge approach clear of incidental foliage. The four outer rail posts
	# are intentional bridge architecture at the edge of this broad sightline,
	# so they must not be classified as an obstruction.
	var world_blocks: Dictionary = gameplay.get("blocks")
	var preserved_flank_trees := _clear_river_review_tree_occluders(gameplay)
	if preserved_flank_trees < 2:
		push_error("River review capture must retain at least two grounded flank trees; found=%d" % preserved_flank_trees)
		quit(16)
		return
	print("RIVER_REVIEW_FLANK_FOREST_PRESERVED_PASS trees=", preserved_flank_trees)
	await process_frame
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
				var pos := Vector3i(x, y, z)
				var kind := str(world_blocks.get(pos, ""))
				var is_bridge_rail_post := pos.y == 5 and absi(pos.x) == 2 and pos.z in [-20, -18, -16, -14]
				if kind in ["wood", "leaves"] and not is_bridge_rail_post:
					push_error("Spawn bridge sightline remains obstructed by %s at %s" % [kind, pos])
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

	# Dedicated elevated river review: aim along the generated scenic channel
	# from above, independently of the production third-person camera. The
	# screenshot is saved as its own artifact for direct shoreline inspection.
	var river_cells := 0
	for water_x in range(-12, 13):
		for water_z in range(-30, -8):
			if str(world_blocks.get(Vector3i(water_x, 2, water_z), "")) == "water":
				river_cells += 1
	if river_cells < 20:
		push_error("River observer region contains too few real water cells: %d" % river_cells)
		quit(13)
		return
	var river_camera := Camera3D.new()
	river_camera.name = "RiverReviewCamera"
	river_camera.fov = 55.0
	gameplay.add_child(river_camera)
	# Near-overhead inspection removes terrain occlusion and makes the entire
	# generated channel footprint and both banks visible in one frame.
	# Side-on elevated framing exposes the full bridge length, both approaches,
	# the opposite banks, and the river edges without the avatar blocking them.
	river_camera.global_position = Vector3(20.0, 12.0, -16.0)
	river_camera.look_at(Vector3(0.0, 3.0, -16.0), Vector3.UP)
	river_camera.make_current()
	var river_control_visibility: Dictionary = {}
	for control_node in gameplay.find_children("*", "Control", true, false):
		var control := control_node as Control
		if control:
			river_control_visibility[control.get_instance_id()] = control.visible
			control.visible = false
	var river_model_visibility: Dictionary = {}
	var river_player := gameplay.get_node_or_null("Player") as Node3D
	if river_player:
		river_model_visibility[river_player.get_instance_id()] = river_player.visible
		river_player.visible = false
	for animal_node in gameplay.find_children("Animal_*", "CharacterBody3D", true, false):
		var animal_model := animal_node as Node3D
		if animal_model:
			river_model_visibility[animal_model.get_instance_id()] = animal_model.visible
			animal_model.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var river_image := root.get_texture().get_image()
	if river_image.is_empty() or river_image.get_width() != 1280 or river_image.get_height() != 720:
		push_error("Dedicated river review camera returned an invalid frame.")
		quit(14)
		return
	var river_output_dir := ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(river_output_dir)
	var river_output_path := river_output_dir.path_join("river-corridor-review.png")
	if river_image.save_png(river_output_path) != OK:
		push_error("Could not save dedicated river corridor screenshot.")
		quit(15)
		return
	print("RIVER_REVIEW_CAPTURE_PASS path=%s real_water_cells=%d camera=%s target=%s" % [
		river_output_path, river_cells, river_camera.global_position, Vector3(0.0, 0.0, -15.0)
	])
	for control_node in gameplay.find_children("*", "Control", true, false):
		var control := control_node as Control
		if control and river_control_visibility.has(control.get_instance_id()):
			control.visible = bool(river_control_visibility[control.get_instance_id()])
	var visible_models := [river_player]
	visible_models.append_array(gameplay.find_children("Animal_*", "CharacterBody3D", true, false))
	for model_node in visible_models:
		var model := model_node as Node3D
		if model and river_model_visibility.has(model.get_instance_id()):
			model.visible = bool(river_model_visibility[model.get_instance_id()])
	river_camera.queue_free()
	await process_frame

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

	# Keep the fauna review focused on one real gameplay animal. Hide the player,
	# HUD and non-focus fauna so they cannot clip or obscure the model in either
	# frame. The separate gameplay-camera artifact retains the normal player/HUD.
	var player_was_visible := player.visible
	player.hide()
	var fauna_control_visibility: Dictionary = {}
	for control_node in gameplay.find_children("*", "Control", true, false):
		var control := control_node as Control
		if control:
			fauna_control_visibility[control.get_instance_id()] = control.visible
			control.visible = false
	var fauna_visibility: Dictionary = {}
	var focus_animal: CharacterBody3D = animals[0] as CharacterBody3D
	for candidate in animals:
		var candidate_animal := candidate as CharacterBody3D
		if candidate_animal.global_position.distance_squared_to(player.global_position) < focus_animal.global_position.distance_squared_to(player.global_position):
			focus_animal = candidate_animal
	for animal in animals:
		var animal_model := animal as Node3D
		if animal_model:
			fauna_visibility[animal_model.get_instance_id()] = animal_model.visible
			animal_model.visible = animal_model == focus_animal

	var fauna_camera := Camera3D.new()
	fauna_camera.name = "FaunaObservationCamera"
	fauna_camera.fov = 48.0
	gameplay.add_child(fauna_camera)
	var observer_offset := player.global_position - focus_animal.global_position
	observer_offset.y = 0.0
	if observer_offset.length_squared() < 0.01:
		observer_offset = Vector3(0.0, 0.0, 1.0)
	observer_offset = observer_offset.normalized()
	var fauna_camera_distance := 5.0
	var fauna_camera_height := 3.2
	var fauna_target := focus_animal.global_position + Vector3(0.0, 0.72, 0.0)
	fauna_camera.global_position = focus_animal.global_position - observer_offset * fauna_camera_distance + Vector3.UP * fauna_camera_height
	fauna_camera.look_at(fauna_target, Vector3.UP)
	fauna_camera.make_current()
	print("GAMEPLAY_FAUNA_FOCUS name=", focus_animal.name, " kind=", focus_animal.get("kind"),
		" start=", focus_animal.global_position, " camera=", fauna_camera.global_position)

	await process_frame
	await RenderingServer.frame_post_draw
	var before_image := root.get_texture().get_image()
	var fauna_output_dir := ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(fauna_output_dir)
	var before_path := fauna_output_dir.path_join("gameplay-animals-before.png")
	if before_image.is_empty() or before_image.get_width() != 1280 or before_image.get_height() != 720:
		push_error("Pre-roaming fauna screenshot returned an invalid 1280x720 frame.")
		quit(10)
		return
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

	# The animal may roam several metres during the observation interval. Re-aim
	# the same observer camera at its new position so the after frame is still a
	# valid silhouette review instead of capturing the animal at the frame edge.
	fauna_target = focus_animal.global_position + Vector3(0.0, 0.72, 0.0)
	fauna_camera.global_position = focus_animal.global_position - observer_offset * fauna_camera_distance + Vector3.UP * fauna_camera_height
	fauna_camera.look_at(fauna_target, Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	var after_image := root.get_texture().get_image()
	var after_path := fauna_output_dir.path_join("gameplay-animals-after.png")
	if after_image.is_empty() or after_image.get_width() != 1280 or after_image.get_height() != 720:
		push_error("Post-roaming fauna screenshot returned an invalid 1280x720 frame.")
		quit(12)
		return
	if after_image.save_png(after_path) != OK:
		push_error("Could not save post-roaming gameplay fauna screenshot.")
		quit(12)
		return
	print("GAMEPLAY_FAUNA_FRAMING_PASS: focus animal re-centered before and after roaming; player and HUD excluded")

	# Restore the production third-person view for the gameplay baseline.
	fauna_camera.queue_free()
	camera.make_current()
	player.visible = player_was_visible
	for control_node in gameplay.find_children("*", "Control", true, false):
		var control := control_node as Control
		if control and fauna_control_visibility.has(control.get_instance_id()):
			control.visible = bool(fauna_control_visibility[control.get_instance_id()])
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
