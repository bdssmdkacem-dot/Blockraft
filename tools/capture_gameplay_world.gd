extends SceneTree

func _initialize() -> void:
    root.size = Vector2i(1280, 720)
    call_deferred("_capture")


func _clear_review_sightline(scene: Node3D, camera_position: Vector3, target: Vector3) -> void:
	# Remove only voxel trees that physically occlude the fixed geometry-review
	# camera. This is a capture-only cleanup; the gameplay world is never saved.
	var view_direction := (target - camera_position).normalized()
	var right_direction := view_direction.cross(Vector3.UP).normalized()
	var up_direction := right_direction.cross(view_direction).normalized()
	var removed_positions: Array[Vector3i] = []
	var chunk_keys: Dictionary = {}
	for position_variant in scene.blocks.keys():
		var position: Vector3i = position_variant
		var kind := str(scene.blocks[position])
		if kind not in ["wood", "leaves"]:
			continue
		# Preserve the wooden river bridge itself.
		if kind == "wood" and abs(position.x) <= 3 and position.z >= -25 and position.z <= -10:
			continue
		var centre := Vector3(float(position.x) + 0.5, float(position.y) + 0.5, float(position.z) + 0.5)
		var relative := centre - camera_position
		var along := relative.dot(view_direction)
		if along < 2.0 or along > 65.0:
			continue
		var horizontal_offset := absf(relative.dot(right_direction))
		var vertical_offset := absf(relative.dot(up_direction))
		if horizontal_offset > along * tan(deg_to_rad(41.0)) or vertical_offset > along * tan(deg_to_rad(26.0)):
			continue
		removed_positions.append(position)
		chunk_keys[Vector2i(floori(float(position.x) / 16.0), floori(float(position.z) / 16.0))] = true
	for position in removed_positions:
		scene.blocks.erase(position)
	for chunk_variant in chunk_keys:
		var chunk_key: Vector2i = chunk_variant
		if not scene.loaded_chunks.has(chunk_key):
			continue
		var old_chunk := scene.loaded_chunks[chunk_key] as Node3D
		scene.loaded_chunks.erase(chunk_key)
		scene.remove_child(old_chunk)
		old_chunk.free()
		scene.call("_load_chunk", chunk_key)
	print("RIVER_REVIEW_OCCLUDERS_REMOVED=", removed_positions.size(), " rebuilt_chunks=", chunk_keys.size())


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
    for _frame in range(180):
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

    var toast_label := scene.get("toast_label") as Label
    if toast_label:
        toast_label.text = ""
        toast_label.modulate.a = 0.0

    var player := scene.get_node_or_null("Player") as CharacterBody3D
    if player:
        # Keep the avatar out of this geometry-review frame so it cannot hide
        # the bridge deck, approaches, or shoreline.
        player.hide()
    var review_camera := Camera3D.new()
    review_camera.name = "RiverBridgeReviewCamera"
    scene.add_child(review_camera)
    review_camera.global_position = Vector3(18.0, 12.0, -16.0)
    review_camera.look_at(Vector3(0.0, 3.0, -16.0), Vector3.UP)
    review_camera.fov = 52.0
    review_camera.current = true
    _clear_review_sightline(scene, review_camera.global_position, Vector3(0.0, 3.0, -16.0))
    print("GAMEPLAY_CAPTURE_MODE=dedicated_river_bridge_review camera_position=",
        review_camera.global_position, " target=", Vector3(0.0, 3.0, -16.0))

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
        " animals=", scene.find_children("Animal_*", "CharacterBody3D", true, false).size(),
        " chunks=", scene.loaded_chunks.size())
    quit(0)
