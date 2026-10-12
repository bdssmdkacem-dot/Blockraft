# Blockraft original asset pack builder — Blender 4.x
# Run from the repository root:
# blender --background --python tools/blender/build_blockraft_asset_pack.py
#
# Source OBJ meshes remain editable. This script creates review-ready GLB exports
# and a .blend review scene; it does not claim visual acceptance or Android testing.

import bpy
import os
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MODEL_DIR = os.path.join(ROOT, "assets", "models")
GLB_DIR = os.path.join(MODEL_DIR, "glb")
BLEND_DIR = os.path.join(ROOT, "assets", "blender")
os.makedirs(GLB_DIR, exist_ok=True)
os.makedirs(BLEND_DIR, exist_ok=True)

ASSETS = [
    ("voxel_oak_tree", "voxel_oak_tree.obj"),
    ("meadow_cottage", "meadow_cottage.obj"),
    ("crafting_bench", "crafting_bench.obj"),
]

# Start from a clean scene so repeated runs are deterministic.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.cameras, bpy.data.lights):
    for block in list(datablocks):
        if block.users == 0:
            datablocks.remove(block)

review_collection = bpy.context.scene.collection

for asset_name, filename in ASSETS:
    source_path = os.path.join(MODEL_DIR, filename)
    if not os.path.isfile(source_path):
        raise FileNotFoundError("Missing Blockraft model: " + source_path)

    before = set(bpy.data.objects)
    bpy.ops.wm.obj_import(filepath=source_path, forward_axis="NEGATIVE_Z", up_axis="Y")
    imported = [obj for obj in bpy.data.objects if obj not in before and obj.type == "MESH"]
    if not imported:
        raise RuntimeError("OBJ import created no mesh objects for " + asset_name)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in imported:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = imported[0]
    if len(imported) > 1:
        bpy.ops.object.join()
    model = bpy.context.view_layer.objects.active
    model.name = asset_name
    model.data.name = asset_name + "_Mesh"

    # A tiny single-segment bevel catches light without destroying the voxel silhouette.
    bevel = model.modifiers.new("Micro edge highlight", "BEVEL")
    bevel.width = 0.025
    bevel.segments = 1
    bevel.limit_method = "ANGLE"
    bevel.angle_limit = 0.35
    bevel.profile = 0.5

    normal = model.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    normal.keep_sharp = True
    normal.weight = 30

    # Preserve each asset's own origin/coordinates; place only in the review scene.
    export_path = os.path.join(GLB_DIR, asset_name + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    model.select_set(True)
    bpy.context.view_layer.objects.active = model
    bpy.ops.export_scene.gltf(
        filepath=export_path,
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_materials="EXPORT",
    )
    print("Exported:", export_path)
    # Keep the source object available for duplication, but out of the review render.
    model.hide_render = True
    model.hide_set(True)

# Review layout: separate copies in a simple studio scene.
review_layout = [
    ("voxel_oak_tree", (-5.0, 0.0, 0.0)),
    ("meadow_cottage", (0.0, 0.0, 0.0)),
    ("crafting_bench", (5.0, 0.0, 0.0)),
]
for name, location in review_layout:
    source = bpy.data.objects.get(name)
    if source is None:
        raise RuntimeError("Expected model missing from review scene: " + name)
    duplicate = source.copy()
    duplicate.data = source.data.copy()
    duplicate.name = name + "_Review"
    review_collection.objects.link(duplicate)
    duplicate.hide_set(False)
    duplicate.hide_render = False
    duplicate.location = Vector(location)

# Ground plane for visual review only; it is not exported with individual models.
bpy.ops.mesh.primitive_plane_add(size=22, location=(0, -0.05, 0))
ground = bpy.context.object
ground.name = "ReviewGround"
ground_mat = bpy.data.materials.new("ReviewGround_Moss")
ground_mat.diffuse_color = (0.10, 0.16, 0.11, 1.0)
ground.data.materials.append(ground_mat)

bpy.ops.object.camera_add(location=(10.5, 8.0, 17.0))
camera = bpy.context.object
camera.name = "AssetReviewCamera"
direction = Vector((0.0, 2.2, 0.0)) - camera.location
camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
camera.data.lens = 48
bpy.context.scene.camera = camera

bpy.ops.object.light_add(type="AREA", location=(1.0, 9.0, 7.0))
key = bpy.context.object
key.name = "AssetReview_Key"
key.data.energy = 1800
key.data.shape = "DISK"
key.data.size = 8
key.rotation_euler = (Vector((0.0, 1.5, 0.0)) - key.location).to_track_quat("-Z", "Y").to_euler()

bpy.ops.object.light_add(type="AREA", location=(-8.0, 5.0, -4.0))
fill = bpy.context.object
fill.name = "AssetReview_Fill"
fill.data.energy = 650
fill.data.size = 7
fill.rotation_euler = (Vector((0.0, 2.0, 0.0)) - fill.location).to_track_quat("-Z", "Y").to_euler()

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = os.path.join(BLEND_DIR, "blockraft_asset_review.png")
scene.world.color = (0.08, 0.1, 0.12)

blend_path = os.path.join(BLEND_DIR, "Blockraft_Asset_Review.blend")
bpy.ops.wm.save_as_mainfile(filepath=blend_path)
print("Saved review scene:", blend_path)
print("Render with: blender -b " + blend_path + " -o " + os.path.join(BLEND_DIR, "blockraft_asset_review") + " -F PNG -f 1")
