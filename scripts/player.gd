extends CharacterBody3D
## Assembles player from scripts/rp0..rp5.txt
const _N := 6
func _ready() -> void:
	if has_meta("ok"):
		return
	set_meta("ok", true)
	var src := ""
	for i in range(_N):
		var path := "res://scripts/rp%d.txt" % i
		if not FileAccess.file_exists(path):
			push_error("Missing " + path)
			return
		var f := FileAccess.open(path, FileAccess.READ)
		src += f.get_as_text()
		f.close()
	if not src.begins_with("extends"):
		push_error("Bad player source")
		return
	var g := GDScript.new()
	g.source_code = src
	if g.reload() != OK:
		push_error("Player reload failed")
		return
	set_script(g)
	call_deferred("_ready")
