extends Node3D
## Blockraft menu 3D panorama — golden-hour valley with grand castle.

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
	sky_material.sky_top_color = Color("#2a5a9a")
	sky_material.sky_horizon_color = Color("#ffb060")
	sky_material.ground_bottom_color = Color("#1a2b2a")
	sky_material.ground_horizon_color = Color("#e0a868")
	sky_material.sun_angle_max = 22.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#a8c8d8")
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.95
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
	sun.light_color = Color("#ffe0a0")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, 120.0, 0.0)
	fill.light_color = Color("#88b8d8")
	fill.light_energy = 0.25
	add_child(fill)

func _setup_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "MenuWorldCamera"
	camera.position = Vector3(-6.5, 4.2, 11.5)
	camera.rotation_degrees = Vector3(-12.0, -28.0, 0.0)
	camera.fov = 55.0
	camera.near = 0.1
	camera.far = 200.0
	camera.current = true
	add_child(camera)

func _build_landscape() -> void:
	var ground := Node3D.new()
	ground.name = "Landscape"
	add_child(ground)
	_box(ground, Vector3(0, -0.5, 0), Vector3(80, 1, 80), MAT_GRASS)
	for i in range(12):
		var ox := (i % 4) * 8.0 - 12.0
		var oz := (i / 4) * 10.0 - 8.0
		_box(ground, Vector3(ox, 0.2, oz), Vector3(6.0 + (i % 3), 0.4, 5.0), MAT_GRASS_LIGHT if i % 2 == 0 else MAT_GRASS)
	_box(ground, Vector3(-10, 1.2, 4), Vector3(8, 2.5, 6), MAT_GRASS)
	_box(ground, Vector3(-8, 2.0, 3), Vector3(4, 1.2, 3), MAT_GRASS_LIGHT)

func _build_horizon_layers() -> void:
	var far := Node3D.new()
	far.name = "Horizon"
	add_child(far)
	_box(far, Vector3(25, 6, -40), Vector3(30, 14, 8), MAT_STONE)
	_box(far, Vector3(35, 10, -45), Vector3(12, 18, 6), MAT_STONE_LIGHT)
	_box(far, Vector3(-20, 5, -38), Vector3(18, 12, 7), MAT_STONE)
	_box(far, Vector3(0, 3, -35), Vector3(40, 6, 5), MAT_GRASS)

func _build_river_and_bridge() -> void:
	var water := Node3D.new()
	water.name = "River"
	add_child(water)
	var wmat := _material(Color(0.22, 0.58, 0.78, 0.72), 0.08, 0.25)
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.emission_enabled = true
	wmat.emission = Color(0.08, 0.2, 0.3)
	wmat.emission_energy_multiplier = 0.2
	var river := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(7.5, 0.28, 58)
	river.mesh = rm
	river.position = Vector3(3.5, -0.05, -6)
	river.material_override = wmat
	water.add_child(river)
	_box(water, Vector3(-0.8, 0.15, -6), Vector3(1.6, 0.25, 50), Color("#d4c090"))
	_box(water, Vector3(8.0, 0.15, -6), Vector3(1.6, 0.25, 50), Color("#d4c090"))
	var foam := _material(Color(0.75, 0.9, 0.95, 0.45), 0.2)
	foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for z in [-15.0, -5.0, 5.0, 12.0]:
		var f := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(6.5, 0.08, 1.2)
		f.mesh = fm
		f.position = Vector3(3.5, 0.12, z)
		f.material_override = foam
		water.add_child(f)
	_box(water, Vector3(1.2, 0.45, 3), Vector3(1.0, 0.18, 7), MAT_WOOD)
	_box(water, Vector3(5.8, 0.45, 3), Vector3(1.0, 0.18, 7), MAT_WOOD)
	_box(water, Vector3(3.5, 0.6, 3), Vector3(5.5, 0.14, 1.8), MAT_WOOD)
	for xz in [[1.2, 0.5], [5.8, 0.5], [1.2, 5.5], [5.8, 5.5]]:
		_box(water, Vector3(xz[0], 1.0, xz[1]), Vector3(0.12, 1.0, 0.12), MAT_WOOD)

