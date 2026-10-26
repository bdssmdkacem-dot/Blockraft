extends SceneTree
## Runtime regression test: spawn is grounded on the reserved pad, and fall
## recovery repairs both voxel data and the chunk collision.

const GAME_SCENE := "res://scenes/main.tscn"
const SPAWN_POSITION := Vector3(0.5, 5.04, 0.5)
const SPAWN_TOLERANCE := 0.12

func _initialize() -> void:
	call_deferred("_run_spawn_safety_test")

func _run_spawn_safety_test() -> void:
	var packed := load(GAME_SCENE) as PackedScene
	if packed == null:
		_fail("Could not load gameplay scene: " + GAME_SCENE)
		return

	var game := packed.instantiate() as Node3D
	if game == null:
		_fail("Gameplay scene root is not Node3D")
		return
	root.add_child(game)

	var ready := false
	for _frame in range(900):
		await process_frame
		if bool(game.get("world_initialized")):
			ready = true
			break
	if not ready:
		_fail("World did not initialize within 900 process frames")
		return

	var player := game.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		_fail("Gameplay scene has no CharacterBody3D Player")
		return

	# Allow the physics server to settle after the spawn chunk was built.
	for _frame in range(3):
		await physics_frame

	var blocks: Dictionary = game.get("blocks")
	if str(blocks.get(Vector3i(0, 4, 0), "")) != "grass":
		_fail("Spawn pad has no solid grass block at (0, 4, 0)")
		return
	if blocks.has(Vector3i(0, 5, 0)):
		_fail("Spawn headroom is obstructed directly above the pad")
		return
	if player.global_position.distance_to(SPAWN_POSITION) > SPAWN_TOLERANCE:
		_fail("Player spawned at unexpected position: " + str(player.global_position))
		return
	if not player.is_on_floor():
		_fail("Player is not grounded after spawn; position=" + str(player.global_position))
		return

	# Simulate the failure path and require a collision-backed recovery.
	blocks.erase(Vector3i(0, 4, 0))
	player.global_position = Vector3(SPAWN_POSITION.x, -20.0, SPAWN_POSITION.z)
	player.velocity = Vector3(0.0, -12.0, 0.0)
	game.call("_check_fall_respawn")

	if str(blocks.get(Vector3i(0, 4, 0), "")) != "grass":
		_fail("Fall recovery did not rebuild the spawn-pad voxel")
		return
	if player.global_position.distance_to(SPAWN_POSITION) > SPAWN_TOLERANCE:
		_fail("Fall recovery returned player to an unsafe position: " + str(player.global_position))
		return
	if player.velocity.length() > 0.01:
		_fail("Fall recovery did not clear player velocity")
		return

	for _frame in range(3):
		await physics_frame
	if not player.is_on_floor():
		_fail("Player is not grounded after fall recovery")
		return

	print("SPAWN_SAFETY_TEST_PASS: spawn and fall recovery are collision-backed")
	quit(0)

func _fail(message: String) -> void:
	push_error("SPAWN_SAFETY_TEST_FAIL: " + message)
	quit(1)
