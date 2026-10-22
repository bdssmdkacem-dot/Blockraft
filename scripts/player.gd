extends CharacterBody3D
## Third-person voxel player — smooth move, swim-to-shore, progressive mining.

const SPEED := 7.6
const SPRINT_MULT := 1.45
const ACCEL := 38.0
const DECEL := 42.0
const AIR_ACCEL := 18.0
const AIR_DRAG := 0.35
const JUMP_VELOCITY := 9.6
const JUMP_CUT_MULT := 0.45
const FALL_GRAVITY_MULT := 1.35
const MAX_FALL_SPEED := 28.0
const LAND_HARD_SPEED := 12.0
const REACH := 6.5
const SWIM_SPEED := 5.2
const SWIM_ACCEL := 16.0
const SWIM_RISE := 4.5
const WATER_DRAG := 0.55
const MINE_RANGE := 6.5
const CAMERA_SENSITIVITY := 0.0022
const TOUCH_LOOK_SENSITIVITY := 0.0036
const TOUCH_LOOK_SMOOTH := 0.28
const TOUCH_JOY_RADIUS := 104.0
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
var _touch_roles: Dictionary = {}
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
var _in_water := false
var _mine_pos: Vector3i = Vector3i(99999, 99999, 99999)
var _mine_progress := 0.0
var _mine_kind := ""

