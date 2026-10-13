extends CharacterBody3D

const SPEED := 6.0
const JUMP_VELOCITY := 5.0
const REACH := 6.0
const CAMERA_START_PITCH := deg_to_rad(-12.0)
const CAMERA_SENSITIVITY := 0.0025
const TOUCH_LOOK_SENSITIVITY := 0.0032
const TOUCH_BUTTON_SIZE := Vector2(56.0, 56.0)
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera: Camera3D
var touch_controls_enabled := false
var touch_move := Vector2.ZERO
var touch_directions: Dictionary = {}
var touch_jump_pressed := false

func _ready() -> void:
    var collider := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.height = 1.8
    capsule.radius = 0.35
    collider.shape = capsule
    collider.position.y = 0.9
    add_child(collider)

    camera = Camera3D.new()
    camera.name = "PlayerCamera"
    camera.position = Vector3(0, 1.55, 0)
    camera.rotation.x = CAMERA_START_PITCH
    camera.fov = 75.0
    camera.near = 0.05
    camera.far = 500.0
    add_child(camera)
    # Set current after entering the scene tree so this camera is unambiguously active.
    camera.make_current()

    touch_controls_enabled = OS.has_feature("mobile")
    if touch_controls_enabled:
        _build_touch_controls()
    else:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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
    pad.name = "MovementPad"
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
    actions.name = "ActionButtons"
    actions.position = Vector2(viewport_size.x - 164.0, viewport_size.y - 210.0)
    actions.add_theme_constant_override("separation", 8)
    root.add_child(actions)

    var jump := _make_touch_button("JUMP", Vector2(132, 48))
    jump.name = "JumpButton"
    jump.button_down.connect(_set_touch_jump.bind(true))
    jump.button_up.connect(_set_touch_jump.bind(false))
    actions.add_child(jump)

    var mine := _make_touch_button("MINE", Vector2(132, 48))
    mine.name = "MineButton"
    mine.pressed.connect(_interact.bind(false))
    actions.add_child(mine)

    var place := _make_touch_button("PLACE", Vector2(132, 48))
    place.name = "PlaceButton"
    place.pressed.connect(_interact.bind(true))
    actions.add_child(place)

    var look_hint := Label.new()
    look_hint.name = "LookHint"
    look_hint.text = "DRAG TO LOOK"
    look_hint.position = Vector2(viewport_size.x * 0.43, viewport_size.y - 42.0)
    look_hint.add_theme_font_size_override("font_size", 13)
    look_hint.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.72))
    root.add_child(look_hint)

func _add_pad_slot(parent: GridContainer) -> void:
    var slot := Control.new()
    slot.custom_minimum_size = TOUCH_BUTTON_SIZE
    parent.add_child(slot)

func _add_direction_button(parent: GridContainer, caption: String, direction: Vector2) -> void:
    var button := _make_touch_button(caption, TOUCH_BUTTON_SIZE)
    button.name = "Move_" + caption
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
    normal.content_margin_left = 6
    normal.content_margin_right = 6
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color(0.76, 0.58, 0.25, 0.92)
    pressed.border_color = Color(1.0, 0.91, 0.62, 1.0)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", pressed)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_color_override("font_color", Color("#fff7dd"))
    button.add_theme_color_override("font_hover_color", Color("#ffffff"))
    button.add_theme_color_override("font_pressed_color", Color("#14251d"))
    return button

func _set_touch_direction(direction: Vector2, pressed: bool) -> void:
    if pressed:
        touch_directions[direction] = true
    else:
        touch_directions.erase(direction)
    touch_move = Vector2.ZERO
    for key in touch_directions.keys():
        touch_move += Vector2(key)
    touch_move = touch_move.limit_length(1.0)

func _set_touch_jump(pressed: bool) -> void:
    touch_jump_pressed = pressed

func _input(event: InputEvent) -> void:
    if not touch_controls_enabled or not event is InputEventScreenDrag:
        return
    var drag := event as InputEventScreenDrag
    var viewport_size := get_viewport().get_visible_rect().size
    # The left movement pad and right action stack must not rotate the camera.
    if drag.position.x < 250.0 and drag.position.y > viewport_size.y - 250.0:
        return
    if drag.position.x > viewport_size.x - 180.0 and drag.position.y > viewport_size.y - 240.0:
        return
    if drag.position.x < viewport_size.x * 0.38:
        return
    rotate_y(-drag.relative.x * TOUCH_LOOK_SENSITIVITY)
    camera.rotate_x(-drag.relative.y * TOUCH_LOOK_SENSITIVITY)
    camera.rotation.x = clamp(camera.rotation.x, -1.45, 1.45)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
    if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * CAMERA_SENSITIVITY)
        camera.rotate_x(-event.relative.y * CAMERA_SENSITIVITY)
        camera.rotation.x = clamp(camera.rotation.x, -1.45, 1.45)
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            _interact(false)
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            _interact(true)

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= gravity * delta
    elif Input.is_key_pressed(KEY_SPACE) or touch_jump_pressed:
        velocity.y = JUMP_VELOCITY

    var input_dir := Vector2(
        float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
        float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
    ) + touch_move
    input_dir = input_dir.limit_length(1.0)
    var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    velocity.x = direction.x * SPEED
    velocity.z = direction.z * SPEED
    move_and_slide()

func _interact(place: bool) -> void:
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
        world.place_block(target, "dirt")
    else:
        world.remove_block(pos)
