extends Control
## Official Blockraft title screen — matched to reference art.

const GAME_SCENE := "res://scenes/main.tscn"
const LOGIN_SCENE := "res://scenes/login.tscn"
const DESIGN_SIZE := Vector2(1280.0, 720.0)

var menu_column: VBoxContainer
var status_label: Label
var _play_button: Button
var dialog_layer: Control
var _click_player: AudioStreamPlayer
var _hover_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _title_root: Control
var _feature_strip: HBoxContainer
var _footer: Control
var _tagline: Label
var _subtitle: Label

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
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_show_session_user()
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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if is_instance_valid(dialog_layer):
			dialog_layer.queue_free()
			dialog_layer = null
			return
		_on_menu_action("exit")

func _build_3d_backdrop() -> void:
	var host := SubViewportContainer.new()
	host.name = "MenuWorldHost"
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.stretch = true
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)
	move_child(host, 0)
	var vp := SubViewport.new()
	vp.name = "MenuWorldViewport"
	vp.transparent_bg = false
	vp.handle_input_locally = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(1280, 720)
	host.add_child(vp)
	var world_script = load("res://scripts/menu_world_3d.gd")
	if world_script:
		var world: Node = world_script.new()
		world.name = "MenuWorld3D"
		vp.add_child(world)
	var top_fade := ColorRect.new()
	top_fade.color = Color(0.02, 0.04, 0.06, 0.35)
	top_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_fade.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_fade.offset_bottom = 90
	add_child(top_fade)
	var bottom_fade := ColorRect.new()
	bottom_fade.color = Color(0.02, 0.05, 0.04, 0.55)
	bottom_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_fade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_fade.offset_top = -160
	add_child(bottom_fade)

func _build_title_block() -> void:
	_title_root = Control.new()
	_title_root.name = "TitleBlock"
	_title_root.position = Vector2(36, 28)
	_title_root.custom_minimum_size = Vector2(520, 110)
	add_child(_title_root)
	var word := "BLOCKCRAFT"
	var layers := [
		{"off": Vector2(5, 6), "col": Color("#1a1510"), "size": 56},
		{"off": Vector2(3, 4), "col": Color("#3a3428"), "size": 56},
		{"off": Vector2(1, 2), "col": Color("#6a6358"), "size": 56},
		{"off": Vector2(0, 0), "col": Color("#f2efe6"), "size": 56},
	]
	for layer in layers:
		var lab := Label.new()
		lab.text = word
		lab.position = layer["off"]
		lab.add_theme_font_size_override("font_size", int(layer["size"]))
		lab.add_theme_color_override("font_color", layer["col"])
		_title_root.add_child(lab)
	var highlight := Label.new()
	highlight.text = word
	highlight.position = Vector2(0, -1)
	highlight.add_theme_font_size_override("font_size", 56)
	highlight.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	_title_root.add_child(highlight)
	_subtitle = Label.new()
	_subtitle.text = "EXPLORE  ·  BUILD  ·  SURVIVE"
	_subtitle.position = Vector2(8, 72)
	_subtitle.add_theme_font_size_override("font_size", 15)
	_subtitle.add_theme_color_override("font_color", Color("#c8e0d0"))
	_title_root.add_child(_subtitle)
	_tagline = Label.new()
	_tagline.text = "Your World\nYour Adventure"
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tagline.add_theme_font_size_override("font_size", 22)
	_tagline.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_tagline.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_tagline.add_theme_constant_override("shadow_offset_x", 2)
	_tagline.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_tagline)

func _build_menu_buttons() -> void:
	menu_column = VBoxContainer.new()
	menu_column.position = Vector2(40, 130)
	menu_column.custom_minimum_size = Vector2(280, 0)
	menu_column.add_theme_constant_override("separation", 12)
	add_child(menu_column)
	_add_menu_button("▶   Play", "play", true)
	_add_menu_button("⚙   Settings", "settings", false)
	_add_menu_button("📖   Help", "help", false)
	_add_menu_button("⏻   Exit", "exit", false)

