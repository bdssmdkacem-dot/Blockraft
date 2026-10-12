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