func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 0.8
	floor_max_angle = deg_to_rad(62.0)
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
	var platform_name := OS.get_name().to_lower()
	touch_controls_enabled = platform_name == "android" or platform_name == "ios" or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	print("BLOCKRAFT_INPUT platform=", platform_name, " touch_controls=", touch_controls_enabled)
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
	_box(leg_l_pivot, Vector3(0.0, -0.78, 0.10), Vector3(0.34, 0.18, 0.42), MAT_BOOT)
	leg_r_pivot = Node3D.new()
	leg_r_pivot.position = Vector3(0.17, 0.85, 0.0)
	body_root.add_child(leg_r_pivot)
	_box(leg_r_pivot, Vector3(0.0, -0.36, 0.0), Vector3(0.30, 0.72, 0.28), MAT_BLUE)
	_box(leg_r_pivot, Vector3(0.0, -0.78, 0.10), Vector3(0.34, 0.18, 0.42), MAT_BOOT)
	torso_node = Node3D.new()
	torso_node.position = Vector3(0.0, 1.12, 0.0)
	body_root.add_child(torso_node)
	_box(torso_node, Vector3(0.0, 0.0, 0.0), Vector3(0.78, 0.72, 0.42), MAT_TEAL)
	_box(torso_node, Vector3(0.0, -0.28, 0.0), Vector3(0.80, 0.14, 0.44), Color("#1a3a50"))
	_box(torso_node, Vector3(0.0, -0.28, 0.22), Vector3(0.16, 0.16, 0.08), Color("#d4a020"))
	_box(torso_node, Vector3(0.0, 0.08, -0.38), Vector3(0.62, 0.68, 0.30), MAT_PACK)
	_box(torso_node, Vector3(0.0, 0.32, -0.42), Vector3(0.58, 0.18, 0.12), MAT_PACK_FLAP)
	_box(torso_node, Vector3(0.0, -0.10, -0.42), Vector3(0.20, 0.12, 0.08), Color("#5a3218"))
	arm_l_pivot = Node3D.new()
	arm_l_pivot.position = Vector3(-0.52, 1.40, 0.0)
	body_root.add_child(arm_l_pivot)
	_box(arm_l_pivot, Vector3(0.0, -0.32, 0.0), Vector3(0.26, 0.64, 0.26), MAT_SKIN)
	_box(arm_l_pivot, Vector3(0.0, -0.62, 0.0), Vector3(0.22, 0.12, 0.22), Color("#e0a880"))
	arm_r_pivot = Node3D.new()
	arm_r_pivot.position = Vector3(0.52, 1.40, 0.0)
	body_root.add_child(arm_r_pivot)
	_box(arm_r_pivot, Vector3(0.0, -0.32, 0.0), Vector3(0.26, 0.64, 0.26), MAT_SKIN)
	_box(arm_r_pivot, Vector3(0.0, -0.62, 0.0), Vector3(0.22, 0.12, 0.22), Color("#e0a880"))
	head_node = Node3D.new()
	head_node.position = Vector3(0.0, 1.78, 0.0)
	body_root.add_child(head_node)
	_box(head_node, Vector3(0.0, 0.0, 0.0), Vector3(0.56, 0.56, 0.54), MAT_SKIN)
	_box(head_node, Vector3(0.0, 0.30, -0.02), Vector3(0.62, 0.22, 0.60), MAT_HAIR)
	_box(head_node, Vector3(0.0, 0.12, -0.28), Vector3(0.58, 0.28, 0.12), MAT_HAIR)
	_box(head_node, Vector3(-0.12, 0.06, 0.26), Vector3(0.14, 0.12, 0.06), Color("#ffffff"))
	_box(head_node, Vector3(0.12, 0.06, 0.26), Vector3(0.14, 0.12, 0.06), Color("#ffffff"))
	_box(head_node, Vector3(-0.12, 0.05, 0.30), Vector3(0.07, 0.07, 0.05), Color("#1a1a28"))
	_box(head_node, Vector3(0.12, 0.05, 0.30), Vector3(0.07, 0.07, 0.05), Color("#1a1a28"))
	_box(head_node, Vector3(-0.12, 0.16, 0.27), Vector3(0.16, 0.04, 0.04), MAT_HAIR)
	_box(head_node, Vector3(0.12, 0.16, 0.27), Vector3(0.16, 0.04, 0.04), MAT_HAIR)
	_box(head_node, Vector3(0.0, -0.02, 0.28), Vector3(0.08, 0.08, 0.08), Color("#e0a080"))
	_box(head_node, Vector3(0.0, -0.14, 0.27), Vector3(0.18, 0.05, 0.05), Color("#c06060"))
	_box(head_node, Vector3(-0.32, 0.02, 0.0), Vector3(0.08, 0.14, 0.10), MAT_SKIN)
	_box(head_node, Vector3(0.32, 0.02, 0.0), Vector3(0.08, 0.14, 0.10), MAT_SKIN)
	pickaxe_node = Node3D.new()
	pickaxe_node.position = Vector3(0.06, -0.52, 0.08)
	pickaxe_node.rotation_degrees = Vector3(95.0, 0.0, -12.0)
	arm_r_pivot.add_child(pickaxe_node)
	_box(pickaxe_node, Vector3(0.0, 0.0, 0.0), Vector3(0.07, 0.85, 0.07), MAT_HANDLE)
	_box(pickaxe_node, Vector3(0.0, 0.48, 0.0), Vector3(0.48, 0.14, 0.12), MAT_DIAMOND, 0.25)
	_box(pickaxe_node, Vector3(0.0, 0.48, 0.18), Vector3(0.14, 0.12, 0.16), MAT_DIAMOND, 0.25)

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

	_joy_base_ui = Control.new()
	_joy_base_ui.name = "VirtualJoystickBase"
	_joy_base_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_base_ui.size = Vector2(144.0, 144.0)
	_joy_base_ui.custom_minimum_size = _joy_base_ui.size
	var base_panel := Panel.new()
	base_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.08, 0.12, 0.16, 0.42)
	base_style.border_color = Color(0.72, 0.86, 0.9, 0.72)
	base_style.set_border_width_all(2)
	base_style.set_corner_radius_all(72)
	base_panel.add_theme_stylebox_override("panel", base_style)
	_joy_base_ui.add_child(base_panel)
	_touch_root.add_child(_joy_base_ui)

	_joy_knob_ui = Control.new()
	_joy_knob_ui.name = "VirtualJoystickKnob"
	_joy_knob_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_knob_ui.size = Vector2(58.0, 58.0)
	_joy_knob_ui.custom_minimum_size = _joy_knob_ui.size
	var knob_panel := Panel.new()
	knob_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = Color(0.45, 0.78, 0.86, 0.82)
	knob_style.border_color = Color(0.92, 0.98, 1.0, 0.95)
	knob_style.set_border_width_all(2)
	knob_style.set_corner_radius_all(29)
	knob_panel.add_theme_stylebox_override("panel", knob_style)
	_joy_knob_ui.add_child(knob_panel)
	_touch_root.add_child(_joy_knob_ui)

	_action_column = VBoxContainer.new()
	_action_column.name = "TouchActionColumn"
	_action_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_column.add_theme_constant_override("separation", 10)
	_action_column.custom_minimum_size = Vector2(116.0, 194.0)
	_action_column.size = Vector2(116.0, 194.0)
	_touch_root.add_child(_action_column)
	for label in ["JUMP", "MINE", "PLACE"]:
		var button := Button.new()
		button.text = label
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(116.0, 58.0)
		_action_column.add_child(button)
	_layout_touch()
	get_viewport().size_changed.connect(_layout_touch)

