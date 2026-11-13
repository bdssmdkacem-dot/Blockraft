extends Node3D
## Blockraft menu 3D panorama — golden-hour valley with grand castle.

const MAT_GRASS := Color("#326b3c")
const MAT_GRASS_LIGHT := Color("#548e45")
const MAT_DIRT := Color("#79513a")
const MAT_STONE := Color("#687b80")
const MAT_STONE_LIGHT := Color("#9eafa8")
const MAT_STONE_CASTLE := Color("#697873")
const MAT_WOOD := Color("#70472f")
const MAT_LEAF_DARK := Color("#276747")
const MAT_LEAF := Color("#397b49")
const MAT_LEAF_LIGHT := Color("#5da64f")
const MAT_ROOF := Color("#a65f42")
const MAT_WALL := Color("#cbb17c")
const MAT_WATER := Color("#48b9d1")
const MAT_SKIN := Color("#e8b896")
const MAT_TEAL := Color("#2ec4b6")
const MAT_BLUE_PANTS := Color("#3a5f9a")
const MAT_DIAMOND := Color("#5ce1e6")
const MAT_BROWN_PACK := Color("#8b5a2b")

func _ready() -> void:
	_setup_environment()
	_build_sky_dome()
	_setup_lighting()
	_setup_camera()
	_build_landscape()
	_build_horizon_layers()
	_build_mountain_backdrop()
	_build_sunset_disc()
	_build_sky_clouds()
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
	sky_material.sky_top_color = Color("#245f9d")
	sky_material.sky_horizon_color = Color("#f2a66a")
	sky_material.ground_bottom_color = Color("#172b2d")
	sky_material.ground_horizon_color = Color("#b77f58")
	sky_material.sky_energy_multiplier = 1.2
	sky_material.sky_curve = 0.05
	sky_material.sun_angle_max = 22.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#8da8bf")
	environment.ambient_light_energy = 0.23
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.82
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.12
	environment.adjustment_saturation = 1.05
	environment.adjustment_brightness = 1.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.12
	environment.fog_enabled = true
	environment.fog_light_color = Color("#a9b6b5")
	environment.fog_density = 0.00024
	environment.fog_aerial_perspective = 0.35
	world.environment = environment
	add_child(world)

func _build_sky_dome() -> void:
	# A deterministic gradient dome keeps the menu sky vivid in the nested
	# SubViewport on both desktop and software-rendered CI, where the procedural
	# sky background was falling back to a flat grey tone.
	var dome := MeshInstance3D.new()
	dome.name = "MenuSkyDome"
	var sphere := SphereMesh.new()
	sphere.radius = 190.0
	sphere.height = 380.0
	sphere.radial_segments = 32
	sphere.rings = 16
	dome.mesh = sphere
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
varying vec3 sky_direction;
void vertex() {
	sky_direction = VERTEX;
}
void fragment() {
	float elevation = clamp(normalize(sky_direction).y, -0.08, 1.0);
	float blend = smoothstep(-0.10, 0.30, elevation);
	vec3 horizon = vec3(0.96, 0.68, 0.48);
	vec3 zenith = vec3(0.13, 0.40, 0.72);
	ALBEDO = mix(horizon, zenith, blend);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	dome.material_override = material
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)

func _setup_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "GoldenHourSun"
	sun.rotation_degrees = Vector3(-32.0, -42.0, 0.0)
	sun.light_color = Color("#ffe0a0")
	sun.light_energy = 0.92
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, 120.0, 0.0)
	fill.light_color = Color("#88b8d8")
	fill.light_energy = 0.13
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
	# Keep the horizon low and broken: the old continuous block wall hid the
	# ridgelines and read as an inaccessible cliff across the whole panorama.
	var far := Node3D.new()
	far.name = "Horizon"
	add_child(far)
	var foothill_colors := [Color("#486858"), Color("#587663"), Color("#6b8064")]
	for i in range(9):
		var x := -42.0 + float(i) * 10.5
		var depth := -38.0 - float(i % 3) * 3.0
		var height := 5.0 + float((i * 5) % 4) * 1.35
		_box(far, Vector3(x, height * 0.34, depth), Vector3(12.0, height * 0.68, 9.0), foothill_colors[i % foothill_colors.size()])
		_pyramid(far, Vector3(x, height * 0.72, depth - 0.2), 6.8, height * 0.72, foothill_colors[(i + 1) % foothill_colors.size()])
	# A low valley saddle leaves a visible gap between the foothills and the
	# taller snow ridges behind them.
	_box(far, Vector3(0.0, 1.4, -34.0), Vector3(34.0, 2.8, 5.0), Color("#527454"))


