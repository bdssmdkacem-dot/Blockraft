extends CharacterBody3D
## Third-person voxel player — movement, dig, place, combat.

const SPEED := 7.4
const SPRINT_MULT := 1.45
const ACCEL := 32.0
const DECEL := 40.0
const AIR_ACCEL := 14.0
const AIR_DRAG := 0.35
const JUMP_VELOCITY := 8.6
const JUMP_CUT_MULT := 0.45
const FALL_GRAVITY_MULT := 1.35
const MAX_FALL_SPEED := 28.0
const SLOPE_BOOST := 1.08
const LAND_HARD_SPEED := 12.0
const REACH := 7.0
const CAMERA_SENSITIVITY := 0.0022
const TOUCH_LOOK_SENSITIVITY := 0.0036
const TOUCH_LOOK_SMOOTH := 0.28
const TOUCH_JOY_RADIUS := 92.0
const TOUCH_JOY_DEADZONE := 0.08
const TOUCH_MOVE_SMOOTH := 14.0
const CAMERA_DISTANCE := 4.2
const CAMERA_MIN_PITCH := deg_to_rad(-55.0)
const CAMERA_MAX_PITCH := deg_to_rad(25.0)
const LOOK_SMOOTH := 18.0
const CAM_FOLLOW := 14.0

const MAT_SKIN := Color("#f0c4a0")
const MAT_TEAL := Color("#2bb8a8")
const MAT_BLUE := Color("#2f4f8a")
const MAT_HAIR := Color("#5a3218")
const MAT_BOOT := Color("#1e1a18")
const MAT_PACK := Color("#7a4a22")
const MAT_PACK_FLAP := Color("#9a6230")
const MAT_DIAMOND := Color("#6af0f5")
const MAT_HANDLE := Color("#8b5a2b")

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera: Camera3D
var yaw := 0.0
var pitch := deg_to_rad(-18.0)
var touch_controls_enabled := false
var touch_move := Vector2.ZERO
var _touch_move_target := Vector2.ZERO
var _yaw_target := 0.0
var _pitch_target := deg_to_rad(-18.0)
var _cam_pos := Vector3.ZERO
var _cam_ready := false
var touch_jump_pressed := false
var joystick_active := false
var joystick_origin := Vector2.ZERO
var joystick_touch_index := -1
var look_touch_index := -1
var _look_accum := Vector2.ZERO
var _joy_base_ui: Control = null
var _joy_knob_ui: Control = null
var _action_column: Control = null
var _touch_root: Control = null
var _mine_held := false
var _mine_cooldown := 0.0
var coyote_time := 0.0
var jump_buffer := 0.0
var _jump_held := false
var _fall_speed_peak := 0.0
var body_root: Node3D
var pickaxe_node: Node3D
var pickaxe_swing_t := 0.0
var walk_phase := 0.0
var footstep_player: AudioStreamPlayer3D
var footstep_stream: AudioStreamWAV
var _last_step_sign := 0
var _step_cooldown := 0.0
var _was_on_floor := true
var _land_squash := 0.0
var _jump_stretch := 0.0
var leg_l_pivot: Node3D
var leg_r_pivot: Node3D
var arm_l_pivot: Node3D
var arm_r_pivot: Node3D
var torso_node: Node3D
var head_node: Node3D
var jump_player: AudioStreamPlayer3D
var land_player: AudioStreamPlayer3D
var _look_sens_mult := 1.0

func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 0.55
	floor_max_angle = deg_to_rad(55.0)
	floor_constant_speed = true
	floor_block_on_wall = true
	floor_stop_on_slope = false
	safe_margin = 0.08
	max_slides = 6
	up_direction = Vector3.UP
	motion_mode = MOTION_MODE_GROUNDED
	collision_layer = 2
	collision_mask = 1
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.35
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	_build_character_body()
	_build_third_person_camera()
	_init_footsteps()
	_yaw_target = yaw
	_pitch_target = pitch
	var snode = load("res://scripts/settings.gd").new()
	snode.load_settings()
	_look_sens_mult = float(snode.look_sensitivity)
	snode.apply_audio()
	touch_controls_enabled = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	if touch_controls_enabled:
		_build_touch_controls()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _material(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, roughness: float = 0.85) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _material(color, roughness)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

