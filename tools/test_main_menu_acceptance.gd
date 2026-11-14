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
	if world.find_child("SunsetDisc", true, false) == null or world.find_child("SkyClouds", true, false) == null:
		_fail("menu sunset focal light or cloud layers are missing", 39)
		return
	if world.find_child("GoldenHourSun", true, false) == null:
		_fail("3D menu world has no key light", 27)
		return
	if world.find_child("MountainBackdrop", true, false) == null:
		_fail("menu panorama is missing layered mountain and waterfall backdrop", 34)
		return
	var environment_nodes := world.find_children("*", "WorldEnvironment", true, false)
	var world_environment: WorldEnvironment = environment_nodes[0] as WorldEnvironment if not environment_nodes.is_empty() else null
	if world_environment == null or world_environment.environment == null:
		_fail("menu panorama has no controlled environment/tonemapping", 35)
		return
	if world_environment.environment.tonemap_exposure > 0.9 or world_environment.environment.ambient_light_energy > 0.32:
		_fail("menu lighting exceeds the visual exposure budget", 36)
		return
	var terrain_art := world.find_child("TerrainArtPass", true, false) as MeshInstance3D
	if terrain_art == null or not (terrain_art.mesh is ArrayMesh):
		_fail("menu panorama is missing the vertex-coloured rolling terrain art pass", 48)
		return
	var terrain_arrays: Array = terrain_art.mesh.surface_get_arrays(0)
	var terrain_vertices: PackedVector3Array = terrain_arrays[Mesh.ARRAY_VERTEX]
	var terrain_colors: PackedColorArray = terrain_arrays[Mesh.ARRAY_COLOR]
	if terrain_vertices.size() < 1500 or terrain_colors.size() != terrain_vertices.size():
		_fail("menu terrain art pass lacks dense vertex-colour detail", 49)
		return
	var village := world.find_child("Village", true, false) as Node3D
	if village == null or village.get_child_count() < 120:
		_fail("village has no layered gabled house silhouettes", 37)
		return
	if world.find_child("River", true, false) == null:
		_fail("menu panorama is missing its river and bridge", 38)
		return
	# The former floating-island landmark was removed because it read as
	# disconnected debris in the menu skyline. Keep the grounded mountain,
	# castle, village and river landmarks as the panorama's focal composition.
	if world.find_child("FloatingIsland", true, false) != null:
		_fail("menu panorama still contains distracting floating-island debris", 28)
		return

	var hero := world.find_child("Protagonist", true, false) as Node3D
	if hero == null:
		_fail("menu protagonist is missing", 31)
		return
	if hero.get_child_count() < 24 or hero.find_child("DiamondPickaxe", true, false) == null:
		_fail("menu protagonist silhouette is missing layered clothing, backpack or pickaxe detail", 32)
		return
	if hero.position.x < -10.0:
		_fail("menu protagonist remains underneath the left action-button column", 42)
		return
	var rounded_peaks := 0
	var mountain_root := world.find_child("MountainBackdrop", true, false) as Node3D
	for mountain_part in mountain_root.find_children("*", "MeshInstance3D", true, false):
		var mountain_mesh := (mountain_part as MeshInstance3D).mesh
		if mountain_mesh is ArrayMesh and mountain_mesh.get_surface_count() == 1:
			var mountain_arrays: Array = mountain_mesh.surface_get_arrays(0)
			var mountain_vertices: PackedVector3Array = mountain_arrays[Mesh.ARRAY_VERTEX]
			var mountain_colors: PackedColorArray = mountain_arrays[Mesh.ARRAY_COLOR]
			if mountain_vertices.size() >= 300 and mountain_colors.size() == mountain_vertices.size():
				rounded_peaks += 1
	if rounded_peaks < 9:
		_fail("mountain backdrop is missing faceted multi-ring ridge meshes", 43)
		return
	var connected_ridges := world.find_child("ConnectedMountainRidges", true, false) as Node3D
	if connected_ridges == null or connected_ridges.get_child_count() != 3:
		_fail("menu panorama is missing three connected alpine ridgelines", 50)
		return
	for ridge_part in connected_ridges.get_children():
		if not ridge_part is MeshInstance3D or not ((ridge_part as MeshInstance3D).mesh is ArrayMesh):
			_fail("connected alpine ridge is not a generated mesh", 51)
			return
		var ridge_arrays: Array = (ridge_part as MeshInstance3D).mesh.surface_get_arrays(0)
		var ridge_vertices: PackedVector3Array = ridge_arrays[Mesh.ARRAY_VERTEX]
		var ridge_normals: PackedVector3Array = ridge_arrays[Mesh.ARRAY_NORMAL]
		var ridge_colors: PackedColorArray = ridge_arrays[Mesh.ARRAY_COLOR]
		if ridge_vertices.size() < 300 or ridge_normals.size() != ridge_vertices.size() or ridge_colors.size() != ridge_vertices.size():
			_fail("connected alpine ridge lacks complete vertex, normal or colour buffers", 52)
			return
	var cloud_root := world.find_child("SkyClouds", true, false) as Node3D
	if cloud_root == null or cloud_root.get_child_count() < 15:
		_fail("menu sky does not contain the complete soft-cloud layer", 46)
		return
	for cloud_part in cloud_root.get_children():
		if not cloud_part is MeshInstance3D or not (cloud_part.mesh is SphereMesh):
			_fail("menu sky contains a hard-edged floating cloud fragment", 47)
			return
	var castle := world.find_child("GatehouseCastle", true, false) as Node3D
	if castle == null or castle.get_child_count() < 120:
		_fail("menu castle lacks the layered facade and landmark detail pass", 33)
		return
	if castle.scale.x > 1.15:
		_fail("castle scale clips the upper landmark at menu framing", 44)
		return
	for wing_name in ["CastleWestWing", "CastleEastWing"]:
		var wing := castle.get_node_or_null(wing_name) as Node3D
		if wing == null or wing.get_child_count() < 20:
			_fail("castle is missing a fully detailed side wing: %s" % wing_name, 53)
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
		if card.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			_fail("feature card blocks neither input nor accessibility", 7)
			return

	scene._on_menu_action("settings")
	await process_frame
	var settings_panel := scene.find_child("SettingsPanel", true, false)
	if settings_panel == null:
		_fail("Settings action did not open SettingsPanel", 12)
		return
	if is_instance_valid(scene.dialog_layer):
		scene.dialog_layer.queue_free()
		scene.dialog_layer = null
	await process_frame
	scene._on_menu_action("help")
	await process_frame
	var dialog := scene.find_child("MenuDialog", true, false)
	if dialog == null:
		_fail("How to Play action did not open MenuDialog", 11)
		return
	if is_instance_valid(scene.dialog_layer):
		scene.dialog_layer.queue_free()
		scene.dialog_layer = null
	await process_frame

	var play_button := scene.find_child("PlayButton", true, false) as Button
	if play_button == null:
		_fail("PlayButton was not found for end-to-end interaction test", 30)
		return
	play_button.emit_signal("pressed")
	var transitioned := false
	for attempt in range(120):
		await process_frame
		if current_scene != null and str(current_scene.scene_file_path) == "res://scenes/main.tscn":
			transitioned = true
			break
	if not transitioned:
		_fail("Play button signal did not transition to scenes/main.tscn", 13)
		return

	# Let the deferred gameplay bootstrap finish before releasing the scene.
	# Freeing it on the first transition frame leaves queued world-generation
	# callbacks and resources alive at process shutdown.
	var gameplay_scene := current_scene
	var world_ready := false
	for attempt in range(180):
		if gameplay_scene == null or not is_instance_valid(gameplay_scene):
			break
		if bool(gameplay_scene.get("world_initialized")):
			world_ready = true
			break
		await process_frame
	if not world_ready:
		_fail("gameplay scene did not finish deferred initialization after Play", 45)
		return

	print("MENU_ACCEPTANCE_PASS: 3D world, six feature cards, primary actions, dialogs, and gameplay transition verified")
	if gameplay_scene != null and is_instance_valid(gameplay_scene):
		gameplay_scene.queue_free()
	if scene != null and is_instance_valid(scene):
		scene.queue_free()
	await process_frame
	await process_frame
	await physics_frame
	quit(0)
