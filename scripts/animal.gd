extends CharacterBody3D
## Higher-detail voxel animals with natural wander.

enum Kind { PIG, CHICKEN, COW, SHEEP }

const KIND_DATA := {
	Kind.PIG: {"scale": 0.9, "speed": 3.2, "color_body": Color("#f0a8b4"), "color_spot": Color("#d07080")},
	Kind.CHICKEN: {"scale": 0.58, "speed": 4.0, "color_body": Color("#f5f2e8"), "color_spot": Color("#e84838")},
	Kind.COW: {"scale": 1.15, "speed": 2.6, "color_body": Color("#f8f6f0"), "color_spot": Color("#2c2c2c")},
	Kind.SHEEP: {"scale": 0.95, "speed": 3.0, "color_body": Color("#f5f5f5"), "color_spot": Color("#e8e4dc")},
}

const MAP_LIMIT := 38.0

var kind: int = Kind.PIG
var move_speed := 3.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _dir := Vector3.FORWARD
var _timer := 0.0
var _body_root: Node3D
var _bob := 0.0
var _ready_physics := false

func setup(animal_kind: int, spawn_pos: Vector3) -> void:
	kind = animal_kind
	var data: Dictionary = KIND_DATA[kind]
	move_speed = float(data["speed"])
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(55.0)
	collision_layer = 2
	collision_mask = 1
	_build_mesh(data)
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	var s: float = float(data["scale"])
	shape.radius = 0.25 * s
	shape.height = maxf(0.55 * s, shape.radius * 2.1)
	col.shape = shape
	col.position.y = shape.height * 0.5
	add_child(col)
	global_position = spawn_pos
	var a := randf() * TAU
	_dir = Vector3(cos(a), 0.0, sin(a)).normalized()
	_timer = randf_range(1.5, 3.0)
	call_deferred("_enable_physics")

func _enable_physics() -> void:
	_ready_physics = true
	if is_inside_tree() and get_world_3d():
		var from := global_position + Vector3(0, 2.0, 0)
		var to := global_position + Vector3(0, -8.0, 0)
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.exclude = [self]
		q.collision_mask = 1
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit:
			global_position = hit.position + Vector3(0, 0.05, 0)

func _build_mesh(data: Dictionary) -> void:
	_body_root = Node3D.new()
	add_child(_body_root)
	var s: float = float(data["scale"])
	var body_c: Color = data["color_body"]
	var spot_c: Color = data["color_spot"]
	match kind:
		Kind.CHICKEN:
			_box(_body_root, Vector3(0, 0.32 * s, 0), Vector3(0.38 * s, 0.32 * s, 0.42 * s), body_c)
			_box(_body_root, Vector3(0, 0.52 * s, 0.18 * s), Vector3(0.26 * s, 0.26 * s, 0.26 * s), body_c)
			_box(_body_root, Vector3(0, 0.50 * s, 0.34 * s), Vector3(0.10 * s, 0.08 * s, 0.16 * s), Color("#f0a020"))
			_box(_body_root, Vector3(0, 0.62 * s, 0.12 * s), Vector3(0.12 * s, 0.14 * s, 0.08 * s), spot_c)
			_box(_body_root, Vector3(-0.12 * s, 0.55 * s, 0.22 * s), Vector3(0.06 * s, 0.06 * s, 0.04 * s), Color("#1a1a1a"))
			_box(_body_root, Vector3(0.12 * s, 0.55 * s, 0.22 * s), Vector3(0.06 * s, 0.06 * s, 0.04 * s), Color("#1a1a1a"))
		Kind.COW:
			_box(_body_root, Vector3(0, 0.58 * s, 0), Vector3(0.58 * s, 0.48 * s, 0.90 * s), body_c)
			_box(_body_root, Vector3(0.14 * s, 0.62 * s, 0.12 * s), Vector3(0.22 * s, 0.28 * s, 0.32 * s), spot_c)
			_box(_body_root, Vector3(-0.16 * s, 0.52 * s, -0.18 * s), Vector3(0.24 * s, 0.22 * s, 0.30 * s), spot_c)
			_box(_body_root, Vector3(0, 0.78 * s, 0.52 * s), Vector3(0.36 * s, 0.34 * s, 0.36 * s), body_c)
			_box(_body_root, Vector3(-0.12 * s, 0.88 * s, 0.48 * s), Vector3(0.08 * s, 0.16 * s, 0.08 * s), Color("#f0e8d8"))
			_box(_body_root, Vector3(0.12 * s, 0.88 * s, 0.48 * s), Vector3(0.08 * s, 0.16 * s, 0.08 * s), Color("#f0e8d8"))
		Kind.PIG:
			_box(_body_root, Vector3(0, 0.42 * s, 0), Vector3(0.50 * s, 0.40 * s, 0.70 * s), body_c)
			_box(_body_root, Vector3(0, 0.48 * s, 0.40 * s), Vector3(0.32 * s, 0.28 * s, 0.28 * s), body_c)
			_box(_body_root, Vector3(0, 0.44 * s, 0.58 * s), Vector3(0.14 * s, 0.10 * s, 0.12 * s), spot_c)
			_box(_body_root, Vector3(-0.10 * s, 0.52 * s, 0.48 * s), Vector3(0.06 * s, 0.06 * s, 0.04 * s), Color("#1a1a1a"))
			_box(_body_root, Vector3(0.10 * s, 0.52 * s, 0.48 * s), Vector3(0.06 * s, 0.06 * s, 0.04 * s), Color("#1a1a1a"))
		Kind.SHEEP:
			_box(_body_root, Vector3(0, 0.48 * s, 0), Vector3(0.52 * s, 0.44 * s, 0.72 * s), body_c)
			_box(_body_root, Vector3(0, 0.55 * s, 0.05 * s), Vector3(0.58 * s, 0.20 * s, 0.60 * s), spot_c)
			_box(_body_root, Vector3(0, 0.62 * s, 0.42 * s), Vector3(0.28 * s, 0.28 * s, 0.28 * s), Color("#2a2a2a"))
	# Legs for silhouette and ground feel
	var leg_c := Color("#2a2218") if kind != Kind.CHICKEN else Color("#f0a020")
	var leg_h := 0.22 * s
	var leg_w := 0.08 * s if kind != Kind.CHICKEN else 0.05 * s
	_box(_body_root, Vector3(-0.14 * s, 0.12 * s, 0.16 * s), Vector3(leg_w, leg_h, leg_w), leg_c)
	_box(_body_root, Vector3(0.14 * s, 0.12 * s, 0.16 * s), Vector3(leg_w, leg_h, leg_w), leg_c)
	_box(_body_root, Vector3(-0.14 * s, 0.12 * s, -0.16 * s), Vector3(leg_w, leg_h, leg_w), leg_c)
	_box(_body_root, Vector3(0.14 * s, 0.12 * s, -0.16 * s), Vector3(leg_w, leg_h, leg_w), leg_c)

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, roughness: float = 0.88) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mi.material_override = mat
	parent.add_child(mi)

