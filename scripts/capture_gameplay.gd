extends SceneTree

func _initialize() -> void:
    call_deferred("_capture_gameplay")

func _capture_gameplay() -> void:
    var packed_scene: PackedScene = load("res://scenes/main.tscn")
    if packed_scene == null:
        push_error("Could not load gameplay scene.")
        quit(1)
        return

    var gameplay: Node = packed_scene.instantiate()
    root.add_child(gameplay)
    await process_frame
    await process_frame
    await create_timer(2.0).timeout

    var viewport_image: Image = root.get_viewport().get_texture().get_image()
    if viewport_image.is_empty():
        push_error("Gameplay viewport returned an empty image.")
        quit(1)
        return

    var output_path := "artifacts/gameplay-camera.png"
    var error := viewport_image.save_png(output_path)
    if error != OK:
        push_error("Could not save gameplay screenshot: %s" % error)
        quit(1)
        return

    print("GAMEPLAY_SCREENSHOT=%s SIZE=%sx%s" % [output_path, viewport_image.get_width(), viewport_image.get_height()])
    quit(0)
