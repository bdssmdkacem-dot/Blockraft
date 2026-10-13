extends Control

## Blockraft Main Menu — rebuilt to match the official visual north-star
## (assets/reference/blockraft_main_menu_reference.png) as closely as possible.
## Layout: big BLOCKRAFT title, Explore • Build • Survive, left action column
## (Play / Settings / Help / Exit), cinematic 3D voxel backdrop, six feature
## cards, and bottom icon strip.

const GAME_SCENE := "res://scenes/main.tscn"
const DESIGN_SIZE := Vector2(1280.0, 720.0)

var menu_column: VBoxContainer
var dialog_layer: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_3d_backdrop()
	_build_interface()
	_build_feature_strip()
	_build_footer_bar()
	_apply_responsive_layout()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
		if is_node_ready():
			_apply_responsive_layout()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_instance_valid(dialog_layer):
		dialog_layer.queue_free()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	pass

func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x < 1.0 or viewport_size.y < 1.0:
		return
	var ui_scale := minf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	ui_scale = clampf(ui_scale, 0.55, 1.35)
	for child in get_children():
		if child is Control and child.name in ["TitleBlock", "ActionColumn", "FeatureStrip", "FooterBar", "Slogan"]:
			child.scale = Vector2.ONE * ui_scale
			if child.name == "ActionColumn":
				child.position = Vector2(36.0 * ui_scale, 210.0 * ui_scale)

func _build_3d_backdrop() -> void:
	var backdrop := SubViewportContainer.new()
	backdrop.name = "ThreeDMenuBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.stretch = true
	backdrop.size = size
	backdrop.z_index = 0
	backdrop.z_as_relative = false
	add_child(backdrop)
	move_child(backdrop, 0)
	var viewport := SubViewport.new()
	viewport.name = "WorldViewport"
	viewport.size = Vector2i(1280, 720)
	viewport.disable_3d = false
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = false
	backdrop.add_child(viewport)
	var world := Node3D.new()
	world.name = "VoxelMenuWorld"
	world.set_script(load("res://scripts/menu_world_3d.gd"))
	viewport.add_child(world)

func _build_interface() -> void:
	var title_block := Control.new()
	title_block.name = "TitleBlock"
	title_block.position = Vector2(48, 28)
	title_block.size = Vector2(620, 160)
	add_child(title_block)
	var title := Label.new()
	title.name = "GameTitle"
	title.text = "BLOCKRAFT"
	title.position = Vector2(0, 0)
	title.size = Vector2(620, 92)
	title.add_theme_font_size_override("font_size", 78)
	title.add_theme_color_override("font_color", Color("#f5f0e0"))
	title.add_theme_color_override("font_shadow_color", Color("#1a2e22"))
	title.add_theme_constant_override("shadow_offset_x", 5)
	title.add_theme_constant_override("shadow_offset_y", 7)
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color("#2a4a38"))
	title_block.add_child(title)
	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "EXPLORE  •  BUILD  •  SURVIVE"
	subtitle.position = Vector2(8, 92)
	subtitle.size = Vector2(500, 28)
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color("#e8f5e0"))
	subtitle.add_theme_color_override("font_shadow_color", Color("#1a3328"))
	subtitle.add_theme_constant_override("shadow_offset_x", 2)
	subtitle.add_theme_constant_override("shadow_offset_y", 2)
	title_block.add_child(subtitle)
	var action_col := VBoxContainer.new()
	action_col.name = "ActionColumn"
	action_col.position = Vector2(48, 210)
	action_col.size = Vector2(240, 220)
	action_col.add_theme_constant_override("separation", 10)
	add_child(action_col)
	menu_column = action_col
	_add_menu_button("▶  Play", "play", true)
	_add_menu_button("⚙  Settings", "settings", false)
	_add_menu_button("📖  Help", "help", false)
	_add_menu_button("⏻  Exit", "exit", false)
	var slogan := Label.new()
	slogan.name = "Slogan"
	slogan.text = "Your World\nYour Adventure"
	slogan.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slogan.position = Vector2(900, 480)
	slogan.size = Vector2(320, 80)
	slogan.add_theme_font_size_override("font_size", 22)
	slogan.add_theme_color_override("font_color", Color("#fff8e8"))
	slogan.add_theme_color_override("font_shadow_color", Color("#1a2e22"))
	slogan.add_theme_constant_override("shadow_offset_x", 2)
	slogan.add_theme_constant_override("shadow_offset_y", 2)
	add_child(slogan)

