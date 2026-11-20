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
	_build_terrain_art_pass()
	# Use the connected alpine ridges as the sole mountain skyline; the old
	# repeated cone layer made the panorama look like a row of identical peaks.
	_build_mountain_ridge_art_pass()
	_build_sunset_disc()
	_build_sky_clouds()
	_build_river_and_bridge()
	_build_village()
	_build_village_details()
	_build_village_architecture_pass()
	_build_forests()
	# Floating islands were removed: they read as disconnected debris in the menu skyline.
	_build_gatehouse_castle()
	_build_castle_surface_details()
	_build_landmark_details()
	_build_castle_compound_pass()
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
	environment.ambient_light_energy = 0.30
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
	fill.light_energy = 0.20
	add_child(fill)

func _setup_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "MenuWorldCamera"
	# Pull the panorama camera back and above the near forest canopy. This
	# keeps the protagonist in the left foreground while revealing the river,
	# village, gatehouse and softened mountain ridges behind the menu UI.
	camera.position = Vector3(-17.0, 8.5, 29.0)
	camera.rotation_degrees = Vector3(-15.0, -34.0, 0.0)
	camera.fov = 55.0
	camera.near = 0.1
	camera.far = 200.0
	camera.current = true
	add_child(camera)

func _build_landscape() -> void:
	# A buried backing plane prevents sky leaks at the panorama edge. The visible
	# meadow is generated by TerrainArtPass, not by overlapping green box slabs.
	var ground := Node3D.new()
	ground.name = "Landscape"
	add_child(ground)
	_box(ground, Vector3(0, -2.8, 0), Vector3(84, 1.0, 84), MAT_GRASS)

