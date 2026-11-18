extends Node
## Station-based crafting with atomic ingredient consumption and a compact touch UI.

const RECIPES := [
	{"id": "planks", "title": "Wood Planks", "input": {"wood": 1}, "output": "planks", "amount": 4},
	{"id": "stone_bricks", "title": "Stone Bricks", "input": {"stone": 4}, "output": "stone_brick", "amount": 4},
	{"id": "reinforced_planks", "title": "Reinforced Planks", "input": {"planks": 4, "iron": 1}, "output": "planks", "amount": 8}
]

var host: Node3D
var inventory: Node
var station_position := Vector3.ZERO
var panel: PanelContainer
var hint: Label
var rows: VBoxContainer
var open_button: Button
var _near_station := false

func setup(world: Node3D, player_inventory: Node) -> void:
	host = world
	inventory = player_inventory
	_build_station()
	_build_ui()
	set_process(true)

func _build_station() -> void:
	# Place the workbench beside the resource depot on supported ground.
	var ground_y := 4
	var world_blocks: Dictionary = host.get("blocks")
	for y in range(30, -5, -1):
		var cell := Vector3i(13, y, 8)
		if world_blocks.has(cell) and str(world_blocks[cell]) in ["grass", "dirt", "stone", "rock"]:
			ground_y = y
			break
	station_position = Vector3(13.5, float(ground_y) + 1.31, 8.5)
	var root := Node3D.new()
	root.name = "CraftingBench"
	root.position = station_position
	host.add_child(root)
	_box(root, Vector3(0, 0.38, 0), Vector3(1.8, 0.18, 1.0), Color("#8b5a32"))
	for x in [-0.72, 0.72]:
		for z in [-0.34, 0.34]:
			_box(root, Vector3(x, 0.05, z), Vector3(0.14, 0.72, 0.14), Color("#654126"))
	_box(root, Vector3(0, 0.53, -0.30), Vector3(0.72, 0.10, 0.12), Color("#c18a4d"))
	_box(root, Vector3(0, 0.53, 0.30), Vector3(0.72, 0.10, 0.12), Color("#c18a4d"))

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mesh_instance)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CraftingUI"
	layer.layer = 12
	host.add_child(layer)
	open_button = Button.new()
	open_button.name = "CraftButton"
	open_button.text = "CRAFT"
	open_button.position = Vector2(-132, 18)
	open_button.size = Vector2(112, 42)
	open_button.anchor_left = 1.0
	open_button.anchor_right = 1.0
	open_button.pressed.connect(toggle)
	layer.add_child(open_button)

	panel = PanelContainer.new()
	panel.name = "CraftingPanel"
	panel.custom_minimum_size = Vector2(360, 280)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-180, -140)
	panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.07, 0.075, 0.96)
	style.border_color = Color("#79c79a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "WORKBENCH"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#e9f5dc"))
	header.add_child(title)
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(42, 34)
	close.pressed.connect(func(): panel.visible = false)
	header.add_child(close)
	hint = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("#b9d2c2"))
	column.add_child(hint)
	var separator := HSeparator.new()
	column.add_child(separator)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	column.add_child(rows)
	_refresh_recipes()

func _process(_delta: float) -> void:
	var player := host.get_node_or_null("Player") as Node3D
	_near_station = player != null and player.global_position.distance_to(station_position) <= 5.0
	open_button.disabled = not _near_station
	open_button.tooltip_text = "Move closer to the workbench" if not _near_station else "Open workbench (C)"
	if panel.visible and not _near_station:
		panel.visible = false

func toggle() -> void:
	if not _near_station:
		if host and host.has_method("_show_toast"):
			host.call("_show_toast", "Move closer to the workbench", 1.8)
		return
	panel.visible = not panel.visible
	if panel.visible:
		_refresh_recipes()

func _refresh_recipes() -> void:
	if rows == null:
		return
	for child in rows.get_children():
		child.queue_free()
	for recipe_variant in RECIPES:
		var recipe: Dictionary = recipe_variant
		var row := HBoxContainer.new()
		rows.add_child(row)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		var name_label := Label.new()
		name_label.text = str(recipe["title"]) + "  ×" + str(recipe["amount"])
		name_label.add_theme_color_override("font_color", Color("#f2f4e9"))
		details.add_child(name_label)
		var cost := Label.new()
		cost.text = _cost_text(recipe["input"])
		cost.add_theme_font_size_override("font_size", 12)
		cost.add_theme_color_override("font_color", Color("#a9c7b5"))
		details.add_child(cost)
		var craft_button := Button.new()
		craft_button.text = "MAKE"
		craft_button.custom_minimum_size = Vector2(76, 38)
		craft_button.disabled = not _can_craft(recipe)
		craft_button.pressed.connect(_craft.bind(str(recipe["id"])))
		row.add_child(craft_button)

func _cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for item in cost:
		parts.append("%s %d/%d" % [str(item).capitalize(), int(inventory.call("total_of", str(item))), int(cost[item])])
	return "Needs: " + ", ".join(parts)

func _can_craft(recipe: Dictionary) -> bool:
	for item in recipe["input"]:
		if inventory.total_of(str(item)) < int(recipe["input"][item]):
			return false
	return true

func _craft(recipe_id: String) -> void:
	for recipe_variant in RECIPES:
		var recipe: Dictionary = recipe_variant
		if str(recipe["id"]) != recipe_id:
			continue
		if not _can_craft(recipe):
			hint.text = "Not enough materials."
			return
		if not bool(inventory.call("consume_items", recipe["input"])):
			hint.text = "Materials changed. Try again."
			_refresh_recipes()
			return
		inventory.call("add_block", str(recipe["output"]), int(recipe["amount"]))
		hint.text = "Crafted %d %s." % [int(recipe["amount"]), str(recipe["output"]).replace("_", " ")]
		_refresh_recipes()
		if host and host.has_method("mark_world_dirty"):
			host.call("mark_world_dirty")
		return
