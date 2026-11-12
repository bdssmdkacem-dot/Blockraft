extends SceneTree

const ANIMAL_SCRIPT := preload("res://scripts/animal.gd")

func _initialize() -> void:
	call_deferred("_run_checks")

func _fail(message: String, code: int) -> void:
	push_error("Animal readability acceptance: " + message)
	quit(code)

func _run_checks() -> void:
	# A real collision floor keeps the roaming test grounded. Without it, the
	# animal's obstacle/ground probe correctly changes direction while falling,
	# making movement assertions depend on random wander choices.
	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(40.0, 1.0, 40.0)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.5
	floor_body.add_child(floor_collision)
	root.add_child(floor_body)
	for kind in range(4):
		var animal := ANIMAL_SCRIPT.new() as CharacterBody3D
		if animal == null:
			_fail("animal script did not instantiate", 2)
			return
		root.add_child(animal)
		animal.setup(kind, Vector3(float(kind) * 3.0, 0.05, 0.0))
		await process_frame
		await process_frame

		# Child names can be auto-adjusted by Godot; assert the actual node type
		# rather than relying on the default name CollisionShape3D.
		var colliders := animal.find_children("*", "CollisionShape3D", true, false)
		var collision: CollisionShape3D = colliders[0] as CollisionShape3D if not colliders.is_empty() else null
		if collision == null or not (collision.shape is CapsuleShape3D):
			_fail("animal %d has no capsule collision" % kind, 3)
			return
		var capsule := collision.shape as CapsuleShape3D
		if capsule.radius < (0.34 if kind == 1 else 0.27):
			_fail("animal %d collision/body scale is still too small" % kind, 4)
			return

		var meshes := animal.find_children("*", "MeshInstance3D", true, false)
		var min_parts: int = int([12, 14, 15, 15][kind])
		if meshes.size() < min_parts:
			_fail("animal %d has too few visible mesh parts: %d" % [kind, meshes.size()], 5)
			return
		var body := animal.get_child(0) as Node3D
		if body == null or body.get_child_count() < min_parts:
			_fail("animal %d lacks enough silhouette/detail pieces" % kind, 6)
			return
		var animated_legs: Array = animal.get("_animated_legs")
		if animated_legs.size() < 2:
			_fail("animal %d has fewer than two explicitly registered animated legs" % kind, 7)
			return
		animal._dir = Vector3(1.0, 0.0, 0.0)
		animal._timer = 4.0
		var before := (animated_legs[0] as MeshInstance3D).rotation.x
		var before_position := animal.global_position
		for _frame in range(8):
			await physics_frame
		var after := (animated_legs[0] as MeshInstance3D).rotation.x
		var moved_distance := Vector2(animal.global_position.x - before_position.x, animal.global_position.z - before_position.z).length()
		if moved_distance < 0.08:
			_fail("animal %d gait animated without actual roaming movement" % kind, 9)
			return
		if is_equal_approx(before, after):
			_fail("animal %d gait did not animate while moving" % kind, 8)
			return
		animal.queue_free()
		await process_frame

	floor_body.queue_free()
	print("ANIMAL_READABILITY_ACCEPTANCE_PASS: four animal types have species-specific silhouettes, mobile-scale collision, grounded roaming and animated gait")
	quit(0)
