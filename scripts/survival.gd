extends Node
## Day/night cycle + health/hunger + polished HUD.

var time_of_day := 0.28
var day_cycle_speed := 0.012
var health := 100.0
var hunger := 100.0
var sun_light: DirectionalLight3D
var world_env: Environment
var health_bar: ProgressBar
var hunger_bar: ProgressBar
var time_label: Label
var phase_icon: Label
var clock_bar: ProgressBar
var hint_label: Label
var settings: Node
var host: Node
var _ui_root: Control
var _dmg_flash: ColorRect

func setup(world: Node, settings_node: Node = null) -> void:
	host = world
	settings = settings_node
	if settings:
		day_cycle_speed = 0.012 * float(settings.day_speed)
	sun_light = world.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	var we = world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		world_env = we.environment
	_build_ui()

func is_night() -> bool:
	var angle := time_of_day * TAU - PI * 0.5
	return sin(angle) < 0.15

func day_factor() -> float:
	var angle := time_of_day * TAU - PI * 0.5
	return clampf(sin(angle) * 0.5 + 0.5, 0.0, 1.0)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 8
	layer.name = "GameHUD"
	host.add_child(layer)
	_ui_root = Control.new()
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui_root)
	var card := PanelContainer.new()
	card.position = Vector2(14, 12)
	card.custom_minimum_size = Vector2(210, 118)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.04, 0.07, 0.09, 0.82)
	st.border_color = Color(0.45, 0.72, 0.55, 0.9)
	st.set_border_width_all(2)
	st.set_corner_radius_all(12)
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", st)
	_ui_root.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	phase_icon = Label.new()
	phase_icon.text = "☀"
	phase_icon.add_theme_font_size_override("font_size", 20)
	row.add_child(phase_icon)
	time_label = Label.new()
	time_label.text = "Day  08:00"
	time_label.add_theme_font_size_override("font_size", 15)
	time_label.add_theme_color_override("font_color", Color("#e8f8f0"))
	row.add_child(time_label)
	clock_bar = ProgressBar.new()
	clock_bar.custom_minimum_size = Vector2(180, 8)
	clock_bar.max_value = 1.0
	clock_bar.value = time_of_day
	clock_bar.show_percentage = false
	var clock_bg := StyleBoxFlat.new()
	clock_bg.bg_color = Color(0.1, 0.14, 0.18, 0.9)
	clock_bg.set_corner_radius_all(4)
	var clock_fill := StyleBoxFlat.new()
	clock_fill.bg_color = Color(0.95, 0.78, 0.35, 1.0)
	clock_fill.set_corner_radius_all(4)
	clock_bar.add_theme_stylebox_override("background", clock_bg)
	clock_bar.add_theme_stylebox_override("fill", clock_fill)
	v.add_child(clock_bar)
	health_bar = _make_stat_bar(v, "❤  Health", Color(0.85, 0.25, 0.28), Color(0.45, 0.1, 0.12))
	hunger_bar = _make_stat_bar(v, "🍖  Hunger", Color(0.9, 0.65, 0.25), Color(0.4, 0.28, 0.08))
	hint_label = Label.new()
	hint_label.text = "WASD move  ·  Mouse look  ·  LMB dig/attack  ·  RMB place  ·  E eat  ·  B bag"
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.88, 0.75))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui_root.add_child(hint_label)
	_layout_hints()
	host.get_viewport().size_changed.connect(_layout_hints)
	_dmg_flash = ColorRect.new()
	_dmg_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dmg_flash.color = Color(0.7, 0.05, 0.05, 0.0)
	_dmg_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_dmg_flash)

func _make_stat_bar(parent: Control, title: String, fill_c: Color, bg_c: Color) -> ProgressBar:
	var hl := Label.new()
	hl.text = title
	hl.add_theme_font_size_override("font_size", 11)
	hl.add_theme_color_override("font_color", Color("#d8e8e0"))
	parent.add_child(hl)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(180, 12)
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = bg_c
	bg.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_c
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar

func _layout_hints() -> void:
	if hint_label == null:
		return
	var vs := host.get_viewport().get_visible_rect().size
	hint_label.position = Vector2(20, vs.y - 28)
	hint_label.size = Vector2(vs.x - 40, 24)

func tick(delta: float) -> void:
	_update_day_night(delta)
	_update_survival(delta)

