# Builds game/bodies/planet/faceted_ball.glb: a truncated icosahedron (a football's 12 pentagons
# and 20 hexagons), flat shaded, circumradius 1.05 so its faces sit on a unit sphere
# collider. Run: blender -b --python art/make_faceted_ball.py -- <out.glb>
import sys

import bmesh
import bpy

CIRCUMRADIUS = 1.05

out = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
mesh = bpy.data.meshes.new("Ball")
ball = bpy.data.objects.new("Ball", mesh)
bpy.context.scene.collection.objects.link(ball)
bm = bmesh.new()
bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0)
# Cutting every corner a third of the way along its edges truncates the icosahedron.
bmesh.ops.bevel(
    bm, geom=list(bm.verts), offset=100.0 / 3.0, offset_type="PERCENT", affect="VERTICES"
)
for vert in bm.verts:
    vert.co = vert.co.normalized() * CIRCUMRADIUS
for face in bm.faces:
    face.smooth = False
bm.to_mesh(mesh)
bm.free()
print("FACES", len(mesh.polygons), sorted({len(p.vertices) for p in mesh.polygons}))
ball.select_set(True)
bpy.ops.export_scene.gltf(
    filepath=out, use_selection=True, export_format="GLB", export_materials="NONE"
)
