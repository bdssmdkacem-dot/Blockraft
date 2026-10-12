extends SceneTree

func _initialize() -> void:
    # Use a deterministic design resolution so the artifact is comparable
    # between CI runs instead of inheriting the runner's default viewport.
    root.size = Vector2i(1280, 720)
    call_deferred("_capture")


func _capture() -> void:
    var packed := load("res://scenes/main_menu.tscn") as PackedScene
    if packed == null:
        push_error("Could not load main_menu.tscn")
        quit(2)
        return

    var scene := packed.instantiate()
    root.add_child(scene)
    # Let the SubViewport render its 3D world before reading the root texture.
    for _frame in range(4):
        await process_frame
    await RenderingServer.frame_post_draw

    var image := root.get_texture().get_image()
    if image.is_empty():
        push_error("Main menu capture returned an empty image")
        quit(3)
        return

    if image.get_width() != 1280 or image.get_height() != 720:
        push_error("Unexpected capture size: %sx%s" % [image.get_width(), image.get_height()])
        quit(4)
        return

    var output_path := ProjectSettings.globalize_path("res://main_menu_capture.png")
    var error := image.save_png(output_path)
    if error != OK:
        push_error("Could not save main menu screenshot: %s" % error)
        quit(5)
        return

    print("MAIN_MENU_CAPTURE=", output_path, " size=", image.get_width(), "x", image.get_height())
    quit(0)
