extends CharacterBody3D

const SPEED := 6.0
const JUMP_VELOCITY := 5.0
const REACH := 6.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera: Camera3D

func _ready() -> void:
    var collider := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.height = 1.8
    capsule.radius = 0.35
    collider.shape = capsule
    collider.position.y = 0.9
    add_child(collider)
    camera = Camera3D.new()
    camera.position = Vector3(0, 1.55, 0)
    camera.current = true
    add_child(camera)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * 0.0025)
        camera.rotate_x(-event.relative.y * 0.0025)
        camera.rotation.x = clamp(camera.rotation.x, -1.45, 1.45)
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            _interact(false)
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            _interact(true)

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= gravity * delta
    elif Input.is_key_pressed(KEY_SPACE):
        velocity.y = JUMP_VELOCITY
    var input_dir := Vector2(
        float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
        float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
    ).normalized()
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
