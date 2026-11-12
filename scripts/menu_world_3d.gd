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
	_build_mountain_backdrop()
	_build_river_and_bridge()
	_build_village()
	_build_village_details()
	_build_forests()
	_build_floating_islands()
	_build_gatehouse_castle()
	_build_castle_surface_details()
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
	environment.ambient_light_color = Color("#8199a8")
	environment.ambient_light_energy = 0.28
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.84
	environment.glow_enabled = true
	environment.glow_intensity = 0.10
	environment.fog_enabled = true
	environment.fog_light_color = Color("#b6a080")
	environment.fog_density = 0.00038
	environment.fog_aerial_perspective = 0.35
	world.environment = environment
	add_child(world)

func _setup_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "GoldenHourSun"
	sun.rotation_degrees = Vector3(-32.0, -42.0, 0.0)
	sun.light_color = Color("#ffe0a0")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, 120.0, 0.0)
	fill.light_color = Color("#88b8d8")
	fill.light_energy = 0.14
	add_child(fill)

func _setup_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "MenuWorldCamera"
	# Pull the panorama camera back and above the near forest canopy. This
	# keeps the protagonist in the left foreground while revealing the river,
	# village, gatehouse and floating islands behind the menu UI.
	camera.position = Vector3(-17.0, 8.5, 29.0)
	camera.rotation_degrees = Vector3(-15.0, -34.0, 0.0)
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


func _build_mountain_backdrop() -> void:
	# Three depth-separated ridgelines establish a real mountain valley rather
	# than a flat horizon. Snow facets and darker foothills preserve contrast.
	var ridges := Node3D.new()
	ridges.name = "MountainBackdrop"
	add_child(ridges)
	for i in range(7):
		var x := -34.0 + float(i) * 12.0
		var peak := 13.0 + float((i * 7) % 5) * 2.2
		var width := 13.0 + float(i % 3) * 3.0
		var depth := -54.0 - float(i % 2) * 9.0
		_box(ridges, Vector3(x, peak * 0.42, depth), Vector3(width, peak, 10.0), Color("#526b78"))
		_box(ridges, Vector3(x - 1.0, peak * 0.79, depth + 0.1), Vector3(width * 0.42, peak * 0.34, 10.2), Color("#718895"))
		if i % 2 == 0:
			_box(ridges, Vector3(x - 1.0, peak * 0.99, depth + 0.2), Vector3(width * 0.20, peak * 0.12, 10.3), Color("#d7ddd8"))
	for i in range(5):
		var x := -25.0 + float(i) * 13.0
		_box(ridges, Vector3(x, 3.2, -31.0), Vector3(15.0, 6.4, 8.0), Color("#344f45"))
	# Waterfall ribbons on the valley wall add a readable vertical landmark.
	var fall_mat := _material(Color("#75c8dc"), 0.18)
	fall_mat.emission_enabled = true
	fall_mat.emission = Color("#397f9a")
	fall_mat.emission_energy_multiplier = 0.18
	for x in [-18.0, 19.0]:
		var fall := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.0, 7.0, 0.22)
		fall.mesh = mesh
		fall.position = Vector3(x, 3.8, -27.0)
		fall.material_override = fall_mat
		ridges.add_child(fall)

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
	for i in range(7):
		var hx := 9.0 + i * 3.0
		var hz := -2.0 - (i % 3) * 2.5
		_box(village, Vector3(hx, 0.8, hz), Vector3(2.2, 1.6, 2.0), MAT_WALL)
		_box(village, Vector3(hx, 1.9, hz), Vector3(2.6, 0.8, 2.4), MAT_ROOF)
		_box(village, Vector3(hx, 1.1, hz + 1.05), Vector3(0.5, 0.7, 0.1), MAT_WOOD)
		_box(village, Vector3(hx - 0.58, 1.05, hz + 0.15), Vector3(0.12, 0.62, 0.12), MAT_WOOD)
		_box(village, Vector3(hx + 0.58, 1.05, hz + 0.15), Vector3(0.12, 0.62, 0.12), MAT_WOOD)