func _build_character_body() -> void:
	body_root = Node3D.new()
	body_root.name = "VoxelBody"
	add_child(body_root)
	leg_l_pivot = Node3D.new()
	leg_l_pivot.position = Vector3(-0.17, 0.85, 0.0)
	body_root.add_child(leg_l_pivot)
	_box(leg_l_pivot, Vector3(0.0, -0.36, 0.0), Vector3(0.30, 0.72, 0.28), MAT_BLUE)
	_box(leg_l_pivot, Vector3(0.0, -0.78, 0.08), Vector3(0.32, 0.18, 0.40), MAT_BOOT)
	leg_r_pivot = Node3D.new()
	leg_r_pivot.position = Vector3(0.17, 0.85, 0.0)
	body_root.add_child(leg_r_pivot)
	_box(leg_r_pivot, Vector3(0.0, -0.36, 0.0), Vector3(0.30, 0.72, 0.28), MAT_BLUE)
	_box(leg_r_pivot, Vector3(0.0, -0.78, 0.08), Vector3(0.32, 0.18, 0.40), MAT_BOOT)
	torso_node = Node3D.new()
	torso_node.position = Vector3(0.0, 1.12, 0.0)
	body_root.add_child(torso_node)
	_box(torso_node, Vector3(0.0, 0.0, 0.0), Vector3(0.78, 0.72, 0.42), MAT_TEAL)
	_box(torso_node, Vector3(0.0, 0.06, -0.36), Vector3(0.62, 0.68, 0.28), MAT_PACK)
	arm_l_pivot = Node3D.new()
	arm_l_pivot.position = Vector3(-0.52, 1.40, 0.0)
	body_root.add_child(arm_l_pivot)
	_box(arm_l_pivot, Vector3(0.0, -0.32, 0.0), Vector3(0.26, 0.64, 0.26), MAT_SKIN)
	arm_r_pivot = Node3D.new()
	arm_r_pivot.position = Vector3(0.52, 1.40, 0.0)
	body_root.add_child(arm_r_pivot)
	_box(arm_r_pivot, Vector3(0.0, -0.32, 0.0), Vector3(0.26, 0.64, 0.26), MAT_SKIN)
	head_node = Node3D.new()
	head_node.position = Vector3(0.0, 1.78, 0.0)
	body_root.add_child(head_node)
	_box(head_node, Vector3(0.0, 0.0, 0.0), Vector3(0.56, 0.56, 0.54), MAT_SKIN)
	_box(head_node, Vector3(0.0, 0.30, -0.02), Vector3(0.60, 0.20, 0.58), MAT_HAIR)
	pickaxe_node = Node3D.new()
	pickaxe_node.position = Vector3(0.12, -0.55, 0.15)
	pickaxe_node.rotation_degrees = Vector3(10.0, 0.0, -25.0)
	arm_r_pivot.add_child(pickaxe_node)
	_box(pickaxe_node, Vector3(0.0, 0.0, 0.0), Vector3(0.07, 0.90, 0.07), MAT_HANDLE)
	_box(pickaxe_node, Vector3(0.0, 0.52, 0.0), Vector3(0.52, 0.14, 0.13), MAT_DIAMOND, 0.25)

func _build_third_person_camera() -> void:
	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.fov = 70.0
	add_child(camera)
	camera.make_current()
	_update_camera_transform(0.016)

func _update_camera_transform(delta: float = 0.016) -> void:
	if camera == null: return
	var pivot := global_position + Vector3(0.0, 1.35, 0.0)
	yaw = lerp_angle(yaw, _yaw_target, 1.0 - exp(-LOOK_SMOOTH * delta))
	pitch = lerpf(pitch, _pitch_target, 1.0 - exp(-LOOK_SMOOTH * delta))
	pitch = clampf(pitch, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var desired := pivot + basis * Vector3(0.0, 0.0, CAMERA_DISTANCE)
	var dist := CAMERA_DISTANCE
	if is_inside_tree() and get_world_3d():
		var query := PhysicsRayQueryParameters3D.create(pivot, desired)
		query.exclude = [self]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit: dist = clampf(pivot.distance_to(hit.position) - 0.25, 1.2, CAMERA_DISTANCE)
	var target_cam := pivot + basis * Vector3(0.0, 0.0, dist)
	if not _cam_ready:
		_cam_pos = target_cam
		_cam_ready = true
	else:
		_cam_pos = _cam_pos.lerp(target_cam, 1.0 - exp(-CAM_FOLLOW * delta))
	camera.global_position = _cam_pos
	camera.look_at(pivot, Vector3.UP)

func _build_touch_controls() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_touch_root = Control.new()
	_touch_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_touch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_touch_root)
	_joy_base_ui = Panel.new()
	_joy_base_ui.size = Vector2(TOUCH_JOY_RADIUS * 2.0, TOUCH_JOY_RADIUS * 2.0)
	_joy_base_ui.visible = false
	_touch_root.add_child(_joy_base_ui)
	_joy_knob_ui = Panel.new()
	_joy_knob_ui.size = Vector2(64, 64)
	_joy_base_ui.add_child(_joy_knob_ui)
	_action_column = VBoxContainer.new()
	_action_column.add_theme_constant_override("separation", 14)
	_touch_root.add_child(_action_column)
	var jump := Button.new()
	jump.text = "⬆ JUMP"
	jump.custom_minimum_size = Vector2(150, 68)
	jump.button_down.connect(func(): touch_jump_pressed = true; jump_buffer = 0.18)
	jump.button_up.connect(func(): touch_jump_pressed = false)
	_action_column.add_child(jump)
	var mine := Button.new()
	mine.text = "⛏ MINE"
	mine.custom_minimum_size = Vector2(150, 64)
	mine.button_down.connect(func(): _mine_held = true; _interact(false))
	mine.button_up.connect(func(): _mine_held = false)
	_action_column.add_child(mine)
	var place := Button.new()
	place.text = "🧱 PLACE"
	place.custom_minimum_size = Vector2(150, 64)
	place.pressed.connect(_interact.bind(true))
	_action_column.add_child(place)
	_layout_touch()
	get_viewport().size_changed.connect(_layout_touch)

