extends CharacterBody3D
## Third-person voxel player — tuned movement physics for voxel terrain.

const SPEED := 7.4
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
	leg_l_pivot.name = "LegL"
	leg_l_pivot.position = Vector3(-0.17, 0.85, 0.0)
	body_root.add_child(leg_l_pivot)
	_box(leg_l_pivot, Vector3(0.0, -0.36, 0.0), Vector3(0.30, 0.72, 0.28), MAT_BLUE)
	_box(leg_l_pivot, Vector3(0.0, -0.78, 0.08), Vector3(0.32, 0.18, 0.40), MAT_BOOT)
	_box(leg_l_pivot, Vector3(0.0, -0.70, 0.24), Vector3(0.28, 0.08, 0.12), Color("#141210"))
	leg_r_pivot = Node3D.new()
	leg_r_pivot.name = "LegR"
	leg_r_pivot.position = Vector3(0.17, 0.85, 0.0)
	body_root.add_child(leg_r_pivot)
	_box(leg_r_pivot, Vector3(0.0, -0.36, 0.0), Vector3(0.30, 0.72, 0.28), MAT_BLUE)
	_box(leg_r_pivot, Vector3(0.0, -0.78, 0.08), Vector3(0.32, 0.18, 0.40), MAT_BOOT)
	_box(leg_r_pivot, Vector3(0.0, -0.70, 0.24), Vector3(0.28, 0.08, 0.12), Color("#141210"))
	torso_node = Node3D.new()
	torso_node.name = "Torso"
	torso_node.position = Vector3(0.0, 1.12, 0.0)
	body_root.add_child(torso_node)
	_box(torso_node, Vector3(0.0, 0.0, 0.0), Vector3(0.78, 0.72, 0.42), MAT_TEAL)
	_box(torso_node, Vector3(0.0, 0.0, 0.22), Vector3(0.50, 0.48, 0.06), Color("#249e90"))
	_box(torso_node, Vector3(0.0, -0.34, 0.0), Vector3(0.82, 0.14, 0.44), Color("#1f8a7e"))
	_box(torso_node, Vector3(0.0, 0.06, -0.36), Vector3(0.62, 0.68, 0.28), MAT_PACK)
	_box(torso_node, Vector3(0.0, 0.36, -0.38), Vector3(0.48, 0.14, 0.30), MAT_PACK_FLAP)
	_box(torso_node, Vector3(0.0, -0.07, -0.36), Vector3(0.50, 0.10, 0.26), Color("#5c3818"))
	_box(torso_node, Vector3(-0.28, 0.13, -0.22), Vector3(0.08, 0.35, 0.08), Color("#4a3010"))
	_box(torso_node, Vector3(0.28, 0.13, -0.22), Vector3(0.08, 0.35, 0.08), Color("#4a3010"))
	arm_l_pivot = Node3D.new()
	arm_l_pivot.name = "ArmL"
	arm_l_pivot.position = Vector3(-0.52, 1.40, 0.0)
	body_root.add_child(arm_l_pivot)
	_box(arm_l_pivot, Vector3(0.0, -0.32, 0.0), Vector3(0.26, 0.64, 0.26), MAT_SKIN)
	_box(arm_l_pivot, Vector3(0.0, -0.68, 0.0), Vector3(0.28, 0.14, 0.28), Color("#e0b090"))
	_box(arm_l_pivot, Vector3(0.0, -0.05, 0.0), Vector3(0.30, 0.12, 0.30), MAT_TEAL)
	arm_r_pivot = Node3D.new()
	arm_r_pivot.name = "ArmR"
	arm_r_pivot.position = Vector3(0.52, 1.40, 0.0)
	body_root.add_child(arm_r_pivot)
	_box(arm_r_pivot, Vector3(0.0, -0.32, 0.0), Vector3(0.26, 0.64, 0.26), MAT_SKIN)
	_box(arm_r_pivot, Vector3(0.0, -0.68, 0.0), Vector3(0.28, 0.14, 0.28), Color("#e0b090"))
	_box(arm_r_pivot, Vector3(0.0, -0.05, 0.0), Vector3(0.30, 0.12, 0.30), MAT_TEAL)
	head_node = Node3D.new()
	head_node.name = "Head"
	head_node.position = Vector3(0.0, 1.78, 0.0)
	body_root.add_child(head_node)
	_box(head_node, Vector3(0.0, 0.0, 0.0), Vector3(0.56, 0.56, 0.54), MAT_SKIN)
	_box(head_node, Vector3(0.0, 0.30, -0.02), Vector3(0.60, 0.20, 0.58), MAT_HAIR)
	_box(head_node, Vector3(0.0, 0.14, -0.26), Vector3(0.58, 0.36, 0.16), MAT_HAIR)
	_box(head_node, Vector3(-0.28, 0.17, 0.05), Vector3(0.14, 0.28, 0.40), MAT_HAIR)
	_box(head_node, Vector3(0.28, 0.17, 0.05), Vector3(0.14, 0.28, 0.40), MAT_HAIR)
	_box(head_node, Vector3(-0.12, 0.02, 0.28), Vector3(0.10, 0.10, 0.06), Color("#1a1410"))
	_box(head_node, Vector3(0.12, 0.02, 0.28), Vector3(0.10, 0.10, 0.06), Color("#1a1410"))
	_box(head_node, Vector3(-0.12, 0.04, 0.30), Vector3(0.04, 0.04, 0.04), Color("#ffffff"))
	_box(head_node, Vector3(0.12, 0.04, 0.30), Vector3(0.04, 0.04, 0.04), Color("#ffffff"))
	_box(head_node, Vector3(0.0, -0.10, 0.28), Vector3(0.14, 0.06, 0.05), Color("#d4887a"))
	pickaxe_node = Node3D.new()
	pickaxe_node.name = "DiamondPickaxe"
	pickaxe_node.position = Vector3(0.12, -0.55, 0.15)
	pickaxe_node.rotation_degrees = Vector3(10.0, 0.0, -25.0)
	arm_r_pivot.add_child(pickaxe_node)
	_box(pickaxe_node, Vector3(0.0, 0.0, 0.0), Vector3(0.07, 0.90, 0.07), MAT_HANDLE)
	_box(pickaxe_node, Vector3(0.0, -0.35, 0.0), Vector3(0.09, 0.12, 0.09), Color("#6b4420"))
	_box(pickaxe_node, Vector3(0.0, 0.52, 0.0), Vector3(0.52, 0.14, 0.13), MAT_DIAMOND, 0.25)
	_box(pickaxe_node, Vector3(-0.24, 0.38, 0.0), Vector3(0.14, 0.24, 0.12), MAT_DIAMOND, 0.25)
	_box(pickaxe_node, Vector3(0.24, 0.38, 0.0), Vector3(0.14, 0.24, 0.12), MAT_DIAMOND, 0.25)
	_box(pickaxe_node, Vector3(0.0, 0.58, 0.0), Vector3(0.18, 0.10, 0.16), Color("#a8ffff"), 0.2)

