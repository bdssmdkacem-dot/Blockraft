extends CharacterBody3D
## Voxel animals — wander, flee when hurt, night aggression, meat drops.

enum Kind { PIG, CHICKEN, COW, SHEEP }

const KIND_DATA := {
	Kind.PIG: {"scale": 0.9, "speed": 3.2, "hp": 18.0, "dmg": 4.0, "color_body": Color("#f0a8b4"), "color_spot": Color("#d07080")},
	Kind.CHICKEN: {"scale": 0.58, "speed": 4.0, "hp": 8.0, "dmg": 1.0, "color_body": Color("#f5f2e8"), "color_spot": Color("#e84838")},
	Kind.COW: {"scale": 1.15, "speed": 2.6, "hp": 28.0, "dmg": 6.0, "color_body": Color("#f8f6f0"), "color_spot": Color("#2c2c2c")},
	Kind.SHEEP: {"scale": 0.95, "speed": 3.0, "hp": 16.0, "dmg": 2.0, "color_body": Color("#f5f5f5"), "color_spot": Color("#e8e4dc")},
}

const MAP_LIMIT := 38.0

var kind: int = Kind.PIG
var move_speed := 3.0
var max_hp := 16.0
var hp := 16.0
var attack_damage := 2.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _dir := Vector3.FORWARD
var _timer := 0.0
var _body_root: Node3D
var _bob := 0.0
var _ready_physics := false
var _flee_t := 0.0
var _attack_cd := 0.0
var _hurt_flash := 0.0

func setup(animal_kind: int, spawn_pos: Vector3) -> void:
	kind = animal_kind
	var data: Dictionary = KIND_DATA[kind]
	move_speed = float(data["speed"])
	max_hp = float(data["hp"])
	hp = max_hp
	attack_damage = float(data["dmg"])
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(55.0)
	collision_layer = 4
	collision_mask = 1
	add_to_group("animals")
	add_to_group("hittable")
	_build_mesh(data)
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	var s: float = float(data["scale"])
	shape.radius = 0.28 * s
	shape.height = maxf(0.55 * s, shape.radius * 2.1)
	col.shape = shape
	col.position.y = shape.height * 0.5
	add_child(col)
	global_position = spawn_pos
	var a := randf() * TAU
	_dir = Vector3(cos(a), 0.0, sin(a)).normalized()
	_timer = randf_range(1.5, 3.0)
	call_deferred("_enable_physics")

func take_damage(amount: float, from_pos: Vector3 = Vector3.ZERO) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	_hurt_flash = 0.4
	_flee_t = 2.2
	if from_pos != Vector3.ZERO:
		var away := global_position - from_pos
		away.y = 0.0
		if away.length() > 0.05:
			_dir = away.normalized()
	if hp <= 0.0:
		_die()

func _die() -> void:
	var player_node = get_tree().get_first_node_in_group("player")
	var world = player_node.get_parent() if player_node else null
	if world and world.get("inventory") and world.inventory.has_method("add_block"):
		world.inventory.add_block("meat", 1 if kind == Kind.CHICKEN else 2)
		if world.has_method("_show_toast"):
			world._show_toast("+meat from hunt", 1.4)
		if world.get("mining_fx") and world.mining_fx.has_method("play_hit"):
			world.mining_fx.play_hit(global_position)
	queue_free()

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
		Kind.COW:
			_box(_body_root, Vector3(0, 0.58 * s, 0), Vector3(0.58 * s, 0.48 * s, 0.90 * s), body_c)
			_box(_body_root, Vector3(0.14 * s, 0.62 * s, 0.12 * s), Vector3(0.22 * s, 0.28 * s, 0.32 * s), spot_c)
			_box(_body_root, Vector3(0, 0.78 * s, 0.52 * s), Vector3(0.36 * s, 0.34 * s, 0.36 * s), body_c)
		Kind.PIG:
			_box(_body_root, Vector3(0, 0.42 * s, 0), Vector3(0.50 * s, 0.40 * s, 0.70 * s), body_c)
			_box(_body_root, Vector3(0, 0.48 * s, 0.40 * s), Vector3(0.32 * s, 0.28 * s, 0.28 * s), body_c)
			_box(_body_root, Vector3(0, 0.44 * s, 0.58 * s), Vector3(0.14 * s, 0.10 * s, 0.12 * s), spot_c)
		Kind.SHEEP:
			_box(_body_root, Vector3(0, 0.48 * s, 0), Vector3(0.52 * s, 0.44 * s, 0.72 * s), body_c)
			_box(_body_root, Vector3(0, 0.55 * s, 0.05 * s), Vector3(0.58 * s, 0.20 * s, 0.60 * s), spot_c)
			_box(_body_root, Vector3(0, 0.62 * s, 0.42 * s), Vector3(0.28 * s, 0.28 * s, 0.28 * s), Color("#2a2a2a"))
	var leg_c := Color("#2a2218") if kind != Kind.CHICKEN else Color("#f0a020")
	var leg_h := 0.22 * s
	var leg_w := 0.08 * s if kind != Kind.CHICKEN else 0.05 * s
	for p in [Vector3(-0.14, 0.12, 0.16), Vector3(0.14, 0.12, 0.16), Vector3(-0.14, 0.12, -0.16), Vector3(0.14, 0.12, -0.16)]:
		_box(_body_root, p * s, Vector3(leg_w, leg_h, leg_w), leg_c)

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
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_flee_t = maxf(0.0, _flee_t - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var night := false
	var surv = null
	if player and player.get_parent():
		surv = player.get_parent().get_node_or_null("Survival")
		if surv and surv.has_method("is_night"):
			night = surv.is_night()
	var speed := move_speed
	if _flee_t > 0.0:
		speed = move_speed * 1.7
	elif player:
		var to_p: Vector3 = global_position - player.global_position
		to_p.y = 0.0
		var dist := to_p.length()
		if dist < 6.0 and dist > 0.05 and not night:
			_dir = to_p.normalized()
			_timer = maxf(_timer, 0.5)
		if night and dist < 5.0 and kind in [Kind.PIG, Kind.COW]:
			_dir = player.global_position - global_position
			_dir.y = 0.0
			if _dir.length() > 0.05:
				_dir = _dir.normalized()
			speed = move_speed * 1.25
			if dist < 1.6 and _attack_cd <= 0.0:
				_attack_cd = 1.2
				if surv and surv.has_method("apply_damage"):
					surv.apply_damage(attack_damage)
					if player.get_parent().has_method("_show_toast"):
						player.get_parent()._show_toast("Hit by animal! -%.0f hp" % attack_damage, 1.0)
	_timer -= delta
	if _timer <= 0.0 and _flee_t <= 0.0:
		if randf() < 0.25:
			_dir = Vector3.ZERO
			_timer = randf_range(0.6, 1.4)
		else:
			_pick_new_direction()
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
		velocity.x = _dir.x * speed
		velocity.z = _dir.z * speed
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
