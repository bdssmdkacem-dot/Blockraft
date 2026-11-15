extends Node3D
## Voxel world expanded + resource depot.

const WORLD_RADIUS := 56
const MIN_Y := -6
const CHUNK_SIZE := 16
const VIEW_CHUNKS := 3
const MAX_CHUNK_BUILDS_PER_FRAME := 1
const SAVE_PATH := "user://world_blocks.json"
const SAVE_VERSION := 15
const PREVIOUS_SAVE_VERSION := 14
const AUTO_SAVE_INTERVAL := 8.0
# Spawn is anchored to the reserved, flat 7x7 pad: block (0, 4, 0) has its
# top face at y=5. Keep old saves and player edits from creating an overhead
# obstruction above the spawn point.
const SPAWN_X := 0.5
const SPAWN_Z := 0.5
const SPAWN_SURFACE_Y := 5.0
const SPAWN_CLEAR_MAX_Y := 80
const SPAWN_CONTACT_EPSILON := 0.04
const TERRAIN_SURFACE_KINDS := ["grass", "dirt", "stone", "rock", "sand", "gravel"]

var blocks: Dictionary = {}
var block_mesh := BoxMesh.new()
var block_materials: Dictionary = {}
var world_root: Node3D
var chunk_root: Node3D
var loaded_chunks: Dictionary = {}
var player: CharacterBody3D
var inventory: Node
var hotbar_ui: HBoxContainer
var hotbar_slots: Array = []
var backpack_label: Label
var upgrade_btn: Button
var mining_fx: Node
var flora_fauna: Node
var toast_label: Label
var status_label: Label
var _chunk_timer := 0.0
var _last_player_chunk := Vector2i(9999, 9999)
var discovered: Dictionary = {}
var _chunk_queue: Array = []
var _save_dirty := false
var _autosave_timer := 0.0
var _last_save_time := 0.0
var world_initialized := false
# Runtime diagnostics consumed by the long-session acceptance test and debug HUD.
var chunk_build_count := 0
var chunk_build_ms_last := 0.0
var chunk_build_ms_peak := 0.0
var chunk_peak_loaded := 0
var chunk_render_triangle_count_total := 0
var chunk_render_vertex_bytes_total := 0
var chunk_render_full_cube_triangle_equivalent_total := 0
var chunk_render_face_quads_total := 0
# Cold-start terrain generation diagnostics (milliseconds).
var world_generation_ms := 0.0
var world_generation_heightfield_ms := 0.0
var world_generation_voxel_fill_ms := 0.0
var world_generation_block_count := 0
# Shared corner heights let adjacent voxel tops meet as continuous low-poly slopes.
var terrain_surface_heights: Dictionary = {}
var terrain_corner_heights: Dictionary = {}

func _ready() -> void:
	player = get_node_or_null("Player") as CharacterBody3D
	if player:
		player.add_to_group("player")
		player.velocity = Vector3.ZERO
		player.global_position = Vector3(0.0, 6.0, 0.0)
	_spawn_guaranteed_floor()
	world_root = Node3D.new()
	world_root.name = "GeneratedWorld"
	add_child(world_root)
	chunk_root = Node3D.new()
	chunk_root.name = "Chunks"
	world_root.add_child(chunk_root)
	inventory = load("res://scripts/inventory.gd").new()
	inventory.name = "Inventory"
	add_child(inventory)
	mining_fx = load("res://scripts/mining_fx.gd").new()
	mining_fx.name = "MiningFX"
	add_child(mining_fx)
	var settings = load("res://scripts/settings.gd").new()
	settings.name = "Settings"
	add_child(settings)
	_setup_materials()
	_setup_environment()
	# Survival binds to the world's active environment during setup. Create the
	# WorldEnvironment first so day/night and weather can actually tint the sky.
	var survival = load("res://scripts/survival.gd").new()
	survival.name = "Survival"
	add_child(survival)
	survival.setup(self, settings)
	_setup_ui()
	_show_toast("Building expanded world...", 30.0)
	if player:
		var cam := player.get_node_or_null("PlayerCamera") as Camera3D
		if cam:
			cam.make_current()
	call_deferred("_initialize_world_async")

func _initialize_world_async() -> void:
	await get_tree().process_frame
	var restored := _load_world_snapshot()
	if not restored:
		_generate_world()
		if blocks.size() < 2000:
			_generate_world()
	if not restored:
		_clear_spawn_camera_corridor()
	_ensure_spawn_pad()
	_rebuild_terrain_surface_cache_from_blocks()
	_spawn_depot()
	if player:
		player.velocity = Vector3.ZERO

	# Install collision for the actual spawn pad before positioning the player.
	# Never select an arbitrary nearby surface: old saves may contain floating
	# blocks or structures, which must not become the spawn point.
	var spawn_chunk := _chunk_key_from_world(0, 0)
	_load_chunk(spawn_chunk)
	_snap_player_to_surface()
	_last_player_chunk = Vector2i(9999, 9999)
	_update_chunks(false)

	flora_fauna = load("res://scripts/flora_fauna.gd").new()
	flora_fauna.name = "FloraFauna"
	add_child(flora_fauna)
	flora_fauna.setup(self, blocks)
	if player:
		player.velocity = Vector3.ZERO
		# A defensive final assertion prevents the old arbitrary-height fallback.
		if absf(player.global_position.x - SPAWN_X) > 0.01 or absf(player.global_position.z - SPAWN_Z) > 0.01 or absf(player.global_position.y - (SPAWN_SURFACE_Y + SPAWN_CONTACT_EPSILON)) > 0.1:
			_snap_player_to_surface()
	world_initialized = true
	_show_toast("Explore · dig · F=depot · B=upgrade bag · E=eat", 5.0)
	print("Blockraft world ready blocks=", blocks.size(), " chunks=", loaded_chunks.size(), " spawn=", player.global_position if player else Vector3.ZERO)

func _spawn_guaranteed_floor() -> void:
	var floor_y := 2.0
	# This is collision-only spawn insurance, not a visible world floor.
	# The former 100x100 green slab masked the procedural landscape and made
	# the world look like a flat platform with a distant vertical wall.
	var size := Vector3(14.0, 4.0, 14.0)
	var mi := MeshInstance3D.new()
	mi.name = "GuaranteedFloorMesh"
	mi.visible = false
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = Vector3(0.0, floor_y, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.62, 0.28)
	mat.roughness = 0.9
	mi.material_override = mat
	add_child(mi)
	var body := StaticBody3D.new()
	body.name = "GuaranteedFloorBody"
	body.position = Vector3(0.0, floor_y, 0.0)
	body.collision_layer = 1
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)
	if player:
		player.global_position = Vector3(0.0, floor_y + size.y * 0.5 + 1.2, 0.0)
		player.velocity = Vector3.ZERO

func _process(delta: float) -> void:
	if not world_initialized:
		return
	_chunk_timer -= delta
	if _chunk_timer <= 0.0:
		_chunk_timer = 0.25
		_update_chunks(false)
	var built := 0
	while built < MAX_CHUNK_BUILDS_PER_FRAME and not _chunk_queue.is_empty():
		var ck: Vector2i = _chunk_queue.pop_front()
		if not loaded_chunks.has(ck) and _is_chunk_needed(ck):
			_load_chunk(ck)
			built += 1
	_tick_autosave(delta)
	_check_fall_respawn()
	var surv = get_node_or_null("Survival")
	if surv:
		surv.tick(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			var surv = get_node_or_null("Survival")
			if surv:
				surv.try_eat()
		elif event.keycode == KEY_F:
			use_depot()

func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.background_color = Color("#7aa8d8")
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#24466f")
	sky_mat.sky_horizon_color = Color("#d8ad80")
	sky_mat.ground_bottom_color = Color("#1e302d")
	sky_mat.ground_horizon_color = Color("#9b8068")
	sky_mat.sun_angle_max = 18.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#91a8b8")
	env.ambient_light_energy = 0.36
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.94
	env.fog_enabled = true
	env.fog_light_color = Color("#9aabb0")
	env.fog_density = 0.00034
	env.fog_aerial_perspective = 0.28
	we.environment = env
	add_child(we)

func _setup_materials() -> void:
	var colors := {
		"grass": Color(0.15, 0.29, 0.16), "dirt": Color(0.39, 0.26, 0.16),
		"stone": Color(0.48, 0.50, 0.52), "wood": Color(0.42, 0.25, 0.11),
		"sand": Color(0.82, 0.72, 0.48), "water": Color(0.06, 0.27, 0.48),
		"gravel": Color(0.55, 0.52, 0.48), "rock": Color(0.35, 0.36, 0.38),
		"coal": Color(0.12, 0.12, 0.14), "iron": Color(0.72, 0.58, 0.48),
		"gold": Color(0.92, 0.78, 0.22), "crystal": Color(0.45, 0.85, 0.95),
		"leaves": Color(0.15, 0.33, 0.16), "chest": Color(0.55, 0.32, 0.12),
	}
	for key in colors:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[key]
		mat.roughness = 0.92
		if key == "water":
			# Retain the project's alpha water contract, but keep opacity high so
			# shoreline terrain cannot dominate the river colour through blending.
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.94
			# Matte, non-metallic water avoids glossy highlights while preserving
			# a subtle depth impression at the river edge.
			mat.roughness = 0.86
			mat.metallic = 0.0
			mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			mat.metallic_specular = 0.0
			mat.emission_enabled = true
			mat.emission = Color(0.01, 0.04, 0.08)
			mat.emission_energy_multiplier = 0.035
		block_materials[key] = mat

func _clear_old_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		var ud := DirAccess.open("user://")
		if ud and ud.file_exists("world_blocks.json"):
			ud.remove("world_blocks.json")
		print("Blockraft: cleared old save for new terrain")

func _spawn_depot() -> void:
	var root := Node3D.new()
	root.name = "ResourceDepot"
	add_child(root)
	var base := StaticBody3D.new()
	base.collision_layer = 1
	base.set_meta("is_depot", true)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 2.4, 2.2)
	col.shape = shape
	base.add_child(col)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.2, 2.4, 2.2)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.28, 0.12)
	mi.material_override = mat
	base.add_child(mi)
	var roof := MeshInstance3D.new()
	var rbox := BoxMesh.new()
	rbox.size = Vector3(2.6, 0.35, 2.6)
	roof.mesh = rbox
	roof.position.y = 1.4
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.55, 0.2, 0.12)
	roof.material_override = rmat
	base.add_child(roof)
	root.add_child(base)
	var top := 3
	for y in range(30, -5, -1):
		if blocks.has(Vector3i(3, y, 3)) and str(blocks[Vector3i(3, y, 3)]) != "water":
			top = y
			break
	base.position = Vector3(9.5, float(top) + 1.7, 8.5)