func _build_terrain_art_pass() -> void:
	# A vertex-coloured rolling terrain mesh replaces the broad flat green menu slab.
	# The higher-resolution surface adds visible rolling relief while flattening
	# locally beneath the village and castle footprints.
	var terrain := MeshInstance3D.new()
	terrain.name = "TerrainArtPass"
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	const GRID := 72
	const EXTENT := 40.0
	for z in range(GRID + 1):
		for x in range(GRID + 1):
			var px := -EXTENT + float(x) * (EXTENT * 2.0 / float(GRID))
			var pz := -EXTENT + float(z) * (EXTENT * 2.0 / float(GRID))
			var rolling := sin(px * 0.19 + pz * 0.08) * 0.52 + cos(pz * 0.16 - px * 0.05) * 0.34 + sin(px * 0.075 + pz * 0.12) * 0.22
			var bank := exp(-pow((px - 4.5) / 7.5, 2.0) - pow((pz + 8.0) / 25.0, 2.0)) * 0.28
			# A broad, subtle natural rise under the hero keeps the silhouette
			# above the lower feature-card edge without a visible floating plinth.
			var hero_perch := exp(-pow((px + 9.0) / 3.2, 2.0) - pow((pz - 13.0) / 3.0, 2.0)) * 0.75
			var building_mask := 1.0
			for landmark in [Vector2(18.0, -5.0), Vector2(30.0, -18.0)]:
				var landmark_distance := Vector2(px - landmark.x, pz - landmark.y).length()
				building_mask = minf(building_mask, smoothstep(3.0, 10.0, landmark_distance))
			vertices.append(Vector3(px, 0.025 + (rolling + bank + hero_perch) * lerpf(0.28, 1.0, building_mask), pz))
			var variation := sin(px * 0.31) * cos(pz * 0.27) + sin(px * 0.13 + pz * 0.21) * 0.35
			var base := Color("#356d3b").lerp(Color("#8bb653"), clampf(0.5 + variation * 0.30, 0.0, 1.0))
			if absf(pz - (sin(px * 0.11) * 8.0 + cos(px * 0.04) * 3.0)) < 5.0:
				base = base.lerp(Color("#b59a69"), 0.32)
			colors.append(base)
	for z in range(GRID):
		for x in range(GRID):
			var a := z * (GRID + 1) + x
			var b := a + 1
			var d := a + GRID + 1
			var e := d + 1
			indices.append_array(PackedInt32Array([a, d, b, b, d, e]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	terrain.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	terrain.material_override = mat
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(terrain)

	# A layered dirt-and-stone footpath ties the village to the bridge.
	var path := Node3D.new()
	path.name = "VillageFootpath"
	path.position = Vector3(13.0, 0.18, -3.5)
	path.rotation.y = deg_to_rad(-8.0)
	add_child(path)
	for i in range(13):
		var z := float(i) * 1.25
		var width := 1.35 + sin(float(i) * 0.55) * 0.18
		_box(path, Vector3(sin(float(i) * 0.22) * 0.42, 0.0, z), Vector3(width, 0.10, 1.05), Color("#a98a62") if i % 3 else Color("#c1a477"))
		if i % 2 == 0:
			_box(path, Vector3(-0.9 + sin(float(i)) * 0.2, 0.04, z + 0.28), Vector3(0.24, 0.12, 0.30), Color("#8a8a78"))

	# Low rock clusters and ground cover provide scale transitions at the meadow edge.
	for i in range(18):
		var x := -25.0 + float((i * 17) % 47)
		var z := 4.0 + float((i * 11) % 24)
		if absf(x + 9.0) < 4.0 and z > 10.0:
			continue
		var rock := MeshInstance3D.new()
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = 0.5
		rock_mesh.height = 0.72
		rock_mesh.radial_segments = 8
		rock_mesh.rings = 5
		rock.mesh = rock_mesh
		rock.position = Vector3(x, 0.18, z)
		rock.scale = Vector3(0.55 + float(i % 3) * 0.16, 0.55, 0.7 + float(i % 2) * 0.18)
		rock.material_override = _material(Color("#68736c") if i % 2 == 0 else Color("#817e70"), 0.96)
		add_child(rock)

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


func _build_mountain_ridge_art_pass() -> void:
	# Connected alpine ridgelines create a continuous skyline behind the older
	# peak silhouettes. Height samples form several asymmetric summits and
	# saddles; vertex colours separate forest foothills, exposed rock and snow.
	var root := Node3D.new()
	root.name = "ConnectedMountainRidges"
	add_child(root)
	var ridge_specs := [
		{"z": -50.0, "base": 1.5, "height": 19.0, "phase": 0.0, "color": Color("#536c79")},
		{"z": -59.0, "base": 0.0, "height": 24.0, "phase": 2.2, "color": Color("#405a6b")},
		{"z": -68.0, "base": -0.8, "height": 27.0, "phase": 4.1, "color": Color("#617782")}
	]
	for ridge_index in range(ridge_specs.size()):
		var spec: Dictionary = ridge_specs[ridge_index]
		var vertices := PackedVector3Array()
		var colors := PackedColorArray()
		var indices := PackedInt32Array()
		const SEGMENTS := 64
		const DEPTH_ROWS := 5
		for row in range(DEPTH_ROWS):
			var depth_t := float(row) / float(DEPTH_ROWS - 1)
			for segment in range(SEGMENTS + 1):
				var t := float(segment) / float(SEGMENTS)
				var x := -52.0 + t * 104.0
				var envelope := 0.50 + 0.50 * sin(PI * t)
				var peaks := 0.0
				for peak_spec in [[-0.78, 0.78, 0.13], [-0.48, 0.54, 0.10], [-0.12, 1.0, 0.12], [0.22, 0.68, 0.09], [0.57, 0.92, 0.12], [0.84, 0.48, 0.08]]:
					var distance := (t - float(peak_spec[0])) / float(peak_spec[2])
					peaks = maxf(peaks, float(peak_spec[1]) * exp(-distance * distance * 0.5))
				var serration := (sin(t * 93.0 + float(spec["phase"])) * 0.035 + sin(t * 171.0 + float(spec["phase"]) * 1.7) * 0.018) * envelope
				var height := float(spec["base"]) + float(spec["height"]) * (peaks * envelope + serration)
				var z := float(spec["z"]) - depth_t * (5.0 + ridge_index * 1.5)
				var side_drop := absf(depth_t - 0.5) * 0.22
				vertices.append(Vector3(x, height - side_drop, z))
				var rock: Color = spec["color"]
				var facet := 0.5 + 0.5 * sin(t * 137.0 + depth_t * 8.0 + ridge_index)
				var color := rock.lerp(Color("#89969a"), facet * 0.24)
				if height > 15.0 + ridge_index * 1.3:
					color = color.lerp(Color("#e1e8e4"), clampf((height - 15.0 - ridge_index * 1.3) / 8.0, 0.0, 0.92))
				elif height < 6.0:
					color = color.lerp(Color("#42664f"), 0.72)
				colors.append(color)
		for row in range(DEPTH_ROWS - 1):
			for segment in range(SEGMENTS):
				var a := row * (SEGMENTS + 1) + segment
				var b := a + 1
				var d := a + SEGMENTS + 1
				var e := d + 1
				indices.append_array(PackedInt32Array([a, b, d, b, e, d]))
		var normals := PackedVector3Array()
		normals.resize(vertices.size())
		for index_offset in range(0, indices.size(), 3):
			var ia := indices[index_offset]
			var ib := indices[index_offset + 1]
			var ic := indices[index_offset + 2]
			var face_normal := (vertices[ib] - vertices[ia]).cross(vertices[ic] - vertices[ia])
			normals[ia] += face_normal
			normals[ib] += face_normal
			normals[ic] += face_normal
		for normal_index in range(normals.size()):
			normals[normal_index] = normals[normal_index].normalized()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var ridge := MeshInstance3D.new()
		ridge.name = "ConnectedAlpineRidge_%d" % ridge_index
		ridge.mesh = mesh
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.98
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		ridge.material_override = material
		ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ridge)

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
	var cloud_material := _material(Color("#fff0e2"), 0.96)
	var lobe_offsets := [-0.30, 0.0, 0.28, -0.12, 0.18]
	var lobe_widths := [0.34, 0.42, 0.32, 0.26, 0.24]
	var lobe_heights := [0.70, 0.92, 0.72, 0.62, 0.60]
	for spec in cloud_specs:
		var base_position: Vector3 = spec[0]
		var base_size: Vector3 = spec[1]
		for lobe_index in range(lobe_offsets.size()):
			var puff := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 1.0
			sphere.height = 2.0
			sphere.radial_segments = 16
			sphere.rings = 10
			puff.mesh = sphere
			puff.position = base_position + Vector3(base_size.x * lobe_offsets[lobe_index], base_size.y * (0.10 if lobe_index == 1 else 0.0), 0.0)
			puff.scale = Vector3(base_size.x * lobe_widths[lobe_index], base_size.y * lobe_heights[lobe_index], base_size.z * 0.48)
			puff.material_override = cloud_material
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			clouds.add_child(puff)

func _pyramid(parent: Node3D, position: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	# Faceted multi-ring mountain mesh: broad shoulders, broken ridge lines and
	# irregular rock facets replace the old straight-sided cone silhouette.
	var spire := MeshInstance3D.new()
	spire.name = "FacetedLandform"
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS := 18
	var ring_radii := [1.0, 0.84, 0.62, 0.39, 0.17]
	var ring_heights := [0.0, 0.20, 0.46, 0.73, 1.0]
	for ring in range(ring_radii.size() - 1):
		for segment in range(SEGMENTS):
			var angle_a := TAU * float(segment) / float(SEGMENTS)
			var angle_b := TAU * float(segment + 1) / float(SEGMENTS)
			var jitter_a := 1.0 + sin(float(segment) * 4.13 + position.x * 0.17) * 0.055
			var jitter_b := 1.0 + sin(float(segment + 1) * 4.13 + position.x * 0.17) * 0.055
			var lower_a := Vector3(cos(angle_a) * radius * ring_radii[ring] * jitter_a, height * ring_heights[ring], sin(angle_a) * radius * ring_radii[ring] * jitter_a)
			var lower_b := Vector3(cos(angle_b) * radius * ring_radii[ring] * jitter_b, height * ring_heights[ring], sin(angle_b) * radius * ring_radii[ring] * jitter_b)
			var upper_a := Vector3(cos(angle_a) * radius * ring_radii[ring + 1] * jitter_a, height * ring_heights[ring + 1], sin(angle_a) * radius * ring_radii[ring + 1] * jitter_a)
			var upper_b := Vector3(cos(angle_b) * radius * ring_radii[ring + 1] * jitter_b, height * ring_heights[ring + 1], sin(angle_b) * radius * ring_radii[ring + 1] * jitter_b)
			var facet := color.darkened(float((segment + ring * 3) % 5) * 0.035)
			if segment % 6 == 0:
				facet = facet.lightened(0.10)
			surface.set_color(facet)
			surface.add_vertex(lower_a)
			surface.set_color(facet.darkened(0.025))
			surface.add_vertex(lower_b)
			surface.set_color(facet.lightened(0.035))
			surface.add_vertex(upper_b)
			surface.set_color(facet)
			surface.add_vertex(lower_a)
			surface.set_color(facet.lightened(0.035))
			surface.add_vertex(upper_b)
			surface.set_color(facet.lightened(0.06))
			surface.add_vertex(upper_a)
	surface.generate_normals()
	var mesh := surface.commit()
	spire.mesh = mesh
	spire.position = position
	spire.rotation.y = PI * 0.25
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	spire.material_override = material
	parent.add_child(spire)
	return spire

func _build_river_and_bridge() -> void:
	# The menu river is a single curved, vertex-coloured ribbon rather than a
	# rectangular water slab. A modest segment count keeps this panorama cheap.
	var water := Node3D.new()
	water.name = "River"
	add_child(water)
	const SEGMENTS := 72
	var river_vertices := PackedVector3Array()
	var river_normals := PackedVector3Array()
	var river_colors := PackedColorArray()
	var river_uvs := PackedVector2Array()
	var river_indices := PackedInt32Array()
	var bank_vertices := PackedVector3Array()
	var bank_normals := PackedVector3Array()
	var bank_colors := PackedColorArray()
	var bank_indices := PackedInt32Array()
	for segment in range(SEGMENTS + 1):
		var t := float(segment) / float(SEGMENTS)
		var z := 18.0 - t * 52.0
		# Keep the bridge crossing centred while the channel bends gently away
		# from it in both directions.
		var center_x := 4.5 + sin((z - 3.0) * 0.065) * 1.35 + sin((z - 3.0) * 0.13) * 0.30
		var half_width := 2.75 + sin(t * TAU * 1.15) * 0.22 + cos(t * TAU * 2.1) * 0.12
		for side in [-1.0, 1.0]:
			var edge_x: float = center_x + float(side) * half_width
			var ripple := sin(t * TAU * 3.0 + side) * 0.018
			river_vertices.append(Vector3(edge_x, 0.22 + ripple, z))
			river_normals.append(Vector3.UP)
			var depth_tint := 0.5 + 0.5 * sin(t * TAU * 2.0 + side * 0.35)
			river_colors.append(Color(0.10 + depth_tint * 0.025, 0.42 + depth_tint * 0.08, 0.62 + depth_tint * 0.10, 0.94))
			river_uvs.append(Vector2(0.0 if side < 0.0 else 1.0, t * 8.0))
			# Each bank is a narrow, irregular sand-to-grass transition strip.
			bank_vertices.append(Vector3(edge_x, 0.18, z))
			bank_normals.append(Vector3.UP)
			bank_colors.append(Color("#c6ae7c"))
			bank_vertices.append(Vector3(edge_x + side * (0.9 + sin(t * TAU * 1.7) * 0.12), 0.11, z))
			bank_normals.append(Vector3.UP)
			bank_colors.append(Color("#6f9856"))
		if segment < SEGMENTS:
			var a := segment * 2
			var b := a + 1
			var c := a + 2
			var d := a + 3
			river_indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
			# Two independent bank ribbons share one mesh and one draw call.
			var bank_a := segment * 4
			# Connect each bank's inner/outer edge to the next river sample.
			bank_indices.append_array(PackedInt32Array([bank_a, bank_a + 4, bank_a + 1, bank_a + 1, bank_a + 4, bank_a + 5]))
			bank_indices.append_array(PackedInt32Array([bank_a + 2, bank_a + 3, bank_a + 6, bank_a + 3, bank_a + 7, bank_a + 6]))
	var river_arrays := []
	river_arrays.resize(Mesh.ARRAY_MAX)
	river_arrays[Mesh.ARRAY_VERTEX] = river_vertices
	river_arrays[Mesh.ARRAY_NORMAL] = river_normals
	river_arrays[Mesh.ARRAY_COLOR] = river_colors
	river_arrays[Mesh.ARRAY_TEX_UV] = river_uvs
	river_arrays[Mesh.ARRAY_INDEX] = river_indices
	var river_mesh := ArrayMesh.new()
	river_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, river_arrays)
	var river := MeshInstance3D.new()
	river.name = "RiverSurface"
	river.mesh = river_mesh
	var water_material := _material(Color.WHITE, 0.12, 0.16)
	water_material.vertex_color_use_as_albedo = true
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.emission_enabled = true
	water_material.emission = Color(0.035, 0.11, 0.16)
	water_material.emission_energy_multiplier = 0.08
	river.material_override = water_material
	river.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.add_child(river)
	var bank_arrays := []
	bank_arrays.resize(Mesh.ARRAY_MAX)
	bank_arrays[Mesh.ARRAY_VERTEX] = bank_vertices
	bank_arrays[Mesh.ARRAY_NORMAL] = bank_normals
	bank_arrays[Mesh.ARRAY_COLOR] = bank_colors
	bank_arrays[Mesh.ARRAY_INDEX] = bank_indices
	var bank_mesh := ArrayMesh.new()
	bank_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bank_arrays)
	var banks := MeshInstance3D.new()
	banks.name = "RiverBanks"
	banks.mesh = bank_mesh
	var bank_material := _material(Color.WHITE, 0.96)
	bank_material.vertex_color_use_as_albedo = true
	bank_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	banks.material_override = bank_material
	banks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.add_child(banks)
	# Four low-profile foam streaks follow the channel instead of spanning it
	# as full-width rectangular bars.
	var foam_material := _material(Color(0.82, 0.94, 0.98, 0.42), 0.22)
	foam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for foam_index in range(4):
		var foam_t := 0.18 + float(foam_index) * 0.19
		var foam_z := 18.0 - foam_t * 52.0
		var foam_x := 4.5 + sin((foam_z - 3.0) * 0.065) * 1.35 + sin((foam_z - 3.0) * 0.13) * 0.30
		var streak := MeshInstance3D.new()
		var streak_mesh := BoxMesh.new()
		streak_mesh.size = Vector3(0.9 + float(foam_index % 2) * 0.45, 0.025, 0.12)
		streak.mesh = streak_mesh
		streak.position = Vector3(foam_x + sin(float(foam_index)) * 0.55, 0.16, foam_z)
		streak.rotation.y = deg_to_rad(-8.0 + float(foam_index) * 5.0)
		streak.material_override = foam_material
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		water.add_child(streak)
	# The timber crossing remains aligned with the river's centreline.
	_box(water, Vector3(1.2, 0.45, 3), Vector3(1.0, 0.18, 7), MAT_WOOD)
	_box(water, Vector3(5.8, 0.45, 3), Vector3(1.0, 0.18, 7), MAT_WOOD)
	_box(water, Vector3(3.5, 0.6, 3), Vector3(5.5, 0.14, 1.8), MAT_WOOD)
	for xz in [[1.2, 0.5], [5.8, 0.5], [1.2, 5.5], [5.8, 5.5]]:
		_box(water, Vector3(xz[0], 1.0, xz[1]), Vector3(0.12, 1.0, 0.12), MAT_WOOD)

