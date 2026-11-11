extends SceneTree

const MARKER := Vector3i(40, 20, 40)
const SAVE_PATH := "user://world_blocks.json"

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_run")

func _fail(message: String, code: int) -> void:
	push_error("Process restart persistence: " + message)
	quit(code)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := "verify"
	for argument in args:
		var candidate := str(argument).trim_prefix("--")
		if candidate in ["write", "verify"]:
			phase = candidate
			break
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("gameplay scene could not load", 2)
		return
	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	var ready := false
	for _i in range(240):
		await process_frame
		if scene.world_initialized:
			ready = true
			break
	if not ready:
		_fail("world did not initialize", 3)
		return
	var inventory := scene.get_node_or_null("Inventory")
	if inventory == null:
		_fail("inventory node is missing", 4)
		return

	if phase == "write":
		# Seed a valid primary snapshot first so the next save must rotate it
		# into the backup. This keeps the process-restart test independent of
		# stale user:// files left by earlier CI steps.
		scene.save_world()
		scene.blocks[MARKER] = "stone"
		inventory.slots[1]["count"] = 9
		inventory.storage["stone"] = 17
		scene.save_world()
		if not FileAccess.file_exists(SAVE_PATH + ".bak"):
			_fail("second save did not preserve the first snapshot as backup", 5)
			return
		scene.blocks[MARKER] = "crystal"
		inventory.slots[1]["count"] = 3
		inventory.storage["stone"] = 2
		scene.save_world()
		var corrupt := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if corrupt == null:
			_fail("could not corrupt primary save for recovery test", 6)
			return
		corrupt.store_string("{broken-primary")
		corrupt.close()
		print("PROCESS_RESTART_WRITE_PASS: primary deliberately corrupted after valid backup was committed")
		quit(0)
		return

	if str(scene.blocks.get(MARKER, "")) != "stone":
		_fail("fresh process did not restore the previous world snapshot from backup", 7)
		return
	if int(inventory.slots[1].get("count", -1)) != 9 or int(inventory.storage_count("stone")) != 17:
		_fail("fresh process did not restore the matching inventory backup", 8)
		return
	print("PROCESS_RESTART_RECOVERY_PASS: new Godot process restored world and inventory from last-known-good backup")
	quit(0)
