extends SceneTree

class TouchTestWorld:
	extends Node3D
	var mining_fx: Node = null
	var blocks: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String, code: int) -> void:
	push_error("Touch controls acceptance: " + message)
	quit(code)

func _send_touch(player: CharacterBody3D, index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	player._input(event)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var world := TouchTestWorld.new()
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.set_script(load("res://scripts/player.gd"))
	world.add_child(player)
	await process_frame
	player.touch_controls_enabled = true
	if player._touch_root == null:
		player._build_touch_controls()
	await process_frame

	var viewport_size: Vector2 = player.get_viewport().get_visible_rect().size
	var start := Vector2(viewport_size.x * 0.16, viewport_size.y * 0.55)
	_send_touch(player, 5, start, true)
	if not player.joystick_active or str(player._touch_roles.get(5, "")) != "move":
		_fail("left-side touch did not acquire the movement stick", 1)
		return

	var drag := InputEventScreenDrag.new()
	drag.index = 5
	drag.position = start + Vector2(72.0, -72.0)
	drag.relative = Vector2(72.0, -72.0)
	player._input(drag)
	if player._touch_move_target.x < 0.3 or player._touch_move_target.y > -0.3:
		_fail("diagonal joystick drag did not produce a matching movement vector: %s" % str(player._touch_move_target), 2)
		return
	_send_touch(player, 5, drag.position, false)
	if player.joystick_active or player._touch_move_target != Vector2.ZERO:
		_fail("releasing the movement finger did not reset the stick", 3)
		return

	var action_origin := Vector2(viewport_size.x - 142.0, viewport_size.y - 205.0)
	var jump_pos := action_origin + Vector2(58.0, 29.0)
	_send_touch(player, 6, jump_pos, true)
	if not player.touch_jump_pressed or str(player._touch_roles.get(6, "")) != "jump":
		_fail("JUMP touch did not set jump state", 4)
		return
	_send_touch(player, 6, jump_pos, false)
	if player.touch_jump_pressed:
		_fail("releasing JUMP did not clear jump state", 5)
		return

	var mine_pos := action_origin + Vector2(58.0, 97.0)
	_send_touch(player, 7, mine_pos, true)
	if not player._mine_held or str(player._touch_roles.get(7, "")) != "mine":
		_fail("MINE touch did not set mining state", 6)
		return
	_send_touch(player, 7, mine_pos, false)
	if player._mine_held:
		_fail("releasing MINE did not clear mining state", 7)
		return

	var place_pos := action_origin + Vector2(58.0, 165.0)
	_send_touch(player, 8, place_pos, true)
	if str(player._touch_roles.get(8, "")) != "place":
		_fail("PLACE touch was not mapped to the place action", 8)
		return
	_send_touch(player, 8, place_pos, false)
	print("TOUCH_CONTROLS_ACCEPTANCE_PASS: floating movement drag, joystick release, jump, mining, and place hit regions")
	quit(0)