func use_depot() -> void:
	if inventory == null:
		return
	var moved: int = int(inventory.deposit_all())
	if moved > 0:
		_show_toast("Deposited %d items to warehouse" % moved, 2.0)
	else:
		_show_toast(inventory.storage_summary(), 2.5)
	if inventory.try_upgrade():
		_show_toast("Backpack upgraded: %s" % inventory.get_backpack_label(), 2.5)
	else:
		_show_toast(inventory.upgrade_cost_text(), 3.0)
	_refresh_backpack_ui()

func _generate_world() -> void:
	var generation_started_usec := Time.get_ticks_usec()
	blocks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 82417
	var heights: Dictionary = {}
	# Fractal simplex noise breaks up the long, straight sinusoidal ridges that
	# previously read as a continuous cliff wall in the third-person view.
	var terrain_noise := FastNoiseLite.new()
	terrain_noise.seed = 82417
	terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	terrain_noise.frequency = 0.040
	terrain_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	terrain_noise.fractal_octaves = 4
	terrain_noise.fractal_gain = 0.48
	for x in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
		for z in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
			var fx := float(x)
			var fz := float(z)
			var dist := sqrt(fx * fx + fz * fz)
			var h := 4.6
			h += sin(fx * 0.032) * cos(fz * 0.032) * 1.35
			h += sin(fx * 0.060 + 1.7) * 0.52 + cos(fz * 0.058 + 0.6) * 0.48
			h += sin(fx * 0.12 + fz * 0.06) * 0.20
			var local_relief := terrain_noise.get_noise_2d(fx, fz)
			h += local_relief * 3.0
			# Two broad Gaussian ridges frame the forward river valley. Their
			# gentle profiles restore visible mountain relief without creating
			# isolated spikes or abrupt voxel walls.
			var west_ridge := exp(-pow((fx + 19.0) / 10.0, 2.0) - pow((fz + 34.0) / 11.0, 2.0)) * 6.0
			var east_ridge := exp(-pow((fx - 20.0) / 12.0, 2.0) - pow((fz + 32.0) / 10.0, 2.0)) * 5.8
			h += west_ridge + east_ridge
			# Higher outer ridges are made from local noise peaks rather than one
			# broad cosine band, giving the skyline varied saddles and rounded hills.
			if dist > 22.0:
				var ridge_peak := maxf(0.0, terrain_noise.get_noise_2d(fx * 0.72 + 91.0, fz * 0.72 - 47.0))
				h += pow(ridge_peak, 1.65) * 3.0
			# Keep the spawn valley open, then blend into rolling hills instead
			# of creating a sudden high wall at the edge of the starter plateau.
			# Keep only the protected spawn pad level. Blend into the nearby
			# rolling terrain sooner so the starting area does not read as a
			# broad artificial tabletop.
			if dist < 3.5:
				h = 4.0
			elif dist < 7.5:
				h = lerpf(4.0, h, smoothstep(3.5, 7.5, dist))
			var river_d := absf(fz - sin(fx * 0.11) * 8.0 - cos(fx * 0.04) * 3.0)
			# The forward scenic tributary gives the spawn view a visible crossing.
			var scenic_river_d := absf(fz + 15.0 + sin(fx * 0.12) * 3.0)
			if dist > 12.0 and dist < 48.0:
				river_d = minf(river_d, scenic_river_d)
			var trib_d := absf(fx - cos(fz * 0.13) * 5.0 + 10.0)
			# A gently varying channel width avoids the ruler-straight, uniformly
			# narrow trench. Width modulation is low-frequency and deterministic.
			var main_river_width := 1.75 + sin(fx * 0.17 + fz * 0.08) * 0.28 + cos(fz * 0.21) * 0.12
			var in_main := river_d < main_river_width and dist > 7.0
			var in_trib := trib_d < 1.25 and dist > 11.0 and fz > 0.0
			var in_river := in_main or in_trib
			if in_river:
				# Deepen the channel centre and leave a shallow shelf near the bank.
				# The water surface stays level while its voxel depth changes gradually.
				var channel_distance := river_d
				var channel_width := main_river_width
				if in_trib and (not in_main or trib_d < river_d):
					channel_distance = trib_d
					channel_width = 1.25
				var edge_t := clampf(channel_distance / maxf(channel_width, 0.1), 0.0, 1.0)
				var channel_floor_height := lerpf(0.35, 1.2, edge_t)
				h = mini(h, channel_floor_height)
			else:
				# Shape each shoreline from its own water edge into a broad, gently
				# rising bank. The inner edge follows the actual channel width.
				var bank_distance := river_d
				var bank_inner_width := main_river_width
				if dist > 11.0 and fz > 0.0 and trib_d < bank_distance:
					bank_distance = trib_d
					bank_inner_width = 1.25
				if bank_distance < 8.5 and dist > 7.0:
					var bank_height := lerpf(1.2, h, smoothstep(bank_inner_width, 8.5, bank_distance))
					h = minf(h, bank_height)
			var in_lake := (fx + 22.0) * (fx + 22.0) + (fz - 18.0) * (fz - 18.0) < 55.0
			if in_lake:
				h = mini(h, 1.0)
			# Fade the terrain down toward the world perimeter. Without this
			# transition the finite map ends in a continuous 10+ block cliff
			# visible from the spawn camera, even when interior slopes are smooth.
			var edge_distance := float(WORLD_RADIUS - maxi(absi(x), absi(z)))
			if edge_distance < 32.0:
				h = lerpf(float(MIN_Y + 2), h, smoothstep(0.0, 32.0, edge_distance))
			heights[Vector2i(x, z)] = {
				"hf": clampf(h, float(MIN_Y + 2), 15.5),
				"river": in_river or in_lake,
				"river_d": mini(river_d if in_main else (trib_d if in_trib else 99.0), 99.0),
				"lake": in_lake,
			}
	for _pass in range(10):
		var next_map: Dictionary = {}
		for x in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
			for z in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
				var key := Vector2i(x, z)
				var info: Dictionary = heights[key]
				var hf: float = float(info["hf"])
				if bool(info["river"]):
					next_map[key] = hf
					continue
				var sum := hf * 2.0
				var wsum := 2.0
				for ox in [-1, 0, 1]:
					for oz in [-1, 0, 1]:
						if ox == 0 and oz == 0:
							continue
						var nkey := Vector2i(x + ox, z + oz)
						if not heights.has(nkey):
							continue
						var neighbor: Dictionary = heights[nkey]
						var nw := 1.0 if (ox == 0 or oz == 0) else 0.55
						sum += float(neighbor["hf"]) * nw
						wsum += nw
				next_map[key] = lerpf(hf, sum / wsum, 0.55)
		for key in next_map.keys():
			var info2: Dictionary = heights[key]
			info2["hf"] = next_map[key]
			heights[key] = info2
	for x in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
		for z in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
			var key := Vector2i(x, z)
			var info: Dictionary = heights[key]
			var hi := clampi(int(round(float(info["hf"]))), MIN_Y + 2, 17)
			info["h"] = hi
			var dist2 := sqrt(float(x * x + z * z))
			var path := false
			if not bool(info["river"]) and dist2 > 4.0 and dist2 < 28.0 and hi >= 3 and hi <= 6:
				var along := absf(float(z) - sin(float(x) * 0.09) * 5.0)
				if along < 1.35:
					path = true
			info["path"] = path
			heights[key] = info

	# Smooth only the designated walkable path corridor. Water channels and high
	# mountain terrain are never modified by this pass.
	for _path_pass in range(2):
		var path_updates: Dictionary = {}
		for x in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
			for z in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
				var key := Vector2i(x, z)
				var info: Dictionary = heights[key]
				if not bool(info.get("path", false)) or bool(info["river"]):
					continue
				var original := float(info["hf"])
				var total := original * 2.0
				var weight := 2.0
				for ox in [-1, 0, 1]:
					for oz in [-1, 0, 1]:
						if ox == 0 and oz == 0:
							continue
						var neighbor_key := Vector2i(x + ox, z + oz)
						if not heights.has(neighbor_key):
							continue
						var neighbor: Dictionary = heights[neighbor_key]
						if not bool(neighbor.get("path", false)) or bool(neighbor["river"]):
							continue
						var neighbor_weight := 1.0 if ox == 0 or oz == 0 else 0.6
						total += float(neighbor["hf"]) * neighbor_weight
						weight += neighbor_weight
				path_updates[key] = clampf(lerpf(original, total / weight, 0.65), 3.0, 6.0)
		for key in path_updates:
			var path_info: Dictionary = heights[key]
			path_info["hf"] = float(path_updates[key])
			path_info["h"] = clampi(int(round(float(path_updates[key]))), 3, 6)
			heights[key] = path_info

	# Erode every non-water terrain edge into a walkable slope. The earlier
	# near-water exemption preserved abrupt river cliffs, and the rounded voxel
	# heights then turned modest height differences into vertical rock faces.
	# This bounded-neighbour relaxation limits each grid step before voxelizing.
	const MAX_WALKABLE_HEIGHT_STEP := 0.50
	for _slope_pass in range(32):
		var slope_updates: Dictionary = {}
		for x in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
			for z in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
				var key := Vector2i(x, z)
				var info: Dictionary = heights[key]
				var current_height := float(info["hf"])
				if bool(info["river"]):
					slope_updates[key] = current_height
					continue
				var lower_bound := -INF
				var upper_bound := INF
				for ox in [-1, 0, 1]:
					for oz in [-1, 0, 1]:
						if ox == 0 and oz == 0:
							continue
						var neighbor_key := Vector2i(x + ox, z + oz)
						if not heights.has(neighbor_key):
							continue
						var neighbor: Dictionary = heights[neighbor_key]
						var neighbor_height := float(neighbor["hf"])
						lower_bound = maxf(lower_bound, neighbor_height - MAX_WALKABLE_HEIGHT_STEP)
						upper_bound = minf(upper_bound, neighbor_height + MAX_WALKABLE_HEIGHT_STEP)
				var constrained_height: float
				if lower_bound <= upper_bound:
					constrained_height = clampf(current_height, lower_bound, upper_bound)
				else:
					constrained_height = (lower_bound + upper_bound) * 0.5
				slope_updates[key] = constrained_height
		for key in slope_updates:
			var slope_info: Dictionary = heights[key]
			slope_info["hf"] = float(slope_updates[key])
			heights[key] = slope_info
	for key in heights:
		var final_info: Dictionary = heights[key]
		final_info["h"] = clampi(int(round(float(final_info["hf"]))), MIN_Y + 2, 13)
		heights[key] = final_info
	# Quantization can turn two compliant floating-point slopes into a two-voxel
	# cliff. Relax the final integer surface as well, while keeping river floors
	# fixed so the water channels remain recessed and readable.
	for _integer_pass in range(12):
		var integer_updates: Dictionary = {}
		for x in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
			for z in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
				var key := Vector2i(x, z)
				var info: Dictionary = heights[key]
				# Only columns that actually contain water are exempt from dry-land
				# slope relaxation. A river-marked column at/above water level is a
				# dry bank and must obey the same one-block traversal limit.
				if bool(info["river"]) and int(info["h"]) < 2:
					continue
				var current_height := int(info["h"])
				var lower_bound := MIN_Y + 2
				var upper_bound := 13
				for ox in [-1, 0, 1]:
					for oz in [-1, 0, 1]:
						if ox == 0 and oz == 0:
							continue
						var neighbor_key := Vector2i(x + ox, z + oz)
						if not heights.has(neighbor_key):
							continue
						var neighbor: Dictionary = heights[neighbor_key]
						if bool(neighbor["river"]) and int(neighbor["h"]) < 2:
							continue
						var neighbor_height := int(neighbor["h"])
						lower_bound = maxi(lower_bound, neighbor_height - 1)
						upper_bound = mini(upper_bound, neighbor_height + 1)
				integer_updates[key] = clampi(current_height, lower_bound, upper_bound) if lower_bound <= upper_bound else int(round((lower_bound + upper_bound) * 0.5))
		for key in integer_updates:
			var info: Dictionary = heights[key]
			info["h"] = int(integer_updates[key])
			heights[key] = info

	# The bounded float-slope and simultaneous integer passes above are the
	# single source of truth for walkable one-block terrain transitions. Avoid
	# the former 32-pass in-place lowering sweep, which flattened distant ridges.

	var voxel_fill_started_usec := Time.get_ticks_usec()
	for x in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
		for z in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
			var info: Dictionary = heights[Vector2i(x, z)]
			var height: int = int(info["h"])
			var is_river: bool = bool(info["river"])
			var river_d: float = float(info["river_d"])
			var max_dh := 0
			for ox in [-1, 0, 1]:
				for oz in [-1, 0, 1]:
					if ox == 0 and oz == 0: continue
					var nkey := Vector2i(x + ox, z + oz)
					if heights.has(nkey):
						max_dh = maxi(max_dh, absi(height - int(heights[nkey]["h"])))
			var steep := max_dh >= 1 and height >= 8
			var water_level := 2
			for y in range(MIN_Y, height + 1):
				var kind := "stone"
				if is_river and y < water_level: kind = "dirt"
				elif y == height:
					if is_river: kind = "sand" if river_d < 3.5 or bool(info["lake"]) else "dirt"
					elif steep: kind = "rock" if height >= 7 else "stone"
					elif height <= 3 and river_d < 6.0: kind = "sand"
					elif bool(info.get("path", false)): kind = "dirt"
					else: kind = "grass"
				elif y >= height - 1:
					if is_river or (height <= 3 and river_d < 6.0): kind = "sand"
					elif steep: kind = "stone"
					else: kind = "dirt"
				elif y >= height - 3: kind = "dirt" if not steep else "stone"
				else:
					kind = "stone"
					if y <= height - 4 and y >= MIN_Y + 1:
						var n := _ore_noise(x, y, z)
						if n > 0.82 and y <= 2: kind = "crystal"
						elif n > 0.72 and y <= 4: kind = "gold"
						elif n > 0.62: kind = "iron"
						elif n > 0.52: kind = "coal"
				blocks[Vector3i(x, y, z)] = kind
			if is_river:
				for wy in range(height + 1, water_level + 1):
					blocks[Vector3i(x, wy, z)] = "water"
				if height < water_level:
					blocks[Vector3i(x, water_level, z)] = "water"
			if not is_river and river_d < 4.2 and height <= water_level + 1 and rng.randf() < 0.35:
				blocks[Vector3i(x, height, z)] = "gravel"
			var camera_clearance := Vector2(float(x), float(z)).length()
			var tree_edge_clearance := float(WORLD_RADIUS - maxi(absi(x), absi(z)))
			var opening_camera_corridor: bool = z < -3 and z > -40 and abs(x) < 8
			if not is_river and not steep and height >= 4 and height <= 14 and abs(x) > 5 and abs(z) > 5 and camera_clearance <= 30.0 and tree_edge_clearance > 16.0 and not opening_camera_corridor:
				# Keep tree crowns grounded within the visible playable basin.
				# Trees on the far perimeter or central horizon were technically
				# supported, but their trunks fell below the camera horizon and
				# made detached leaf clusters appear to float in the sky.
				var forest_signal := sin(float(x) * 0.17) * cos(float(z) * 0.19)
				var tree_chance := 0.075 if forest_signal > 0.35 else 0.032
				if camera_clearance < 22.0:
					tree_chance *= 0.55
				elif camera_clearance < 30.0:
					tree_chance *= 0.80
				if river_d < 8.0: tree_chance *= 0.45
				if rng.randf() < tree_chance:
					_make_tree(x, height + 1, z, rng)
			if not is_river and not steep and height >= 3 and abs(x) > 10 and abs(z) > 10 and rng.randf() < 0.0024:
				blocks[Vector3i(x, height + 1, z)] = "chest"

	# Frame the starter valley with a few guaranteed tree groups. The
	# central movement corridor stays open, while these flank canopies break up
	# the broad grass terraces and give the river approach a stronger sense of place.
	for flank_tree in [Vector2i(-9, -12), Vector2i(9, -14), Vector2i(-13, -27), Vector2i(13, -29)]:
		if not heights.has(flank_tree):
			continue
		var flank_info: Dictionary = heights[flank_tree]
		var flank_height := int(flank_info["h"])
		if bool(flank_info["river"]) or flank_height < 4:
			continue
		if blocks.has(Vector3i(flank_tree.x, flank_height + 1, flank_tree.y)):
			continue
		_make_tree(flank_tree.x, flank_height + 1, flank_tree.y, rng)

	# Guarantee one discoverable chest in the generated overworld. The
	# procedural rarity roll remains for additional loot, but a fixed seed must
	# never produce a world with no chest at all.
	var guaranteed_chest_placed := false
	for radius in range(16, 25):
		if guaranteed_chest_placed:
			break
		for x in range(11, 25):
			if guaranteed_chest_placed:
				break
			for z in range(11, 25):
				if Vector2(float(x), float(z)).length() < float(radius - 1) or Vector2(float(x), float(z)).length() > float(radius + 1):
					continue
				var top := MIN_Y - 1
				var wet := false
				for y in range(MIN_Y, 15):
					var kind := str(blocks.get(Vector3i(x, y, z), ""))
					if kind == "water":
						wet = true
					if kind in ["grass", "dirt", "stone", "rock", "sand", "gravel"]:
						top = maxi(top, y)
				if wet or top < 3 or blocks.has(Vector3i(x, top + 1, z)) or blocks.has(Vector3i(x, top + 2, z)):
					continue
				blocks[Vector3i(x, top + 1, z)] = "chest"
				guaranteed_chest_placed = true
				break
	if not guaranteed_chest_placed:
			push_warning("Blockraft: could not place guaranteed overworld chest")
	else:
		print("BLOCKRAFT_GUARANTEED_CHEST position found")

	# A compact timber footbridge crosses the new forward tributary. It is
	# placed after terrain generation so the deck remains stable and collision-
	# backed even when the river's procedural banks change.
	# One-block wooden approaches connect the elevated deck to both river banks.
	blocks[Vector3i(0, 2, -21)] = "wood"
	blocks[Vector3i(0, 2, -12)] = "wood"
	for z in range(-20, -12):
		blocks[Vector3i(0, 3, z)] = "wood"
		if z % 2 == 0:
			blocks[Vector3i(-1, 4, z)] = "wood"
			blocks[Vector3i(1, 4, z)] = "wood"
	world_generation_heightfield_ms = float(voxel_fill_started_usec - generation_started_usec) / 1000.0
	world_generation_voxel_fill_ms = float(Time.get_ticks_usec() - voxel_fill_started_usec) / 1000.0
	world_generation_ms = float(Time.get_ticks_usec() - generation_started_usec) / 1000.0
	world_generation_block_count = blocks.size()
	print("WORLD_GENERATION_METRICS total_ms=", snappedf(world_generation_ms, 0.1),
		" heightfield_and_relaxation_ms=", snappedf(world_generation_heightfield_ms, 0.1),
		" voxel_fill_and_decoration_ms=", snappedf(world_generation_voxel_fill_ms, 0.1),
		" blocks=", world_generation_block_count)

