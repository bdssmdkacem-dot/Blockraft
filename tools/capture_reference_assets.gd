extends SceneTree

func _initialize() -> void:
    root.size = Vector2i(1280, 720)
    call_deferred("_capture")


func _capture() -> void:
    var packed := load("res://scenes/asset_gallery.tscn") as PackedScene
    if packed == null:
        push_error("Could not load asset_gallery.tscn")
        quit(2)
        return
    var scene := packed.instantiate()
    root.add_child(scene)
    for _frame in range(6):
        await process_frame
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    if image.is_empty() or image.get_width() != 1280 or image.get_height() != 720:
        push_error("Asset gallery capture is empty or has unexpected dimensions")
        quit(3)
        return
    var output_path := ProjectSettings.globalize_path("res://reference_assets_capture.png")
    var error := image.save_png(output_path)
    if error != OK:
        push_error("Could not save reference asset screenshot: %s" % error)
        quit(4)
        return
    print("REFERENCE_ASSETS_CAPTURE=", output_path, " size=", image.get_width(), "x", image.get_height())
    quit(0)
