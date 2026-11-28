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

	var tagline := scene.find_child("MenuTagline", true, false) as Label
	if tagline == null:
		_fail("main menu tagline is missing", 54)
		return
	var desktop_viewport := scene.get_viewport().get_visible_rect().size
	if not tagline.visible or tagline.position.x < 0.0 or tagline.position.x + tagline.size.x > desktop_viewport.x - 12.0:
		_fail("desktop tagline is hidden or clipped by the right viewport edge", 55)
		return
	scene.call("_apply_responsive_layout", Vector2(360.0, 640.0))
	if tagline.visible:
		_fail("tagline should hide on narrow screens to avoid the action column", 56)
		return
	scene.call("_apply_responsive_layout", Vector2(1280.0, 720.0))
	if not tagline.visible or tagline.position.x + tagline.size.x > 1268.0:
		_fail("tagline did not restore within the desktop safe area", 57)
		return

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
	var terrain_min_y := INF
	var terrain_max_y := -INF
	for terrain_vertex in terrain_vertices:
		terrain_min_y = minf(terrain_min_y, terrain_vertex.y)
		terrain_max_y = maxf(terrain_max_y, terrain_vertex.y)
	if terrain_max_y - terrain_min_y < 0.55:
		_fail("menu meadow still reads as a flat slab: relief=%.3f" % (terrain_max_y - terrain_min_y), 60)
		return
	var village := world.find_child("Village", true, false) as Node3D
	if village == null:
		_fail("village root is missing", 37)
		return
	var village_group_names := ["CottageQuarter", "LonghouseQuarter", "StoneTowerQuarter"]
	var village_roof_names := ["Roof_Gable", "Roof_Hipped", "Roof_Parapet"]
	var village_footprints: Array[Vector3] = []
	var village_house_count := 0
	for group_index in range(village_group_names.size()):
		var house_group := village.get_node_or_null(village_group_names[group_index]) as Node3D
		if house_group == null or house_group.get_child_count() != 3:
			_fail("village neighbourhood is missing its three distinct houses: %s" % village_group_names[group_index], 37)
			return
		var first_house := house_group.get_child(0) as Node3D
		var footprint := first_house.get_node_or_null("Footprint") as MeshInstance3D if first_house else null
		if footprint == null or not (footprint.mesh is BoxMesh):
			_fail("village house is missing its measurable footprint", 66)
			return
		village_footprints.append((footprint.mesh as BoxMesh).size)
		for house_variant in house_group.get_children():
			var house := house_variant as Node3D
			if house == null or int(house.get_meta("architecture_style", -1)) != group_index:
				_fail("village house was placed in the wrong architectural neighbourhood", 67)
				return
			if house.get_node_or_null(village_roof_names[group_index]) == null:
				_fail("village neighbourhood is missing its unique roof language: %s" % village_roof_names[group_index], 68)
				return
			village_house_count += 1
	if village_house_count != 9:
		_fail("village should contain nine houses across three architectural groups", 69)
		return
	if village_footprints[0].distance_to(village_footprints[1]) < 0.5 or village_footprints[1].distance_to(village_footprints[2]) < 0.5 or village_footprints[0].distance_to(village_footprints[2]) < 0.5:
		_fail("village architectural groups still share repeated house footprints", 70)
		return
	var river_root := world.find_child("River", true, false) as Node3D
	if river_root == null:
		_fail("menu panorama is missing its river and bridge", 38)
		return
	var river_surface := river_root.get_node_or_null("RiverSurface") as MeshInstance3D
	var river_banks := river_root.get_node_or_null("RiverBanks") as MeshInstance3D
	if river_surface == null or river_banks == null or not (river_surface.mesh is ArrayMesh) or not (river_banks.mesh is ArrayMesh):
		_fail("menu river must use curved water and bank ArrayMesh surfaces", 54)
		return
	var river_arrays: Array = river_surface.mesh.surface_get_arrays(0)
	var river_vertices: PackedVector3Array = river_arrays[Mesh.ARRAY_VERTEX]
	var river_indices: PackedInt32Array = river_arrays[Mesh.ARRAY_INDEX]
	if river_vertices.size() != 146 or river_indices.size() != 432:
		_fail("menu river surface exceeds or misses its bounded ribbon geometry", 55)
		return
	var river_normals: PackedVector3Array = river_arrays[Mesh.ARRAY_NORMAL]
	for river_vertex in river_vertices:
		if river_vertex.y < 0.19:
			_fail("menu river surface is below the landscape plane and will be occluded", 59)
			return
	for index_offset in range(0, river_indices.size(), 3):
		var ia := river_indices[index_offset]
		var ib := river_indices[index_offset + 1]
		var ic := river_indices[index_offset + 2]
		var geometric_normal := (river_vertices[ib] - river_vertices[ia]).cross(river_vertices[ic] - river_vertices[ia])
		if geometric_normal.length_squared() < 0.0001 or geometric_normal.normalized().dot(river_normals[ia]) > -0.99:
			_fail("menu river triangle winding hides the water surface from above", 58)
			return
	var river_center_min := INF
	var river_center_max := -INF
	for vertex_index in range(0, river_vertices.size(), 2):
		var center_x := (river_vertices[vertex_index].x + river_vertices[vertex_index + 1].x) * 0.5
		river_center_min = minf(river_center_min, center_x)
		river_center_max = maxf(river_center_max, center_x)
	if river_center_max - river_center_min < 1.0:
		_fail("menu river centerline is still a straight rectangular channel", 56)
		return
	var bank_arrays: Array = river_banks.mesh.surface_get_arrays(0)
	var bank_vertices: PackedVector3Array = bank_arrays[Mesh.ARRAY_VERTEX]
	var bank_indices: PackedInt32Array = bank_arrays[Mesh.ARRAY_INDEX]
	if bank_vertices.size() != 292 or bank_indices.size() != 864:
		_fail("menu river banks are missing their low-cost paired shoreline ribbons", 57)
		return
	# The owner-approved north-star reference explicitly includes floating
	# islands and waterfalls. Do not reject this landmark by name: an integrated
	# island is a required visual direction, not inherently disconnected debris.
	# Keep this manual visual gate visible until the landmark is implemented and
	# reviewed in a fresh capture; structural CI must not imply visual acceptance.
	if world.find_child("FloatingIsland", true, false) == null:
		print("MENU_FLOATING_ISLAND_VISUAL_GATE_PENDING: north-star composition still requires an integrated floating island and waterfall")

	var forests := world.find_child("Forests", true, false) as Node3D
	var right_grove := forests.get_node_or_null("RightGrove") as Node3D if forests else null
	if right_grove == null or right_grove.get_child_count() != 12:
		_fail("menu panorama lacks the balanced 12-tree right meadow grove", 62)
		return
	var grove_min_x := INF
	var grove_max_x := -INF
	for grove_tree in right_grove.get_children():
		if not grove_tree is Node3D or (grove_tree as Node3D).get_node_or_null("Trunk") == null:
			_fail("right meadow tree is missing its grounded trunk", 63)
			return
		var tree_node := grove_tree as Node3D
		grove_min_x = minf(grove_min_x, tree_node.position.x)
		grove_max_x = maxf(grove_max_x, tree_node.position.x)
		for canopy_name in ["Canopy_Core", "Canopy_Left", "Canopy_Right", "Canopy_Crown"]:
			var canopy := tree_node.get_node_or_null(canopy_name) as MeshInstance3D
			if canopy == null or not (canopy.mesh is SphereMesh):
				_fail("right meadow tree lacks its layered low-poly canopy: %s" % canopy_name, 64)
				return
	if grove_min_x < 7.0 or grove_max_x < 30.0:
		_fail("right meadow grove does not occupy the open right panorama flank", 65)
		return

	var hero := world.find_child("Protagonist", true, false) as Node3D
	if hero == null:
		_fail("menu protagonist is missing", 31)
		return
	if world.find_child("RockyOutcropBase", true, false) != null or hero.position.y < 0.0 or hero.position.y > 0.2:
		_fail("menu protagonist is still displayed on a raised floating plinth instead of grounded terrain", 61)
		return
	if hero.get_child_count() < 24 or hero.find_child("DiamondPickaxe", true, false) == null:
		_fail("menu protagonist silhouette is missing layered clothing, backpack or pickaxe detail", 32)
		return
	if hero.position.x < -10.0:
		_fail("menu protagonist remains underneath the left action-button column", 42)
		return
	# Reject the former row of repeated cone peaks; the connected ridge pass
	# below is now the only mountain skyline.
	if world.find_child("MountainBackdrop", true, false) != null or world.find_child("Horizon", true, false) != null:
		_fail("legacy repeated mountain cones or box horizon remain in the panorama", 43)
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
