extends Node3D
## Chunk-streamed voxel world — playable with spawn safety and auto-save.

const WORLD_RADIUS := 48
const MIN_Y := -6
const CHUNK_SIZE := 16
const VIEW_CHUNKS := 3
const MAX_CHUNK_BUILDS_PER_FRAME := 6
const SAVE_PATH := "user://world_blocks.json"
const SAVE_VERSION := 6
const AUTO_SAVE_INTERVAL := 8.0

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

func _ready() -> void:
	world_root = Node3D.new()
	world_root.name = "GeneratedWorld"
	add_child(world_root)
	chunk_root = Node3D.new()
	chunk_root.name = "Chunks"
	world_root.add_child(chunk_root)
	player = get_node("Player")
	if player:
		player.add_to_group("player")
	inventory = load("res://scripts/inventory.gd").new()
	inventory.name = "Inventory"
	add_child(inventory)
	mining_fx = load("res://scripts/mining_fx.gd").new()
	mining_fx.name = "MiningFX"
	add_child(mining_fx)
	_setup_materials()
	_generate_world()
	_load_world_snapshot()
	if blocks.size() < 500:
		push_warning("World too small (%d blocks); regenerating." % blocks.size())
		_generate_world()
	_ensure_spawn_pad()
	_snap_player_to_surface()
	if player:
		player.velocity = Vector3.ZERO
	_update_chunks(true)
	while not _chunk_queue.is_empty():
		var ck: Vector2i = _chunk_queue.pop_front()
		if not loaded_chunks.has(ck):
			_load_chunk(ck)
	_snap_player_to_surface()
	flora_fauna = load("res://scripts/flora_fauna.gd").new()
	flora_fauna.name = "FloraFauna"
	add_child(flora_fauna)
	flora_fauna.setup(self, blocks)
	_setup_ui()
	_show_toast("Explore • Mine • Build  |  WASD  •  Mouse  •  LMB dig  •  RMB place", 4.5)

func _process(delta: float) -> void:
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

func _setup_materials() -> void:
	var colors := {
		"grass": Color(0.30, 0.58, 0.24), "dirt": Color(0.40, 0.26, 0.14),
		"stone": Color(0.48, 0.50, 0.52), "wood": Color(0.42, 0.25, 0.11),
		"sand": Color(0.82, 0.72, 0.48), "water": Color(0.22, 0.48, 0.72),
		"gravel": Color(0.55, 0.52, 0.48), "rock": Color(0.35, 0.36, 0.38),
		"coal": Color(0.12, 0.12, 0.14), "iron": Color(0.72, 0.58, 0.48),
		"gold": Color(0.92, 0.78, 0.22), "crystal": Color(0.45, 0.85, 0.95),
		"leaves": Color(0.22, 0.55, 0.25), "chest": Color(0.55, 0.32, 0.12),
	}
	for key in colors:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[key]
		mat.roughness = 0.92
		if key == "water":
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.72
			mat.roughness = 0.12
			mat.metallic = 0.15
		elif key == "crystal":
			mat.metallic = 0.35
			mat.roughness = 0.2
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.55, 0.65)
			mat.emission_energy_multiplier = 0.6
		elif key == "gold":
			mat.metallic = 0.7
			mat.roughness = 0.35
		elif key == "leaves":
			mat.roughness = 0.85
		block_materials[key] = mat

func _ensure_spawn_pad() -> void:
	for x in range(-4, 5):
		for z in range(-4, 5):
			var top := MIN_Y
			for y in range(MIN_Y, 30):
				if blocks.has(Vector3i(x, y, z)) and str(blocks[Vector3i(x, y, z)]) != "water":
					top = maxi(top, y)
			if top < 3:
				for y in range(MIN_Y, 4):
					blocks[Vector3i(x, y, z)] = "dirt" if y < 3 else "grass"
				top = 3
			for y in range(top + 1, 12):
				var p2 := Vector3i(x, y, z)
				if blocks.has(p2) and abs(x) <= 2 and abs(z) <= 2:
					if str(blocks[p2]) not in ["wood", "leaves"]:
						blocks.erase(p2)

