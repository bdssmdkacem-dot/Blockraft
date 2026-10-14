extends Node3D

const WORLD_RADIUS := 42
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
var backpack_label: Label
var upgrade_btn: Button
var mining_fx: Node

func _ready() -> void:
	world_root = Node3D.new()
	world_root.name = "GeneratedWorld"
	add_child(world_root)
	player = get_node("Player")
	inventory = load("res://scripts/inventory.gd").new()
	inventory.name = "Inventory"
	add_child(inventory)
	mining_fx = load("res://scripts/mining_fx.gd").new()
	mining_fx.name = "MiningFX"
	add_child(mining_fx)
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
			var fx := float(x)
			var fz := float(z)
			var h := 4.0
			h += sin(fx * 0.08) * cos(fz * 0.07) * 4.5
			h += sin(fx * 0.18 + 1.7) * 2.2 + cos(fz * 0.16 + 0.4) * 2.0
			h += sin(fx * 0.35) * cos(fz * 0.31) * 1.1
			var dist := sqrt(fx * fx + fz * fz)
			if dist < 12.0:
				h = lerpf(h, 3.0, 1.0 - dist / 12.0)
			var river := absf(sin(fx * 0.12) * 6.0 - fz * 0.15)
			var is_river := river < 2.2 and dist > 8.0
			if is_river:
				h = mini(h, 1.5)
			var height := int(round(h))
			height = clampi(height, MIN_Y + 1, 22)
			for y in range(MIN_Y, height + 1):
				var kind := "stone"
				if is_river and y <= 1:
					kind = "dirt"
				elif y == height:
					kind = "grass" if not is_river else "dirt"
				elif y >= height - 2:
					kind = "dirt"
				blocks[Vector3i(x, y, z)] = kind
			if not is_river and height >= 3 and abs(x) > 4 and abs(z) > 4:
				var tree_chance := 0.018
				if sin(fx * 0.2) * cos(fz * 0.2) > 0.35:
					tree_chance = 0.045
				if rng.randf() < tree_chance:
					_make_tree(x, height + 1, z, rng)
			if not is_river and height >= 8 and rng.randf() < 0.008:
				for dy in range(1, 4):
					blocks[Vector3i(x, height + dy, z)] = "stone"

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
	var kind := str(blocks[pos])
	if mining_fx and mining_fx.has_method("play_break"):
		mining_fx.play_break(Vector3(pos), kind)
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
	if mining_fx and mining_fx.has_method("play_place"):
		mining_fx.play_place(Vector3(pos), kind)
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
		label.text = "BLOCKRAFT  |  Joystick move  •  Drag look  •  Mine & Place"
		label.add_theme_font_size_override("font_size", 13)
	else:
		label.text = "BLOCKRAFT  |  1-9 select  •  Scroll  •  LMB mine  •  RMB place  •  B upgrade bag"
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
	inventory.backpack_changed.connect(_on_backpack_changed)
	_build_backpack_ui(layer)
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

func _build_backpack_ui(layer: CanvasLayer) -> void:
	backpack_label = Label.new()
	backpack_label.name = "BackpackLabel"
	backpack_label.position = Vector2(16, 42)
	backpack_label.add_theme_font_size_override("font_size", 14)
	backpack_label.add_theme_color_override("font_shadow_color", Color("#1a2e22"))
	backpack_label.add_theme_constant_override("shadow_offset_x", 1)
	backpack_label.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(backpack_label)
	upgrade_btn = Button.new()
	upgrade_btn.name = "UpgradeBackpackBtn"
	upgrade_btn.position = Vector2(16, 66)
	upgrade_btn.custom_minimum_size = Vector2(280, 32)
	upgrade_btn.add_theme_font_size_override("font_size", 13)
	upgrade_btn.focus_mode = Control.FOCUS_NONE
	upgrade_btn.pressed.connect(_on_upgrade_pressed)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.14, 0.12, 0.88)
	normal.border_color = Color("#8b5a2b")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	upgrade_btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.14, 0.22, 0.18, 0.95)
	upgrade_btn.add_theme_stylebox_override("hover", hover)
	upgrade_btn.add_theme_color_override("font_color", Color("#f0f8e6"))
	layer.add_child(upgrade_btn)
	_refresh_backpack_ui()

func _on_backpack_changed(_tier: String = "") -> void:
	_refresh_backpack_ui()
	_refresh_hotbar()

func _on_upgrade_pressed() -> void:
	if inventory.try_upgrade():
		_refresh_backpack_ui()
		_refresh_hotbar()

func _refresh_backpack_ui() -> void:
	if backpack_label == null:
		return
	var max_stack: int = inventory.get_max_stack()
	backpack_label.text = "Backpack: %s  |  max stack %d" % [inventory.get_backpack_label(), max_stack]
	backpack_label.add_theme_color_override("font_color", inventory.get_backpack_color())
	if upgrade_btn == null:
		return
	var nxt: String = inventory.get_next_tier()
	if nxt == "":
		upgrade_btn.text = "Backpack maxed (Diamond)"
		upgrade_btn.disabled = true
		return
	var cost: Dictionary = inventory.get_upgrade_cost()
	var parts: PackedStringArray = []
	for k in cost.keys():
		parts.append("%d %s" % [int(cost[k]), str(k)])
	var cost_txt := ", ".join(parts)
	var can := inventory.can_upgrade()
	upgrade_btn.disabled = not can
	if can:
		upgrade_btn.text = "Upgrade to %s (%s)" % [str(inventory.BACKPACKS[nxt]["label"]), cost_txt]
	else:
		upgrade_btn.text = "Need: %s  [B]" % cost_txt

func _refresh_hotbar(_arg = null) -> void:
	_refresh_backpack_ui()
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
				count.text = "Pick"
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
	if mining_fx and mining_fx.has_method("play_place"):
		mining_fx.play_place(Vector3(pos), kind)
	save_world()
	return true

func on_block_mined(kind: String) -> void:
	inventory.add_block(kind, 1)
