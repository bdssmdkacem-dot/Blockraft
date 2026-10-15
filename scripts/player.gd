extends CharacterBody3D
const _N := 14
func _ready() -> void:
	if has_meta("_done"): return
	set_meta("_done", true)
	var src := ""
	for i in range(_N):
		var path := "res://scripts/pl_p%d.txt" % i
		if not FileAccess.file_exists(path):
			push_error("Missing " + path); return
		var f := FileAccess.open(path, FileAccess.READ)
		src += f.get_as_text(); f.close()
	var g := GDScript.new()
	g.source_code = src
	if g.reload() != OK:
		push_error("Player reload failed"); return
	set_script(g)
	call_deferred("_ready")