func _build_mountain_backdrop() -> void:
	# Layered faceted peaks replace the old continuous rectangular cliff wall.
	# Each ridge has a sloped silhouette, visible valley gaps and a separate
	# snow crown so the castle sits in a mountain landscape rather than a box canyon.
	var ridges := Node3D.new()
	ridges.name = "MountainBackdrop"
	add_child(ridges)
	var rock_colors := [Color("#405c6d"), Color("#526f7d"), Color("#607c86"), Color("#718c91")]
	for i in range(9):
		var x := -43.0 + float(i) * 10.5
		var peak := 12.0 + float((i * 7) % 6) * 2.1
		var radius := 7.5 + float(i % 3) * 1.6
		var depth := -57.0 - float(i % 3) * 7.0
		var rock: Color = rock_colors[i % rock_colors.size()]
		_pyramid(ridges, Vector3(x, peak * 0.50, depth), radius, peak, rock)
		# Offset secondary shoulders create irregular mountain profiles.
		if i % 2 == 0:
			_pyramid(ridges, Vector3(x - radius * 0.72, peak * 0.30, depth + 2.0), radius * 0.66, peak * 0.60, rock.lightened(0.10))
		if i % 3 != 1:
			_pyramid(ridges, Vector3(x + radius * 0.62, peak * 0.27, depth + 1.0), radius * 0.58, peak * 0.54, rock.darkened(0.10))
		# Small snow facets sit only on the tallest rear peaks.
		if i % 2 == 0:
			_pyramid(ridges, Vector3(x, peak * 0.88, depth - 0.3), radius * 0.34, peak * 0.34, Color("#d8e1df"))
	# Lower green foothills retain a broad valley floor and do not form a wall.
	for i in range(7):
		var x := -36.0 + float(i) * 12.0
		var height := 4.5 + float((i * 3) % 4) * 1.0
		_pyramid(ridges, Vector3(x, height * 0.5, -34.0 - float(i % 2) * 3.0), 10.0, height, Color("#496b55").lightened(float(i % 3) * 0.035))
	# Narrow waterfalls descend through two visible mountain gaps.
	var fall_mat := _material(Color("#75c8dc"), 0.18)
	fall_mat.emission_enabled = true
	fall_mat.emission = Color("#397f9a")
	fall_mat.emission_energy_multiplier = 0.12
	for spec in [[-19.0, 5.0, -30.0], [20.0, 6.0, -31.0]]:
		var fall := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.55, spec[1], 0.16)
		fall.mesh = mesh
		fall.position = Vector3(spec[0], spec[1] * 0.5, spec[2])
		fall.material_override = fall_mat
		ridges.add_child(fall)

func _build_sunset_disc() -> void:
	# A warm, emissive sun gives the valley a clear golden-hour focal point.
	var sun := MeshInstance3D.new()
	sun.name = "SunsetDisc"
	var mesh := SphereMesh.new()
	mesh.radius = 3.2
	mesh.height = 6.4
	mesh.radial_segments = 20
	mesh.rings = 10
	sun.mesh = mesh
	sun.position = Vector3(13.0, 16.5, -50.0)
	sun.scale = Vector3.ONE * 1.35
	var material := _emissive(Color("#ffbd55"), 0.82)
	sun.material_override = material
	add_child(sun)

