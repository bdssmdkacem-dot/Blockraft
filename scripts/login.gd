extends Control
## Blockraft login / guest entry screen.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const REGISTER_SCENE := "res://scenes/register.tscn"
const PROFILE_PATH := "user://profile.cfg"

var _user_edit: LineEdit
var _pass_edit: LineEdit
var _status: Label
var _click: AudioStreamPlayer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_backdrop()
	_build_ui()
	_click = AudioStreamPlayer.new()
	_click.stream = _tone(880.0, 0.05)
	_click.volume_db = -8.0
	add_child(_click)
	var saved := _load_last_user()
	if saved != "" and _user_edit:
		_user_edit.text = saved

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
	bg.color = Color("#0c1418")
	add_child(bg)
	var left := ColorRect.new()
	left.color = Color(0.08, 0.18, 0.14, 0.55)
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.offset_right = 420
	add_child(left)
	var accent := ColorRect.new()
	accent.color = Color(0.18, 0.55, 0.32, 0.25)
	accent.position = Vector2(0, 0)
	accent.size = Vector2(8, 2000)
	add_child(accent)
	for i in range(12):
		var b := ColorRect.new()
		var s := 18 + (i % 4) * 10
		b.size = Vector2(s, s)
		b.position = Vector2(480 + (i * 67) % 700, 40 + (i * 53) % 520)
		b.color = Color(0.2 + (i % 3) * 0.08, 0.45 + (i % 2) * 0.1, 0.28, 0.35)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(b)

func _build_ui() -> void:
	var center := PanelContainer.new()
	center.name = "LoginCard"
	center.custom_minimum_size = Vector2(420, 480)
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.position = Vector2(-210, -240)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.07, 0.1, 0.09, 0.96)
	st.border_color = Color("#5ecf8a")
	st.set_border_width_all(2)
	st.set_corner_radius_all(16)
	st.content_margin_left = 28
	st.content_margin_right = 28
	st.content_margin_top = 24
	st.content_margin_bottom = 24
	center.add_theme_stylebox_override("panel", st)
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	center.add_child(v)
	var logo := Label.new()
	logo.text = "BLOCKCRAFT"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", 36)
	logo.add_theme_color_override("font_color", Color("#f2efe6"))
	logo.add_theme_color_override("font_shadow_color", Color("#1a1510"))
	logo.add_theme_constant_override("shadow_offset_x", 3)
	logo.add_theme_constant_override("shadow_offset_y", 3)
	v.add_child(logo)
	var sub := Label.new()
	sub.text = "Sign in to continue"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color("#9ab8a8"))
	v.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	v.add_child(spacer)
	var ul := Label.new()
	ul.text = "Username"
	ul.add_theme_font_size_override("font_size", 13)
	ul.add_theme_color_override("font_color", Color("#c8e0d0"))
	v.add_child(ul)
	_user_edit = LineEdit.new()
	_user_edit.placeholder_text = "Enter your name"
	_user_edit.custom_minimum_size = Vector2(0, 40)
	_user_edit.max_length = 20
	v.add_child(_user_edit)
	var pl := Label.new()
	pl.text = "Password (optional / local)"
	pl.add_theme_font_size_override("font_size", 13)
	pl.add_theme_color_override("font_color", Color("#c8e0d0"))
	v.add_child(pl)
	_pass_edit = LineEdit.new()
	_pass_edit.secret = true
	_pass_edit.placeholder_text = "••••••••"
	_pass_edit.custom_minimum_size = Vector2(0, 40)
	_pass_edit.max_length = 32
	v.add_child(_pass_edit)
	_status = Label.new()
	_status.text = " "
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color("#e8a070"))
	v.add_child(_status)
	var login_btn := _make_btn("Login", true)
	login_btn.pressed.connect(_on_login)
	v.add_child(login_btn)
	var guest_btn := _make_btn("Continue as Guest", false)
	guest_btn.pressed.connect(_on_guest)
	v.add_child(guest_btn)
	var reg_btn := _make_btn("Create New Account", false)
	reg_btn.pressed.connect(_on_go_register)
	v.add_child(reg_btn)
	var note := Label.new()
	note.text = "Profiles are stored on this device only.\nOnline multiplayer coming later."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color("#6a8878"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(note)

func _make_btn(caption: String, primary: bool) -> Button:
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

func _load_last_user() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) != OK:
		return ""
	return str(cfg.get_value("session", "last_user", ""))

func _save_session(username: String, guest: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PROFILE_PATH)
	cfg.set_value("session", "last_user", username)
	cfg.set_value("session", "guest", guest)
	cfg.set_value("session", "logged_in", true)
	cfg.save(PROFILE_PATH)
	Engine.set_meta("blockraft_user", username)
	Engine.set_meta("blockraft_guest", guest)

func _profile_exists(username: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) != OK:
		return false
	return cfg.has_section_key("users", username.to_lower())

func _check_password(username: String, password: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) != OK:
		return false
	var stored := str(cfg.get_value("users", username.to_lower(), ""))
	var h := str(password.hash())
	return stored == h or (stored == "" and password == "")

func _on_login() -> void:
	if _click:
		_click.play()
	var u := _user_edit.text.strip_edges()
	var p := _pass_edit.text
	if u.length() < 2:
		_status.text = "Username must be at least 2 characters"
		return
	if not _profile_exists(u):
		_status.text = "No profile found — Create New Account"
		return
	if not _check_password(u, p):
		_status.text = "Wrong password"
		return
	_status.text = "Welcome, %s!" % u
	_save_session(u, false)
	call_deferred("_go_menu")

func _on_go_register() -> void:
	if _click:
		_click.play()
	var packed := load(REGISTER_SCENE) as PackedScene
	if packed == null:
		_status.text = "Failed to open register page"
		return
	get_tree().change_scene_to_packed(packed)

func _on_guest() -> void:
	if _click:
		_click.play()
	_save_session("Guest", true)
	_status.text = "Playing as Guest..."
	call_deferred("_go_menu")

func _go_menu() -> void:
	var packed := load(MENU_SCENE) as PackedScene
	if packed == null:
		_status.text = "Failed to load main menu"
		return
	get_tree().change_scene_to_packed(packed)
