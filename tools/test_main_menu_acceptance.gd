extends SceneTree

func _initialize() -> void:
    call_deferred("_run_checks")


func _run_checks() -> void:
    root.size = Vector2i(1280, 720)
    var packed := load("res://scenes/main_menu.tscn") as PackedScene
    if packed == null:
        push_error("Acceptance test: main_menu.tscn failed to load")
        quit(2)
        return

    var scene := packed.instantiate() as Control
    if scene == null:
        push_error("Acceptance test: menu root is not a Control")
        quit(3)
        return
    root.add_child(scene)
    await process_frame
    await process_frame

    var strip := scene.find_child("FeatureStrip", true, false) as HBoxContainer
    if strip == null:
        push_error("Acceptance test: FeatureStrip is missing")
        quit(4)
        return
    if strip.get_child_count() != 6:
        push_error("Acceptance test: expected six feature cards, got %s" % strip.get_child_count())
        quit(5)
        return

    var expected_actions := ["▶   PLAY WORLD", "▦   WORLDS", "⚒   HOW TO PLAY", "⚙   SETTINGS"]
    var buttons_found := {}
    for node in scene.find_children("*", "Button", true, false):
        if node is Button:
            buttons_found[(node as Button).text] = true
    for caption in expected_actions:
        if not buttons_found.has(caption):
            push_error("Acceptance test: missing main action button: %s" % caption)
            quit(6)
            return

    if strip.offset_left < 0 or strip.offset_right > 0:
        push_error("Acceptance test: feature strip horizontal anchors/offsets are invalid")
        quit(7)
        return

    print("MENU_ACCEPTANCE_PASS: six feature cards and four primary actions found at 1280x720")
    quit(0)
