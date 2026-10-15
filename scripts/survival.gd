extends Node
## Day/night cycle + health/hunger + redesigned game HUD.

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
var phase_detail: Label
var night_banner: PanelContainer
var night_label: Label
var hint_label: Label
var settings: Node
var host: Node
var _ui_root: Control
var _dmg_flash: ColorRect
var _top_bar: PanelContainer

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

	# === TOP BAR ===
	_top_bar = PanelContainer.new()
	_top_bar.position = Vector2(0, 0)
	var top_st := StyleBoxFlat.new()
	top_st.bg_color = Color(0.03, 0.06, 0.08, 0.88)
	top_st.border_color = Color(0.35, 0.55, 0.42, 0.6)
	top_st.set_border_width_all(0)
	top_st.border_width_bottom = 2
	top_st.content_margin_left = 16
	top_st.content_margin_right = 16
	top_st.content_margin_top = 8
	top_st.content_margin_bottom = 8
	_top_bar.add_theme_stylebox_override("panel", top_st)
	_ui_root.add_child(_top_bar)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 20)
	_top_bar.add_child(top_row)
	var title := Label.new()
	title.text = "BLOCKRAFT"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("#b8f0c8"))
	top_row.add_child(title)
	var sep := Label.new()
	sep.text = "|"
	sep.add_theme_color_override("font_color", Color(0.4, 0.5, 0.45))
	top_row.add_child(sep)
	phase_icon = Label.new()
	phase_icon.text = "☀"
	phase_icon.add_theme_font_size_override("font_size", 22)
	top_row.add_child(phase_icon)
	time_label = Label.new()
	time_label.text = "Day  08:00"
	time_label.add_theme_font_size_override("font_size", 16)
	time_label.add_theme_color_override("font_color", Color("#e8f8f0"))
	top_row.add_child(time_label)
	phase_detail = Label.new()
	phase_detail.text = "day cycle 28%"
	phase_detail.add_theme_font_size_override("font_size", 12)
	phase_detail.add_theme_color_override("font_color", Color(0.7, 0.85, 0.75))
	top_row.add_child(phase_detail)

	# === LEFT STATS CARD ===
	var card := PanelContainer.new()
	card.position = Vector2(14, 52)
	card.custom_minimum_size = Vector2(220, 130)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.04, 0.07, 0.09, 0.86)
	st.border_color = Color(0.45, 0.72, 0.55, 0.95)
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 12
	st.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", st)
	_ui_root.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	card.add_child(v)
	var cycle_title := Label.new()
	cycle_title.text = "DAY / NIGHT CYCLE"
	cycle_title.add_theme_font_size_override("font_size", 10)
	cycle_title.add_theme_color_override("font_color", Color(0.65, 0.8, 0.7))
	v.add_child(cycle_title)
	clock_bar = ProgressBar.new()
	clock_bar.custom_minimum_size = Vector2(190, 10)
	clock_bar.max_value = 1.0
	clock_bar.value = time_of_day
	clock_bar.show_percentage = false
	var clock_bg := StyleBoxFlat.new()
	clock_bg.bg_color = Color(0.08, 0.12, 0.16, 0.95)
	clock_bg.set_corner_radius_all(5)
	var clock_fill := StyleBoxFlat.new()
	clock_fill.bg_color = Color(0.95, 0.78, 0.35, 1.0)
	clock_fill.set_corner_radius_all(5)
	clock_bar.add_theme_stylebox_override("background", clock_bg)
	clock_bar.add_theme_stylebox_override("fill", clock_fill)
	v.add_child(clock_bar)
	health_bar = _make_stat_bar(v, "❤  Health", Color(0.9, 0.28, 0.32), Color(0.35, 0.08, 0.1))
	hunger_bar = _make_stat_bar(v, "🍖  Hunger", Color(0.95, 0.7, 0.28), Color(0.35, 0.25, 0.08))

	# === NIGHT WARNING BANNER (hidden by day) ===
	night_banner = PanelContainer.new()
	night_banner.visible = false
	var nb_st := StyleBoxFlat.new()
	nb_st.bg_color = Color(0.12, 0.05, 0.2, 0.88)
	nb_st.border_color = Color(0.7, 0.35, 0.9, 0.9)
	nb_st.set_border_width_all(2)
	nb_st.set_corner_radius_all(10)
	nb_st.content_margin_left = 14
	nb_st.content_margin_right = 14
	nb_st.content_margin_top = 8
	nb_st.content_margin_bottom = 8
	night_banner.add_theme_stylebox_override("panel", nb_st)
	_ui_root.add_child(night_banner)
	night_label = Label.new()
	night_label.text = "☾  NIGHT — chickens, pigs & cows attack!"
	night_label.add_theme_font_size_override("font_size", 14)
	night_label.add_theme_color_override("font_color", Color(0.95, 0.85, 1.0))
	night_banner.add_child(night_label)

	# === BOTTOM HINTS ===
	hint_label = Label.new()
	hint_label.text = "WASD move  ·  Mouse look  ·  LMB dig/attack  ·  RMB place  ·  E eat  ·  B bag  ·  night = danger"
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.88, 0.8))
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
	hl.add_theme_font_size_override("font_size", 12)
	hl.add_theme_color_override("font_color", Color("#d8e8e0"))
	parent.add_child(hl)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(190, 14)
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = bg_c
	bg.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_c
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar

func _layout_hints() -> void:
	if host == null:
		return
	var vs := host.get_viewport().get_visible_rect().size
	if _top_bar:
		_top_bar.custom_minimum_size = Vector2(vs.x, 42)
		_top_bar.size = Vector2(vs.x, 42)
	if hint_label:
		hint_label.position = Vector2(20, vs.y - 28)
		hint_label.size = Vector2(vs.x - 40, 24)
	if night_banner:
		night_banner.position = Vector2(vs.x * 0.5 - 200.0, 56)
		night_banner.custom_minimum_size = Vector2(400, 36)

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
	if time_label:
		time_label.text = "%s  %02d:00" % [phase, hour]
	if phase_icon:
		phase_icon.text = icon
	if phase_detail:
		phase_detail.text = "cycle %.0f%%  ·  sun %.0f%%" % [time_of_day * 100.0, day_f * 100.0]
	if clock_bar:
		clock_bar.value = time_of_day
		var fill := StyleBoxFlat.new()
		fill.set_corner_radius_all(5)
		if day_f < 0.2:
			fill.bg_color = Color(0.35, 0.4, 0.85)
		elif day_f < 0.45:
			fill.bg_color = Color(0.95, 0.7, 0.35)
		elif day_f < 0.85:
			fill.bg_color = Color(0.95, 0.85, 0.35)
		else:
			fill.bg_color = Color(0.9, 0.45, 0.3)
		clock_bar.add_theme_stylebox_override("fill", fill)
	if night_banner:
		night_banner.visible = is_night()

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
