extends Node3D
## A real-time 3D voxel panorama used behind the main-menu interface.
## Geometry is deliberately assembled in 3D, with depth, perspective, shadows,
## material response and atmospheric lighting rather than CanvasItem polygons.

const MAT_GRASS := Color("#438b49")
const MAT_GRASS_LIGHT := Color("#70b956")
const MAT_DIRT := Color("#79513a")
const MAT_STONE := Color("#687b80")
const MAT_STONE_LIGHT := Color("#9eafa8")
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
    _build_horizon_layers()
    _build_river_and_bridge()
    _build_village()
    _build_forests()
    _build_floating_island()
    _build_landmark_details()

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
    # A deeper blue overhead and a warmer horizon make the valley read as
    # golden-hour scenery instead of a flat, overexposed cyan backdrop.
    sky_material.sky_top_color = Color("#1e5688")
    sky_material.sky_horizon_color = Color("#e9a86a")
    sky_material.ground_bottom_color = Color("#1a2b2a")
    sky_material.ground_horizon_color = Color("#bb8d69")
    sky_material.sun_angle_max = 18.0
    sky.sky_material = sky_material
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#91b6ca")
    environment.ambient_light_energy = 0.22
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.tonemap_exposure = 0.78
    environment.glow_enabled = true
    environment.glow_intensity = 0.12
    environment.fog_enabled = true
    environment.fog_light_color = Color("#7fabbf")
    environment.fog_density = 0.00055
    world.environment = environment
    add_child(world)

func _setup_lighting() -> void:
    var sun := DirectionalLight3D.new()
    sun.name = "GoldenHourSun"
    sun.rotation_degrees = Vector3(-37.0, -28.0, 0.0)
    sun.light_color = Color("#ffe0a3")
    sun.light_energy = 0.95
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 90.0
    add_child(sun)

    var fill := DirectionalLight3D.new()
    fill.name = "CoolSkyFill"
    fill.rotation_degrees = Vector3(-18.0, 145.0, 0.0)
    fill.light_color = Color("#a6d9f0")
    fill.light_energy = 0.16
    fill.shadow_enabled = false
    add_child(fill)

func _setup_camera() -> void:
    var camera := Camera3D.new()
    camera.name = "MenuWorldCamera"
    camera.position = Vector3(0.0, 10.5, 31.0)
    camera.fov = 60.0
    camera.near = 0.1
    camera.far = 180.0
    # Compose the valley for a wide menu backdrop: a lower camera and a
    # stronger downward pitch bring the river, village roofs and terrain into
    # the visible center instead of leaving a large empty sky above the cards.
    # Add the camera before orienting it; look_at requires SceneTree membership.
    add_child(camera)
    camera.look_at(Vector3(0.0, -10.0, -5.0), Vector3.UP)
    camera.make_current()

