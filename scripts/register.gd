extends Control
## Blockraft — create a new local account.

const LOGIN_SCENE := "res://scenes/login.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const PROFILE_PATH := "user://profile.cfg"

var _user: LineEdit
var _pass: LineEdit
var _pass2: LineEdit
var _status: Label
var _click: AudioStreamPlayer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_backdrop()
	_build_ui()
	_click = AudioStreamPlayer.new()
	_click.stream = _tone(720.0, 0.05)
	_click.volume_db = -8.0
	add_child(_click)

func _tone(freq: float, dur: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / rate
		var env := exp(-t * 35.0)
		var s := sin(TAU * freq * t) * 0.3 * env
		var s16 := int(clampf(s, -1.0, 1.0) * 32767.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

func _build_backdrop() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#0a1216")
	add_child(bg)
	var left := ColorRect.new()
	left.color = Color(0.1, 0.22, 0.16, 0.5)
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.offset_right = 400
	add_child(left)
	for i in range(10):
		var b := ColorRect.new()
		var s := 20 + (i % 3) * 12
		b.size = Vector2(s, s)
		b.position = Vector2(500 + (i * 71) % 680, 60 + (i * 49) % 500)
		b.color = Color(0.22, 0.5, 0.32, 0.28)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(b)

func _build_ui() -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(440, 520)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-220, -260)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.07, 0.11, 0.09, 0.97)
	st.border_color = Color("#5ecf8a")
	st.set_border_width_all(2)
	st.set_corner_radius_all(16)
	st.content_margin_left = 28
	st.content_margin_right = 28
	st.content_margin_top = 22
	st.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", st)
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var logo := Label.new()
	logo.text = "BLOCKCRAFT"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", 32)
	logo.add_theme_color_override("font_color", Color("#f2efe6"))
	logo.add_theme_color_override("font_shadow_color", Color("#1a1510"))
	logo.add_theme_constant_override("shadow_offset_x", 3)
	logo.add_theme_constant_override("shadow_offset_y", 3)
	v.add_child(logo)
	var head := Label.new()
	head.text = "Create New Account"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 18)
	head.add_theme_color_override("font_color", Color("#a8e0c0"))
	v.add_child(head)
	var note := Label.new()
	note.text = "Local profile on this device only"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color("#6a8878"))
	v.add_child(note)
	v.add_child(_field_label("Username (min 2 characters)"))
	_user = LineEdit.new()
	_user.placeholder_text = "Choose a username"
	_user.custom_minimum_size = Vector2(0, 40)
	_user.max_length = 20
	v.add_child(_user)
	v.add_child(_field_label("Password (optional)"))
	_pass = LineEdit.new()
	_pass.placeholder_text = "••••••••"
	_pass.secret = true
	_pass.custom_minimum_size = Vector2(0, 40)
	_pass.max_length = 32
	v.add_child(_pass)
	v.add_child(_field_label("Confirm password"))
	_pass2 = LineEdit.new()
	_pass2.placeholder_text = "••••••••"
	_pass2.secret = true
	_pass2.custom_minimum_size = Vector2(0, 40)
	_pass2.max_length = 32
	v.add_child(_pass2)
	_status = Label.new()
	_status.text = " "
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color("#e8a070"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(_status)
	var create_btn := _btn("Create Account", true)
	create_btn.pressed.connect(_on_create)
	v.add_child(create_btn)
	var back_btn := _btn("Back to Login", false)
	back_btn.pressed.connect(_on_back)
	v.add_child(back_btn)

func _field_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color("#c8e0d0"))
	return l

func _btn(caption: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(0, 46)
	var normal := StyleBoxFlat.new()
	var hover := StyleBoxFlat.new()
	if primary:
		normal.bg_color = Color("#2d8a4a")
		hover.bg_color = Color("#3aa85a")
		normal.border_color = Color("#7dff9a")
	else:
		normal.bg_color = Color(0.1, 0.14, 0.13, 0.9)
		hover.bg_color = Color(0.16, 0.22, 0.2, 0.95)
		normal.border_color = Color("#4a6a58")
	for s in [normal, hover]:
		s.set_corner_radius_all(10)
		s.set_border_width_all(2)
		s.content_margin_top = 8
		s.content_margin_bottom = 8
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", normal)
	b.add_theme_color_override("font_color", Color("#f0fff4"))
	b.add_theme_font_size_override("font_size", 16)
	return b

func _profile_exists(username: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) != OK:
		return false
	return cfg.has_section_key("users", username.to_lower())

func _create_profile(username: String, password: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PROFILE_PATH)
	cfg.set_value("users", username.to_lower(), str(password.hash()) if password != "" else "")
	cfg.set_value("session", "last_user", username)
	cfg.set_value("session", "guest", false)
	cfg.set_value("session", "logged_in", true)
	cfg.save(PROFILE_PATH)
	Engine.set_meta("blockraft_user", username)
	Engine.set_meta("blockraft_guest", false)

func _on_create() -> void:
	if _click:
		_click.play()
	var u := _user.text.strip_edges()
	var p := _pass.text
	var p2 := _pass2.text
	if u.length() < 2:
		_status.text = "Username must be at least 2 characters"
		return
	for ch in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		if ch in u:
			_status.text = "Username has invalid characters"
			return
	if p != p2:
		_status.text = "Passwords do not match"
		return
	if p.length() > 0 and p.length() < 4:
		_status.text = "Password must be 4+ characters (or empty)"
		return
	if _profile_exists(u):
		_status.text = "Username already taken"
		return
	_create_profile(u, p)
	_status.add_theme_color_override("font_color", Color("#7dff9a"))
	_status.text = "Account created! Entering menu..."
	call_deferred("_go_menu")

func _on_back() -> void:
	if _click:
		_click.play()
	var packed := load(LOGIN_SCENE) as PackedScene
	if packed:
		get_tree().change_scene_to_packed(packed)

func _go_menu() -> void:
	var packed := load(MENU_SCENE) as PackedScene
	if packed == null:
		_status.text = "Failed to load menu"
		return
	get_tree().change_scene_to_packed(packed)
