extends SceneTree
## Load every project GDScript resource and fail CI if Godot reports a parse error.
## Godot's editor import command can log parser errors while still exiting with code 0.

const SCRIPT_DIRECTORIES := [
	"res://scripts",
	"res://tests",
	"res://tools",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	for directory_path in SCRIPT_DIRECTORIES:
		_scan_directory(directory_path, failures)

	if not failures.is_empty():
		for script_path in failures:
			push_error("SCRIPT_PARSE_ACCEPTANCE_FAIL: " + script_path)
		quit(1)
		return

	print("SCRIPT_PARSE_ACCEPTANCE_PASS: all project GDScript files loaded successfully")
	quit(0)

func _scan_directory(directory_path: String, failures: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		failures.append("Could not open script directory: " + directory_path)
		return

	directory.list_dir_begin()
	while true:
		var entry := directory.get_next()
		if entry.is_empty():
			break
		if entry == "." or entry == "..":
			continue

		var entry_path := directory_path.path_join(entry)
		if directory.current_is_dir():
			_scan_directory(entry_path, failures)
		elif entry.get_extension().to_lower() == "gd":
			var script_resource = load(entry_path)
			if script_resource == null:
				failures.append(entry_path + " (load returned null)")
			elif not script_resource is GDScript:
				failures.append(entry_path + " (resource is not a GDScript)")
			elif not (script_resource as GDScript).can_instantiate():
				# load() can return a GDScript resource even after the parser has
				# reported an error. A non-instantiable resource must fail CI.
				failures.append(entry_path + " (GDScript cannot instantiate; parse/base error)")
	directory.list_dir_end()
