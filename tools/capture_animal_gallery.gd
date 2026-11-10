extends SceneTree

const ANIMAL_SCRIPT := preload("res://scripts/animal.gd")

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_capture")

func _capture() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#9db9d1")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#ffffff")
	env.ambient_light_energy = 0.65
	env_node.environment = env
	world.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -28, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	world.add_child(sun)
	var floor_body := StaticBody3D.new()
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(18, 0.4, 8)
	floor_mesh.mesh = floor_box
	floor_mesh.position.y = -0.2
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("#617c4a")
	floor_mesh.material_override = floor_mat
	floor_body.add_child(floor_mesh)
	var floor_shape := CollisionShape3D.new()
	var floor_collision := BoxShape3D.new()
	floor_collision.size = floor_box.size
	floor_shape.shape = floor_collision
	floor_shape.position.y = -0.2
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	var names := ["FOX", "CHICKEN", "COW", "SHEEP"]
	for kind in range(4):
		var animal := ANIMAL_SCRIPT.new() as CharacterBody3D
		animal.name = "AnimalGallery_%s" % names[kind]
		world.add_child(animal)
		animal.setup(kind, Vector3(-5.1 + float(kind) * 3.4, 0.1, 0))
		animal.set_physics_process(false)
		var label := Label3D.new()
		label.text = names[kind]
		label.position = Vector3(0, 2.0, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 48
		label.modulate = Color("#17232d")
		animal.add_child(label)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 4.2, 12.5)
	camera.look_at(Vector3(0, 0.9, 0), Vector3.UP)
	camera.current = true
	camera.fov = 43.0
	world.add_child(camera)
	for _i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.is_empty() or image.get_width() != 1280 or image.get_height() != 720:
		push_error("Animal gallery capture failed")
		quit(2)
		return
	var err := image.save_png(ProjectSettings.globalize_path("res://animal_gallery_capture.png"))
	if err != OK:
		push_error("Could not save animal gallery image: %s" % err)
		quit(3)
		return
	print("ANIMAL_GALLERY_CAPTURE_PASS")
	quit(0)