func _layout_touch() -> void:
	if _action_column == null: return
	var vs := get_viewport().get_visible_rect().size
	_action_column.position = Vector2(vs.x - 190.0, vs.y - 270.0)

func _input(event: InputEvent) -> void:
	if not touch_controls_enabled: return
	var vs := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if touch.position.x < vs.x * 0.5:
				joystick_active = true
				joystick_touch_index = touch.index
				joystick_origin = touch.position
			else:
				look_touch_index = touch.index
		else:
			if touch.index == joystick_touch_index:
				joystick_active = false
				joystick_touch_index = -1
				_touch_move_target = Vector2.ZERO
			if touch.index == look_touch_index:
				look_touch_index = -1
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == joystick_touch_index and joystick_active:
			var delta := drag.position - joystick_origin
			if delta.length() > TOUCH_JOY_RADIUS:
				delta = delta.normalized() * TOUCH_JOY_RADIUS
			var raw := Vector2(delta.x / TOUCH_JOY_RADIUS, delta.y / TOUCH_JOY_RADIUS)
			if raw.length() < TOUCH_JOY_DEADZONE:
				_touch_move_target = Vector2.ZERO
			else:
				var len_v := raw.length()
				_touch_move_target = raw.normalized() * clampf((len_v - TOUCH_JOY_DEADZONE) / (1.0 - TOUCH_JOY_DEADZONE), 0.0, 1.0)
		elif drag.index == look_touch_index or (look_touch_index < 0 and drag.position.x >= vs.x * 0.5):
			_look_accum += drag.relative
			var look := _look_accum * TOUCH_LOOK_SMOOTH
			_look_accum *= (1.0 - TOUCH_LOOK_SMOOTH)
			_yaw_target -= look.x * TOUCH_LOOK_SENSITIVITY * _look_sens_mult
			_pitch_target = clampf(_pitch_target - look.y * TOUCH_LOOK_SENSITIVITY * _look_sens_mult, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			var wb = get_parent()
			if wb and wb.get("inventory") and wb.inventory.has_method("try_upgrade"):
				wb.inventory.try_upgrade()
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var w = get_parent()
			if w and w.get("inventory"):
				w.inventory.select(event.keycode - KEY_1)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var wu = get_parent()
			if wu and wu.get("inventory"): wu.inventory.cycle(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var wd = get_parent()
			if wd and wd.get("inventory"): wd.inventory.cycle(1)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw_target -= event.relative.x * CAMERA_SENSITIVITY * _look_sens_mult
		_pitch_target = clampf(_pitch_target - event.relative.y * CAMERA_SENSITIVITY * _look_sens_mult, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_interact(false)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_interact(true)

func _init_footsteps() -> void:
	footstep_player = AudioStreamPlayer3D.new()
	add_child(footstep_player)
	jump_player = AudioStreamPlayer3D.new()
	add_child(jump_player)
	land_player = AudioStreamPlayer3D.new()
	add_child(land_player)

func _physics_process(delta: float) -> void:
	if camera == null: return
	_update_camera_transform(delta)
	if _mine_held:
		_mine_cooldown -= delta
		if _mine_cooldown <= 0.0:
			_mine_cooldown = 0.28
			_interact(false)
	else:
		_mine_cooldown = 0.0
	touch_move = touch_move.lerp(_touch_move_target, 1.0 - exp(-TOUCH_MOVE_SMOOTH * delta))
	var want_jump := Input.is_key_pressed(KEY_SPACE) or touch_jump_pressed
	if is_on_floor():
		coyote_time = 0.15
		_fall_speed_peak = 0.0
		if velocity.y < 0.0: velocity.y = 0.0
	else:
		coyote_time = maxf(0.0, coyote_time - delta)
		var g := gravity
		if velocity.y < 0.0:
			g *= FALL_GRAVITY_MULT
			_fall_speed_peak = maxf(_fall_speed_peak, -velocity.y)
		elif not want_jump and _jump_held:
			velocity.y *= JUMP_CUT_MULT
			_jump_held = false
		velocity.y -= g * delta
		velocity.y = maxf(velocity.y, -MAX_FALL_SPEED)
	if want_jump: jump_buffer = 0.16
	else: jump_buffer = maxf(0.0, jump_buffer - delta)
	if jump_buffer > 0.0 and coyote_time > 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer = 0.0
		coyote_time = 0.0
		touch_jump_pressed = false
		_jump_held = true
		_jump_stretch = 1.0
	var input_dir := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	) + touch_move
	input_dir = input_dir.limit_length(1.0)
	var basis := Basis(Vector3.UP, yaw)
	var direction := basis * Vector3(input_dir.x, 0.0, input_dir.y)
	if direction.length() > 0.001: direction = direction.normalized()
	var wish := direction
	if is_on_floor() and get_floor_normal().y > 0.4 and direction.length() > 0.01:
		var n := get_floor_normal()
		var projected := direction - n * direction.dot(n)
		if projected.length() > 0.01: wish = projected.normalized()
		else: wish = Vector3.ZERO
	var speed := SPEED
	if Input.is_key_pressed(KEY_SHIFT) and is_on_floor():
		speed *= SPRINT_MULT
	var target_vel := wish * speed
	var rate: float = ACCEL if is_on_floor() and wish.length() > 0.05 else (DECEL if is_on_floor() else AIR_ACCEL)
	if not is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, AIR_DRAG * absf(velocity.x) * delta)
		velocity.z = move_toward(velocity.z, 0.0, AIR_DRAG * absf(velocity.z) * delta)
	velocity.x = move_toward(velocity.x, target_vel.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, rate * delta)
	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		_land_squash = clampf(_fall_speed_peak / LAND_HARD_SPEED, 0.35, 1.0)
	_was_on_floor = is_on_floor()
	_land_squash = maxf(0.0, _land_squash - delta * 5.0)
	_jump_stretch = maxf(0.0, _jump_stretch - delta * 4.0)
	if body_root and direction.length() > 0.05 and is_on_floor():
		body_root.rotation.y = lerp_angle(body_root.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-12.0 * delta))
		walk_phase += delta * 11.0
		var swing := sin(walk_phase) * 0.55
		if leg_l_pivot: leg_l_pivot.rotation.x = swing
		if leg_r_pivot: leg_r_pivot.rotation.x = -swing
		if arm_l_pivot: arm_l_pivot.rotation.x = -swing * 0.75
		if arm_r_pivot and pickaxe_swing_t <= 0.0: arm_r_pivot.rotation.x = swing * 0.75
	if pickaxe_node and pickaxe_swing_t > 0.0:
		pickaxe_swing_t = maxf(0.0, pickaxe_swing_t - delta * 5.0)
		var st := 1.0 - pickaxe_swing_t
		if arm_r_pivot: arm_r_pivot.rotation.x = -sin(st * PI) * 1.1

