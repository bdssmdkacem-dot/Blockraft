extends Node
## Realistic day/night + weather system + health/hunger HUD.

enum Weather { CLEAR, CLOUDY, RAIN, STORM, FOG }

const WEATHER_NAMES := {
	Weather.CLEAR: "Clear",
	Weather.CLOUDY: "Cloudy",
	Weather.RAIN: "Rain",
	Weather.STORM: "Storm",
	Weather.FOG: "Fog",
}

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
var weather_label: Label
var night_banner: PanelContainer
var night_label: Label
var hint_label: Label
var settings: Node
var host: Node
var _ui_root: Control
var _dmg_flash: ColorRect
var _top_bar: PanelContainer
var _invuln := 0.0
var weather: int = Weather.CLEAR
var _weather_timer := 45.0
var _weather_blend := 1.0
var _target_weather: int = Weather.CLEAR
var _rain: GPUParticles3D
var _lightning_t := 0.0
var _rng := RandomNumberGenerator.new()

func setup(world: Node, settings_node: Node = null) -> void:
	host = world
	settings = settings_node
	_rng.randomize()
	if settings:
		day_cycle_speed = 0.012 * float(settings.day_speed)
	sun_light = world.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun_light == null:
		sun_light = DirectionalLight3D.new()
		sun_light.name = "DirectionalLight3D"
		sun_light.shadow_enabled = false
		sun_light.light_energy = 1.0
		sun_light.light_color = Color(1.0, 0.95, 0.85)
		world.add_child(sun_light)
	var we = world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		world_env = we.environment
	_setup_rain()
	_build_ui()
	_pick_next_weather(true)
	_update_day_night(0.0)

func is_night() -> bool:
	return day_factor() < 0.18

func day_factor() -> float:
	var angle := time_of_day * TAU - PI * 0.5
	var raw := sin(angle)
	var f := clampf(raw * 0.5 + 0.5, 0.0, 1.0)
	return smoothstep(0.0, 1.0, f)

func _phase_name() -> String:
	var h := time_of_day * 24.0
	if h < 5.0:
		return "Midnight"
	if h < 7.0:
		return "Dawn"
	if h < 11.0:
		return "Morning"
	if h < 14.0:
		return "Noon"
	if h < 17.0:
		return "Afternoon"
	if h < 19.5:
		return "Dusk"
	if h < 22.0:
		return "Evening"
	return "Night"

func _setup_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "RainParticles"
	_rain.amount = 900
	_rain.lifetime = 1.1
	_rain.explosiveness = 0.0
	_rain.randomness = 0.4
	_rain.visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 50, 80))
	_rain.emitting = false
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.12, -1.0, 0.05)
	mat.spread = 8.0
	mat.initial_velocity_min = 12.0
	mat.initial_velocity_max = 18.0
	mat.gravity = Vector3(0, -20, 0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(28, 0.5, 28)
	_rain.process_material = mat
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.35, 0.04)
	var draw := StandardMaterial3D.new()
	draw.albedo_color = Color(0.65, 0.75, 0.95, 0.55)
	draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = draw
	_rain.draw_pass_1 = mesh
	host.add_child(_rain)

func _pick_next_weather(immediate: bool = false) -> void:
	var night := is_night()
	var roll := _rng.randf()
	var next := Weather.CLEAR
	if night:
		if roll < 0.35:
			next = Weather.CLEAR
		elif roll < 0.55:
			next = Weather.CLOUDY
		elif roll < 0.75:
			next = Weather.FOG
		elif roll < 0.9:
			next = Weather.RAIN
		else:
			next = Weather.STORM
	else:
		if roll < 0.40:
			next = Weather.CLEAR
		elif roll < 0.62:
			next = Weather.CLOUDY
		elif roll < 0.80:
			next = Weather.RAIN
		elif roll < 0.90:
			next = Weather.FOG
		else:
			next = Weather.STORM
	_target_weather = next
	_weather_timer = _rng.randf_range(35.0, 90.0)
	if immediate:
		weather = next
		_weather_blend = 1.0
	else:
		_weather_blend = 0.0
		weather = next
		if host and host.has_method("_show_toast"):
			host._show_toast("Weather: %s" % WEATHER_NAMES[weather], 2.2)

func _update_weather(delta: float) -> void:
	_weather_timer -= delta
	_weather_blend = minf(1.0, _weather_blend + delta * 0.35)
	if _weather_timer <= 0.0:
		_pick_next_weather(false)
	var player = host.get_node_or_null("Player") as Node3D
	if _rain and player:
		_rain.global_position = player.global_position + Vector3(0, 18, 0)
	var raining := weather == Weather.RAIN or weather == Weather.STORM
	if _rain:
		_rain.emitting = raining
		_rain.amount = 1400 if weather == Weather.STORM else 900
	_lightning_t = maxf(0.0, _lightning_t - delta)
	if weather == Weather.STORM and _rng.randf() < delta * 0.12:
		_lightning_t = 0.18
		if _dmg_flash:
			_dmg_flash.color = Color(0.85, 0.9, 1.0, 0.45)
			var tw := host.create_tween()
			tw.tween_property(_dmg_flash, "color:a", 0.0, 0.25)

func _weather_sun_mult() -> float:
	match weather:
		Weather.CLEAR:
			return 1.0
		Weather.CLOUDY:
			return 0.55
		Weather.RAIN:
			return 0.35
		Weather.STORM:
			return 0.22
		Weather.FOG:
			return 0.4
	return 1.0