func _build_village() -> void:
	var village := Node3D.new()
	village.name = "Village"
	village.position = Vector3(-1.5, 0.0, 0.5)
	village.scale = Vector3.ONE * 1.28
	add_child(village)

	# Three small neighbourhoods replace the former nine-copy cottage row.
	# Each group has a distinct footprint, roof language and facade material.
	var group_specs := [
		{
			"name": "CottageQuarter",
			"style": 0,
			"positions": [Vector3(7.0, 0.0, -1.5), Vector3(10.5, 0.0, -6.0), Vector3(7.5, 0.0, -10.5)],
			"rotations": [0.0, -0.12, 0.10]
		},
		{
			"name": "LonghouseQuarter",
			"style": 1,
			"positions": [Vector3(15.5, 0.0, -2.0), Vector3(19.5, 0.0, -7.0), Vector3(15.5, 0.0, -11.5)],
			"rotations": [0.08, -0.08, 0.16]
		},
		{
			"name": "StoneTowerQuarter",
			"style": 2,
			"positions": [Vector3(24.0, 0.0, -1.5), Vector3(28.0, 0.0, -6.5), Vector3(24.5, 0.0, -11.5)],
			"rotations": [-0.08, 0.12, -0.14]
		}
	]
	for group_spec_variant in group_specs:
		var group_spec: Dictionary = group_spec_variant
		var group := Node3D.new()
		group.name = str(group_spec["name"])
		group.set_meta("architecture_style", int(group_spec["style"]))
		village.add_child(group)
		var positions: Array = group_spec["positions"]
		var rotations: Array = group_spec["rotations"]
		for house_index in range(positions.size()):
			var house_position: Vector3 = positions[house_index]
			var house_rotation := float(rotations[house_index])
			_build_village_house(group, "%s_%02d" % [group.name, house_index + 1],
				int(group_spec["style"]), house_position, house_rotation)

