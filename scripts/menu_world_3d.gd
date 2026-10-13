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
	sky_material.sky_top_color = Color("#1a4a7a")
	sky_material.sky_horizon_color = Color("#f0a85c")
	sky_material.ground_bottom_color = Color("#1a2b2a")
	sky_material.ground_horizon_color = Color("#c8956a")
	sky_material.sun_angle_max = 22.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#a8c8d8")
	environment.ambient_light_energy = 0.28
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.82
	environment.glow_enabled = true
	environment.glow_intensity = 0.18
	environment.fog_enabled = true
	environment.fog_light_color = Color("#c8a878")
	environment.fog_density = 0.0007
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
	camera.position = Vector3(-1.5, 8.8, 26.0)
	camera.fov = 58.0
	camera.near = 0.1
	camera.far = 200.0
	add_child(camera)
	camera.look_at(Vector3(2.0, 1.5, -8.0), Vector3.UP)
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
		if i % 3 == 0:
			_box(self, Vector3(x + 0.4, peak + 0.55, z - 0.2), Vector3(1.1, 0.18, 1.4), Color("#d4d7c8"))
	_box(self, Vector3(10.0, 0.4, -12.0), Vector3(14.0, 0.9, 8.0), MAT_STONE)
	_box(self, Vector3(10.0, 0.95, -12.0), Vector3(13.2, 0.28, 7.4), MAT_GRASS)
	_box(self, Vector3(-6.0, 0.25, -9.0), Vector3(10.0, 0.6, 6.0), MAT_DIRT)
	_box(self, Vector3(-6.0, 0.6, -9.0), Vector3(9.5, 0.22, 5.6), MAT_GRASS)

func _build_horizon_layers() -> void:
	var far_colors := [Color("#4a6578"), Color("#556e80"), Color("#5f7888"), Color("#445f72")]
	for i in range(16):
		var x := -40.0 + float(i) * 5.4
		var h := 5.0 + float((i * 13) % 8) * 0.85
		var z := -52.0 - float((i * 5) % 4) * 1.8
		var color: Color = far_colors[i % far_colors.size()]
		_box(self, Vector3(x, h * 0.42, z), Vector3(6.2, h * 0.84, 5.5), color)
		_box(self, Vector3(x + 0.6, h * 0.84 + 0.5, z - 0.3), Vector3(3.8, 1.0, 4.2), color.lightened(0.1))
		if i % 3 == 0:
			_box(self, Vector3(x + 0.8, h * 0.84 + 1.1, z - 0.4), Vector3(1.5, 0.2, 2.2), Color("#d0d4c4"))
	for i in range(11):
		var x := -28.0 + float(i) * 5.5
		var h := 2.4 + float((i * 3) % 5) * 0.55
		var z := -30.0 - float(i % 3) * 1.2
		_box(self, Vector3(x, h * 0.5, z), Vector3(5.0, h, 4.0), MAT_STONE)
		_box(self, Vector3(x - 0.2, h + 0.18, z + 0.15), Vector3(3.9, 0.34, 3.2), MAT_GRASS)
	for i in range(14):
		var x := -26.0 + float(i) * 4.0
		var z := -26.0 - float((i * 7) % 3) * 1.3
		var scale := 0.38 + float(i % 3) * 0.1
		_box(self, Vector3(x, 0.72 * scale, z), Vector3(0.16, 1.4, 0.16) * scale, MAT_WOOD)
		_box(self, Vector3(x, 1.55 * scale, z), Vector3(0.9, 0.95, 0.9) * scale, MAT_LEAF_DARK)
		_box(self, Vector3(x, 2.05 * scale, z), Vector3(0.62, 0.7, 0.62) * scale, MAT_LEAF)

