extends Control
## Professional in-app account registration (device-local only).

const LOGIN_SCENE := "res://scenes/login.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const PROFILE_PATH := "user://profile.cfg"

var _user: LineEdit
var _display: LineEdit
var _pass: LineEdit
var _pass2: LineEdit
var _status: Label
var _strength: ProgressBar
var _strength_lab: Label
var _click: AudioStreamPlayer
var _busy := false

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
	bg.color = Color("#071016")
	add_child(bg)
	var brand := PanelContainer.new()
	brand.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	brand.offset_right = 380
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.06, 0.14, 0.11, 0.95)
	brand.add_theme_stylebox_override("panel", bs)
	add_child(brand)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 14)
	brand.add_child(bv)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 80)
	bv.add_child(pad)
	var title := Label.new()
	title.text = "  BLOCKCRAFT"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#f2efe6"))
	bv.add_child(title)
	var tag := Label.new()
	tag.text = "  Create your explorer profile"
	tag.add_theme_font_size_override("font_size", 15)
	tag.add_theme_color_override("font_color", Color("#8fd4a8"))
	bv.add_child(tag)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(280, 2)
	rule.color = Color("#3a8a5a")
	bv.add_child(rule)
	var bullets := [
		"• Registration is in-app only",
		"• Data stays on this device",
		"• No external server required",
		"• Ready for future multiplayer",
	]
	for line in bullets:
		var l := Label.new()
		l.text = "  " + line
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color("#a8c8b8"))
		bv.add_child(l)

func _build_ui() -> void:
	var card := PanelContainer.new()
	card.name = "RegisterCard"
	card.custom_minimum_size = Vector2(460, 560)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-60, -280)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.11, 0.1, 0.98)
	st.border_color = Color("#4ab87a")
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	st.content_margin_left = 32
	st.content_margin_right = 32
	st.content_margin_top = 26
	st.content_margin_bottom = 26
	card.add_theme_stylebox_override("panel", st)
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	card.add_child(v)
	var head := Label.new()
	head.text = "Create New Account"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", Color("#eef8f0"))
	v.add_child(head)
	var sub := Label.new()
	sub.text = "Sign up from the app — local profile"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color("#88a898"))
	v.add_child(sub)
	var step := Label.new()
	step.text = "STEP 1 OF 1  ·  ACCOUNT DETAILS"
	step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step.add_theme_font_size_override("font_size", 11)
	step.add_theme_color_override("font_color", Color("#5ecf8a"))
	v.add_child(step)
	v.add_child(_sep())
	v.add_child(_field_label("Username *"))
	_user = _line("explorer_name", false)
	_user.max_length = 20
	v.add_child(_user)
	v.add_child(_field_label("Display name (optional)"))
	_display = _line("How others see you", false)
	_display.max_length = 24
	v.add_child(_display)
	v.add_child(_field_label("Password (optional, min 4 if set)"))
	_pass = _line("••••••••", true)
	_pass.max_length = 32
	_pass.text_changed.connect(_on_pass_changed)
	v.add_child(_pass)
	var str_row := HBoxContainer.new()
	str_row.add_theme_constant_override("separation", 8)
	v.add_child(str_row)
	_strength = ProgressBar.new()
	_strength.min_value = 0
	_strength.max_value = 100
	_strength.value = 0
	_strength.custom_minimum_size = Vector2(200, 10)
	_strength.show_percentage = false
	str_row.add_child(_strength)
	_strength_lab = Label.new()
	_strength_lab.text = "Strength: —"
	_strength_lab.add_theme_font_size_override("font_size", 11)
	_strength_lab.add_theme_color_override("font_color", Color("#9ab8a8"))
	str_row.add_child(_strength_lab)
	v.add_child(_field_label("Confirm password"))
	_pass2 = _line("••••••••", true)
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
	var back_btn := _btn("← Back to Login", false)
	back_btn.pressed.connect(_on_back)
	v.add_child(back_btn)
	var legal := Label.new()
	legal.text = "By creating an account you agree this profile is stored only on this device for Blockraft."
	legal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legal.add_theme_font_size_override("font_size", 10)
	legal.add_theme_color_override("font_color", Color("#5a7068"))
	legal.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(legal)