func _build_village_house(parent: Node3D, house_name: String, style: int, position: Vector3, rotation_y: float) -> void:
	var house := Node3D.new()
	house.name = house_name
	house.position = position
	house.rotation.y = rotation_y
	house.set_meta("architecture_style", style)
	parent.add_child(house)

	var wood := Color("#563d2b")
	var trim := Color("#e2c99c")
	var stone := Color("#858b80")
	var roof_a := Color("#96523d")
	var roof_b := Color("#bd7650")
	var wall := MAT_WALL
	var footprint_size := Vector3(2.9, 0.22, 2.55)
	var footprint := _box(house, Vector3(0.0, 0.11, 0.0), footprint_size, stone)
	footprint.name = "Footprint"

	match style:
		0:
			# Compact plaster cottage: a steep gable, exposed timber frame and
			# offset chimney create the small rural-house silhouette.
			_box(house, Vector3(0.0, 1.05, 0.0), Vector3(2.55, 1.82, 2.25), wall)
			for side_x in [-0.94, 0.94]:
				_box(house, Vector3(side_x, 1.05, 1.14), Vector3(0.12, 1.78, 0.12), wood)
			_box(house, Vector3(0.0, 1.88, 1.16), Vector3(2.48, 0.12, 0.12), wood)
			var roof := Node3D.new()
			roof.name = "Roof_Gable"
			house.add_child(roof)
			var left_roof := _box(roof, Vector3(-0.68, 2.20, 0.0), Vector3(1.82, 0.18, 2.78), roof_a)
			left_roof.rotation.z = deg_to_rad(-27.0)
			var right_roof := _box(roof, Vector3(0.68, 2.20, 0.0), Vector3(1.82, 0.18, 2.78), roof_b)
			right_roof.rotation.z = deg_to_rad(27.0)
			_box(roof, Vector3(0.0, 2.57, 0.0), Vector3(0.18, 0.16, 2.86), Color("#d08a5c"))
			_box(house, Vector3(-0.88, 2.45, -0.66), Vector3(0.40, 0.92, 0.40), Color("#755344"))
			_box(house, Vector3(0.0, 0.72, 1.18), Vector3(0.58, 1.42, 0.10), wood)
			for side_x in [-0.76, 0.76]:
				_box(house, Vector3(side_x, 1.42, 1.19), Vector3(0.44, 0.48, 0.07), Color("#8bc5d0"), 0.3)
				_box(house, Vector3(side_x, 1.42, 1.24), Vector3(0.06, 0.52, 0.06), trim)
		1:
			# Broad timber longhouse: a stone lower storey, framed upper level,
			# four-sided roof and covered porch distinguish the market street.
			footprint_size = Vector3(3.72, 0.24, 2.82)
			footprint.mesh.size = footprint_size
			footprint.position.y = 0.12
			_box(house, Vector3(0.0, 0.88, 0.0), Vector3(3.42, 1.52, 2.48), Color("#a99a7a"))
			_box(house, Vector3(0.0, 1.88, 0.0), Vector3(3.18, 0.70, 2.30), Color("#d0b88b"))
			for side_x in [-1.42, -0.48, 0.48, 1.42]:
				_box(house, Vector3(side_x, 1.88, 1.17), Vector3(0.12, 0.78, 0.12), wood)
			_box(house, Vector3(0.0, 1.52, 1.22), Vector3(3.18, 0.12, 0.12), wood)
			var roof := Node3D.new()
			roof.name = "Roof_Hipped"
			house.add_child(roof)
			var left_roof := _box(roof, Vector3(-0.78, 2.48, 0.0), Vector3(2.12, 0.18, 2.92), roof_a)
			left_roof.rotation.z = deg_to_rad(-23.0)
			var right_roof := _box(roof, Vector3(0.78, 2.48, 0.0), Vector3(2.12, 0.18, 2.92), roof_b)
			right_roof.rotation.z = deg_to_rad(23.0)
			var front_hip := _box(roof, Vector3(0.0, 2.48, 0.94), Vector3(3.54, 0.16, 1.28), Color("#a55e43"))
			front_hip.rotation.x = deg_to_rad(22.0)
			var rear_hip := _box(roof, Vector3(0.0, 2.48, -0.94), Vector3(3.54, 0.16, 1.28), Color("#89503d"))
			rear_hip.rotation.x = deg_to_rad(-22.0)
			_box(roof, Vector3(0.0, 2.83, 0.0), Vector3(0.20, 0.14, 2.70), Color("#d29a68"))
			_box(house, Vector3(0.0, 0.70, 1.30), Vector3(0.66, 1.38, 0.10), wood)
			for side_x in [-1.02, 1.02]:
				_box(house, Vector3(side_x, 1.88, 1.20), Vector3(0.48, 0.48, 0.07), Color("#82b9c4"), 0.3)
				_box(house, Vector3(side_x, 1.88, 1.25), Vector3(0.06, 0.54, 0.06), trim)
			for side_x in [-1.24, 1.24]:
				_box(house, Vector3(side_x, 0.98, 1.55), Vector3(0.14, 1.82, 0.14), wood)
			_box(house, Vector3(0.0, 1.90, 1.57), Vector3(2.72, 0.14, 0.86), roof_a)
			_box(house, Vector3(-1.36, 2.44, -0.62), Vector3(0.40, 0.90, 0.40), Color("#765342"))
		2:
			# Narrow stone tower-house: tall masonry, arrow windows and a
			# crenellated parapet replace the cottage roof profile entirely.
			footprint_size = Vector3(2.30, 0.24, 2.12)
			footprint.mesh.size = footprint_size
			footprint.position.y = 0.12
			_box(house, Vector3(0.0, 1.43, 0.0), Vector3(2.16, 2.66, 2.08), Color("#a9afa5"))
			for side_x in [-1.02, 1.02]:
				for side_z in [-0.92, 0.92]:
					_box(house, Vector3(side_x, 1.42, side_z), Vector3(0.18, 2.72, 0.18), Color("#777f78"))
			_box(house, Vector3(0.0, 2.82, 0.0), Vector3(2.52, 0.22, 2.42), trim)
			var roof := Node3D.new()
			roof.name = "Roof_Parapet"
			house.add_child(roof)
			for crenel_x in [-0.88, 0.0, 0.88]:
				_box(roof, Vector3(crenel_x, 3.22, 1.02), Vector3(0.34, 0.58, 0.34), stone)
				_box(roof, Vector3(crenel_x, 3.22, -1.02), Vector3(0.34, 0.58, 0.34), stone)
			for crenel_z in [-0.52, 0.52]:
				_box(roof, Vector3(-1.08, 3.22, crenel_z), Vector3(0.34, 0.58, 0.34), stone)
				_box(roof, Vector3(1.08, 3.22, crenel_z), Vector3(0.34, 0.58, 0.34), stone)
			_box(roof, Vector3(0.0, 3.40, 0.0), Vector3(1.08, 0.56, 1.08), Color("#68756f"))
			_pyramid(roof, Vector3(0.0, 3.82, 0.0), 0.72, 0.92, roof_a)
			_box(house, Vector3(0.0, 0.72, 1.08), Vector3(0.56, 1.42, 0.10), wood)
			for side_x in [-0.62, 0.62]:
				_box(house, Vector3(side_x, 2.05, 1.08), Vector3(0.30, 0.88, 0.08), Color("#253b49"))
				_box(house, Vector3(side_x, 2.08, 1.14), Vector3(0.12, 0.68, 0.04), Color("#f0c47b"), 0.3)
			_box(house, Vector3(1.22, 1.72, 0.0), Vector3(0.28, 0.50, 0.28), Color("#ffd28a"), 0.25)

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

