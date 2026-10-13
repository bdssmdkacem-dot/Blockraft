extends SceneTree

func _initialize() -> void:
	call_deferred("_run_checks")

func _fail(message: String, code: int) -> void:
	push_error("Acceptance test: " + message)
	quit(code)

func _run_checks() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/main_menu.tscn") as PackedScene
	if packed == null:
		_fail("main_menu.tscn failed to load", 2)
		return

	var scene := packed.instantiate() as Control
	if scene == null:
		_fail("menu root is not a Control", 3)
		return
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	await process_frame

	var backdrop := scene.find_child("ThreeDMenuBackdrop", true, false) as SubViewportContainer
	if backdrop == null:
		_fail("real-time 3D menu backdrop is missing", 23)
		return
	var world_viewport := backdrop.get_node_or_null("WorldViewport") as SubViewport
	if world_viewport == null:
		_fail("3D menu SubViewport is missing", 24)
		return
	var world := world_viewport.get_node_or_null("VoxelMenuWorld") as Node3D
	if world == null:
		_fail("3D voxel menu world did not instantiate", 25)
		return
	var camera := world.find_child("MenuWorldCamera", true, false) as Camera3D
	if camera == null:
		_fail("3D menu world has no perspective camera", 26)
		return
	if camera.rotation.x > -0.05:
		_fail("menu camera is not pitched down toward the voxel landscape", 29)
		return
	if world.find_child("GoldenHourSun", true, false) == null:
		_fail("3D menu world has no key light", 27)
		return
	if world.find_child("FloatingIsland", true, false) == null:
		_fail("3D menu world is missing its floating island landmark", 28)
		return

	var strip := scene.find_child("FeatureStrip", true, false) as HBoxContainer
	if strip == null:
		_fail("FeatureStrip is missing", 4)
		return
	if strip.get_child_count() != 6:
		_fail("expected six feature cards, got %s" % strip.get_child_count(), 5)
		return

	var buttons_found := {}
	for node in scene.find_children("*", "Button", true, false):
		if node is Button:
			buttons_found[(node as Button).text] = true
	var primary_ok := false
	for caption in buttons_found.keys():
		if "PLAY" in caption.to_upper() or caption.strip_edges().begins_with("▶"):
			primary_ok = true
			break
	if not primary_ok:
		_fail("missing Play action button", 6)
		return

	for card_node in strip.get_children():
		var card := card_node as Control
		if card == null:
			_fail("feature card is not a Control", 15)
			return
		var hit_nodes := card.find_children("*", "Button", true, false)
		if hit_nodes.is_empty():
			_fail("feature card has no accessible hit area", 7)
			return
		var hit_area := hit_nodes[0] as Button
		if hit_area.pressed.get_connections().is_empty():
			_fail("feature card hit area has no action connection", 8)
			return

	if scene.has_method("_on_menu_action"):
		scene._on_menu_action("settings")
		await process_frame
		var dialog := scene.find_child("MenuDialog", true, false)
		if dialog == null:
			_fail("Settings action did not open MenuDialog", 12)
			return
		if scene.has_method("_on_dialog_action"):
			scene._on_dialog_action("close")
			await process_frame
		scene._on_menu_action("help")
		await process_frame
		dialog = scene.find_child("MenuDialog", true, false)
		if dialog == null:
			_fail("How to Play action did not open MenuDialog", 11)
			return
		if scene.has_method("_on_dialog_action"):
			scene._on_dialog_action("close")
			await process_frame

	if scene.has_method("_start_game"):
		scene._start_game()
		await process_frame
		await process_frame
		if current_scene == null or str(current_scene.scene_file_path) != "res://scenes/main.tscn":
			_fail("Play did not transition to scenes/main.tscn", 13)
			return

	print("MENU_ACCEPTANCE_PASS: 3D world, six feature cards, primary actions, dialogs, and gameplay transition verified")
	quit(0)