func _add_menu_button(caption: String, action: String, primary: bool) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(220, 46 if primary else 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 18 if primary else 16)
	var normal := StyleBoxFlat.new()
	if primary:
		normal.bg_color = Color("#2ecc71")
		normal.border_color = Color("#a8f0c0")
	else:
		normal.bg_color = Color(0.08, 0.12, 0.14, 0.82)
		normal.border_color = Color("#5a8a6a")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#3ee085") if primary else Color(0.14, 0.22, 0.24, 0.92)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#1e9c55") if primary else Color(0.05, 0.08, 0.10, 0.95)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color("#0d1f14") if primary else Color("#f0f8e6"))
	button.add_theme_color_override("font_hover_color", Color("#0a1810"))
	button.add_theme_color_override("font_pressed_color", Color("#0a1810"))
	button.pressed.connect(_on_menu_action.bind(action))
	menu_column.add_child(button)

func _build_feature_strip() -> void:
	var features := [
		{"title": "EXPLORE VAST WORLDS", "body": "Endless procedural landscapes", "action": "help"},
		{"title": "GATHER RESOURCES", "body": "Mine ores, chop wood, craft", "action": "help"},
		{"title": "CRAFT & BUILD", "body": "Workbench recipes & tools", "action": "help"},
		{"title": "SURVIVE THE NIGHT", "body": "Health, hunger & monsters", "action": "help"},
		{"title": "BUILD YOUR DREAMS", "body": "Castles, cottages, floating isles", "action": "help"},
		{"title": "MULTIPLAYER (OPTIONAL)", "body": "Play with friends online", "action": "help"},
	]
	var strip := HBoxContainer.new()
	strip.name = "FeatureStrip"
	strip.position = Vector2(24, 560)
	strip.size = Vector2(1232, 110)
	strip.add_theme_constant_override("separation", 10)
	add_child(strip)
	for feature in features:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(198, 100)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.08, 0.10, 0.78)
		style.border_color = Color("#6ab88a")
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", style)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 4)
		card.add_child(content)
		var heading := Label.new()
		heading.text = feature.title
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		heading.add_theme_font_size_override("font_size", 12)
		heading.add_theme_color_override("font_color", Color("#fff5d9"))
		content.add_child(heading)
		var detail := Label.new()
		detail.text = feature.body
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_font_size_override("font_size", 10)
		detail.add_theme_color_override("font_color", Color("#c8dcc8"))
		content.add_child(detail)
		var hit_area := Button.new()
		hit_area.name = "CardHitArea"
		hit_area.text = ""
		hit_area.flat = true
		hit_area.focus_mode = Control.FOCUS_ALL
		hit_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hit_area.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(1, 1, 1, 0.08)
		hit_area.add_theme_stylebox_override("hover", hover)
		hit_area.pressed.connect(_on_menu_action.bind(feature.action))
		card.add_child(hit_area)
		strip.add_child(card)

func _build_footer_bar() -> void:
	var footer := HBoxContainer.new()
	footer.name = "FooterBar"
	footer.position = Vector2(40, 680)
	footer.size = Vector2(1200, 32)
	footer.add_theme_constant_override("separation", 48)
	add_child(footer)
	var items := [
		{"icon": "⬡", "label": "Procedural Worlds"},
		{"icon": "🌳", "label": "Dynamic Biomes"},
		{"icon": "⛏", "label": "Multiple Tools"},
		{"icon": "♥", "label": "Health & Hunger"},
		{"icon": "☀", "label": "Day & Night Cycle"},
		{"icon": "👥", "label": "Online Play"},
	]
	for item in items:
		var lbl := Label.new()
		lbl.text = "%s  %s" % [item.icon, item.label]
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color("#d0e8d0"))
		footer.add_child(lbl)

