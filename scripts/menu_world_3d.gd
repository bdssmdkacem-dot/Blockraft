extends Node3D
## A real-time 3D voxel panorama used behind the main-menu interface.
## Geometry is deliberately assembled in 3D, with depth, perspective, shadows,
## material response and atmospheric lighting rather than CanvasItem polygons.

const MAT_GRASS := Color("#5baf57")
const MAT_GRASS_LIGHT := Color("#86cf65")
const MAT_DIRT := Color("#79513a")
const MAT_STONE := Color("#87979a")
const MAT_STONE_LIGHT := Color("#c2c7b5")
const MAT_WOOD := Color("#70472f")
const MAT_LEAF_DARK := Color("#276747")
const MAT_LEAF := Color("#3d8a4b")
const MAT_LEAF_LIGHT := Color("#65b85a")
const MAT_ROOF := Color("#a65f42")
const MAT_WALL := Color("#e4c98e")
const MAT_WATER := Color("#48b9d1")

func _ready() -> void:
    _setup_environment()
    _setup_lighting()
    _setup_camera()
    _build_landscape()
    _build_river_and_bridge()
    _build_village()
    _build_forests()
    _build_floating_island()

func _material(color: Color, roughness: float = 0.88, metallic: float = 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    return material

func _box(parent: Node3D, position: Vector3, dimensions: Vector3, color: Color, roughness: float = 0.88) -> MeshInstance3D:
    var block := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    block.mesh = mesh
    block.position = position
    block.material_override = _material(color, roughness)
    block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    parent.add_child(block)
    return block

func _setup_environment() -> void:
    var world := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color("#438dc5")
    sky_material.sky_horizon_color = Color("#f7b66e")
    sky_material.ground_bottom_color = Color("#263b35")
    sky_material.ground_horizon_color = Color("#e8ad70")
    sky_material.sun_angle_max = 18.0
    sky.sky_material = sky_material
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#b4c8d5")
    environment.ambient_light_energy = 0.48
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.tonemap_exposure = 1.0
    environment.glow_enabled = true
    environment.glow_intensity = 0.12
    environment.fog_enabled = true
    environment.fog_light_color = Color("#e2c4a0")
    environment.fog_density = 0.003
    world.environment = environment
    add_child(world)

func _setup_lighting() -> void:
    var sun := DirectionalLight3D.new()
    sun.name = "GoldenHourSun"
    sun.rotation_degrees = Vector3(-37.0, -28.0, 0.0)
    sun.light_color = Color("#ffe0a3")
    sun.light_energy = 1.45
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 90.0
    add_child(sun)

    var fill := DirectionalLight3D.new()
    fill.name = "CoolSkyFill"
    fill.rotation_degrees = Vector3(-18.0, 145.0, 0.0)
    fill.light_color = Color("#a6d9f0")
    fill.light_energy = 0.42
    fill.shadow_enabled = false
    add_child(fill)

func _setup_camera() -> void:
    var camera := Camera3D.new()
    camera.name = "MenuWorldCamera"
    camera.position = Vector3(0.0, 16.0, 30.0)
    camera.fov = 58.0
    camera.near = 0.1
    camera.far = 180.0
    # look_at() must run after the camera enters the SceneTree; otherwise the
    # transform can remain at the default horizontal orientation and the
    # SubViewport shows only sky instead of the voxel landscape.
    add_child(camera)
    camera.look_at(Vector3(0.0, 2.6, -7.0), Vector3.UP)
    camera.make_current()

func _build_landscape() -> void:
    # Layered block terrain creates a readable foreground, mid-ground and horizon.
    _box(self, Vector3(0.0, -1.2, -4.0), Vector3(42.0, 2.0, 34.0), MAT_DIRT)
    _box(self, Vector3(0.0, -0.15, -5.0), Vector3(42.0, 0.34, 31.0), MAT_GRASS)

    for i in range(11):
        var x := -24.0 + float(i) * 4.8
        var peak := 5.0 + float((i * 7) % 5) * 1.15
        var z := -19.0 - float((i * 3) % 4) * 1.6
        _box(self, Vector3(x, peak * 0.5 - 0.1, z), Vector3(5.4, peak, 5.2), MAT_STONE)
        _box(self, Vector3(x - 0.5, peak + 0.15, z), Vector3(4.4, 0.45, 4.4), MAT_GRASS_LIGHT if i % 3 == 0 else MAT_GRASS)
        if i % 2 == 0:
            _box(self, Vector3(x + 0.6, peak + 0.75, z - 0.2), Vector3(2.2, 1.0, 2.0), MAT_STONE_LIGHT)

    # Distant keep silhouette, placed above the right side of the village.
    _box(self, Vector3(12.0, 4.0, -14.5), Vector3(4.0, 8.5, 3.2), MAT_STONE_LIGHT)
    _box(self, Vector3(12.0, 8.5, -14.5), Vector3(4.8, 0.65, 3.8), MAT_ROOF)
    _box(self, Vector3(12.0, 9.4, -14.5), Vector3(2.0, 1.8, 2.0), MAT_STONE_LIGHT)
    _box(self, Vector3(12.0, 10.6, -14.5), Vector3(2.4, 0.45, 2.4), MAT_ROOF)
    for dx in [-1.8, 1.8]:
        _box(self, Vector3(12.0 + dx, 8.0, -14.5), Vector3(0.8, 2.4, 0.8), MAT_STONE_LIGHT)
        _box(self, Vector3(12.0 + dx, 9.4, -14.5), Vector3(1.0, 0.3, 1.0), MAT_ROOF)

func _build_river_and_bridge() -> void:
    # Broad segmented water ribbon catches the sun through low-roughness material.
    var water_material := _material(MAT_WATER, 0.22, 0.12)
    for i in range(11):
        var z := 8.0 - float(i) * 2.6
        var x := 2.4 - sin(float(i) * 0.58) * 3.0
        var water := _box(self, Vector3(x, -0.02, z), Vector3(6.2, 0.12, 3.6), MAT_WATER, 0.22)
        water.material_override = water_material
    # Stone crossing with chunky parapets and visible depth.
    for i in range(7):
        var x := 3.2 + float(i) * 0.8
        _box(self, Vector3(x, 0.35, -1.4), Vector3(0.9, 0.45, 2.3), MAT_STONE_LIGHT)
    _box(self, Vector3(5.6, 0.7, -2.25), Vector3(6.2, 0.28, 0.22), MAT_STONE)
    _box(self, Vector3(5.6, 0.7, -0.55), Vector3(6.2, 0.28, 0.22), MAT_STONE)

func _build_village() -> void:
    _house(Vector3(-4.5, 0.0, -5.0), Vector3(3.3, 2.7, 3.0), MAT_WALL, MAT_ROOF)
    _house(Vector3(0.2, 0.0, -7.0), Vector3(2.7, 2.2, 2.6), Color("#d4dfc0"), Color("#7d5949"))
    _house(Vector3(6.7, 0.0, -7.0), Vector3(3.0, 2.4, 2.8), Color("#d7bd8d"), Color("#98583f"))
    _house(Vector3(-9.0, 0.0, -8.0), Vector3(2.8, 2.3, 2.8), Color("#c6d7d2"), Color("#6f5142"))

func _house(origin: Vector3, dimensions: Vector3, wall_color: Color, roof_color: Color) -> void:
    _box(self, origin + Vector3(0.0, dimensions.y * 0.5, 0.0), dimensions, wall_color)
    _box(self, origin + Vector3(0.0, dimensions.y + 0.28, 0.0), Vector3(dimensions.x + 0.65, 0.48, dimensions.z + 0.65), roof_color)
    _box(self, origin + Vector3(0.0, dimensions.y + 0.65, 0.0), Vector3(dimensions.x * 0.78, 0.42, dimensions.z * 0.78), roof_color.darkened(0.12))
    _box(self, origin + Vector3(0.0, 0.72, dimensions.z * 0.5 + 0.035), Vector3(0.48, 1.35, 0.12), MAT_WOOD)
    for wx in [-0.72, 0.72]:
        _box(self, origin + Vector3(wx, dimensions.y * 0.62, dimensions.z * 0.5 + 0.08), Vector3(0.38, 0.46, 0.1), Color("#ffd78a"), 0.32)

func _build_forests() -> void:
    for i in range(17):
        var x := -18.0 + float((i * 11) % 35)
        var z := -2.0 - float((i * 7) % 13)
        if absf(x) < 5.0 and z > -8.5:
            continue
        var scale := 0.78 + float(i % 4) * 0.17
        _tree(Vector3(x, 0.0, z), scale)

    # A few foreground trees frame the screen without obscuring the UI.
    _tree(Vector3(-17.0, 0.0, 4.0), 1.45)
    _tree(Vector3(17.0, 0.0, 2.5), 1.35)

func _tree(origin: Vector3, scale: float) -> void:
    _box(self, origin + Vector3(0.0, 1.15 * scale, 0.0), Vector3(0.62, 2.3, 0.62) * scale, MAT_WOOD)
    _box(self, origin + Vector3(0.0, 2.6 * scale, 0.0), Vector3(2.25, 1.25, 2.1) * scale, MAT_LEAF_DARK)
    _box(self, origin + Vector3(-0.22 * scale, 3.35 * scale, -0.08 * scale), Vector3(1.8, 1.2, 1.8) * scale, MAT_LEAF)
    _box(self, origin + Vector3(0.16 * scale, 3.9 * scale, -0.12 * scale), Vector3(1.15, 0.8, 1.2) * scale, MAT_LEAF_LIGHT)

func _build_floating_island() -> void:
    var island := Node3D.new()
    island.name = "FloatingIsland"
    island.position = Vector3(13.5, 12.0, -15.0)
    add_child(island)
    _box(island, Vector3(0.0, 0.0, 0.0), Vector3(8.2, 1.0, 5.0), MAT_GRASS)
    _box(island, Vector3(0.0, -0.8, 0.0), Vector3(6.8, 0.8, 4.0), MAT_DIRT)
    _box(island, Vector3(-0.3, -1.65, 0.0), Vector3(4.7, 0.9, 2.8), MAT_STONE)
    _box(island, Vector3(0.2, -2.4, 0.0), Vector3(2.4, 0.7, 1.6), MAT_STONE)
    for i in range(3):
        _box(island, Vector3(-2.0 + float(i) * 1.9, 0.75, -0.6), Vector3(0.75, 1.2 + float(i % 2) * 0.7, 0.75), MAT_STONE_LIGHT)
    _box(island, Vector3(-2.0, -1.9, 1.1), Vector3(0.16, 2.8, 0.16), Color("#7dd6e9"), 0.2)
    _box(island, Vector3(-1.8, -2.1, 1.1), Vector3(0.12, 1.9, 0.12), Color("#b5eff4"), 0.2)
    # A smaller distant island gives the skyline the layered fantasy silhouette
    # shown in the approved concept instead of a single floating block.
    var distant := Node3D.new()
    distant.name = "DistantFloatingIsland"
    distant.position = Vector3(-12.5, 12.8, -20.0)
    distant.scale = Vector3(0.62, 0.62, 0.62)
    add_child(distant)
    _box(distant, Vector3.ZERO, Vector3(5.8, 0.7, 3.8), MAT_GRASS_LIGHT)
    _box(distant, Vector3(0.0, -0.6, 0.0), Vector3(4.6, 0.8, 3.0), MAT_DIRT)
    _box(distant, Vector3(0.0, -1.3, 0.0), Vector3(2.6, 0.7, 2.0), MAT_STONE)
    _box(distant, Vector3(0.0, 0.65, 0.0), Vector3(0.8, 1.3, 0.8), MAT_STONE_LIGHT)
    _box(distant, Vector3(0.0, 1.45, 0.0), Vector3(1.0, 0.35, 1.0), MAT_ROOF)