func _build_landscape() -> void:
    # Layered block terrain creates a readable foreground, mid-ground and horizon.
    _box(self, Vector3(0.0, -1.2, -4.0), Vector3(42.0, 2.0, 34.0), MAT_DIRT)
    _box(self, Vector3(0.0, -0.15, -5.0), Vector3(42.0, 0.34, 31.0), MAT_GRASS)

    # Separate the ridge into stepped peaks with gaps, so the scene reads as a
    # valley rather than one continuous wall of oversized blocks.
    for i in range(11):
        var x := -25.0 + float(i) * 5.0
        # Keep the skyline low and staggered. Tall, tightly packed blocks
        # read as a wall in the menu camera and hide the valley landmarks.
        var peak := 1.75 + float((i * 7) % 5) * 0.38
        var z := -35.0 - float((i * 3) % 4) * 1.7
        var lower_height := peak * 0.62
        var upper_height := peak - lower_height
        var width := 3.25 if i % 3 == 1 else 3.7
        _box(self, Vector3(x, lower_height * 0.5 - 0.1, z), Vector3(width, lower_height, 3.7), MAT_STONE)
        _box(self, Vector3(x + 0.18, lower_height + upper_height * 0.5 - 0.05, z), Vector3(width * 0.72, upper_height, 2.8), MAT_STONE)
        _box(self, Vector3(x - 0.1, peak + 0.16, z), Vector3(width * 0.84, 0.34, 3.0), MAT_GRASS_LIGHT if i % 3 == 0 else MAT_GRASS)
        if i % 3 == 0:
            _box(self, Vector3(x + 0.5, peak + 0.38, z - 0.2), Vector3(0.9, 0.18, 0.95), Color("#899995"))

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
        var z := 5.0 - float(i) * 2.5
        var x := 2.4 - sin(float(i) * 0.58) * 1.8
        var water := _box(self, Vector3(x, 0.04, z), Vector3(8.0, 0.18, 3.8), MAT_WATER, 0.22)
        water.material_override = water_material

    # Two visible stepped waterfalls connect the elevated valley to the river.
    # Thin layered ribbons avoid a single oversized cyan slab in the panorama.
    var falls_material := _material(Color("#42c5df"), 0.18, 0.08)
    for fall in [
        {"x": 1.0, "y": 2.15, "z": -8.5, "height": 3.8},
        {"x": 7.6, "y": 1.7, "z": -10.0, "height": 3.3}
    ]:
        var fx: float = fall["x"]
        var fy: float = fall["y"]
        var fz: float = fall["z"]
        var fh: float = fall["height"]
        var sheet := _box(self, Vector3(fx, fy, fz), Vector3(0.72, fh, 0.16), Color("#42c5df"), 0.18)
        sheet.material_override = falls_material
        _box(self, Vector3(fx + 0.22, fy - fh * 0.2, fz + 0.1), Vector3(0.18, fh * 0.55, 0.12), Color("#a5f0f4"), 0.2)
        _box(self, Vector3(fx, 0.05, fz + 0.45), Vector3(2.0, 0.08, 1.2), Color("#68d8e8"), 0.2)

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
    _tree(Vector3(-13.0, 0.0, 3.0), 1.55)
    _tree(Vector3(13.0, 0.0, 2.5), 1.5)

func _tree(origin: Vector3, scale: float) -> void:
    _box(self, origin + Vector3(0.0, 1.15 * scale, 0.0), Vector3(0.62, 2.3, 0.62) * scale, MAT_WOOD)
    _box(self, origin + Vector3(0.0, 2.6 * scale, 0.0), Vector3(2.25, 1.25, 2.1) * scale, MAT_LEAF_DARK)
    _box(self, origin + Vector3(-0.22 * scale, 3.35 * scale, -0.08 * scale), Vector3(1.8, 1.2, 1.8) * scale, MAT_LEAF)
    _box(self, origin + Vector3(0.16 * scale, 3.9 * scale, -0.12 * scale), Vector3(1.15, 0.8, 1.2) * scale, MAT_LEAF_LIGHT)

func _build_floating_island() -> void:
    var island := Node3D.new()
    island.name = "FloatingIsland"
    island.position = Vector3(13.5, 9.6, -15.0)
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
    distant.position = Vector3(-12.5, 10.5, -20.0)
    distant.scale = Vector3(0.62, 0.62, 0.62)
    add_child(distant)
    _box(distant, Vector3.ZERO, Vector3(5.8, 0.7, 3.8), MAT_GRASS_LIGHT)
    _box(distant, Vector3(0.0, -0.6, 0.0), Vector3(4.6, 0.8, 3.0), MAT_DIRT)
    _box(distant, Vector3(0.0, -1.3, 0.0), Vector3(2.6, 0.7, 2.0), MAT_STONE)
    _box(distant, Vector3(0.0, 0.65, 0.0), Vector3(0.8, 1.3, 0.8), MAT_STONE_LIGHT)
    _box(distant, Vector3(0.0, 1.45, 0.0), Vector3(1.0, 0.35, 1.0), MAT_ROOF)


