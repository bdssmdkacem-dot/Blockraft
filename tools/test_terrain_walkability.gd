extends SceneTree
## Ensures the generated terrain is traversable rather than ending in abrupt voxel cliffs.

const GAME_SCENE := "res://scenes/main.tscn"
const GROUND_KINDS := ["grass", "dirt", "stone", "rock", "sand", "gravel"]
const WATER_LEVEL := 2
const WORLD_RADIUS := 56

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

	var blocks: Dictionary = game.get("blocks")
	var surface_heights: Dictionary = {}
	var water_columns: Dictionary = {}
	for position in blocks:
		var kind := str(blocks[position])
		var p: Vector3i = position
		if kind == "water":
			water_columns[Vector2i(p.x, p.z)] = true
		if kind not in GROUND_KINDS:
			continue
		var key := Vector2i(p.x, p.z)
		if not surface_heights.has(key) or p.y > int(surface_heights[key]):
			surface_heights[key] = p.y
	if surface_heights.size() < 10000:
		_fail("Too few terrain columns were generated: %d" % surface_heights.size())
		return

	# The protected 7x7 spawn pad needs two dry transition rings so
	# its raised center blends into the natural terrain without two-cell cliffs.
	var spawn_ring_violations: Array[String] = []
	var spawn_ring_checked := 0
	for radius in [4, 6]:
		var minimum_surface := 3 if radius == 4 else 2
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				if maxi(absi(x), absi(z)) != radius:
					continue
				var ring_key := Vector2i(x, z)
				if water_columns.has(ring_key):
					continue
				if not surface_heights.has(ring_key) or int(surface_heights.get(ring_key, -999)) < minimum_surface:
					spawn_ring_violations.append("%s=%s target>=%d" % [ring_key, str(surface_heights.get(ring_key, "missing")), minimum_surface])
				else:
					spawn_ring_checked += 1
	if spawn_ring_checked < 16 or not spawn_ring_violations.is_empty():
		_fail("spawn transition rings are incomplete: checked=%d violations=%s" % [spawn_ring_checked, str(spawn_ring_violations)])
		return
	print("TERRAIN_SPAWN_TRANSITION_PASS columns=", spawn_ring_checked, " ring4_min=3 ring6_min=2")

	var water_bank_edges := 0
	var water_bank_violations := 0
	var worst_water_bank_step := 0
	var water_bank_samples: Array[String] = []
	for water_key_variant in water_columns:
		var water_key: Vector2i = water_key_variant
		# The outer 32 columns are a deliberate world-edge fade, not a playable
		# riverbank. Measure only the interior shoreline used by the player.
		if maxi(absi(water_key.x), absi(water_key.y)) > WORLD_RADIUS - 32:
			continue
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var land_key: Vector2i = water_key + offset
			if maxi(absi(land_key.x), absi(land_key.y)) > WORLD_RADIUS - 32:
				continue
			if water_columns.has(land_key) or not surface_heights.has(land_key):
				continue
			var land_height := int(surface_heights[land_key])
			var bank_step := absi(land_height - WATER_LEVEL)
			water_bank_edges += 1
			worst_water_bank_step = maxi(worst_water_bank_step, bank_step)
			if bank_step > 1:
				water_bank_violations += 1
				if water_bank_samples.size() < 16:
					water_bank_samples.append("%s=%d beside water %s" % [land_key, land_height, water_key])
	if water_bank_edges < 20:
		_fail("not enough generated river/lake shoreline edges were sampled: %d" % water_bank_edges)
		return
	if water_bank_violations > 0:
		push_error("Water bank edge samples: " + str(water_bank_samples))
		_fail("generated shoreline contains %d abrupt water-to-land edges; worst surface-level difference is %d blocks" % [water_bank_violations, worst_water_bank_step])
		return
	print("TERRAIN_WATER_BANK_PASS edges=", water_bank_edges, " max_waterline_step=", worst_water_bank_step)

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
	if annulus_max - annulus_min < 3 or annulus_heights.size() < 4:
		_fail("surrounding hills lack gradual but visible relief: range=%d unique_heights=%d" % [annulus_max - annulus_min, annulus_heights.size()])
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
	var worst_two_cell_step := 0
	var steep_two_cell_edges := 0
	var two_cell_samples: Array[String] = []
	for key in surface_heights:
		if water_columns.has(key):
			continue
		var height := int(surface_heights[key])
		for offset in [Vector2i(2, 0), Vector2i(0, 2)]:
			var neighbor_key: Vector2i = key + offset
			if not surface_heights.has(neighbor_key) or water_columns.has(neighbor_key):
				continue
			var step := absi(height - int(surface_heights[neighbor_key]))
			worst_two_cell_step = maxi(worst_two_cell_step, step)
			if step > 1:
				steep_two_cell_edges += 1
				if two_cell_samples.size() < 16:
					two_cell_samples.append("%s=%d -> %s=%d" % [key, height, neighbor_key, int(surface_heights[neighbor_key])])
	if steep_two_cell_edges > 0:
		push_error("Two-cell terrain edge samples: " + str(two_cell_samples))
		_fail("generated terrain still has %d two-cell rises sharper than one voxel; worst difference is %d blocks" % [steep_two_cell_edges, worst_two_cell_step])
		return

	# After the 0.45-block slope relaxation, adjacent dry ground must round to
	# at most one voxel step; any two-block edge is a real traversal defect.
	if worst_step > 1 or steep_edges > 0:
		push_error("Terrain edge samples: " + str(samples))
		_fail("Generated terrain still contains %d abrupt edges; worst adjacent height difference is %d blocks at %s" % [steep_edges, worst_step, worst_edge])
		return
	print("TERRAIN_WALKABILITY_PASS columns=", surface_heights.size(), " max_adjacent_height_step=", worst_step, " max_two_cell_height_step=", worst_two_cell_step, " two_block_edges=", steep_edges, " hill_relief=", annulus_max - annulus_min, " distinct_hill_heights=", annulus_heights.size())
	quit(0)

func _fail(message: String) -> void:
	push_error("TERRAIN_WALKABILITY_FAIL: " + message)
	quit(1)