func _add_menu_button(caption: String, action: String, primary: bool) -> void:
	var button := Button.new()
	if action == "play":
		button.name = "PlayButton"
		_play_button = button
	button.text = caption
	button.custom_minimum_size = Vector2(260, 52 if primary else 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	var normal := StyleBoxFlat.new()
	var hover := StyleBoxFlat.new()
	var pressed := StyleBoxFlat.new()
	if primary:
		normal.bg_color = Color("#2d8a4a")
		hover.bg_color = Color("#3aa85a")
		pressed.bg_color = Color("#1f6a38")
		normal.border_color = Color("#7dff9a")
		hover.border_color = Color("#a8ffc0")
	else:
		normal.bg_color = Color(0.08, 0.12, 0.12, 0.82)
		hover.bg_color = Color(0.14, 0.2, 0.18, 0.9)
		pressed.bg_color = Color(0.05, 0.08, 0.08, 0.95)
		normal.border_color = Color(0.35, 0.55, 0.45, 0.7)
		hover.border_color = Color(0.55, 0.85, 0.65, 0.9)
	for s in [normal, hover, pressed]:
		s.set_corner_radius_all(10)
		s.set_border_width_all(2)
		s.content_margin_left = 16
		s.content_margin_right = 16
		s.content_margin_top = 8
		s.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color("#f0fff4") if primary else Color("#d8ece0"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 18 if primary else 16)
	button.pressed.connect(func():
		_play_click()
		_on_menu_action(action)
	)
	button.mouse_entered.connect(_play_hover)
	menu_column.add_child(button)

func _build_feature_strip() -> void:
	_feature_strip = HBoxContainer.new()
	_feature_strip.name = "FeatureStrip"
	_feature_strip.add_theme_constant_override("separation", 10)
	add_child(_feature_strip)
	var cards := [
		{"title": "EXPLORE VAST WORLDS", "sub": "Endless horizons", "tex": "res://assets/ui/cards/explore.svg", "c0": Color("#2a6a8a"), "icon": "🏔"},
		{"title": "GATHER RESOURCES", "sub": "Mine deep ores", "tex": "res://assets/ui/cards/mining.svg", "c0": Color("#5a4840"), "icon": "⛏"},
		{"title": "CRAFT & BUILD", "sub": "Shape your base", "tex": "res://assets/ui/cards/build.svg", "c0": Color("#7a5a30"), "icon": "🛠"},
		{"title": "SURVIVE THE NIGHT", "sub": "Face the dark", "tex": "res://assets/ui/cards/survive.svg", "c0": Color("#2a3050"), "icon": "🌙"},
		{"title": "BUILD YOUR DREAMS", "sub": "Homes & castles", "tex": "res://assets/ui/cards/dreams.svg", "c0": Color("#3a6a40"), "icon": "🏠"},
		{"title": "MULTIPLAYER (OPTIONAL)", "sub": "Play with friends", "tex": "res://assets/ui/cards/multiplayer.svg", "c0": Color("#3a5070"), "icon": "👥"},
	]
	for card in cards:
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.custom_minimum_size = Vector2(190, 148)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.08, 0.1, 0.92)
		style.border_color = card["c0"]
		style.set_border_width_all(2)
		style.set_corner_radius_all(10)
		style.content_margin_bottom = 6
		panel.add_theme_stylebox_override("panel", style)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		panel.add_child(v)
		var img_host := Control.new()
		img_host.custom_minimum_size = Vector2(0, 88)
		img_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(img_host)
		var bg := ColorRect.new()
		bg.color = card["c0"]
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img_host.add_child(bg)
		var tex_path: String = card["tex"]
		if ResourceLoader.exists(tex_path):
			var tr := TextureRect.new()
			tr.texture = load(tex_path)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			img_host.add_child(tr)
		else:
			var icon := Label.new()
			icon.text = str(card["icon"])
			icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			icon.add_theme_font_size_override("font_size", 36)
			img_host.add_child(icon)
		var fade := ColorRect.new()
		fade.color = Color(0, 0, 0, 0.35)
		fade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		fade.offset_top = -28
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img_host.add_child(fade)
		var title := Label.new()
		title.text = card["title"]
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 11)
		title.add_theme_color_override("font_color", Color("#f5f8f0"))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD
		v.add_child(title)
		var sub := Label.new()
		sub.text = card["sub"]
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 10)
		sub.add_theme_color_override("font_color", Color("#a8c8b8"))
		v.add_child(sub)
		_feature_strip.add_child(panel)

