extends CharacterBody3D
## Combat animals: chicken/fox aggressive, cow night-only, sheep peaceful.

enum Kind { FOX, CHICKEN, COW, SHEEP }
enum State { WANDER, CHASE, ATTACK, FLEE, HURT }

const KIND_DATA := {
	Kind.FOX: {
		"scale": 0.85, "speed": 4.4, "hp": 18.0, "dmg": 6.0,
		"aggro": 10.0, "hit_range": 1.8, "attack_cd": 0.85,
		"color_body": Color("#c46828"), "color_spot": Color("#f0e8e0")
	},
	Kind.CHICKEN: {
		"scale": 0.65, "speed": 5.2, "hp": 14.0, "dmg": 5.0,
		"aggro": 11.0, "hit_range": 2.0, "attack_cd": 0.65,
		"color_body": Color("#f5f2e8"), "color_spot": Color("#e84838")
	},
	Kind.COW: {
		"scale": 1.15, "speed": 2.8, "hp": 32.0, "dmg": 8.0,
		"aggro": 7.0, "hit_range": 2.1, "attack_cd": 1.1,
		"color_body": Color("#f8f6f0"), "color_spot": Color("#2c2c2c")
	},
	Kind.SHEEP: {
		"scale": 0.95, "speed": 3.2, "hp": 16.0, "dmg": 0.0,
		"aggro": 0.0, "hit_range": 0.0, "attack_cd": 1.0,
		"color_body": Color("#f5f5f5"), "color_spot": Color("#e8e4dc")
	},
}

const MAP_LIMIT := 38.0
const AGGRESSIVE_KINDS := [Kind.FOX, Kind.CHICKEN, Kind.COW]

var kind: int = Kind.CHICKEN
var move_speed := 3.0
var max_hp := 16.0
var hp := 16.0
var attack_damage := 2.0
var aggro_range := 8.0
var hit_range := 1.8
var attack_interval := 0.8
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _dir := Vector3.FORWARD
var _timer := 0.0
var _body_root: Node3D
var _bob := 0.0
var _ready_physics := false
var _flee_t := 0.0
var _attack_cd := 0.0
var _hurt_flash := 0.0
var _state: int = State.WANDER
var _knockback := Vector3.ZERO
var _hp_bar: MeshInstance3D
var _hp_bg: MeshInstance3D

func setup(animal_kind: int, spawn_pos: Vector3) -> void:
	kind = animal_kind
	var data: Dictionary = KIND_DATA[kind]
	move_speed = float(data["speed"])
	max_hp = float(data["hp"])
	hp = max_hp
	attack_damage = float(data["dmg"])
	aggro_range = float(data["aggro"])
	hit_range = float(data["hit_range"])
	attack_interval = float(data["attack_cd"])
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(55.0)
	collision_layer = 4
	collision_mask = 1
	add_to_group("animals")
	add_to_group("hittable")
	_build_mesh(data)
	_build_hp_bar()
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
	_hurt_flash = 0.6
	_state = State.HURT
	if from_pos != Vector3.ZERO:
		var away := global_position - from_pos
		away.y = 0.0
		if away.length() > 0.05:
			_knockback = away.normalized() * 6.5
			_dir = away.normalized()
	if kind == Kind.SHEEP:
		_flee_t = 2.5
		_state = State.FLEE
	else:
		_flee_t = 0.15
		_state = State.CHASE
		if from_pos != Vector3.ZERO:
			var toward := from_pos - global_position
			toward.y = 0.0
			if toward.length() > 0.05:
				_dir = toward.normalized()
	_update_hp_bar()
	if hp <= 0.0:
		_die()

func _die() -> void:
	var player_node = get_tree().get_first_node_in_group("player")
	var world = player_node.get_parent() if player_node else null
	if world and world.get("inventory") and world.inventory.has_method("add_block"):
		var meat_amt := 1
		if kind == Kind.COW:
			meat_amt = 3
		elif kind == Kind.FOX or kind == Kind.SHEEP:
			meat_amt = 2
		world.inventory.add_block("meat", meat_amt)
		if world.has_method("_show_toast"):
			var names := {Kind.FOX: "Fox", Kind.CHICKEN: "Chicken", Kind.COW: "Cow", Kind.SHEEP: "Sheep"}
			world._show_toast("%s down! +%d meat" % [names.get(kind, "Animal"), meat_amt], 1.6)
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

func _build_hp_bar() -> void:
	_hp_bg = MeshInstance3D.new()
	var bg := BoxMesh.new()
	bg.size = Vector3(0.7, 0.08, 0.04)
	_hp_bg.mesh = bg
	_hp_bg.position = Vector3(0, 1.35, 0)
	var bgm := StandardMaterial3D.new()
	bgm.albedo_color = Color(0.1, 0.1, 0.1, 0.85)
	bgm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hp_bg.material_override = bgm
	_hp_bg.visible = false
	add_child(_hp_bg)
	_hp_bar = MeshInstance3D.new()
	var fg := BoxMesh.new()
	fg.size = Vector3(0.66, 0.06, 0.05)
	_hp_bar.mesh = fg
	_hp_bar.position = Vector3(0, 1.35, 0.01)
	var fgm := StandardMaterial3D.new()
	fgm.albedo_color = Color(0.2, 0.85, 0.25)
	_hp_bar.material_override = fgm
	_hp_bar.visible = false
	add_child(_hp_bar)