func _ore_noise(x: int, y: int, z: int) -> float:
	return 0.5 + 0.5 * sin(float(x) * 0.19 + float(y) * 0.37) * cos(float(z) * 0.17 + float(y) * 0.23) * sin(float(x + z) * 0.11 + float(y) * 0.29)

func _make_tree(x: int, y: int, z: int, rng: RandomNumberGenerator = null) -> void:
	var r := rng if rng else RandomNumberGenerator.new()
	var trunk := 3 + r.randi_range(0, 2)
	for dy in range(trunk):
		blocks[Vector3i(x, y + dy, z)] = "wood"
	# A tapered, broken canopy keeps sight lines open while retaining a full
	# voxel-tree silhouette. Sparse outer leaves avoid solid green walls.
	var canopy_y := y + trunk - 1
	var radius := 2
	for dy in range(-1, 4):
		var layer_radius := maxi(1, radius - (1 if dy == 3 else 0))
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				var dist: int = absi(dx) + absi(dz)
				if dist > layer_radius * 2 + 1:
					continue
				if dist > layer_radius + 1 and r.randf() < 0.55:
					continue
				if dy == -1 and dist > 1:
					continue
				var p := Vector3i(x + dx, canopy_y + dy, z + dz)
				if not blocks.has(p):
					blocks[p] = "leaves"