func _build_village_architecture_pass() -> void:
	var village := get_node_or_null("Village") as Node3D
	if village == null:
		return
	var cottage_group := village.get_node_or_null("CottageQuarter") as Node3D
	var longhouse_group := village.get_node_or_null("LonghouseQuarter") as Node3D
	var tower_group := village.get_node_or_null("StoneTowerQuarter") as Node3D
	if cottage_group == null or longhouse_group == null or tower_group == null:
		return

	# Give each neighbourhood one or two authored landmarks rather than
	# repeating the same dormer/balcony on every roof.
	var first_cottage := cottage_group.get_child(0) as Node3D
	if first_cottage:
		var dormer := Node3D.new()
		dormer.name = "CottageDormer"
		first_cottage.add_child(dormer)
		_box(dormer, Vector3(0.0, 2.40, -0.38), Vector3(0.68, 0.54, 0.52), Color("#d6c19a"))
		_box(dormer, Vector3(0.0, 2.70, -0.38), Vector3(0.88, 0.12, 0.70), Color("#8d4c39"))
	var second_cottage := cottage_group.get_child(1) as Node3D
	if second_cottage:
		_box(second_cottage, Vector3(0.0, 0.48, 1.34), Vector3(1.10, 0.28, 0.16), Color("#6d4a31"))
		for flower_x in [-0.36, 0.0, 0.36]:
			_box(second_cottage, Vector3(flower_x, 0.70, 1.34), Vector3(0.14, 0.18, 0.14), Color("#d97962") if flower_x < 0.0 else Color("#e5bd65"))
	var third_cottage := cottage_group.get_child(2) as Node3D
	if third_cottage:
		for fence_x in [-1.85, -1.25, -0.65]:
			_box(third_cottage, Vector3(fence_x, 0.42, 1.75), Vector3(0.08, 0.74, 0.08), Color("#785137"))
		_box(third_cottage, Vector3(-1.25, 0.66, 1.75), Vector3(1.28, 0.08, 0.08), Color("#b48a5a"))

	var first_longhouse := longhouse_group.get_child(0) as Node3D
	if first_longhouse:
		# A market awning and two timber braces make the first longhouse the
		# village's public-facing workshop rather than another cottage copy.
		_box(first_longhouse, Vector3(-1.05, 1.38, 1.70), Vector3(0.10, 0.72, 0.10), Color("#563d2b"))
		_box(first_longhouse, Vector3(1.05, 1.38, 1.70), Vector3(0.10, 0.72, 0.10), Color("#563d2b"))
		_box(first_longhouse, Vector3(0.0, 1.78, 1.70), Vector3(2.35, 0.12, 0.76), Color("#d2a16b"))
	var second_longhouse := longhouse_group.get_child(1) as Node3D
	if second_longhouse:
		_box(second_longhouse, Vector3(-1.90, 0.34, 1.35), Vector3(0.56, 0.50, 0.48), Color("#9a7048"))
		_box(second_longhouse, Vector3(-1.90, 0.62, 1.35), Vector3(0.62, 0.08, 0.54), Color("#c49a63"))
	var third_longhouse := longhouse_group.get_child(2) as Node3D
	if third_longhouse:
		for rail_x in [-1.20, -0.40, 0.40, 1.20]:
			_box(third_longhouse, Vector3(rail_x, 0.76, 1.74), Vector3(0.06, 0.66, 0.06), Color("#65442e"))
		_box(third_longhouse, Vector3(0.0, 1.08, 1.74), Vector3(2.56, 0.08, 0.08), Color("#b88a58"))

	var first_tower := tower_group.get_child(0) as Node3D
	if first_tower:
		_box(first_tower, Vector3(-1.34, 2.30, 0.0), Vector3(0.10, 1.10, 0.10), Color("#6a4a34"))
		_box(first_tower, Vector3(-1.62, 2.18, 0.0), Vector3(0.62, 0.78, 0.08), Color("#a64236"))
	var second_tower := tower_group.get_child(1) as Node3D
	if second_tower:
		_box(second_tower, Vector3(0.0, 3.62, -0.55), Vector3(0.12, 0.72, 0.12), Color("#d8bd7e"))
	var third_tower := tower_group.get_child(2) as Node3D
	if third_tower:
		# A stone well marks the small courtyard between the tower houses.
		_box(third_tower, Vector3(1.65, 0.28, 1.50), Vector3(0.92, 0.56, 0.92), Color("#7e8980"))
		_box(third_tower, Vector3(1.65, 0.62, 1.50), Vector3(1.10, 0.12, 1.10), Color("#c1b89f"))

