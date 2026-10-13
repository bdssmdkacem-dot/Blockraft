extends Node3D
## Blockraft menu 3D panorama — improved to match the official title-screen
## reference (golden-hour valley, river, waterfalls, village, gatehouse castle,
## floating islands, and a voxel protagonist with diamond pickaxe).

const MAT_GRASS := Color("#438b49")
const MAT_GRASS_LIGHT := Color("#70b956")
const MAT_DIRT := Color("#79513a")
const MAT_STONE := Color("#687b80")
const MAT_STONE_LIGHT := Color("#9eafa8")
const MAT_STONE_CASTLE := Color("#8a9590")
const MAT_WOOD := Color("#70472f")
const MAT_LEAF_DARK := Color("#276747")
const MAT_LEAF := Color("#3d8a4b")
const MAT_LEAF_LIGHT := Color("#65b85a")
const MAT_ROOF := Color("#a65f42")
const MAT_WALL := Color("#e4c98e")
const MAT_WATER := Color("#48b9d1")
const MAT_SKIN := Color("#e8b896")
const MAT_TEAL := Color("#2ec4b6")
const MAT_BLUE_PANTS := Color("#3a5f9a")
const MAT_DIAMOND := Color("#5ce1e6")
const MAT_BROWN_PACK := Color("#8b5a2b")

func _ready() -> void:
	_setup_environment()
	_setup_lighting()
	_setup_camera()
	_build_landscape()
	_build_horizon_layers()
	_build_river_and_bridge()
	_build_village()
	_build_forests()
	_build_floating_islands()
	_build_gatehouse_castle()
	_build_landmark_details()
	_build_protagonist()