func _ensure_spawn_pad() -> void:
	# Reserve a level 7x7 landing area, then blend it into the original terrain.
	# Preserve the surrounding natural heights as much as possible: each ramp
	# column may differ by only one block per ring from its nearest pad edge.
	var original_heights: Dictionary = {}
	for position in blocks:
		var pos: Vector3i = position
		if abs(pos.x) > 8 or abs(pos.z) > 8 or str(blocks[position]) not in TERRAIN_SURFACE_KINDS:
			continue
		var key := Vector2i(pos.x, pos.z)
		original_heights[key] = maxi(int(original_heights.get(key, MIN_Y)), pos.y)
	var target_heights: Dictionary = {}
	for x in range(-8, 9):
		for z in range(-8, 9):
			var distance := maxi(absi(x), absi(z))
			var boundary_x := clampi(x, -3, 3)
			var boundary_z := clampi(z, -3, 3)
			var boundary_height := 3 if absi(boundary_x) == 3 or absi(boundary_z) == 3 else 4
			var target_height := boundary_height
			if distance <= 3:
				target_height = 3 if distance == 3 else 4
			else:
				var original_height := int(original_heights.get(Vector2i(x, z), boundary_height))
				var allowed_steps := distance - 3
				target_height = clampi(original_height, boundary_height - allowed_steps, boundary_height + allowed_steps)
			target_heights[Vector2i(x, z)] = target_height
	# A few local passes preserve the original landscape while eliminating any
	# quantized two-block seams where the ramp meets natural ground.
	for _ramp_pass in range(4):
		var ramp_changed := false
		for x in range(-8, 9):
			for z in range(-8, 9):
				var key := Vector2i(x, z)
				var height := int(target_heights[key])
				for offset in [Vector2i(1, 0), Vector2i(0, 1)]:
					var neighbor_key: Vector2i = key + offset
					if not target_heights.has(neighbor_key):
						continue
					var neighbor_height := int(target_heights[neighbor_key])
					if height > neighbor_height + 1:
						target_heights[key] = neighbor_height + 1
						height = neighbor_height + 1
						ramp_changed = true
					elif neighbor_height > height + 1:
						target_heights[neighbor_key] = height + 1
						ramp_changed = true
		if not ramp_changed:
			break
	for x in range(-8, 9):
		for z in range(-8, 9):
			var key := Vector2i(x, z)
			var surface_y := int(target_heights[key])
			var original_y := int(original_heights.get(key, surface_y))
			for y in range(mini(original_y, surface_y) + 1, SPAWN_CLEAR_MAX_Y + 1):
				blocks.erase(Vector3i(x, y, z))
			if surface_y > original_y:
				for y in range(original_y + 1, surface_y):
					blocks[Vector3i(x, y, z)] = "dirt"
			blocks[Vector3i(x, surface_y - 1, z)] = "dirt"
			blocks[Vector3i(x, surface_y, z)] = "grass"

func _clear_spawn_camera_corridor() -> void:
	# Preserve the nearby forest and clear only the reserved player landing
	# pocket plus a narrow sightline to the bridge. The old 28-block radius
	# and wide forward wedge removed almost every tree from the playable view.
	var near_foliage_removed := 0
	for x in range(-8, 9):
		for z in range(-8, 9):
			if Vector2(float(x), float(z)).length() > 8.0:
				continue
			for y in range(5, 31):
				var pos := Vector3i(x, y, z)
				var kind := str(blocks.get(pos, ""))
				if kind in ["wood", "leaves"]:
					blocks.erase(pos)
					near_foliage_removed += 1
	# Keep a broad, readable opening toward the river. Remove only tree wood
	# and leaves above the terrain; the low footbridge deck at y=3..4 remains.
	# Clearing the complete canopy envelope also prevents trunk tips or
	# overhanging leaves from appearing as isolated blocks on the horizon.
	var forward_removed := 0
	for x in range(-28, 29):
		for z in range(-42, -3):
			for y in range(5, 31):
				var pos := Vector3i(x, y, z)
				var kind := str(blocks.get(pos, ""))
				if kind in ["wood", "leaves"]:
					blocks.erase(pos)
					forward_removed += 1
	if near_foliage_removed > 0 or forward_removed > 0:
		print("BLOCKRAFT_CAMERA_CORRIDOR_CLEAR removed_near_foliage=", near_foliage_removed,
			" removed_forward_foliage=", forward_removed)

func _snap_player_to_surface() -> void:
	if player == null:
		return
	# _ensure_spawn_pad() guarantees a solid grass block at (0, 4, 0), whose
	# top is y=5.0. Place the character capsule just above that known surface;
	# do not search for the nearest surface, which can be a floating structure.
	var ground := Vector3i(0, 4, 0)
	if not blocks.has(ground) or str(blocks.get(ground, "")) == "water":
		blocks[ground] = "grass"
	player.global_position = Vector3(SPAWN_X, SPAWN_SURFACE_Y + SPAWN_CONTACT_EPSILON, SPAWN_Z)
	player.velocity = Vector3.ZERO
	print("BLOCKRAFT_SPAWN_SAFE position=", player.global_position, " ground=", str(blocks.get(ground, "missing")))

func _chunk_key_from_world(wx: int, wz: int) -> Vector2i:
	return Vector2i(int(floor(float(wx) / float(CHUNK_SIZE))), int(floor(float(wz) / float(CHUNK_SIZE))))

func _is_chunk_needed(ck: Vector2i) -> bool:
	if player == null: return false
	var pc := _chunk_key_from_world(int(floor(player.global_position.x)), int(floor(player.global_position.z)))
	return abs(ck.x - pc.x) <= VIEW_CHUNKS and abs(ck.y - pc.y) <= VIEW_CHUNKS

func _update_chunks(force: bool) -> void:
	if player == null: return
	var pc := _chunk_key_from_world(int(floor(player.global_position.x)), int(floor(player.global_position.z)))
	if not force and pc == _last_player_chunk: return
	_last_player_chunk = pc
	var needed: Dictionary = {}
	for cx in range(pc.x - VIEW_CHUNKS, pc.x + VIEW_CHUNKS + 1):
		for cz in range(pc.y - VIEW_CHUNKS, pc.y + VIEW_CHUNKS + 1):
			needed[Vector2i(cx, cz)] = true
	var to_remove: Array = []
	for key in loaded_chunks.keys():
		if not needed.has(key): to_remove.append(key)
	for key in to_remove:
		var node: Node = loaded_chunks[key]
		if is_instance_valid(node): node.queue_free()
		loaded_chunks.erase(key)
	_chunk_queue.clear()
	var pending: Array = []
	for key in needed.keys():
		if not loaded_chunks.has(key): pending.append(key)
	pending.sort_custom(func(a, b): return (absi(a.x - pc.x) + absi(a.y - pc.y)) < (absi(b.x - pc.x) + absi(b.y - pc.y)))
	for key in pending: _chunk_queue.append(key)
	if force:
		while not _chunk_queue.is_empty():
			var ck2: Vector2i = _chunk_queue.pop_front()
			if not loaded_chunks.has(ck2):
				_load_chunk(ck2)

func _is_exposed(pos: Vector3i) -> bool:
	for d in [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,1,0), Vector3i(0,-1,0), Vector3i(0,0,1), Vector3i(0,0,-1)]:
		var n: Vector3i = pos + d
		if not blocks.has(n) or str(blocks[n]) == "water": return true
	return false

func _load_chunk(ck: Vector2i) -> void:
	if loaded_chunks.has(ck): return
	var build_started := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [ck.x, ck.y]
	chunk_root.add_child(root)
	loaded_chunks[ck] = root
	var x0 := ck.x * CHUNK_SIZE
	var z0 := ck.y * CHUNK_SIZE
	var render_groups: Dictionary = {}
	var collision_faces := PackedVector3Array()
	var block_count := 0
	var collision_face_count := 0
	for x in range(x0, x0 + CHUNK_SIZE):
		for z in range(z0, z0 + CHUNK_SIZE):
			for y in range(MIN_Y, 28):
				var pos := Vector3i(x, y, z)
				if not blocks.has(pos): continue
				var kind := str(blocks[pos])
				if not (_is_exposed(pos) or kind in ["chest", "water"]):
					continue
				if kind != "water":
					collision_face_count += _append_exposed_collision_faces(collision_faces, pos)
				_append_exposed_render_faces(render_groups, pos, kind)
				block_count += 1
	var render_triangles := 0
	var render_vertex_bytes := 0
	var render_face_quads := 0
	for group_variant in render_groups.keys():
		var render_group: Dictionary = render_groups[group_variant]
		var group_vertices: PackedVector3Array = render_group["vertices"]
		var group_indices: PackedInt32Array = render_group["indices"]
		render_triangles += int(group_indices.size() / 3)
		render_face_quads += int(group_indices.size() / 6)
		render_vertex_bytes += group_vertices.size() * 40 + group_indices.size() * 4
	chunk_render_triangle_count_total += render_triangles
	chunk_render_vertex_bytes_total += render_vertex_bytes
	chunk_render_full_cube_triangle_equivalent_total += block_count * 12
	chunk_render_face_quads_total += render_face_quads
	_build_chunk_surface_meshes(root, render_groups)
	if not collision_faces.is_empty():
		var body := StaticBody3D.new()
		body.name = "ChunkCollision"
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("chunk_key", ck)
		var collision := CollisionShape3D.new()
		collision.name = "ChunkCollisionShape"
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(collision_faces)
		# Exposed voxel faces meet the CharacterBody from either side during
		# spawn settling, chunk rebuilds, and slopes. Two-sided collision avoids
		# a winding-dependent hole in the concave chunk surface that let the
		# player fall through the spawn floor.
		shape.set_backface_collision_enabled(true)
		collision.shape = shape
		body.add_child(collision)
		root.add_child(body)
	chunk_build_count += 1
	chunk_build_ms_last = float(Time.get_ticks_msec() - build_started)
	chunk_build_ms_peak = maxf(chunk_build_ms_peak, chunk_build_ms_last)
	chunk_peak_loaded = maxi(chunk_peak_loaded, loaded_chunks.size())
	if OS.is_debug_build():
		print("CHUNK_PERF key=", ck, " blocks=", block_count, " batches=", render_groups.size(), " collision_faces=", collision_face_count, " render_triangles=", render_triangles, " full_cube_triangles=", block_count * 12, " render_face_quads=", render_face_quads, " render_buffer_bytes=", render_vertex_bytes, " nodes=", root.get_child_count(), " build_ms=", Time.get_ticks_msec() - build_started)

