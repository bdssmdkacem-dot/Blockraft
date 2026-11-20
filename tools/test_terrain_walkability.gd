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
	for position in blocks:
		var kind := str(blocks[position])
		var p: Vector3i = position
		if kind == "water":
			var water_key := Vector2i(p.x, p.z)
			water_columns[water_key] = int(water_columns.get(water_key, 0)) + 1
		var key := Vector2i(p.x, p.z)
		var is_bridge_approach := kind == "wood" and absi(p.x) <= 1 and p.z in [-22, -21, -12] and p.y >= 2 and p.y <= 4
		if kind not in GROUND_KINDS and not is_bridge_approach:
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
	var bridge_deck_cells := 0
	for bridge_z in range(-20, -12):
		if str(blocks.get(Vector3i(0, 3, bridge_z), "")) == "wood":
			bridge_deck_cells += 1
	var approaches_complete := true
	for bridge_x in range(-1, 2):
		var north_y := 4 if bridge_x != 1 else 3
		if str(blocks.get(Vector3i(bridge_x, north_y, -22), "")) != "wood":
			approaches_complete = false
		if str(blocks.get(Vector3i(bridge_x, 3, -21), "")) != "wood":
			approaches_complete = false
		if str(blocks.get(Vector3i(bridge_x, 3, -12), "")) != "wood":
			approaches_complete = false
	if bridge_deck_cells != 8 or not approaches_complete:
		_fail("Timber bridge deck or stepped bank approaches are incomplete: deck=%d approaches=%s" % [bridge_deck_cells, approaches_complete])
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
	print("TERRAIN_WALKABILITY_PASS columns=", surface_heights.size(), " max_adjacent_height_step=", worst_step, " two_block_edges=", steep_edges, " hill_relief=", annulus_max - annulus_min, " distinct_hill_heights=", annulus_heights.size(), " river_wet_rows=", river_rows, " river_widest_run=", widest_river_run, " shallow_river_columns=", shallow_river_columns, " deep_river_columns=", deep_river_columns)
	quit(0)

func _fail(message: String) -> void:
	push_error("TERRAIN_WALKABILITY_FAIL: " + message)
	quit(1)
