extends SceneTree

const BRIDGE_X := 0.5
const DECK_Z_MIN := -20.0
const DECK_Z_MAX := -13.0
const APPROACH_ZS := [-21.5, -12.5]
const BANK_ZS := [-22.5, -11.5]

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String, code: int = 1) -> void:
    push_error("Bridge acceptance: " + message)
    quit(code)

func _ray_surface(scene: Node3D, x: float, z: float) -> Dictionary:
    var query := PhysicsRayQueryParameters3D.create(
        Vector3(x, 9.0, z),
        Vector3(x, -2.0, z)
    )
    query.collision_mask = 1
    return scene.get_world_3d().direct_space_state.intersect_ray(query)

func _run() -> void:
    root.size = Vector2i(1280, 720)
    var packed := load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("main.tscn failed to load", 2)
        return
    var scene := packed.instantiate() as Node3D
    if scene == null:
        _fail("gameplay root is not Node3D", 3)
        return
    scene.call("_clear_old_save")
    var backup := "user://world_blocks.json.bak"
    if FileAccess.file_exists(backup):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
    root.add_child(scene)
    current_scene = scene

    var waited := 0
    var required_chunks := [
        Vector2i(-1, -2), Vector2i(0, -2),
        Vector2i(-1, -1), Vector2i(0, -1)
    ]
    while waited < 180:
        var all_ready: bool = bool(scene.world_initialized)
        for key in required_chunks:
            if not scene.loaded_chunks.has(key):
                all_ready = false
                break
        if all_ready:
            break
        await process_frame
        waited += 1
    if not scene.world_initialized:
        _fail("world generation did not finish", 4)
        return
    for key in required_chunks:
        if not scene.loaded_chunks.has(key):
            _fail("bridge collision chunk did not stream: " + str(key), 5)
            return

    for _sync in range(3):
        await physics_frame

    # Verify every lane on the actual static chunk collision, not the voxel map.
    for x in range(-1, 2):
        var wx := float(x) + 0.5
        var deck := _ray_surface(scene, wx, -15.5)
        if deck.is_empty() or not is_equal_approx(float(deck.position.y), 4.0):
            _fail("deck collision missing or at wrong height in lane x=%d: %s" % [x, str(deck)], 6)
            return
        for approach_z in APPROACH_ZS:
            var approach := _ray_surface(scene, wx, approach_z)
            if approach.is_empty() or not is_equal_approx(float(approach.position.y), 3.0):
                _fail("approach collision missing or discontinuous in lane x=%d z=%f: %s" % [x, approach_z, str(approach)], 7)
                return
        for bank_z in BANK_ZS:
            var bank := _ray_surface(scene, wx, bank_z)
            if bank.is_empty():
                _fail("bank collision missing beside approach in lane x=%d z=%f" % [x, bank_z], 8)
                return
            var bank_y := float(bank.position.y)
            if absf(bank_y - 3.0) > 1.25:
                _fail("bank-to-approach height discontinuity in lane x=%d z=%f: bank=%f approach=3.0" % [x, bank_z, bank_y], 9)
                return
    print("BRIDGE_LANE_COLLISION_PASS: 3 deck lanes, 6 approach surfaces, and 6 bank contacts hit real chunk colliders")

    # Exercise a real CharacterBody3D across bank -> approach -> deck -> approach -> bank.
    # The single one-block rise onto the deck is traversed with a jump, as in gameplay.
    var walker := CharacterBody3D.new()
    walker.name = "BridgeAcceptanceWalker"
    walker.collision_layer = 0
    walker.collision_mask = 1
    walker.floor_snap_length = 0.5
    walker.floor_max_angle = deg_to_rad(50.0)
    walker.safe_margin = 0.002
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.28
    capsule.height = 1.65
    var shape_node := CollisionShape3D.new()
    shape_node.shape = capsule
    walker.add_child(shape_node)
    scene.add_child(walker)

    var start_hit := _ray_surface(scene, BRIDGE_X, BANK_ZS[0])
    if start_hit.is_empty():
        _fail("could not locate the starting bank for traversal", 10)
        return
    walker.global_position = Vector3(BRIDGE_X, float(start_hit.position.y) + 0.84, BANK_ZS[0])
    for _settle in range(4):
        await physics_frame
        walker.velocity = Vector3.ZERO
        walker.move_and_slide()

    var jumped := false
    var reached_deck := false
    var reached_far_bank := false
    var min_y := walker.global_position.y
    for frame in range(480):
        await physics_frame
        var z := walker.global_position.z
        walker.velocity.z = 2.0
        walker.velocity.x = 0.0
        walker.velocity.y -= 9.8 / 60.0
        if not jumped and walker.is_on_floor() and z >= -21.2 and z <= -20.65:
            walker.velocity.y = 5.7
            jumped = true
        walker.move_and_slide()
        min_y = minf(min_y, walker.global_position.y)
        if walker.global_position.z >= -19.9 and walker.global_position.z <= -13.0 and walker.global_position.y >= 4.7:
            reached_deck = true
        if walker.global_position.z >= -11.3 and walker.is_on_floor():
            reached_far_bank = true
            break
        if walker.global_position.y < -1.0:
            break

    if not jumped:
        _fail("walker never reached the deck step while grounded; approach may not connect", 11)
        return
    if not reached_deck:
        _fail("CharacterBody3D could not traverse onto the bridge deck", 12)
        return
    if not reached_far_bank:
        _fail("CharacterBody3D did not reach and land on the opposite bank", 13)
        return
    if min_y < 1.5:
        _fail("walker fell through bridge or bank collision: minimum_y=%f" % min_y, 14)
        return
    print("BRIDGE_WALKTHROUGH_PASS: CharacterBody3D traversed bank -> approach -> raised deck -> approach -> opposite bank")
    walker.queue_free()
    scene.queue_free()
    await process_frame
    await physics_frame
    quit(0)
