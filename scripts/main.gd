extends Node3D
## Minimal world bootstrap — floor also from player.gd as backup.

const WORLD_RADIUS := 32
const MIN_Y := -4
const CHUNK_SIZE := 16
const VIEW_CHUNKS := 2
const MAX_CHUNK_BUILDS_PER_FRAME := 4
const SAVE_PATH := "user://world_blocks.json"
const SAVE_VERSION := 11
const AUTO_SAVE_INTERVAL := 10.0

var blocks: Dictionary = {}
var block_mesh := BoxMesh.new()
var block_materials: Dictionary = {}
var world_root: Node3D
var chunk_root: Node3D
var loaded_chunks: Dictionary = {}
var player: CharacterBody3D
var inventory: Node
var mining_fx: Node
var flora_fauna: Node
var hotbar_ui: HBoxContainer
var hotbar_slots: Array = []
var backpack_label: Label
var upgrade_btn: Button
var toast_label: Label
var status_label: Label
var _chunk_timer := 0.0
var _last_player_chunk := Vector2i(9999, 9999)
var discovered: Dictionary = {}
var _chunk_queue: Array = []
var _save_dirty := false
var _autosave_timer := 0.0

func _ready() -> void:
	print("MAIN.GD _ready START")
	player = get_node_or_null("Player") as CharacterBody3D
	if player:
		player.add_to_group("player")
	_make_floor()
	world_root = Node3D.new()
	world_root.name = "GeneratedWorld"
	add_child(world_root)
	chunk_root = Node3D.new()
	chunk_root.name = "Chunks"
	world_root.add_child(chunk_root)
	_safe_setup_systems()
	_setup_materials()
	_setup_environment()
	_generate_simple_world()
	_force_spawn_blocks()
	if player:
		player.global_position = Vector3(0.0, 6.0, 0.0)
		player.velocity = Vector3.ZERO
	_setup_ui()
	print("MAIN.GD _ready DONE blocks=", blocks.size())
	_show_toast("World OK: %d blocks" % blocks.size(), 5.0)

func _make_floor() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "MainFloor"
	var box := BoxMesh.new()
	box.size = Vector3(100, 3, 100)
	mi.mesh = box
	mi.position = Vector3(0, 1.0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.55, 0.22)
	mi.material_override = mat
	add_child(mi)
	var body := StaticBody3D.new()
	body.name = "MainFloorBody"
	body.position = Vector3(0, 1.0, 0)
	body.collision_layer = 1
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100, 3, 100)
	col.shape = shape
	body.add_child(col)
	add_child(body)
	print("MAIN floor created")

func _safe_setup_systems() -> void:
	var inv_script = load("res://scripts/inventory.gd")
	if inv_script:
		inventory = inv_script.new()
		inventory.name = "Inventory"
		add_child(inventory)
	var fx_script = load("res://scripts/mining_fx.gd")
	if fx_script:
		mining_fx = fx_script.new()
		mining_fx.name = "MiningFX"
		add_child(mining_fx)
	var set_script = load("res://scripts/settings.gd")
	var settings = null
	if set_script:
		settings = set_script.new()
		settings.name = "Settings"
		add_child(settings)
	var surv_script = load("res://scripts/survival.gd")
	if surv_script:
		var survival = surv_script.new()
		survival.name = "Survival"
		add_child(survival)
		if survival.has_method("setup"):
			survival.setup(self, settings)

func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.72, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.ambient_light_energy = 0.6
	we.environment = env
	add_child(we)

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
		mat.roughness = 0.9
		if key == "water":
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.7
		block_materials[key] = mat

func _generate_simple_world() -> void:
	blocks.clear()
	for x in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
		for z in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
			var h := 3 + int(2.0 * sin(float(x) * 0.08) * cos(float(z) * 0.07))
			h = clampi(h, 2, 8)
			for y in range(0, h + 1):
				var kind := "stone"
				if y == h:
					kind = "grass"
				elif y >= h - 1:
					kind = "dirt"
				blocks[Vector3i(x, y, z)] = kind
	print("Generated ", blocks.size(), " blocks")

