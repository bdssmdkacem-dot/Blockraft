extends SceneTree

func _initialize() -> void:
    call_deferred("_run_checks")


func _fail(message: String, code: int) -> void:
    push_error("Acceptance test: " + message)
    quit(code)


func _run_checks() -> void:
    root.size = Vector2i(1280, 720)
    var packed := load("res://scenes/main_menu.tscn") as PackedScene
    if packed == null:
        _fail("main_menu.tscn failed to load", 2)
        return

    var scene := packed.instantiate() as Control
    if scene == null:
        _fail("menu root is not a Control", 3)
        return
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame

    var backdrop := scene.find_child("ThreeDMenuBackdrop", true, false) as SubViewportContainer
    if backdrop == null:
        _fail("real-time 3D menu backdrop is missing", 23)
        return
    var world_viewport := backdrop.get_node_or_null("WorldViewport") as SubViewport
    if world_viewport == null:
        _fail("3D menu SubViewport is missing", 24)
        return
    var world := world_viewport.get_node_or_null("VoxelMenuWorld") as Node3D
    if world == null:
        _fail("3D voxel menu world did not instantiate", 25)
        return
    var camera := world.find_child("MenuWorldCamera", true, false) as Camera3D
    if camera == null:
        _fail("3D menu world has no perspective camera", 26)
        return
    if camera.rotation.x > -0.05:
        _fail("menu camera is not pitched down toward the voxel landscape", 29)
        return
    if world.find_child("GoldenHourSun", true, false) == null:
        _fail("3D menu world has no key light", 27)
        return
    if world.find_child("FloatingIsland", true, false) == null:
        _fail("3D menu world is missing its floating island landmark", 28)
        return

    var strip := scene.find_child("FeatureStrip", true, false) as HBoxContainer
    if strip == null:
        _fail("FeatureStrip is missing", 4)
        return
    if strip.get_child_count() != 6:
        _fail("expected six feature cards, got %s" % strip.get_child_count(), 5)
        return

    var expected_actions := ["▶   PLAY WORLD", "▦   WORLDS", "⚒   HOW TO PLAY", "⚙   SETTINGS"]
    var buttons_found := {}
    for node in scene.find_children("*", "Button", true, false):
        if node is Button:
            buttons_found[(node as Button).text] = true
    for caption in expected_actions:
        if not buttons_found.has(caption):
            _fail("missing main action button: %s" % caption, 6)
            return

    var card_index := 0
    for card_node in strip.get_children():
        var card := card_node as Control
        if card == null:
            _fail("feature card %s is not a Control" % card_index, 15)
            return
        var art := card.find_child("CardArtwork", true, false) as TextureRect
        if art == null:
            _fail("feature card %s is missing CardArtwork" % card_index, 16)
            return
        if art.texture == null:
            _fail("feature card %s failed to load its SVG texture" % card_index, 17)
            return
        if art.size.x <= 0.0 or art.size.y <= 0.0:
            _fail("feature card %s artwork has zero size" % card_index, 18)
            return
        if art.stretch_mode != TextureRect.STRETCH_SCALE:
            _fail("feature card %s artwork is not configured to fill its card" % card_index, 19)
            return
        var hit_nodes := card.find_children("*", "Button", true, false)
        var hit_area := hit_nodes[0] as Button if not hit_nodes.is_empty() else null
        if hit_area == null:
            _fail("feature card %s has no accessible hit area" % card_index, 7)
            return
        if hit_area.pressed.get_connections().is_empty():
            _fail("feature card %s hit area has no action connection" % card_index, 8)
            return
        card_index += 1

    # Exercise the same layout function at common 16:9 and narrow Android
    # landscape sizes, then ensure the scaled feature strip remains in bounds.
    for viewport_size in [Vector2(1280, 720), Vector2(960, 540), Vector2(854, 480), Vector2(800, 360)]:
        scene.size = viewport_size
        scene._apply_responsive_layout()
        await process_frame
        var strip_rect := strip.get_global_rect()
        if strip_rect.position.x < -1.0 or strip_rect.end.x > viewport_size.x + 1.0:
            _fail("feature strip exceeds horizontal bounds at %s" % viewport_size, 9)
            return
        if strip_rect.position.y < -1.0 or strip_rect.end.y > viewport_size.y + 1.0:
            _fail("feature strip exceeds vertical bounds at %s" % viewport_size, 14)
            return
        var previous_card_end := strip_rect.position.x
        for card_i in range(strip.get_child_count()):
            var card := strip.get_child(card_i) as Control
            var card_rect := card.get_global_rect()
            if card_rect.position.x < strip_rect.position.x - 1.0 or card_rect.end.x > strip_rect.end.x + 1.0:
                _fail("card %s exceeds strip horizontal bounds at %s" % [card_i, viewport_size], 20)
                return
            if card_rect.position.y < strip_rect.position.y - 1.0 or card_rect.end.y > strip_rect.end.y + 1.0:
                _fail("card %s exceeds strip vertical bounds at %s" % [card_i, viewport_size], 21)
                return
            if card_i > 0 and card_rect.position.x < previous_card_end - 1.0:
                _fail("feature cards overlap at %s" % viewport_size, 22)
                return
            previous_card_end = card_rect.end.x
    scene.size = Vector2(393, 852)
    scene._apply_responsive_layout()
    await process_frame
    var portrait_panel := scene.find_child("MainMenuPanel", true, false) as Control
    var portrait_title := scene.find_child("GameTitle", true, false) as Control
    var portrait_footer := scene.find_child("Footer", true, false) as Control
    if strip.visible:
        _fail("feature gallery should be hidden in portrait", 29)
        return
    if portrait_panel == null or portrait_panel.scale != Vector2.ONE:
        _fail("portrait menu panel missing or incorrectly scaled", 30)
        return
    var portrait_rect := portrait_panel.get_global_rect()
    if portrait_rect.position.x < 0.0 or portrait_rect.end.x > 393.0:
        _fail("portrait menu panel exceeds viewport bounds", 31)
        return
    if portrait_title == null or portrait_title.scale != Vector2.ONE:
        _fail("portrait title missing or incorrectly scaled", 32)
        return
    if portrait_footer != null and portrait_footer.visible:
        _fail("footer should be hidden in portrait", 33)
        return

    scene.size = Vector2(1280, 720)
    scene._apply_responsive_layout()
    await process_frame
    if not strip.visible or (portrait_footer != null and not portrait_footer.visible):
        _fail("landscape elements were not restored", 34)
        return

    scene._on_menu_action("worlds")
    await process_frame
    var dialog := scene.find_child("MenuDialog", true, false)
    if dialog == null:
        _fail("Worlds action did not open MenuDialog", 10)
        return
    scene._on_dialog_action("close")
    await process_frame

    scene._on_menu_action("help")
    await process_frame
    dialog = scene.find_child("MenuDialog", true, false)
    if dialog == null:
        _fail("How to Play action did not open MenuDialog", 11)
        return
    scene._on_dialog_action("close")
    await process_frame

    scene._on_menu_action("settings")
    await process_frame
    dialog = scene.find_child("MenuDialog", true, false)
    if dialog == null:
        _fail("Settings action did not open MenuDialog", 12)
        return
    scene._on_dialog_action("close")
    await process_frame

    scene._start_game()
    await process_frame
    await process_frame
    if current_scene == null or current_scene.scene_file_path != "res://scenes/main.tscn":
        _fail("Play World did not transition to scenes/main.tscn", 13)
        return

    print("MENU_ACCEPTANCE_PASS: responsive layout at four viewport sizes, six loaded SVG artworks with per-card bounds, six interactive feature cards, four primary actions, three dialogs, and gameplay transition verified")
    quit(0)