func _build_river_and_bridge() -> void:
	var water_material := _material(MAT_WATER, 0.18, 0.15)
	for i in range(14):
		var z := 6.5 - float(i) * 2.4
		var x := 1.8 - sin(float(i) * 0.55) * 2.2
		var water := _box(self, Vector3(x, 0.03, z), Vector3(9.5, 0.16, 3.6), MAT_WATER, 0.18)
		water.material_override = water_material
	var falls_mat := _material(Color("#3ec8e0"), 0.14, 0.1)
	for fall in [
		{"x": 0.5, "y": 3.2, "z": -11.0, "h": 5.2, "w": 1.1},
		{"x": 2.2, "y": 2.4, "z": -10.2, "h": 4.0, "w": 0.7},
		{"x": 8.0, "y": 2.0, "z": -11.5, "h": 3.6, "w": 0.85}
	]:
		var fx: float = fall["x"]
		var fy: float = fall["y"]
		var fz: float = fall["z"]
		var fh: float = fall["h"]
		var fw: float = fall["w"]
		var sheet := _box(self, Vector3(fx, fy, fz), Vector3(fw, fh, 0.18), Color("#3ec8e0"), 0.14)
		sheet.material_override = falls_mat
		_box(self, Vector3(fx + 0.25, fy - fh * 0.15, fz + 0.12), Vector3(0.22, fh * 0.5, 0.12), Color("#a0eef5"), 0.18)
		_box(self, Vector3(fx, 0.08, fz + 0.6), Vector3(2.4, 0.1, 1.5), Color("#68d8e8"), 0.18)
	for i in range(8):
		var x := 2.8 + float(i) * 0.85
		_box(self, Vector3(x, 0.38, -0.8), Vector3(0.95, 0.48, 2.5), MAT_STONE_LIGHT)
	_box(self, Vector3(5.8, 0.75, -1.8), Vector3(7.0, 0.3, 0.24), MAT_STONE)
	_box(self, Vector3(5.8, 0.75, 0.2), Vector3(7.0, 0.3, 0.24), MAT_STONE)

func _build_village() -> void:
	_house(Vector3(-5.0, 0.0, -4.5), Vector3(3.4, 2.8, 3.1), MAT_WALL, MAT_ROOF)
	_house(Vector3(-0.5, 0.0, -6.5), Vector3(2.8, 2.3, 2.7), Color("#d4dfc0"), Color("#7d5949"))
	_house(Vector3(5.5, 0.0, -6.2), Vector3(3.1, 2.5, 2.9), Color("#d7bd8d"), Color("#98583f"))
	_house(Vector3(-9.5, 0.0, -7.5), Vector3(2.9, 2.4, 2.9), Color("#c6d7d2"), Color("#6f5142"))
	_house(Vector3(3.0, 0.0, -9.5), Vector3(2.5, 2.1, 2.4), Color("#e0d0a8"), Color("#8a4a35"))
	for i in range(5):
		_box(self, Vector3(-2.0 + float(i) * 1.6, 0.28, 2.2), Vector3(1.4, 0.12, 0.9), MAT_WOOD)

func _house(origin: Vector3, dimensions: Vector3, wall_color: Color, roof_color: Color) -> void:
	_box(self, origin + Vector3(0.0, dimensions.y * 0.5, 0.0), dimensions, wall_color)
	_box(self, origin + Vector3(0.0, dimensions.y + 0.28, 0.0), Vector3(dimensions.x + 0.7, 0.5, dimensions.z + 0.7), roof_color)
	_box(self, origin + Vector3(0.0, dimensions.y + 0.7, 0.0), Vector3(dimensions.x * 0.75, 0.42, dimensions.z * 0.75), roof_color.darkened(0.12))
	_box(self, origin + Vector3(0.0, 0.75, dimensions.z * 0.5 + 0.04), Vector3(0.5, 1.4, 0.12), MAT_WOOD)
	for wx in [-0.75, 0.75]:
		_box(self, origin + Vector3(wx, dimensions.y * 0.62, dimensions.z * 0.5 + 0.08), Vector3(0.4, 0.48, 0.1), Color("#ffd78a"), 0.3)

func _build_forests() -> void:
	for i in range(20):
		var x := -20.0 + float((i * 11) % 40)
		var z := -1.5 - float((i * 7) % 14)
		if absf(x) < 6.0 and z > -9.0:
			continue
		var scale := 0.75 + float(i % 4) * 0.18
		_tree(Vector3(x, 0.0, z), scale)
	_tree(Vector3(-14.0, 0.0, 3.5), 1.6)
	_tree(Vector3(14.5, 0.0, 2.8), 1.55)
	_tree(Vector3(-11.5, 0.0, 1.0), 1.25)

