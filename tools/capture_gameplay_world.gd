extends SceneTree

func _initialize() -> void:
    root.size = Vector2i(1280, 720)
    call_deferred("_capture")


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

    var player := scene.get_node_or_null("Player") as CharacterBody3D
    var camera := player.get_node_or_null("PlayerCamera") as Camera3D if player else null
    if camera:
        # Produce an overhead proof of the terrain, river system and full voxel surface,
        # without changing the normal in-game camera or the actual gameplay scene.
        if player:
            player.set_physics_process(false)
        camera.global_position = Vector3(25.0, 27.0, 30.0)
        camera.look_at(Vector3(0.0, 4.0, 0.0), Vector3.UP)
        camera.current = true

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
