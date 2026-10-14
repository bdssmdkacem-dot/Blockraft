extends CharacterBody3D
## Simple voxel animal: wander, idle, slight flee from player.

enum Kind { PIG, CHICKEN, COW, SHEEP }

const KIND_DATA := {
	Kind.PIG: {"scale": 0.85, "speed": 2.8, "color_body": Color("#e8a0b0"), "color_spot": Color("#c87888")},
	Kind.CHICKEN: {"scale": 0.55, "speed": 3.4, "color_body": Color("#f0f0e8"), "color_spot": Color("#e05040")},
	Kind.COW: {"scale": 1.1, "speed": 2.2, "color_body": Color("#f5f5f0"), "color_spot": Color("#2a2a2a")},
	Kind.SHEEP: {"scale": 0.9, "speed": 2.5, "color_body": Color("#f2f2f2"), "color_spot": Color("#d8d8d0")},
}

var kind: int = Kind.PIG
var move_speed := 2.5
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _dir := Vector3.ZERO
var _timer := 0.0
var _body_root: Node3D
var _bob := 0.0

func setup(animal_kind: int, spawn_pos: Vector3) -> void:
	kind = animal_kind
	var data: Dictionary = KIND_DATA[kind]
	move_speed = float(data["speed"])
	global_position = spawn_pos
	_build_mesh(data)
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28 * float(data["scale"])
	shape.height = 0.7 * float(data["scale"])
	col.shape = shape
	col.position.y = shape.height * 0.5
	add_child(col)

func _build_mesh(data: Dictionary) -> void:
	_body_root = Node3D.new()
	add_child(_body_root)
	var s: float = float(data["scale"])
	var body_c: Color = data["color_body"]
	var spot_c: Color = data["color_spot"]
	match kind:
		Kind.CHICKEN:
			_box(_body_root, Vector3(0, 0.35 * s, 0), Vector3(0.35 * s, 0.35 * s, 0.4 * s), body_c)
			_box(_body_root, Vector3(0, 0.55 * s, 0.22 * s), Vector3(0.28 * s, 0.28 * s, 0.28 * s), body_c)
			_box(_body_root, Vector3(0, 0.55 * s, 0.38 * s), Vector3(0.1 * s, 0.08 * s, 0.16 * s), spot_c)
			_box(_body_root, Vector3(0, 0.48 * s, -0.2 * s), Vector3(0.08 * s, 0.2 * s, 0.25 * s), Color("#e05040"))
		Kind.COW:
			_box(_body_root, Vector3(0, 0.55 * s, 0), Vector3(0.55 * s, 0.45 * s, 0.85 * s), body_c)
			_box(_body_root, Vector3(0.12 * s, 0.6 * s, 0.1 * s), Vector3(0.2 * s, 0.25 * s, 0.3 * s), spot_c)
			_box(_body_root, Vector3(-0.15 * s, 0.5 * s, -0.15 * s), Vector3(0.22 * s, 0.2 * s, 0.28 * s), spot_c)
			_box(_body_root, Vector3(0, 0.75 * s, 0.5 * s), Vector3(0.35 * s, 0.32 * s, 0.35 * s), body_c)
			for leg in [Vector3(-0.18, 0.18, 0.25), Vector3(0.18, 0.18, 0.25), Vector3(-0.18, 0.18, -0.28), Vector3(0.18, 0.18, -0.28)]:
				_box(_body_root, leg * s, Vector3(0.12 * s, 0.36 * s, 0.12 * s), Color("#2a2a2a"))
		Kind.SHEEP:
			_box(_body_root, Vector3(0, 0.5 * s, 0), Vector3(0.55 * s, 0.5 * s, 0.7 * s), body_c)
			_box(_body_root, Vector3(0, 0.7 * s, 0.4 * s), Vector3(0.32 * s, 0.28 * s, 0.32 * s), Color("#2a2a2a"))
			for leg in [Vector3(-0.16, 0.16, 0.22), Vector3(0.16, 0.16, 0.22), Vector3(-0.16, 0.16, -0.22), Vector3(0.16, 0.16, -0.22)]:
				_box(_body_root, leg * s, Vector3(0.1 * s, 0.32 * s, 0.1 * s), Color("#2a2a2a"))
		_:
			_box(_body_root, Vector3(0, 0.4 * s, 0), Vector3(0.5 * s, 0.4 * s, 0.7 * s), body_c)
			_box(_body_root, Vector3(0, 0.45 * s, 0.4 * s), Vector3(0.32 * s, 0.28 * s, 0.28 * s), body_c)
			_box(_body_root, Vector3(0, 0.42 * s, 0.55 * s), Vector3(0.14 * s, 0.1 * s, 0.12 * s), spot_c)
			for leg in [Vector3(-0.15, 0.14, 0.2), Vector3(0.15, 0.14, 0.2), Vector3(-0.15, 0.14, -0.22), Vector3(0.15, 0.14, -0.22)]:
				_box(_body_root, leg * s, Vector3(0.1 * s, 0.28 * s, 0.1 * s), Color("#c87888"))

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mi.material_override = mat
	parent.add_child(mi)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(1.2, 3.5)
		if randf() < 0.35:
			_dir = Vector3.ZERO
		else:
			var a := randf() * TAU
			_dir = Vector3(cos(a), 0, sin(a))
	var player := get_tree().get_first_node_in_group("player")
	if player and global_position.distance_to(player.global_position) < 5.0:
		var away := global_position - player.global_position
		away.y = 0
		if away.length() > 0.1:
			_dir = away.normalized()
			_timer = 0.8
	velocity.x = _dir.x * move_speed
	velocity.z = _dir.z * move_speed
	move_and_slide()
	if _dir.length() > 0.1:
		var target_yaw := atan2(-_dir.x, -_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-8.0 * delta))
		_bob += delta * 10.0
		if _body_root:
			_body_root.position.y = absf(sin(_bob)) * 0.04
	elif _body_root:
		_body_root.position.y = lerpf(_body_root.position.y, 0.0, 1.0 - exp(-6.0 * delta))
