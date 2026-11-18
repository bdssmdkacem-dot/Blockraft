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
    var surface_cache: Dictionary = scene.get("terrain_surface_heights")
    var corner_cache: Dictionary = scene.get("terrain_corner_heights")
    if surface_cache.size() < 10000 or corner_cache.size() < 10000:
        _fail("smoothed terrain surface/corner cache is incomplete: surfaces=%d corners=%d" % [surface_cache.size(), corner_cache.size()], 79)
        return
    var fractional_terrain_corners := 0
    for corner_height in corner_cache.values():
        if not is_equal_approx(float(corner_height), roundf(float(corner_height))):
            fractional_terrain_corners += 1
    if fractional_terrain_corners < 100:
        _fail("terrain renderer did not create enough blended low-poly slope corners: %d" % fractional_terrain_corners, 80)
        return
    # Water is deliberately excluded from the dry-land corner cache: averaging
    # shoreline heights into water vertices made the river surface uneven.
    # Verify the bank has blended corners next to real water columns, while the
    # rendered water top remains a level plane at y=3.0.
    var blended_shore_corners: Dictionary = {}
    var water_surface_columns: Dictionary = {}
    for block_position in scene.blocks:
        var water_cell: Vector3i = block_position
        if str(scene.blocks[block_position]) != "water" or water_cell.y != 2:
            continue
        water_surface_columns[Vector2i(water_cell.x, water_cell.z)] = true
        for corner_variant in [
            Vector2i(water_cell.x, water_cell.z),
            Vector2i(water_cell.x + 1, water_cell.z),
            Vector2i(water_cell.x, water_cell.z + 1),
            Vector2i(water_cell.x + 1, water_cell.z + 1)
        ]:
            var corner: Vector2i = corner_variant
            if not corner_cache.has(corner):
                continue
            var corner_height := float(corner_cache[corner])
            if corner_height > 2.0 and corner_height < 3.0:
                blended_shore_corners[corner] = true
    if blended_shore_corners.size() < 20 or water_surface_columns.size() < 20:
        _fail("river bank is missing blended shoreline corners or water columns: shore_corners=%d water_columns=%d" % [blended_shore_corners.size(), water_surface_columns.size()], 81)
        return

    var flat_water_top_vertices := 0
    var non_top_water_vertices := 0
    for chunk_variant in scene.loaded_chunks.values():
        var chunk_root := chunk_variant as Node3D
        if chunk_root == null:
            continue
        var water_instance := chunk_root.get_node_or_null("Surface_water") as MeshInstance3D
        if water_instance == null:
            continue
        var water_mesh := water_instance.mesh as ArrayMesh
        if water_mesh == null or water_mesh.get_surface_count() == 0:
            continue
        var water_arrays: Array = water_mesh.surface_get_arrays(0)
        var water_vertices: PackedVector3Array = water_arrays[Mesh.ARRAY_VERTEX]
        var water_normals: PackedVector3Array = water_arrays[Mesh.ARRAY_NORMAL]
        for vertex_index in range(mini(water_vertices.size(), water_normals.size())):
            if water_normals[vertex_index].y <= 0.9:
                non_top_water_vertices += 1
                continue
            flat_water_top_vertices += 1
            if not is_equal_approx(water_vertices[vertex_index].y, 3.0):
                _fail("river water top is not level at y=3.0: vertex_y=%f" % water_vertices[vertex_index].y, 82)
                return
    if non_top_water_vertices > 0:
        _fail("river water surface still contains side or bottom faces: %d vertices" % non_top_water_vertices, 84)
        return
    if flat_water_top_vertices < 20:
        _fail("loaded chunks do not expose enough level river top vertices: %d" % flat_water_top_vertices, 83)
        return
    print("TERRAIN_SMOOTH_MESH_PASS: cached surface columns=", surface_cache.size(), " shared corners=", corner_cache.size(), " fractional slope corners=", fractional_terrain_corners, " blended shoreline corners=", blended_shore_corners.size(), " water columns=", water_surface_columns.size(), " flat water top vertices=", flat_water_top_vertices)

    # Regression: a lower exposed water surface beside a taller water column
    # must not be culled merely because the neighbouring cell also contains water.
    var stepped_water_probe := Vector3i(1000, 2, 1000)
    var old_stepped_water_probe: Variant = scene.blocks.get(stepped_water_probe, null)
    var old_left_water: Variant = scene.blocks.get(stepped_water_probe + Vector3i.LEFT, null)
    var old_left_water_top: Variant = scene.blocks.get(stepped_water_probe + Vector3i.LEFT + Vector3i.UP, null)
    scene.blocks[stepped_water_probe] = "water"
    scene.blocks[stepped_water_probe + Vector3i.LEFT] = "water"
    scene.blocks[stepped_water_probe + Vector3i.LEFT + Vector3i.UP] = "water"
    var exposed_water_groups: Dictionary = {}
    scene.call("_append_exposed_render_faces", exposed_water_groups, stepped_water_probe, "water")
    var exposed_water_group: Dictionary = exposed_water_groups.get("water", {})
    var exposed_water_vertices: PackedVector3Array = exposed_water_group.get("vertices", PackedVector3Array())
    if exposed_water_vertices.size() != 4:
        _fail("lower water surface was culled beside a taller water column: vertices=%d" % exposed_water_vertices.size(), 85)
        return
    if old_stepped_water_probe == null: scene.blocks.erase(stepped_water_probe)
    else: scene.blocks[stepped_water_probe] = old_stepped_water_probe
    if old_left_water == null: scene.blocks.erase(stepped_water_probe + Vector3i.LEFT)
    else: scene.blocks[stepped_water_probe + Vector3i.LEFT] = old_left_water
    if old_left_water_top == null: scene.blocks.erase(stepped_water_probe + Vector3i.LEFT + Vector3i.UP)
    else: scene.blocks[stepped_water_probe + Vector3i.LEFT + Vector3i.UP] = old_left_water_top
    print("WATER_EXPOSED_TOP_REGRESSION_PASS: stepped water columns retain exposed lower top surfaces")

    # The generated river must contain a genuinely 4-connected two-dimensional
    # water region; diagonal corner-touching cells do not count as a continuous
    # channel and previously produced visible breaks in the camera capture.
    var unvisited_water: Dictionary = {}
    for water_column_variant in water_surface_columns:
        unvisited_water[water_column_variant] = true
    var largest_water_component := 0
    while not unvisited_water.is_empty():
        var seed: Vector2i = unvisited_water.keys()[0]
        unvisited_water.erase(seed)
        var queue: Array[Vector2i] = [seed]
        var queue_head := 0
        var component_size := 0
        while queue_head < queue.size():
            var current: Vector2i = queue[queue_head]
            queue_head += 1
            component_size += 1
            for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
                var neighbor: Vector2i = current + direction
                if unvisited_water.has(neighbor):
                    unvisited_water.erase(neighbor)
                    queue.append(neighbor)
        largest_water_component = maxi(largest_water_component, component_size)
    if largest_water_component < 20:
        _fail("generated river has no sufficiently large 4-connected water region: largest=%d" % largest_water_component, 86)
        return
    print("WATER_GRID_CONNECTIVITY_PASS: largest 4-connected surface region=", largest_water_component)

    # The deterministic spawn landing pad and its one-block ramp occupy the
    # full [-8, 8] square. It intentionally replaces terrain (including any
    # procedural channel samples) so the player always starts on a dry, level
    # surface. Assert that contract explicitly instead of demanding river water
    # underneath the protected pad.
    var spawn_pad_water_cells: Array[Vector2i] = []
    for pad_x in range(-8, 9):
        for pad_z in range(-8, 9):
            if str(scene.blocks.get(Vector3i(pad_x, 2, pad_z), "")) == "water":
                spawn_pad_water_cells.append(Vector2i(pad_x, pad_z))
    if not spawn_pad_water_cells.is_empty():
        _fail("protected spawn pad overlaps river water: %s" % str(spawn_pad_water_cells), 87)
        return

    # Guard the primary river centreline cell-by-cell outside the protected
    # spawn-pad footprint. A large connected component can still hide short
    # local holes, so every exposed centreline sample must contain water at the
    # fixed surface level.
    var missing_river_center_cells: Array[Vector2i] = []
    for river_x in range(-30, 31):
        var river_z := int(round(sin(float(river_x) * 0.055) * 8.0 + cos(float(river_x) * 0.025) * 3.0))
        if absi(river_x) <= 8 and absi(river_z) <= 8:
            continue
        var river_center := Vector3i(river_x, 2, river_z)
        if str(scene.blocks.get(river_center, "")) != "water":
            missing_river_center_cells.append(Vector2i(river_x, river_z))
    if not missing_river_center_cells.is_empty():
        _fail("primary river has local centreline gaps outside the protected spawn pad: %s" % str(missing_river_center_cells), 88)
        return
    print("WATER_LOCAL_CONTINUITY_PASS: primary river centreline is continuous outside the protected dry spawn pad")

    # Shoreline sediment must never be drawn above the water plane: opaque
    # bevel triangles above y=3.0 masked water cells and appeared as blue gaps.
    var bevel_groups: Dictionary = {}
    scene.call("_append_shoreline_transition", bevel_groups, Vector3(100.0, 0.0, 100.0), Vector3(100.0, 0.0, 101.0), Vector3(0.38, 0.0, 0.0), Vector2i(100, 100), Vector2i(100, 101), 3.0)
    var bevel_vertices: PackedVector3Array = bevel_groups.get("sand", {}).get("vertices", PackedVector3Array())
    if bevel_vertices.size() != 6:
        _fail("shoreline bevel did not emit its expected two triangles: vertices=%d" % bevel_vertices.size(), 89)
        return
    for bevel_vertex in bevel_vertices:
        if bevel_vertex.y > 2.97:
            _fail("shoreline bevel overlaps the visible water plane: y=%f" % bevel_vertex.y, 90)
            return
    print("WATER_SHORELINE_CLEARANCE_PASS: opaque sediment bevel remains below the y=3 water plane")

    # The smoothed dry-bank mesh must never rise above the fixed water
    # surface at any corner shared with an actual generated water column.
    var checked_river_edge_corners := 0
    for water_variant in scene.blocks.keys():
        var water_cell: Vector3i = water_variant
        if water_cell.y != 2 or str(scene.blocks[water_cell]) != "water":
            continue
        if scene.blocks.has(water_cell + Vector3i.UP):
            continue
        for corner in [
            Vector2i(water_cell.x, water_cell.z),
            Vector2i(water_cell.x + 1, water_cell.z),
            Vector2i(water_cell.x, water_cell.z + 1),
            Vector2i(water_cell.x + 1, water_cell.z + 1)
        ]:
            if not scene.terrain_corner_heights.has(corner):
                continue
            var edge_height := float(scene.terrain_corner_heights[corner])
            if edge_height > 2.92:
                _fail("smoothed bank corner rises above the river edge at %s: y=%f" % [str(corner), edge_height], 98)
                return
            checked_river_edge_corners += 1
    if checked_river_edge_corners < 100:
        _fail("too few actual river-edge terrain corners were checked: %d" % checked_river_edge_corners, 99)
        return
    print("WATER_BANK_CLEARANCE_PASS: actual river-edge corners=%d remain at or below y=2.92" % checked_river_edge_corners)

    # Exercise both vertical and horizontal chunk boundaries at negative and
    # positive coordinates. Each neighbouring chunk must own its water cell
    # while the resulting quads meet exactly on the shared world-space edge.
    var seam_x_values := [-32, -16, 0, 16, 32]
    for seam_x in seam_x_values:
        var left_cell := Vector3i(seam_x - 1, 2, 1000 + seam_x)
        var right_cell := Vector3i(seam_x, 2, 1000 + seam_x)
        scene.blocks[left_cell] = "water"
        scene.blocks[right_cell] = "water"
        var left_groups: Dictionary = {}
        var right_groups: Dictionary = {}
        scene.call("_append_exposed_render_faces", left_groups, left_cell, "water", seam_x - 16, seam_x)
        scene.call("_append_exposed_render_faces", right_groups, right_cell, "water", seam_x, seam_x + 16)
        var left_vertices: PackedVector3Array = left_groups.get("water", {}).get("vertices", PackedVector3Array())
        var right_vertices: PackedVector3Array = right_groups.get("water", {}).get("vertices", PackedVector3Array())
        var left_edge := -INF
        var right_edge := INF
        for vertex in left_vertices:
            left_edge = maxf(left_edge, vertex.x)
        for vertex in right_vertices:
            right_edge = minf(right_edge, vertex.x)
        if not is_equal_approx(left_edge, float(seam_x)) or not is_equal_approx(right_edge, float(seam_x)):
            _fail("water quads do not meet at x chunk seam %d: left=%f right=%f" % [seam_x, left_edge, right_edge], 91)
            return
        scene.blocks.erase(left_cell)
        scene.blocks.erase(right_cell)

    var seam_z_values := [-32, -16, 0, 16, 32]
    for seam_z in seam_z_values:
        var north_cell := Vector3i(1000 + seam_z, 2, seam_z - 1)
        var south_cell := Vector3i(1000 + seam_z, 2, seam_z)
        scene.blocks[north_cell] = "water"
        scene.blocks[south_cell] = "water"
        var north_groups: Dictionary = {}
        var south_groups: Dictionary = {}
        scene.call("_append_exposed_render_faces", north_groups, north_cell, "water")
        scene.call("_append_exposed_render_faces", south_groups, south_cell, "water")
        var north_vertices: PackedVector3Array = north_groups.get("water", {}).get("vertices", PackedVector3Array())
        var south_vertices: PackedVector3Array = south_groups.get("water", {}).get("vertices", PackedVector3Array())
        var north_edge := -INF
        var south_edge := INF
        for vertex in north_vertices:
            north_edge = maxf(north_edge, vertex.z)
        for vertex in south_vertices:
            south_edge = minf(south_edge, vertex.z)
        if not is_equal_approx(north_edge, float(seam_z)) or not is_equal_approx(south_edge, float(seam_z)):
            _fail("water quads do not meet at z chunk seam %d: north=%f south=%f" % [seam_z, north_edge, south_edge], 92)
            return
        scene.blocks.erase(north_cell)
        scene.blocks.erase(south_cell)
    print("WATER_CHUNK_SEAMS_PASS: water quads meet at five x seams and five z seams")

    # Validate chunk seams against the actual generated river footprint, not
    # synthetic cells. Every real pair crossing a 16-cell chunk boundary must
    # produce two complete water quads sharing the exact world-space edge.
    var actual_x_seam_pairs := 0
    var actual_z_seam_pairs := 0
    for cell_variant in scene.blocks.keys():
        var water_cell: Vector3i = cell_variant
        if str(scene.blocks[water_cell]) != "water":
            continue
        # Only the topmost voxel in each water column owns a visible surface.
        # Lower water voxels are intentionally culled by the production mesher.
        if scene.blocks.has(water_cell + Vector3i.UP):
            continue
        var east_cell := water_cell + Vector3i.RIGHT
        if (water_cell.x + 1) % 16 == 0 and str(scene.blocks.get(east_cell, "")) == "water" and not scene.blocks.has(east_cell + Vector3i.UP):
            var west_groups: Dictionary = {}
            var east_groups: Dictionary = {}
            scene.call("_append_exposed_render_faces", west_groups, water_cell, "water")
            scene.call("_append_exposed_render_faces", east_groups, east_cell, "water")
            var west_vertices: PackedVector3Array = west_groups.get("water", {}).get("vertices", PackedVector3Array())
            var east_vertices: PackedVector3Array = east_groups.get("water", {}).get("vertices", PackedVector3Array())
            if west_vertices.size() < 4 or east_vertices.size() < 4:
                _fail("actual river water cell at x seam did not emit a complete surface quad: %s" % str(water_cell), 93)
                return
            var west_edge := -INF
            var east_edge := INF
            for vertex in west_vertices:
                west_edge = maxf(west_edge, vertex.x)
            for vertex in east_vertices:
                east_edge = minf(east_edge, vertex.x)
            if not is_equal_approx(west_edge, float(water_cell.x + 1)) or not is_equal_approx(east_edge, float(east_cell.x)):
                _fail("actual river surface does not meet at x chunk boundary near %s" % str(water_cell), 94)
                return
            actual_x_seam_pairs += 1
        var south_cell := water_cell + Vector3i(0, 0, 1)
        if (water_cell.z + 1) % 16 == 0 and str(scene.blocks.get(south_cell, "")) == "water" and not scene.blocks.has(south_cell + Vector3i.UP):
            var north_groups: Dictionary = {}
            var south_groups: Dictionary = {}
            scene.call("_append_exposed_render_faces", north_groups, water_cell, "water")
            scene.call("_append_exposed_render_faces", south_groups, south_cell, "water")
            var north_vertices: PackedVector3Array = north_groups.get("water", {}).get("vertices", PackedVector3Array())
            var south_vertices: PackedVector3Array = south_groups.get("water", {}).get("vertices", PackedVector3Array())
            if north_vertices.size() < 4 or south_vertices.size() < 4:
                _fail("actual river water cell at z seam did not emit a complete surface quad: %s" % str(water_cell), 95)
                return
            var north_edge := -INF
            var south_edge := INF
            for vertex in north_vertices:
                north_edge = maxf(north_edge, vertex.z)
            for vertex in south_vertices:
                south_edge = minf(south_edge, vertex.z)
            if not is_equal_approx(north_edge, float(water_cell.z + 1)) or not is_equal_approx(south_edge, float(south_cell.z)):
                _fail("actual river surface does not meet at z chunk boundary near %s" % str(water_cell), 96)
                return
            actual_z_seam_pairs += 1
    if actual_x_seam_pairs == 0 or actual_z_seam_pairs == 0:
        _fail("generated river does not exercise both chunk axes: x_pairs=%d z_pairs=%d" % [actual_x_seam_pairs, actual_z_seam_pairs], 97)
        return
    print("WATER_REAL_CHUNK_SEAMS_PASS: generated river cells verified across x=%d z=%d chunk-boundary pairs" % [actual_x_seam_pairs, actual_z_seam_pairs])

    # Every spawned plant must sit on a continuous, exposed terrain column.
    var flora := scene.get_node_or_null("FloraFauna")
    var flora_root := scene.get_node_or_null("Flora") as Node3D if flora != null else null
    if flora_root == null:
        _fail("flora root is missing after world initialization", 68)
        return
    var grounded_plants := 0
    for plant_node in flora_root.get_children():
        var plant := plant_node as Node3D
        if plant == null:
            continue
        var gx := floori(plant.position.x)
        var gz := floori(plant.position.z)
        var gy := floori(plant.position.y - 1.0 + 0.001)
        var ground_cell := Vector3i(gx, gy, gz)
        var ground_kind := str(scene.blocks.get(ground_cell, ""))
        if plant.position.z < -6.0 and plant.position.z > -42.0 and absf(plant.position.x) < 8.0 and Vector2(plant.position.x, plant.position.z).length() > 18.0:
            _fail("decorative plant spawned inside the opening camera corridor", 75)
            return
        if ground_kind not in ["grass", "dirt", "sand", "gravel"]:
            _fail("plant spawned on a non-ground voxel at %s (%s)" % [str(ground_cell), ground_kind], 69)
            return
        if scene.blocks.has(ground_cell + Vector3i.UP) or scene.blocks.has(ground_cell + Vector3i(0, 2, 0)):
            _fail("plant spawned inside an obstructed voxel column at %s" % str(ground_cell), 70)
            return
        for support_y in range(gy - 1, -7, -1):
            if not scene.blocks.has(Vector3i(gx, support_y, gz)) or str(scene.blocks.get(Vector3i(gx, support_y, gz), "")) == "water":
                _fail("plant is not supported by continuous terrain at %s" % str(ground_cell), 71)
                return
        grounded_plants += 1
    if grounded_plants < 20:
        _fail("too few grounded plants were spawned: %d" % grounded_plants, 72)
        return
    for block_position in scene.blocks:
        var block_cell: Vector3i = block_position
        if str(scene.blocks[block_position]) in ["wood", "leaves"] and block_cell.y >= 5 and block_cell.z < -3 and block_cell.z > -42 and abs(block_cell.x) < 8:
            _fail("tree foliage remains inside the opening camera corridor at %s" % str(block_cell), 76)
            return
    for block_position in scene.blocks:
        var visible_cell: Vector3i = block_position
        if visible_cell.y < 5 or visible_cell.z >= -3 or visible_cell.z <= -42 or abs(visible_cell.x) >= 30:
            continue
        var visible_kind := str(scene.blocks[block_position])
        if visible_kind == "water":
            continue
        if not scene.blocks.has(visible_cell + Vector3i.DOWN):
            _fail("unsupported solid voxel remains in the opening view at %s (%s)" % [str(visible_cell), visible_kind], 77)
            return
    print("FLORA_GROUNDING_ACCEPTANCE_PASS: plants and tree foliage are grounded, opening corridor is clear, and visible solids have vertical support count=", grounded_plants)

    var water_material := scene.block_materials.get("water") as StandardMaterial3D
    var gameplay_environment := scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
    if water_material == null or water_material.roughness < 0.40 or water_material.metallic > 0.02 or water_material.specular_mode != BaseMaterial3D.SPECULAR_DISABLED or water_material.metallic_specular > 0.02 or water_material.albedo_color.a < 0.70 or water_material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
        _fail("gameplay water material is too glossy, metallic, or transparent for readable water", 73)
        return
    if gameplay_environment == null or gameplay_environment.environment == null or gameplay_environment.environment.background_mode != Environment.BG_SKY:
        _fail("gameplay world is not rendering its configured sky environment", 74)
        return
    print("WORLD_MATERIAL_ACCEPTANCE_PASS: sky background and deep matte translucent water verified")

    var survival := scene.get_node_or_null("Survival")
    if survival == null or survival.get("world_env") == null:
        _fail("day/night system did not bind to the active WorldEnvironment", 49)
        return

    # Two adjacent solid voxels must emit ten outer quads (60 vertices),
    # not twelve quads: the shared internal face is culled.
    var face_test_origin := Vector3i(1000, 100, 1000)
    var face_test_neighbor := face_test_origin + Vector3i(1, 0, 0)
    var old_origin: Variant = scene.blocks.get(face_test_origin, null)
    var old_neighbor: Variant = scene.blocks.get(face_test_neighbor, null)
    scene.blocks[face_test_origin] = "stone"
    scene.blocks[face_test_neighbor] = "stone"
    var face_test_groups: Dictionary = {}
    scene.call("_append_exposed_render_faces", face_test_groups, face_test_origin, "stone")
    scene.call("_append_exposed_render_faces", face_test_groups, face_test_neighbor, "stone")
    var face_test_group: Dictionary = face_test_groups["stone"]
    var face_test_vertices: PackedVector3Array = face_test_group["vertices"]
    var face_test_normals: PackedVector3Array = face_test_group["normals"]
    var face_test_colors: PackedColorArray = face_test_group["colors"]
    var face_test_indices: PackedInt32Array = face_test_group["indices"]
    if face_test_vertices.size() != 40 or face_test_normals.size() != 40 or face_test_colors.size() != 40 or face_test_indices.size() != 60:
        _fail("indexed face culling did not produce ten quads with four vertices each: vertices=%d indices=%d" % [face_test_vertices.size(), face_test_indices.size()], 60)
        return
    for index_offset in range(0, face_test_indices.size(), 3):
        var ia := face_test_indices[index_offset]
        var ib := face_test_indices[index_offset + 1]
        var ic := face_test_indices[index_offset + 2]
        if ia >= face_test_vertices.size() or ib >= face_test_vertices.size() or ic >= face_test_vertices.size():
            _fail("indexed voxel surface references a vertex outside its buffer", 66)
            return
        var geometric_normal := (face_test_vertices[ib] - face_test_vertices[ia]).cross(face_test_vertices[ic] - face_test_vertices[ia])
        if geometric_normal.length_squared() < 0.0001 or geometric_normal.normalized().dot(face_test_normals[ia]) > -0.99:
            _fail("indexed voxel triangle winding disagrees with outward normals", 67)
            return
    if old_origin == null:
        scene.blocks.erase(face_test_origin)
    else:
        scene.blocks[face_test_origin] = old_origin
    if old_neighbor == null:
        scene.blocks.erase(face_test_neighbor)
    else:
        scene.blocks[face_test_neighbor] = old_neighbor
    print("CULLED_SURFACE_MESH_ACCEPTANCE_PASS: two adjacent blocks emit ten boundary quads, with the shared face removed")

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
        var surface_batches := 0
        for child in chunk.get_children():
            if child is StaticBody3D and child.has_meta("chunk_key"):
                static_bodies += 1
                collision_chunk = chunk
                collision_body = child as StaticBody3D
                collision_key = key
            elif child is MeshInstance3D and child.name.begins_with("Surface_"):
                surface_batches += 1
                if not (child.mesh is ArrayMesh) or child.mesh.get_surface_count() != 1:
                    _fail("chunk %s contains a non-ArrayMesh terrain surface batch" % str(key), 61)
                    return
                var mesh_arrays: Array = child.mesh.surface_get_arrays(0)
                var mesh_vertices: PackedVector3Array = mesh_arrays[Mesh.ARRAY_VERTEX]
                var mesh_normals: PackedVector3Array = mesh_arrays[Mesh.ARRAY_NORMAL]
                var mesh_colors: PackedColorArray = mesh_arrays[Mesh.ARRAY_COLOR]
                var mesh_indices: PackedInt32Array = mesh_arrays[Mesh.ARRAY_INDEX]
                var mesh_material := child.material_override as StandardMaterial3D
                if mesh_vertices.is_empty() or mesh_vertices.size() != mesh_normals.size() or mesh_vertices.size() != mesh_colors.size() or mesh_material == null or not mesh_material.vertex_color_use_as_albedo or mesh_indices.is_empty() or mesh_indices.size() % 3 != 0:
                    _fail("chunk %s contains invalid indexed culled surface geometry" % str(key), 62)
                    return
                for index_offset in range(0, mesh_indices.size(), 3):
                    var ia := mesh_indices[index_offset]
                    var ib := mesh_indices[index_offset + 1]
                    var ic := mesh_indices[index_offset + 2]
                    if ia >= mesh_vertices.size() or ib >= mesh_vertices.size() or ic >= mesh_vertices.size():
                        _fail("chunk %s index buffer references an invalid vertex" % str(key), 66)
                        return
                    var geometric_normal := (mesh_vertices[ib] - mesh_vertices[ia]).cross(mesh_vertices[ic] - mesh_vertices[ia])
                    var normal_alignment := geometric_normal.normalized().dot(mesh_normals[ia]) if geometric_normal.length_squared() >= 0.0001 else 1.0
                    if geometric_normal.length_squared() < 0.0001 or normal_alignment > -0.99:
                        _fail("chunk %s batch %s triangle %d winding disagrees with outward normals (dot=%.4f)" % [str(key), child.name, index_offset / 3, normal_alignment], 65)
                        return
                var surface_material := child.material_override as StandardMaterial3D
                if surface_material == null or surface_material.cull_mode != BaseMaterial3D.CULL_BACK:
                    _fail("chunk %s surface material must retain efficient back-face culling" % str(key), 64)
                    return
        if surface_batches == 0:
            _fail("chunk %s has no culled ArrayMesh surface batches" % str(key), 63)
            return
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
    print("CHUNK_COLLISION_ACCEPTANCE_PASS: chunks use <=10 nodes, culled ArrayMesh surfaces, one static concave collision body, and valid exposed-face triangles")
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
    var rounded_animal_parts := 0
    for animal_node in animals:
        var animal := animal_node as CharacterBody3D
        var animal_mesh_parts := 0
        var rounded_mesh_parts := 0
        for part in animal.find_children("*", "MeshInstance3D", true, false):
            if not part is MeshInstance3D:
                continue
            animal_mesh_parts += 1
            var mesh_part := part as MeshInstance3D
            if mesh_part.mesh is SphereMesh and mesh_part.has_meta("animal_rounded_part"):
                rounded_mesh_parts += 1
        # Rounded body volumes are required, while crisp BoxMesh details keep eyes, beaks, hooves and horns readable.
        if animal_mesh_parts >= 12 and rounded_mesh_parts >= 2 and float(rounded_mesh_parts) / float(animal_mesh_parts) >= 0.15:
            rounded_animal_parts += 1
    if rounded_animal_parts < animals.size():
        _fail("one or more animals lack rounded core volumes or readable anatomy: rounded=%d/%d" % [rounded_animal_parts, animals.size()], 78)
        return
    # No spawned animal may begin inside a water voxel. Also exercise the
    # explicit water-avoidance steering path against a deterministic water cell.
    for animal_node in animals:
        var animal := animal_node as CharacterBody3D
        var spawn_position: Vector3 = animal.get_meta("spawn_position", animal.global_position)
        if animal.call("_is_water_at_world_position", spawn_position):
            _fail("animal initial spawn position is inside a water volume: %s at %s" % [animal.name, str(spawn_position)], 52)
            return
    var navigation_animal := animals[0] as CharacterBody3D
    var original_direction: Vector3 = navigation_animal.get("_dir")
    var water_probe := navigation_animal.global_position + original_direction * 2.0
    var water_cell := Vector3i(floori(water_probe.x), 2, floori(water_probe.z))
    var previous_water_value: Variant = scene.blocks.get(water_cell, null)
    scene.blocks[water_cell] = "water"
    if not navigation_animal.call("_is_water_at_world_position", water_probe):
        _fail("animal water-navigation probe did not detect the test water cell", 53)
        return
    navigation_animal.call("_steer_away_from_water")
    var redirected_direction: Vector3 = navigation_animal.get("_dir")
    var redirected_probe: Vector3 = navigation_animal.global_position + redirected_direction * 2.0
    if navigation_animal.call("_is_water_at_world_position", redirected_probe):
        _fail("animal water-avoidance steering still points into the water cell", 54)
        return
    if previous_water_value == null:
        scene.blocks.erase(water_cell)
    else:
        scene.blocks[water_cell] = previous_water_value
    print("ANIMAL_WATER_AVOIDANCE_PASS: spawned fauna is dry and steering redirects away from water")
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
    # Release the generated world, animal actors, chunk meshes and physics
    # resources before the headless process exits.
    if is_instance_valid(scene):
        scene.queue_free()
    await process_frame
    await process_frame
    await physics_frame
    # Let the audio server retire stopped WAV playback handles before process exit.
    await create_timer(0.35).timeout
    quit(0)
