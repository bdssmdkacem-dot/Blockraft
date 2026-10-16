extends SceneTree

const ANIMAL_SCRIPT := preload("res://scripts/animal.gd")

func _initialize() -> void:
	call_deferred("_run_checks")

func _fail(message: String, code: int) -> void:
	push_error("Animal readability acceptance: " + message)
	quit(code)

func _run_checks() -> void:
	for kind in range(4):
		var animal := ANIMAL_SCRIPT.new() as CharacterBody3D
		if animal == null:
			_fail("animal script did not instantiate", 2)
			return
		root.add_child(animal)
		animal.setup(kind, Vector3(float(kind) * 3.0, 3.0, 0.0))
		await process_frame
		await process_frame

		var collision := animal.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision == null or not (collision.shape is CapsuleShape3D):
			_fail("animal %d has no capsule collision" % kind, 3)
			return
		var capsule := collision.shape as CapsuleShape3D
		if capsule.radius < 0.27:
			_fail("animal %d collision/body scale is still too small" % kind, 4)
			return

		var meshes := animal.find_children("*", "MeshInstance3D", true, false)
		if meshes.size() < 9:
			_fail("animal %d has too few visible mesh parts: %d" % [kind, meshes.size()], 5)
			return
		var body := animal.get_child(0) as Node3D
		if body == null or body.get_child_count() < 8:
			_fail("animal %d lacks enough silhouette/detail pieces" % kind, 6)
			return
		animal.queue_free()
		await process_frame

	print("ANIMAL_READABILITY_ACCEPTANCE_PASS: four animal types have mobile-scale collision and layered visible geometry")
	quit(0)
