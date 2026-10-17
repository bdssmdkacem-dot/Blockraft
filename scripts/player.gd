extends CharacterBody3D
const _N := 12
func _ready() -> void:
	if has_meta("ok"):
		return
	set_meta("ok", true)
	var src := ""
	for i in range(_N):
		var path := "res://scripts/s%d.txt" % i
		if not FileAccess.file_exists(path):
			push_error("Missing " + path)
			return
		var f := FileAccess.open(path, FileAccess.READ)
		src += f.get_as_text()
		f.close()
	var g := GDScript.new()
	g.source_code = src
	if g.reload() != OK:
		push_error("Player reload failed")
		return
	set_script(g)
	call_deferred("_ready")