func _layout_touch() -> void:
	if _action_column == null:
		return
	var vs := get_viewport().get_visible_rect().size
	if _joy_base_ui:
		_joy_base_ui.size = Vector2(144.0, 144.0)
		_joy_base_ui.position = Vector2(28.0, vs.y - 174.0)
	if _joy_knob_ui:
		_joy_knob_ui.size = Vector2(58.0, 58.0)
		_joy_knob_ui.position = Vector2(71.0, vs.y - 131.0) + _touch_move_target * 43.0
	_action_column.custom_minimum_size = Vector2(116.0, 194.0)
	_action_column.size = Vector2(116.0, 194.0)
	_action_column.position = Vector2(vs.x - 142.0, vs.y - 205.0)

func _update_joystick_visual() -> void:
	if _joy_base_ui == null or _joy_knob_ui == null:
		return
	var vs := get_viewport().get_visible_rect().size
	if joystick_active:
		_joy_base_ui.position = joystick_origin - Vector2(72.0, 72.0)
		_joy_knob_ui.position = joystick_origin - Vector2(29.0, 29.0) + _touch_move_target * 43.0
	else:
		_joy_base_ui.position = Vector2(28.0, vs.y - 174.0)
		_joy_knob_ui.position = _joy_base_ui.position + Vector2(43.0, 43.0)

func _touch_action_role(position: Vector2, viewport_size: Vector2) -> String:
	var origin := Vector2(viewport_size.x - 142.0, viewport_size.y - 205.0)
	if Rect2(origin, Vector2(116.0, 58.0)).has_point(position):
		return "jump"
	if Rect2(origin + Vector2(0.0, 68.0), Vector2(116.0, 58.0)).has_point(position):
		return "mine"
	if Rect2(origin + Vector2(0.0, 136.0), Vector2(116.0, 58.0)).has_point(position):
		return "place"
	return ""

func _end_touch(index: int) -> void:
	var role := str(_touch_roles.get(index, ""))
	_touch_roles.erase(index)
	match role:
		"move":
			joystick_active = false
			joystick_touch_index = -1
			_touch_move_target = Vector2.ZERO
			_update_joystick_visual()
		"jump":
			touch_jump_pressed = false
		"mine":
			_mine_held = false
		"look":
			if look_touch_index == index:
				look_touch_index = -1

func _input(event: InputEvent) -> void:
	if not touch_controls_enabled:
		return
	var vs := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _touch_roles.has(touch.index):
				return
			var action_role := _touch_action_role(touch.position, vs)
			if not action_role.is_empty():
				_touch_roles[touch.index] = action_role
				match action_role:
					"jump":
					touch_jump_pressed = true
					jump_buffer = 0.18
					"mine":
					_mine_held = true
					"place":
					_interact(true)
				print("BLOCKRAFT_TOUCH index=", touch.index, " role=", action_role)
				return
			if touch.position.x < vs.x * 0.52:
				if joystick_active:
					_touch_roles[touch.index] = "blocked"
					return
				_touch_roles[touch.index] = "move"
				joystick_active = true
				joystick_touch_index = touch.index
				joystick_origin = touch.position
				_touch_move_target = Vector2.ZERO
				_update_joystick_visual()
				print("BLOCKRAFT_TOUCH index=", touch.index, " role=move pos=", touch.position)
			else:
				_touch_roles[touch.index] = "look"
				look_touch_index = touch.index
		else:
			_end_touch(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		var role := str(_touch_roles.get(drag.index, ""))
		if role == "move" and drag.index == joystick_touch_index and joystick_active:
			var delta := drag.position - joystick_origin
			if delta.length() > TOUCH_JOY_RADIUS:
				delta = delta.normalized() * TOUCH_JOY_RADIUS
			var raw := Vector2(delta.x / TOUCH_JOY_RADIUS, delta.y / TOUCH_JOY_RADIUS)
			if raw.length() < TOUCH_JOY_DEADZONE:
				_touch_move_target = Vector2.ZERO
			else:
				var len_v := raw.length()
				_touch_move_target = raw.normalized() * clampf((len_v - TOUCH_JOY_DEADZONE) / (1.0 - TOUCH_JOY_DEADZONE), 0.0, 1.0)
			_update_joystick_visual()
		elif role == "look":
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
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_interact(true)

func _init_footsteps() -> void:
	footstep_player = AudioStreamPlayer3D.new()
	add_child(footstep_player)
	jump_player = AudioStreamPlayer3D.new()
	add_child(jump_player)
	land_player = AudioStreamPlayer3D.new()
	add_child(land_player)

func _physics_process(delta: float) -> void:
	if camera == null:
		return
	_update_camera_transform(delta)
	if not touch_controls_enabled:
		_mine_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_in_water = _check_in_water()
	if _mine_held:
		_tick_mining(delta)
	else:
		_mine_progress = 0.0
		_mine_pos = Vector3i(99999, 99999, 99999)
	touch_move = touch_move.lerp(_touch_move_target, 1.0 - exp(-TOUCH_MOVE_SMOOTH * delta))
	var want_jump := Input.is_key_pressed(KEY_SPACE) or touch_jump_pressed
	var input_dir := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	) + touch_move
	input_dir = input_dir.limit_length(1.0)
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length() > 0.001:
		forward = forward.normalized()
	var right := camera.global_transform.basis.x
	right.y = 0.0
	if right.length() > 0.001:
		right = right.normalized()
	var direction := right * input_dir.x + (-forward) * input_dir.y
	if direction.length() > 0.001:
		direction = direction.normalized()
	if _in_water:
		_physics_swim(delta, direction, want_jump)
	else:
		_physics_land(delta, direction, want_jump)
	move_and_slide()
	_update_body_anim(delta, direction)