func _rebuild_terrain_surface_cache_from_blocks() -> void:
	terrain_surface_heights.clear()
	terrain_corner_heights.clear()
	for position_variant in blocks:
		var position: Vector3i = position_variant
		var surface_kind := str(blocks[position])
		if position.y > 14 or (surface_kind not in TERRAIN_SURFACE_KINDS and not (surface_kind == "water" and position.y == 2)):
			continue
		var key := Vector2i(position.x, position.z)
		var surface_y := float(position.y + 1)
		if not terrain_surface_heights.has(key) or surface_y > float(terrain_surface_heights[key]):
			terrain_surface_heights[key] = surface_y
	for x in range(-WORLD_RADIUS - 1, WORLD_RADIUS + 2):
		for z in range(-WORLD_RADIUS - 1, WORLD_RADIUS + 2):
			_refresh_terrain_corner_height(Vector2i(x, z))

func _refresh_terrain_corner_height(corner: Vector2i) -> void:
	var total := 0.0
	var samples := 0
	for ox in [-1, 0]:
		for oz in [-1, 0]:
			var column := Vector2i(corner.x + ox, corner.y + oz)
			if terrain_surface_heights.has(column):
				total += float(terrain_surface_heights[column])
				samples += 1
	if samples > 0:
		terrain_corner_heights[corner] = total / float(samples)
	else:
		terrain_corner_heights.erase(corner)

func _refresh_terrain_surface_column(x: int, z: int) -> void:
	# The procedural terrain never exceeds y=13; higher player structures are
	# intentionally excluded from natural-landscape smoothing.
	for structure_y in range(27, 14, -1):
		if str(blocks.get(Vector3i(x, structure_y, z), "")) in TERRAIN_SURFACE_KINDS:
			return
	var key := Vector2i(x, z)
	var found := false
	for y in range(14, MIN_Y - 1, -1):
		var surface_kind := str(blocks.get(Vector3i(x, y, z), ""))
		if surface_kind in TERRAIN_SURFACE_KINDS or (surface_kind == "water" and y == 2):
			terrain_surface_heights[key] = float(y + 1)
			found = true
			break
	if not found:
		terrain_surface_heights.erase(key)
	for corner_x in [x, x + 1]:
		for corner_z in [z, z + 1]:
			_refresh_terrain_corner_height(Vector2i(corner_x, corner_z))

func _terrain_normal_at_corner(corner: Vector2i) -> Vector3:
	var center_height := float(terrain_corner_heights.get(corner, 3.0))
	var left_height := float(terrain_corner_heights.get(corner + Vector2i(-1, 0), center_height))
	var right_height := float(terrain_corner_heights.get(corner + Vector2i(1, 0), center_height))
	var north_height := float(terrain_corner_heights.get(corner + Vector2i(0, -1), center_height))
	var south_height := float(terrain_corner_heights.get(corner + Vector2i(0, 1), center_height))
	return Vector3(left_height - right_height, 2.0, north_height - south_height).normalized()

func _smooth_terrain_vertex(vertex: Vector3) -> Vector3:
	var corner := Vector2i(roundi(vertex.x), roundi(vertex.z))
	if terrain_corner_heights.has(corner):
		vertex.y = float(terrain_corner_heights[corner])
	return vertex

func _append_exposed_render_faces(groups: Dictionary, pos: Vector3i, kind: String) -> void:
	if not groups.has(kind):
		groups[kind] = {"vertices": PackedVector3Array(), "normals": PackedVector3Array(), "colors": PackedColorArray(), "indices": PackedInt32Array()}
	var group: Dictionary = groups[kind]
	var vertices: PackedVector3Array = group["vertices"]
	var normals: PackedVector3Array = group["normals"]
	var colors: PackedColorArray = group["colors"]
	var indices: PackedInt32Array = group["indices"]
	var x := float(pos.x)
	var y := float(pos.y)
	var z := float(pos.z)
	var terrain_column := Vector2i(pos.x, pos.z)
	var smooth_surface := (kind in TERRAIN_SURFACE_KINDS or (kind == "water" and pos.y == 2)) and terrain_surface_heights.has(terrain_column) and is_equal_approx(float(terrain_surface_heights[terrain_column]), y + 1.0)
	var faces := [
		[Vector3i(1, 0, 0), Vector3(x + 1, y, z), Vector3(x + 1, y + 1, z), Vector3(x + 1, y + 1, z + 1), Vector3(x + 1, y, z + 1), Vector3.RIGHT],
		[Vector3i(-1, 0, 0), Vector3(x, y, z), Vector3(x, y, z + 1), Vector3(x, y + 1, z + 1), Vector3(x, y + 1, z), Vector3.LEFT],
		[Vector3i(0, 1, 0), Vector3(x, y + 1, z), Vector3(x, y + 1, z + 1), Vector3(x + 1, y + 1, z + 1), Vector3(x + 1, y + 1, z), Vector3.UP],
		[Vector3i(0, -1, 0), Vector3(x, y, z), Vector3(x + 1, y, z), Vector3(x + 1, y, z + 1), Vector3(x, y, z + 1), Vector3.DOWN],
		[Vector3i(0, 0, 1), Vector3(x, y, z + 1), Vector3(x + 1, y, z + 1), Vector3(x + 1, y + 1, z + 1), Vector3(x, y + 1, z + 1), Vector3.BACK],
		[Vector3i(0, 0, -1), Vector3(x, y, z), Vector3(x, y + 1, z), Vector3(x + 1, y + 1, z), Vector3(x + 1, y, z), Vector3.FORWARD]
	]
	for face in faces:
		var neighbor: Vector3i = pos + face[0]
		var neighbor_exists: bool = blocks.has(neighbor)
		var neighbor_kind := str(blocks.get(neighbor, ""))
		var visible := not neighbor_exists
		if kind != "water" and neighbor_kind == "water":
			visible = true
		if kind == "water" and neighbor_exists:
			visible = false
		if not visible:
			continue
		var a: Vector3 = face[1]
		var b: Vector3 = face[2]
		var c: Vector3 = face[3]
		var d: Vector3 = face[4]
		var normal: Vector3 = face[5]
		var smoothed_face := false
		# Natural ground surface blocks share corner heights across neighbouring
		# columns. Render and collision therefore agree on the same gentle slopes.
		if smooth_surface:
			if is_equal_approx(a.y, y + 1.0):
				var next_a := _smooth_terrain_vertex(a)
				smoothed_face = smoothed_face or not is_equal_approx(next_a.y, a.y)
				a = next_a
			if is_equal_approx(b.y, y + 1.0):
				var next_b := _smooth_terrain_vertex(b)
				smoothed_face = smoothed_face or not is_equal_approx(next_b.y, b.y)
				b = next_b
			if is_equal_approx(c.y, y + 1.0):
				var next_c := _smooth_terrain_vertex(c)
				smoothed_face = smoothed_face or not is_equal_approx(next_c.y, c.y)
				c = next_c
			if is_equal_approx(d.y, y + 1.0):
				var next_d := _smooth_terrain_vertex(d)
				smoothed_face = smoothed_face or not is_equal_approx(next_d.y, d.y)
				d = next_d
		# Per-face biome colour is baked into the existing vertex buffer: no
		# extra materials, texture lookups, nodes, draw calls or triangles.
		# Grass tops vary with local moisture/altitude while their exposed sides
		# read as an earthy soil-and-rock layer instead of one flat green plane.
		var noise_value := sin(float(pos.x) * 12.9898 + float(pos.y) * 78.233 + float(pos.z) * 37.719)
		var broad_biome := 0.5 + 0.5 * sin(float(pos.x) * 0.071 + cos(float(pos.z) * 0.053) * 1.7)
		var fine_biome := 0.5 + 0.5 * cos(float(pos.x + pos.z) * 0.31 + float(pos.x - pos.z) * 0.17)
		var variation := 0.88 + (noise_value * 0.5 + 0.5) * 0.20
		var tint := Color(variation, variation, variation, 1.0)
		match kind:
			"grass":
				if normal.y > 0.5:
					var meadow := Color("#397b35").lerp(Color("#86b94a"), broad_biome * 0.72 + fine_biome * 0.28)
					tint = meadow * variation * 1.04
				else:
					var soil := Color("#604b35").lerp(Color("#8a7048"), fine_biome * 0.55)
					tint = soil * variation * 0.92
			"dirt":
				tint = Color("#795337").lerp(Color("#a0784b"), fine_biome * 0.45) * variation
			"stone", "rock":
				tint = Color("#59666a").lerp(Color("#929b98"), fine_biome * 0.48) * variation
			"sand", "gravel":
				tint = Color("#b69b68").lerp(Color("#e2d09b"), fine_biome * 0.48) * variation
			"water":
				# Keep the river's broad surface visually continuous. Small world-space
				# colour waves replace per-voxel contrast that made the water look tiled.
				var depth_tint := 0.5 + 0.5 * sin(float(pos.x) * 0.075 + float(pos.z) * 0.061)
				var water_variation := 0.97 + depth_tint * 0.045
				tint = Color("#236f98").lerp(Color("#459fbd"), depth_tint * 0.30) * water_variation
			"leaves":
				tint = Color("#245c2c").lerp(Color("#69a83e"), broad_biome * 0.65 + fine_biome * 0.35) * variation
		if normal.y > 0.5:
			tint = tint.lightened(0.035)
		elif absf(normal.y) < 0.5:
			tint = tint.darkened(0.045)
		var base_index := vertices.size()
		if smoothed_face:
			# A warped quad is two non-coplanar triangles. Give each triangle its
			# own three vertices/normals so the mesh winding test and lighting stay exact.
			var first_normal := (c - a).cross(b - a)
			var second_normal := (d - a).cross(c - a)
			if first_normal.length_squared() < 0.0001 or second_normal.length_squared() < 0.0001:
				continue
			vertices.append_array(PackedVector3Array([a, c, b, a, d, c]))
			if normal.y > 0.5:
				var first_outward := -first_normal.normalized()
				var second_outward := -second_normal.normalized()
				# The indexed-surface acceptance contract requires each triangle's
				# vertex normals to match its exact geometric face normal. Keep the
				# normals deterministic and correct; visual smoothing belongs in
				# finer surface tessellation, not mismatched shading vectors.
				var first_outward := -first_normal.normalized()
				var second_outward := -second_normal.normalized()
				var normal_a := first_outward
				var normal_b := first_outward
				var normal_c := first_outward
				var normal_d := second_outward
				var second_normal_a := second_outward
				var second_normal_c := second_outward
				normals.append_array(PackedVector3Array([normal_a, normal_c, normal_b, second_normal_a, normal_d, second_normal_c]))
			else:
				normals.append_array(PackedVector3Array([-first_normal.normalized(), -first_normal.normalized(), -first_normal.normalized(), -second_normal.normalized(), -second_normal.normalized(), -second_normal.normalized()]))
			colors.append_array(PackedColorArray([tint, tint, tint, tint, tint, tint]))
			indices.append_array(PackedInt32Array([base_index, base_index + 1, base_index + 2, base_index + 3, base_index + 4, base_index + 5]))
		else:
			vertices.append_array(PackedVector3Array([a, b, c, d]))
			normals.append_array(PackedVector3Array([normal, normal, normal, normal]))
			colors.append_array(PackedColorArray([tint, tint, tint, tint]))
			indices.append_array(PackedInt32Array([base_index, base_index + 2, base_index + 1, base_index, base_index + 3, base_index + 2]))
	group["vertices"] = vertices
	group["normals"] = normals
	group["colors"] = colors
	group["indices"] = indices
	groups[kind] = group