func _sep() -> ColorRect:
	var r := ColorRect.new()
	r.custom_minimum_size = Vector2(0, 1)
	r.color = Color(0.3, 0.45, 0.38, 0.5)
	return r

func _field_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color("#b8d4c8"))
	return l

func _line(placeholder: String, secret: bool) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	e.custom_minimum_size = Vector2(0, 42)
	return e

func _btn(caption: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(0, 48)
	var normal := StyleBoxFlat.new()
	var hover := StyleBoxFlat.new()
	if primary:
		normal.bg_color = Color("#2a8f4e")
		hover.bg_color = Color("#36a85c")
		normal.border_color = Color("#7dff9a")
	else:
		normal.bg_color = Color(0.1, 0.14, 0.13, 0.92)
		hover.bg_color = Color(0.15, 0.2, 0.18, 0.96)
		normal.border_color = Color("#4a6a58")
	for s in [normal, hover]:
		s.set_corner_radius_all(10)
		s.set_border_width_all(2)
		s.content_margin_top = 10
		s.content_margin_bottom = 10
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", normal)
	b.add_theme_color_override("font_color", Color("#f0fff4"))
	b.add_theme_font_size_override("font_size", 16)
	return b

func _on_pass_changed(text: String) -> void:
	var score := 0
	if text.length() >= 4:
		score += 25
	if text.length() >= 8:
		score += 25
	var has_num := false
	var has_letter := false
	for i in text.length():
		var c := text[i]
		if c >= "0" and c <= "9":
			has_num = true
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z"):
			has_letter = true
	if has_num:
		score += 25
	if has_letter:
		score += 25
	if text.is_empty():
		score = 0
	_strength.value = score
	if score == 0:
		_strength_lab.text = "Strength: —"
	elif score < 50:
		_strength_lab.text = "Strength: Weak"
	elif score < 75:
		_strength_lab.text = "Strength: Medium"
	else:
		_strength_lab.text = "Strength: Strong"

func _profile_exists(username: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) != OK:
		return false
	return cfg.has_section_key("users", username.to_lower())

func _create_profile(username: String, password: String, display: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PROFILE_PATH)
	cfg.set_value("users", username.to_lower(), str(password.hash()) if password != "" else "")
	if display != "":
		cfg.set_value("display", username.to_lower(), display)
	cfg.set_value("session", "last_user", username)
	cfg.set_value("session", "guest", false)
	cfg.set_value("session", "logged_in", true)
	cfg.set_value("session", "created_at", Time.get_datetime_string_from_system())
	cfg.save(PROFILE_PATH)
	Engine.set_meta("blockraft_user", display if display != "" else username)
	Engine.set_meta("blockraft_guest", false)

func _set_status(msg: String, ok: bool = false) -> void:
	_status.add_theme_color_override("font_color", Color("#7dff9a") if ok else Color("#e8a070"))
	_status.text = msg

func _on_create() -> void:
	if _busy:
		return
	if _click:
		_click.play()
	var u := _user.text.strip_edges()
	var d := _display.text.strip_edges()
	var p := _pass.text
	var p2 := _pass2.text
	if u.length() < 2:
		_set_status("Username must be at least 2 characters")
		return
	if u.length() > 20:
		_set_status("Username is too long")
		return
	for ch in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", "@", "#"]:
		if ch in u:
			_set_status("Username has invalid characters")
			return
	if p != p2:
		_set_status("Passwords do not match")
		return
	if p.length() > 0 and p.length() < 4:
		_set_status("Password must be 4+ characters, or leave empty")
		return
	if _profile_exists(u):
		_set_status("This username is already registered on this device")
		return
	_busy = true
	_create_profile(u, p, d)
	_set_status("Account created successfully — welcome!", true)
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
		_busy = false
		_set_status("Failed to load menu")
		return
	get_tree().change_scene_to_packed(packed)
