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
var _invuln := 0.0

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
	_top_bar = PanelContainer.new()
	_top_bar.position = Vector2(0, 0)
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.05, 0.07, 0.1, 0.82)
	_top_bar.add_theme_stylebox_override("panel", top_style)
	_ui_root.add_child(_top_bar)
	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 12)
	_top_bar.add_child(top_h)
	var title := Label.new()
	title.text = "BLOCKRAFT"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#e8f5d8"))
	top_h.add_child(title)
	phase_icon = Label.new()
	phase_icon.add_theme_font_size_override("font_size", 16)
	top_h.add_child(phase_icon)
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 14)
	time_label.add_theme_color_override("font_color", Color("#c8e0f0"))
	top_h.add_child(time_label)
	phase_detail = Label.new()
	phase_detail.add_theme_font_size_override("font_size", 12)
	phase_detail.add_theme_color_override("font_color", Color("#9ab0c0"))
	top_h.add_child(phase_detail)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 48)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.08, 0.1, 0.88)
	ps.set_corner_radius_all(10)
	ps.content_margin_left = 10
	ps.content_margin_right = 10
	ps.content_margin_top = 8
	ps.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", ps)
	_ui_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var day_l := Label.new()
	day_l.text = "DAY / NIGHT CYCLE"
	day_l.add_theme_font_size_override("font_size", 11)
	day_l.add_theme_color_override("font_color", Color("#a0c0d0"))
	v.add_child(day_l)
	clock_bar = ProgressBar.new()
	clock_bar.min_value = 0
	clock_bar.max_value = 100
	clock_bar.value = 50
	clock_bar.custom_minimum_size = Vector2(160, 12)
	clock_bar.show_percentage = false
	v.add_child(clock_bar)
	var hl := Label.new()
	hl.text = "Health"
	hl.add_theme_font_size_override("font_size", 12)
	hl.add_theme_color_override("font_color", Color("#f0a0a0"))
	v.add_child(hl)
	health_bar = ProgressBar.new()
	health_bar.min_value = 0
	health_bar.max_value = 100
	health_bar.value = 100
	health_bar.custom_minimum_size = Vector2(160, 14)
	health_bar.show_percentage = false
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(0.75, 0.18, 0.18)
	hs.set_corner_radius_all(4)
	health_bar.add_theme_stylebox_override("fill", hs)
	v.add_child(health_bar)
	var hul := Label.new()
	hul.text = "Hunger"
	hul.add_theme_font_size_override("font_size", 12)
	hul.add_theme_color_override("font_color", Color("#f0c080"))
	v.add_child(hul)
	hunger_bar = ProgressBar.new()
	hunger_bar.min_value = 0
	hunger_bar.max_value = 100
	hunger_bar.value = 100
	hunger_bar.custom_minimum_size = Vector2(160, 14)
	hunger_bar.show_percentage = false
	var hus := StyleBoxFlat.new()
	hus.bg_color = Color(0.85, 0.55, 0.12)
	hus.set_corner_radius_all(4)
	hunger_bar.add_theme_stylebox_override("fill", hus)
	v.add_child(hunger_bar)
	night_banner = PanelContainer.new()
	night_banner.visible = false
	var ns := StyleBoxFlat.new()
	ns.bg_color = Color(0.25, 0.1, 0.35, 0.9)
	ns.set_corner_radius_all(12)
	ns.content_margin_left = 14
	ns.content_margin_right = 14
	ns.content_margin_top = 8
	ns.content_margin_bottom = 8
	night_banner.add_theme_stylebox_override("panel", ns)
	_ui_root.add_child(night_banner)
	night_label = Label.new()
	night_label.text = "NIGHT — chickens, foxes & cows attack!"
	night_label.add_theme_font_size_override("font_size", 14)
	night_label.add_theme_color_override("font_color", Color("#e8d0ff"))
	night_banner.add_child(night_label)
	hint_label = Label.new()
	hint_label.text = "WASD move · Mouse look · LMB dig/attack · RMB place · E eat · B bag"
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_ui_root.add_child(hint_label)
	_dmg_flash = ColorRect.new()
	_dmg_flash.color = Color(0.8, 0.05, 0.05, 0.0)
	_dmg_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dmg_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_dmg_flash)
	_layout_ui()
	host.get_viewport().size_changed.connect(_layout_ui)

