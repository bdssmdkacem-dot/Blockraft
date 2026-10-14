extends Node
## Spawns decorative plants and wandering animals after the voxel world is built.

const AnimalScript = preload("res://scripts/animal.gd")

var _world: Node3D
var _blocks: Dictionary
var _rng := RandomNumberGenerator.new()

func setup(world: Node3D, blocks: Dictionary, seed_value: int = 82417) -> void:
	_world = world
	_blocks = blocks
	_rng.seed = seed_value + 99
	_spawn_plants()
	_spawn_animals()

func _surface_y(x: int, z: int) -> int:
	var top := -999
	for y in range(30, -5, -1):
		if _blocks.has(Vector3i(x, y, z)):
			var k := str(_blocks[Vector3i(x, y, z)])
			if k != "water" and k != "wood":
				top = y
				break
	return top

func _is_water(x: int, z: int) -> bool:
	for y in range(0, 6):
		if _blocks.has(Vector3i(x, y, z)) and str(_blocks[Vector3i(x, y, z)]) == "water":
			return true
	return false

func _box_at(parent: Node3D, pos: Vector3, size: Vector3, color: Color, roughness: float = 0.95) -> void:
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
	_world.add_child(root)
	var count := 0
	var target := 280
	var attempts := 0
	while count < target and attempts < 4000:
		attempts += 1
		var x := _rng.randi_range(-40, 40)
		var z := _rng.randi_range(-40, 40)
		if abs(x) < 3 and abs(z) < 3:
			continue
		var sy := _surface_y(x, z)
		if sy < 0 or sy > 18:
			continue
		var kind := str(_blocks.get(Vector3i(x, sy, z), ""))
		if kind in ["stone", "rock", "water", "wood"]:
			continue
		var near_water := _is_water(x, z) or _is_water(x + 1, z) or _is_water(x, z + 1)
		var plant := Node3D.new()
		plant.position = Vector3(x + 0.5, sy + 1.0, z + 0.5)
		root.add_child(plant)
		if near_water and _rng.randf() < 0.45:
			_make_reed(plant)
		elif kind == "sand":
			_make_dry_tuft(plant)
		elif _rng.randf() < 0.35:
			_make_bush(plant)
		elif _rng.randf() < 0.5:
			_make_flower(plant)
		else:
			_make_tall_grass(plant)
		count += 1

func _make_flower(p: Node3D) -> void:
	_box_at(p, Vector3(0, 0.15, 0), Vector3(0.06, 0.3, 0.06), Color("#2d6b2d"))
	var petal := Color("#e85a8a") if _rng.randf() < 0.5 else Color("#f0c040")
	if _rng.randf() < 0.33:
		petal = Color("#7ec8f0")
	_box_at(p, Vector3(0, 0.38, 0), Vector3(0.22, 0.12, 0.22), petal)
	_box_at(p, Vector3(0, 0.42, 0), Vector3(0.1, 0.08, 0.1), Color("#f8f0a0"))

func _make_tall_grass(p: Node3D) -> void:
	for i in range(3):
		var ox := _rng.randf_range(-0.15, 0.15)
		var oz := _rng.randf_range(-0.15, 0.15)
		var h := _rng.randf_range(0.35, 0.65)
		_box_at(p, Vector3(ox, h * 0.5, oz), Vector3(0.05, h, 0.05), Color("#3a8a35"))

func _make_bush(p: Node3D) -> void:
	_box_at(p, Vector3(0, 0.25, 0), Vector3(0.55, 0.45, 0.55), Color("#2f6b28"))
	_box_at(p, Vector3(0.15, 0.4, -0.1), Vector3(0.35, 0.3, 0.35), Color("#3a8030"))
	if _rng.randf() < 0.4:
		_box_at(p, Vector3(-0.1, 0.35, 0.12), Vector3(0.12, 0.12, 0.12), Color("#c04040"))

func _make_reed(p: Node3D) -> void:
	for i in range(4):
		var ox := _rng.randf_range(-0.2, 0.2)
		var oz := _rng.randf_range(-0.2, 0.2)
		var h := _rng.randf_range(0.7, 1.2)
		_box_at(p, Vector3(ox, h * 0.5, oz), Vector3(0.04, h, 0.04), Color("#4a7a38"))
		_box_at(p, Vector3(ox, h + 0.05, oz), Vector3(0.1, 0.12, 0.06), Color("#6a9a40"))

func _make_dry_tuft(p: Node3D) -> void:
	for i in range(2):
		var ox := _rng.randf_range(-0.1, 0.1)
		var h := _rng.randf_range(0.2, 0.4)
		_box_at(p, Vector3(ox, h * 0.5, ox * 0.5), Vector3(0.05, h, 0.05), Color("#a09050"))

func _spawn_animals() -> void:
	var root := Node3D.new()
	root.name = "Fauna"
	_world.add_child(root)
	var kinds := [AnimalScript.Kind.PIG, AnimalScript.Kind.CHICKEN, AnimalScript.Kind.COW, AnimalScript.Kind.SHEEP]
	var spawned := 0
	var attempts := 0
	while spawned < 18 and attempts < 500:
		attempts += 1
		var x := _rng.randi_range(-35, 35)
		var z := _rng.randi_range(-35, 35)
		if abs(x) < 6 and abs(z) < 6:
			continue
		if _is_water(x, z):
			continue
		var sy := _surface_y(x, z)
		if sy < 1 or sy > 14:
			continue
		var kind_surface := str(_blocks.get(Vector3i(x, sy, z), ""))
		if kind_surface in ["stone", "rock", "sand"]:
			if _rng.randf() < 0.7:
				continue
		var animal: CharacterBody3D = AnimalScript.new()
		animal.name = "Animal_%d" % spawned
		root.add_child(animal)
		var k: int = kinds[_rng.randi_range(0, kinds.size() - 1)]
		if kind_surface == "grass" and _rng.randf() < 0.3:
			k = AnimalScript.Kind.CHICKEN
		animal.setup(k, Vector3(float(x) + 0.5, float(sy) + 1.2, float(z) + 0.5))
		spawned += 1
