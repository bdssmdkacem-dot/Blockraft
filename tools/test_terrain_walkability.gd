extends SceneTree
## Ensures the generated terrain is traversable rather than ending in abrupt voxel cliffs.

const GAME_SCENE := "res://scenes/main.tscn"
const GROUND_KINDS := ["grass", "dirt", "stone", "rock", "sand", "gravel"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load(GAME_SCENE) as PackedScene
	if packed == null:
		_fail("Could not load gameplay scene")
		return
	var game := packed.instantiate() as Node3D
	if game == null:
		_fail("Gameplay scene root is not Node3D")
		return
	# Each acceptance script shares Godot's user:// directory inside the CI
	# container. Remove any snapshot written by an earlier test so this check
	# measures the current procedural generator, not an older saved world.
	game.call("_clear_old_save")
	# _clear_old_save removes the primary snapshot; remove its recovery backup too
	# so this acceptance run cannot silently load an older generated world.
	var backup_path := "user://world_blocks.json.bak"
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))
	root.add_child(game)
	var ready := false
	for _frame in range(900):
		await process_frame
		if game.get("world_initialized") == true:
			ready = true
			break
	if not ready:
		_fail("World did not initialize")
		return
	if float(game.get("world_generation_ms")) <= 0.0:
		_fail("Terrain test did not run a fresh procedural generation pass")
		return

	var blocks: Dictionary = game.get("blocks")
	var surface_heights: Dictionary = {}
	var water_columns: Dictionary = {}
	# Columns occupied by the actual bridge deck/approaches are not exposed
	# natural-ground walking surfaces. Their timber tops and collision are
	# validated independently by test_bridge_acceptance.gd.
	var bridge_columns: Dictionary = {}
	for bridge_z in range(-20, -12):
		if str(blocks.get(Vector3i(0, 3, bridge_z), "")) == "wood":
			for bridge_x in range(-1, 2):
				bridge_columns[Vector2i(bridge_x, bridge_z)] = true
	for bridge_x in range(-1, 2):
		var north_y := 3
		for bridge_position in [
			Vector3i(bridge_x, 3, -23),
			Vector3i(bridge_x, north_y, -22),
			Vector3i(bridge_x, 3, -21),
			Vector3i(bridge_x, 3, -12)
		]:
			if str(blocks.get(bridge_position, "")) == "wood":
				bridge_columns[Vector2i(bridge_position.x, bridge_position.z)] = true
	for position in blocks:
		var kind := str(blocks[position])
		var p: Vector3i = position
		if kind == "water":
			var water_key := Vector2i(p.x, p.z)
			water_columns[water_key] = int(water_columns.get(water_key, 0)) + 1
		var key := Vector2i(p.x, p.z)
		if bridge_columns.has(key):
			continue
		# Bridge timber is a separate elevated structure with its own collision
		# and traversal acceptance test. Do not mix its deck/approach tops into
		# the procedural dry-ground slope field: lateral wood-to-bank adjacency
		# is not a terrain slope. The dedicated bridge test raycasts every lane.
		if kind not in GROUND_KINDS:
			continue
		if not surface_heights.has(key) or p.y > int(surface_heights[key]):
			surface_heights[key] = p.y
	if surface_heights.size() < 10000:
		_fail("Too few terrain columns were generated: %d" % surface_heights.size())
		return

	# The forward river must be a real, modestly varied channel rather than a
	# one-cell slit or an oversized flooded plain. Sample its visible approach.
	var river_rows := 0
	var widest_river_run := 0
	for z in range(-22, -10):
		var current_run := 0
		var row_widest := 0
		for x in range(-12, 13):
			if water_columns.has(Vector2i(x, z)):
				current_run += 1
				row_widest = maxi(row_widest, current_run)
			else:
				current_run = 0
		if row_widest > 0:
			river_rows += 1
			widest_river_run = maxi(widest_river_run, row_widest)
	if river_rows < 5 or widest_river_run < 3 or widest_river_run > 12:
		_fail("Forward river channel is not a traversable, varied-width stream: wet_rows=%d widest_run=%d" % [river_rows, widest_river_run])
		return
	var shallow_river_columns := 0
	var deep_river_columns := 0
	for water_key_variant in water_columns:
		var water_key: Vector2i = water_key_variant
		if water_key.x < -12 or water_key.x > 12 or water_key.y < -22 or water_key.y > -10:
			continue
		var water_depth := int(water_columns[water_key])
		if water_depth == 1:
			shallow_river_columns += 1
		elif water_depth >= 2:
			deep_river_columns += 1
	if shallow_river_columns < 8 or deep_river_columns < 8:
		_fail("River needs both shallow shoreline shelves and a deeper centre: shallow=%d deep=%d" % [shallow_river_columns, deep_river_columns])
		return

	# The scenic crossing must have a broad, smoothly varying meander. This
	# prevents a visually straight channel or a one-cell side-to-side jump.
	var scenic_min := INF
	var scenic_max := -INF
	var previous_center := 0.0
	var previous_delta := 0.0
	var centerline_turns := 0
	var max_centerline_step := 0.0
	for sample_x in range(-24, 25):
		var center_x := float(game.call("_scenic_river_centerline", float(sample_x)))
		scenic_min = minf(scenic_min, center_x)
		scenic_max = maxf(scenic_max, center_x)
		if sample_x > -24:
			var delta := center_x - previous_center
			max_centerline_step = maxf(max_centerline_step, absf(delta))
			if previous_delta != 0.0 and delta * previous_delta < 0.0:
				centerline_turns += 1
			previous_delta = delta
		previous_center = center_x
	if scenic_max - scenic_min < 8.0 or max_centerline_step > 0.7 or centerline_turns < 1:
		_fail("Scenic river meander is too straight or abrupt: range=%.2f max_step=%.2f turns=%d" % [scenic_max - scenic_min, max_centerline_step, centerline_turns])
		return

	var bridge_deck_cells := 0
	for bridge_z in range(-20, -12):
		if str(blocks.get(Vector3i(0, 3, bridge_z), "")) == "wood":
			bridge_deck_cells += 1
	var approaches_complete := true
	for bridge_x in range(-1, 2):
		var north_y := 3
		if str(blocks.get(Vector3i(bridge_x, 3, -23), "")) != "wood":
			approaches_complete = false
		if str(blocks.get(Vector3i(bridge_x, north_y, -22), "")) != "wood":
			approaches_complete = false
		if str(blocks.get(Vector3i(bridge_x, 3, -21), "")) != "wood":
			approaches_complete = false
		if str(blocks.get(Vector3i(bridge_x, 3, -12), "")) != "wood":
			approaches_complete = false
	if bridge_deck_cells != 8 or not approaches_complete:
		_fail("Timber bridge deck or flush bank approaches are incomplete: deck=%d approaches=%s" % [bridge_deck_cells, approaches_complete])
		return
	for pad_x in range(-3, 4):
		for pad_z in range(-3, 4):
			var pad_distance := maxi(absi(pad_x), absi(pad_z))
			var expected_pad_height := 3 if pad_distance == 3 else 4
			if int(surface_heights.get(Vector2i(pad_x, pad_z), -999)) != expected_pad_height:
				_fail("Spawn landing pad is not level at (%d,%d)" % [pad_x, pad_z])
				return

	var annulus_min := 999
	var annulus_max := -999
	var annulus_heights: Dictionary = {}
	for key_variant in surface_heights:
		var key: Vector2i = key_variant
		var radius := Vector2(float(key.x), float(key.y)).length()
		if radius >= 14.0 and radius <= 42.0:
			var h := int(surface_heights[key])
			annulus_min = mini(annulus_min, h)
			annulus_max = maxi(annulus_max, h)
			annulus_heights[h] = true
	if annulus_max - annulus_min < 8 or annulus_heights.size() < 8:
		_fail("surrounding hills lack gradual but visible relief: min=%d max=%d range=%d unique_heights=%d" % [annulus_min, annulus_max, annulus_max - annulus_min, annulus_heights.size()])
		return

	var worst_step := 0
	var steep_edges := 0
	var worst_edge := ""
	var samples: Array[String] = []
	for key in surface_heights:
		var height := int(surface_heights[key])
		for offset in [Vector2i(1, 0), Vector2i(0, 1)]:
			var neighbor_key: Vector2i = key + offset
			if not surface_heights.has(neighbor_key):
				continue
			# Water channels are intentionally below the walking surface; their
			# banks are not adjacent walkable ground columns.
			if water_columns.has(key) or water_columns.has(neighbor_key):
				continue
			var neighbor_height := int(surface_heights[neighbor_key])
			var step := absi(height - neighbor_height)
			if step > worst_step:
				worst_step = step
				worst_edge = "%s=%d -> %s=%d" % [key, height, neighbor_key, neighbor_height]
			if step > 1:
				steep_edges += 1
				if samples.size() < 16:
					samples.append("%s=%d -> %s=%d" % [key, height, neighbor_key, neighbor_height])
	# After the 0.45-block slope relaxation, adjacent dry ground must round to
	# at most one voxel step; any two-block edge is a real traversal defect.
	if worst_step > 1 or steep_edges > 0:
		var diagnostic_rows: Array[String] = []
		for debug_z in range(24, 35):
			var row: Array[String] = []
			for debug_x in range(-33, -27):
				var debug_key := Vector2i(debug_x, debug_z)
				var debug_height := int(surface_heights.get(debug_key, -999))
				var wet_marker := "W" if water_columns.has(debug_key) else "-"
				row.append("%d%s" % [debug_height, wet_marker])
			diagnostic_rows.append("%d: %s" % [debug_z, " ".join(row)])
		push_error("TERRAIN_WALKABILITY_GRID x=-33..-28 z=24..34: " + " | ".join(diagnostic_rows))
		push_error("Terrain edge samples: " + str(samples))
		_fail("Generated terrain still contains %d abrupt edges; worst adjacent height difference is %d blocks at %s" % [steep_edges, worst_step, worst_edge])
		return
	# Render acceptance: each bank face adjacent to water must remain present
	# (watertight terrain) and use the brighter wet-silt vertex tint.
	var shoreline_edges_checked := 0
	var wet_face_debug_count := 0
	for position_variant in blocks:
		if shoreline_edges_checked >= 64:
			break
		var position: Vector3i = position_variant
		if position.x < -14 or position.x > 14 or position.z < -27 or position.z > -6:
			continue
		var kind := str(blocks[position])
		if kind not in GROUND_KINDS:
			continue
		var wet_offsets: Array[Vector3i] = []
		for offset in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			var adjacent_water := false
			for water_y in range(maxi(position.y, -8), 3):
				if str(blocks.get(Vector3i(position.x + offset.x, water_y, position.z + offset.z), "")) == "water":
					adjacent_water = true
					break
			var same_level_neighbor := str(blocks.get(position + offset, ""))
			if adjacent_water and (same_level_neighbor == "" or same_level_neighbor == "water"):
				wet_offsets.append(offset)
		if wet_offsets.is_empty():
			continue
		var render_groups: Dictionary = {}
		game.call("_append_exposed_render_faces", render_groups, position, kind)
		for wet_offset in wet_offsets:
			var matching_face_found := false
			for batch_name in [kind, "wet_silt"]:
				var rendered_group: Dictionary = render_groups.get(batch_name, {})
				var rendered_normals: PackedVector3Array = rendered_group.get("normals", PackedVector3Array())
				var rendered_colors: PackedColorArray = rendered_group.get("colors", PackedColorArray())
				for vertex_index in range(rendered_normals.size()):
					if rendered_normals[vertex_index].dot(Vector3(wet_offset)) <= 0.99:
						continue
					matching_face_found = true
					var face_luminance := rendered_colors[vertex_index].get_luminance()
					if wet_face_debug_count < 24:
						print("WET_FACE_DIAG position=", position, " kind=", kind, " normal=", rendered_normals[vertex_index], " batch=", batch_name, " color=", rendered_colors[vertex_index], " luminance=", face_luminance)
						wet_face_debug_count += 1
					if face_luminance < 0.42:
						_fail("water-facing bank face is too dark at %s toward %s in batch %s (luminance=%.3f)" % [position, wet_offset, batch_name, face_luminance])
						return
			if not matching_face_found:
				_fail("watertight bank face is missing from terrain and sand batches at %s toward %s" % [position, wet_offset])
				return
			shoreline_edges_checked += 1
	if shoreline_edges_checked < 16:
		_fail("too few shoreline faces were sampled in bridge review corridor: %d" % shoreline_edges_checked)
		return
	var buffer_groups: Dictionary = {}
	for render_position_variant in blocks:
		var render_position: Vector3i = render_position_variant
		if render_position.x < -14 or render_position.x > 14 or render_position.z < -27 or render_position.z > -6:
			continue
		var render_kind := str(blocks[render_position])
		if render_kind not in GROUND_KINDS and render_kind != "water":
			continue
		game.call("_append_exposed_render_faces", buffer_groups, render_position, render_kind)
	for batch_name_variant in buffer_groups:
		var batch_name := str(batch_name_variant)
		var batch_group: Dictionary = buffer_groups[batch_name]
		var batch_vertices: PackedVector3Array = batch_group.get("vertices", PackedVector3Array())
		var batch_normals: PackedVector3Array = batch_group.get("normals", PackedVector3Array())
		var batch_colors: PackedColorArray = batch_group.get("colors", PackedColorArray())
		var batch_indices: PackedInt32Array = batch_group.get("indices", PackedInt32Array())
		if batch_vertices.size() != batch_normals.size() or batch_vertices.size() != batch_colors.size():
			_fail("render batch %s has mismatched vertex/normal/color buffers: %d/%d/%d" % [batch_name, batch_vertices.size(), batch_normals.size(), batch_colors.size()])
			return
		if batch_indices.size() % 3 != 0:
			_fail("render batch %s has a non-triangle index buffer: %d" % [batch_name, batch_indices.size()])
			return
		for index_value in batch_indices:
			if index_value < 0 or index_value >= batch_vertices.size():
				_fail("render batch %s contains an out-of-range index %d of %d" % [batch_name, index_value, batch_vertices.size()])
				return

	var shoreline_transition_cells := 0
	var raised_shoreline_cells := 0
	var shoreline_collision_samples := 0
	var transition_min_luminance := 1.0
	var transition_min_height := INF
	var transition_max_height := -INF
	var corner_cache: Dictionary = game.get("terrain_corner_heights")
	var block_materials: Dictionary = game.get("block_materials")
	var wet_silt_material := block_materials.get("wet_silt") as StandardMaterial3D
	if wet_silt_material == null or wet_silt_material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
		_fail("wet_silt material must remain unshaded so shoreline sediment cannot render as dark soil")
		return
	for water_position_variant in blocks:
		if shoreline_transition_cells >= 64 and shoreline_collision_samples >= 12:
			break
		var water_position: Vector3i = water_position_variant
		if str(blocks[water_position]) != "water":
			continue
		# This acceptance gate targets the visible scenic crossing beside the
		# bridge, not the remote lake or the separate rear river.
		if water_position.x < -14 or water_position.x > 14 or water_position.z < -27 or water_position.z > -6:
			continue
		var transition_groups: Dictionary = {}
		game.call("_append_exposed_render_faces", transition_groups, water_position, "water")
		if shoreline_transition_cells < 10:
			var side_offsets: Array[Vector3i] = [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]
			var side_corner_a: Array[Vector2i] = [
				Vector2i(water_position.x, water_position.z),
				Vector2i(water_position.x + 1, water_position.z + 1),
				Vector2i(water_position.x + 1, water_position.z),
				Vector2i(water_position.x, water_position.z + 1)
			]
			var side_corner_b: Array[Vector2i] = [
				Vector2i(water_position.x, water_position.z + 1),
				Vector2i(water_position.x + 1, water_position.z),
				Vector2i(water_position.x, water_position.z),
				Vector2i(water_position.x + 1, water_position.z + 1)
			]
			var side_landward: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
			var side_names: Array[String] = ["left", "right", "north", "south"]
			for side_index in range(4):
				var side_offset: Vector3i = side_offsets[side_index]
				if str(blocks.get(water_position + side_offset, "")) == "water":
					continue
				var bank_column := Vector2i(water_position.x + side_offset.x, water_position.z + side_offset.z)
				if not surface_heights.has(bank_column):
					continue
				var corner_a: Vector2i = side_corner_a[side_index]
				var corner_b: Vector2i = side_corner_b[side_index]
				var profile_a: Array[String] = []
				var profile_b: Array[String] = []
				for profile_step in range(1, 7):
					var landward_step: Vector2i = side_landward[side_index]
					var profile_corner_a: Vector2i = corner_a + landward_step * profile_step
					var profile_corner_b: Vector2i = corner_b + landward_step * profile_step
					profile_a.append(str(corner_cache.get(profile_corner_a, "missing")))
					profile_b.append(str(corner_cache.get(profile_corner_b, "missing")))
				print("RIVER_BANK_PROFILE water=", water_position, " side=", side_names[side_index], " bank_surface=", surface_heights[bank_column], " corners=", corner_a, "/", corner_b, " heights_a=", profile_a, " heights_b=", profile_b)
		var transition_group: Dictionary = transition_groups.get("wet_silt", {})
		var transition_vertices: PackedVector3Array = transition_group.get("vertices", PackedVector3Array())
		var transition_colors: PackedColorArray = transition_group.get("colors", PackedColorArray())
		if transition_vertices.is_empty():
			continue
		var cell_max_height := -INF
		for transition_vertex in transition_vertices:
			transition_min_height = minf(transition_min_height, transition_vertex.y)
			transition_max_height = maxf(transition_max_height, transition_vertex.y)
			cell_max_height = maxf(cell_max_height, transition_vertex.y)
		if cell_max_height > 3.05:
			raised_shoreline_cells += 1
		for transition_color in transition_colors:
			transition_min_luminance = minf(transition_min_luminance, transition_color.get_luminance())
		if shoreline_transition_cells < 10:
			print("RIVER_BANK_TRANSITION water=", water_position, " vertices=", transition_vertices.size(), " cell_max_y=", cell_max_height, " color_luminance=", transition_min_luminance)
		shoreline_transition_cells += 1

		# The dry bank collision must use exactly the same shared corner heights
		# as the smoothed visible top, so changing the render bevel cannot hide a
		# gap or create a floating walkable lip.
		for bank_offset in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			var bank_key := Vector2i(water_position.x + bank_offset.x, water_position.z + bank_offset.z)
			if not surface_heights.has(bank_key) or bridge_columns.has(bank_key):
				continue
			var bank_top := Vector3i(bank_key.x, int(surface_heights[bank_key]), bank_key.y)
			if str(blocks.get(bank_top, "")) not in GROUND_KINDS:
				continue
			var collision_faces := PackedVector3Array()
			game.call("_append_exposed_collision_faces", collision_faces, bank_top)
			if collision_faces.is_empty():
				_fail("river-bank collision mesh is missing at %s" % bank_top)
				return
			var matching_corner_vertices := 0
			for collision_vertex in collision_faces:
				if collision_vertex.y <= float(bank_top.y) + 0.5:
					continue
				var collision_corner := Vector2i(roundi(collision_vertex.x), roundi(collision_vertex.z))
				if not corner_cache.has(collision_corner):
					continue
				var expected_height := float(corner_cache[collision_corner])
				if absf(collision_vertex.y - expected_height) > 0.001:
					_fail("river-bank collision/render corner mismatch at %s: collision=%.3f render=%.3f" % [collision_corner, collision_vertex.y, expected_height])
					return
				matching_corner_vertices += 1
			if matching_corner_vertices >= 4:
				shoreline_collision_samples += 1
				break
	if shoreline_transition_cells < 32:
		_fail("too few rendered shoreline transitions were sampled across the river: %d" % shoreline_transition_cells)
		return
	if raised_shoreline_cells < 8 or transition_max_height <= 3.05:
		_fail("shoreline bevel does not rise onto enough dry-bank sections: raised=%d/%d max_y=%.3f" % [raised_shoreline_cells, shoreline_transition_cells, transition_max_height])
		return
	if transition_min_luminance < 0.55:
		_fail("shoreline sediment is still too dark: min_luminance=%.3f" % transition_min_luminance)
		return
	if shoreline_collision_samples < 8:
		_fail("too few river-bank collision tops matched the shared rendered corner heights: %d" % shoreline_collision_samples)
		return
	print("WATER_BANK_BEVEL_PASS: ", shoreline_transition_cells, " transitions sampled, ", raised_shoreline_cells, " raised onto the dry bank; min_height=", transition_min_height, " max_height=", transition_max_height, " minimum sediment luminance=", transition_min_luminance)
	print("RIVER_BANK_COLLISION_MATCH_PASS: ", shoreline_collision_samples, " bank tops share render/collision corner heights")
	print("WATER_BANK_WATERTIGHT_SILT_PASS: ", shoreline_edges_checked, " shoreline faces retained with bright wet-silt tint")
	print("TERRAIN_WALKABILITY_PASS columns=", surface_heights.size(), " max_adjacent_height_step=", worst_step, " two_block_edges=", steep_edges, " hill_relief=", annulus_max - annulus_min, " distinct_hill_heights=", annulus_heights.size(), " river_wet_rows=", river_rows, " river_widest_run=", widest_river_run, " shallow_river_columns=", shallow_river_columns, " deep_river_columns=", deep_river_columns)
	quit(0)

func _fail(message: String) -> void:
	push_error("TERRAIN_WALKABILITY_FAIL: " + message)
	quit(1)