func _update_day_night(delta: float) -> void:
	var spd := day_cycle_speed
	if settings:
		spd = 0.012 * float(settings.day_speed)
	time_of_day = fmod(time_of_day + spd * delta, 1.0)
	var angle := time_of_day * TAU - PI * 0.5
	var sun_h := sin(angle)
	var day_f := clampf(sun_h * 0.5 + 0.5, 0.0, 1.0)
	if sun_light:
		sun_light.rotation = Vector3(-angle, -0.6, 0.0)
		sun_light.light_energy = lerpf(0.08, 1.35, day_f)
		var noon := Color(1.0, 0.98, 0.92)
		var warm := Color(1.0, 0.72, 0.45)
		var cool := Color(0.55, 0.65, 0.95)
		if day_f > 0.55:
			sun_light.light_color = noon.lerp(warm, 0.25)
		elif day_f > 0.2:
			sun_light.light_color = cool.lerp(noon, (day_f - 0.2) / 0.35)
		else:
			sun_light.light_color = cool
	if world_env:
		var day_sky := Color(0.55, 0.72, 0.92)
		var dusk_sky := Color(0.85, 0.45, 0.35)
		var night_sky := Color(0.05, 0.07, 0.14)
		if day_f > 0.45:
			world_env.background_color = day_sky
		elif day_f > 0.15:
			world_env.background_color = night_sky.lerp(dusk_sky, clampf((day_f - 0.15) / 0.3, 0, 1))
		else:
			world_env.background_color = night_sky
		world_env.ambient_light_energy = lerpf(0.12, 0.6, day_f)
		world_env.fog_light_color = world_env.background_color
	if time_label:
		var hour := int(time_of_day * 24.0) % 24
		var phase := "Night"
		var icon := "☾"
		if day_f > 0.85:
			phase = "Dusk"
			icon = "🌤"
		elif day_f > 0.45:
			phase = "Day"
			icon = "☀"
		elif day_f > 0.2:
			phase = "Dawn"
			icon = "🌤"
		time_label.text = "%s  %02d:00" % [phase, hour]
		if phase_icon:
			phase_icon.text = icon
	if clock_bar:
		clock_bar.value = time_of_day

func _update_survival(delta: float) -> void:
	hunger = maxf(0.0, hunger - delta * 0.55)
	if hunger <= 0.0:
		health = maxf(0.0, health - delta * 2.2)
	elif hunger > 70.0 and health < 100.0:
		health = minf(100.0, health + delta * 1.5)
	if health_bar:
		health_bar.value = health
	if hunger_bar:
		hunger_bar.value = hunger
	if health <= 0.0:
		_on_starve()

func apply_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	if health_bar:
		health_bar.value = health
	if _dmg_flash:
		_dmg_flash.color.a = 0.35
		var tw := host.create_tween()
		tw.tween_property(_dmg_flash, "color:a", 0.0, 0.35)
	if health <= 0.0:
		_on_starve()

func _on_starve() -> void:
	health = 100.0
	hunger = 60.0
	if host and host.has_method("_snap_player_to_surface"):
		host._snap_player_to_surface()
	if host and host.get("player"):
		host.player.velocity = Vector3.ZERO
	if host and host.has_method("_show_toast"):
		host._show_toast("You collapsed — returned to camp", 3.5)

func try_eat() -> void:
	if host == null or host.get("inventory") == null:
		return
	var inv = host.inventory
	if inv.has_method("count_of") and inv.has_method("_remove_amount"):
		if inv.count_of("meat") >= 1:
			inv._remove_amount("meat", 1)
			hunger = minf(100.0, hunger + 40.0)
			health = minf(100.0, health + 12.0)
			host._show_toast("Ate meat (+hunger +hp)", 1.5)
			inv.counts_changed.emit()
			return
		if inv.count_of("grass") >= 4:
			inv._remove_amount("grass", 4)
			hunger = minf(100.0, hunger + 18.0)
			host._show_toast("Foraged plants (+hunger)", 1.5)
			inv.counts_changed.emit()
			return
		if inv.count_of("leaves") >= 6:
			inv._remove_amount("leaves", 6)
			hunger = minf(100.0, hunger + 14.0)
			host._show_toast("Ate leaves (+hunger)", 1.5)
			inv.counts_changed.emit()
			return
	host._show_toast("Need food — forage or hunt animals", 2.0)