func _build_village_details() -> void:
	var details := Node3D.new()
	details.name = "VillageDetails"
	add_child(details)
	_box(details, Vector3(19.0, 0.08, -8.0), Vector3(25.0, 0.12, 1.2), Color("#b89a70"))
	for i in range(8):
		var x := 8.5 + float(i) * 3.0
		_box(details, Vector3(x, 1.35, -6.3), Vector3(0.18, 0.72, 0.18), MAT_WOOD)
		_box(details, Vector3(x, 1.72, -6.3), Vector3(0.22, 0.10, 0.22), Color("#c99b62"))
		_box(details, Vector3(x, 1.10, -3.0), Vector3(0.42, 0.55, 0.08), Color("#f3c879"), 0.3)
	for i in range(4):
		var x := 11.0 + float(i) * 7.0
		_box(details, Vector3(x, 1.1, -12.0), Vector3(0.24, 2.2, 0.24), MAT_WOOD)
		_box(details, Vector3(x, 2.55, -12.0), Vector3(1.45, 1.35, 1.45), MAT_LEAF_DARK)
		_box(details, Vector3(x, 3.2, -12.0), Vector3(1.05, 0.85, 1.05), MAT_LEAF_LIGHT)
		_box(details, Vector3(x + 1.25, 1.3, -5.0), Vector3(0.08, 1.2, 0.08), MAT_WOOD)
		_box(details, Vector3(x + 1.25, 1.85, -5.0), Vector3(0.34, 0.24, 0.12), Color("#ffd58a"), 0.25)

func _build_forests() -> void:
	var forest := Node3D.new()
	forest.name = "Forests"
	add_child(forest)
	for i in range(22):
		var tx := -10.0 + float(i % 7) * 2.4 + sin(float(i) * 1.7) * 0.6
		var tz := -3.5 + float(i / 7) * 3.0 + cos(float(i) * 1.3) * 0.5
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
	root.position = Vector3(24.0, 0.8, -18.0)
	root.scale = Vector3(1.22, 1.22, 1.22)
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
	for side_x in [-6.5, 6.5]:
		for crenel in range(5):
			_box(root, Vector3(side_x, 9.0, -4.5 + float(crenel) * 1.75), Vector3(0.62, 0.72, 0.62), light)
		_box(root, Vector3(side_x, 7.2, 4.45), Vector3(0.20, 1.8, 0.18), dark)
	for win_x in [-3.8, -2.5, 2.5, 3.8]:
		_box(root, Vector3(win_x, 8.8, 0.34), Vector3(0.48, 0.95, 0.12), Color("#253744"))
		_box(root, Vector3(win_x, 9.3, 0.42), Vector3(0.58, 0.12, 0.14), light)
	for level in range(4):		_box(root, Vector3(0, 4.5 + float(level) * 1.7, 0.3), Vector3(0.55, 0.75, 0.12), glow, 0.35)
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

func _build_castle_surface_details() -> void:
	# Layered masonry, slit windows, banners and warm sconces break up the
	# oversized flat wall planes and give the gatehouse a readable focal face.
	var castle := get_node_or_null("GatehouseCastle") as Node3D
	if castle == null:
		return
	var mortar := Color("#59645f")
	var stone_a := Color("#a4aaa0")
	var stone_b := Color("#737f7b")
	var banner := Color("#b84f3c")
	for row in range(5):
		var y := 4.0 + float(row) * 1.15
		for col in range(8):
			var x := -5.1 + float(col) * 1.45 + (0.35 if row % 2 == 1 else 0.0)
			if absf(x) < 1.5 and y < 6.0:
				continue
			_box(castle, Vector3(x, y, 4.28), Vector3(1.25, 0.055, 0.045), mortar)
			if row % 2 == 0:
				_box(castle, Vector3(x + 0.55, y + 0.35, 4.30), Vector3(0.055, 0.55, 0.055), stone_b)
		for side_x in [-6.5, 6.5]:
			_box(castle, Vector3(side_x, 8.7, 4.52), Vector3(0.12, 2.1, 0.12), MAT_WOOD)
			_box(castle, Vector3(side_x + (0.62 if side_x < 0.0 else -0.62), 8.55, 4.52), Vector3(1.15, 1.35, 0.10), banner)
			_box(castle, Vector3(side_x + (0.62 if side_x < 0.0 else -0.62), 7.82, 4.58), Vector3(0.72, 0.12, 0.06), Color("#e7c77c"))
	for side_x in [-4.8, 4.8]:
		_box(castle, Vector3(side_x, 5.6, 4.55), Vector3(0.22, 0.5, 0.16), Color("#f3bd68"), 0.25)
		_box(castle, Vector3(side_x, 5.6, 4.64), Vector3(0.42, 0.18, 0.12), Color("#ffd98a"), 0.22)