func _build_forests() -> void:
	var forest := Node3D.new()
	forest.name = "Forests"
	add_child(forest)
	for i in range(14):
		# Preserve the established left-flank grove while the new right grove
		# balances the panorama and frames the village without hiding the river.
		var tx := -19.0 + float(i % 5) * 2.35 + sin(float(i) * 1.7) * 0.45
		var tz := -5.5 + float(i / 5) * 3.2 + cos(float(i) * 1.3) * 0.4
		var h := 1.8 + float(i % 4) * 0.35
		_box(forest, Vector3(tx, h * 0.5, tz), Vector3(0.32, h, 0.32), MAT_WOOD)
		_box(forest, Vector3(tx, h + 0.5, tz), Vector3(1.8, 1.2, 1.8), MAT_LEAF_DARK)
		_box(forest, Vector3(tx, h + 1.3, tz), Vector3(1.5, 1.1, 1.5), MAT_LEAF)
		_box(forest, Vector3(tx, h + 2.0, tz), Vector3(1.0, 0.9, 1.0), MAT_LEAF_LIGHT)
		if i % 3 == 0:
			_box(forest, Vector3(tx + 0.6, h + 0.9, tz - 0.4), Vector3(0.9, 0.8, 0.9), MAT_LEAF)

	# The previous menu composition left the entire right foreground as an
	# uninterrupted green plane. Add a second, deliberately broken grove on
	# the outer meadow edge; the centre path, river crossing and house fronts
	# remain open. Low-poly layered crowns retain the voxel game's visual style
	# without repeating identical cube stacks.
	var right_grove := Node3D.new()
	right_grove.name = "RightGrove"
	forest.add_child(right_grove)
	var trunk_material := _material(MAT_WOOD, 0.98)
	var canopy_materials := [
		_material(MAT_LEAF_DARK, 0.98),
		_material(MAT_LEAF, 0.98),
		_material(MAT_LEAF_LIGHT, 0.98)
	]
	var tree_positions := [
		Vector3(8.0, 0.0, 9.0), Vector3(13.0, 0.0, 12.0),
		Vector3(18.0, 0.0, 9.0), Vector3(22.0, 0.0, 14.0),
		Vector3(27.0, 0.0, 10.0), Vector3(11.0, 0.0, 18.0),
		Vector3(16.0, 0.0, 22.0), Vector3(21.0, 0.0, 19.0),
		Vector3(26.0, 0.0, 23.0), Vector3(7.5, 0.0, 23.0),
		Vector3(30.0, 0.0, 18.0), Vector3(32.0, 0.0, 11.0)
	]
	for tree_index in range(tree_positions.size()):
		_add_menu_grove_tree(right_grove, tree_index, tree_positions[tree_index],
			0.82 + float((tree_index * 3) % 5) * 0.09, trunk_material, canopy_materials)