func _tree(origin: Vector3, scale: float) -> void:
	_box(self, origin + Vector3(0.0, 1.15 * scale, 0.0), Vector3(0.6, 2.3, 0.6) * scale, MAT_WOOD)
	_box(self, origin + Vector3(0.0, 2.6 * scale, 0.0), Vector3(2.3, 1.3, 2.15) * scale, MAT_LEAF_DARK)
	_box(self, origin + Vector3(-0.2 * scale, 3.4 * scale, -0.08 * scale), Vector3(1.85, 1.25, 1.85) * scale, MAT_LEAF)
	_box(self, origin + Vector3(0.15 * scale, 4.0 * scale, -0.1 * scale), Vector3(1.2, 0.85, 1.25) * scale, MAT_LEAF_LIGHT)

func _build_floating_islands() -> void:
	var island := Node3D.new()
	island.name = "FloatingIsland"
	island.position = Vector3(15.0, 10.5, -16.0)
	add_child(island)
	_box(island, Vector3(0.0, 0.0, 0.0), Vector3(9.0, 1.1, 5.5), MAT_GRASS)
	_box(island, Vector3(0.0, -0.85, 0.0), Vector3(7.5, 0.9, 4.4), MAT_DIRT)
	_box(island, Vector3(-0.3, -1.75, 0.0), Vector3(5.2, 1.0, 3.0), MAT_STONE)
	_box(island, Vector3(0.2, -2.55, 0.0), Vector3(2.8, 0.75, 1.8), MAT_STONE)
	for i in range(4):
		_box(island, Vector3(-2.4 + float(i) * 1.7, 0.9, -0.5), Vector3(0.8, 1.3 + float(i % 2) * 0.6, 0.8), MAT_STONE_LIGHT)
	_box(island, Vector3(-2.2, -2.0, 1.2), Vector3(0.18, 3.0, 0.18), Color("#7dd6e9"), 0.18)
	_box(island, Vector3(-1.9, -2.2, 1.2), Vector3(0.12, 2.0, 0.12), Color("#b5eff4"), 0.18)
	var mid := Node3D.new()
	mid.name = "MidFloatingIsland"
	mid.position = Vector3(-10.0, 11.5, -22.0)
	mid.scale = Vector3(0.7, 0.7, 0.7)
	add_child(mid)
	_box(mid, Vector3.ZERO, Vector3(6.5, 0.8, 4.2), MAT_GRASS_LIGHT)
	_box(mid, Vector3(0.0, -0.7, 0.0), Vector3(5.2, 0.9, 3.4), MAT_DIRT)
	_box(mid, Vector3(0.0, -1.5, 0.0), Vector3(3.0, 0.8, 2.2), MAT_STONE)
	_box(mid, Vector3(0.5, 0.7, 0.0), Vector3(1.0, 1.5, 1.0), MAT_STONE_LIGHT)
	_box(mid, Vector3(0.5, 1.6, 0.0), Vector3(1.2, 0.35, 1.2), MAT_ROOF)
	var far := Node3D.new()
	far.name = "FarFloatingIsland"
	far.position = Vector3(6.0, 14.0, -28.0)
	far.scale = Vector3(0.45, 0.45, 0.45)
	add_child(far)
	_box(far, Vector3.ZERO, Vector3(5.0, 0.6, 3.2), MAT_GRASS)
	_box(far, Vector3(0.0, -0.55, 0.0), Vector3(3.8, 0.7, 2.4), MAT_DIRT)
	_box(far, Vector3(0.0, -1.2, 0.0), Vector3(2.0, 0.6, 1.5), MAT_STONE)

