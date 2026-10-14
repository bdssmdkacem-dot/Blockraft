extends Control
## Official Blockraft title screen — built to match the reference art exactly.

const GAME_SCENE := "res://scenes/main.tscn"
const DESIGN_SIZE := Vector2(1280.0, 720.0)

var menu_column: VBoxContainer
var status_label: Label
var dialog_layer: Control
var _click_player: AudioStreamPlayer
var _hover_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_menu_audio()
	_build_3d_backdrop()
	_build_title_block()
	_build_menu_buttons()
	_build_feature_strip()
	_build_footer_bar()
	_apply_responsive_layout()
	if _ambient_player:
		_ambient_player.play()

func _setup_menu_audio() -> void:
	_click_player = AudioStreamPlayer.new()
	_click_player.name = "MenuClick"
	_click_player.stream = _make_click_wav()
	_click_player.volume_db = -6.0
	add_child(_click_player)
	_hover_player = AudioStreamPlayer.new()
	_hover_player.name = "MenuHover"
	_hover_player.stream = _make_hover_wav()
	_hover_player.volume_db = -12.0
	add_child(_hover_player)
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "MenuAmbient"
	_ambient_player.stream = _make_ambient_wav()
	_ambient_player.volume_db = -18.0
	add_child(_ambient_player)

