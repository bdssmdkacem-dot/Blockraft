extends Node3D

func _ready() -> void:
    var camera := get_node_or_null("Camera3D") as Camera3D
    if camera:
        camera.look_at(Vector3(0, 2.2, 0), Vector3.UP)

    var environment := WorldEnvironment.new()
    var world := Environment.new()
    world.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color("#4779a1")
    sky_material.sky_horizon_color = Color("#d8cba5")
    sky_material.ground_bottom_color = Color("#263c34")
    sky_material.ground_horizon_color = Color("#9b9877")
    sky.sky_material = sky_material
    world.sky = sky
    world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    world.ambient_light_color = Color("#b6cbb4")
    world.ambient_light_energy = 0.65
    environment.environment = world
    add_child(environment)

    var floor := MeshInstance3D.new()
    var floor_mesh := BoxMesh.new()
    floor_mesh.size = Vector3(20, 0.2, 8)
    floor.mesh = floor_mesh
    floor.position = Vector3(0, -0.15, 0)
    var floor_material := StandardMaterial3D.new()
    floor_material.albedo_color = Color("#354b38")
    floor_material.roughness = 1.0
    floor.material_override = floor_material
    add_child(floor)


    # Reference-aligned production prototypes: protagonist, diamond pickaxe,
    # castle gatehouse, and still-water voxel. These are built as real 3D meshes
    # so their silhouettes/materials can be inspected in the asset gallery.
    _build_protagonist(Vector3(-5.0, 0.0, -2.7))
    _build_castle_gatehouse(Vector3(0.0, 0.0, -2.7))
    _build_still_water_cube(Vector3(5.0, 0.0, -2.7))


func _mat(color: Color, roughness: float = 0.82, metallic: float = 0.0, transparent: bool = false) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    if transparent:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
        material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material


func _block(parent: Node3D, name: String, pos: Vector3, size: Vector3, color: Color, roughness: float = 0.82, metallic: float = 0.0) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = name
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    mesh_instance.material_override = _mat(color, roughness, metallic)
    mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    parent.add_child(mesh_instance)
    return mesh_instance


func _build_protagonist(origin: Vector3) -> void:
    var root := Node3D.new()
    root.name = "ReferenceProtagonist"
    root.position = origin
    add_child(root)

    # Teal shirt, blue trousers, charcoal boots, layered hair and facial features.
    _block(root, "Torso_Teal", Vector3(0, 2.05, 0), Vector3(0.92, 1.05, 0.48), Color("#08b7ad"))
    _block(root, "Belt", Vector3(0, 1.53, 0), Vector3(0.94, 0.12, 0.5), Color("#174f9a"))
    _block(root, "Head", Vector3(0, 2.92, 0), Vector3(0.78, 0.78, 0.68), Color("#e9b58b"))
    _block(root, "Hair_Cap", Vector3(0, 3.32, -0.01), Vector3(0.84, 0.25, 0.74), Color("#75401f"))
    _block(root, "Hair_Back", Vector3(0, 2.98, -0.31), Vector3(0.82, 0.58, 0.16), Color("#75401f"))
    _block(root, "Hair_Front", Vector3(0, 3.18, 0.355), Vector3(0.78, 0.16, 0.08), Color("#75401f"))
    for eye_x in [-0.18, 0.18]:
        _block(root, "Eye", Vector3(eye_x, 2.99, 0.353), Vector3(0.105, 0.12, 0.045), Color("#f8f5e9"))
        _block(root, "Pupil", Vector3(eye_x, 2.99, 0.382), Vector3(0.052, 0.08, 0.025), Color("#25344a"))
    _block(root, "Nose", Vector3(0, 2.84, 0.39), Vector3(0.12, 0.13, 0.08), Color("#d99a72"))

    # Articulated-looking block limbs with joints kept visually connected.
    for side in [-1.0, 1.0]:
        _block(root, "Sleeve", Vector3(side * 0.59, 2.18, 0), Vector3(0.3, 0.65, 0.46), Color("#08b7ad"))
        _block(root, "Arm", Vector3(side * 0.6, 1.69, 0.02), Vector3(0.24, 0.48, 0.3), Color("#e9b58b"))
        _block(root, "Leg_Blue", Vector3(side * 0.23, 0.92, 0), Vector3(0.37, 0.76, 0.43), Color("#0756a7"))
        _block(root, "Boot", Vector3(side * 0.23, 0.38, 0.07), Vector3(0.4, 0.25, 0.53), Color("#343b43"))

    # Backpack: body, lid, straps and two small side pockets.
    _block(root, "Backpack_Main", Vector3(0, 2.06, -0.36), Vector3(0.62, 0.78, 0.3), Color("#8a542e"))
    _block(root, "Backpack_Lid", Vector3(0, 2.43, -0.38), Vector3(0.67, 0.16, 0.34), Color("#b8783d"))
    _block(root, "Backpack_Pocket", Vector3(0, 1.91, -0.54), Vector3(0.36, 0.29, 0.12), Color("#6c3d25"))
    for strap_x in [-0.29, 0.29]:
        _block(root, "Backpack_Strap", Vector3(strap_x, 2.12, 0.25), Vector3(0.09, 0.72, 0.06), Color("#8a542e"))

    # A readable cyan diamond pickaxe held at the character's right side.
    var tool := Node3D.new()
    tool.name = "DiamondPickaxe"
    tool.position = Vector3(0.88, 1.68, 0.12)
    tool.rotation_degrees.z = -18.0
    root.add_child(tool)
    _block(tool, "Wood_Handle", Vector3(0, -0.18, 0), Vector3(0.13, 1.02, 0.14), Color("#81502e"))
    _block(tool, "Handle_Band", Vector3(0, 0.12, 0.01), Vector3(0.15, 0.12, 0.16), Color("#d1a05a"))
    _block(tool, "Diamond_Head_Left", Vector3(-0.28, 0.43, 0), Vector3(0.48, 0.18, 0.2), Color("#16c9c8"), 0.25, 0.12)
    _block(tool, "Diamond_Head_Right", Vector3(0.28, 0.43, 0), Vector3(0.48, 0.18, 0.2), Color("#16c9c8"), 0.25, 0.12)
    _block(tool, "Diamond_Tip_Left", Vector3(-0.49, 0.32, 0), Vector3(0.14, 0.22, 0.2), Color("#76f5ee"), 0.22, 0.1)
    _block(tool, "Diamond_Tip_Right", Vector3(0.49, 0.32, 0), Vector3(0.14, 0.22, 0.2), Color("#76f5ee"), 0.22, 0.1)


