extends Node
## Higher-detail flora + fauna spawn.

const AnimalScript = preload("res://scripts/animal.gd")

var _world: Node3D
var _blocks: Dictionary
var _rng := RandomNumberGenerator.new()
var _wind_t := 0.0
var _flora_root: Node3D
var _wind_step := 0

func setup(world: Node3D, blocks: Dictionary, seed_value: int = 82417) -> void:
	_world = world
	_blocks = blocks
	_rng.seed = seed_value + 99
	_spawn_plants()
	_spawn_animals()

func _process(delta: float) -> void:
	_wind_t += delta
	_wind_step += 1
	if _flora_root == null or (_wind_step % 2) != 0:
		return
	var i := 0
	for child in _flora_root.get_children():
		if child is Node3D:
			var phase := float(i) * 0.37
			child.rotation.z = sin(_wind_t * 1.4 + phase) * 0.05
			child.rotation.x = cos(_wind_t * 1.1 + phase) * 0.035
			i += 1

func _surface_y(x: int, z: int) -> int:
	for y in range(30, -5, -1):
		if _blocks.has(Vector3i(x, y, z)):
			var k := str(_blocks[Vector3i(x, y, z)])
			if k != "water" and k != "wood" and k != "leaves":
				return y
	return -999

func _is_water(x: int, z: int) -> bool:
	for y in range(0, 6):
		if _blocks.has(Vector3i(x, y, z)) and str(_blocks[Vector3i(x, y, z)]) == "water":
			return true
	return false

func _box_at(parent: Node3D, pos: Vector3, size: Vector3, color: Color, roughness: float = 0.9) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

func _spawn_plants() -> void:
	var root := Node3D.new()
	root.name = "Flora"
	_flora_root = root
	_world.add_child(root)
	var count := 0
	var attempts := 0
	while count < 180 and attempts < 4000:
		attempts += 1
		var x := _rng.randi_range(-52, 52)
		var z := _rng.randi_range(-52, 52)
		if abs(x) < 3 and abs(z) < 3:
			continue
		var sy := _surface_y(x, z)
		if sy < 0 or sy > 18:
			continue
		var kind := str(_blocks.get(Vector3i(x, sy, z), ""))
		if kind in ["stone", "rock", "water", "wood", "leaves"]:
			continue
		var near_water := _is_water(x, z) or _is_water(x + 1, z) or _is_water(x, z + 1)
		var plant := Node3D.new()
		plant.position = Vector3(x + 0.5, float(sy) + 1.0, z + 0.5)
		root.add_child(plant)
		if near_water and _rng.randf() < 0.5:
			_make_reed(plant)
		elif kind == "sand":
			_make_dry_tuft(plant)
		elif _rng.randf() < 0.28:
			_make_bush(plant)
		elif _rng.randf() < 0.45:
			_make_flower(plant)
		else:
			_make_tall_grass(plant)
		count += 1

func _make_flower(p: Node3D) -> void:
	_box_at(p, Vector3(0, 0.18, 0), Vector3(0.05, 0.36, 0.05), Color("#2a6b2a"))
	var petals := [Color("#e85a8a"), Color("#f0c040"), Color("#7ec8f0"), Color("#e070e0"), Color("#ff8060")]
	var petal: Color = petals[_rng.randi_range(0, petals.size() - 1)]
	_box_at(p, Vector3(0, 0.42, 0), Vector3(0.20, 0.08, 0.20), petal)
	_box_at(p, Vector3(0.12, 0.40, 0), Vector3(0.10, 0.07, 0.10), petal)
	_box_at(p, Vector3(-0.10, 0.40, 0.08), Vector3(0.10, 0.07, 0.10), petal)
	_box_at(p, Vector3(0, 0.46, 0), Vector3(0.08, 0.08, 0.08), Color("#ffe880"))

func _make_tall_grass(p: Node3D) -> void:
	for i in range(4):
		var ox := _rng.randf_range(-0.18, 0.18)
		var oz := _rng.randf_range(-0.18, 0.18)
		var h := _rng.randf_range(0.35, 0.70)
		var g := Color(0.28 + _rng.randf() * 0.15, 0.55 + _rng.randf() * 0.2, 0.22)
		_box_at(p, Vector3(ox, h * 0.5, oz), Vector3(0.04, h, 0.04), g)

func _make_bush(p: Node3D) -> void:
	_box_at(p, Vector3(0, 0.28, 0), Vector3(0.55, 0.48, 0.55), Color("#2d6e28"))
	_box_at(p, Vector3(0.18, 0.42, -0.08), Vector3(0.38, 0.32, 0.38), Color("#3a8030"))
	_box_at(p, Vector3(-0.15, 0.38, 0.12), Vector3(0.32, 0.28, 0.32), Color("#256020"))
	if _rng.randf() < 0.45:
		_box_at(p, Vector3(-0.08, 0.40, 0.15), Vector3(0.10, 0.10, 0.10), Color("#c04040"))
		_box_at(p, Vector3(0.12, 0.45, -0.05), Vector3(0.09, 0.09, 0.09), Color("#d05040"))

func _make_reed(p: Node3D) -> void:
	for i in range(5):
		var ox := _rng.randf_range(-0.22, 0.22)
		var oz := _rng.randf_range(-0.22, 0.22)
		var h := _rng.randf_range(0.75, 1.35)
		_box_at(p, Vector3(ox, h * 0.5, oz), Vector3(0.035, h, 0.035), Color("#3d7a35"))
		_box_at(p, Vector3(ox, h + 0.06, oz), Vector3(0.12, 0.14, 0.06), Color("#5a9a40"))

func _make_dry_tuft(p: Node3D) -> void:
	for i in range(3):
		var ox := _rng.randf_range(-0.12, 0.12)
		var h := _rng.randf_range(0.18, 0.40)
		_box_at(p, Vector3(ox, h * 0.5, ox * 0.4), Vector3(0.045, h, 0.045), Color("#b0a060"))

func _spawn_animals() -> void:
	var spawned := 0
	var attempts := 0
	var kinds := [AnimalScript.Kind.FOX, AnimalScript.Kind.CHICKEN, AnimalScript.Kind.COW, AnimalScript.Kind.SHEEP, AnimalScript.Kind.CHICKEN]
	while spawned < 28 and attempts < 700:
		attempts += 1
		var x := _rng.randi_range(-50, 50)
		var z := _rng.randi_range(-50, 50)
		if abs(x) < 6 and abs(z) < 6:
			continue
		if _is_water(x, z):
			continue
		var sy := _surface_y(x, z)
		if sy < 1 or sy > 14:
			continue
		var kind_surface := str(_blocks.get(Vector3i(x, sy, z), ""))
		if kind_surface in ["stone", "rock", "sand"] and _rng.randf() < 0.7:
			continue
		var animal: CharacterBody3D = AnimalScript.new()
		animal.name = "Animal_%d" % spawned
		_world.add_child(animal)
		var k: int = kinds[_rng.randi_range(0, kinds.size() - 1)]
		if kind_surface == "grass" and _rng.randf() < 0.55:
			k = AnimalScript.Kind.CHICKEN
		elif _rng.randf() < 0.2:
			k = AnimalScript.Kind.FOX
		animal.setup(k, Vector3(float(x) + 0.5, float(sy) + 1.05, float(z) + 0.5))
		spawned += 1