func _snap_player_to_surface() -> void:
	if player == null:
		return
	var best_pos := Vector3(0.5, 8.0, 0.5)
	var found := false
	for x in range(-6, 7):
		for z in range(-6, 7):
			for y in range(30, MIN_Y - 1, -1):
				var pos := Vector3i(x, y, z)
				if not blocks.has(pos):
					continue
				if str(blocks[pos]) == "water":
					continue
				if blocks.has(Vector3i(x, y + 1, z)):
					continue
				var cand := Vector3(float(x) + 0.5, float(y) + 1.15, float(z) + 0.5)
				if not found or Vector2(cand.x, cand.z).length() < Vector2(best_pos.x, best_pos.z).length():
					best_pos = cand
					found = true
				break
	player.global_position = best_pos
	player.velocity = Vector3.ZERO

func _generate_world() -> void:
	blocks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 82417
	var heights: Dictionary = {}
	for x in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
		for z in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
			var fx := float(x)
			var fz := float(z)
			var dist := sqrt(fx * fx + fz * fz)
			var h := 5.0
			h += sin(fx * 0.06) * cos(fz * 0.055) * 5.5
			h += sin(fx * 0.14 + 2.1) * 2.8 + cos(fz * 0.13 + 0.9) * 2.5
			h += sin(fx * 0.28 + fz * 0.11) * 1.4
			if dist < 14.0:
				h = lerpf(h, 4.0, clampf(1.0 - dist / 14.0, 0.0, 1.0))
			var river_d := absf(fz - sin(fx * 0.11) * 8.0 - cos(fx * 0.04) * 3.0)
			var trib_d := absf(fx - cos(fz * 0.13) * 5.0 + 10.0)
			var in_main := river_d < 2.8 and dist > 6.0
			var in_trib := trib_d < 1.8 and dist > 10.0 and fz > 0.0
			var in_river := in_main or in_trib
			if in_river:
				h = mini(h, 2.2)
			var in_lake := (fx + 22.0) * (fx + 22.0) + (fz - 18.0) * (fz - 18.0) < 55.0
			if in_lake:
				h = mini(h, 1.8)
			heights[Vector2i(x, z)] = {"h": clampi(int(round(h)), MIN_Y + 2, 24), "river": in_river or in_lake, "river_d": mini(river_d if in_main else (trib_d if in_trib else 99.0), 99.0), "lake": in_lake}
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
			var steep := max_dh >= 3
			var water_level := 2
			for y in range(MIN_Y, height + 1):
				var kind := "stone"
				if is_river and y < water_level: kind = "dirt"
				elif y == height:
					if is_river: kind = "sand" if river_d < 3.5 or bool(info["lake"]) else "dirt"
					elif steep: kind = "rock" if height >= 7 else "stone"
					elif height <= 3 and river_d < 6.0: kind = "sand"
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
			if not is_river and not steep and height >= 4 and height <= 14 and abs(x) > 5 and abs(z) > 5:
				var tree_chance := 0.04 if sin(float(x) * 0.17) * cos(float(z) * 0.19) > 0.4 else 0.015
				if river_d < 8.0: tree_chance *= 0.4
				if rng.randf() < tree_chance:
					_make_tree(x, height + 1, z, rng)
			if not is_river and not steep and height >= 3 and abs(x) > 12 and abs(z) > 12 and rng.randf() < 0.0018:
				blocks[Vector3i(x, height + 1, z)] = "chest"

func _ore_noise(x: int, y: int, z: int) -> float:
	return 0.5 + 0.5 * sin(float(x) * 0.19 + float(y) * 0.37) * cos(float(z) * 0.17 + float(y) * 0.23) * sin(float(x + z) * 0.11 + float(y) * 0.29)