func _build_village() -> void:
	var village := Node3D.new()
	village.name = "Village"
	add_child(village)
	for i in range(5):
		var hx := 10.0 + i * 3.5
		var hz := -2.0 - (i % 3) * 2.5
		_box(village, Vector3(hx, 0.8, hz), Vector3(2.2, 1.6, 2.0), MAT_WALL)
		_box(village, Vector3(hx, 1.9, hz), Vector3(2.6, 0.8, 2.4), MAT_ROOF)
		_box(village, Vector3(hx, 1.1, hz + 1.05), Vector3(0.5, 0.7, 0.1), MAT_WOOD)

func _build_forests() -> void:
	var forest := Node3D.new()
	forest.name = "Forests"
	add_child(forest)
	for i in range(22):
		var tx := -15.0 + float(i % 7) * 2.4 + sin(float(i) * 1.7) * 0.6
		var tz := 1.5 + float(i / 7) * 2.8 + cos(float(i) * 1.3) * 0.5
		var h := 1.8 + float(i % 4) * 0.35
		_box(forest, Vector3(tx, h * 0.5, tz), Vector3(0.32, h, 0.32), MAT_WOOD)
		_box(forest, Vector3(tx, h + 0.5, tz), Vector3(1.8, 1.2, 1.8), MAT_LEAF_DARK)
		_box(forest, Vector3(tx, h + 1.3, tz), Vector3(1.5, 1.1, 1.5), MAT_LEAF)
		_box(forest, Vector3(tx, h + 2.0, tz), Vector3(1.0, 0.9, 1.0), MAT_LEAF_LIGHT)
		if i % 3 == 0:
			_box(forest, Vector3(tx + 0.6, h + 0.9, tz - 0.4), Vector3(0.9, 0.8, 0.9), MAT_LEAF)

func _build_floating_islands() -> void:
	var island := Node3D.new()
	island.name = "FloatingIsland"
	island.position = Vector3(22, 14, -18)
	add_child(island)
	_box(island, Vector3(0, 0, 0), Vector3(6, 1.5, 5), MAT_STONE)
	_box(island, Vector3(0, 1.0, 0), Vector3(5.5, 0.4, 4.5), MAT_GRASS)
	_box(island, Vector3(0, -1.5, 0), Vector3(3, 2, 2.5), MAT_STONE_LIGHT)
	var mid := Node3D.new()
	mid.name = "MidFloatingIsland"
	mid.position = Vector3(28, 18, -28)
	add_child(mid)
	_box(mid, Vector3(0, 0, 0), Vector3(4, 1.2, 3.5), MAT_STONE)
	_box(mid, Vector3(0, 0.8, 0), Vector3(3.5, 0.3, 3), MAT_GRASS)
	var far := Node3D.new()
	far.name = "FarFloatingIsland"
	far.position = Vector3(18, 22, -32)
	add_child(far)
	_box(far, Vector3(0, 0, 0), Vector3(3, 1, 2.5), MAT_STONE)
	_box(far, Vector3(0, 0.7, 0), Vector3(2.5, 0.25, 2), MAT_GRASS)

