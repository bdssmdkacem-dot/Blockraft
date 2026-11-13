extends SceneTree
## Ensure the app icon is configured, importable, and suitable for launcher use.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var icon_path := str(ProjectSettings.get_setting("application/config/icon", ""))
	if icon_path.is_empty():
		_fail("application/config/icon is not configured")
		return
	if not ResourceLoader.exists(icon_path):
		_fail("configured icon resource does not exist: " + icon_path)
		return

	var icon_resource = load(icon_path)
	if not icon_resource is Texture2D:
		_fail("configured icon did not import as a Texture2D: " + icon_path)
		return

	var icon_texture := icon_resource as Texture2D
	if icon_texture.get_width() < 256 or icon_texture.get_height() < 256:
		_fail("launcher icon must be at least 256x256 pixels")
		return
	if icon_texture.get_width() != icon_texture.get_height():
		_fail("launcher icon must be square")
		return

	print("PROJECT_ICON_ACCEPTANCE_PASS: configured square launcher icon imported at %dx%d" % [icon_texture.get_width(), icon_texture.get_height()])
	quit(0)

func _fail(message: String) -> void:
	push_error("PROJECT_ICON_ACCEPTANCE_FAIL: " + message)
	quit(1)