func _build_chunk_surface_meshes(parent: Node3D, render_groups: Dictionary) -> void:
	for kind_variant in render_groups.keys():
		var kind := str(kind_variant)
		var group: Dictionary = render_groups[kind_variant]
		var vertices: PackedVector3Array = group["vertices"]
		var normals: PackedVector3Array = group["normals"]
		var colors: PackedColorArray = group["colors"]
		var indices: PackedInt32Array = group["indices"]
		if vertices.is_empty() or indices.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var instance := MeshInstance3D.new()
		instance.name = "Surface_" + kind
		instance.mesh = mesh
		var surface_material := (block_materials.get(kind, block_materials["stone"]) as StandardMaterial3D).duplicate() as StandardMaterial3D
		# Preserve normal back-face culling after emitting clockwise front faces.
		surface_material.cull_mode = BaseMaterial3D.CULL_BACK
		surface_material.vertex_color_use_as_albedo = true
		instance.material_override = surface_material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)

func _append_exposed_collision_faces(faces: PackedVector3Array, pos: Vector3i) -> int:
	var x := float(pos.x)
	var y := float(pos.y)
	var z := float(pos.z)
	var count := 0
	var kind := str(blocks.get(pos, ""))
	var terrain_column := Vector2i(pos.x, pos.z)
	var smooth_surface := kind in TERRAIN_SURFACE_KINDS and terrain_surface_heights.has(terrain_column) and is_equal_approx(float(terrain_surface_heights[terrain_column]), y + 1.0)
	# Build only boundary faces. The smoothed render top and collision top use
	# the same shared corner heights, so the player does not float or sink.
	if not blocks.has(pos + Vector3i(1, 0, 0)) or str(blocks.get(pos + Vector3i(1, 0, 0), "")) == "water":
		_append_surface_aware_collision_quad(faces, Vector3(x + 1, y, z), Vector3(x + 1, y + 1, z), Vector3(x + 1, y + 1, z + 1), Vector3(x + 1, y, z + 1), smooth_surface, y)
		count += 1
	if not blocks.has(pos + Vector3i(-1, 0, 0)) or str(blocks.get(pos + Vector3i(-1, 0, 0), "")) == "water":
		_append_surface_aware_collision_quad(faces, Vector3(x, y, z), Vector3(x, y, z + 1), Vector3(x, y + 1, z + 1), Vector3(x, y + 1, z), smooth_surface, y)
		count += 1
	if not blocks.has(pos + Vector3i(0, 1, 0)) or str(blocks.get(pos + Vector3i(0, 1, 0), "")) == "water":
		_append_surface_aware_collision_quad(faces, Vector3(x, y + 1, z), Vector3(x, y + 1, z + 1), Vector3(x + 1, y + 1, z + 1), Vector3(x + 1, y + 1, z), smooth_surface, y)
		count += 1
	if not blocks.has(pos + Vector3i(0, -1, 0)) or str(blocks.get(pos + Vector3i(0, -1, 0), "")) == "water":
		_append_surface_aware_collision_quad(faces, Vector3(x, y, z), Vector3(x + 1, y, z), Vector3(x + 1, y, z + 1), Vector3(x, y, z + 1), smooth_surface, y)
		count += 1
	if not blocks.has(pos + Vector3i(0, 0, 1)) or str(blocks.get(pos + Vector3i(0, 0, 1), "")) == "water":
		_append_surface_aware_collision_quad(faces, Vector3(x, y, z + 1), Vector3(x + 1, y, z + 1), Vector3(x + 1, y + 1, z + 1), Vector3(x, y + 1, z + 1), smooth_surface, y)
		count += 1
	if not blocks.has(pos + Vector3i(0, 0, -1)) or str(blocks.get(pos + Vector3i(0, 0, -1), "")) == "water":
		_append_surface_aware_collision_quad(faces, Vector3(x, y, z), Vector3(x, y + 1, z), Vector3(x + 1, y + 1, z), Vector3(x + 1, y, z), smooth_surface, y)
		count += 1
	return count

func _append_surface_aware_collision_quad(faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, smooth_surface: bool, base_y: float) -> void:
	if smooth_surface:
		if a.y > base_y + 0.5: a = _smooth_terrain_vertex(a)
		if b.y > base_y + 0.5: b = _smooth_terrain_vertex(b)
		if c.y > base_y + 0.5: c = _smooth_terrain_vertex(c)
		if d.y > base_y + 0.5: d = _smooth_terrain_vertex(d)
	_append_collision_quad(faces, a, b, c, d)

func _append_collision_quad(faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	faces.append(a)
	faces.append(b)
	faces.append(c)
	faces.append(a)
	faces.append(c)
	faces.append(d)

func _build_chunk_multimeshes(parent: Node3D, render_groups: Dictionary) -> void:
	for kind_variant in render_groups.keys():
		var kind := str(kind_variant)
		var transforms: Array = render_groups[kind_variant]
		if transforms.is_empty(): continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = block_mesh
		mm.instance_count = transforms.size()
		for i in range(transforms.size()):
			mm.set_instance_transform(i, transforms[i])
		var mi := MultiMeshInstance3D.new()
		mi.name = "Batch_" + kind
		mi.multimesh = mm
		mi.material_override = block_materials.get(kind, block_materials["stone"])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)

func _rebuild_chunk(ck: Vector2i) -> void:
	if not loaded_chunks.has(ck): return
	var old_root: Node = loaded_chunks[ck]
	loaded_chunks.erase(ck)
	if is_instance_valid(old_root): old_root.queue_free()
	_load_chunk(ck)

func _spawn_block_in(parent: Node, pos: Vector3i, kind: String) -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(float(pos.x) + 0.5, float(pos.y) + 0.5, float(pos.z) + 0.5)
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("block_position", pos)
	body.set_meta("block_kind", kind)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = block_mesh
	mesh_instance.material_override = block_materials.get(kind, block_materials["stone"])
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh_instance)
	if kind != "water":
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3.ONE
		collision.shape = shape
		body.add_child(collision)
	parent.add_child(body)

func _find_block_node(pos: Vector3i) -> Node:
	var ck := _chunk_key_from_world(pos.x, pos.z)
	if not loaded_chunks.has(ck): return null
	for node in loaded_chunks[ck].get_children():
		if node.has_meta("block_position") and node.get_meta("block_position") == pos:
			return node
	return null

func _reveal_neighbors(pos: Vector3i) -> void:
	for d in [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,1,0), Vector3i(0,-1,0), Vector3i(0,0,1), Vector3i(0,0,-1)]:
		var n: Vector3i = pos + d
		if not blocks.has(n) or _find_block_node(n) != null: continue
		var ck := _chunk_key_from_world(n.x, n.z)
		if loaded_chunks.has(ck):
			_spawn_block_in(loaded_chunks[ck], n, str(blocks[n]))

func remove_block(pos: Vector3i) -> void:
	if not blocks.has(pos): return
	var kind := str(blocks[pos])
	if mining_fx and mining_fx.has_method("play_break"):
		mining_fx.play_break(Vector3(pos), kind)
	blocks.erase(pos)
	_refresh_terrain_surface_column(pos.x, pos.z)
	_rebuild_chunk(_chunk_key_from_world(pos.x, pos.z))
	# A boundary edit can expose faces in the neighboring chunk.
	for d in [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,0,1), Vector3i(0,0,-1)]:
		var neighbor_ck := _chunk_key_from_world(pos.x + d.x, pos.z + d.z)
		if neighbor_ck != _chunk_key_from_world(pos.x, pos.z):
			_rebuild_chunk(neighbor_ck)
	mark_world_dirty()

func place_block(pos: Vector3i, kind: String = "dirt") -> void:
	if blocks.has(pos) or pos.y < MIN_Y or pos.y > 80: return
	if player and player.global_position.distance_to(Vector3(pos) + Vector3(0.5, 0.5, 0.5)) < 1.8: return
	blocks[pos] = kind
	_refresh_terrain_surface_column(pos.x, pos.z)
	var ck := _chunk_key_from_world(pos.x, pos.z)
	_rebuild_chunk(ck)
	if mining_fx and mining_fx.has_method("play_place"):
		mining_fx.play_place(Vector3(pos), kind)
	mark_world_dirty()

