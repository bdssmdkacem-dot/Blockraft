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

    for card in strip.get_children():
        var hit_nodes := card.find_children("*", "Button", true, false)
        var hit_area := hit_nodes[0] as Button if not hit_nodes.is_empty() else null
        if hit_area == null:
            _fail("a feature card has no accessible hit area", 7)
            return
        if hit_area.pressed.get_connections().is_empty():
            _fail("a feature card's hit area has no action connection", 8)
            return

    if strip.offset_left < 0 or strip.offset_right > 0:
        _fail("feature strip horizontal anchors/offsets are invalid", 9)
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

    print("MENU_ACCEPTANCE_PASS: six interactive feature cards, four primary actions, three dialogs, and gameplay transition verified")
    quit(0)