func _build_sky_clouds() -> void:
	var clouds := Node3D.new()
	clouds.name = "SkyClouds"
	add_child(clouds)
	var cloud_specs := [
		[Vector3(-5.0, 21.0, -38.0), Vector3(5.0, 0.75, 1.8)],
		[Vector3(0.0, 21.25, -38.0), Vector3(3.2, 1.0, 2.0)],
		[Vector3(18.0, 23.0, -44.0), Vector3(5.8, 0.8, 2.0)],
		[Vector3(23.0, 23.2, -44.0), Vector3(3.6, 1.0, 2.2)],
		[Vector3(38.0, 20.5, -52.0), Vector3(5.0, 0.7, 1.8)]
	]
	for spec in cloud_specs:
		var base_position: Vector3 = spec[0]
		var base_size: Vector3 = spec[1]
		_box(clouds, base_position, base_size, Color("#ffe8d2"), 0.25)
		_box(clouds, base_position + Vector3(-base_size.x * 0.28, 0.32, 0.0), base_size * Vector3(0.52, 0.72, 0.9), Color("#fff0df"), 0.28)
		_box(clouds, base_position + Vector3(base_size.x * 0.24, 0.22, 0.05), base_size * Vector3(0.48, 0.62, 0.82), Color("#f4d9c0"), 0.3)