func _build_protagonist() -> void:
	# Larger, layered hero silhouette based on the approved Blockraft character:
	# teal tunic, blue trousers, backpack, face, boots and diamond pickaxe.
	var ledge := Node3D.new()
	ledge.name = "HeroForegroundLedge"
	add_child(ledge)
	_box(ledge, Vector3(-13.5, 1.75, 13.0), Vector3(5.0, 1.5, 5.0), MAT_GRASS)
	_box(ledge, Vector3(-13.5, 0.5, 13.0), Vector3(5.2, 1.0, 5.2), MAT_STONE)
	var hero := Node3D.new()
	hero.name = "Protagonist"
	hero.position = Vector3(-13.5, 2.5, 13.0)
	hero.rotation_degrees = Vector3(0, 135, 0)
	hero.scale = Vector3(1.28, 1.28, 1.28)
	add_child(hero)
	var skin := Color("#e9b58b")
	var hair := Color("#75401f")
	var teal := Color("#08b7ad")
	var blue := Color("#0756a7")
	var boot := Color("#343b43")
	# Legs and boots are separated to keep the full character readable at menu scale.
	for side in [-1.0, 1.0]:
		_box(hero, Vector3(side * 0.23, 0.88, 0.0), Vector3(0.37, 0.76, 0.43), blue)
		_box(hero, Vector3(side * 0.23, 0.38, 0.08), Vector3(0.40, 0.25, 0.53), boot)
		_box(hero, Vector3(side * 0.23, 0.245, 0.10), Vector3(0.42, 0.06, 0.55), Color("#1f252c"))
		_box(hero, Vector3(side * 0.59, 2.16, 0.0), Vector3(0.30, 0.65, 0.46), teal)
		_box(hero, Vector3(side * 0.60, 1.68, 0.02), Vector3(0.24, 0.48, 0.30), skin)
	_box(hero, Vector3(0.0, 2.05, 0.0), Vector3(0.92, 1.05, 0.48), teal)
	_box(hero, Vector3(0.0, 1.53, 0.0), Vector3(0.94, 0.12, 0.50), Color("#174f9a"))
	_box(hero, Vector3(0.0, 2.92, 0.0), Vector3(0.78, 0.78, 0.68), skin)
	_box(hero, Vector3(0.0, 3.32, -0.01), Vector3(0.84, 0.25, 0.74), hair)
	_box(hero, Vector3(0.0, 2.98, -0.31), Vector3(0.82, 0.58, 0.16), hair)
	_box(hero, Vector3(0.0, 3.18, 0.355), Vector3(0.78, 0.16, 0.08), hair)
	for eye_x in [-0.18, 0.18]:
		_box(hero, Vector3(eye_x, 2.99, 0.353), Vector3(0.105, 0.12, 0.045), Color("#f8f5e9"))
		_box(hero, Vector3(eye_x, 2.99, 0.382), Vector3(0.052, 0.08, 0.025), Color("#25344a"))
	_box(hero, Vector3(0.0, 2.84, 0.39), Vector3(0.12, 0.13, 0.08), Color("#d99a72"))
	# Backpack with lid, side pockets and straps.
	_box(hero, Vector3(0.0, 2.06, -0.36), Vector3(0.62, 0.78, 0.30), MAT_BROWN_PACK)
	_box(hero, Vector3(0.0, 2.43, -0.38), Vector3(0.67, 0.16, 0.34), Color("#b8783d"))
	_box(hero, Vector3(0.0, 1.91, -0.54), Vector3(0.36, 0.29, 0.12), Color("#6c3d25"))
	_box(hero, Vector3(0.0, 2.29, -0.565), Vector3(0.16, 0.09, 0.035), Color("#d9b35f"), 0.4)
	for pocket_x in [-0.34, 0.34]:
		_box(hero, Vector3(pocket_x, 1.98, -0.34), Vector3(0.14, 0.32, 0.26), Color("#754426"))
	for strap_x in [-0.29, 0.29]:
		_box(hero, Vector3(strap_x, 2.12, 0.25), Vector3(0.09, 0.72, 0.06), Color("#8a542e"))
	# Diamond pickaxe held to the hero's right.
	var pick := Node3D.new()
	pick.name = "DiamondPickaxe"
	pick.position = Vector3(0.88, 1.68, 0.12)
	pick.rotation_degrees.z = -18.0
	hero.add_child(pick)
	_box(pick, Vector3(0.0, -0.18, 0.0), Vector3(0.13, 1.02, 0.14), MAT_WOOD)
	_box(pick, Vector3(0.0, 0.12, 0.01), Vector3(0.15, 0.12, 0.16), Color("#d1a05a"))
	_box(pick, Vector3(-0.28, 0.43, 0.0), Vector3(0.48, 0.18, 0.20), MAT_DIAMOND, 0.25)
	_box(pick, Vector3(0.28, 0.43, 0.0), Vector3(0.48, 0.18, 0.20), MAT_DIAMOND, 0.25)
	_box(pick, Vector3(-0.49, 0.32, 0.0), Vector3(0.14, 0.22, 0.20), Color("#76f5ee"), 0.22)
	_box(pick, Vector3(0.49, 0.32, 0.0), Vector3(0.14, 0.22, 0.20), Color("#76f5ee"), 0.22)
