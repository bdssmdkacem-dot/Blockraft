extends Node
## Day/night cycle + health/hunger survival loop.

var time_of_day := 0.28
var day_cycle_speed := 0.012
var health := 100.0
var hunger := 100.0
var sun_light: DirectionalLight3D
var world_env: Environment
var health_bar: ProgressBar
var hunger_bar: ProgressBar
var time_label: Label
var settings: Node
var host: Node

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

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	layer.name = "SurvivalUI"
	host.add_child(layer)
	var bars := VBoxContainer.new()
	bars.position = Vector2(16, 130)
	bars.add_theme_constant_override("separation", 4)
	layer.add_child(bars)
	var hl := Label.new()
	hl.text = "❤ Health"
	hl.add_theme_font_size_override("font_size", 12)
	hl.add_theme_color_override("font_color", Color("#ffb0b0"))
	bars.add_child(hl)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(160, 14)
	health_bar.max_value = 100
	health_bar.value = health
	health_bar.show_percentage = false
	bars.add_child(health_bar)
	var hul := Label.new()
	hul.text = "🍖 Hunger"
	hul.add_theme_font_size_override("font_size", 12)
	hul.add_theme_color_override("font_color", Color("#ffd090"))
	bars.add_child(hul)
	hunger_bar = ProgressBar.new()
	hunger_bar.custom_minimum_size = Vector2(160, 14)
	hunger_bar.max_value = 100
	hunger_bar.value = hunger
	hunger_bar.show_percentage = false
	bars.add_child(hunger_bar)
	time_label = Label.new()
	time_label.position = Vector2(16, 210)
	time_label.add_theme_font_size_override("font_size", 13)
	time_label.add_theme_color_override("font_color", Color("#e8f0ff"))
	layer.add_child(time_label)
	var eat_hint := Label.new()
	eat_hint.text = "E = Eat / forage"
	eat_hint.position = Vector2(16, 230)
	eat_hint.add_theme_font_size_override("font_size", 11)
	eat_hint.add_theme_color_override("font_color", Color("#a8c8b0"))
	layer.add_child(eat_hint)

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
		var warm := Color(1.0, 0.72, 0.45)
		var noon := Color(1.0, 0.98, 0.92)
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
		if day_f > 0.85: phase = "Dusk"
		elif day_f > 0.45: phase = "Day"
		elif day_f > 0.2: phase = "Dawn"
		time_label.text = "%s  %02d:00" % [phase, hour]

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

func _on_starve() -> void:
	health = 100.0
	hunger = 60.0
	if host and host.has_method("_snap_player_to_surface"):
		host._snap_player_to_surface()
	if host and host.get("player"):
		host.player.velocity = Vector3.ZERO
	if host and host.has_method("_show_toast"):
		host._show_toast("You collapsed from hunger — rest and eat!", 3.5)

func try_eat() -> void:
	if host == null or host.get("inventory") == null:
		return
	var inv = host.inventory
	if inv.has_method("count_of") and inv.has_method("_remove_amount"):
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
	host._show_toast("Need food — forage grass/leaves", 2.0)
