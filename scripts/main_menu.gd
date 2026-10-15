extends Control
## Official Blockraft title screen — built to match the reference art exactly.

const GAME_SCENE := "res://scenes/main.tscn"
const DESIGN_SIZE := Vector2(1280.0, 720.0)

var menu_column: VBoxContainer
var status_label: Label
var _play_button: Button
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
	var s = load("res://scripts/settings.gd").new()
	s.load_settings()
	s.apply_audio()
	if _ambient_player:
		_ambient_player.volume_db = -18.0 + linear_to_db(maxf(s.master_volume, 0.01))

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
	for i in range(n):
		var t := float(i) / rate
		var s := sin(TAU * 110.0 * t) * 0.04 + sin(TAU * 165.0 * t) * 0.03 + sin(TAU * 55.0 * t) * 0.05
		var s16 := int(clampf(s, -1.0, 1.0) * 12000.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

func _play_click() -> void:
	if _click_player: _click_player.play()

func _play_hover() -> void:
	if _hover_player: _hover_player.play()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_layout()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_instance_valid(dialog_layer):
		dialog_layer.queue_free()
		dialog_layer = null

func _build_3d_backdrop() -> void:
	var sub := SubViewportContainer.new()
	sub.name = "ThreeDMenuBackdrop"
	sub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sub.stretch = true
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sub)
	move_child(sub, 0)
	var vp := SubViewport.new()
	vp.name = "WorldViewport"
	vp.transparent_bg = false
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.add_child(vp)
	var world_script = load("res://scripts/menu_world_3d.gd")
	if world_script:
		var world = world_script.new()
		world.name = "VoxelMenuWorld"
		vp.add_child(world)

func _build_title_block() -> void:
	var title := Label.new()
	title.text = "BLOCKCRAFT"
	title.position = Vector2(40, 36)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("#f5f8f0"))
	title.add_theme_color_override("font_shadow_color", Color("#1a2e22"))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	add_child(title)
	var sub := Label.new()
	sub.text = "EXPLORE  ·  BUILD  ·  SURVIVE"
	sub.position = Vector2(44, 88)
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color("#b8d4c0"))
	add_child(sub)

func _build_menu_buttons() -> void:
	menu_column = VBoxContainer.new()
	menu_column.position = Vector2(40, 140)
	menu_column.custom_minimum_size = Vector2(260, 0)
	menu_column.add_theme_constant_override("separation", 10)
	add_child(menu_column)
	_add_menu_button("▶  Play", "play", true)
	_add_menu_button("⚙  Settings", "settings", false)
	_add_menu_button("📖  Help", "help", false)
	_add_menu_button("⏻  Exit", "exit", false)

func _add_menu_button(caption: String, action: String, primary: bool) -> void:
	var button := Button.new()
	if action == "play":
		button.name = "PlayButton"
		_play_button = button
	button.text = caption
	button.custom_minimum_size = Vector2(240, 48 if primary else 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 18 if primary else 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.45, 0.28, 0.92) if primary else Color(0.08, 0.12, 0.1, 0.85)
	normal.border_color = Color("#8fd4a8") if primary else Color("#4a6a58")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.18, 0.55, 0.35, 0.95) if primary else Color(0.14, 0.2, 0.16, 0.9)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.85, 0.75, 0.35, 0.95)
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
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
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
	footer.position = Vector2(16, 660)
	footer.add_theme_constant_override("separation", 18)
	add_child(footer)
	for item in ["○ Procedural Worlds", "▲ Dynamic Biomes", "⚒ Multiple Tools", "♥ Health & Hunger", "☀ Day & Night Cycle", "👥 Online Play"]:
		var l := Label.new()
		l.text = item
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", Color("#9ab8a8")
		)
		footer.add_child(l)

func _apply_responsive_layout() -> void:
	pass

func _start_game() -> void:
	if is_instance_valid(_play_button):
		_play_button.disabled = true
		_play_button.text = "Loading world..."
	print("Blockraft: Play pressed; requesting gameplay scene")
	call_deferred("_change_to_game_scene")

func _change_to_game_scene() -> void:
	var packed := load(GAME_SCENE) as PackedScene
	if packed == null:
		push_error("Blockraft: cannot load gameplay scene: " + GAME_SCENE)
		_restore_play_button("Load failed — tap to retry")
		return
	var tree := get_tree()
	var err := tree.change_scene_to_packed(packed)
	if err != OK:
		push_error("Blockraft: gameplay scene transition failed: %s" % err)
		_restore_play_button("Retry Play")

func _restore_play_button(caption: String) -> void:
	if is_instance_valid(_play_button):
		_play_button.disabled = false
		_play_button.text = caption

func _on_menu_action(action: String) -> void:
	match action:
		"play":
			_start_game()
		"settings":
			_open_settings_panel()
		"help":
			_open_dialog("How to Play", "• Move with WASD or the left joystick\n• Look with mouse or right-side drag\n• LMB / MINE to dig blocks\n• RMB / PLACE to build\n• 1–9 select hotbar slots\n• B upgrade backpack\n• E eat / forage\n• Explore, mine ores, find chests!", [
				{"label": "Close", "action": "close", "primary": true}
			])
		"exit":
			get_tree().quit()