func _build_footer_bar() -> void:
	_footer = PanelContainer.new()
	_footer.name = "FooterBar"
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0.04, 0.06, 0.07, 0.88)
	fs.content_margin_left = 16
	fs.content_margin_right = 16
	fs.content_margin_top = 8
	fs.content_margin_bottom = 8
	_footer.add_theme_stylebox_override("panel", fs)
	add_child(_footer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_footer.add_child(row)
	var items := [
		{"icon": "⬡", "title": "Procedural Worlds", "sub": "Never the same twice"},
		{"icon": "🌲", "title": "Dynamic Biomes", "sub": "Forests, mountains, deserts..."},
		{"icon": "⚒", "title": "Multiple Tools", "sub": "Mine, craft, build"},
		{"icon": "♥", "title": "Health & Hunger", "sub": "Stay alive"},
		{"icon": "☀", "title": "Day & Night Cycle", "sub": "New challenges"},
		{"icon": "👥", "title": "Online Play", "sub": "Play with friends"},
	]
	for it in items:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 8)
		var ic := Label.new()
		ic.text = it["icon"]
		ic.add_theme_font_size_override("font_size", 18)
		ic.add_theme_color_override("font_color", Color("#d0e8d8"))
		cell.add_child(ic)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		var t := Label.new()
		t.text = it["title"]
		t.add_theme_font_size_override("font_size", 12)
		t.add_theme_color_override("font_color", Color("#e8f5ec"))
		col.add_child(t)
		var s := Label.new()
		s.text = it["sub"]
		s.add_theme_font_size_override("font_size", 10)
		s.add_theme_color_override("font_color", Color("#88a898"))
		col.add_child(s)
		cell.add_child(col)
		row.add_child(cell)

func _apply_responsive_layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	if vs.x < 10.0 or vs.y < 10.0:
		return
	var sx := vs.x / DESIGN_SIZE.x
	var sy := vs.y / DESIGN_SIZE.y
	var scale := minf(sx, sy)
	if _title_root:
		_title_root.position = Vector2(36.0 * sx, 28.0 * sy)
		_title_root.scale = Vector2(clampf(scale, 0.75, 1.15), clampf(scale, 0.75, 1.15))
	if menu_column:
		menu_column.position = Vector2(40.0 * sx, 130.0 * sy)
		menu_column.scale = Vector2(clampf(scale, 0.8, 1.1), clampf(scale, 0.8, 1.1))
	if _feature_strip:
		var strip_h := 155.0
		var footer_h := 64.0
		_feature_strip.position = Vector2(16.0 * sx, vs.y - footer_h - strip_h - 12.0)
		_feature_strip.size = Vector2(vs.x - 32.0 * sx, strip_h)
	if _footer:
		_footer.position = Vector2(0, vs.y - 64.0)
		_footer.size = Vector2(vs.x, 64.0)
	if _tagline:
		_tagline.position = Vector2(vs.x - 280.0, vs.y * 0.38)
		_tagline.custom_minimum_size = Vector2(250, 80)

func _show_session_user() -> void:
	var username := "Guest"
	var is_guest := true
	if Engine.has_meta("blockraft_user"):
		username = str(Engine.get_meta("blockraft_user"))
	if Engine.has_meta("blockraft_guest"):
		is_guest = bool(Engine.get_meta("blockraft_guest"))
	var bar := HBoxContainer.new()
	bar.name = "SessionBar"
	bar.position = Vector2(16, 8)
	bar.add_theme_constant_override("separation", 10)
	add_child(bar)
	var lab := Label.new()
	lab.text = ("Guest" if is_guest else "Player") + ": " + username
	lab.add_theme_font_size_override("font_size", 13)
	lab.add_theme_color_override("font_color", Color("#c8e0d0"))
	bar.add_child(lab)
	var out_btn := Button.new()
	out_btn.text = "Logout"
	out_btn.custom_minimum_size = Vector2(90, 28)
	out_btn.pressed.connect(func():
		_play_click()
		Engine.set_meta("blockraft_user", "")
		Engine.set_meta("blockraft_guest", true)
		var packed := load(LOGIN_SCENE) as PackedScene
		if packed:
			get_tree().change_scene_to_packed(packed)
	)
	bar.add_child(out_btn)

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
			_open_dialog("How to Play", "• Move with WASD or touch stick\n• LMB / MINE dig & attack\n• RMB / PLACE build\n• F depot store & upgrade bag\n• E eat meat\n• Survive night, weather & animals", [{"label": "Close", "action": "close", "primary": true}])
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

func _on_dialog_action(_action: String) -> void:
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