func _build_gatehouse_castle() -> void:
	var root := Node3D.new()
	root.name = "GatehouseCastle"
	root.position = Vector3(14.0, 0.8, -16.0)
	add_child(root)
	var stone := MAT_STONE_CASTLE
	var light := Color("#a8b4ae")
	var dark := Color("#4a5550")
	var roof := MAT_ROOF
	var glow := Color("#ffd98a")
	_box(root, Vector3(0, 1.5, -2), Vector3(16, 3.2, 12), MAT_STONE)
	_box(root, Vector3(0, 3.2, -2), Vector3(14, 0.5, 10), MAT_GRASS)
	_box(root, Vector3(0, 5.0, 3.5), Vector3(12, 3.5, 1.4), stone)
	_box(root, Vector3(-6.2, 5.0, -1), Vector3(1.4, 3.5, 10), stone)
	_box(root, Vector3(6.2, 5.0, -1), Vector3(1.4, 3.5, 10), stone)
	for i in range(9):
		_box(root, Vector3(-5.0 + float(i) * 1.25, 7.0, 4.0), Vector3(0.55, 0.7, 0.5), light)
	_box(root, Vector3(0, 4.2, 4.2), Vector3(2.8, 2.6, 0.5), dark)
	for i in range(6):
		_box(root, Vector3(-1.0 + float(i) * 0.4, 4.3, 4.35), Vector3(0.1, 2.2, 0.08), Color("#2a2a2a"))
	for side_x in [-6.5, 6.5]:
		for side_z in [3.0, -5.0]:
			_box(root, Vector3(side_x, 6.5, side_z), Vector3(2.8, 7.0, 2.8), stone)
			_box(root, Vector3(side_x, 10.2, side_z), Vector3(3.2, 0.4, 3.2), roof)
			_box(root, Vector3(side_x, 10.7, side_z), Vector3(2.0, 0.8, 2.0), roof.darkened(0.1))
			_box(root, Vector3(side_x, 11.3, side_z), Vector3(0.3, 0.7, 0.3), Color("#f6d78c"), 0.25)
			_box(root, Vector3(side_x + (0.1 if side_x > 0 else -0.1), 5.5, side_z + (1.45 if side_z > 0 else -1.45)), Vector3(0.5, 0.7, 0.12), glow, 0.3)
			_box(root, Vector3(side_x + (0.1 if side_x > 0 else -0.1), 7.5, side_z + (1.45 if side_z > 0 else -1.45)), Vector3(0.5, 0.7, 0.12), glow, 0.3)
	_box(root, Vector3(0, 7.0, -2.5), Vector3(6.5, 8.0, 5.5), stone)
	_box(root, Vector3(0, 11.5, -2.5), Vector3(7.2, 0.45, 6.2), roof)
	_box(root, Vector3(0, 13.0, -2.5), Vector3(3.0, 3.5, 3.0), light)
	_box(root, Vector3(0, 15.0, -2.5), Vector3(3.6, 0.4, 3.6), roof)
	_box(root, Vector3(0, 15.5, -2.5), Vector3(1.8, 0.9, 1.8), roof.darkened(0.12))
	_box(root, Vector3(0, 16.2, -2.5), Vector3(0.25, 0.8, 0.25), Color("#f6d78c"), 0.25)
	for level in range(4):
		_box(root, Vector3(0, 4.5 + float(level) * 1.7, 0.3), Vector3(0.55, 0.75, 0.12), glow, 0.35)
		_box(root, Vector3(-1.8, 4.5 + float(level) * 1.7, 0.3), Vector3(0.4, 0.6, 0.12), glow, 0.35)
		_box(root, Vector3(1.8, 4.5 + float(level) * 1.7, 0.3), Vector3(0.4, 0.6, 0.12), glow, 0.35)
	_box(root, Vector3(0, 3.6, 7.5), Vector3(2.2, 0.35, 6.0), MAT_WOOD)
	for xz in [[-1.0, 6.0], [1.0, 6.0], [-1.0, 9.0], [1.0, 9.0]]:
		_box(root, Vector3(xz[0], 4.2, xz[1]), Vector3(0.15, 1.2, 0.15), MAT_WOOD)
	var fall := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(1.4, 7.0, 0.5)
	fall.mesh = fm
	fall.position = Vector3(9.5, 4.0, 1.0)
	var fmat := _material(Color(0.45, 0.78, 0.92, 0.5), 0.08)
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fall.material_override = fmat
	root.add_child(fall)
	var pool := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(3.5, 0.25, 3.0)
	pool.mesh = pm
	pool.position = Vector3(9.5, 0.5, 3.5)
	pool.material_override = fmat
	root.add_child(pool)

func _build_landmark_details() -> void:
	var details := Node3D.new()
	details.name = "Details"
	add_child(details)
	_box(details, Vector3(12, 0.3, 5), Vector3(1, 0.6, 1), MAT_STONE)
	_box(details, Vector3(-5, 0.4, 8), Vector3(1.5, 0.8, 1.2), MAT_DIRT)

