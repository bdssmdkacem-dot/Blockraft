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