func _build_third_person_camera() -> void:
	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.fov = 70.0
	camera.near = 0.1
	camera.far = 500.0
	add_child(camera)
	camera.make_current()
	_update_camera_transform(0.016)

func _update_camera_transform(delta: float = 0.016) -> void:
	if camera == null:
		return
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
		if hit:
			dist = clampf(pivot.distance_to(hit.position) - 0.25, 1.2, CAMERA_DISTANCE)
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
	layer.name = "TouchControlsLayer"
	layer.layer = 20
	add_child(layer)
	_touch_root = Control.new()
	_touch_root.name = "TouchControls"
	_touch_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_touch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_touch_root)
	_joy_base_ui = Panel.new()
	_joy_base_ui.name = "JoystickBase"
	_joy_base_ui.size = Vector2(TOUCH_JOY_RADIUS * 2.0, TOUCH_JOY_RADIUS * 2.0)
	_joy_base_ui.visible = false
	_joy_base_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.04, 0.08, 0.09, 0.42)
	base_style.border_color = Color(0.75, 0.95, 0.8, 0.7)
	base_style.set_border_width_all(3)
	base_style.set_corner_radius_all(int(TOUCH_JOY_RADIUS))
	_joy_base_ui.add_theme_stylebox_override("panel", base_style)
	_touch_root.add_child(_joy_base_ui)
	_joy_knob_ui = Panel.new()
	_joy_knob_ui.name = "JoystickKnob"
	_joy_knob_ui.size = Vector2(64, 64)
	_joy_knob_ui.position = Vector2(TOUCH_JOY_RADIUS - 32, TOUCH_JOY_RADIUS - 32)
	_joy_knob_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = Color(0.25, 0.7, 0.45, 0.88)
	knob_style.border_color = Color(0.95, 1.0, 0.95, 1.0)
	knob_style.set_border_width_all(3)
	knob_style.set_corner_radius_all(32)
	_joy_knob_ui.add_theme_stylebox_override("panel", knob_style)
	_joy_base_ui.add_child(_joy_knob_ui)
	_action_column = VBoxContainer.new()
	_action_column.name = "ActionButtons"
	_action_column.add_theme_constant_override("separation", 14)
	_action_column.mouse_filter = Control.MOUSE_FILTER_STOP
	_touch_root.add_child(_action_column)
	var jump := _make_touch_button("⬆ JUMP", Vector2(150, 68))
	jump.button_down.connect(_set_touch_jump.bind(true))
	jump.button_up.connect(_set_touch_jump.bind(false))
	_action_column.add_child(jump)
	var mine := _make_touch_button("⛏ MINE", Vector2(150, 64))
	mine.button_down.connect(func(): _mine_held = true; _interact(false))
	mine.button_up.connect(func(): _mine_held = false)
	_action_column.add_child(mine)
	var place := _make_touch_button("🧱 PLACE", Vector2(150, 64))
	place.pressed.connect(_interact.bind(true))
	_action_column.add_child(place)
	_layout_touch_controls()
	get_viewport().size_changed.connect(_layout_touch_controls)

