extends SceneTree

class TouchTestWorld:
	extends Node3D
	var mining_fx: Node = null
	var blocks: Dictionary = {}

class TouchTestPlayer:
	extends "res://scripts/player.gd"
	var place_requests := 0
	func _interact(place: bool) -> void:
		if place:
			place_requests += 1

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String, code: int) -> void:
	push_error("Touch controls acceptance: " + message)
	quit(code)

func _send_touch(player: Node, index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	player.call("_input", event)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	print("TOUCH_CONTROLS_TEST: create isolated player")
	var world := TouchTestWorld.new()
	root.add_child(world)
	var player := TouchTestPlayer.new()
	world.add_child(player)
	await process_frame
	player.set("touch_controls_enabled", true)
	if player.get("_touch_root") == null:
		player.call("_build_touch_controls")
	await process_frame

	var viewport_size: Vector2 = player.get_viewport().get_visible_rect().size
	# Deliberately touch above the fixed on-screen stick: movement should be floating,
	# not dependent on a fixed rectangle or a specific screen density.
	var start := Vector2(viewport_size.x * 0.16, viewport_size.y * 0.55)
	print("TOUCH_CONTROLS_TEST: movement touch ", start)
	_send_touch(player, 5, start, true)
	if not bool(player.get("joystick_active")) or str(player.get("_touch_roles").get(5, "")) != "move":
		_fail("left-side touch did not acquire the movement stick", 1)
		return

	var before_position: Vector3 = player.global_position
	var drag := InputEventScreenDrag.new()
	drag.index = 5
	drag.position = start + Vector2(72.0, -72.0)
	drag.relative = Vector2(72.0, -72.0)
	player.call("_input", drag)
	var target: Vector2 = player.get("_touch_move_target")
	if target.x < 0.3 or target.y > -0.3:
		_fail("diagonal joystick drag produced wrong movement vector: %s" % str(target), 2)
		return
	for frame in range(18):
		await physics_frame
	var after_position: Vector3 = player.global_position
	var horizontal_distance := Vector2(after_position.x - before_position.x, after_position.z - before_position.z).length()
	print("TOUCH_CONTROLS_TEST: horizontal displacement=", horizontal_distance, " velocity=", player.velocity)
	if horizontal_distance < 0.05:
		_fail("touch vector reached the player but did not move the character body", 3)
		return
	_send_touch(player, 5, drag.position, false)
	if bool(player.get("joystick_active")) or player.get("_touch_move_target") != Vector2.ZERO:
		_fail("releasing the movement finger did not reset the stick", 4)
		return

	var action_origin := Vector2(viewport_size.x - 142.0, viewport_size.y - 205.0)
	var jump_pos := action_origin + Vector2(58.0, 29.0)
	_send_touch(player, 6, jump_pos, true)
	if not bool(player.get("touch_jump_pressed")) or str(player.get("_touch_roles").get(6, "")) != "jump":
		_fail("JUMP touch did not set jump state", 5)
		return
	_send_touch(player, 6, jump_pos, false)
	if bool(player.get("touch_jump_pressed")):
		_fail("releasing JUMP did not clear jump state", 6)
		return

	var mine_pos := action_origin + Vector2(58.0, 97.0)
	_send_touch(player, 7, mine_pos, true)
	if not bool(player.get("_mine_held")) or str(player.get("_touch_roles").get(7, "")) != "mine":
		_fail("MINE touch did not set mining state", 7)
		return
	_send_touch(player, 7, mine_pos, false)
	if bool(player.get("_mine_held")):
		_fail("releasing MINE did not clear mining state", 8)
		return

	var place_pos := action_origin + Vector2(58.0, 165.0)
	_send_touch(player, 8, place_pos, true)
	if str(player.get("_touch_roles").get(8, "")) != "place" or player.place_requests != 1:
		_fail("PLACE touch did not invoke the place action", 9)
		return
	_send_touch(player, 8, place_pos, false)
	print("TOUCH_CONTROLS_ACCEPTANCE_PASS: character moved, stick release reset, and jump/mine/place touch states passed")
	quit(0)