func _layout_ui() -> void:
	var vs := host.get_viewport().get_visible_rect().size
	if _top_bar:
		_top_bar.custom_minimum_size = Vector2(vs.x, 36)
	if night_banner:
		night_banner.position = Vector2(vs.x * 0.5 - 180.0, 52)
	if hint_label:
		hint_label.position = Vector2(vs.x * 0.5 - 220.0, vs.y - 28)

func tick(delta: float) -> void:
	_invuln = maxf(0.0, _invuln - delta)
	_update_day_night(delta)
	_update_survival(delta)

func _update_day_night(delta: float) -> void:
	var spd := day_cycle_speed
	if settings:
		spd = 0.012 * float(settings.day_speed)
	time_of_day = fmod(time_of_day + spd * delta, 1.0)
	var angle := time_of_day * TAU - PI * 0.5
	var factor := day_factor()
	if sun_light:
		sun_light.rotation = Vector3(-angle, 0.4, 0.15)
		sun_light.light_energy = lerpf(0.08, 1.15, factor)
		sun_light.light_color = Color(1.0, 0.95, 0.85).lerp(Color(0.35, 0.4, 0.7), 1.0 - factor)
	if world_env:
		world_env.background_color = Color(0.55, 0.72, 0.92).lerp(Color(0.08, 0.1, 0.2), 1.0 - factor)
		world_env.ambient_light_energy = lerpf(0.25, 0.6, factor)
	var hour := int(time_of_day * 24.0)
	var minute := int(fmod(time_of_day * 24.0, 1.0) * 60.0)
	var night := is_night()
	if time_label:
		time_label.text = "%s %02d:%02d" % ["Night" if night else "Day", hour, minute]
	if phase_icon:
		phase_icon.text = "C" if night else "*"
	if phase_detail:
		phase_detail.text = "cycle %.0f%% · sun %.0f%%" % [time_of_day * 100.0, factor * 100.0]
	if clock_bar:
		clock_bar.value = time_of_day * 100.0
	if night_banner:
		night_banner.visible = night

func _update_survival(delta: float) -> void:
	hunger = maxf(0.0, hunger - delta * 0.8)
	if hunger <= 0.0:
		health = maxf(0.0, health - delta * 2.5)
	elif hunger > 70.0 and health < 100.0:
		health = minf(100.0, health + delta * 1.2)
	if health_bar:
		health_bar.value = health
	if hunger_bar:
		hunger_bar.value = hunger
	if health <= 0.0:
		_on_starve()

func try_eat() -> void:
	if host and host.get("inventory") and host.inventory.has_method("consume_food"):
		if host.inventory.consume_food():
			hunger = minf(100.0, hunger + 35.0)
			if host.has_method("_show_toast"):
				host._show_toast("Ate meat +hunger", 1.2)
			return
	if host and host.has_method("_show_toast"):
		host._show_toast("No food — hunt animals for meat", 1.5)

func apply_damage(amount: float) -> void:
	if _invuln > 0.0:
		return
	health = maxf(0.0, health - amount)
	_invuln = 0.55
	if health_bar:
		health_bar.value = health
	if _dmg_flash:
		_dmg_flash.color.a = 0.4
		var tw := host.create_tween()
		tw.tween_property(_dmg_flash, "color:a", 0.0, 0.4)
	if health <= 0.0:
		_on_starve()

func _on_starve() -> void:
	health = 100.0
	hunger = 60.0
	if host and host.has_method("_snap_player_to_surface"):
		host._snap_player_to_surface()
	if host and host.has_method("_show_toast"):
		host._show_toast("You were defeated — respawned", 2.5)
