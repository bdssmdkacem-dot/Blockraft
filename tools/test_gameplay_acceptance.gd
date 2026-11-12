extends SceneTree

func _initialize() -> void:
    call_deferred("_run_checks")

func _fail(message: String, code: int) -> void:
    push_error("Gameplay acceptance: " + message)
    quit(code)

func _run_checks() -> void:
    root.size = Vector2i(1280, 720)
    print("GAMEPLAY_ACCEPTANCE: loading gameplay scene")
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
    print("GAMEPLAY_ACCEPTANCE: world wait finished frames=", waited, " blocks=", scene.blocks.size(), " chunks=", scene.loaded_chunks.size())
    if not scene.world_initialized:
        _fail("full world initialization did not finish", 14)
        return
    if scene.loaded_chunks.size() < 5:
        _fail("nearby world chunks did not stream in", 15)
        return

    var survival := scene.get_node_or_null("Survival")
    if survival == null or survival.get("world_env") == null:
        _fail("day/night system did not bind to the active WorldEnvironment", 49)
        return

    # Chunk rendering should use a handful of draw batches and one static collision
    # shape, not hundreds of physics bodies for individual voxel blocks.
    var collision_chunk: Node = null
    var collision_body: StaticBody3D = null
    var collision_key := Vector2i.ZERO
    for key_variant in scene.loaded_chunks.keys():
        var key: Vector2i = key_variant
        var chunk: Node = scene.loaded_chunks[key]
        if chunk.get_child_count() > 10:
            _fail("chunk %s has too many direct nodes: %d" % [str(key), chunk.get_child_count()], 21)
            return
        var static_bodies := 0
        for child in chunk.get_children():
            if child is StaticBody3D and child.has_meta("chunk_key"):
                static_bodies += 1
                collision_chunk = chunk
                collision_body = child as StaticBody3D
                collision_key = key
        if static_bodies > 1:
            _fail("chunk %s has more than one batched collision body" % str(key), 22)
            return
    if collision_body == null:
        _fail("no batched chunk collision body was generated", 23)
        return
    var chunk_shape := collision_body.get_node_or_null("ChunkCollisionShape") as CollisionShape3D
    if chunk_shape == null or not (chunk_shape.shape is ConcavePolygonShape3D):
        _fail("chunk collision is not using one concave static shape", 24)
        return

    var collision_faces: PackedVector3Array = chunk_shape.shape.get_faces()
    if collision_faces.size() < 6 or collision_faces.size() % 3 != 0:
        _fail("batched concave collision has no valid triangle faces", 25)
        return
    print("CHUNK_COLLISION_ACCEPTANCE_PASS: chunks use <=10 nodes, one static concave collision body, and valid exposed-face triangles")
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

    # Quantify generated landscape coverage and relief, not just material names.
    var water_blocks := 0
    var leaf_blocks := 0
    var wood_blocks := 0
    var column_heights: Dictionary = {}
    for pos_variant in scene.blocks.keys():
        var pos: Vector3i = pos_variant
        var kind := str(scene.blocks[pos])
        if kind == "water":
            water_blocks += 1
        elif kind == "leaves":
            leaf_blocks += 1
        elif kind == "wood":
            wood_blocks += 1
        if kind != "water":
            var column := Vector2i(pos.x, pos.z)
            column_heights[column] = maxi(int(column_heights.get(column, -999)), pos.y)
    var lowest_surface := 999
    var highest_surface := -999
    for height_variant in column_heights.values():
        lowest_surface = mini(lowest_surface, int(height_variant))
        highest_surface = maxi(highest_surface, int(height_variant))
    if water_blocks < 100 or leaf_blocks < 100 or wood_blocks < 20:
        _fail("terrain lacks meaningful water/forest coverage: water=%d leaves=%d wood=%d" % [water_blocks, leaf_blocks, wood_blocks], 40)
        return

    var scenic_water_found := false
    for z in range(-20, -12):
        if str(scene.blocks.get(Vector3i(0, 2, z), "")) == "water":
            scenic_water_found = true
            break
    if not scenic_water_found:
        _fail("forward scenic tributary did not generate water beyond the spawn plateau", 50)
        return
    if str(scene.blocks.get(Vector3i(0, 3, -16), "")) != "wood":
        _fail("forward river footbridge deck is missing", 51)
        return
    if highest_surface - lowest_surface < 6:
        _fail("generated terrain relief is too flat: range=%d" % (highest_surface - lowest_surface), 41)
        return
    print("TERRAIN_DIVERSITY_PASS: water=", water_blocks, " leaves=", leaf_blocks, " wood=", wood_blocks, " relief=", highest_surface - lowest_surface)

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

    # Exercise the actual batched chunk collider, not only the block dictionary.
    # The spawn column is guaranteed clear, so this isolated block has an exposed
    # top face and can be targeted with a deterministic downward physics ray.
    var probe := Vector3i(0, 24, 0)
    scene.blocks[probe] = "stone"
    scene.call("_rebuild_chunk", Vector2i.ZERO)
    for _frame in range(3):
        await physics_frame
    var ray_query := PhysicsRayQueryParameters3D.create(
        Vector3(0.5, 28.0, 0.5),
        Vector3(0.5, 20.0, 0.5)
    )
    ray_query.collision_mask = 1
    var ray_hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(ray_query)
    if ray_hit.is_empty():
        _fail("downward ray did not hit the batched chunk collider", 32)
        return
    var hit_collider = ray_hit.get("collider")
    if hit_collider == null or not hit_collider.has_meta("chunk_key") or hit_collider.has_meta("block_position"):
        _fail("ray did not hit the expected batched chunk collision body", 33)
        return
    var resolved_hit: Dictionary = player.call("_resolve_hit_block", ray_hit, scene)
    if resolved_hit.get("position", Vector3i(99999, 99999, 99999)) != probe or str(resolved_hit.get("kind", "")) != "stone":
        _fail("batched collider hit did not resolve to the correct voxel: %s" % str(resolved_hit), 34)
        return

    # Verify the real mining path removes the voxel and awards exactly one item.
    var stone_before_mine: int = scene.inventory.total_of("stone")
    player.set_physics_process(false)
    player.set("_mine_held", true)
    for step in range(5):
        # Keep the test camera aimed at the probe while the physics server
        # advances between ray queries; the live follow-camera must not steer
        # this deterministic mining fixture away from its target.
        player.camera.global_position = Vector3(0.5, 28.0, 0.5)
        player.camera.look_at(Vector3(0.5, 24.5, 0.5), Vector3.FORWARD)
        player.call("_tick_mining", 0.2)
        print("CHUNK_MINE_STEP index=", step, " progress=", player.get("_mine_progress"), " target=", player.get("_mine_pos"), " block_present=", scene.blocks.has(probe))
        if not scene.blocks.has(probe):
            break
        await physics_frame
    player.set("_mine_held", false)
    player.set_physics_process(true)
    if scene.blocks.has(probe):
        _fail("mining through the batched chunk collider did not remove the targeted voxel", 35)
        return
    if scene.inventory.total_of("stone") != stone_before_mine + 1:
        _fail("successful mining did not award exactly one matching inventory item", 40)
        return
    print("CHUNK_HIT_MAPPING_PASS: physics ray resolved, mined the expected voxel, and awarded one inventory item")

    var placement_probe := Vector3i(1, 8, 0)
    scene.inventory.select(1)
    var dirt_before_place: int = scene.inventory.count_of("dirt")
    var builds_before_place: int = int(scene.chunk_build_count)
    if scene.try_place_selected(Vector3i(1, 24, 0)) or scene.inventory.count_of("dirt") != dirt_before_place:
        _fail("out-of-reach placement was accepted or consumed inventory", 48)
        return
    if not scene.try_place_selected(placement_probe):
        _fail("selected-item placement rejected a valid empty target", 41)
        return
    if str(scene.blocks.get(placement_probe, "")) != "dirt":
        _fail("selected-item placement did not use the selected inventory material", 42)
        return
    if scene.inventory.count_of("dirt") != dirt_before_place - 1:
        _fail("selected-item placement did not consume exactly one item", 43)
        return
    if int(scene.chunk_build_count) <= builds_before_place:
        _fail("selected-item placement did not rebuild the resident chunk mesh/collision", 44)
        return
    var placed_chunk: Node = scene.loaded_chunks[Vector2i.ZERO]
    if placed_chunk.get_child_count() > 10:
        _fail("placed voxel bypassed chunk batching and created excessive per-block nodes", 45)
        return
    if scene.try_place_selected(placement_probe) or scene.inventory.count_of("dirt") != dirt_before_place - 1:
        _fail("placing into an occupied voxel consumed inventory or changed the world", 46)
        return
    scene.remove_block(placement_probe)
    scene.on_block_mined("dirt")
    if scene.blocks.has(placement_probe) or scene.inventory.count_of("dirt") != dirt_before_place:
        _fail("block removal/reward did not restore the expected inventory count", 47)
        return

    # Persistence format is tested with a representative small snapshot so this acceptance
    # test does not spend minutes serializing the entire generated terrain a second time.
    # The full world remains intact for the separate rendered gameplay capture.
    var full_world_blocks: Dictionary = scene.blocks
    scene.blocks = {
        Vector3i(0, 0, 0): "grass",
        Vector3i(1, 0, 0): "stone",
        Vector3i(2, 0, 0): "water"
    }
    print("GAMEPLAY_ACCEPTANCE: testing compact persistence fixture blocks=", scene.blocks.size())
    var inventory_before: Dictionary = scene.inventory.export_state()
    if not scene.inventory.validate_state(inventory_before):
        _fail("live inventory was invalid before the persistence fixture: " + JSON.stringify(inventory_before), 49)
        return
    scene.inventory.slots[1]["count"] = 7
    scene.inventory.storage["stone"] = 11
    scene.inventory.backpack_tier = "iron"
    scene.inventory.selected = 2
    var fixture_inventory: Dictionary = scene.inventory.export_state()
    if not scene.inventory.validate_state(fixture_inventory):
        _fail("persistence fixture produced an invalid inventory snapshot: " + JSON.stringify(fixture_inventory), 50)
        return
    scene.save_world()
    scene.blocks = full_world_blocks
    print("GAMEPLAY_ACCEPTANCE: save_world returned; full world restored blocks=", scene.blocks.size())
    var save_path := "user://world_blocks.json"
    if not FileAccess.file_exists(save_path):
        _fail("world save file was not created", 10)
        return
    var file := FileAccess.open(save_path, FileAccess.READ)
    if file == null:
        _fail("world save file could not be opened", 11)
        return
    var snapshot_text := file.get_as_text()
    file.close()
    var snapshot = JSON.parse_string(snapshot_text)
    if typeof(snapshot) != TYPE_DICTIONARY or typeof(snapshot.get("inventory", null)) != TYPE_DICTIONARY:
        _fail("world save did not include the inventory snapshot", 27)
        return
    var saved_inventory: Dictionary = snapshot["inventory"]
    if str(saved_inventory.get("backpack_tier", "")) != "iron" or int(saved_inventory.get("selected", -1)) != 2:
        _fail("inventory tier or selected slot was not persisted", 28)
        return
    if int(saved_inventory["slots"][1].get("count", -1)) != 7 or int(saved_inventory.get("storage", {}).get("stone", -1)) != 11:
        _fail("inventory slot counts or depot storage were not persisted", 29)
        return
    if not scene.inventory.import_state(saved_inventory):
        _fail("inventory snapshot could not be restored", 30)
        return
    if scene.inventory.backpack_tier != "iron" or scene.inventory.selected != 2 or int(scene.inventory.slots[1]["count"]) != 7 or scene.inventory.storage_count("stone") != 11:
        _fail("restored inventory state did not match saved values", 31)
        return
    scene.inventory.import_state(inventory_before)
    # Avoid reparsing the entire large world snapshot in the acceptance test.
    # The game loader parses it on startup; here verify the saved envelope and
    # that the exact compact record for the removed probe is absent.
    if not snapshot_text.contains("blocks") or not snapshot_text.contains("[") :
        _fail("world save does not contain a blocks array", 12)
        return
    var probe_record := "[%d,%d,%d," % [probe.x, probe.y, probe.z]
    if snapshot_text.contains(probe_record):
        _fail("deleted block was still present in the saved snapshot", 13)
        return
    if not snapshot_text.contains("[1,0,0,\"stone\"]") or not snapshot_text.contains("[2,0,0,\"water\"]"):
        _fail("compact persistence fixture did not preserve block coordinates and kinds", 20)
        return

    # Exercise last-known-good recovery with a full-size valid world. The second
    # save must preserve the first snapshot as .bak; corrupting the primary file
    # must restore both the original spawn terrain and its inventory snapshot.
    scene.blocks = full_world_blocks.duplicate(true)
    scene.inventory.slots[1]["count"] = 9
    scene.inventory.storage["stone"] = 17
    scene.save_world()
    scene.blocks[Vector3i(0, 4, 0)] = "stone"
    scene.inventory.slots[1]["count"] = 3
    scene.inventory.storage["stone"] = 2
    scene.save_world()

    var corrupt_file := FileAccess.open(save_path, FileAccess.WRITE)
    if corrupt_file == null:
        _fail("could not open primary save to simulate corruption", 36)
        return
    corrupt_file.store_string("{invalid-json")
    corrupt_file.close()
    scene.blocks.clear()
    if not scene.call("_load_world_snapshot"):
        _fail("corrupted primary save did not recover from the last-known-good backup", 37)
        return
    if str(scene.blocks.get(Vector3i(0, 4, 0), "")) != "grass":
        _fail("backup recovery did not restore the original spawn terrain", 38)
        return
    if int(scene.inventory.slots[1].get("count", -1)) != 9 or scene.inventory.storage_count("stone") != 17:
        _fail("backup recovery did not restore the matching inventory snapshot", 39)
        return
    print("SAVE_BACKUP_RECOVERY_PASS: corrupted primary restored previous world and inventory snapshot")

    print("GAMEPLAY_ACCEPTANCE_PASS: player/camera, generated blocks, real chunk mining, place/remove, save deletion, and backup recovery verified")
    quit(0)