func _make_click_wav() -> AudioStreamWAV:
	var rate := 22050
	var n := int(0.06 * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / rate
		var env := exp(-t * 40.0)
		var s := sin(TAU * 880.0 * t) * 0.35 * env + sin(TAU * 1320.0 * t) * 0.2 * env
		var s16 := int(clampf(s, -1.0, 1.0) * 32767.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

func _make_hover_wav() -> AudioStreamWAV:
	var rate := 22050
	var n := int(0.04 * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / rate
		var env := exp(-t * 50.0)
		var s := sin(TAU * 660.0 * t) * 0.2 * env
		var s16 := int(clampf(s, -1.0, 1.0) * 32767.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

func _make_ambient_wav() -> AudioStreamWAV:
	var rate := 22050
	var n := int(2.5 * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var prev := 0.0
	for i in range(n):
		var t := float(i) / rate
		var wind := sin(TAU * 0.15 * t) * 0.04 + sin(TAU * 0.37 * t) * 0.03
		var noise := (randf() * 2.0 - 1.0)
		prev = prev * 0.92 + noise * 0.08
		var bird := 0.0
		if int(t * 2.0) % 5 == 0 and fmod(t, 0.5) < 0.08:
			bird = sin(TAU * (1800.0 + sin(t * 20.0) * 200.0) * t) * 0.06 * exp(-fmod(t, 0.5) * 20.0)
		var s := clampf(wind + prev * 0.12 + bird, -1.0, 1.0)
		var s16 := int(s * 16000.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav

func _play_click() -> void:
	if _click_player:
		_click_player.play()

func _play_hover() -> void:
	if _hover_player and not _hover_player.playing:
		_hover_player.play()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_apply_responsive_layout()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_instance_valid(dialog_layer):
		dialog_layer.queue_free()
		dialog_layer = null
		get_viewport().set_input_as_handled()

func _build_3d_backdrop() -> void:
	var container := SubViewportContainer.new()
	container.name = "ThreeDMenuBackdrop"
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	move_child(container, 0)
	var viewport := SubViewport.new()
	viewport.name = "WorldViewport"
	viewport.transparent_bg = false
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(1280, 720)
	container.add_child(viewport)
	var world_script = load("res://scripts/menu_world_3d.gd")
	var world: Node3D = world_script.new() if world_script else Node3D.new()
	world.name = "VoxelMenuWorld"
	viewport.add_child(world)

func _build_title_block() -> void:
	var title := Label.new()
	title.name = "GameTitle"
	title.text = "BLOCKCRAFT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color("#f5f0e6"))
	title.add_theme_color_override("font_shadow_color", Color("#1a1208"))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.position = Vector2(36, 28)
	title.size = Vector2(520, 64)
	add_child(title)
	var tagline := Label.new()
	tagline.name = "Tagline"
	tagline.text = "EXPLORE  •  BUILD  •  SURVIVE"
	tagline.add_theme_font_size_override("font_size", 14)
	tagline.add_theme_color_override("font_color", Color("#d8e8f0"))
	tagline.add_theme_color_override("font_shadow_color", Color("#102030"))
	tagline.add_theme_constant_override("shadow_offset_x", 1)
	tagline.add_theme_constant_override("shadow_offset_y", 1)
	tagline.position = Vector2(42, 88)
	tagline.size = Vector2(400, 24)
	add_child(tagline)

func _build_menu_buttons() -> void:
	var panel := PanelContainer.new()
	panel.name = "MainMenuPanel"
	panel.position = Vector2(36, 130)
	panel.custom_minimum_size = Vector2(260, 220)
	var empty := StyleBoxEmpty.new()
	panel.add_theme_stylebox_override("panel", empty)
	add_child(panel)
	menu_column = VBoxContainer.new()
	menu_column.name = "MenuColumn"
	menu_column.add_theme_constant_override("separation", 10)
	panel.add_child(menu_column)
	_add_menu_button("▶  Play", "play", true)
	_add_menu_button("⚙  Settings", "settings", false)
	_add_menu_button("📖  Help", "help", false)
	_add_menu_button("⏻  Exit", "exit", false)
	status_label = null

func _add_menu_button(caption: String, action: String, primary: bool) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(240, 48 if primary else 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 18 if primary else 16)
	var normal := StyleBoxFlat.new()
	if primary:
		normal.bg_color = Color(0.12, 0.55, 0.28, 0.92)
		normal.border_color = Color(0.45, 0.92, 0.55, 0.95)
	else:
		normal.bg_color = Color(0.06, 0.10, 0.12, 0.78)
		normal.border_color = Color(0.55, 0.70, 0.65, 0.55)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	var hover := normal.duplicate() as StyleBoxFlat
	if primary:
		hover.bg_color = Color(0.18, 0.68, 0.35, 0.96)
	else:
		hover.bg_color = Color(0.12, 0.18, 0.20, 0.90)
		hover.border_color = Color(0.75, 0.95, 0.80, 0.85)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.76, 0.55, 0.18, 0.95) if primary else Color(0.18, 0.22, 0.20, 0.95)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color("#f0f8e6"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#173729"))
	button.pressed.connect(func():
		_play_click()
		_on_menu_action(action)
	)
	button.mouse_entered.connect(_play_hover)
	menu_column.add_child(button)

func _build_feature_strip() -> void:
	var strip := HBoxContainer.new()
	strip.name = "FeatureStrip"
	strip.add_theme_constant_override("separation", 8)
	strip.position = Vector2(16, 500)
	strip.size = Vector2(1248, 140)
	add_child(strip)
	var cards := [
		{"title": "EXPLORE VAST WORLDS", "sub": "Endless horizons", "c0": Color("#3a7a9a"), "c1": Color("#1a4a5a")},
		{"title": "GATHER RESOURCES", "sub": "Mine deep ores", "c0": Color("#5a5048"), "c1": Color("#2a2820")},
		{"title": "CRAFT & BUILD", "sub": "Shape your base", "c0": Color("#8a6a40"), "c1": Color("#4a3820")},
		{"title": "SURVIVE THE NIGHT", "sub": "Face the dark", "c0": Color("#2a3a5a"), "c1": Color("#101828")},
		{"title": "BUILD YOUR DREAMS", "sub": "Homes & castles", "c0": Color("#4a7a50"), "c1": Color("#1a3a28")},
		{"title": "MULTIPLAYER (OPTIONAL)", "sub": "Play with friends", "c0": Color("#4a6a8a"), "c1": Color("#1a2a40")},
	]
	for card in cards:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(200, 130)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = card["c1"]
		style.border_color = card["c0"]
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		panel.add_theme_stylebox_override("panel", style)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		panel.add_child(v)
		var title := Label.new()
		title.text = card["title"]
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 12)
		title.add_theme_color_override("font_color", Color("#f0f8e6"))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD
		v.add_child(title)
		var sub := Label.new()
		sub.text = card["sub"]
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 11)
		sub.add_theme_color_override("font_color", Color("#a8c8b8"))
		v.add_child(sub)
		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(0, 48)
		bar.color = card["c0"]
		v.add_child(bar)
		strip.add_child(panel)

func _build_footer_bar() -> void:
	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", 24)
	footer.position = Vector2(24, 660)
	footer.size = Vector2(1232, 48)
	add_child(footer)
	var items := [
		["⬡", "Procedural Worlds", "Never the same twice"],
		["🌲", "Dynamic Biomes", "Forests, mountains, deserts..."],
		["⛏", "Multiple Tools", "Mine, craft, build"],
		["♥", "Health & Hunger", "Stay alive"],
		["☀", "Day & Night Cycle", "New challenges"],
		["👥", "Online Play", "Play with friends"],
	]
	for item in items:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var icon := Label.new()
		icon.text = item[0] + "  " + item[1]
		icon.add_theme_font_size_override("font_size", 12)
		icon.add_theme_color_override("font_color", Color("#d0e8d8"))
		cell.add_child(icon)
		var desc := Label.new()
		desc.text = item[2]
		desc.add_theme_font_size_override("font_size", 10)
		desc.add_theme_color_override("font_color", Color("#809890"))
		cell.add_child(desc)
		footer.add_child(cell)

func _apply_responsive_layout() -> void:
	var vs := size
	if vs.x <= 0.0 or vs.y <= 0.0:
		return
	var sx := vs.x / DESIGN_SIZE.x
	var sy := vs.y / DESIGN_SIZE.y
	var s := minf(sx, sy)
	var title := get_node_or_null("GameTitle") as Label
	var tagline := get_node_or_null("Tagline") as Label
	var panel := get_node_or_null("MainMenuPanel") as Control
	var strip := get_node_or_null("FeatureStrip") as Control
	var footer := get_node_or_null("Footer") as Control
	if title:
		title.position = Vector2(36 * sx, 28 * sy)
		title.add_theme_font_size_override("font_size", int(52 * s))
	if tagline:
		tagline.position = Vector2(42 * sx, 88 * sy)
	if panel:
		panel.position = Vector2(36 * sx, 130 * sy)
		panel.custom_minimum_size = Vector2(260 * s, 220 * s)
	if strip:
		strip.position = Vector2(16 * sx, vs.y - 220 * sy)
		strip.size = Vector2(vs.x - 32 * sx, 140 * sy)
	if footer:
		footer.position = Vector2(24 * sx, vs.y - 55 * sy)
		footer.size = Vector2(vs.x - 48 * sx, 48 * sy)
	var backdrop := get_node_or_null("ThreeDMenuBackdrop") as SubViewportContainer
	if backdrop:
		var vp := backdrop.get_node_or_null("WorldViewport") as SubViewport
		if vp:
			vp.size = Vector2i(maxi(int(vs.x), 640), maxi(int(vs.y), 360))

func _on_menu_action(action: String) -> void:
	match action:
		"play":
			get_tree().change_scene_to_file(GAME_SCENE)
		"settings":
			_open_dialog("Settings", "Audio, controls, and graphics options will expand here.\n\n• Master volume\n• Music / SFX balance\n• Touch controls (mobile)", [
				{"label": "Close", "action": "close", "primary": true}
			])
		"help":
			_open_dialog("How to Play", "• Move with WASD or the left joystick\n• Look with mouse or right-side drag\n• LMB / MINE to dig blocks\n• RMB / PLACE to build\n• 1–9 select hotbar slots\n• B upgrade backpack\n• Explore, mine ores, find chests!", [
				{"label": "Got it", "action": "close", "primary": true}
			])
		"exit":
			get_tree().quit()
		"worlds":
			_open_dialog("Worlds", "Single world for now — your progress auto-saves.", [
				{"label": "Play", "action": "play", "primary": true},
				{"label": "Back", "action": "close", "primary": false}
			])

func _open_dialog(title_text: String, body_text: String, options: Array) -> void:
	if is_instance_valid(dialog_layer):
		dialog_layer.queue_free()
	dialog_layer = Control.new()
	dialog_layer.name = "DialogLayer"
	dialog_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dialog_layer)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.05, 0.06, 0.72)
	dialog_layer.add_child(dim)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(480, 280)
	box.position = Vector2(size.x * 0.5 - 240, size.y * 0.5 - 140)
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(0.06, 0.12, 0.12, 0.96)
	box_style.border_color = Color("#6ab88a")
	box_style.set_border_width_all(2)
	box_style.set_corner_radius_all(14)
	box_style.content_margin_left = 20
	box_style.content_margin_right = 20
	box_style.content_margin_top = 16
	box_style.content_margin_bottom = 16
	box.add_theme_stylebox_override("panel", box_style)
	dialog_layer.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	box.add_child(col)
	var t := Label.new()
	t.text = title_text
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", Color("#f0f8e6"))
	col.add_child(t)
	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color("#c8e0d0"))
	col.add_child(body)
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	col.add_child(btn_row)
	for opt in options:
		var b := Button.new()
		b.text = str(opt.get("label", "OK"))
		b.custom_minimum_size = Vector2(120, 40)
		b.focus_mode = Control.FOCUS_NONE
		var is_primary: bool = bool(opt.get("primary", false))
		var ns := StyleBoxFlat.new()
		ns.bg_color = Color(0.12, 0.55, 0.28, 0.92) if is_primary else Color(0.08, 0.14, 0.14, 0.9)
		ns.border_color = Color("#6ab88a")
		ns.set_border_width_all(2)
		ns.set_corner_radius_all(8)
		b.add_theme_stylebox_override("normal", ns)
		b.add_theme_color_override("font_color", Color("#f0f8e6"))
		var act := str(opt.get("action", "close"))
		b.pressed.connect(func():
			_play_click()
			_on_dialog_action(act)
		)
		btn_row.add_child(b)

func _on_dialog_action(action: String) -> void:
	if action == "close":
		if is_instance_valid(dialog_layer):
			dialog_layer.queue_free()
			dialog_layer = null
	elif action == "play":
		if is_instance_valid(dialog_layer):
			dialog_layer.queue_free()
		_on_menu_action("play")