func _pick_new_direction() -> void:
	var a := randf() * TAU
	_dir = Vector3(cos(a), 0.0, sin(a)).normalized()
	_timer = randf_range(1.4, 3.2)

func _physics_process(delta: float) -> void:
	if not _ready_physics:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	_timer -= delta
	if _timer <= 0.0:
		if randf() < 0.25:
			_dir = Vector3.ZERO
			_timer = randf_range(0.6, 1.4)
		else:
			_pick_new_direction()
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var to_player: Vector3 = global_position - player.global_position
		to_player.y = 0.0
		if to_player.length() < 6.0 and to_player.length() > 0.05:
			_dir = to_player.normalized()
			_timer = maxf(_timer, 0.6)
	if absf(global_position.x) > MAP_LIMIT or absf(global_position.z) > MAP_LIMIT:
		_dir = Vector3(-global_position.x, 0.0, -global_position.z).normalized()
		_timer = 1.5
	if _dir.length() > 0.1 and is_inside_tree() and get_world_3d():
		var space := get_world_3d().direct_space_state
		var ahead := global_position + Vector3(0, 0.4, 0) + _dir * 1.1
		var wall_q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.4, 0), ahead)
		wall_q.exclude = [self]
		wall_q.collision_mask = 1
		if space.intersect_ray(wall_q):
			_pick_new_direction()
		else:
			var ground_q := PhysicsRayQueryParameters3D.create(ahead + Vector3(0, 1.5, 0), ahead + Vector3(0, -2.5, 0))
			ground_q.exclude = [self]
			ground_q.collision_mask = 1
			if not space.intersect_ray(ground_q):
				_pick_new_direction()
	if _dir.length() > 0.1:
		velocity.x = _dir.x * move_speed
		velocity.z = _dir.z * move_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()
	if is_on_wall():
		_pick_new_direction()
	global_position.x = clampf(global_position.x, -MAP_LIMIT - 1.0, MAP_LIMIT + 1.0)
	global_position.z = clampf(global_position.z, -MAP_LIMIT - 1.0, MAP_LIMIT + 1.0)
	if _dir.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-_dir.x, -_dir.z), 1.0 - exp(-10.0 * delta))
		_bob += delta * 12.0
		if _body_root:
			_body_root.position.y = absf(sin(_bob)) * 0.06
	elif _body_root:
		_body_root.position.y = lerpf(_body_root.position.y, 0.0, 1.0 - exp(-6.0 * delta))