func _open_dialog(title_text: String, body_text: String, options: Array) -> void:
	if is_instance_valid(dialog_layer):
		dialog_layer.queue_free()
	dialog_layer = Control.new()
	dialog_layer.name = "MenuDialog"
	dialog_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dialog_layer)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dialog_layer.add_child(dim)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(480, 280)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-240, -140)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.12, 0.1, 0.96)
	st.border_color = Color("#6ab88a")
	st.set_border_width_all(2)
	st.set_corner_radius_all(12)
	box.add_theme_stylebox_override("panel", st)
	dialog_layer.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#f0f8e6"))
	v.add_child(title)
	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color", Color("#c8e0d0"))
	v.add_child(body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for opt in options:
		var b := Button.new()
		b.text = opt["label"]
		b.custom_minimum_size = Vector2(120, 36)
		var act: String = opt["action"]
		b.pressed.connect(func(): _on_dialog_action(act))
		row.add_child(b)

func _on_dialog_action(action: String) -> void:
	if is_instance_valid(dialog_layer):
		dialog_layer.queue_free()
		dialog_layer = null

func _open_settings_panel() -> void:
	if is_instance_valid(dialog_layer):
		dialog_layer.queue_free()
	var cfg_node = load("res://scripts/settings.gd").new()
	cfg_node.load_settings()
	dialog_layer = Control.new()
	dialog_layer.name = "SettingsPanel"
	dialog_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dialog_layer)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dialog_layer.add_child(dim)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(420, 360)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-210, -180)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.12, 0.1, 0.96)
	st.border_color = Color("#6ab88a")
	st.set_border_width_all(2)
	st.set_corner_radius_all(12)
	box.add_theme_stylebox_override("panel", st)
	dialog_layer.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	box.add_child(v)
	var title := Label.new()
	title.text = "⚙  Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#f0f8e6"))
	v.add_child(title)
	var sens_l := Label.new()
	sens_l.text = "Look sensitivity: %.0f%%" % (cfg_node.look_sensitivity * 100.0)
	sens_l.add_theme_color_override("font_color", Color("#d0e8d8"))
	v.add_child(sens_l)
	var sens := HSlider.new()
	sens.min_value = 0.4
	sens.max_value = 2.0
	sens.step = 0.05
	sens.value = cfg_node.look_sensitivity
	sens.custom_minimum_size = Vector2(360, 24)
	sens.value_changed.connect(func(val):
		cfg_node.look_sensitivity = val
		sens_l.text = "Look sensitivity: %.0f%%" % (val * 100.0)
	)
	v.add_child(sens)
	var vol_l := Label.new()
	vol_l.text = "Master volume: %.0f%%" % (cfg_node.master_volume * 100.0)
	vol_l.add_theme_color_override("font_color", Color("#d0e8d8"))
	v.add_child(vol_l)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = cfg_node.master_volume
	vol.custom_minimum_size = Vector2(360, 24)
	vol.value_changed.connect(func(val):
		cfg_node.master_volume = val
		cfg_node.apply_audio()
		vol_l.text = "Master volume: %.0f%%" % (val * 100.0)
		if _ambient_player:
			_ambient_player.volume_db = -18.0 + linear_to_db(maxf(val, 0.01))
	)
	v.add_child(vol)
	var day_l := Label.new()
	day_l.text = "Day cycle speed: %.0f%%" % (cfg_node.day_speed * 100.0)
	day_l.add_theme_color_override("font_color", Color("#d0e8d8"))
	v.add_child(day_l)
	var day := HSlider.new()
	day.min_value = 0.25
	day.max_value = 3.0
	day.step = 0.25
	day.value = cfg_node.day_speed
	day.custom_minimum_size = Vector2(360, 24)
	day.value_changed.connect(func(val):
		cfg_node.day_speed = val
		day_l.text = "Day cycle speed: %.0f%%" % (val * 100.0)
	)
	v.add_child(day)
	var hint := Label.new()
	hint.text = "Saved settings apply in the next Play session."
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color("#88a898"))
	v.add_child(hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.custom_minimum_size = Vector2(120, 40)
	save_btn.pressed.connect(func():
		cfg_node.save_settings()
		cfg_node.apply_audio()
		_play_click()
		if is_instance_valid(dialog_layer):
			dialog_layer.queue_free()
			dialog_layer = null
	)
	row.add_child(save_btn)
	var close_btn := Button.new()
	close_btn.text = "Cancel"
	close_btn.custom_minimum_size = Vector2(120, 40)
	close_btn.pressed.connect(func():
		_play_click()
		if is_instance_valid(dialog_layer):
			dialog_layer.queue_free()
			dialog_layer = null
	)
	row.add_child(close_btn)