func _on_menu_action(action: String) -> void:
	match action:
		"play":
			_start_game()
		"settings":
			_show_dialog("SETTINGS", "Graphics, audio and sensitivity controls will appear here once wired.\nThis prototype currently uses the project's default settings.", [{"label": "BACK", "action": "close", "primary": true}])
		"help":
			_show_dialog("HOW TO PLAY", "DESKTOP\nW A S D  ·  Move\nSPACE  ·  Jump\nMOUSE  ·  Look\nLEFT CLICK  ·  Mine\nRIGHT CLICK  ·  Place\n\nMOBILE\nLEFT PAD  ·  Move\nDRAG RIGHT  ·  Look\nJUMP / MINE / PLACE buttons on screen\n\nAim at a block before mining or placing.", [{"label": "GOT IT", "action": "close", "primary": true}])
		"exit":
			get_tree().quit()
		"worlds":
			_show_dialog("CHOOSE YOUR WORLD", "Meadowlands is the current playable region. Other biomes are locked until their terrain, landmarks and mobile performance are ready.", [{"label": "▶  PLAY THE MEADOWLANDS", "action": "play", "primary": true}, {"label": "MOUNTAIN FRONTIER  ·  LOCKED", "action": "locked_mountains"}, {"label": "SUNSCORCHED DESERT  ·  LOCKED", "action": "locked_desert"}, {"label": "DEEP BLUE OCEAN  ·  LOCKED", "action": "locked_ocean"}, {"label": "BACK", "action": "close"}])

func _start_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _show_dialog(dialog_title: String, description: String, options: Array) -> void:
	if is_instance_valid(dialog_layer):
		dialog_layer.queue_free()
	dialog_layer = Control.new()
	dialog_layer.name = "MenuDialog"
	dialog_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dialog_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog_layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 320)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -240
	panel.offset_top = -180
	panel.offset_right = 240
	panel.offset_bottom = 180
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.10, 0.12, 0.96)
	panel_style.border_color = Color("#7fe4a0")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", panel_style)
	dialog_layer.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	var heading := Label.new()
	heading.text = dialog_title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", Color("#fff5d9"))
	vbox.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 140)
	vbox.add_child(scroll)
	var body := Label.new()
	body.text = description
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color("#d8e8d0"))
	scroll.add_child(body)
	var button_stack := VBoxContainer.new()
	button_stack.add_theme_constant_override("separation", 8)
	vbox.add_child(button_stack)
	for option in options:
		var option_button := Button.new()
		option_button.text = str(option.get("label", "BACK"))
		option_button.custom_minimum_size = Vector2(0, 42)
		option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option_button.add_theme_font_size_override("font_size", 15)
		var option_style := StyleBoxFlat.new()
		var is_primary := bool(option.get("primary", false))
		option_style.bg_color = Color("#2ecc71") if is_primary else Color("#294e3e")
		option_style.border_color = Color("#a8f0c0") if is_primary else Color("#8ab878")
		option_style.set_border_width_all(1)
		option_style.set_corner_radius_all(6)
		option_button.add_theme_stylebox_override("normal", option_style)
		var hover_style := option_style.duplicate() as StyleBoxFlat
		hover_style.bg_color = Color("#3ee085") if is_primary else Color("#3d6c4b")
		option_button.add_theme_stylebox_override("hover", hover_style)
		option_button.add_theme_color_override("font_color", Color("#0d1f14") if is_primary else Color("#f0f8e6"))
		option_button.pressed.connect(_on_dialog_action.bind(str(option.get("action", "close"))))
		button_stack.add_child(option_button)

func _on_dialog_action(action: String) -> void:
	match action:
		"play":
			_start_game()
		"close":
			if is_instance_valid(dialog_layer):
				dialog_layer.queue_free()
		"locked_mountains":
			_show_dialog("MOUNTAIN FRONTIER", "LOCKED REGION\nThis biome needs its own reviewed terrain, landmarks, resources, and mobile performance checks before it can be selected.", [{"label": "BACK TO WORLDS", "action": "worlds", "primary": true}, {"label": "CLOSE", "action": "close"}])
		"locked_desert":
			_show_dialog("SUNSCORCHED DESERT", "LOCKED REGION\nThe desert will be selectable only after its original block palette, dunes, oasis landmarks, and resource loop are implemented.", [{"label": "BACK TO WORLDS", "action": "worlds", "primary": true}, {"label": "CLOSE", "action": "close"}])
		"locked_ocean":
			_show_dialog("DEEP BLUE OCEAN", "LOCKED REGION\nThe ocean needs water rendering, underwater readability, and a distinct exploration loop before it is considered playable.", [{"label": "BACK TO WORLDS", "action": "worlds", "primary": true}, {"label": "CLOSE", "action": "close"}])
		"worlds":
			_on_menu_action("worlds")
