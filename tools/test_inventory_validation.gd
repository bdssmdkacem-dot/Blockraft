extends SceneTree
## Strict schema and non-mutating rejection tests for persisted inventory state.

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String, code: int = 1) -> void:
	push_error("INVENTORY_VALIDATION_FAIL: " + message)
	quit(code)

func _expect_invalid(inventory: Node, state: Dictionary, label: String) -> bool:
	if inventory.validate_state(state):
		_fail("malformed inventory was accepted: " + label, 2)
		return false
	return true

func _run() -> void:
	var packed := load("res://scripts/inventory.gd") as Script
	if packed == null:
		_fail("inventory script could not be loaded", 3)
		return
	var inventory: Variant = packed.new()
	root.add_child(inventory)
	await process_frame
	var valid: Dictionary = inventory.export_state()
	if not inventory.validate_state(valid):
		_fail("default exported inventory did not validate", 4)
		return

	var bad: Dictionary = valid.duplicate(true)
	bad["selected"] = -1
	if not _expect_invalid(inventory, bad, "negative selected slot"): return
	bad = valid.duplicate(true)
	bad["selected"] = 9
	if not _expect_invalid(inventory, bad, "selected slot past hotbar"): return
	bad = valid.duplicate(true)
	bad["slots"][2]["id"] = "unknown_mod_item"
	if not _expect_invalid(inventory, bad, "unknown item id"): return
	bad = valid.duplicate(true)
	bad["slots"][0]["count"] = 2
	if not _expect_invalid(inventory, bad, "stacked pickaxe tool"): return
	bad = valid.duplicate(true)
	bad["slots"][0]["is_tool"] = false
	if not _expect_invalid(inventory, bad, "pickaxe marked as a normal item"): return
	bad = valid.duplicate(true)
	bad["slots"][1] = {"id": "pickaxe", "count": 1, "is_tool": true}
	if not _expect_invalid(inventory, bad, "duplicate pickaxe tool"): return
	bad = valid.duplicate(true)
	bad["slots"][0] = {"id": "", "count": 0, "is_tool": false}
	if not _expect_invalid(inventory, bad, "missing required pickaxe tool"): return
	bad = valid.duplicate(true)
	bad["slots"][2]["count"] = 0
	if not _expect_invalid(inventory, bad, "non-empty item with zero count"): return
	bad = valid.duplicate(true)
	bad["slots"][2]["count"] = -1
	if not _expect_invalid(inventory, bad, "negative item count"): return
	bad = valid.duplicate(true)
	bad["slots"][2]["count"] = "24"
	if not _expect_invalid(inventory, bad, "string item count"): return
	bad = valid.duplicate(true)
	bad["storage"]["unknown_mod_item"] = 4
	if not _expect_invalid(inventory, bad, "unknown depot item"): return
	bad = valid.duplicate(true)
	bad["storage"]["stone"] = 0
	if not _expect_invalid(inventory, bad, "zero depot stack"): return
	bad = valid.duplicate(true)
	bad.erase("storage")
	if not _expect_invalid(inventory, bad, "missing depot state"): return

	var before: Dictionary = inventory.export_state()
	bad = valid.duplicate(true)
	bad["slots"][1]["id"] = "unknown_mod_item"
	if inventory.import_state(bad):
		_fail("import_state accepted malformed inventory", 5)
		return
	if inventory.export_state() != before:
		_fail("rejected inventory import mutated live player inventory", 6)
		return

	print("INVENTORY_VALIDATION_PASS: valid round-trip accepted; malformed ids, counts, tools, slots and depot data rejected without mutating live state")
	quit(0)