func _check_in_water() -> bool:
	var world = get_parent()
	if world == null or not world.get("blocks"):
		return false
	var feet := Vector3i(int(floor(global_position.x)), int(floor(global_position.y + 0.3)), int(floor(global_position.z)))
	var torso := Vector3i(int(floor(global_position.x)), int(floor(global_position.y + 1.0)), int(floor(global_position.z)))
	for p in [feet, torso]:
		if world.blocks.has(p) and str(world.blocks[p]) == "water":
			return true
	return false

func _physics_swim(delta: float, direction: Vector3, want_jump: bool) -> void:
	velocity.y = move_toward(velocity.y, 0.6 if want_jump else -0.4, 8.0 * delta)
	var wish := direction
	if direction.length() < 0.12:
		var shore := _find_nearest_shore()
		if shore != Vector3.ZERO:
			var to_shore := shore - global_position
			to_shore.y = 0.0
			if to_shore.length() > 0.4:
				wish = to_shore.normalized()
	var target := wish * SWIM_SPEED
	velocity.x = move_toward(velocity.x, target.x, SWIM_ACCEL * delta)
	velocity.z = move_toward(velocity.z, target.z, SWIM_ACCEL * delta)
	velocity.x *= (1.0 - WATER_DRAG * delta)
	velocity.z *= (1.0 - WATER_DRAG * delta)
	if want_jump:
		velocity.y = maxf(velocity.y, SWIM_RISE)
		touch_jump_pressed = false

func _find_nearest_shore() -> Vector3:
	var world = get_parent()
	if world == null or not world.get("blocks"):
		return Vector3.ZERO
	var ox := int(floor(global_position.x))
	var oz := int(floor(global_position.z))
	var best := Vector3.ZERO
	var best_d := 9999.0
	for r in range(1, 18):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if abs(dx) != r and abs(dz) != r:
					continue
				var x := ox + dx
				var z := oz + dz
				for y in range(12, -4, -1):
					var pos := Vector3i(x, y, z)
					if not world.blocks.has(pos):
						continue
					var kind := str(world.blocks[pos])
					if kind == "water":
						continue
					var above := Vector3i(x, y + 1, z)
					if world.blocks.has(above) and str(world.blocks[above]) not in ["", "water"]:
						continue
					var cand := Vector3(float(x) + 0.5, float(y) + 1.2, float(z) + 0.5)
					var d := Vector2(cand.x - global_position.x, cand.z - global_position.z).length()
					if d < best_d:
						best_d = d
						best = cand
		if best_d < 9990.0:
			break
	return best

func _physics_land(delta: float, direction: Vector3, want_jump: bool) -> void:
	if is_on_floor():
		coyote_time = 0.16
		_fall_speed_peak = 0.0
		if velocity.y < 0.0:
			velocity.y = 0.0
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
	if want_jump:
		jump_buffer = 0.16
	else:
		jump_buffer = maxf(0.0, jump_buffer - delta)
	if jump_buffer > 0.0 and coyote_time > 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer = 0.0
		coyote_time = 0.0
		touch_jump_pressed = false
		_jump_held = true
		_jump_stretch = 1.0
	var wish := direction
	if is_on_floor() and get_floor_normal().y > 0.35 and direction.length() > 0.01:
		var n := get_floor_normal()
		var projected := direction - n * direction.dot(n)
		if projected.length() > 0.01:
			wish = projected.normalized()
		else:
			wish = Vector3.ZERO
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
	if is_on_floor() and not _was_on_floor:
		_land_squash = clampf(_fall_speed_peak / LAND_HARD_SPEED, 0.35, 1.0)
	_was_on_floor = is_on_floor()
	_land_squash = maxf(0.0, _land_squash - delta * 5.0)
	_jump_stretch = maxf(0.0, _jump_stretch - delta * 4.0)

