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

	# Saving immediately after fallback recovery must not rotate the corrupt
	# primary over the only known-good backup.
	scene.save_world()
	var primary := _read_snapshot(SAVE_PATH)
	if primary.is_empty() or not _snapshot_has_marker(primary, "stone"):
		_fail("saving after backup recovery did not write a valid restored primary snapshot", 9)
		return
	var backup := _read_snapshot(SAVE_PATH + ".bak")
	if backup.is_empty() or not _snapshot_has_marker(backup, "stone"):
		_fail("saving after recovery replaced the last-known-good backup with the corrupt primary", 10)
		return
	var backup_inventory: Dictionary = backup.get("inventory", {})
	var backup_slots: Array = backup_inventory.get("slots", [])
	var backup_storage: Dictionary = backup_inventory.get("storage", {})
	if backup_slots.size() != 9 or int(backup_slots[1].get("count", -1)) != 9 or int(backup_storage.get("stone", -1)) != 17:
		_fail("last-known-good backup did not preserve the matching hotbar and depot values", 11)
		return
	print("PROCESS_RESTART_RECOVERY_PASS: new process restored world/inventory and a post-recovery save preserved the last-known-good backup")
	quit(0)

func _read_snapshot(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _snapshot_has_marker(snapshot: Dictionary, expected_kind: String) -> bool:
	for entry in snapshot.get("blocks", []):
		if typeof(entry) == TYPE_ARRAY and entry.size() >= 4:
			var position := Vector3i(int(entry[0]), int(entry[1]), int(entry[2]))
			if position == MARKER:
				return str(entry[3]) == expected_kind
	return false
