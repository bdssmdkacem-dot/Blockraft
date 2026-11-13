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
	for position in blocks:
		var kind := str(blocks[position])
		if kind not in GROUND_KINDS:
			continue
		var p: Vector3i = position
		var key := Vector2i(p.x, p.z)
		if not surface_heights.has(key) or p.y > int(surface_heights[key]):
			surface_heights[key] = p.y
	if surface_heights.size() < 10000:
		_fail("Too few terrain columns were generated: %d" % surface_heights.size())
		return

	var worst_step := 0
	var steep_edges := 0
	var worst_edge := ""
	var samples: Array[String] = []
	for key in surface_heights:
		var height := int(surface_heights[key])
		for offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
			var neighbor_key: Vector2i = key + offset
			if not surface_heights.has(neighbor_key):
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
	if worst_step > 1:
		push_error("Terrain edge samples: " + str(samples))
		_fail("Generated terrain still contains %d abrupt edges; worst adjacent height difference is %d blocks at %s" % [steep_edges, worst_step, worst_edge])
		return
	print("TERRAIN_WALKABILITY_PASS columns=", surface_heights.size(), " max_adjacent_height_step=", worst_step)
	quit(0)

func _fail(message: String) -> void:
	push_error("TERRAIN_WALKABILITY_FAIL: " + message)
	quit(1)
