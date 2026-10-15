extends SceneTree

func _initialize() -> void:
    call_deferred("_run_checks")

func _fail(message: String, code: int) -> void:
    push_error("Gameplay acceptance: " + message)
    quit(code)

func _run_checks() -> void:
    root.size = Vector2i(1280, 720)
    var packed := load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("main.tscn failed to load", 2)
        return
    var scene := packed.instantiate() as Node3D
    if scene == null:
        _fail("gameplay root is not Node3D", 3)
        return
    root.add_child(scene)
    current_scene = scene
    var waited := 0
    while waited < 120 and (not scene.world_initialized or scene.loaded_chunks.size() < 5):
        await process_frame
        waited += 1
    if not scene.world_initialized:
        _fail("full world initialization did not finish", 14)
        return
    if scene.loaded_chunks.size() < 5:
        _fail("nearby world chunks did not stream in", 15)
        return
    if scene.blocks.size() < 20000:
        _fail("generated map is incomplete: %d blocks" % scene.blocks.size(), 16)
        return
    var fauna := scene.get_node_or_null("FloraFauna")
    if fauna == null:
        _fail("flora/fauna system was not restored", 17)
        return
    var animals := scene.find_children("Animal_*", "CharacterBody3D", true, false)
    if animals.is_empty():
        _fail("generated world has no animal assets", 18)
        return
    var block_kinds: Dictionary = {}
    for value in scene.blocks.values():
        block_kinds[str(value)] = true
    for required_kind in ["grass", "dirt", "stone", "water", "wood", "leaves", "coal", "iron", "gold", "crystal", "chest"]:
        if not block_kinds.has(required_kind):
            _fail("full map is missing block/asset kind: %s" % required_kind, 19)
            return

    var player := scene.get_node_or_null("Player") as CharacterBody3D
    if player == null:
        _fail("Player node is missing", 4)
        return
    if player.get_node_or_null("PlayerCamera") == null:
        _fail("player camera is missing", 5)
        return
    var generated := scene.get_node_or_null("GeneratedWorld") as Node3D
    if generated == null:
        _fail("GeneratedWorld was not created", 6)
        return
    if scene.blocks.is_empty():
        _fail("generated world has no blocks", 7)
        return

    var probe := Vector3i(0, 24, 0)
    scene.place_block(probe, "stone")
    if not scene.blocks.has(probe):
        _fail("placing a free block did not update the world model", 8)
        return
    scene.remove_block(probe)
    if scene.blocks.has(probe):
        _fail("mining a placed block did not remove it from the world model", 9)
        return

    scene.save_world()
    var save_path := "user://world_blocks.json"
    if not FileAccess.file_exists(save_path):
        _fail("world save file was not created", 10)
        return
    var file := FileAccess.open(save_path, FileAccess.READ)
    if file == null:
        _fail("world save file could not be opened", 11)
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("blocks"):
        _fail("world save does not contain a blocks array", 12)
        return
    for entry in parsed["blocks"]:
        if typeof(entry) == TYPE_DICTIONARY and int(entry.get("x", 9999)) == probe.x and int(entry.get("y", 9999)) == probe.y and int(entry.get("z", 9999)) == probe.z:
            _fail("deleted block was still present in the saved snapshot", 13)
            return

    print("GAMEPLAY_ACCEPTANCE_PASS: player/camera, generated blocks, place/remove model updates, and saved deletion verified")
    quit(0)