func _weather_fog_add() -> float:
	match weather:
		Weather.CLEAR:
			return 0.0
		Weather.CLOUDY:
			return 0.001
		Weather.RAIN:
			return 0.0025
		Weather.STORM:
			return 0.0035
		Weather.FOG:
			return 0.006
	return 0.0

func _weather_sky_tint() -> Color:
	match weather:
		Weather.CLEAR:
			return Color(1, 1, 1)
		Weather.CLOUDY:
			return Color(0.75, 0.78, 0.82)
		Weather.RAIN:
			return Color(0.55, 0.6, 0.68)
		Weather.STORM:
			return Color(0.35, 0.38, 0.45)
		Weather.FOG:
			return Color(0.7, 0.72, 0.75)
	return Color(1, 1, 1)

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
	weather_label = Label.new()
	weather_label.add_theme_font_size_override("font_size", 13)
	weather_label.add_theme_color_override("font_color", Color("#a8d0e8"))
	top_h.add_child(weather_label)
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
	day_l.text = "DAY / NIGHT / WEATHER"
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
	night_label.text = "NIGHT — animals attack!"
	night_label.add_theme_font_size_override("font_size", 14)
	night_label.add_theme_color_override("font_color", Color("#e8d0ff"))
	night_banner.add_child(night_label)
	hint_label = Label.new()
	hint_label.text = "WASD · dig/place · E eat · F depot · weather changes over time"
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
		hint_label.position = Vector2(vs.x * 0.5 - 240.0, vs.y - 28)

func tick(delta: float) -> void:
	_invuln = maxf(0.0, _invuln - delta)
	_update_day_night(delta)
	_update_weather(delta)
	_update_survival(delta)

func _update_day_night(delta: float) -> void:
	var spd := day_cycle_speed
	if settings:
		spd = 0.012 * float(settings.day_speed)
	if delta > 0.0:
		time_of_day = fmod(time_of_day + spd * delta, 1.0)
	var angle := time_of_day * TAU - PI * 0.5
	var factor := day_factor()
	var night := is_night()
	var wmult := lerpf(1.0, _weather_sun_mult(), _weather_blend)
	var wtint := Color(1, 1, 1).lerp(_weather_sky_tint(), _weather_blend)
	if sun_light:
		sun_light.rotation = Vector3(-angle, 0.55 + sin(time_of_day * TAU) * 0.15, 0.08)
		var day_col := Color(1.0, 0.97, 0.9)
		var dusk_col := Color(1.0, 0.52, 0.25)
		var night_col := Color(0.32, 0.4, 0.72)
		var sun_col := day_col
		if factor < 0.28:
			sun_col = night_col.lerp(dusk_col, clampf(factor / 0.28, 0.0, 1.0))
		elif factor < 0.5:
			sun_col = dusk_col.lerp(day_col, clampf((factor - 0.28) / 0.22, 0.0, 1.0))
		else:
			sun_col = day_col
		sun_light.light_color = sun_col * wtint
		var energy := lerpf(0.05, 1.25, factor * factor)
		if _lightning_t > 0.0:
			energy = maxf(energy, 2.2)
		sun_light.light_energy = energy * wmult
		sun_light.visible = true
	if world_env:
		var sky_day := Color(0.48, 0.7, 0.95)
		var sky_dusk := Color(0.9, 0.42, 0.25)
		var sky_night := Color(0.04, 0.05, 0.12)
		var sky := sky_day
		if factor < 0.25:
			sky = sky_night.lerp(sky_dusk, clampf(factor / 0.25, 0.0, 1.0))
		elif factor < 0.48:
			sky = sky_dusk.lerp(sky_day, clampf((factor - 0.25) / 0.23, 0.0, 1.0))
		else:
			sky = sky_day
		sky = sky * wtint
		world_env.background_color = sky
		world_env.ambient_light_color = sky.lerp(Color(0.78, 0.82, 0.9), factor * 0.7)
		world_env.ambient_light_energy = lerpf(0.15, 0.58, factor) * lerpf(1.0, 0.7, 1.0 - wmult)
		world_env.fog_enabled = true
		world_env.fog_light_color = sky
		var base_fog := lerpf(0.0048, 0.0018, factor)
		world_env.fog_density = base_fog + _weather_fog_add() * _weather_blend
	var hour := int(time_of_day * 24.0) % 24
	var minute := int(fmod(time_of_day * 24.0, 1.0) * 60.0)
	var phase := _phase_name()
	if time_label:
		time_label.text = "%s  %02d:%02d" % [phase, hour, minute]
	if phase_icon:
		phase_icon.text = "C" if night else ("~" if factor < 0.45 else "*")
	if weather_label:
		weather_label.text = "· %s" % WEATHER_NAMES.get(weather, "Clear")
	if phase_detail:
		phase_detail.text = "cycle %.0f%% · light %.0f%%" % [time_of_day * 100.0, factor * 100.0 * wmult]
	if clock_bar:
		clock_bar.value = time_of_day * 100.0
	if night_banner:
		night_banner.visible = night
		if night_label and night:
			night_label.text = "NIGHT — animals attack!  %02d:%02d" % [hour, minute]

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
		_dmg_flash.color = Color(0.8, 0.05, 0.05, 0.4)
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