func _pyramid(parent: Node3D, position: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var spire := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.16
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 7
	mesh.rings = 1
	spire.mesh = mesh
	spire.position = position
	spire.rotation.y = PI * 0.25
	spire.material_override = _material(color, 0.62)
	parent.add_child(spire)
	return spire

func _build_river_and_bridge() -> void:
	var water := Node3D.new()
	water.name = "River"
	add_child(water)
	var wmat := _material(Color(0.13, 0.37, 0.58, 0.72), 0.18, 0.10)
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.emission_enabled = true
	wmat.emission = Color(0.08, 0.2, 0.3)
	wmat.emission_energy_multiplier = 0.08
	var river := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(9.5, 0.28, 66)
	river.mesh = rm
	river.position = Vector3(4.5, -0.05, -8)
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
	village.position = Vector3(-1.5, 0.0, 0.5)
	village.scale = Vector3.ONE * 1.18
	add_child(village)
	for i in range(9):
		var hx := 8.0 + i * 2.5
		var hz := -2.0 - (i % 3) * 2.8
		_box(village, Vector3(hx, 0.8, hz), Vector3(2.2, 1.6, 2.0), MAT_WALL)
		_box(village, Vector3(hx, 1.9, hz), Vector3(2.6, 0.8, 2.4), MAT_ROOF)
		# Two sloped roof planes and a ridge cap replace the flat slab silhouette.
		var roof_left := _box(village, Vector3(hx - 0.62, 2.28, hz), Vector3(1.55, 0.16, 2.65), Color("#9a5039"))
		roof_left.rotation.z = deg_to_rad(-27.0)
		var roof_right := _box(village, Vector3(hx + 0.62, 2.28, hz), Vector3(1.55, 0.16, 2.65), Color("#b96a48"))
		roof_right.rotation.z = deg_to_rad(27.0)
		_box(village, Vector3(hx, 2.63, hz), Vector3(0.18, 0.14, 2.7), Color("#d18a5b"))
		_box(village, Vector3(hx, 1.85, hz + 1.12), Vector3(0.72, 0.88, 0.08), Color("#594333"))
		_box(village, Vector3(hx - 0.48, 1.45, hz + 1.12), Vector3(0.42, 0.42, 0.07), Color("#8bc5d0"), 0.3)
		_box(village, Vector3(hx + 0.48, 1.45, hz + 1.12), Vector3(0.42, 0.42, 0.07), Color("#8bc5d0"), 0.3)
		_box(village, Vector3(hx, 1.1, hz + 1.05), Vector3(0.5, 0.7, 0.1), MAT_WOOD)
		_box(village, Vector3(hx - 0.58, 1.05, hz + 0.15), Vector3(0.12, 0.62, 0.12), MAT_WOOD)
		_box(village, Vector3(hx + 0.58, 1.05, hz + 0.15), Vector3(0.12, 0.62, 0.12), MAT_WOOD)
		# Chimney cap and warm side lantern make each house readable at panorama scale.
		_box(village, Vector3(hx - 0.72, 2.55, hz - 0.55), Vector3(0.42, 0.95, 0.42), Color("#765344"))
		_box(village, Vector3(hx + 1.14, 1.35, hz + 0.98), Vector3(0.24, 0.34, 0.12), Color("#ffd28a"), 0.25)

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
	for i in range(14):
		# Keep the dense canopy on the left flank; the river, village and castle
		# remain visible through the centre of the panorama.
		var tx := -19.0 + float(i % 5) * 2.35 + sin(float(i) * 1.7) * 0.45
		var tz := -5.5 + float(i / 5) * 3.2 + cos(float(i) * 1.3) * 0.4
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
	root.position = Vector3(30.0, 0.8, -18.0)
	root.scale = Vector3(1.25, 1.25, 1.25)
	add_child(root)
	var stone := MAT_STONE_CASTLE
	var light := Color("#a8b4ae")
	var dark := Color("#4a5550")
	var roof := MAT_ROOF
	var glow := Color("#ffd98a")
	# Two visible heraldic banners add a focal point to the front towers.
	for side_x in [-4.8, 4.8]:
		_box(root, Vector3(side_x, 10.8, 4.8), Vector3(0.12, 2.6, 0.12), Color("#5c4430"))
		_box(root, Vector3(side_x + 0.52, 10.45, 4.8), Vector3(0.95, 1.25, 0.08), Color("#a83e35"))
		_box(root, Vector3(side_x + 0.52, 10.45, 4.74), Vector3(0.22, 0.82, 0.06), Color("#e8c46f"))
	_box(root, Vector3(0, 1.5, -2), Vector3(16, 3.2, 12), MAT_STONE)
	_box(root, Vector3(0, 3.2, -2), Vector3(14, 0.5, 10), MAT_GRASS)
	_box(root, Vector3(0, 5.0, 3.5), Vector3(12, 3.5, 1.4), stone)
	_box(root, Vector3(-6.2, 5.0, -1), Vector3(1.4, 3.5, 10), stone)
	_box(root, Vector3(6.2, 5.0, -1), Vector3(1.4, 3.5, 10), stone)
	for i in range(9):
		_box(root, Vector3(-5.0 + float(i) * 1.25, 7.0, 4.0), Vector3(0.55, 0.7, 0.5), light)
	_box(root, Vector3(0, 4.2, 4.2), Vector3(2.8, 2.6, 0.5), dark)
	# Deep-set gate frame, layered arch voussoirs and stone pilasters give the
	# entrance a readable architectural silhouette instead of a flat cut-out.
	for side_x in [-1.75, 1.75]:
		_box(root, Vector3(side_x, 4.25, 4.58), Vector3(0.42, 3.15, 0.34), light)
		_box(root, Vector3(side_x * 1.10, 5.9, 4.58), Vector3(0.62, 0.30, 0.42), Color("#c0c6bb"))
	for arch_i in range(7):
		var arch_x := -1.55 + float(arch_i) * 0.52
		_box(root, Vector3(arch_x, 5.58, 4.58), Vector3(0.42, 0.34, 0.34), light)
	for side_x in [-6.5, 6.5]:
		# Vertical corner quoins and narrow arrow slits break up tower mass.
		for level in range(5):
			_box(root, Vector3(side_x + (0.82 if side_x < 0.0 else -0.82), 3.8 + float(level) * 1.25, 4.02), Vector3(0.34, 0.88, 0.16), Color("#b2b9af"))
		_box(root, Vector3(side_x, 8.1, 4.52), Vector3(0.32, 1.05, 0.14), Color("#263a45"))
		_box(root, Vector3(side_x, 8.65, 4.60), Vector3(0.46, 0.12, 0.12), Color("#d7c8a0"))
	for i in range(6):
		_box(root, Vector3(-1.0 + float(i) * 0.4, 4.3, 4.35), Vector3(0.1, 2.2, 0.08), Color("#2a2a2a"))
	for side_x in [-6.5, 6.5]:
		for side_z in [3.0, -5.0]:
			_box(root, Vector3(side_x, 6.5, side_z), Vector3(2.8, 7.0, 2.8), stone)
			_box(root, Vector3(side_x, 10.2, side_z), Vector3(3.2, 0.4, 3.2), roof)
			_box(root, Vector3(side_x, 10.7, side_z), Vector3(2.0, 0.8, 2.0), roof.darkened(0.1))
			_pyramid(root, Vector3(side_x, 12.0, side_z), 1.75, 2.8, Color("#75443a"))
			_box(root, Vector3(side_x, 13.55, side_z), Vector3(0.18, 0.85, 0.18), Color("#f2cf83"), 0.28)
			_box(root, Vector3(side_x, 11.3, side_z), Vector3(0.3, 0.7, 0.3), Color("#f6d78c"), 0.25)
			_box(root, Vector3(side_x + (0.1 if side_x > 0 else -0.1), 5.5, side_z + (1.45 if side_z > 0 else -1.45)), Vector3(0.5, 0.7, 0.12), glow, 0.3)
			_box(root, Vector3(side_x + (0.1 if side_x > 0 else -0.1), 7.5, side_z + (1.45 if side_z > 0 else -1.45)), Vector3(0.5, 0.7, 0.12), glow, 0.3)
	_box(root, Vector3(0, 7.0, -2.5), Vector3(6.5, 8.0, 5.5), stone)
	_box(root, Vector3(0, 11.5, -2.5), Vector3(7.2, 0.45, 6.2), roof)
	_box(root, Vector3(0, 13.0, -2.5), Vector3(3.0, 3.5, 3.0), light)
	_box(root, Vector3(0, 15.0, -2.5), Vector3(3.6, 0.4, 3.6), roof)
	_box(root, Vector3(0, 15.5, -2.5), Vector3(1.8, 0.9, 1.8), roof.darkened(0.12))
	_box(root, Vector3(0, 16.2, -2.5), Vector3(0.25, 0.8, 0.25), Color("#f6d78c"), 0.25)
	_pyramid(root, Vector3(0, 18.2, -2.5), 2.1, 4.2, Color("#6f3e35"))
	_box(root, Vector3(0, 20.45, -2.5), Vector3(0.16, 0.9, 0.16), Color("#f4d68e"), 0.25)
	for side_x in [-6.5, 6.5]:
		for crenel in range(5):
			_box(root, Vector3(side_x, 9.0, -4.5 + float(crenel) * 1.75), Vector3(0.62, 0.72, 0.62), light)
		_box(root, Vector3(side_x, 7.2, 4.45), Vector3(0.20, 1.8, 0.18), dark)
	for win_x in [-3.8, -2.5, 2.5, 3.8]:
		_box(root, Vector3(win_x, 8.8, 0.34), Vector3(0.48, 0.95, 0.12), Color("#253744"))
		_box(root, Vector3(win_x, 9.3, 0.42), Vector3(0.58, 0.12, 0.14), light)
	for level in range(4):
		_box(root, Vector3(0, 4.5 + float(level) * 1.7, 0.3), Vector3(0.55, 0.75, 0.12), glow, 0.35)
		_box(root, Vector3(-1.8, 4.5 + float(level) * 1.7, 0.3), Vector3(0.4, 0.6, 0.12), glow, 0.35)
		_box(root, Vector3(1.8, 4.5 + float(level) * 1.7, 0.3), Vector3(0.4, 0.6, 0.12), glow, 0.35)
	# Layered facade courses, lit arrow windows and roof-edge stonework
	# break up the broad wall planes at the new right-of-centre composition.
	for course in range(5):
		var y := 3.7 + float(course) * 1.45
		_box(root, Vector3(0, y, 4.28), Vector3(10.8, 0.12, 0.18), Color("#b8c0b4"))
	for window_x in [-4.8, -3.2, 3.2, 4.8]:
		_box(root, Vector3(window_x, 6.5, 4.38), Vector3(0.52, 1.05, 0.12), Color("#263b48"))
		_box(root, Vector3(window_x, 6.5, 4.46), Vector3(0.22, 0.78, 0.04), Color("#f4c56f"), 0.3)
		_box(root, Vector3(window_x, 7.08, 4.50), Vector3(0.72, 0.12, 0.14), light)
	for side_x in [-8.0, 8.0]:
		for level in range(3):
			_box(root, Vector3(side_x, 2.9 + float(level) * 1.4, 3.75), Vector3(0.52, 0.62, 0.36), Color("#c2c8bc"))
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
	_box(ledge, Vector3(-9.0, 1.75, 13.0), Vector3(5.0, 1.5, 5.0), MAT_GRASS)
	_box(ledge, Vector3(-9.0, 0.5, 13.0), Vector3(5.2, 1.0, 5.2), MAT_STONE)
	var hero := Node3D.new()
	hero.name = "Protagonist"
	hero.position = Vector3(-9.0, 2.5, 13.0)
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