func _update_hp_bar() -> void:
	if _hp_bar == null:
		return
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	_hp_bar.visible = hp < max_hp and hp > 0.0
	_hp_bg.visible = _hp_bar.visible
	_hp_bar.scale = Vector3(maxf(ratio, 0.05), 1.0, 1.0)
	_hp_bar.position.x = -0.33 * (1.0 - ratio)
	var mat := _hp_bar.material_override as StandardMaterial3D
	if mat:
		if ratio > 0.5:
			mat.albedo_color = Color(0.25, 0.9, 0.3)
		elif ratio > 0.25:
			mat.albedo_color = Color(0.95, 0.75, 0.15)
		else:
			mat.albedo_color = Color(0.95, 0.2, 0.15)

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mi.material_override = mat
	parent.add_child(mi)

func _build_mesh(data: Dictionary) -> void:
	_body_root = Node3D.new()
	add_child(_body_root)
	var s: float = float(data["scale"])
	var body_c: Color = data["color_body"]
	var spot_c: Color = data["color_spot"]
	match kind:
		Kind.CHICKEN:
			_box(_body_root, Vector3(0, 0.32 * s, 0), Vector3(0.40 * s, 0.34 * s, 0.48 * s), body_c)
			_box(_body_root, Vector3(0, 0.52 * s, 0.18 * s), Vector3(0.28 * s, 0.26 * s, 0.28 * s), body_c)
			_box(_body_root, Vector3(0, 0.48 * s, 0.34 * s), Vector3(0.10 * s, 0.08 * s, 0.18 * s), spot_c)
			_box(_body_root, Vector3(0, 0.62 * s, 0.12 * s), Vector3(0.08 * s, 0.16 * s, 0.08 * s), spot_c)
			_box(_body_root, Vector3(-0.12 * s, 0.12 * s, 0), Vector3(0.08 * s, 0.22 * s, 0.08 * s), Color("#e8c040"))
			_box(_body_root, Vector3(0.12 * s, 0.12 * s, 0), Vector3(0.08 * s, 0.22 * s, 0.08 * s), Color("#e8c040"))
		Kind.FOX:
			_box(_body_root, Vector3(0, 0.35 * s, 0), Vector3(0.42 * s, 0.32 * s, 0.70 * s), body_c)
			_box(_body_root, Vector3(0, 0.48 * s, 0.32 * s), Vector3(0.30 * s, 0.28 * s, 0.30 * s), body_c)
			_box(_body_root, Vector3(0, 0.38 * s, -0.42 * s), Vector3(0.14 * s, 0.16 * s, 0.36 * s), body_c)
			_box(_body_root, Vector3(0, 0.38 * s, -0.58 * s), Vector3(0.12 * s, 0.12 * s, 0.12 * s), spot_c)
			_box(_body_root, Vector3(-0.12 * s, 0.12 * s, 0.15 * s), Vector3(0.10 * s, 0.24 * s, 0.10 * s), body_c)
			_box(_body_root, Vector3(0.12 * s, 0.12 * s, 0.15 * s), Vector3(0.10 * s, 0.24 * s, 0.10 * s), body_c)
		Kind.COW:
			_box(_body_root, Vector3(0, 0.55 * s, 0), Vector3(0.55 * s, 0.45 * s, 0.85 * s), body_c)
			_box(_body_root, Vector3(0.12 * s, 0.55 * s, 0.1 * s), Vector3(0.22 * s, 0.35 * s, 0.30 * s), spot_c)
			_box(_body_root, Vector3(0, 0.70 * s, 0.48 * s), Vector3(0.36 * s, 0.32 * s, 0.32 * s), body_c)
			_box(_body_root, Vector3(-0.18 * s, 0.20 * s, 0.25 * s), Vector3(0.12 * s, 0.40 * s, 0.12 * s), body_c)
			_box(_body_root, Vector3(0.18 * s, 0.20 * s, 0.25 * s), Vector3(0.12 * s, 0.40 * s, 0.12 * s), body_c)
			_box(_body_root, Vector3(-0.18 * s, 0.20 * s, -0.25 * s), Vector3(0.12 * s, 0.40 * s, 0.12 * s), body_c)
			_box(_body_root, Vector3(0.18 * s, 0.20 * s, -0.25 * s), Vector3(0.12 * s, 0.40 * s, 0.12 * s), body_c)
		Kind.SHEEP:
			_box(_body_root, Vector3(0, 0.42 * s, 0), Vector3(0.50 * s, 0.42 * s, 0.65 * s), body_c)
			_box(_body_root, Vector3(0, 0.55 * s, 0.38 * s), Vector3(0.28 * s, 0.26 * s, 0.28 * s), Color("#2a2a2a"))
			_box(_body_root, Vector3(-0.14 * s, 0.16 * s, 0.18 * s), Vector3(0.10 * s, 0.28 * s, 0.10 * s), Color("#2a2a2a"))
			_box(_body_root, Vector3(0.14 * s, 0.16 * s, 0.18 * s), Vector3(0.10 * s, 0.28 * s, 0.10 * s), Color("#2a2a2a"))
			_box(_body_root, Vector3(-0.14 * s, 0.16 * s, -0.18 * s), Vector3(0.10 * s, 0.28 * s, 0.10 * s), Color("#2a2a2a"))
			_box(_body_root, Vector3(0.14 * s, 0.16 * s, -0.18 * s), Vector3(0.10 * s, 0.28 * s, 0.10 * s), Color("#2a2a2a"))