func _build_landmark_details() -> void:
    # Break up the silhouette with a readable, layered castle instead of a
    # single stack of large cubes. These details are deliberately placed behind
    # the menu panel and above the feature strip's horizon line.
    var castle_x := 12.0
    var castle_z := -14.5
    var stone_trim := Color("#c0c8bc")
    var window_glow := Color("#ffd98a")
    var roof_shadow := Color("#754238")

    # Main keep: corner buttresses, inset windows and a stepped crown.
    for side_x in [-1.72, 1.72]:
        _box(self, Vector3(castle_x + side_x, 3.6, castle_z + 1.66), Vector3(0.46, 6.4, 0.42), stone_trim)
        for level in range(3):
            _box(self, Vector3(castle_x + side_x, 2.0 + float(level) * 2.0, castle_z + 1.91), Vector3(0.25, 0.72, 0.08), window_glow, 0.34)

    for level in range(4):
        var y := 1.8 + float(level) * 1.65
        _box(self, Vector3(castle_x, y, castle_z + 1.67), Vector3(0.28, 0.82, 0.08), Color("#f5c979"), 0.35)
        _box(self, Vector3(castle_x - 0.68, y, castle_z + 1.67), Vector3(0.18, 0.62, 0.08), Color("#f5c979"), 0.35)
        _box(self, Vector3(castle_x + 0.68, y, castle_z + 1.67), Vector3(0.18, 0.62, 0.08), Color("#f5c979"), 0.35)

    # Four crenellations across the roofline.
    for i in range(5):
        _box(self, Vector3(castle_x - 1.65 + float(i) * 0.82, 8.62, castle_z + 1.5), Vector3(0.42, 0.48, 0.55), stone_trim)

    # Narrow tower turrets with warm roofs create a recognizable skyline.
    for tower in [
        {"x": castle_x - 2.0, "y": 7.2, "z": castle_z - 0.2, "h": 3.6},
        {"x": castle_x + 2.0, "y": 7.5, "z": castle_z - 0.25, "h": 4.2},
        {"x": castle_x, "y": 10.3, "z": castle_z - 0.45, "h": 3.8}
    ]:
        var tx: float = tower["x"]
        var ty: float = tower["y"]
        var tz: float = tower["z"]
        var th: float = tower["h"]
        _box(self, Vector3(tx, ty, tz), Vector3(1.05, th, 1.05), stone_trim)
        _box(self, Vector3(tx, ty + th * 0.5 + 0.24, tz), Vector3(1.38, 0.42, 1.38), roof_shadow)
        _box(self, Vector3(tx, ty + th * 0.5 + 0.72, tz), Vector3(0.82, 0.65, 0.82), MAT_ROOF)
        _box(self, Vector3(tx, ty + th * 0.5 + 1.12, tz), Vector3(0.2, 0.5, 0.2), Color("#f6d78c"), 0.28)
        _box(self, Vector3(tx, ty, tz + 0.55), Vector3(0.18, 0.75, 0.08), window_glow, 0.32)

    # Village lanterns and signposts give the settlement scale and warmth.
    for lamp in [
        {"x": -7.1, "z": -3.1},
        {"x": -1.8, "z": -4.0},
        {"x": 4.4, "z": -3.4},
        {"x": 8.8, "z": -5.1}
    ]:
        var lx: float = lamp["x"]
        var lz: float = lamp["z"]
        _box(self, Vector3(lx, 1.05, lz), Vector3(0.12, 2.1, 0.12), MAT_WOOD)
        _box(self, Vector3(lx, 2.05, lz), Vector3(0.62, 0.16, 0.62), MAT_WOOD)
        var glow := _box(self, Vector3(lx, 1.72, lz), Vector3(0.32, 0.38, 0.32), Color("#ffca6b"), 0.28)
        var glow_material := glow.material_override as StandardMaterial3D
        glow_material.emission_enabled = true
        glow_material.emission = Color("#ffb84d")
        glow_material.emission_energy_multiplier = 1.4

    # Rocky outcrops and grass-topped stepping stones add foreground depth.
    for i in range(13):
        var x := -14.0 + float(i) * 2.3
        var z := 4.2 + float((i * 5) % 4) * 0.45
        var radius := 0.48 + float(i % 3) * 0.18
        _box(self, Vector3(x, 0.14, z), Vector3(radius * 1.8, 0.28, radius * 1.3), MAT_STONE)
        if i % 2 == 0:
            _box(self, Vector3(x + 0.12, 0.31, z - 0.05), Vector3(radius * 1.6, 0.12, radius), MAT_GRASS_LIGHT)

    # A few tiny, high-contrast flower patches make the ground less uniform.
    for flower in [
        {"x": -10.0, "z": 1.0, "c": "#f4d36e"},
        {"x": -7.7, "z": 2.0, "c": "#f3a8a0"},
        {"x": 8.2, "z": 1.2, "c": "#f4d36e"},
        {"x": 10.1, "z": 2.0, "c": "#b8a6f0"}
    ]:
        var fx: float = flower["x"]
        var fz: float = flower["z"]
        var petal_color: Color = Color(flower["c"])
        _box(self, Vector3(fx, 0.34, fz), Vector3(0.16, 0.16, 0.16), petal_color, 0.55)
        _box(self, Vector3(fx, 0.23, fz), Vector3(0.08, 0.22, 0.08), MAT_LEAF_DARK)