func _interact(place: bool) -> void:
	pickaxe_swing_t = 1.0
	var world = get_parent()
	if world and world.get("mining_fx") and world.mining_fx.has_method("play_swing"):
		world.mining_fx.play_swing(global_position + Vector3(0, 1.2, 0))
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * REACH)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	query.collision_mask = 1 | 4
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider = hit.get("collider")
	if collider == null:
		return
	if not place and (collider.is_in_group("animals") or collider.is_in_group("hittable")):
		if collider.has_method("take_damage"):
			collider.take_damage(12.0, global_position)
			if world and world.get("mining_fx") and world.mining_fx.has_method("play_hit"):
				world.mining_fx.play_hit(hit.get("position", global_position))
			if world and world.has_method("_show_toast"):
				var hp_left = collider.get("hp")
				if hp_left != null and float(hp_left) > 0.0:
					world._show_toast("Hit! animal hp %.0f" % float(hp_left), 0.8)
		return
	if not collider.has_meta("block_position"):
		return
	var pos: Vector3i = collider.get_meta("block_position")
	if place:
		var normal: Vector3 = hit.get("normal")
		var target := pos + Vector3i(roundi(normal.x), roundi(normal.y), roundi(normal.z))
		if world.has_method("try_place_selected"):
			world.try_place_selected(target)
		else:
			world.place_block(target, "dirt")
	else:
		var kind := "dirt"
		if collider.has_meta("block_kind"):
			kind = str(collider.get_meta("block_kind"))
		elif world.get("blocks") and world.blocks.has(pos):
			kind = str(world.blocks[pos])
		world.remove_block(pos)
		if world.has_method("on_block_mined"):
			world.on_block_mined(kind)
