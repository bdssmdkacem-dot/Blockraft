extends SceneTree
## Acceptance test for HUD collisions at desktop and narrow Android-like widths.

const GAME_SCENE := "res://scenes/main.tscn"

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_run")

func _fail(message: String, code: int = 1) -> void:
	push_error("GAMEPLAY_UI_LAYOUT_FAIL: " + message)
	quit(code)

func _rect(control: Control) -> Rect2:
	return Rect2(control.global_position, control.size)

func _run() -> void:
	var packed := load(GAME_SCENE) as PackedScene
	if packed == null:
		_fail("could not load gameplay scene", 2)
		return
	var game := packed.instantiate() as Node3D
	if game == null:
		_fail("gameplay scene root is not Node3D", 3)
		return
	root.add_child(game)

	var ready := false
	for _frame in range(600):
		await process_frame
		if game.get("world_initialized") == true:
			ready = true
			break
	if not ready:
		_fail("world did not initialize before HUD layout check", 4)
		return

	var survival := game.get_node_or_null("Survival")
	if survival == null:
		_fail("survival HUD node is missing", 5)
		return

	for _frame in range(3):
		await process_frame
	if not _check_layout(game, survival, false, Vector2(1280.0, 720.0)):
		return

	game.call("_layout_hotbar", Vector2(360.0, 800.0))
	survival.call("_layout_ui", Vector2(360.0, 800.0))
	for _frame in range(3):
		await process_frame
	if not _check_layout(game, survival, true, Vector2(360.0, 800.0)):
		return

	print("GAMEPLAY_UI_LAYOUT_PASS: desktop HUD clears survival panel; 360px layout keeps hotbar in bounds above touch actions and hides keyboard hint")
	quit(0)

func _check_layout(game: Node, survival: Node, compact: bool, viewport_size: Vector2) -> bool:
	var bag := game.get("backpack_label") as Label
	var upgrade := game.get("upgrade_btn") as Button
	var status := game.get("status_label") as Label
	var hotbar := game.get("hotbar_ui") as HBoxContainer
	var panel := game.find_child("SurvivalStatusPanel", true, false) as Control
	var hint := survival.get("hint_label") as Label
	var toast := game.get("toast_label") as Label
	if bag == null or upgrade == null or status == null or hotbar == null or panel == null or hint == null or toast == null:
		_fail("one or more HUD controls are missing", 6)
		return false

	var panel_rect := _rect(panel)
	print("HUD_LAYOUT_GEOMETRY width=%d panel=%s status=%s bag=%s upgrade=%s hotbar=%s hint=%s" % [int(viewport_size.x), str(panel_rect), str(_rect(status)), str(_rect(bag)), str(_rect(upgrade)), str(_rect(hotbar)), str(_rect(hint))])
	if _rect(bag).intersects(panel_rect):
		_fail("backpack label overlaps the survival status panel at width %d" % int(viewport_size.x), 7)
		return false
	if _rect(upgrade).intersects(panel_rect):
		_fail("depot/upgrade button overlaps the survival status panel at width %d" % int(viewport_size.x), 8)
		return false
	if _rect(status).intersects(panel_rect):
		_fail("discovery status overlaps the survival status panel at width %d" % int(viewport_size.x), 9)
		return false
	if _rect(status).intersects(_rect(toast)):
		_fail("discovery status overlaps the toast area at width %d" % int(viewport_size.x), 17)
		return false
	if _rect(bag).intersects(_rect(upgrade)):
		_fail("backpack label overlaps the depot/upgrade button", 10)
		return false

	var hotbar_rect := _rect(hotbar)
	if hotbar_rect.size.x <= 0.0 or hotbar_rect.size.y <= 0.0:
		_fail("hotbar has no measurable layout size", 11)
		return false
	if hotbar_rect.position.x < -0.5 or hotbar_rect.position.x + hotbar_rect.size.x > viewport_size.x + 0.5:
		_fail("hotbar extends outside the viewport at width %d" % int(viewport_size.x), 12)
		return false
	if hotbar_rect.size.y > (56.5 if not compact else 36.5):
		_fail("hotbar grew taller than its responsive slot size: %s" % str(hotbar_rect.size), 18)
		return false

	if compact:
		if hint.visible:
			_fail("keyboard help hint should be hidden in the narrow touch layout", 13)
			return false
		if hotbar_rect.position.y + hotbar_rect.size.y > viewport_size.y - 205.0:
			_fail("hotbar overlaps the reserved touch-action area", 14)
			return false
	else:
		if not hint.visible:
			_fail("desktop keyboard help hint should remain visible", 15)
			return false
		if _rect(hint).intersects(hotbar_rect):
			_fail("desktop help hint overlaps the hotbar", 16)
			return false
	return true