func mark_world_dirty() -> void:
	_save_dirty = true
	_autosave_timer = AUTO_SAVE_INTERVAL

func _tick_autosave(delta: float) -> void:
	if not _save_dirty: return
	_autosave_timer -= delta
	if _autosave_timer <= 0.0: save_world()

func _respawn_at_safe_pad() -> void:
	if player == null:
		return
	# Repair terrain and rebuild its collision together, so recovery cannot
	# teleport the player onto a surface that exists only in the block dictionary.
	_ensure_spawn_pad()
	var spawn_chunk := _chunk_key_from_world(0, 0)
	if loaded_chunks.has(spawn_chunk):
		_rebuild_chunk(spawn_chunk)
	else:
		_load_chunk(spawn_chunk)
	_snap_player_to_surface()
	_last_player_chunk = Vector2i(9999, 9999)
	_update_chunks(false)
	mark_world_dirty()
	print("BLOCKRAFT_RESPAWN_SAFE position=", player.global_position)

func _check_fall_respawn() -> void:
	if player == null:
		return
	if player.global_position.y < float(MIN_Y) - 8.0:
		_respawn_at_safe_pad()
		_show_toast("You fell — safe spawn restored", 2.0)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_GO_BACK_REQUEST, NOTIFICATION_EXIT_TREE]:
		if _save_dirty or what == NOTIFICATION_WM_CLOSE_REQUEST:
			save_world(what != NOTIFICATION_EXIT_TREE)

func _is_valid_save_candidate(path: String, minimum_blocks: int = 2000) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var version := int(parsed.get("version", -1))
	if version != SAVE_VERSION and version != PREVIOUS_SAVE_VERSION:
		return false
	if version >= SAVE_VERSION and (inventory == null or not inventory.has_method("validate_state") or not inventory.validate_state(parsed.get("inventory", {}))):
		return false
	var entries = parsed.get("blocks", [])
	if typeof(entries) != TYPE_ARRAY or entries.size() < minimum_blocks:
		return false
	var valid_blocks := 0
	for entry in entries:
		if typeof(entry) == TYPE_ARRAY and entry.size() >= 4:
			valid_blocks += 1
		elif typeof(entry) == TYPE_DICTIONARY and entry.has("x") and entry.has("y") and entry.has("z") and entry.has("kind"):
			valid_blocks += 1
		if valid_blocks >= minimum_blocks:
			return true
	return false

func save_world(show_feedback: bool = false) -> void:
	# Write and validate a complete snapshot before replacing the last known-good save.
	var serialized: Array = []
	serialized.resize(blocks.size())
	var index := 0
	for p in blocks:
		serialized[index] = [p.x, p.y, p.z, str(blocks[p])]
		index += 1
	var payload := {
		"version": SAVE_VERSION,
		"blocks": serialized,
		"inventory": inventory.export_state() if inventory and inventory.has_method("export_state") else {},
		"saved_at": Time.get_datetime_string_from_system()
	}
	var encoded := JSON.stringify(payload)
	var temp_path := SAVE_PATH + ".tmp"
	var backup_path := SAVE_PATH + ".bak"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Blockraft: could not open temporary save; error=" + str(FileAccess.get_open_error()))
		return
	file.store_string(encoded)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		push_error("Blockraft: temporary save write failed; error=" + str(write_error))
		return
	var verify_file := FileAccess.open(temp_path, FileAccess.READ)
	if verify_file == null:
		push_error("Blockraft: temporary save could not be reopened")
		return
	var verified = JSON.parse_string(verify_file.get_as_text())
	verify_file.close()
	if typeof(verified) != TYPE_DICTIONARY:
		push_error("Blockraft: temporary save JSON root is not a Dictionary; previous save preserved")
		return
	var verified_blocks: Variant = verified.get("blocks", null)
	if typeof(verified_blocks) != TYPE_ARRAY or verified_blocks.size() != blocks.size():
		push_error("Blockraft: temporary save block count mismatch; expected=%d actual=%d; previous save preserved" % [blocks.size(), verified_blocks.size() if typeof(verified_blocks) == TYPE_ARRAY else -1])
		return
	if not _is_valid_save_candidate(temp_path, 1):
		var candidate_inventory: Variant = verified.get("inventory", {})
		var candidate_inventory_valid: bool = false
		if inventory != null and inventory.has_method("validate_state"):
			candidate_inventory_valid = bool(inventory.call("validate_state", candidate_inventory))
		push_error("Blockraft: temporary save candidate rejected; version=%d blocks=%d inventory_valid=%s inventory=%s; previous save preserved" % [
			int(verified.get("version", -1)), verified_blocks.size(), str(candidate_inventory_valid), JSON.stringify(candidate_inventory)
		])
		return
	var absolute_save := ProjectSettings.globalize_path(SAVE_PATH)
	var absolute_temp := ProjectSettings.globalize_path(temp_path)
	var absolute_backup := ProjectSettings.globalize_path(backup_path)
	var quarantined_path := SAVE_PATH + ".invalid"
	var absolute_quarantined := ProjectSettings.globalize_path(quarantined_path)
	var moved_primary_to_backup := false
	var moved_invalid_to_quarantine := false
	if FileAccess.file_exists(SAVE_PATH):
		if _is_valid_save_candidate(SAVE_PATH):
			# Rotate only a valid primary snapshot. Once it is in .bak, it is
			# the last-known-good copy if the new temporary save cannot be committed.
			if FileAccess.file_exists(backup_path):
				var remove_backup_error := DirAccess.remove_absolute(absolute_backup)
				if remove_backup_error != OK:
					push_error("Blockraft: could not retire old backup; error=" + str(remove_backup_error))
					return
			var backup_error := DirAccess.rename_absolute(absolute_save, absolute_backup)
			if backup_error != OK:
				push_error("Blockraft: could not preserve previous save; error=" + str(backup_error))
				return
			moved_primary_to_backup = true
		else:
			# A corrupt primary must never replace a valid backup during recovery.
			if FileAccess.file_exists(quarantined_path):
				var remove_quarantine_error := DirAccess.remove_absolute(absolute_quarantined)
				if remove_quarantine_error != OK:
					push_error("Blockraft: could not clear stale invalid-save quarantine; error=" + str(remove_quarantine_error))
					return
			var quarantine_error := DirAccess.rename_absolute(absolute_save, absolute_quarantined)
			if quarantine_error != OK:
				push_error("Blockraft: could not quarantine invalid primary save; error=" + str(quarantine_error))
				return
			moved_invalid_to_quarantine = true
	var replace_error := DirAccess.rename_absolute(absolute_temp, absolute_save)
	if replace_error != OK:
		if moved_primary_to_backup and FileAccess.file_exists(backup_path):
			var restore_error := DirAccess.rename_absolute(absolute_backup, absolute_save)
			if restore_error != OK:
				push_error("Blockraft: new save failed and previous primary could not be restored; backup remains available")
		elif moved_invalid_to_quarantine and FileAccess.file_exists(quarantined_path):
			var restore_invalid_error := DirAccess.rename_absolute(absolute_quarantined, absolute_save)
			if restore_invalid_error != OK:
				push_error("Blockraft: invalid primary could not be restored; last-known-good backup remains untouched")
		push_error("Blockraft: could not commit new save; error=" + str(replace_error))
		return
	if moved_invalid_to_quarantine and FileAccess.file_exists(quarantined_path):
		DirAccess.remove_absolute(absolute_quarantined)
	_save_dirty = false
	_autosave_timer = AUTO_SAVE_INTERVAL
	if show_feedback:
		_show_toast("World saved", 1.2)

func _load_world_snapshot() -> bool:
	var candidates := [SAVE_PATH, SAVE_PATH + ".bak"]
	for candidate in candidates:
		if not FileAccess.file_exists(candidate):
			continue
		var file := FileAccess.open(candidate, FileAccess.READ)
		if file == null:
			push_warning("Blockraft: could not open save candidate " + candidate)
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(parsed) != TYPE_DICTIONARY:
			push_warning("Blockraft: invalid save JSON in " + candidate)
			continue
		var version := int(parsed.get("version", -1))
		if version != SAVE_VERSION and version != PREVIOUS_SAVE_VERSION:
			push_warning("Blockraft: unsupported save version in " + candidate)
			continue
		if version >= SAVE_VERSION and (inventory == null or not inventory.has_method("validate_state") or not inventory.validate_state(parsed.get("inventory", {}))):
			push_warning("Blockraft: invalid inventory snapshot in " + candidate)
			continue
		var entries = parsed.get("blocks", [])
		if typeof(entries) != TYPE_ARRAY or entries.size() < 2000:
			push_warning("Blockraft: incomplete block snapshot in " + candidate)
			continue
		var restored: Dictionary = {}
		for entry in entries:
			if typeof(entry) == TYPE_ARRAY:
				if entry.size() < 4:
					continue
				restored[Vector3i(int(entry[0]), int(entry[1]), int(entry[2]))] = str(entry[3])
			elif typeof(entry) == TYPE_DICTIONARY:
				if not entry.has("x") or not entry.has("y") or not entry.has("z") or not entry.has("kind"):
					continue
				restored[Vector3i(int(entry["x"]), int(entry["y"]), int(entry["z"]))] = str(entry["kind"])
		if restored.size() < 2000:
			push_warning("Blockraft: too few valid blocks in " + candidate)
			continue
		blocks = restored
		if version >= SAVE_VERSION and inventory and inventory.has_method("import_state"):
			if not inventory.import_state(parsed.get("inventory", {})):
				push_warning("Blockraft: inventory snapshot invalid; starting with default inventory")
		print("Blockraft: restored save candidate=", candidate, " blocks=", blocks.size(), " version=", version)
		return true
	return false

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GameUI"
	add_child(layer)
	status_label = Label.new()
	status_label.position = Vector2(12, 246)
	status_label.size = Vector2(320, 22)
	status_label.visible = false
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_label.add_theme_color_override("font_color", Color("#f4f7e8"))
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color("#c8e0d0"))
	layer.add_child(status_label)
	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 16)
	toast_label.add_theme_color_override("font_color", Color("#ffe9a0"))
	toast_label.position = Vector2(100, 120)
	toast_label.size = Vector2(600, 40)
	layer.add_child(toast_label)
	_build_hotbar(layer)
	inventory.selection_changed.connect(_refresh_hotbar)
	inventory.counts_changed.connect(_refresh_hotbar)
	inventory.backpack_changed.connect(_on_backpack_changed)
	_build_backpack_ui(layer)
	_refresh_hotbar()
	_refresh_status()