func _build_protagonist() -> void:
	var hero := Node3D.new()
	hero.name = "Protagonist"
	hero.position = Vector3(-7.2, 1.8, 6.0)
	hero.rotation_degrees = Vector3(0, 40, 0)
	add_child(hero)
	_box(hero, Vector3(-0.17, 0.48, 0), Vector3(0.30, 0.72, 0.28), MAT_BLUE_PANTS)
	_box(hero, Vector3(0.17, 0.48, 0), Vector3(0.30, 0.72, 0.28), MAT_BLUE_PANTS)
	_box(hero, Vector3(-0.17, 0.10, 0.06), Vector3(0.32, 0.18, 0.40), Color("#1e1a18"))
	_box(hero, Vector3(0.17, 0.10, 0.06), Vector3(0.32, 0.18, 0.40), Color("#1e1a18"))
	_box(hero, Vector3(0, 1.12, 0), Vector3(0.78, 0.72, 0.42), MAT_TEAL)
	_box(hero, Vector3(0, 1.12, 0.22), Vector3(0.50, 0.48, 0.06), Color("#249e90"))
	_box(hero, Vector3(0, 0.78, 0), Vector3(0.82, 0.14, 0.44), Color("#1f8a7e"))
	_box(hero, Vector3(-0.55, 1.08, 0), Vector3(0.26, 0.70, 0.26), MAT_SKIN)
	_box(hero, Vector3(0.55, 1.08, 0), Vector3(0.26, 0.70, 0.26), MAT_SKIN)
	_box(hero, Vector3(-0.55, 1.35, 0), Vector3(0.30, 0.12, 0.30), MAT_TEAL)
	_box(hero, Vector3(0.55, 1.35, 0), Vector3(0.30, 0.12, 0.30), MAT_TEAL)
	_box(hero, Vector3(0, 1.18, -0.36), Vector3(0.62, 0.68, 0.28), MAT_BROWN_PACK)
	_box(hero, Vector3(0, 1.48, -0.38), Vector3(0.48, 0.14, 0.30), Color("#9a6230"))
	_box(hero, Vector3(-0.28, 1.25, -0.22), Vector3(0.08, 0.35, 0.08), Color("#4a3010"))
	_box(hero, Vector3(0.28, 1.25, -0.22), Vector3(0.08, 0.35, 0.08), Color("#4a3010"))
	_box(hero, Vector3(0, 1.78, 0), Vector3(0.56, 0.56, 0.54), MAT_SKIN)
	_box(hero, Vector3(0, 2.08, -0.02), Vector3(0.60, 0.20, 0.58), Color("#5a3218"))
	_box(hero, Vector3(0, 1.92, -0.26), Vector3(0.58, 0.36, 0.16), Color("#5a3218"))
	_box(hero, Vector3(-0.28, 1.95, 0.05), Vector3(0.14, 0.28, 0.40), Color("#5a3218"))
	_box(hero, Vector3(0.28, 1.95, 0.05), Vector3(0.14, 0.28, 0.40), Color("#5a3218"))
	_box(hero, Vector3(-0.12, 1.80, 0.28), Vector3(0.10, 0.10, 0.06), Color("#1a1410"))
	_box(hero, Vector3(0.12, 1.80, 0.28), Vector3(0.10, 0.10, 0.06), Color("#1a1410"))
	_box(hero, Vector3(-0.12, 1.82, 0.30), Vector3(0.04, 0.04, 0.04), Color("#ffffff"))
	_box(hero, Vector3(0.12, 1.82, 0.30), Vector3(0.04, 0.04, 0.04), Color("#ffffff"))
	_box(hero, Vector3(0, 1.68, 0.28), Vector3(0.14, 0.06, 0.05), Color("#d4887a"))
	var pick := Node3D.new()
	pick.position = Vector3(0.70, 0.95, 0.22)
	pick.rotation_degrees = Vector3(18, 0, -32)
	hero.add_child(pick)
	_box(pick, Vector3(0, 0, 0), Vector3(0.07, 0.90, 0.07), MAT_WOOD)
	_box(pick, Vector3(0, 0.52, 0), Vector3(0.52, 0.14, 0.13), MAT_DIAMOND, 0.25)
	_box(pick, Vector3(-0.24, 0.38, 0), Vector3(0.14, 0.24, 0.12), MAT_DIAMOND, 0.25)
	_box(pick, Vector3(0.24, 0.38, 0), Vector3(0.14, 0.24, 0.12), MAT_DIAMOND, 0.25)
	_box(pick, Vector3(0, 0.58, 0), Vector3(0.18, 0.10, 0.16), Color("#a8ffff"), 0.2)