func _force_spawn_blocks() -> void:
	var root := Node3D.new()
	root.name = "SpawnChunk"
	chunk_root.add_child(root)
	loaded_chunks[Vector2i(0, 0)] = root
	var n := 0
	for x in range(-12, 13):
		for z in range(-12, 13):
			for y in range(0, 10):
				var pos := Vector3i(x, y, z)
				if not blocks.has(pos):
					continue
				_spawn_block_in(root, pos, str(blocks[pos]))
				n += 1
	print("Spawned ", n, " visible blocks")

func _spawn_block_in(parent: Node, pos: Vector3i, kind: String) -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(float(pos.x) + 0.5, float(pos.y) + 0.5, float(pos.z) + 0.5)
	body.collision_layer = 1
	body.set_meta("block_position", pos)
	body.set_meta("block_kind", kind)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = block_mesh
	if block_materials.has(kind):
		mesh_instance.material_override = block_materials[kind]
	body.add_child(mesh_instance)
	if kind != "water":
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3.ONE
		collision.shape = shape
		body.add_child(collision)
	parent.add_child(body)

func _process(delta: float) -> void:
	var surv = get_node_or_null("Survival")
	if surv and surv.has_method("tick"):
		surv.tick(delta)
	if player and player.global_position.y < -20.0:
		player.global_position = Vector3(0, 6, 0)
		player.velocity = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		var surv = get_node_or_null("Survival")
		if surv and surv.has_method("try_eat"):
			surv.try_eat()

func remove_block(pos: Vector3i) -> void:
	if not blocks.has(pos):
		return
	var kind := str(blocks[pos])
	if mining_fx and mining_fx.has_method("play_break"):
		mining_fx.play_break(Vector3(pos), kind)
	blocks.erase(pos)
	for ck in loaded_chunks.keys():
		var root = loaded_chunks[ck]
		if not is_instance_valid(root):
			continue
		for node in root.get_children():
			if node.has_meta("block_position") and node.get_meta("block_position") == pos:
				node.queue_free()
				break

func place_block(pos: Vector3i, kind: String = "dirt") -> void:
	if blocks.has(pos):
		return
	blocks[pos] = kind
	var root = loaded_chunks.get(Vector2i(0, 0))
	if root:
		_spawn_block_in(root, pos, kind)

func try_place_selected(pos: Vector3i) -> bool:
	if inventory == null:
		place_block(pos, "dirt")
		return true
	var kind := ""
	if inventory.has_method("get_place_kind"):
		kind = inventory.get_place_kind()
	if kind == "":
		return false
	if inventory.has_method("consume_place") and not inventory.consume_place():
		return false
	place_block(pos, kind)
	return true

func on_block_mined(kind: String) -> void:
	if inventory and inventory.has_method("add_block"):
		inventory.add_block(kind, 1)
	_show_toast("+1 " + kind, 1.0)

func mark_world_dirty() -> void:
	pass

func save_world(_show_feedback: bool = false) -> void:
	pass

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GameUI"
	add_child(layer)
	var label := Label.new()
	label.text = "BLOCKRAFT - MAP OK"
	label.add_theme_font_size_override("font_size", 18)
	label.position = Vector2(16, 12)
	label.add_theme_color_override("font_color", Color(1, 1, 0.3))
	layer.add_child(label)
	toast_label = Label.new()
	toast_label.position = Vector2(16, 40)
	toast_label.add_theme_font_size_override("font_size", 16)
	toast_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	layer.add_child(toast_label)
	if inventory:
		_build_hotbar(layer)

func _show_toast(text: String, duration: float = 2.5) -> void:
	if toast_label == null:
		return
	toast_label.text = text
	toast_label.modulate.a = 1.0

func _build_hotbar(layer: CanvasLayer) -> void:
	if inventory == null:
		return
	var bar := HBoxContainer.new()
	bar.position = Vector2(40, 500)
	layer.add_child(bar)
	hotbar_ui = bar
	for i in range(9):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(48, 48)
		bar.add_child(slot)

func _on_backpack_changed(_t: String = "") -> void:
	pass

func _refresh_hotbar(_a = null) -> void:
	pass

func _on_upgrade_pressed() -> void:
	pass
