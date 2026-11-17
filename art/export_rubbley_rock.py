# Exports Rubbley's rock from art/rubbley.blend to game/bodies/rubbley/rubbley_rock.glb:
# centred, flat shaded, scaled to a mean width of 2.47 m so 0.75 x his collider radius
# frames it (RubbleyMass). It refuses a rock with a hole, which shows in game as a dark
# gap you can see inside through. Run:
# blender -b art/rubbley.blend --python art/export_rubbley_rock.py -- <out.glb>
import sys

import bmesh
import bpy
import mathutils

MEAN_WIDTH_M = 2.47

out = sys.argv[sys.argv.index("--") + 1]
src = bpy.data.objects["Cube"]
for obj in bpy.context.scene.objects:
    obj.select_set(False)
rock = src.copy()
rock.data = src.data.copy()
rock.name = "Rock"
rock.data.name = "Rock"
bpy.context.scene.collection.objects.link(rock)
rock.data.materials.clear()
me = rock.data
me.transform(mathutils.Matrix.Diagonal(src.matrix_world.to_scale()).to_4x4())
rock.matrix_world = mathutils.Matrix.Identity(4)
lo = mathutils.Vector([min(v.co[i] for v in me.vertices) for i in range(3)])
hi = mathutils.Vector([max(v.co[i] for v in me.vertices) for i in range(3)])
me.transform(mathutils.Matrix.Translation(-(lo + hi) / 2))
me.transform(mathutils.Matrix.Scale(MEAN_WIDTH_M / (sum(hi - lo) / 3), 4))
bm = bmesh.new()
bm.from_mesh(me)
assert all(e.is_manifold for e in bm.edges), "Rubbley's rock has a hole; close it in Blender"
bm.free()
for poly in me.polygons:
    poly.use_smooth = False
rock.select_set(True)
bpy.ops.export_scene.gltf(
    filepath=out, use_selection=True, export_format="GLB", export_materials="NONE"
)