func _pick_new_direction() -> void:
	var a := randf() * TAU
	_dir = Vector3(cos(a), 0.0, sin(a)).normalized()
	_timer = randf_range(1.2, 3.0)
	_state = State.WANDER

func _is_night() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and player.get_parent():
		var surv = player.get_parent().get_node_or_null("Survival")
		if surv and surv.has_method("is_night"):
			return surv.is_night()
	return false

func _should_aggro(night: bool) -> bool:
	if kind == Kind.SHEEP:
		return false
	if kind == Kind.CHICKEN or kind == Kind.FOX:
		return true
	if kind == Kind.COW:
		return night
	return false

func _physics_process(delta: float) -> void:
	if not _ready_physics:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_flee_t = maxf(0.0, _flee_t - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	if _knockback.length() > 0.05:
		velocity.x = _knockback.x
		velocity.z = _knockback.z
		_knockback = _knockback.move_toward(Vector3.ZERO, 18.0 * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	if _body_root:
		var flash := _hurt_flash > 0.0
		for child in _body_root.get_children():
			if child is MeshInstance3D and child.material_override is StandardMaterial3D:
				var m: StandardMaterial3D = child.material_override
				m.emission_enabled = flash
				if flash:
					m.emission = Color(1.0, 0.2, 0.15)
					m.emission_energy_multiplier = 0.8 * (_hurt_flash / 0.6)
				else:
					m.emission_energy_multiplier = 0.0
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var night := _is_night()
	var speed := move_speed
	if player and _knockback.length() < 0.5:
		var to_p: Vector3 = player.global_position - global_position
		to_p.y = 0.0
		var dist := to_p.length()
		if kind == Kind.SHEEP and dist < 7.0 and dist > 0.05:
			_dir = -to_p.normalized()
			_state = State.FLEE
			speed = move_speed * 1.6
			_timer = maxf(_timer, 0.4)
		elif _should_aggro(night) and dist < aggro_range:
			_state = State.CHASE
			_dir = to_p.normalized()
			speed = move_speed * (1.55 if kind == Kind.CHICKEN else 1.35)
			if dist < hit_range and _attack_cd <= 0.0:
				_state = State.ATTACK
				_attack_cd = attack_interval
				_do_attack(player, dist)
		elif _flee_t > 0.0 and kind != Kind.CHICKEN:
			_state = State.FLEE
			speed = move_speed * 1.7
	_timer -= delta
	if _timer <= 0.0 and _state == State.WANDER and _flee_t <= 0.0:
		if randf() < 0.25:
			_dir = Vector3.ZERO
			_timer = randf_range(0.6, 1.4)
		else:
			_pick_new_direction()
	if absf(global_position.x) > MAP_LIMIT or absf(global_position.z) > MAP_LIMIT:
		_dir = Vector3(-global_position.x, 0.0, -global_position.z).normalized()
		_timer = 1.5
	if _dir.length() > 0.1 and is_inside_tree() and get_world_3d() and _knockback.length() < 0.5:
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
	if _knockback.length() < 0.5:
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

func _do_attack(player: Node3D, _dist: float) -> void:
	var surv = null
	if player.get_parent():
		surv = player.get_parent().get_node_or_null("Survival")
	if surv and surv.has_method("apply_damage"):
		surv.apply_damage(attack_damage)
	var toward := player.global_position - global_position
	toward.y = 0.0
	if toward.length() > 0.05:
		_knockback = toward.normalized() * 3.0
	var world = player.get_parent()
	if world and world.has_method("_show_toast"):
		var msg := "Attacked! -%.0f" % attack_damage
		if kind == Kind.CHICKEN:
			msg = "Chicken peck! -%.0f" % attack_damage
		elif kind == Kind.FOX:
			msg = "Fox bite! -%.0f" % attack_damage
		elif kind == Kind.COW:
			msg = "Cow charge! -%.0f" % attack_damage
		world._show_toast(msg, 1.0)
	if world and world.get("mining_fx") and world.mining_fx.has_method("play_hit"):
		world.mining_fx.play_hit(global_position)