func _build_horizon_layers() -> void:
    # Distinct far/mid mountain layers add atmospheric depth behind the valley.
    # Their stepped silhouettes are intentionally irregular, not one flat wall.
    var far_colors := [Color("#526e83"), Color("#5a7585"), Color("#647d88"), Color("#4b687c")]
    for i in range(15):
        var x := -36.0 + float(i) * 5.2
        var h := 4.2 + float((i * 13) % 7) * 0.72
        var z := -48.0 - float((i * 5) % 4) * 1.6
        var color: Color = far_colors[i % far_colors.size()]
        _box(self, Vector3(x, h * 0.42, z), Vector3(5.8, h * 0.84, 5.2), color)
        _box(self, Vector3(x + 0.55, h * 0.84 + 0.42, z - 0.2), Vector3(3.5, 0.84, 4.1), color.lightened(0.12))
        if i % 3 == 0:
            _box(self, Vector3(x + 0.7, h * 0.84 + 0.88, z - 0.32), Vector3(1.35, 0.16, 2.0), Color("#d4d7c8"))

    # Nearer ridgelets and warm rock faces create depth around the waterfall basin.
    for i in range(10):
        var x := -25.0 + float(i) * 5.4
        var h := 2.0 + float((i * 3) % 5) * 0.48
        var z := -28.0 - float(i % 3) * 1.1
        _box(self, Vector3(x, h * 0.5, z), Vector3(4.8, h, 3.8), MAT_STONE)
        _box(self, Vector3(x - 0.2, h + 0.16, z + 0.15), Vector3(3.7, 0.32, 3.1), MAT_GRASS)
        if i % 2 == 0:
            _box(self, Vector3(x + 1.05, h + 0.38, z + 0.2), Vector3(0.7, 0.14, 0.8), Color("#b6b5a2"))

    # Tiny distant pines establish scale along the ridgeline without competing
    # with the foreground trees or obscuring the castle silhouette.
    for i in range(12):
        var x := -23.0 + float(i) * 4.1
        var z := -25.0 - float((i * 7) % 3) * 1.2
        var scale := 0.42 + float(i % 3) * 0.09
        _box(self, Vector3(x, 0.72 * scale, z), Vector3(0.18, 1.44, 0.18) * scale, MAT_WOOD)
        _box(self, Vector3(x, 1.55 * scale, z), Vector3(0.95, 1.0, 0.95) * scale, MAT_LEAF_DARK)
        _box(self, Vector3(x, 2.08 * scale, z), Vector3(0.68, 0.76, 0.68) * scale, MAT_LEAF)
