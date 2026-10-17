# Rendering a Floating Face in Godot 4.7

Researched 2026-10-17 for [#58 How can Godot 4.7 render a Floating Face just off a body?](https://github.com/snackpackgames/Rubbley/issues/58) (map [#57](https://github.com/snackpackgames/Rubbley/issues/57)).

**Question:** how should Godot 4.7 draw a flat, animated 2D face just off a 3D body, facing the fixed-yaw, fixed-tilt camera (ADR 0007)? The face must always show over its own body, other bodies must hide it with normal depth, and it has to run on the Mobile and Compatibility renderers on a low-end phone.

Sources are the Godot 4.7 class reference (the `doc/classes/*.xml` files at tag `4.7-stable`, which build the online docs), engine source at `4.7-stable`, and the Godot 4.7 manual on docs.godotengine.org (the `/en/stable/` pages currently carry the "Godot Engine 4.7 documentation" header).

## Answer

- **Draw each face as one camera-facing quad with a small custom `spatial` shader** (`unshaded`). The shader composites the layers (eyes, brows, mouth) from one atlas and selects frames by index. Set the frame and layer indices with `instance uniform`s on a `MeshInstance3D`, or with `INSTANCE_CUSTOM` if the faces later move into a `MultiMesh`. Every renderer supports this, and it needs one draw call and one texture per face.
- **Get "over its own body, under other bodies" from geometry, not from render flags.** Keep the normal depth test. Either place the quad in front of the body's visual surface, along the ray to the camera, or keep it anywhere and pull its depth toward the camera in the vertex shader by the body's visual radius. Pulling along the view ray changes depth without moving the face on screen. Both work on every renderer and keep normal occlusion by other bodies.
- **Do not use `no_depth_test`** (it draws over other bodies). **Do not use `render_priority` for this either**: it only orders transparent objects among themselves and never overrides the depth test.
- **The camera has fixed yaw and tilt, so the face does not need billboarding.** Give the quad the camera's basis once. Billboard modes work too, but they solve a problem this game doesn't have.
- **`Sprite3D`/`AnimatedSprite3D` are fine for a quick prototype but are the weaker production choice.** Each one owns a private mesh and material, re-uploads its quad's vertex buffers on every frame change, keeps processing off screen, and cannot layer parts.
- **Avoid a `SubViewport` per face on phones.** Each one is an extra render target. Keep it as an option for one bespoke face (Rubbley or a boss) whose art really needs a 2D rig.
- **Mobile and Compatibility do not auto-instance.** Every separate face node costs at least one draw call on the phone renderers. The GLOSSARY says only a few Celestial Bodies exist at once, so per-face nodes should be affordable. `MultiMesh` is the fallback if shared-style enemies or planets push the count up.

## 1. Ways to draw the face

### a. `Sprite3D` / `AnimatedSprite3D` (SpriteBase3D)

- They support billboard modes (`BILLBOARD_ENABLED`: Z axis faces the camera; `BILLBOARD_FIXED_Y`; `BILLBOARD_PARTICLES`), `fixed_size`, `no_depth_test`, `render_priority`, `alpha_cut` (disabled, discard, opaque prepass, hash), `shaded` (default off, so unlit), `double_sided` and `pixel_size` ([SpriteBase3D.xml](https://github.com/godotengine/godot/blob/4.7-stable/doc/classes/SpriteBase3D.xml), [BaseMaterial3D.xml](https://github.com/godotengine/godot/blob/4.7-stable/doc/classes/BaseMaterial3D.xml)).
- **Every sprite node creates its own mesh and its own material RID.** The shader is shared through `StandardMaterial3D::get_material_for_2d(...)`, but the material instance and mesh are per node ([sprite_3d.cpp L721-786, L303-316](https://github.com/godotengine/godot/blob/4.7-stable/scene/3d/sprite_3d.cpp)). Separate materials and meshes rule out any merging.
- **Every frame change re-uploads the quad.** `draw_texture_rect` rebuilds the four vertices and UVs and calls `mesh_surface_update_vertex_region` and `mesh_surface_update_attribute_region`. The texture parameter is only re-set when the texture RID changes (sprite_3d.cpp L278-313), so frames that share one atlas avoid the texture swap but still upload vertices.
- **`AnimatedSprite3D` advances frames in `NOTIFICATION_INTERNAL_PROCESS` with no on-screen check** (sprite_3d.cpp L1125-1180, `set_process_internal(true)` at L1409). "Only animate on screen" needs a `VisibleOnScreenEnabler3D`/`VisibleOnScreenNotifier3D` that pauses it ([VisibleOnScreenNotifier3D.xml](https://github.com/godotengine/godot/blob/4.7-stable/doc/classes/VisibleOnScreenNotifier3D.xml)).
- **They can't layer parts.** A sprite draws one texture region, so eyes, brows and mouth would be three nodes (three draw calls), or every combination would have to be pre-baked into frames.
- A `material_override` is allowed. It has to read vertex color (`ALBEDO *= COLOR.rgb`) or `modulate` is ignored (SpriteBase3D.xml, `modulate`). Once a custom shader is in place, though, the sprite node adds little over a plain quad.

### b. Quad (`QuadMesh` in a `MeshInstance3D`) + custom spatial shader (recommended)

- A single shared `ShaderMaterial` (`render_mode unshaded, cull_back;`) on a shared `QuadMesh`. Per-face state goes in `instance uniform`s, which "are set on each GeometryInstance3D, rather than on each Material instance". This avoids duplicating materials, which "has a performance overhead". There is a practical limit of 16 per shader, and textures and arrays are not allowed, only scalars and vectors ([Shading language: per-instance uniforms](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html)). That is enough for frame indices per layer, gaze offset, tint and style id.
- The Compatibility renderer supports instance uniforms: its scene shader declares `instance_offset` into the global uniform buffer ([drivers/gles3/shaders/scene.glsl](https://github.com/godotengine/godot/blob/4.7-stable/drivers/gles3/shaders/scene.glsl), L503/L1238).
- Animation timing can live in script (set an int frame index when it changes) or entirely in the shader (`frame = int(TIME * fps + phase) % count`), which costs no CPU per frame.
- **Facing:** ADR 0007 fixes the camera's yaw and tilt, so copy the camera's basis onto the face node (or use `top_level` and set it once). Alternatively, rebuild the model-view from `INV_VIEW_MATRIX`/`MAIN_CAM_INV_VIEW_MATRIX` in the vertex shader, as BaseMaterial3D billboarding does ([Spatial shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)). Note: when a billboarded material casts shadows, the billboard faces "the" camera even in the shadow pass (BaseMaterial3D/SpriteBase3D `billboard` note). Faces should not cast shadows anyway.

### c. `SubViewport` rendering a 2D face into a `ViewportTexture`

- This is the documented "Rendering 2D elements in a 3D game" route. By default a SubViewport re-renders whenever its ViewportTexture was drawn that frame; `UPDATE_ONCE` renders once and then switches to never ([Using Viewports](https://docs.godotengine.org/en/stable/tutorials/rendering/viewports.html)).
- **Cost:** every SubViewport is an extra render target and render pass. Godot's GPU optimization guide warns that on mobile you should "be very careful to test the performance of shaders, viewport textures and post processing", because tiles that depend on earlier results can be very slow ([GPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html)).
- Its one advantage is that the face can be authored with full 2D tooling (`Skeleton2D`, `AnimationPlayer`, several `Sprite2D`s). Use it at most for one bespoke face, updating only when the Expression or frame changes, not as the general mechanism.

## 2. Over its own body, hidden by other bodies

| Technique | Over own body | Hidden by other bodies | Renderers | Verdict |
|---|---|---|---|---|
| Place the quad in front of the body's visual surface | Yes, if the margin covers the body's visual extent | Yes (normal depth test) | All | **Use** (simplest) |
| Vertex-shader depth pull toward camera | Yes | Yes | All (`POSITION` built-in) | **Use** when the face should stay centred on the body |
| `no_depth_test` | Yes | **No**: draws on top of all others | All | Reject |
| `render_priority` | No (does not beat depth) | n/a | All | Reject for this purpose |
| Writing `DEPTH` in fragment | Yes | Yes | All | Avoid: costs early-Z on mobile |
| Stencil (body writes ID, face compares) | Possible | Possible | All, experimental | Overkill |

**Placement.** For a roughly convex body with visual radius `r`, put the face centre at `body_centre + dir_to_camera * (r + margin)`. A point on the ray toward the camera keeps the face over the body's screen position. The quad's edges lie in a plane parallel to the screen. Off-axis, they can sit slightly behind the sphere's front-most depth, so the margin needs a little slack: about `r * (1/cos θ - 1)` at a view angle of θ, roughly 5% of `r` at 17°, the half-angle of a 35° FOV. Procedural squash, stretch and swell (map #57) enlarge the visual extent, so drive the margin from the animated extent, not the collider radius. The face sitting in front of the body is physically what "the side nearest the camera" means, and other bodies occlude it correctly with normal depth.

**Depth pull in the vertex shader.** Leave the face at any position and scale each vertex's view-space position along its own view ray:

```glsl
// spatial shader, vertex()
vec4 v = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
float d = length(v.xyz);
v.xyz *= max(d - depth_pull, near_eps) / d; // depth_pull = body visual radius + margin (instance uniform)
POSITION = PROJECTION_MATRIX * v;
```

Scaling along the ray leaves the projected screen position unchanged. Only the depth changes. `POSITION` "overrides final vertex position in clip space", and when it is written "the value from `VERTEX` is ignored and projection does not happen", so it has to be written on every branch ([Spatial shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)). Compatibility uses 24-bit depth without reverse-Z and Mobile uses 24-bit with reverse-Z ([Overview of renderers](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)), so keep the margin well above depth precision at gameplay distances. With a single tilted camera and bodies on one plane, that is easy.

**Why not the flags:**

- `no_depth_test` / `FLAG_DISABLE_DEPTH_TEST`: "Disables the depth test, so this object is drawn on top of all others drawn before it. This puts the object in the transparent draw pass where it is sorted based on distance to camera … This also disables writing to depth" ([BaseMaterial3D.xml](https://github.com/godotengine/godot/blob/4.7-stable/doc/classes/BaseMaterial3D.xml)). It breaks the "hidden by other bodies" rule.
- `render_priority`: "This will not impact how transparent objects are sorted relative to opaque objects or how dynamic meshes will be sorted relative to other opaque meshes. This is because all transparent objects are drawn after all opaque objects…" ([Material.xml](https://github.com/godotengine/godot/blob/4.7-stable/doc/classes/Material.xml)). On a sprite it "only applies if `alpha_cut` is set to `ALPHA_CUT_DISABLED`" (SpriteBase3D.xml). It only orders draw sequence; depth testing still applies. It is useful only for ordering the face against other transparent effects such as Orbit trails.
- `fixed_size`: renders "the same size regardless of distance", as if the camera were 1 unit away (SpriteBase3D.xml, BaseMaterial3D.xml). That is wrong here: ADR 0007 zooms by moving the camera, and faces should scale with their bodies.
- Writing `DEPTH` in the fragment shader: the Godot docs only require it to be written on every branch. Arm's Mali hidden-surface-removal notes say shader behaviour that can change visibility forces late Z-testing and reduces early-Z/Forward Pixel Kill benefits ([Arm: hidden surface removal in Mali GPUs](https://developer.arm.com/community/arm-community-blogs/b/mobile-graphics-and-gaming-blog/posts/hidden-surface-graphics-removal-methods-in-mali-gpus)). The vertex pull gets the same result for free.
- Stencil: spatial shaders have `stencil_mode` (`read`, `write`, `compare_*`…), marked "experimental, use at your own risk", and "You can only read from the stencil buffer in the transparent pass" (Spatial shaders). Compatibility implements it, but opaque stencil writes force a depth prepass ([rasterizer_scene_gles3.cpp L253-276, L2712-2713](https://github.com/godotengine/godot/blob/4.7-stable/drivers/gles3/rasterizer_scene_gles3.cpp)). It is not needed when geometry already solves the problem.

### Transparency mode and sorting pitfalls

- **Alpha blend** (sprite default `ALPHA_CUT_DISABLED`; shader writes `ALPHA`): soft edges, but the face goes in the transparent pass. Transparent objects are sorted back to front per object and do not write depth by default (`DEPTH_DRAW_OPAQUE_ONLY`). They still test against the opaque bodies' depth, so occlusion by bodies works. The pitfall is face-on-face overlap: sorting is per object origin, so two overlapping faces can swap order. That only happens when two Characters overlap on screen, and the depth pull keeps origins ordered sensibly. Transparent pixels also cost fill rate: "every item has to be drawn" ([GPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html)). Keep the quad tight around the art.
- **Alpha scissor / discard** (`ALPHA_CUT_DISCARD`, `alpha_scissor_threshold`): stays in the opaque pass with correct depth and no sorting issues, but edges are "harsh" unless screen-space AA is on (SpriteBase3D.xml). The Compatibility renderer has no FXAA/SMAA but does support 3D MSAA (renderers page). `discard` also weakens early-Z on Mali (Arm blog). On a quad this small the cost is minor.
- **Opaque prepass** (`ALPHA_CUT_OPAQUE_PREPASS` / `depth_prepass_alpha`): correct sorting plus smooth edges, but "slower than" the other two (SpriteBase3D.xml).
- **Alpha hash**: dithered cutoff; it is noisy at small sizes.

The default suggestion is alpha blend with `unshaded`. Switch to scissor if face-on-face overlap looks wrong in the prototype.

## 3. Mobile and Compatibility

All recommended pieces work on both renderers: quad + spatial shader, `instance uniform`, `POSITION`, alpha blend or scissor, `MultiMesh` with custom data. Points that differ:

- **No automatic instancing**: "This is only implemented in the Forward+ renderer, not Mobile or Compatibility." Even on Forward+ it needs opaque or alpha-tested materials; "Alpha-blended or depth pre-pass materials are never instanced this way" ([Optimizing 3D performance](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html)). On the phone renderers, N separate face nodes are N draw calls.
- `MultiMesh` custom data "is stored in 32 bits in the Forward+ and Mobile rendering methods, but is packed into 16 bits in the Compatibility rendering method" ([MultiMesh.xml](https://github.com/godotengine/godot/blob/4.7-stable/doc/classes/MultiMesh.xml)). Half floats store integers up to 2048 exactly, which is plenty for frame indices.
- Compatibility: "Low base cost, but high scaling cost". Mobile: "Medium base cost, and medium scaling cost" (renderers page). Godot 4.7's release notes say Vulkan Mobile "matches or even outperforms our Compatibility renderer in a number of benchmarks" ([Godot 4.7 release](https://godotengine.org/releases/4.7/)). The notes list no changes to Sprite3D, billboards, MultiMesh, stencil or instance uniforms in 4.7.

## 4. Cost of many animated faces on a low-end phone

- **Draw calls dominate, not pixels.** One quad per face is cheap to shade. Without auto-instancing, each face node adds a draw call plus per-object state. "Godot sorts objects by Material and Shader" (Optimizing 3D performance), so sharing one ShaderMaterial and one atlas across all faces keeps state changes low. The GPU guide's advice is to reuse materials and "in the worst case, use atlases to decrease the amount of texture changes" (GPU optimization).
- **SpriteFrames vs shader frame index:**
  - `AnimatedSprite3D` runs CPU work per node every frame (internal process), plus a vertex and attribute buffer upload on each frame change, on a per-node material (section 1a).
  - A shader frame index costs one `instance uniform` write when the frame or Expression changes, or nothing if the shader derives the frame from `TIME`. All faces share one material.
- **MultiMesh** is "a single draw primitive" for many instances, with per-instance `INSTANCE_CUSTOM` (4 floats). The catches: "there is no screen or frustum culling possible for individual instances", visibility is all-or-none for the whole MultiMesh, and the docs suggest splitting by area ([Optimization using MultiMeshes](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html)). Script must also push every face's transform each frame. Use one MultiMesh per shared face style if generic enemies or planets get numerous. Bespoke faces (Rubbley, bosses) stay as separate nodes.
- **Only animate on screen:** pause per-face script work with `VisibleOnScreenNotifier3D` (it ignores occlusion unless occlusion culling is on, and needs a frame before `is_on_screen()` is valid). Frustum culling already skips drawing off-screen `MeshInstance3D`s. MultiMesh instances are not culled individually.
- **Not measured.** No numbers exist for the Galaxy A16 / Mali-G68 MP2 from [android-min-spec-phone.md](android-min-spec-phone.md). The draw-call budget needs a prototype benchmark on that device.

## 5. Composing layered parts into one face

Draw one quad with one shader and one atlas. Sample one atlas cell per layer and alpha-composite them in the fragment shader:

```glsl
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform vec2 grid = vec2(8.0, 8.0);          // cells in the atlas
instance uniform float eyes_frame;            // or INSTANCE_CUSTOM.x in a MultiMesh
instance uniform float brows_frame;
instance uniform float mouth_frame;
instance uniform vec2 gaze = vec2(0.0);       // pupil UV offset
instance uniform vec4 tint : source_color = vec4(1.0);

vec4 cell(float idx, vec2 uv) {
    vec2 c = vec2(mod(idx, grid.x), floor(idx / grid.x));
    return texture(atlas, (c + clamp(uv, 0.0, 1.0)) / grid);
}
vec4 over(vec4 top, vec4 base) { return vec4(mix(base.rgb, top.rgb, top.a), base.a + top.a * (1.0 - base.a)); }

void fragment() {
    vec4 c = cell(eyes_frame, UV + gaze);     // gaze moves only the eye layer
    c = over(cell(brows_frame, UV), c);
    c = over(cell(mouth_frame, UV), c);
    ALBEDO = c.rgb * tint.rgb;
    ALPHA = c.a * tint.a;
}
```

- This is one draw call and one texture bind per face, whatever the number of layers. It costs three texture samples per pixel on a small quad.
- Per-face values fit in the 16-instance-uniform limit. In a MultiMesh, pack them into `INSTANCE_CUSTOM`'s 4 floats (eyes, brows, mouth, gaze packed or style).
- Clamp UVs (or pad atlas cells) so linear filtering and gaze offsets do not bleed into neighbouring cells. Sprite texture filtering has the same edge-artifact warning (SpriteBase3D.xml, `texture_filter`).
- Tint and scale give generic enemies and planets shared face styles (map #57). A style is either a different atlas, which needs a different material and therefore a separate draw call or MultiMesh, or a row offset inside one big atlas.
- The alternative of three stacked quads triples draw calls and adds sorting between the layers. Don't use it.

## Not verified

- No benchmark of draw-call budget or fill rate on the min-spec phone. The cost conclusions are qualitative and come from the docs and source.
- Whether `instance uniform` updates cost anything noticeable on Compatibility at high face counts. The source confirms support, not performance.
- How Godot 4.7 orders transparent objects at equal distance in detail (the face-on-face overlap case). Check it visually in the prototype.

## Sources

- Godot 4.7 class reference at `4.7-stable`: [SpriteBase3D](https://github.com/godotengine/godot/blob/4.7-stable/doc/classes/SpriteBase3D.xml), [BaseMaterial3D](https://github.com/godotengine/godot/blob/4.7-stable/doc/classes/BaseMaterial3D.xml), [Material](https://github.com/godotengine/godot/blob/4.7-stable/doc/classes/Material.xml), [MultiMesh](https://github.com/godotengine/godot/blob/4.7-stable/doc/classes/MultiMesh.xml), [VisibleOnScreenNotifier3D](https://github.com/godotengine/godot/blob/4.7-stable/doc/classes/VisibleOnScreenNotifier3D.xml)
- Engine source at `4.7-stable`: [scene/3d/sprite_3d.cpp](https://github.com/godotengine/godot/blob/4.7-stable/scene/3d/sprite_3d.cpp), [drivers/gles3/rasterizer_scene_gles3.cpp](https://github.com/godotengine/godot/blob/4.7-stable/drivers/gles3/rasterizer_scene_gles3.cpp), [drivers/gles3/shaders/scene.glsl](https://github.com/godotengine/godot/blob/4.7-stable/drivers/gles3/shaders/scene.glsl)
- Godot 4.7 manual: [Spatial shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html), [Shading language](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html), [Optimizing 3D performance](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html), [GPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html), [Optimization using MultiMeshes](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html), [Using Viewports](https://docs.godotengine.org/en/stable/tutorials/rendering/viewports.html), [Overview of renderers](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
- [Godot 4.7 release notes](https://godotengine.org/releases/4.7/)
- Arm: [Hidden surface removal methods in Mali GPUs](https://developer.arm.com/community/arm-community-blogs/b/mobile-graphics-and-gaming-blog/posts/hidden-surface-graphics-removal-methods-in-mali-gpus)
