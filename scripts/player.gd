extends CharacterBody3D
## Third-person player with a fully visible voxel body matching the official
## protagonist sheet. PlayerCamera is a direct child (required by acceptance tests).

const SPEED := 6.0
const JUMP_VELOCITY := 5.0
const REACH := 7.0
const CAMERA_SENSITIVITY := 0.0025
const TOUCH_LOOK_SENSITIVITY := 0.0032
const TOUCH_BUTTON_SIZE := Vector2(56.0, 56.0)
const CAMERA_DISTANCE := 4.2
const CAMERA_MIN_PITCH := deg_to_rad(-55.0)
const CAMERA_MAX_PITCH := deg_to_rad(25.0)

const MAT_SKIN := Color("#e8b896")
const MAT_TEAL := Color("#2ec4b6")
const MAT_BLUE := Color("#3a5f9a")
const MAT_HAIR := Color("#6b3e1f")
const MAT_BOOT := Color("#2a2a2a")
const MAT_PACK := Color("#8b5a2b")
const MAT_PACK_FLAP := Color("#a07040")
const MAT_DIAMOND := Color("#5ce1e6")
const MAT_HANDLE := Color("#8b5a2b")

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera: Camera3D
var yaw := 0.0
var pitch := deg_to_rad(-18.0)
var touch_controls_enabled := false
var touch_move := Vector2.ZERO
var touch_directions: Dictionary = {}
var touch_jump_pressed := false
var body_root: Node3D
var pickaxe_node: Node3D
var pickaxe_swing_t := 0.0
var walk_phase := 0.0

func _ready() -> void:
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.35
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	_build_character_body()
	_build_third_person_camera()
	touch_controls_enabled = OS.has_feature("mobile")
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
	var leg_l := _box(body_root, Vector3(-0.18, 0.42, 0.0), Vector3(0.32, 0.84, 0.3), MAT_BLUE)
	leg_l.name = "LegL"
	var leg_r := _box(body_root, Vector3(0.18, 0.42, 0.0), Vector3(0.32, 0.84, 0.3), MAT_BLUE)
	leg_r.name = "LegR"
	_box(body_root, Vector3(-0.18, 0.06, 0.08), Vector3(0.34, 0.14, 0.42), MAT_BOOT)
	_box(body_root, Vector3(0.18, 0.06, 0.08), Vector3(0.34, 0.14, 0.42), MAT_BOOT)
	_box(body_root, Vector3(0.0, 1.15, 0.0), Vector3(0.85, 0.88, 0.44), MAT_TEAL)
	var arm_l := _box(body_root, Vector3(-0.58, 1.12, 0.0), Vector3(0.28, 0.8, 0.28), MAT_SKIN)
	arm_l.name = "ArmL"
	var arm_r := _box(body_root, Vector3(0.58, 1.12, 0.0), Vector3(0.28, 0.8, 0.28), MAT_SKIN)
	arm_r.name = "ArmR"
	_box(body_root, Vector3(0.0, 1.2, -0.34), Vector3(0.68, 0.72, 0.3), MAT_PACK)
	_box(body_root, Vector3(0.0, 1.42, -0.36), Vector3(0.5, 0.18, 0.32), MAT_PACK_FLAP)
	_box(body_root, Vector3(0.0, 1.82, 0.0), Vector3(0.6, 0.6, 0.58), MAT_SKIN)
	_box(body_root, Vector3(0.0, 2.1, -0.04), Vector3(0.64, 0.24, 0.6), MAT_HAIR)
	_box(body_root, Vector3(0.0, 1.92, -0.24), Vector3(0.62, 0.38, 0.18), MAT_HAIR)
	_box(body_root, Vector3(-0.14, 1.85, 0.28), Vector3(0.1, 0.1, 0.06), Color("#1a1a1a"))
	_box(body_root, Vector3(0.14, 1.85, 0.28), Vector3(0.1, 0.1, 0.06), Color("#1a1a1a"))
	pickaxe_node = Node3D.new()
	pickaxe_node.name = "DiamondPickaxe"
	pickaxe_node.position = Vector3(0.72, 0.95, 0.25)
	pickaxe_node.rotation_degrees = Vector3(20.0, 0.0, -35.0)
	body_root.add_child(pickaxe_node)
	_box(pickaxe_node, Vector3(0.0, 0.0, 0.0), Vector3(0.08, 0.85, 0.08), MAT_HANDLE)
	_box(pickaxe_node, Vector3(0.0, 0.48, 0.0), Vector3(0.48, 0.16, 0.14), MAT_DIAMOND, 0.3)
	_box(pickaxe_node, Vector3(-0.2, 0.36, 0.0), Vector3(0.14, 0.22, 0.12), MAT_DIAMOND, 0.3)
	_box(pickaxe_node, Vector3(0.2, 0.36, 0.0), Vector3(0.14, 0.22, 0.12), MAT_DIAMOND, 0.3)

func _build_third_person_camera() -> void:
	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.fov = 70.0
	camera.near = 0.1
	camera.far = 500.0
	add_child(camera)
	camera.make_current()
	_update_camera_transform()

func _update_camera_transform() -> void:
	var pivot := global_position + Vector3(0.0, 1.35, 0.0)
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var desired := pivot + basis * Vector3(0.0, 0.0, CAMERA_DISTANCE)
	var dist := CAMERA_DISTANCE
	if is_inside_tree() and get_world_3d():
		var query := PhysicsRayQueryParameters3D.create(pivot, desired)
		query.exclude = [self]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit:
			dist = clampf(pivot.distance_to(hit.position) - 0.25, 1.2, CAMERA_DISTANCE)
	camera.global_position = pivot + basis * Vector3(0.0, 0.0, dist)
	camera.look_at(pivot, Vector3.UP)

