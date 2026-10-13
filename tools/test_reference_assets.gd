extends SceneTree

func _initialize() -> void:
    call_deferred("_run_checks")


func _fail(message: String, code: int) -> void:
    push_error("Reference asset acceptance: " + message)
    quit(code)


func _run_checks() -> void:
    var packed := load("res://scenes/asset_gallery.tscn") as PackedScene
    if packed == null:
        _fail("asset_gallery.tscn failed to load", 2)
        return
    var gallery := packed.instantiate() as Node3D
    if gallery == null:
        _fail("asset gallery root is not Node3D", 3)
        return
    root.add_child(gallery)
    current_scene = gallery
    await process_frame
    await process_frame

    var protagonist := gallery.get_node_or_null("ReferenceProtagonist") as Node3D
    var castle := gallery.get_node_or_null("ReferenceCastleGatehouse") as Node3D
    var water := gallery.get_node_or_null("ReferenceStillWaterCube") as Node3D
    if protagonist == null or castle == null or water == null:
        _fail("one or more reference prototypes were not created", 4)
        return

    for required in ["Head", "Torso_Teal", "Backpack_Main", "Backpack_Lid", "DiamondPickaxe"]:
        if protagonist.find_child(required, true, false) == null:
            _fail("protagonist missing required component: " + required, 5)
            return
    for required in ["Left_Tower", "Right_Tower", "Gate_Lintel", "Gate_Threshold", "Tower_Crenellation"]:
        if castle.find_child(required, true, false) == null:
            _fail("castle gatehouse missing required component: " + required, 6)
            return
    for required in ["Water_Volume", "Water_Surface", "Water_Glint"]:
        if water.find_child(required, true, false) == null:
            _fail("water cube missing required layer: " + required, 7)
            return

    var volume := water.get_node("Water_Volume") as MeshInstance3D
    var water_material := volume.material_override as StandardMaterial3D
    if water_material == null or water_material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
        _fail("water volume is not configured with alpha transparency", 8)
        return
    if protagonist.get_child_count() < 15 or castle.get_child_count() < 20 or water.get_child_count() < 5:
        _fail("prototype geometry is incomplete; expected layered detail", 9)
        return

    print("REFERENCE_ASSET_ACCEPTANCE_PASS: protagonist/backpack/pickaxe, castle gatehouse, and layered translucent water cube verified")
    quit(0)