func _material(color: Color, roughness: float = 0.88, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _emissive(color: Color, energy: float = 1.2) -> StandardMaterial3D:
	var m := _material(color, 0.35, 0.0)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

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
	sky_material.sky_top_color = Color("#183b70")
	sky_material.sky_horizon_color = Color("#f7b36b")
	sky_material.ground_bottom_color = Color("#253d43")
	sky_material.ground_horizon_color = Color("#e7a06b")
	sky_material.sun_angle_max = 18.0
	sky_material.energy_multiplier = 1.15
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#a8c8d8")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.18
	environment.fog_enabled = true
	environment.fog_light_color = Color("#c8a878")
	environment.fog_density = 0.0012
	environment.fog_aerial_perspective = 0.35
	world.environment = environment
	add_child(world)

func _setup_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "GoldenHourSun"
	sun.rotation_degrees = Vector3(-32.0, -42.0, 0.0)
	sun.light_color = Color("#ffd089")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "CoolSkyFill"
	fill.rotation_degrees = Vector3(-15.0, 150.0, 0.0)
	fill.light_color = Color("#9ed4f0")
	fill.light_energy = 0.22
	fill.shadow_enabled = false
	add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.name = "SunsetRim"
	rim.rotation_degrees = Vector3(-8.0, 80.0, 0.0)
	rim.light_color = Color("#ffb060")
	rim.light_energy = 0.18
	rim.shadow_enabled = false
	add_child(rim)

func _setup_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "MenuWorldCamera"
	camera.position = Vector3(0.0, 10.5, 31.0)
	camera.fov = 60.0
	camera.near = 0.1
	camera.far = 180.0
	add_child(camera)
	camera.look_at(Vector3(0.0, -10.0, -5.0), Vector3.UP)
	camera.make_current()

func _build_landscape() -> void:
	_box(self, Vector3(0.0, -1.2, -4.0), Vector3(48.0, 2.0, 38.0), MAT_DIRT)
	_box(self, Vector3(0.0, -0.15, -5.0), Vector3(48.0, 0.34, 34.0), MAT_GRASS)
	for i in range(12):
		var x := -28.0 + float(i) * 5.0
		var peak := 1.9 + float((i * 7) % 5) * 0.42
		var z := -36.0 - float((i * 3) % 4) * 1.8
		var lower_height := peak * 0.58
		var upper_height := peak - lower_height
		var width := 3.4 if i % 3 == 1 else 3.9
		_box(self, Vector3(x, lower_height * 0.5 - 0.1, z), Vector3(width, lower_height, 3.8), MAT_STONE)
		_box(self, Vector3(x + 0.2, lower_height + upper_height * 0.5 - 0.05, z), Vector3(width * 0.7, upper_height, 2.9), MAT_STONE)
		_box(self, Vector3(x - 0.1, peak + 0.16, z), Vector3(width * 0.82, 0.34, 3.1), MAT_GRASS_LIGHT if i % 3 == 0 else MAT_GRASS)

func _build_horizon_layers() -> void:
	# Break the former continuous wall of oversized rectangular mountains into
	# layered, irregular silhouettes. Keep them distant so the village and castle
	# remain the focal points instead of being hidden behind a grey block wall.
	for i in range(23):
		var x := -42.0 + float(i) * 3.8
		var h := 3.8 + float((i * 13) % 7) * 0.72
		var z := -54.0 - float((i * 5) % 4) * 2.1
		var width := 3.0 + float(i % 3) * 0.42
		var depth := 3.4 + float((i + 1) % 3) * 0.55
		var shade := Color("#4a6578") if i % 3 == 0 else (Color("#526c7b") if i % 3 == 1 else Color("#5c7180"))
		_box(self, Vector3(x, h * 0.36, z), Vector3(width, h * 0.72, depth), shade)
		# Small offset upper mass creates a broken peak line rather than a flat top.
		var crown_h := h * (0.20 if i % 4 == 0 else 0.13)
		_box(self, Vector3(x + width * 0.12, h * 0.72 + crown_h * 0.5, z - 0.15), Vector3(width * 0.56, crown_h, depth * 0.72), shade.lightened(0.08))

func _build_river_and_bridge() -> void:
	var water_material := _material(MAT_WATER, 0.18, 0.15)
	for i in range(14):
		var z := 6.5 - float(i) * 2.4
		var x := 1.8 - sin(float(i) * 0.55) * 2.2
		var water := _box(self, Vector3(x, 0.03, z), Vector3(9.5, 0.16, 3.6), MAT_WATER, 0.18)
		water.material_override = water_material
	for i in range(8):
		var x := 2.8 + float(i) * 0.85
		_box(self, Vector3(x, 0.38, -0.8), Vector3(0.95, 0.48, 2.5), MAT_STONE_LIGHT)

func _build_village() -> void:
	_house(Vector3(-5.0, 0.0, -4.5), Vector3(3.4, 2.8, 3.1), MAT_WALL, MAT_ROOF)
	_house(Vector3(-0.5, 0.0, -6.5), Vector3(2.8, 2.3, 2.7), Color("#d4dfc0"), Color("#7d5949"))
	_house(Vector3(5.5, 0.0, -6.2), Vector3(3.1, 2.5, 2.9), Color("#d7bd8d"), Color("#98583f"))
	_house(Vector3(-9.5, 0.0, -7.5), Vector3(2.9, 2.4, 2.9), Color("#c6d7d2"), Color("#6f5142"))

func _house(origin: Vector3, dimensions: Vector3, wall_color: Color, roof_color: Color) -> void:
	_box(self, origin + Vector3(0.0, dimensions.y * 0.5, 0.0), dimensions, wall_color)
	_box(self, origin + Vector3(0.0, dimensions.y + 0.28, 0.0), Vector3(dimensions.x + 0.7, 0.5, dimensions.z + 0.7), roof_color)
	_box(self, origin + Vector3(0.0, 0.75, dimensions.z * 0.5 + 0.04), Vector3(0.5, 1.4, 0.12), MAT_WOOD)

func _build_forests() -> void:
	for i in range(20):
		var x := -20.0 + float((i * 11) % 40)
		var z := -1.5 - float((i * 7) % 14)
		if absf(x) < 6.0 and z > -9.0:
			continue
		_tree(Vector3(x, 0.0, z), 0.75 + float(i % 4) * 0.18)
	_tree(Vector3(-14.0, 0.0, 3.5), 1.6)
	_tree(Vector3(14.5, 0.0, 2.8), 1.55)

func _tree(origin: Vector3, scale: float) -> void:
	_box(self, origin + Vector3(0.0, 1.15 * scale, 0.0), Vector3(0.6, 2.3, 0.6) * scale, MAT_WOOD)
	_box(self, origin + Vector3(0.0, 2.6 * scale, 0.0), Vector3(2.3, 1.3, 2.15) * scale, MAT_LEAF_DARK)
	_box(self, origin + Vector3(0.0, 3.5 * scale, 0.0), Vector3(1.6, 1.1, 1.6) * scale, MAT_LEAF)

func _build_floating_islands() -> void:
	# Three distinct silhouettes across the upper panorama; keep their scale
	# modest enough that none is clipped by the 16:9 menu camera.
	_create_floating_island("FloatingIsland_Left", Vector3(-15.0, 7.0, -22.0), Vector3(4.6, 2.8, 3.4))
	_create_floating_island("FloatingIsland", Vector3(1.0, 7.8, -28.0), Vector3(4.8, 3.0, 3.6))
	_create_floating_island("FloatingIsland_Right", Vector3(15.0, 7.2, -22.0), Vector3(4.8, 3.0, 3.5))

func _create_floating_island(island_name: String, origin: Vector3, dimensions: Vector3) -> void:
	var island := Node3D.new()
	island.name = island_name
	island.position = origin
	add_child(island)
	_box(island, Vector3(0.0, 0.0, 0.0), dimensions, MAT_GRASS)
	_box(island, Vector3(0.0, -0.72, 0.0), dimensions * Vector3(0.82, 0.72, 0.82), MAT_DIRT)
	_box(island, Vector3(-0.16, -1.45, 0.0), dimensions * Vector3(0.56, 0.66, 0.58), MAT_STONE)
	# Hanging rock points break up the otherwise flat underside.
	for i in range(3):
		var dx := (float(i) - 1.0) * dimensions.x * 0.22
		_box(island, Vector3(dx, -2.08 - float(i % 2) * 0.18, 0.12), Vector3(0.62, 1.0, 0.7), MAT_STONE)

func _build_gatehouse_castle() -> void:
	var root := Node3D.new()
	root.name = "GatehouseCastle"
	# Pull the landmark into the camera's readable midground instead of letting
	# the village roofs and distant silhouettes swallow it at the right edge.
	root.position = Vector3(8.0, 0.0, -12.5)
	add_child(root)
	_box(root, Vector3(0.0, 2.4, 0.0), Vector3(5.8, 4.8, 3.6), MAT_STONE_CASTLE)
	_box(root, Vector3(0.0, 1.4, 1.85), Vector3(1.9, 2.8, 0.28), Color("#5a6560"))
	for side in [-1.0, 1.0]:
		_box(root, Vector3(side * 3.25, 3.5, 0.1), Vector3(1.7, 7.0, 2.3), MAT_STONE_CASTLE)
		_box(root, Vector3(side * 3.25, 7.15, 0.1), Vector3(2.0, 0.3, 2.6), MAT_STONE_LIGHT)
		for crenel in range(3):
			_box(root, Vector3(side * 3.25 + (float(crenel) - 1.0) * 0.48, 7.48, 0.1), Vector3(0.3, 0.36, 2.25), MAT_STONE_LIGHT)
	# Warm windows and stone courses add scale cues to the main keep.
	for side in [-1.0, 1.0]:
		for level in range(2):
			var wy := 2.0 + float(level) * 1.45
			_box(root, Vector3(side * 1.65, wy, 1.84), Vector3(0.26, 0.48, 0.06), Color("#414f50"))
			var window := _box(root, Vector3(side * 1.65, wy, 1.89), Vector3(0.12, 0.31, 0.035), Color("#ffd27b"), 0.3)
			window.material_override = _emissive(Color("#ffca70"), 1.25)
	for row in range(5):
		var yy := 0.7 + float(row) * 0.82
		_box(root, Vector3(0.0, yy, 1.82), Vector3(5.6, 0.045, 0.04), Color("#65716e"))

func _build_landmark_details() -> void:
	for lamp in [{"x": -7.5, "z": -2.8}, {"x": -2.0, "z": -3.6}, {"x": 4.0, "z": -3.0}]:
		var lx: float = lamp["x"]
		var lz: float = lamp["z"]
		_box(self, Vector3(lx, 1.05, lz), Vector3(0.12, 2.1, 0.12), MAT_WOOD)
		var glow := _box(self, Vector3(lx, 1.72, lz), Vector3(0.32, 0.38, 0.32), Color("#ffca6b"), 0.28)
		glow.material_override = _emissive(Color("#ffb84d"), 1.6)

func _build_protagonist() -> void:
	var char := Node3D.new()
	char.name = "Protagonist"
	char.position = Vector3(-6.5, 0.0, 6.5)
	char.scale = Vector3(1.15, 1.15, 1.15)
	add_child(char)
	_box(char, Vector3(-0.22, 0.45, 0.0), Vector3(0.38, 0.9, 0.35), MAT_BLUE_PANTS)
	_box(char, Vector3(0.22, 0.45, 0.0), Vector3(0.38, 0.9, 0.35), MAT_BLUE_PANTS)
	_box(char, Vector3(0.0, 1.25, 0.0), Vector3(0.95, 0.95, 0.5), MAT_TEAL)
	_box(char, Vector3(0.0, 2.05, 0.0), Vector3(0.7, 0.7, 0.65), MAT_SKIN)
	_box(char, Vector3(0.0, 1.3, -0.4), Vector3(0.75, 0.8, 0.35), MAT_BROWN_PACK)
