extends Node
## Persistent player preferences (sensitivity + audio + day cycle).

const PATH := "user://settings.cfg"

var look_sensitivity := 1.0
var master_volume := 0.85
var day_speed := 1.0

func _ready() -> void:
	load_settings()
	apply_audio()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	look_sensitivity = float(cfg.get_value("controls", "look_sensitivity", 1.0))
	master_volume = float(cfg.get_value("audio", "master_volume", 0.85))
	day_speed = float(cfg.get_value("world", "day_speed", 1.0))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "look_sensitivity", look_sensitivity)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("world", "day_speed", day_speed)
	cfg.save(PATH)

func apply_audio() -> void:
	var db := linear_to_db(clampf(master_volume, 0.001, 1.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