func _show_toast(text: String, duration: float = 2.5) -> void:
	if toast_label == null: return
	toast_label.text = text
	toast_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.6)

func _refresh_status() -> void:
	if status_label == null: return
	var bits: PackedStringArray = []
	for k in ["coal", "iron", "gold", "crystal", "chest"]:
		if discovered.get(k, false): bits.append(k.capitalize())
	status_label.text = "Discovered: " + ", ".join(bits)
	status_label.visible = not bits.is_empty()

func _build_hotbar(layer: CanvasLayer) -> void:
	var bar := HBoxContainer.new()
	bar.name = "Hotbar"
	bar.add_theme_constant_override("separation", 6)
	layer.add_child(bar)
	hotbar_ui = bar
	hotbar_slots.clear()
	for i in range(inventory.SLOT_COUNT):
		var slot := Panel.new()
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.custom_minimum_size = Vector2(56, 56)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.08, 0.1, 0.82)
		style.border_color = Color("#6ab88a")
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		slot.add_theme_stylebox_override("panel", style)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		slot.add_child(v)
		var icon := ColorRect.new()
		icon.name = "Icon"
		icon.custom_minimum_size = Vector2(36, 28)
		v.add_child(icon)
		var count := Label.new()
		count.name = "Count"
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.add_theme_font_size_override("font_size", 11)
		v.add_child(count)
		var key := Label.new()
		key.name = "Key"
		key.text = str(i + 1)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.add_theme_font_size_override("font_size", 10)
		v.add_child(key)
		var slot_index := i
		slot.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				inventory.select(slot_index)
			elif event is InputEventScreenTouch and event.pressed:
				inventory.select(slot_index)
		)
		bar.add_child(slot)
		hotbar_slots.append(slot)
	_layout_hotbar()
	get_viewport().size_changed.connect(_layout_hotbar)

func _layout_hotbar(viewport_size: Vector2 = Vector2.ZERO) -> void:
	if hotbar_ui == null: return
	var vs := viewport_size if viewport_size.x > 0.0 else get_viewport().get_visible_rect().size
	var compact := vs.x < 700.0
	var gap := 2 if compact else 6
	var slot_size := 56.0
	if compact:
		slot_size = clampf((vs.x - 24.0 - float(gap * (inventory.SLOT_COUNT - 1))) / float(inventory.SLOT_COUNT), 26.0, 56.0)
	hotbar_ui.add_theme_constant_override("separation", gap)
	for slot_variant in hotbar_slots:
		var slot := slot_variant as Panel
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
		var icon := slot.find_child("Icon", true, false) as ColorRect
		if icon:
			icon.custom_minimum_size = Vector2(slot_size * 0.64, slot_size * 0.32)
		var count := slot.find_child("Count", true, false) as Label
		if count:
			count.add_theme_font_size_override("font_size", 8 if compact else 10)
		var key := slot.find_child("Key", true, false) as Label
		if key:
			key.add_theme_font_size_override("font_size", 7 if compact else 9)
	var total_width := slot_size * float(inventory.SLOT_COUNT) + float(gap * (inventory.SLOT_COUNT - 1))
	hotbar_ui.size = Vector2(total_width, slot_size)
	hotbar_ui.position = Vector2(maxf(0.0, (vs.x - total_width) * 0.5), vs.y - (250.0 if compact else slot_size + 28.0))
	if toast_label:
		toast_label.size = Vector2(maxf(0.0, vs.x - 24.0), 40.0) if compact else Vector2(600.0, 40.0)
		toast_label.position = Vector2(12.0, 300.0) if compact else Vector2(vs.x * 0.5 - 300.0, 110.0)
	if status_label:
		status_label.position = Vector2(12.0, 246.0)
		status_label.size = Vector2(maxf(0.0, vs.x - 24.0), 22.0)
	_layout_backpack_ui(vs)

func _layout_backpack_ui(viewport_size: Vector2 = Vector2.ZERO) -> void:
	if backpack_label == null or upgrade_btn == null:
		return
	var vs := viewport_size if viewport_size.x > 0.0 else get_viewport().get_visible_rect().size
	var compact := vs.x < 700.0
	# Keep the bag label comfortably inside the safe area; a wide right-aligned
	# control can appear clipped on narrow devices even when its text is short.
	var label_width := minf(320.0, maxf(120.0, vs.x * (0.48 if compact else 0.34)))
	var button_width := minf(156.0, maxf(112.0, vs.x * 0.42))
	# On narrow touch screens the survival panel occupies the upper-left
	# quadrant. Keep the backpack readout in a dedicated top-right strip above
	# that panel instead of letting its 42px Y offset collide at 360px width.
	backpack_label.size = Vector2(label_width, 28.0 if compact else 20.0)
	backpack_label.position = Vector2(vs.x - label_width - 20.0, 4.0 if compact else 42.0)
	backpack_label.clip_text = false
	backpack_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	backpack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	backpack_label.add_theme_font_size_override("font_size", 11 if compact else 12)
	upgrade_btn.size = Vector2(button_width, 28.0)
	upgrade_btn.position = Vector2(vs.x - button_width - 12.0, 84.0)

func _build_backpack_ui(layer: CanvasLayer) -> void:
	backpack_label = Label.new()
	backpack_label.add_theme_font_size_override("font_size", 12)
	backpack_label.add_theme_color_override("font_color", Color("#d8e8d0"))
	layer.add_child(backpack_label)
	upgrade_btn = Button.new()
	upgrade_btn.text = "Depot / Upgrade"
	upgrade_btn.custom_minimum_size = Vector2(156, 28)
	upgrade_btn.pressed.connect(_on_upgrade_pressed)
	layer.add_child(upgrade_btn)
	_refresh_backpack_ui()

func _on_backpack_changed(_tier: String = "") -> void:
	_refresh_backpack_ui()
	_refresh_hotbar()

func _on_upgrade_pressed() -> void:
	use_depot()

func _refresh_backpack_ui() -> void:
	if backpack_label == null: return
	backpack_label.text = "%s · %d max" % [inventory.get_backpack_label(), inventory.get_max_stack()]
	if upgrade_btn:
		upgrade_btn.tooltip_text = inventory.upgrade_cost_text()

func _refresh_hotbar(_arg = null) -> void:
	_refresh_backpack_ui()
	if hotbar_slots.is_empty(): return
	for i in range(inventory.SLOT_COUNT):
		var slot: Panel = hotbar_slots[i]
		var data: Dictionary = inventory.slots[i]
		var style := StyleBoxFlat.new()
		if i == inventory.selected:
			style.border_color = Color("#f1c86c")
			style.set_border_width_all(3)
			style.bg_color = Color(0.12, 0.16, 0.12, 0.92)
		else:
			style.border_color = Color("#6ab88a")
			style.set_border_width_all(2)
			style.bg_color = Color(0.05, 0.08, 0.1, 0.82)
		style.set_corner_radius_all(8)
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		slot.add_theme_stylebox_override("panel", style)
		var icon := slot.find_child("Icon", true, false) as ColorRect
		var count := slot.find_child("Count", true, false) as Label
		if icon:
			icon.color = Color(0.15, 0.18, 0.18, 0.4) if str(data.get("id", "")) == "" else data.get("color", Color.GRAY)
		if count:
			if data.get("is_tool", false): count.text = "Pick"
			elif str(data.get("id", "")) == "": count.text = ""
			else: count.text = str(int(data.get("count", 0)))
	_layout_hotbar()

func try_place_selected(pos: Vector3i) -> bool:
	var kind: String = str(inventory.get_place_kind())
	if kind == "" or kind == "chest": return false
	if blocks.has(pos) or pos.y < MIN_Y or pos.y > 80: return false
	if player:
		var target_center := Vector3(pos) + Vector3(0.5, 0.5, 0.5)
		var target_distance := player.global_position.distance_to(target_center)
		if target_distance < 1.8 or target_distance > 7.0:
			return false
	if not inventory.consume_place(): return false
	blocks[pos] = kind
	var ck := _chunk_key_from_world(pos.x, pos.z)
	# Rebuild the whole edited chunk so neighboring exposed faces disappear
	# from both rendering and collision. Boundary edits also affect the adjacent
	# chunk's shared face and must rebuild it when that chunk is resident.
	_rebuild_chunk(ck)
	for direction in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		var neighbor_ck := _chunk_key_from_world(pos.x + direction.x, pos.z + direction.z)
		if neighbor_ck != ck:
			_rebuild_chunk(neighbor_ck)
	if mining_fx and mining_fx.has_method("play_place"):
		mining_fx.play_place(Vector3(pos), kind)
	mark_world_dirty()
	return true

func on_block_mined(kind: String) -> void:
	if kind == "chest":
		_open_chest_loot()
		return
	inventory.add_block(kind, 1)
	if kind in ["coal", "iron", "gold", "crystal"] and not discovered.get(kind, false):
		discovered[kind] = true
		_show_toast("Discovered %s ore!" % kind.capitalize(), 2.8)
		_refresh_status()
	elif kind in ["coal", "iron", "gold", "crystal"]:
		_show_toast("+1 %s" % kind.capitalize(), 1.2)

func _open_chest_loot() -> void:
	var loot := [["gold", 3], ["crystal", 2], ["iron", 6], ["coal", 8], ["wood", 12]]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pick: Array = loot[rng.randi_range(0, loot.size() - 1)]
	inventory.add_block(str(pick[0]), int(pick[1]))
	if not discovered.get("chest", false):
		discovered["chest"] = true
		_refresh_status()
	_show_toast("Chest! +%d %s" % [int(pick[1]), str(pick[0])], 3.0)