func _make_tree(x: int, y: int, z: int, rng: RandomNumberGenerator = null) -> void:
	var trunk := 3 + (rng.randi_range(0, 2) if rng else 1)
	for dy in range(trunk):
		blocks[Vector3i(x, y + dy, z)] = "wood"
	var canopy_y := y + trunk - 1
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			for dy in range(0, 3):
				if abs(dx) + abs(dz) + abs(dy) < 5:
					var p := Vector3i(x + dx, canopy_y + dy, z + dz)
					if not blocks.has(p):
						blocks[p] = "leaves"

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
	pending.sort_custom(func(a, b):
		return (absi(a.x - pc.x) + absi(a.y - pc.y)) < (absi(b.x - pc.x) + absi(b.y - pc.y))
	)
	for key in pending: _chunk_queue.append(key)
	if force:
		while not _chunk_queue.is_empty():
			var ck2: Vector2i = _chunk_queue.pop_front()
			if not loaded_chunks.has(ck2):
				_load_chunk(ck2)

func _is_exposed(pos: Vector3i) -> bool:
	for d in [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,1,0), Vector3i(0,-1,0), Vector3i(0,0,1), Vector3i(0,0,-1)]:
		var n := pos + d
		if not blocks.has(n) or str(blocks[n]) == "water": return true
	return false

func _load_chunk(ck: Vector2i) -> void:
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [ck.x, ck.y]
	chunk_root.add_child(root)
	loaded_chunks[ck] = root
	var x0 := ck.x * CHUNK_SIZE
	var z0 := ck.y * CHUNK_SIZE
	for x in range(x0, x0 + CHUNK_SIZE):
		for z in range(z0, z0 + CHUNK_SIZE):
			for y in range(MIN_Y, 28):
				var pos := Vector3i(x, y, z)
				if not blocks.has(pos): continue
				var kind := str(blocks[pos])
				if kind in ["coal", "iron", "gold", "crystal", "chest"] or _is_exposed(pos):
					_spawn_block_in(root, pos, kind)

func _spawn_block_in(parent: Node, pos: Vector3i, kind: String) -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(pos)
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
		var n := pos + d
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
	var node := _find_block_node(pos)
	if node: node.queue_free()
	_reveal_neighbors(pos)
	mark_world_dirty()

func place_block(pos: Vector3i, kind: String = "dirt") -> void:
	if blocks.has(pos) or pos.y < MIN_Y or pos.y > 80: return
	if player.global_position.distance_to(Vector3(pos)) < 1.8: return
	blocks[pos] = kind
	var ck := _chunk_key_from_world(pos.x, pos.z)
	if loaded_chunks.has(ck): _spawn_block_in(loaded_chunks[ck], pos, kind)
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

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_GO_BACK_REQUEST, NOTIFICATION_EXIT_TREE]:
		if _save_dirty or what == NOTIFICATION_WM_CLOSE_REQUEST:
			save_world(what != NOTIFICATION_EXIT_TREE)

func save_world(show_feedback: bool = false) -> void:
	var serialized: Array = []
	for p in blocks:
		serialized.append({"x": p.x, "y": p.y, "z": p.z, "kind": blocks[p]})
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version": SAVE_VERSION, "blocks": serialized, "saved_at": Time.get_datetime_string_from_system()}))
		_save_dirty = false
		_autosave_timer = AUTO_SAVE_INTERVAL
		if show_feedback: _show_toast("World saved", 1.2)