func _update_body_anim(delta: float, direction: Vector3) -> void:
	if body_root and direction.length() > 0.05 and (is_on_floor() or _in_water):
		body_root.rotation.y = lerp_angle(body_root.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-12.0 * delta))
		walk_phase += delta * (9.0 if _in_water else 12.0)
		var swing := sin(walk_phase) * (0.35 if _in_water else 0.55)
		if leg_l_pivot: leg_l_pivot.rotation.x = swing
		if leg_r_pivot: leg_r_pivot.rotation.x = -swing
		if arm_l_pivot: arm_l_pivot.rotation.x = -swing * 0.75
		if arm_r_pivot and pickaxe_swing_t <= 0.0: arm_r_pivot.rotation.x = swing * 0.75
	if pickaxe_node and pickaxe_swing_t > 0.0:
		pickaxe_swing_t = maxf(0.0, pickaxe_swing_t - delta * 5.5)
		var st := 1.0 - pickaxe_swing_t
		if arm_r_pivot:
			arm_r_pivot.rotation.x = sin(st * PI) * 1.35
			arm_r_pivot.rotation.z = -sin(st * PI) * 0.25

func _block_hardness(kind: String) -> float:
	match kind:
		"leaves", "sand", "gravel":
			return 0.18
		"dirt", "grass", "wood":
			return 0.32
		"stone", "rock", "coal":
			return 0.55
		"iron":
			return 0.75
		"gold", "crystal", "chest":
			return 0.9
		_:
			return 0.4

func _tick_mining(delta: float) -> void:
	var world = get_parent()
	if world == null:
		return
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * MINE_RANGE)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	query.collision_mask = 1 | 4
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_mine_progress = 0.0
		return
	var collider = hit.get("collider")
	if collider == null:
		return
	if collider.is_in_group("animals") or collider.is_in_group("hittable"):
		_mine_cooldown -= delta
		if _mine_cooldown <= 0.0:
			_mine_cooldown = 0.35
			if collider.has_method("take_damage"):
				collider.take_damage(14.0, global_position)
				if world.get("mining_fx") and world.mining_fx.has_method("play_hit"):
					world.mining_fx.play_hit(hit.get("position", global_position))
		return
	if not collider.has_meta("block_position"):
		_mine_progress = 0.0
		return
	var pos: Vector3i = collider.get_meta("block_position")
	var kind := str(collider.get_meta("block_kind")) if collider.has_meta("block_kind") else "dirt"
	if pos != _mine_pos:
		_mine_pos = pos
		_mine_progress = 0.0
		_mine_kind = kind
	var hard := _block_hardness(kind)
	_mine_progress += delta / hard
	pickaxe_swing_t = maxf(pickaxe_swing_t, 0.35)
	if _mine_progress >= 1.0:
		_mine_progress = 0.0
		if kind == "water":
			return
		world.remove_block(pos)
		if world.has_method("on_block_mined"):
			world.on_block_mined(kind)
		_mine_pos = Vector3i(99999, 99999, 99999)

func _interact(place: bool) -> void:
	pickaxe_swing_t = 1.0
	var world = get_parent()
	if world and world.get("mining_fx") and world.mining_fx.has_method("play_swing"):
		world.mining_fx.play_swing(global_position + Vector3(0, 1.2, 0))
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * MINE_RANGE)
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
			collider.take_damage(14.0, global_position)
			if world and world.get("mining_fx") and world.mining_fx.has_method("play_hit"):
				world.mining_fx.play_hit(hit.get("position", global_position))
		return
	if not collider.has_meta("block_position"):
		return
	var pos: Vector3i = collider.get_meta("block_position")
	if place:
		var normal: Vector3 = hit.get("normal")
		var target := pos + Vector3i(roundi(normal.x), roundi(normal.y), roundi(normal.z))
		if global_position.distance_to(Vector3(target) + Vector3(0.5, 0.5, 0.5)) > MINE_RANGE + 0.5:
			return
		var ok := false
		if world.has_method("try_place_selected"):
			ok = world.try_place_selected(target)
		elif world.has_method("place_block"):
			world.place_block(target, "dirt")
			ok = true
		if ok and world and world.has_method("_show_toast"):
			world._show_toast("Placed", 0.6)
