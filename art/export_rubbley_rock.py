# Exports Rubbley's rock from art/rubbley.blend to game/bodies/rubbley/rubbley_rock.glb:
# centred, flat shaded, scaled to a mean width of 2.47 m so 0.75 x his collider radius
# frames it (RubbleyMass). Run:
# blender -b art/rubbley.blend --python art/export_rubbley_rock.py -- <out.glb>
import sys

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
for poly in me.polygons:
    poly.use_smooth = False
rock.select_set(True)
bpy.ops.export_scene.gltf(
    filepath=out, use_selection=True, export_format="GLB", export_materials="NONE"
)