func _build_touch_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TouchControlsLayer"
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	root.name = "TouchControls"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var viewport_size := get_viewport().get_visible_rect().size
	var pad := GridContainer.new()
	pad.columns = 3
	pad.position = Vector2(24.0, viewport_size.y - 204.0)
	pad.add_theme_constant_override("h_separation", 5)
	pad.add_theme_constant_override("v_separation", 5)
	root.add_child(pad)
	_add_pad_slot(pad)
	_add_direction_button(pad, "▲", Vector2(0, -1))
	_add_pad_slot(pad)
	_add_direction_button(pad, "◀", Vector2(-1, 0))
	_add_pad_slot(pad)
	_add_direction_button(pad, "▶", Vector2(1, 0))
	_add_pad_slot(pad)
	_add_direction_button(pad, "▼", Vector2(0, 1))
	_add_pad_slot(pad)
	var actions := VBoxContainer.new()
	actions.position = Vector2(viewport_size.x - 164.0, viewport_size.y - 210.0)
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)
	var jump := _make_touch_button("JUMP", Vector2(132, 48))
	jump.button_down.connect(_set_touch_jump.bind(true))
	jump.button_up.connect(_set_touch_jump.bind(false))
	actions.add_child(jump)
	var mine := _make_touch_button("MINE", Vector2(132, 48))
	mine.pressed.connect(_interact.bind(false))
	actions.add_child(mine)
	var place := _make_touch_button("PLACE", Vector2(132, 48))
	place.pressed.connect(_interact.bind(true))
	actions.add_child(place)

func _add_pad_slot(parent: GridContainer) -> void:
	var slot := Control.new()
	slot.custom_minimum_size = TOUCH_BUTTON_SIZE
	parent.add_child(slot)

func _add_direction_button(parent: GridContainer, caption: String, direction: Vector2) -> void:
	var button := _make_touch_button(caption, TOUCH_BUTTON_SIZE)
	button.add_theme_font_size_override("font_size", 25)
	button.button_down.connect(_set_touch_direction.bind(direction, true))
	button.button_up.connect(_set_touch_direction.bind(direction, false))
	parent.add_child(button)

func _make_touch_button(caption: String, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = minimum_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.07, 0.075, 0.72)
	normal.border_color = Color(0.75, 0.9, 0.75, 0.82)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.76, 0.58, 0.25, 0.92)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", pressed)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color("#f0f8e6"))
	return button

func _set_touch_direction(direction: Vector2, pressed: bool) -> void:
	if pressed:
		touch_directions[direction] = true
	else:
		touch_directions.erase(direction)
	touch_move = Vector2.ZERO
	for d in touch_directions:
		touch_move += d
	touch_move = touch_move.limit_length(1.0)

func _set_touch_jump(pressed: bool) -> void:
	touch_jump_pressed = pressed

func _input(event: InputEvent) -> void:
	if not touch_controls_enabled:
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.position.x < get_viewport().get_visible_rect().size.x * 0.45:
			return
		yaw -= drag.relative.x * TOUCH_LOOK_SENSITIVITY
		pitch -= drag.relative.y * TOUCH_LOOK_SENSITIVITY
		pitch = clampf(pitch, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			var world_b = get_parent()
			if world_b and world_b.get("inventory") and world_b.inventory.has_method("try_upgrade"):
				world_b.inventory.try_upgrade()
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var world = get_parent()
			if world and world.get("inventory"):
				world.inventory.select(event.keycode - KEY_1)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var world_up = get_parent()
			if world_up and world_up.get("inventory"):
				world_up.inventory.cycle(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var world_dn = get_parent()
			if world_dn and world_dn.get("inventory"):
				world_dn.inventory.cycle(1)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * CAMERA_SENSITIVITY
		pitch -= event.relative.y * CAMERA_SENSITIVITY
		pitch = clampf(pitch, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_interact(false)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_interact(true)

func _physics_process(delta: float) -> void:
	_update_camera_transform()
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_key_pressed(KEY_SPACE) or touch_jump_pressed:
		velocity.y = JUMP_VELOCITY
	var input_dir := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	) + touch_move
	input_dir = input_dir.limit_length(1.0)
	var basis := Basis(Vector3.UP, yaw)
	var direction := (basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	move_and_slide()
	if direction.length() > 0.05:
		var target_yaw := atan2(-direction.x, -direction.z)
		body_root.rotation.y = lerp_angle(body_root.rotation.y, target_yaw, 1.0 - exp(-12.0 * delta))
		walk_phase += delta * 10.0
		var swing := sin(walk_phase) * 0.35
		for pair in [["LegL", swing], ["LegR", -swing], ["ArmL", -swing * 0.7], ["ArmR", swing * 0.7]]:
			var part := body_root.get_node_or_null(pair[0]) as MeshInstance3D
			if part:
				part.rotation.x = pair[1]
	else:
		walk_phase = 0.0
		for n in ["LegL", "LegR", "ArmL", "ArmR"]:
			var part := body_root.get_node_or_null(n) as MeshInstance3D
			if part:
				part.rotation.x = lerpf(part.rotation.x, 0.0, 1.0 - exp(-10.0 * delta))
	if pickaxe_node:
		if pickaxe_swing_t > 0.0:
			pickaxe_swing_t = maxf(0.0, pickaxe_swing_t - delta * 4.5)
			var t := 1.0 - pickaxe_swing_t
			pickaxe_node.rotation_degrees = Vector3(20.0 + sin(t * PI) * 50.0, 0.0, -35.0 - sin(t * PI) * 20.0)
		else:
			pickaxe_node.rotation_degrees = Vector3(20.0, 0.0, -35.0)

func _interact(place: bool) -> void:
	pickaxe_swing_t = 1.0
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
	var world = get_parent()
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