func _add_menu_grove_tree(parent: Node3D, tree_index: int, tree_position: Vector3,
		tree_scale: float, trunk_material: Material, canopy_materials: Array) -> void:
	var tree := Node3D.new()
	tree.name = "RightGroveTree_%02d" % tree_index
	tree.position = tree_position
	tree.scale = Vector3.ONE * tree_scale
	parent.add_child(tree)

	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.12
	trunk_mesh.bottom_radius = 0.20
	trunk_mesh.height = 2.8
	trunk_mesh.radial_segments = 7
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.4
	trunk.material_override = trunk_material
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	tree.add_child(trunk)

	var canopy_specs := [
		{"name": "Canopy_Core", "position": Vector3(0.0, 2.95, 0.0), "scale": Vector3(1.15, 1.0, 1.05), "material": 0},
		{"name": "Canopy_Left", "position": Vector3(-0.62, 2.78, 0.12), "scale": Vector3(0.82, 0.78, 0.82), "material": 1},
		{"name": "Canopy_Right", "position": Vector3(0.60, 2.84, -0.10), "scale": Vector3(0.84, 0.82, 0.78), "material": 1},
		{"name": "Canopy_Crown", "position": Vector3(0.0, 3.72, -0.04), "scale": Vector3(0.72, 0.70, 0.70), "material": 2}
	]
	for canopy_spec in canopy_specs:
		var canopy := MeshInstance3D.new()
		canopy.name = str(canopy_spec["name"])
		var canopy_mesh := SphereMesh.new()
		canopy_mesh.radius = 1.0
		canopy_mesh.height = 2.0
		canopy_mesh.radial_segments = 8
		canopy_mesh.rings = 5
		canopy.mesh = canopy_mesh
		canopy.position = canopy_spec["position"]
		canopy.scale = canopy_spec["scale"]
		canopy.material_override = canopy_materials[int(canopy_spec["material"])]
		canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		tree.add_child(canopy)

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
	root.position = Vector3(30.0, 0.2, -18.0)
	root.scale = Vector3(1.12, 1.12, 1.12)
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
		var tower_z := 3.0
		_box(root, Vector3(side_x, 6.5, tower_z), Vector3(2.8, 7.0, 2.8), stone)
		_box(root, Vector3(side_x, 10.2, tower_z), Vector3(3.2, 0.4, 3.2), roof)
		_box(root, Vector3(side_x, 10.7, tower_z), Vector3(2.0, 0.8, 2.0), roof.darkened(0.1))
		if side_x < 0.0:
			# West tower becomes a low crenellated watch platform rather than
			# repeating the same tall cone silhouette as the central spire.
			_box(root, Vector3(side_x, 11.25, tower_z), Vector3(2.45, 0.24, 2.45), light)
			for merlon_x in [-0.82, 0.0, 0.82]:
				_box(root, Vector3(side_x + merlon_x, 11.72, tower_z), Vector3(0.34, 0.72, 0.34), light)
			for merlon_z in [-0.82, 0.82]:
				_box(root, Vector3(side_x, 11.72, tower_z + merlon_z), Vector3(0.34, 0.72, 0.34), light)
		else:
			# East tower uses a stepped pavilion cap with a small lantern crown.
			for roof_tier in range(3):
				var half := 1.32 - float(roof_tier) * 0.30
				_box(root, Vector3(side_x, 11.20 + float(roof_tier) * 0.52, tower_z), Vector3(half * 2.0, 0.34, half * 2.0), roof.lightened(float(roof_tier) * 0.08))
			_box(root, Vector3(side_x, 12.95, tower_z), Vector3(0.58, 0.72, 0.58), light)
			_box(root, Vector3(side_x, 13.48, tower_z), Vector3(0.14, 0.44, 0.14), Color("#f2cf83"))
		_box(root, Vector3(side_x + (0.1 if side_x > 0 else -0.1), 5.5, tower_z + 1.45), Vector3(0.5, 0.7, 0.12), glow, 0.3)
		_box(root, Vector3(side_x + (0.1 if side_x > 0 else -0.1), 7.5, tower_z + 1.45), Vector3(0.5, 0.7, 0.12), glow, 0.3)
	_box(root, Vector3(0, 7.0, -2.5), Vector3(6.5, 8.0, 5.5), stone)
	_box(root, Vector3(0, 11.5, -2.5), Vector3(7.2, 0.45, 6.2), roof)
	_box(root, Vector3(0, 13.0, -2.5), Vector3(3.0, 3.5, 3.0), light)
	_box(root, Vector3(0, 15.0, -2.5), Vector3(3.6, 0.4, 3.6), roof)
	_box(root, Vector3(0, 15.5, -2.5), Vector3(1.8, 0.9, 1.8), roof.darkened(0.12))
	_box(root, Vector3(0, 16.2, -2.5), Vector3(0.25, 0.8, 0.25), Color("#f6d78c"), 0.25)
	_pyramid(root, Vector3(0, 17.1, -2.5), 2.0, 2.6, Color("#6f3e35"))
	_box(root, Vector3(0, 18.65, -2.5), Vector3(0.16, 0.9, 0.16), Color("#f4d68e"), 0.25)
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
	var castle := get_node_or_null("GatehouseCastle") as Node3D
	if castle == null:
		return

	# Two inhabited side wings turn the isolated gatehouse into a broader
	# fortified landmark. Roof slopes, corner towers, connecting galleries and
	# repeated lit windows give the silhouette depth at menu-camera distance.
	for side in [-1.0, 1.0]:
		var wing_x: float = float(side) * 11.2
		var wing_root := Node3D.new()
		wing_root.name = "CastleWestWing" if side < 0.0 else "CastleEastWing"
		# Bring the side wings forward to the gatehouse facade plane; otherwise
		# their walls sit behind the main mass and only the roofline reads as floating.
		wing_root.position.z = 1.8
		castle.add_child(wing_root)
		_box(wing_root, Vector3(wing_x, 3.4, -1.6), Vector3(7.0, 6.6, 9.5), Color("#78847e"))
		_box(wing_root, Vector3(wing_x, 6.9, -1.6), Vector3(7.6, 0.35, 10.0), Color("#a8b1a7"))
		var front_roof := _box(wing_root, Vector3(wing_x - side * 1.55, 6.95, 1.0), Vector3(4.0, 0.28, 10.4), Color("#854a3b"))
		front_roof.rotation.z = deg_to_rad(side * -24.0)
		front_roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var rear_roof := _box(wing_root, Vector3(wing_x + side * 1.55, 6.95, 1.0), Vector3(4.0, 0.28, 10.4), Color("#a45c43"))
		rear_roof.rotation.z = deg_to_rad(side * 24.0)
		rear_roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_box(wing_root, Vector3(wing_x, 7.45, 1.0), Vector3(0.22, 0.32, 10.6), Color("#c28b61"))
		for window_z in [-4.4, -1.8, 0.8, 3.4]:
			_box(wing_root, Vector3(wing_x - side * 3.56, 4.4, window_z), Vector3(0.12, 1.25, 0.72), Color("#253b49"))
			_box(wing_root, Vector3(wing_x - side * 3.64, 4.4, window_z), Vector3(0.08, 0.18, 0.86), Color("#e9b96b"), 0.32)
		# Four shallow stone buttresses articulate the long wing walls and
		# restore the detailed facade rhythm without adding another roof tower.
		for buttress_z in [-5.2, 2.8]:
			_box(wing_root, Vector3(wing_x - side * 3.48, 3.35, buttress_z), Vector3(0.42, 6.9, 0.72), Color("#89958d"))
			_box(wing_root, Vector3(wing_x - side * 3.58, 6.72, buttress_z), Vector3(0.58, 0.22, 0.86), Color("#b9c2b5"))
		for tower_z in [3.0]:
			_box(wing_root, Vector3(wing_x, 8.3, tower_z), Vector3(2.3, 3.2, 2.3), Color("#66756f"))
			_box(wing_root, Vector3(wing_x, 10.0, tower_z), Vector3(2.8, 0.28, 2.8), Color("#b2b8ad"))
			_pyramid(wing_root, Vector3(wing_x, 10.05, tower_z), 1.35, 1.75, Color("#75463b"))
			_box(wing_root, Vector3(wing_x, 11.65, tower_z), Vector3(0.12, 0.7, 0.12), Color("#f0ce83"))
	# Raised stone causeway and retaining walls visually anchor the expanded wings.
	_box(castle, Vector3(0.0, 0.35, 8.4), Vector3(24.0, 0.55, 2.0), Color("#777f76"))
	for side in [-1.0, 1.0]:
		_box(castle, Vector3(side * 10.0, 0.9, 8.4), Vector3(0.42, 1.2, 2.0), Color("#aab2a8"))

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