func _build_castle_gatehouse(origin: Vector3) -> void:
    var root := Node3D.new()
    root.name = "ReferenceCastleGatehouse"
    root.position = origin
    add_child(root)
    var stone := Color("#777c78")
    var stone_light := Color("#a5a49a")
    var mortar := Color("#4f5757")
    var roof := Color("#5e5147")

    # Two solid towers frame a real walk-through arch; no flat front-face decal.
    _block(root, "Left_Tower", Vector3(-1.0, 1.35, 0), Vector3(0.72, 2.7, 0.92), stone)
    _block(root, "Right_Tower", Vector3(1.0, 1.35, 0), Vector3(0.72, 2.7, 0.92), stone)
    _block(root, "Gate_Lintel", Vector3(0, 2.47, 0), Vector3(1.45, 0.48, 0.92), stone_light)
    _block(root, "Gate_Threshold", Vector3(0, 0.12, 0), Vector3(1.38, 0.24, 1.02), stone_light)
    for side in [-1.0, 1.0]:
        _block(root, "Tower_Roof_Band", Vector3(side, 2.82, 0), Vector3(0.86, 0.22, 1.04), roof)
        for crenel in range(3):
            _block(root, "Tower_Crenellation", Vector3(side + (float(crenel) - 1.0) * 0.25, 3.06, 0), Vector3(0.18, 0.28, 0.94), stone_light)
        _block(root, "Tower_Window_Recess", Vector3(side, 1.92, 0.476), Vector3(0.18, 0.42, 0.035), mortar)
        _block(root, "Tower_Window_Glow", Vector3(side, 1.92, 0.5), Vector3(0.075, 0.28, 0.025), Color("#f4cf7c"))
    # Layered brick seams on front and side faces to avoid a smooth monolith.
    for y in range(5):
        var yy := 0.32 + float(y) * 0.46
        for side in [-1.0, 1.0]:
            _block(root, "Front_Mortar_Line", Vector3(side, yy, 0.472), Vector3(0.69, 0.035, 0.025), mortar)
            _block(root, "Front_Stone_Block", Vector3(side + (0.18 if y % 2 == 0 else -0.18), yy + 0.19, 0.49), Vector3(0.28, 0.32, 0.055), stone_light if y % 3 == 0 else stone)
    _block(root, "Back_Wall", Vector3(0, 1.38, -0.42), Vector3(2.75, 2.76, 0.12), stone)
    # Wall walk and crenellated parapet extend the gatehouse into a fortification.
    _block(root, "Wall_Left", Vector3(-2.05, 1.0, -0.05), Vector3(1.45, 2.0, 0.7), stone)
    _block(root, "Wall_Right", Vector3(2.05, 1.0, -0.05), Vector3(1.45, 2.0, 0.7), stone)
    for side in [-1.0, 1.0]:
        for i in range(4):
            _block(root, "Wall_Crenellation", Vector3(side * (1.65 + float(i) * 0.31), 2.15, -0.05), Vector3(0.22, 0.28, 0.75), stone_light)


func _build_still_water_cube(origin: Vector3) -> void:
    var root := Node3D.new()
    root.name = "ReferenceStillWaterCube"
    root.position = origin + Vector3(0, 1.05, 0)
    add_child(root)

    # A full voxel silhouette with a translucent blue body and a separate top layer.
    var water_body := _block(root, "Water_Volume", Vector3(0, 0, 0), Vector3(1.55, 1.55, 1.55), Color(0.08, 0.38, 0.82, 0.72), 0.16, 0.08)
    water_body.material_override = _mat(Color(0.08, 0.38, 0.82, 0.72), 0.16, 0.08, true)
    var top := _block(root, "Water_Surface", Vector3(0, 0.79, 0), Vector3(1.48, 0.055, 1.48), Color("#7adfff"), 0.18, 0.08)
    top.material_override = _mat(Color(0.22, 0.72, 0.96, 0.76), 0.18, 0.08, true)
    # Two bright internal planes suggest refraction and depth while staying cheap.
    var glint := _block(root, "Water_Glint", Vector3(-0.22, 0.81, 0.08), Vector3(0.68, 0.025, 0.11), Color("#d7f7ff"), 0.12, 0.05)
    glint.material_override = _mat(Color(0.78, 0.96, 1.0, 0.82), 0.12, 0.05, true)
    _block(root, "Water_Edge_Left", Vector3(-0.79, 0, 0), Vector3(0.035, 1.5, 1.5), Color("#5dbcf0"), 0.22, 0.1)
    _block(root, "Water_Edge_Right", Vector3(0.79, 0, 0), Vector3(0.035, 1.5, 1.5), Color("#2b72c6"), 0.22, 0.1)
