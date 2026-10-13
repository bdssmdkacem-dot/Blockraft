extends Node3D

const WORLD_RADIUS := 18
const MIN_Y := -3
const SAVE_PATH := "user://world_blocks.json"

var blocks: Dictionary = {}
var block_mesh := BoxMesh.new()
var block_materials: Dictionary = {}
var world_root: Node3D
var player: CharacterBody3D
var inventory: Node
var hotbar_ui: HBoxContainer
var hotbar_slots: Array = []

func _ready() -> void:
	world_root = Node3D.new()
	world_root.name = "GeneratedWorld"
	add_child(world_root)
	player = get_node("Player")
	inventory = load("res://scripts/inventory.gd").new()
	inventory.name = "Inventory"
	add_child(inventory)
	_setup_materials()
	_generate_world()
	_load_world_snapshot()
	_build_world()
	_setup_ui()

func _setup_materials() -> void:
	var colors := {
		"grass": Color(0.28, 0.62, 0.22),
		"dirt": Color(0.38, 0.24, 0.13),
		"stone": Color(0.42, 0.45, 0.48),
		"wood": Color(0.42, 0.25, 0.11)
	}
	for key in colors:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[key]
		mat.roughness = 1.0
		block_materials[key] = mat

func _generate_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 82417
	for x in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
		for z in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
			var height := int(round(2.0 + sin(float(x) * 0.23) * 1.5 + cos(float(z) * 0.19) * 1.3))
			for y in range(MIN_Y, height + 1):
				var kind := "stone"
				if y == height:
					kind = "grass"
				elif y >= height - 2:
					kind = "dirt"
				blocks[Vector3i(x, y, z)] = kind
			if rng.randf() < 0.025 and abs(x) > 3 and abs(z) > 3:
				_make_tree(x, height + 1, z)

func _make_tree(x: int, y: int, z: int) -> void:
	for dy in range(4):
		blocks[Vector3i(x, y + dy, z)] = "wood"
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			for dy in range(2, 5):
				if abs(dx) + abs(dz) + abs(dy - 3) < 5:
					var p := Vector3i(x + dx, y + dy, z + dz)
					if not blocks.has(p):
						blocks[p] = "grass"

func _build_world() -> void:
	for pos in blocks:
		_spawn_block(pos, str(blocks[pos]))

func _spawn_block(pos: Vector3i, kind: String) -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(pos)
	body.set_meta("block_position", pos)
	body.set_meta("block_kind", kind)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = block_mesh
	mesh_instance.material_override = block_materials.get(kind, block_materials["stone"])
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE
	collision.shape = shape
	body.add_child(collision)
	world_root.add_child(body)

func remove_block(pos: Vector3i) -> void:
	if not blocks.has(pos):
		return
	blocks.erase(pos)
	for node in world_root.get_children():
		if node.has_meta("block_position") and node.get_meta("block_position") == pos:
			node.queue_free()
			break
	save_world()

func place_block(pos: Vector3i, kind: String = "dirt") -> void:
	if blocks.has(pos) or pos.y < MIN_Y or pos.y > 80:
		return
	if player.global_position.distance_to(Vector3(pos)) < 1.8:
		return
	blocks[pos] = kind
	_spawn_block(pos, kind)
	save_world()

func save_world() -> void:
	var serialized: Array = []
	for p in blocks:
		serialized.append({"x": p.x, "y": p.y, "z": p.z, "kind": blocks[p]})
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version": 1, "blocks": serialized}))

func _load_world_snapshot() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_warning("Could not open saved world; using generated terrain.")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("blocks") or typeof(parsed["blocks"]) != TYPE_ARRAY:
		push_warning("Saved world format is invalid; using generated terrain.")
		return
	var restored: Dictionary = {}
	for entry in parsed["blocks"]:
		if typeof(entry) == TYPE_DICTIONARY and entry.has("x") and entry.has("y") and entry.has("z") and entry.has("kind"):
			restored[Vector3i(int(entry["x"]), int(entry["y"]), int(entry["z"]))] = str(entry["kind"])
	blocks = restored

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GameUI"
	add_child(layer)
	var label := Label.new()
	if OS.has_feature("mobile"):
		label.text = "BLOCKRAFT  |  1-9 / tap slots  •  Mine & Place"
		label.add_theme_font_size_override("font_size", 13)
	else:
		label.text = "BLOCKRAFT  |  1-9 select  •  Scroll cycle  •  LMB mine  •  RMB place"
		label.add_theme_font_size_override("font_size", 15)
	label.position = Vector2(16, 14)
	label.add_theme_color_override("font_color", Color("#f0f8e6"))
	label.add_theme_color_override("font_shadow_color", Color("#1a2e22"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(label)
	_build_hotbar(layer)
	inventory.selection_changed.connect(_refresh_hotbar)
	inventory.counts_changed.connect(_refresh_hotbar)
	_refresh_hotbar()

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
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.08, 0.1, 0.82)
		style.border_color = Color("#6ab88a")
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		slot.add_theme_stylebox_override("panel", style)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(v)
		var icon := ColorRect.new()
		icon.name = "Icon"
		icon.custom_minimum_size = Vector2(36, 28)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(icon)
		var count := Label.new()
		count.name = "Count"
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.add_theme_font_size_override("font_size", 11)
		count.add_theme_color_override("font_color", Color("#e8f5e0"))
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(count)
		var key := Label.new()
		key.name = "Key"
		key.text = str(i + 1)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.add_theme_font_size_override("font_size", 10)
		key.add_theme_color_override("font_color", Color("#a8c8b0"))
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	if hotbar_ui == null:
		return
	var vs := get_viewport().get_visible_rect().size
	hotbar_ui.position = Vector2(vs.x * 0.5 - 260.0, vs.y - 78.0)

func _refresh_hotbar(_arg = null) -> void:
	if hotbar_slots.is_empty():
		return
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
			if str(data.get("id", "")) == "":
				icon.color = Color(0.15, 0.18, 0.18, 0.4)
			else:
				icon.color = data.get("color", Color.GRAY)
		if count:
			if data.get("is_tool", false):
				count.text = "⛏"
			elif str(data.get("id", "")) == "":
				count.text = ""
			else:
				count.text = str(int(data.get("count", 0)))
	_layout_hotbar()

func get_selected_place_kind() -> String:
	return inventory.get_place_kind()

func try_place_selected(pos: Vector3i) -> bool:
	var kind := inventory.get_place_kind()
	if kind == "":
		return false
	if blocks.has(pos) or pos.y < MIN_Y or pos.y > 80:
		return false
	if player.global_position.distance_to(Vector3(pos)) < 1.8:
		return false
	if not inventory.consume_place():
		return false
	blocks[pos] = kind
	_spawn_block(pos, kind)
	save_world()
	return true

func on_block_mined(kind: String) -> void:
	inventory.add_block(kind, 1)