func _layout_touch_controls() -> void:
	if _action_column == null:
		return
	var vs := get_viewport().get_visible_rect().size
	_action_column.position = Vector2(vs.x - 190.0, vs.y - 270.0)

func _make_touch_button(caption: String, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = minimum_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.04, 0.1, 0.1, 0.78)
	normal.border_color = Color(0.7, 0.92, 0.75, 0.9)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(16)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.78, 0.58, 0.2, 0.95)
	pressed.border_color = Color(1.0, 0.9, 0.5, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", pressed)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color("#f4fff0"))
	button.add_theme_color_override("font_pressed_color", Color("#1a1208"))
	return button

func _set_touch_jump(pressed: bool) -> void:
	touch_jump_pressed = pressed
	if pressed:
		jump_buffer = 0.18

func _update_joystick_knob() -> void:
	if _joy_base_ui == null or _joy_knob_ui == null:
		return
	if not joystick_active:
		_joy_base_ui.visible = false
		_joy_knob_ui.position = Vector2(TOUCH_JOY_RADIUS - 32, TOUCH_JOY_RADIUS - 32)
		return
	_joy_base_ui.visible = true
	var offset := touch_move * (TOUCH_JOY_RADIUS - 8.0)
	_joy_knob_ui.position = Vector2(TOUCH_JOY_RADIUS - 32, TOUCH_JOY_RADIUS - 32) + offset

func _input(event: InputEvent) -> void:
	if not touch_controls_enabled:
		return
	var vs := get_viewport().get_visible_rect().size
	var action_zone_x := vs.x - 190.0
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if touch.position.x >= action_zone_x and touch.position.y > vs.y * 0.45:
				return
			if touch.position.x < vs.x * 0.5:
				joystick_active = true
				joystick_touch_index = touch.index
				joystick_origin = touch.position
				if _joy_base_ui:
					_joy_base_ui.position = joystick_origin - Vector2(TOUCH_JOY_RADIUS, TOUCH_JOY_RADIUS)
				_touch_move_target = Vector2.ZERO
				touch_move = Vector2.ZERO
				_update_joystick_knob()
			else:
				look_touch_index = touch.index
				_look_accum = Vector2.ZERO
		else:
			if touch.index == joystick_touch_index:
				joystick_active = false
				joystick_touch_index = -1
				_touch_move_target = Vector2.ZERO
				_update_joystick_knob()
			if touch.index == look_touch_index:
				look_touch_index = -1
				_look_accum = Vector2.ZERO
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
			_update_joystick_knob()
		elif drag.index == look_touch_index or (look_touch_index < 0 and drag.position.x >= vs.x * 0.5 and drag.position.x < action_zone_x):
			_look_accum += drag.relative
			var look := _look_accum * TOUCH_LOOK_SMOOTH
			_look_accum *= (1.0 - TOUCH_LOOK_SMOOTH)
			_yaw_target -= look.x * TOUCH_LOOK_SENSITIVITY
			_pitch_target = clampf(_pitch_target - look.y * TOUCH_LOOK_SENSITIVITY, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)

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
			if wu and wu.get("inventory"):
				wu.inventory.cycle(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var wd = get_parent()
			if wd and wd.get("inventory"):
				wd.inventory.cycle(1)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw_target -= event.relative.x * CAMERA_SENSITIVITY
		_pitch_target = clampf(_pitch_target - event.relative.y * CAMERA_SENSITIVITY, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_interact(false)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_interact(true)

func _init_footsteps() -> void:
	footstep_stream = _make_footstep_wav()
	footstep_player = AudioStreamPlayer3D.new()
	footstep_player.stream = footstep_stream
	footstep_player.max_distance = 28.0
	footstep_player.unit_size = 6.0
	footstep_player.volume_db = -4.0
	add_child(footstep_player)
	jump_player = AudioStreamPlayer3D.new()
	jump_player.stream = _make_jump_wav()
	jump_player.max_distance = 28.0
	jump_player.unit_size = 6.0
	jump_player.volume_db = -6.0
	add_child(jump_player)
	land_player = AudioStreamPlayer3D.new()
	land_player.stream = _make_land_wav()
	land_player.max_distance = 28.0
	land_player.unit_size = 6.0
	land_player.volume_db = -5.0
	add_child(land_player)

func _make_footstep_wav() -> AudioStreamWAV:
	var sample_rate := 22050
	var n := int(0.08 * sample_rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var prev := 0.0
	for i in range(n):
		var tt := float(i) / sample_rate
		var env := exp(-tt * 32.0)
		var noise := (randf() * 2.0 - 1.0)
		prev = prev * 0.55 + noise * 0.45
		var thump := sin(TAU * 70.0 * tt) * 0.5 * env + sin(TAU * 110.0 * tt) * 0.25 * env
		var sample := clampf((thump + prev * 0.35 * env) * 0.75, -1.0, 1.0)
		var s16 := int(sample * 32767.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _make_jump_wav() -> AudioStreamWAV:
	var sample_rate := 22050
	var n := int(0.12 * sample_rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var tt := float(i) / sample_rate
		var env := exp(-tt * 18.0)
		var s := sin(TAU * (220.0 + tt * 180.0) * tt) * 0.45 * env + sin(TAU * 90.0 * tt) * 0.2 * env
		var s16 := int(clampf(s, -1.0, 1.0) * 30000.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _make_land_wav() -> AudioStreamWAV:
	var sample_rate := 22050
	var n := int(0.1 * sample_rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var prev := 0.0
	for i in range(n):
		var tt := float(i) / sample_rate
		var env := exp(-tt * 28.0)
		var noise := (randf() * 2.0 - 1.0)
		prev = prev * 0.55 + noise * 0.45
		var s := sin(TAU * 70.0 * tt) * 0.4 * env + prev * 0.35 * env
		var s16 := int(clampf(s, -1.0, 1.0) * 30000.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _play_footstep() -> void:
	if footstep_player == null: return
	if footstep_player.playing: footstep_player.stop()
	footstep_player.pitch_scale = randf_range(0.88, 1.12)
	footstep_player.play()

func _play_jump() -> void:
	if jump_player:
		jump_player.pitch_scale = randf_range(0.95, 1.08)
		jump_player.play()

func _play_land() -> void:
	if land_player:
		land_player.pitch_scale = randf_range(0.9, 1.1)
		land_player.play()

func _physics_process(delta: float) -> void:
	if camera == null:
		return
	_update_camera_transform(delta)
	if _mine_held:
		_mine_cooldown -= delta
		if _mine_cooldown <= 0.0:
			_mine_cooldown = 0.28
			_interact(false)
	else:
		_mine_cooldown = 0.0
	touch_move = touch_move.lerp(_touch_move_target, 1.0 - exp(-TOUCH_MOVE_SMOOTH * delta))
	if _touch_move_target == Vector2.ZERO and touch_move.length() < 0.02:
		touch_move = Vector2.ZERO
	_update_joystick_knob()
	var want_jump := Input.is_key_pressed(KEY_SPACE) or touch_jump_pressed
	if is_on_floor():
		coyote_time = 0.15
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
		_play_jump()
	var input_dir := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	) + touch_move
	input_dir = input_dir.limit_length(1.0)
	var basis := Basis(Vector3.UP, yaw)
	var direction := basis * Vector3(input_dir.x, 0.0, input_dir.y)
	if direction.length() > 0.001:
		direction = direction.normalized()
	var wish := direction
	if is_on_floor() and get_floor_normal().y > 0.4 and direction.length() > 0.01:
		var n := get_floor_normal()
		var projected := direction - n * direction.dot(n)
		if projected.length() > 0.01:
			wish = projected.normalized()
		else:
			wish = Vector3.ZERO
	var speed := SPEED
	if is_on_floor() and get_floor_angle() > deg_to_rad(8.0) and wish.dot(Vector3(get_floor_normal().x, 0, get_floor_normal().z)) < -0.1:
		speed *= SLOPE_BOOST
	var target_vel := wish * speed
	var rate: float
	if is_on_floor():
		rate = ACCEL if wish.length() > 0.05 else DECEL
	else:
		rate = AIR_ACCEL if wish.length() > 0.05 else AIR_ACCEL * 0.5
		velocity.x = move_toward(velocity.x, 0.0, AIR_DRAG * absf(velocity.x) * delta)
		velocity.z = move_toward(velocity.z, 0.0, AIR_DRAG * absf(velocity.z) * delta)
	velocity.x = move_toward(velocity.x, target_vel.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, rate * delta)
	move_and_slide()
	if is_on_wall() and not is_on_floor():
		var wn := get_wall_normal()
		var push := velocity.dot(wn)
		if push < 0.0:
			velocity -= wn * push
	if is_on_floor() and not _was_on_floor:
		var impact := clampf(_fall_speed_peak / LAND_HARD_SPEED, 0.35, 1.0)
		_land_squash = impact
		_play_land()
		_fall_speed_peak = 0.0
	_was_on_floor = is_on_floor()
	_step_cooldown = maxf(0.0, _step_cooldown - delta)
	_land_squash = maxf(0.0, _land_squash - delta * 5.0)
	_jump_stretch = maxf(0.0, _jump_stretch - delta * 4.0)
	var squash := 1.0 - _land_squash * 0.18
	var stretch := 1.0 + _jump_stretch * 0.12
	if body_root:
		body_root.scale = Vector3(1.0 + (1.0 - squash) * 0.5, squash * stretch, 1.0 + (1.0 - squash) * 0.5)
	if direction.length() > 0.05 and is_on_floor() and body_root:
		body_root.rotation.y = lerp_angle(body_root.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-12.0 * delta))
		walk_phase += delta * 11.0
		var swing := sin(walk_phase) * 0.55
		var bob := absf(sin(walk_phase)) * 0.06
		if torso_node: torso_node.position.y = 1.12 + bob
		if head_node:
			head_node.position.y = 1.78 + bob * 0.8
			head_node.rotation.x = sin(walk_phase * 0.5) * 0.04
		if leg_l_pivot: leg_l_pivot.rotation.x = swing
		if leg_r_pivot: leg_r_pivot.rotation.x = -swing
		if arm_l_pivot: arm_l_pivot.rotation.x = -swing * 0.75
		if arm_r_pivot and pickaxe_swing_t <= 0.0: arm_r_pivot.rotation.x = swing * 0.75
		var step_sign := 1 if sin(walk_phase) >= 0.0 else -1
		if step_sign != _last_step_sign and _step_cooldown <= 0.0:
			_last_step_sign = step_sign
			_step_cooldown = 0.14
			_play_footstep()
	elif direction.length() > 0.05 and body_root:
		body_root.rotation.y = lerp_angle(body_root.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-12.0 * delta))
		if arm_l_pivot: arm_l_pivot.rotation.x = lerpf(arm_l_pivot.rotation.x, -0.3, 1.0 - exp(-6.0 * delta))
		if arm_r_pivot and pickaxe_swing_t <= 0.0: arm_r_pivot.rotation.x = lerpf(arm_r_pivot.rotation.x, -0.3, 1.0 - exp(-6.0 * delta))
		if leg_l_pivot: leg_l_pivot.rotation.x = lerpf(leg_l_pivot.rotation.x, 0.25, 1.0 - exp(-6.0 * delta))
		if leg_r_pivot: leg_r_pivot.rotation.x = lerpf(leg_r_pivot.rotation.x, -0.15, 1.0 - exp(-6.0 * delta))
	else:
		walk_phase = 0.0
		_last_step_sign = 0
		if torso_node: torso_node.position.y = lerpf(torso_node.position.y, 1.12, 1.0 - exp(-10.0 * delta))
		if head_node:
			head_node.position.y = lerpf(head_node.position.y, 1.78, 1.0 - exp(-10.0 * delta))
			head_node.rotation.x = lerpf(head_node.rotation.x, 0.0, 1.0 - exp(-8.0 * delta))
		for pivot in [leg_l_pivot, leg_r_pivot, arm_l_pivot]:
			if pivot: pivot.rotation.x = lerpf(pivot.rotation.x, 0.0, 1.0 - exp(-10.0 * delta))
		if arm_r_pivot and pickaxe_swing_t <= 0.0:
			arm_r_pivot.rotation.x = lerpf(arm_r_pivot.rotation.x, 0.0, 1.0 - exp(-10.0 * delta))
	if pickaxe_node:
		if pickaxe_swing_t > 0.0:
			pickaxe_swing_t = maxf(0.0, pickaxe_swing_t - delta * 5.0)
			var st := 1.0 - pickaxe_swing_t
			if arm_r_pivot: arm_r_pivot.rotation.x = -sin(st * PI) * 1.1
			pickaxe_node.rotation_degrees = Vector3(10.0 + sin(st * PI) * 55.0, 0.0, -25.0 - sin(st * PI) * 15.0)
		else:
			pickaxe_node.rotation_degrees = Vector3(10.0, 0.0, -25.0)

func _interact(place: bool) -> void:
	pickaxe_swing_t = 1.0
	var world = get_parent()
	if world and world.get("mining_fx") and world.mining_fx.has_method("play_swing"):
		world.mining_fx.play_swing(global_position + Vector3(0, 1.2, 0))
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * REACH)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider = hit.get("collider")
	if not collider or not collider.has_meta("block_position"):
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