func _load_world_snapshot() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file: return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("blocks"): return
	if int(parsed.get("version", 1)) < SAVE_VERSION:
		push_warning("Old save; regenerating world.")
		return
	var restored: Dictionary = {}
	for entry in parsed["blocks"]:
		if typeof(entry) == TYPE_DICTIONARY and entry.has("x") and entry.has("kind"):
			restored[Vector3i(int(entry["x"]), int(entry["y"]), int(entry["z"]))] = str(entry["kind"])
	if restored.size() < 500:
		push_warning("Save has too few blocks (%d); keeping generated world." % restored.size())
		return
	blocks = restored

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GameUI"
	add_child(layer)
	var label := Label.new()
	label.text = "BLOCKRAFT  |  Explore • Mine • Build"
	label.add_theme_font_size_override("font_size", 14)
	label.position = Vector2(16, 14)
	label.add_theme_color_override("font_color", Color("#f0f8e6"))
	layer.add_child(label)
	status_label = Label.new()
	status_label.position = Vector2(16, 100)
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color("#c8e0d0"))
	layer.add_child(status_label)
	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 18)
	toast_label.add_theme_color_override("font_color", Color("#ffe9a0"))
	toast_label.position = Vector2(100, 120)
	toast_label.size = Vector2(600, 40)
	layer.add_child(toast_label)
	var cross := Label.new()
	cross.text = "+"
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.add_theme_font_size_override("font_size", 22)
	cross.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position = Vector2(-12, -12)
	cross.size = Vector2(24, 24)
	layer.add_child(cross)
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
	status_label.text = "Discoveries: dig underground & search clearings" if bits.is_empty() else "Discovered: " + ", ".join(bits)

func _build_hotbar(layer: CanvasLayer) -> void:
	var bar := HBoxContainer.new()
	bar.name = "Hotbar"
	bar.add_theme_constant_override("separation", 6)
	layer.add_child(bar)
	hotbar_ui = bar
	hotbar_slots.clear()
	for i in range(inventory.SLOT_COUNT):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(56, 56)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.08, 0.1, 0.82)
		style.border_color = Color("#6ab88a")
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		slot.add_theme_stylebox_override("panel", style)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		key.text = str(i + 1)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.add_theme_font_size_override("font_size", 10)
		v.add_child(key)
		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var slot_index := i
		btn.pressed.connect(func(): inventory.select(slot_index))
		slot.add_child(btn)
		bar.add_child(slot)
		hotbar_slots.append(slot)
	_layout_hotbar()
	get_viewport().size_changed.connect(_layout_hotbar)

func _layout_hotbar() -> void:
	if hotbar_ui == null: return
	var vs := get_viewport().get_visible_rect().size
	hotbar_ui.position = Vector2(vs.x * 0.5 - 260.0, vs.y - 78.0)
	if toast_label: toast_label.position = Vector2(vs.x * 0.5 - 300.0, 110.0)

func _build_backpack_ui(layer: CanvasLayer) -> void:
	backpack_label = Label.new()
	backpack_label.position = Vector2(16, 42)
	backpack_label.add_theme_font_size_override("font_size", 13)
	backpack_label.add_theme_color_override("font_color", Color("#d8e8d0"))
	layer.add_child(backpack_label)
	upgrade_btn = Button.new()
	upgrade_btn.text = "Upgrade Bag (B)"
	upgrade_btn.position = Vector2(16, 66)
	upgrade_btn.custom_minimum_size = Vector2(160, 28)
	upgrade_btn.pressed.connect(_on_upgrade_pressed)
	layer.add_child(upgrade_btn)
	_refresh_backpack_ui()

func _on_backpack_changed(_tier: String = "") -> void:
	_refresh_backpack_ui()
	_refresh_hotbar()

func _on_upgrade_pressed() -> void:
	if inventory.try_upgrade():
		_show_toast("Backpack upgraded!", 2.0)

func _refresh_backpack_ui() -> void:
	if backpack_label == null: return
	backpack_label.text = "Backpack: %s  |  max stack %d" % [inventory.get_backpack_label(), inventory.get_max_stack()]

func _refresh_hotbar(_arg = null) -> void:
	_refresh_backpack_ui()
	if hotbar_slots.is_empty(): return
	for i in range(inventory.SLOT_COUNT):
		var slot: PanelContainer = hotbar_slots[i]
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
	var kind := inventory.get_place_kind()
	if kind == "" or kind == "chest": return false
	if blocks.has(pos) or pos.y < MIN_Y or pos.y > 80: return false
	if player.global_position.distance_to(Vector3(pos)) < 1.8: return false
	if not inventory.consume_place(): return false
	blocks[pos] = kind
	var ck := _chunk_key_from_world(pos.x, pos.z)
	if loaded_chunks.has(ck): _spawn_block_in(loaded_chunks[ck], pos, kind)
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
