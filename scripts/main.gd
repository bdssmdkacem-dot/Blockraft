extends Node3D

const WORLD_RADIUS := 18
const MIN_Y := -3
const SAVE_PATH := "user://world_blocks.json"

var blocks: Dictionary = {}
var block_mesh := BoxMesh.new()
var block_materials: Dictionary = {}
var world_root: Node3D
var player: CharacterBody3D

func _ready() -> void:
    world_root = Node3D.new()
    world_root.name = "GeneratedWorld"
    add_child(world_root)
    player = get_node("Player")
    _setup_materials()
    _generate_world()
    _load_world_snapshot()
    _build_world()
    _setup_ui()

func _setup_materials() -> void:
    var colors := {
        "grass": Color(0.28, 0.62, 0.22),
        "dirt": Color(0.38, 0.24, 0.13),
        "stone": Color(0.42, 0.45, 0.48),
        "wood": Color(0.42, 0.25, 0.11)
    }
    for key in colors:
        var mat := StandardMaterial3D.new()
        mat.albedo_color = colors[key]
        mat.roughness = 1.0
        block_materials[key] = mat

func _generate_world() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 82417
    for x in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
        for z in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
            var height := int(round(2.0 + sin(float(x) * 0.23) * 1.5 + cos(float(z) * 0.19) * 1.3))
            for y in range(MIN_Y, height + 1):
                var kind := "stone"
                if y == height:
                    kind = "grass"
                elif y >= height - 2:
                    kind = "dirt"
                blocks[Vector3i(x, y, z)] = kind
            if rng.randf() < 0.025 and abs(x) > 3 and abs(z) > 3:
                _make_tree(x, height + 1, z)

func _make_tree(x: int, y: int, z: int) -> void:
    for dy in range(4):
        blocks[Vector3i(x, y + dy, z)] = "wood"
    for dx in range(-2, 3):
        for dz in range(-2, 3):
            for dy in range(2, 5):
                if abs(dx) + abs(dz) + abs(dy - 3) < 5:
                    var p := Vector3i(x + dx, y + dy, z + dz)
                    if not blocks.has(p):
                        blocks[p] = "grass"

func _build_world() -> void:
    for pos in blocks:
        _spawn_block(pos, str(blocks[pos]))

func _spawn_block(pos: Vector3i, kind: String) -> void:
    var body := StaticBody3D.new()
    body.position = Vector3(pos)
    body.set_meta("block_position", pos)
    body.set_meta("block_kind", kind)
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.mesh = block_mesh
    mesh_instance.material_override = block_materials.get(kind, block_materials["stone"])
    body.add_child(mesh_instance)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3.ONE
    collision.shape = shape
    body.add_child(collision)
    world_root.add_child(body)

func remove_block(pos: Vector3i) -> void:
    if not blocks.has(pos):
        return
    blocks.erase(pos)
    for node in world_root.get_children():
        if node.has_meta("block_position") and node.get_meta("block_position") == pos:
            node.queue_free()
            break
    save_world()

func place_block(pos: Vector3i, kind: String = "dirt") -> void:
    if blocks.has(pos) or pos.y < MIN_Y or pos.y > 80:
        return
    if player.global_position.distance_to(Vector3(pos)) < 1.8:
        return
    blocks[pos] = kind
    _spawn_block(pos, kind)
    save_world()

func save_world() -> void:
    var serialized: Array = []
    for p in blocks:
        serialized.append({"x": p.x, "y": p.y, "z": p.z, "kind": blocks[p]})
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify({"version": 1, "blocks": serialized}))

func _load_world_snapshot() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if not file:
        push_warning("Could not open saved world; using generated terrain.")
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("blocks") or typeof(parsed["blocks"]) != TYPE_ARRAY:
        push_warning("Saved world format is invalid; using generated terrain.")
        return
    var restored: Dictionary = {}
    for entry in parsed["blocks"]:
        if typeof(entry) == TYPE_DICTIONARY and entry.has("x") and entry.has("y") and entry.has("z") and entry.has("kind"):
            restored[Vector3i(int(entry["x"]), int(entry["y"]), int(entry["z"]))] = str(entry["kind"])
    # Replace the generated snapshot completely so removed blocks stay removed after restart.
    blocks = restored

func _setup_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var label := Label.new()
    if OS.has_feature("mobile"):
        label.text = "BLOCKRAFT  |  Drag to look  •  Use the pad to move  •  Mine / Place"
        label.add_theme_font_size_override("font_size", 13)
    else:
        label.text = "BLOCKRAFT  |  WASD move  •  Space jump  •  Mouse look  •  Left click mine  •  Right click build"
        label.add_theme_font_size_override("font_size", 16)
    label.position = Vector2(16, 14)
    layer.add_child(label)