func _build_gatehouse_castle() -> void:
	var root := Node3D.new()
	root.name = "GatehouseCastle"
	root.position = Vector3(11.5, 1.0, -13.5)
	add_child(root)
	var stone := MAT_STONE_CASTLE
	var trim := Color("#b8c0b4")
	var dark := Color("#5a6560")
	var glow := Color("#ffd98a")
	_box(root, Vector3(0.0, 2.4, 0.0), Vector3(7.5, 4.8, 4.2), stone)
	_box(root, Vector3(0.0, 1.4, 2.15), Vector3(2.4, 2.8, 0.35), dark)
	for i in range(5):
		_box(root, Vector3(-0.9 + float(i) * 0.45, 1.5, 2.25), Vector3(0.12, 2.4, 0.08), Color("#3a3a3a"))
	for side in [-1.0, 1.0]:
		var tx := side * 4.2
		_box(root, Vector3(tx, 3.5, 0.2), Vector3(2.4, 7.0, 2.6), stone)
		for j in range(3):
			_box(root, Vector3(tx - 0.7 + float(j) * 0.7, 7.2, 1.35), Vector3(0.45, 0.55, 0.4), trim)
			_box(root, Vector3(tx - 0.7 + float(j) * 0.7, 7.2, -0.95), Vector3(0.45, 0.55, 0.4), trim)
		for level in range(3):
			_box(root, Vector3(tx, 2.0 + float(level) * 1.8, 1.4), Vector3(0.55, 0.7, 0.12), glow, 0.3)
		_box(root, Vector3(tx, 7.5, 0.2), Vector3(2.8, 0.35, 3.0), MAT_ROOF)
		_box(root, Vector3(tx, 7.95, 0.2), Vector3(1.6, 0.55, 1.6), MAT_ROOF.darkened(0.1))
	_box(root, Vector3(0.0, 4.5, -3.2), Vector3(5.0, 6.5, 4.0), stone)
	for i in range(5):
		_box(root, Vector3(-1.8 + float(i) * 0.9, 8.0, -1.3), Vector3(0.5, 0.6, 0.45), trim)
	_box(root, Vector3(0.0, 9.5, -3.2), Vector3(2.2, 3.5, 2.2), trim)
	_box(root, Vector3(0.0, 11.4, -3.2), Vector3(2.6, 0.4, 2.6), MAT_ROOF)
	_box(root, Vector3(0.0, 11.9, -3.2), Vector3(1.4, 0.7, 1.4), MAT_ROOF.darkened(0.12))
	_box(root, Vector3(0.0, 12.5, -3.2), Vector3(0.25, 0.6, 0.25), Color("#f6d78c"), 0.28)
	for level in range(3):
		_box(root, Vector3(0.0, 3.0 + float(level) * 1.9, -1.15), Vector3(0.5, 0.75, 0.1), glow, 0.32)
		_box(root, Vector3(-1.4, 3.0 + float(level) * 1.9, -1.15), Vector3(0.35, 0.6, 0.1), glow, 0.32)
		_box(root, Vector3(1.4, 3.0 + float(level) * 1.9, -1.15), Vector3(0.35, 0.6, 0.1), glow, 0.32)
	_box(root, Vector3(6.5, 2.2, -1.0), Vector3(4.0, 3.2, 1.8), stone)
	for j in range(4):
		_box(root, Vector3(5.0 + float(j) * 0.9, 4.0, -0.1), Vector3(0.5, 0.5, 0.4), trim)

func _build_landmark_details() -> void:
	for lamp in [
		{"x": -7.5, "z": -2.8},
		{"x": -2.0, "z": -3.6},
		{"x": 4.0, "z": -3.0},
		{"x": 8.5, "z": -4.8},
		{"x": -4.0, "z": 0.5}
	]:
		var lx: float = lamp["x"]
		var lz: float = lamp["z"]
		_box(self, Vector3(lx, 1.05, lz), Vector3(0.12, 2.1, 0.12), MAT_WOOD)
		_box(self, Vector3(lx, 2.05, lz), Vector3(0.62, 0.16, 0.62), MAT_WOOD)
		var glow := _box(self, Vector3(lx, 1.72, lz), Vector3(0.32, 0.38, 0.32), Color("#ffca6b"), 0.28)
		glow.material_override = _emissive(Color("#ffb84d"), 1.6)
	for i in range(14):
		var x := -15.0 + float(i) * 2.3
		var z := 4.5 + float((i * 5) % 4) * 0.5
		var radius := 0.5 + float(i % 3) * 0.2
		_box(self, Vector3(x, 0.14, z), Vector3(radius * 1.8, 0.28, radius * 1.3), MAT_STONE)
		if i % 2 == 0:
			_box(self, Vector3(x + 0.12, 0.32, z - 0.05), Vector3(radius * 1.6, 0.12, radius), MAT_GRASS_LIGHT)
	for flower in [
		{"x": -10.5, "z": 1.2, "c": "#f4d36e"},
		{"x": -8.0, "z": 2.2, "c": "#f3a8a0"},
		{"x": 7.5, "z": 1.4, "c": "#f4d36e"},
		{"x": 10.5, "z": 2.2, "c": "#b8a6f0"},
		{"x": -3.0, "z": 3.0, "c": "#f0e080"}
	]:
		var fx: float = flower["x"]
		var fz: float = flower["z"]
		_box(self, Vector3(fx, 0.34, fz), Vector3(0.16, 0.16, 0.16), Color(flower["c"]), 0.55)
		_box(self, Vector3(fx, 0.23, fz), Vector3(0.08, 0.22, 0.08), MAT_LEAF_DARK)