func _build_castle_compound_pass() -> void:
	# A varied outer compound gives the landmark a readable skyline beyond the
	# central gatehouse: a chapel, two inhabited bastions and a stepped curtain.
	var castle := get_node_or_null("GatehouseCastle") as Node3D
	if castle == null:
		return
	var stone := Color("#78857e")
	var trim := Color("#b9c2b5")
	var roof_a := Color("#75463b")
	var roof_b := Color("#a85e43")
	var window_glow := Color("#ffd58a")
	# Rear chapel: a narrower footprint and a tall gabled roof break the
	# repeated square-tower rhythm of the original gatehouse.
	var chapel := Node3D.new()
	chapel.name = "CastleChapel"
	chapel.position = Vector3(0.0, 0.0, -10.0)
	castle.add_child(chapel)
	_box(chapel, Vector3(0.0, 4.0, -1.0), Vector3(8.0, 7.0, 7.0), stone)
	_box(chapel, Vector3(0.0, 7.65, -1.0), Vector3(8.6, 0.28, 7.6), trim)
	for side in [-1.0, 1.0]:
		var slope := _box(chapel, Vector3(side * 1.65, 9.0, -1.0), Vector3(4.2, 0.24, 8.0), roof_a if side < 0.0 else roof_b)
		slope.rotation.z = deg_to_rad(side * 34.0)
	_box(chapel, Vector3(0.0, 10.25, -1.0), Vector3(0.22, 0.20, 8.2), Color("#d19a68"))
	for window_z in [-3.0, -0.8, 1.4]:
		_box(chapel, Vector3(-4.08, 4.9, window_z), Vector3(0.10, 1.35, 0.68), Color("#263b48"))
		_box(chapel, Vector3(-4.15, 4.9, window_z), Vector3(0.07, 0.86, 0.34), window_glow)
	# Outer bastions are deliberately asymmetric in height and roof treatment.
	for side in [-1.0, 1.0]:
		var bastion := Node3D.new()
		bastion.name = "OuterBastionWest" if side < 0.0 else "OuterBastionEast"
		bastion.position = Vector3(side * 17.2, 0.0, -2.0 if side < 0.0 else -4.0)
		castle.add_child(bastion)
		var height := 7.2 if side < 0.0 else 5.8
		_box(bastion, Vector3(0.0, height * 0.5, 0.0), Vector3(4.6, height, 5.2), stone.darkened(0.04 if side < 0.0 else 0.0))
		_box(bastion, Vector3(0.0, height + 0.12, 0.0), Vector3(5.0, 0.28, 5.6), trim)
		if side < 0.0:
			# West bastion uses a steep octagonal-looking spire.
			_pyramid(bastion, Vector3(0.0, height + 0.18, 0.0), 2.8, 4.8, roof_a)
		else:
			# East bastion has a broad stepped roof and a small lantern crown.
			for level in range(3):
				var half := 2.45 - float(level) * 0.55
				_box(bastion, Vector3(0.0, height + 0.42 + float(level) * 0.72, 0.0), Vector3(half * 2.0, 0.42, half * 2.0), roof_b.darkened(float(level) * 0.06))
			_box(bastion, Vector3(0.0, height + 2.75, 0.0), Vector3(0.8, 0.8, 0.8), trim)
		for window_y in [2.4, 4.6]:
			_box(bastion, Vector3(0.0, window_y, 2.66), Vector3(0.58, 0.92, 0.10), Color("#263b48"))
			_box(bastion, Vector3(0.0, window_y, 2.73), Vector3(0.24, 0.58, 0.05), window_glow)
		# Small merlons articulate the outer parapet rather than leaving a flat cap.
		for edge in [-1.7, -0.55, 0.55, 1.7]:
			_box(bastion, Vector3(edge, height + 0.52, 0.0), Vector3(0.42, 0.62, 0.52), trim)
	# Low connecting curtain walls and a central courtyard stair anchor the
	# separate masses to one continuous fortified site.
	for side in [-1.0, 1.0]:
		_box(castle, Vector3(side * 13.4, 2.2, 4.8), Vector3(5.2, 4.4, 0.72), stone)
		for merlon in range(4):
			_box(castle, Vector3(side * (11.4 + float(merlon) * 1.3), 4.65, 4.8), Vector3(0.62, 0.58, 0.78), trim)
	for step in range(4):
		_box(castle, Vector3(0.0, 0.18 + float(step) * 0.22, 10.2 + float(step) * 0.72), Vector3(5.2 - float(step) * 0.45, 0.32, 0.82), Color("#9b9a88"))

func _build_protagonist() -> void:
	# Larger, layered hero silhouette based on the approved Blockraft character:
	# teal tunic, blue trousers, backpack, face, boots and diamond pickaxe.
	var ledge := Node3D.new()
	ledge.name = "HeroForegroundLedge"
	add_child(ledge)
	# Remove the broad oval rock plinth: it reads as a floating display base.
	# Seat the character on the actual meadow elevation and use small, irregular
	# grass/stone accents around the boots to blend the silhouette into terrain.
	for patch_index in range(6):
		var patch_angle := TAU * float(patch_index) / 6.0
		var grass_patch := MeshInstance3D.new()
		var patch_mesh := SphereMesh.new()
		patch_mesh.radius = 1.0
		patch_mesh.height = 2.0
		patch_mesh.radial_segments = 9
		patch_mesh.rings = 5
		grass_patch.mesh = patch_mesh
		grass_patch.position = Vector3(-9.0 + cos(patch_angle) * 1.55, 0.39 + float(patch_index % 2) * 0.035, 13.0 + sin(patch_angle) * 1.35)
		grass_patch.scale = Vector3(0.72 + float(patch_index % 3) * 0.12, 0.07, 0.52 + float(patch_index % 2) * 0.10)
		grass_patch.material_override = _material(Color("#477f3f") if patch_index % 2 == 0 else Color("#5b9149"), 0.96)
		grass_patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ledge.add_child(grass_patch)
	for rock_index in range(7):
		var angle := TAU * float(rock_index) / 7.0
		var pebble := MeshInstance3D.new()
		var pebble_mesh := SphereMesh.new()
		pebble_mesh.radius = 0.42
		pebble_mesh.height = 0.62
		pebble_mesh.radial_segments = 8
		pebble_mesh.rings = 5
		pebble.mesh = pebble_mesh
		pebble.position = Vector3(-9.0 + cos(angle) * 2.05, 0.49, 13.0 + sin(angle) * 1.85)
		pebble.scale = Vector3(0.42 + float(rock_index % 3) * 0.10, 0.28, 0.40 + float(rock_index % 2) * 0.12)
		pebble.material_override = _material(Color("#788078") if rock_index % 2 == 0 else Color("#8c8978"), 0.98)
		pebble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ledge.add_child(pebble)
	var hero := Node3D.new()
	hero.name = "Protagonist"
	hero.position = Vector3(-9.0, 0.06, 13.0)
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
