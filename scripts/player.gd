extends CharacterBody3D
## Third-person voxel player — smooth move, swim-to-shore, progressive mining + SFX.

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
var dig_player: AudioStreamPlayer3D
var splash_player: AudioStreamPlayer3D
var swim_player: AudioStreamPlayer3D
var _foot_cd := 0.0
var _swim_cd := 0.0
var _was_in_water := false
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
	touch_controls_enabled = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	if touch_controls_enabled:
		_build_touch_controls()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