func _build_protagonist() -> void:
	var char := Node3D.new()
	char.name = "Protagonist"
	char.position = Vector3(-6.5, 0.0, 6.5)
	char.scale = Vector3(1.15, 1.15, 1.15)
	add_child(char)
	_box(char, Vector3(-0.22, 0.45, 0.0), Vector3(0.38, 0.9, 0.35), MAT_BLUE_PANTS)
	_box(char, Vector3(0.22, 0.45, 0.0), Vector3(0.38, 0.9, 0.35), MAT_BLUE_PANTS)
	_box(char, Vector3(-0.22, 0.08, 0.08), Vector3(0.4, 0.18, 0.48), Color("#2a2a2a"))
	_box(char, Vector3(0.22, 0.08, 0.08), Vector3(0.4, 0.18, 0.48), Color("#2a2a2a"))
	_box(char, Vector3(0.0, 1.25, 0.0), Vector3(0.95, 0.95, 0.5), MAT_TEAL)
	_box(char, Vector3(-0.65, 1.2, 0.0), Vector3(0.32, 0.85, 0.32), MAT_SKIN)
	_box(char, Vector3(0.65, 1.15, 0.15), Vector3(0.32, 0.85, 0.32), MAT_SKIN)
	_box(char, Vector3(0.0, 2.05, 0.0), Vector3(0.7, 0.7, 0.65), MAT_SKIN)
	_box(char, Vector3(0.0, 2.4, -0.05), Vector3(0.75, 0.28, 0.7), Color("#6b3e1f"))
	_box(char, Vector3(0.0, 2.15, -0.28), Vector3(0.72, 0.45, 0.2), Color("#6b3e1f"))
	_box(char, Vector3(-0.15, 2.1, 0.32), Vector3(0.12, 0.12, 0.06), Color("#1a1a1a"))
	_box(char, Vector3(0.15, 2.1, 0.32), Vector3(0.12, 0.12, 0.06), Color("#1a1a1a"))
	_box(char, Vector3(0.0, 1.3, -0.4), Vector3(0.75, 0.8, 0.35), MAT_BROWN_PACK)
	_box(char, Vector3(0.0, 1.55, -0.42), Vector3(0.55, 0.2, 0.38), Color("#a07040"))
	var pick := Node3D.new()
	pick.name = "DiamondPickaxe"
	pick.position = Vector3(0.9, 1.0, 0.35)
	pick.rotation_degrees = Vector3(15.0, -25.0, -40.0)
	char.add_child(pick)
	_box(pick, Vector3(0.0, 0.0, 0.0), Vector3(0.14, 1.4, 0.14), Color("#8b5a2b"))
	_box(pick, Vector3(0.0, 0.75, 0.0), Vector3(0.85, 0.28, 0.22), MAT_DIAMOND)
	_box(pick, Vector3(-0.35, 0.55, 0.0), Vector3(0.22, 0.35, 0.18), MAT_DIAMOND)
	_box(pick, Vector3(0.35, 0.55, 0.0), Vector3(0.22, 0.35, 0.18), MAT_DIAMOND)
