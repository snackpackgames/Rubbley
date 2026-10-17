# How can Godot 4.7 do procedural squash, stretch, wobble and particle break-apart?

Research for [#59](https://github.com/snackpackgames/Rubbley/issues/59), part of map [#57](https://github.com/snackpackgames/Rubbley/issues/57). Researched 2026-10-17 against the Godot 4.7 stable docs and the `4.7-stable` tag of `godotengine/godot`.

Constraints from the repo: Godot 4.7, GDScript only (ADR 0002, 0004). Physics is 3D Jolt on the XZ Play Plane, and each body locks linear Y and angular X/Z (ADR 0003). The camera has fixed yaw and tilt and sits outside the body's tree (ADR 0007). Phones on the Mobile and Compatibility renderers are the tightest target. Body animation must be visual only.

## Short answer

- **Deform a visual pivot node, never the body or the collider.** Give each Character a `Visual` `Node3D` that is a sibling of its `CollisionShape3D`. Only `CollisionObject3D` and `CollisionShape3D` transforms reach Jolt, so scaling anything under `Visual` costs physics nothing and triggers no warning.
- **Use a damped spring for impacts and a Tween for authored one-shots.** Both write the pivot's `basis`. A squash along an arbitrary axis is `R * S * R⁻¹` (volume-preserving: `S = diag(s, 1/√s, 1/√s)` along the impact axis). This works the same on spheres and low-poly rocks and costs a few float ops per body per frame.
- **Use a vertex shader for wobble and jelly.** A spring cannot do it, because the effect needs per-vertex variation. It is cheap on the GPU, but children don't follow it. A Floating Face has to run the same deformation function in its own shader (a shared `.gdshaderinc` plus the same per-instance uniforms). Wobble also needs vertex density: it looks good on a sphere and coarse on a 12–40-vertex rock.
- **Physics interpolation:** animate the pivot either in `_physics_process`, or in `_process` with `physics_interpolation_mode = OFF` on the pivot. Changing an interpolated node's transform in `_process` causes jitter.
- **Breaking apart:** use a one-shot `GPUParticles3D` (`explosiveness = 1`) with a rock-chunk mesh in its draw pass. It works on both phone renderers. On Compatibility it loses trails, sub-emitters, `emit_particle()`, SDF collision and vector-field attractors, and gets no pipeline precompilation, so warm it up at level load. Ship `CPUParticles3D` as the fallback for Adreno 3xx (where GPUParticles is disabled) and for anything that needs script-placed emission points.
- **The Floating Face follows transform-based deformation for free** if it is a child of the squash pivot but not of the tumble node. Don't use `billboard_keep_scale`, because it throws away the squash direction. With the fixed camera of ADR 0007, a plane with a constant world orientation already faces the camera.

## Recommended node layout

```
RigidBody3D                  (Jolt; never scaled, never animated)
├─ CollisionShape3D          (uniform scale only; never animated)
└─ Visual (Node3D)           squash/stretch/swell basis; interpolation OFF if driven in _process
   ├─ Tumble (Node3D)        cosmetic 3-axis rotation (ADR 0003)
   │  └─ MeshInstance3D      body mesh; optional wobble shader
   └─ FaceAnchor (Node3D)    placed on the camera-facing side; cancels body Y rotation
      └─ Face (MeshInstance3D quad)
```

Squash sits above Tumble so its axis is the world impact direction, not a direction that rolls with the tumble. The face sits under Squash, so it squashes with the body, and outside Tumble, so it never rolls.

## 1. Scale on a child vs. the physics body (Jolt)

- Only the body and its shapes are sent to the physics server. Jolt reads the scale from the body transform and from each shape's transform, and wraps the shape in a `JPH::ScaledShape` when the scale isn't 1 ([`jolt_shaped_object_3d.cpp`](https://github.com/godotengine/godot/blob/4.7-stable/modules/jolt_physics/objects/jolt_shaped_object_3d.cpp) lines 69–72 and 92–97). If a scale is invalid for a shape (for example, non-uniform on a sphere), Jolt replaces it with a valid one and prints *"A scale of %v is not supported by Jolt Physics for this shape/body. The scale will instead be treated as %v."* ([`jolt_shape_3d.h`](https://github.com/godotengine/godot/blob/4.7-stable/modules/jolt_physics/shapes/jolt_shape_3d.h) lines 110–131).
- Editor warnings: `RigidBody3D` warns *"Scale changes to RigidBody3D will be overridden by the physics engine when running. Please change the size in children collision shapes instead."* ([`rigid_body_3d.cpp`](https://github.com/godotengine/godot/blob/4.7-stable/scene/3d/physics/rigid_body_3d.cpp) line 675). `CollisionShape3D` warns *"A non-uniformly scaled CollisionShape3D node will probably not function as expected."* ([`collision_shape_3d.cpp`](https://github.com/godotengine/godot/blob/4.7-stable/scene/3d/physics/collision_shape_3d.cpp) line 158).
- A `MeshInstance3D` or `Node3D` sibling of the shape isn't a collision object, so no physics code reads its scale. The rule follows: **never put a `CollisionShape3D` under the deformed pivot.** If one ended up there, every squash would rebuild a Jolt `ScaledShape` and change gameplay.
- Mass-change swell and shrink is visual here (the map's Out of scope section sends collider growth to #66). Scaling `Visual` uniformly is the visual half; the gameplay half changes the shape resource's `radius`, not node scale.

## 2. Transform-based deformation: Tween and damped spring

Both approaches write `Visual.basis` (and optionally its `position`, to keep the contact side planted). They differ only in where the numbers come from.

**Squash along an arbitrary axis.** Build an orthonormal basis `R` whose X axis is the impact normal (in the body's local frame: `body.global_basis.inverse() * world_normal`, which for this game is a Y-rotation only). Then set `Visual.basis = R * Basis.from_scale(Vector3(s, k, k)) * R.transposed()`. For volume preservation, `k = 1/sqrt(s)`. Godot's renderer transforms normals with the normal matrix, so lighting stays correct under non-uniform scale (`MODEL_NORMAL_MATRIX` built-in, [spatial shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)).

**Tween** ([Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html)):
- Created with `create_tween()`; *"the Tween will be automatically killed when the bound object is freed"*; *"You should avoid using more than one Tween per object's property ... the last one created will take priority."*
- `set_process_mode(TWEEN_PROCESS_PHYSICS)` makes it *"update after each physics frame"*, which is the interpolation-safe choice (section 4). `TRANS_ELASTIC`, `TRANS_SPRING` and `TRANS_BACK` give overshoot curves.
- Good for authored, fixed-shape moments: Spin flourish, Orbit capture pop, stun shudder, idle breathing (as a looping tween, or just `sin(t)`).
- Weak for impacts. A second hit mid-tween must `kill()` and restart, which snaps the curve. One tween per property means stacking squash plus swell needs separate nodes or a combined script.

**Damped spring** (hand-written in GDScript; no engine node):
- State is a scalar or `Vector3` displacement `x` and velocity `v`. Each step: `v += (-k*x - c*v) * dt; x += v * dt` (semi-implicit Euler, the same integrator family Jolt uses). An impact adds to `v`, so hits accumulate naturally and never snap.
- Impact strength: Jolt's `get_contact_impulse()` values are estimates, *"only accurate in cases where the two bodies in question are not colliding"* with others ([Using Jolt Physics](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html)). Prefer the relative normal speed from `get_contact_local_velocity_at_position()` and `get_contact_collider_velocity_at_position()` in `_integrate_forces` (needs `contact_monitor` and `max_contacts_reported > 0`; [PhysicsDirectBodyState3D](https://docs.godotengine.org/en/stable/classes/class_physicsdirectbodystate3d.html)), or the per-tick change in `linear_velocity`.
- One spring per Character can drive squash amount, swell and stun jitter, and the same values can feed the Reaction layer.

**How it looks.** Spheres read best, because a squashed sphere is an ellipsoid with no tell. Low-poly rocks squash convincingly too, because whole-object scale keeps faceting intact. Transform deformation is uniform across the object, so it can't do a ripple or a wobble that travels across the surface.

**Phone cost.** Per Character per frame: a few dozen float ops in GDScript and one transform push to the RenderingServer. This is negligible next to the N-body gravity loop. Only animate Characters on screen (a map standing decision).

## 3. Vertex-shader deformation (wobble, jelly, directional squash)

- A `ShaderMaterial` with a `vertex()` function moves `VERTEX` in model space. Use `world_vertex_coords` to work in world space instead, which makes an impact direction in world space easy ([spatial shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)). Never visible to physics.
- **Per-Character parameters without per-Character materials:** `instance uniform` values set with `set_instance_shader_parameter()`. *"There is a practical maximum limit of 16 instance uniforms per shader"*, and they don't support textures or arrays. The only Compatibility caveat the docs give is about indexing texture arrays ([shading language](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html)). GDScript feeds them from the same spring (impact direction, amplitude, phase) each frame. That is a uniform write, not a transform, so physics interpolation doesn't apply.
- **Wobble:** for example, `VERTEX += NORMAL * amp * sin(dot(VERTEX, dir) * freq - TIME * speed) * exp(-decay * t_since_hit)`. To keep lighting right, also bend `NORMAL`, or accept slightly wrong shading. A toon ramp hides most of the error.
- **Squash in the shader** is the same `R*S*R⁻¹` matrix applied to `VERTEX`, plus its inverse-transpose applied to `NORMAL`. It's only worth it if you want to avoid the extra node.
- **Culling:** displacement past the mesh's AABB can pop at the screen edge. Pad it with `extra_cull_margin` or `custom_aabb` ([GeometryInstance3D](https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html)).
- **How it looks.** A sphere (`SphereMesh` defaults to 64 radial segments × 32 rings) has enough vertices for smooth wobble. A low-poly rock has too few: the wobble becomes faceted jitter, and displacing along `NORMAL` on flat-shaded split vertices tears faces apart. For rocks, displace along the direction from the centre (`normalize(VERTEX)`), not `NORMAL`, or use transform squash only.
- **Phone cost:** a handful of ALU ops per vertex. That is small next to fragment cost, and vertex counts here are tiny. One extra shader variant per material, which on Compatibility must be warmed up (see section 5).

## 4. Physics interpolation

- *"Both in 2D and 3D, physics interpolation is performed on the local transform of each instance"* ([advanced physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html)). Changing an interpolated node's transform outside the physics tick makes *"the calculations for the interpolated position ... incorrect, and you will get jitter"* ([using physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/using_physics_interpolation.html)). In 3D, interpolation runs on the scene side ([2D and 3D physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/2d_and_3d_physics_interpolation.html)).
- **Option A, tick-driven:** step the spring or tween in `_physics_process` (`TWEEN_PROCESS_PHYSICS`). The pivot's local transform is interpolated like everything else. This is fine at 60 Hz, but a spring with a period near the tick length aliases, and the body's tick rate may drop on phones (ADR 0003).
- **Option B, frame-driven:** set `Visual.physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF` and step in `_process`. *"Only the child's local transform is uninterpolated"*, so the node still rides the body's interpolated transform. In source, a non-interpolated node's transform change is pushed straight to the server on the next frame traversal ([`scene_tree_fti.cpp`](https://github.com/godotengine/godot/blob/4.7-stable/scene/main/scene_tree_fti.cpp) lines 364–376). This is the smoothest option and is independent of tick rate. It is the recommended choice.
- Shader-driven deformation is unaffected either way, because instance uniforms aren't transforms.
- **Particles:** `CPUParticles3D` in global coords emits from `get_global_transform_interpolated()` ([`cpu_particles_3d.cpp`](https://github.com/godotengine/godot/blob/4.7-stable/scene/3d/cpu_particles_3d.cpp) line 781). `GPUParticles3D` computes emitter velocity in the internal physics process *"so that velocity calculations remain correct if the physics tick rate is lower than the rendered framerate"* ([`gpu_particles_3d.cpp`](https://github.com/godotengine/godot/blob/4.7-stable/scene/3d/gpu_particles_3d.cpp) lines 565–575).

## 5. Breaking apart: particles only

**GPUParticles3D** ([class](https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html), [properties](https://docs.godotengine.org/en/stable/tutorials/3d/particles/properties.html), [creating a system](https://docs.godotengine.org/en/stable/tutorials/3d/particles/creating_a_3d_particle_system.html)):
- One-shot burst: `one_shot = true` (*"emit `amount` particles and then disable itself"*) plus `explosiveness = 1` (*"all `amount` particles emit at the same time"*). The `finished` signal fires when all particles are done, which is when to free the node.
- Mesh fragments: put a low-poly chunk mesh in `draw_pass_1`. *"You can use up to 4 draw passes ... Each pass can render a different mesh with its own unique material"*, and *"All draw passes use the data that is computed by the process material."* From that wording, every particle is drawn once per pass, so extra passes don't give per-particle mesh variety. For variety, use 2–3 emitters with different chunk meshes, or one mesh with per-particle random rotation and scale (`ParticleProcessMaterial` angle and scale ranges). Tint chunks with the body colour through the draw-pass material.
- **Compatibility limits** (4.7 source): *"Particle trails / sub-emitters are only available when using the Forward+ or Mobile renderer"* ([`gpu_particles_3d.cpp`](https://github.com/godotengine/godot/blob/4.7-stable/scene/3d/gpu_particles_3d.cpp) lines 430–436). The GLES3 backend also warns that it *"does not support manually emitting particles"*, and that *"Vector field particle attractors"* and *"SDF Particle Colliders are not available"*. It uses transform feedback to process particles. Hard stop: *"Due to driver bugs, GPUParticles are not supported on Adreno 3XX devices. Please use CPUParticles instead."* ([`drivers/gles3/storage/particles_storage.cpp`](https://github.com/godotengine/godot/blob/4.7-stable/drivers/gles3/storage/particles_storage.cpp) lines 124, 303–392, 674, 707). The renderer table agrees: trails and SDF collision aren't supported on Compatibility ([renderers](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)).
- `emit_particle()` (*"only supported on the Forward+ and Mobile rendering methods, not Compatibility"*) is the only way to place individual GPU particles from script. On Compatibility, emission placement must come from the process material (sphere or box shape, or emission points baked from the mesh).
- **Stutter:** ubershaders and pipeline precompilation apply *"only ... to the Forward+ and Mobile renderers, not Compatibility"*. On Forward+ and Mobile (4.4+), pipelines are precompiled *"as long as the scene is instantiated at least once ... even if it's completely invisible"*. Compatibility needs the legacy warm-up: *"displaying them for at least one frame in the view frustum"* during load ([pipeline compilations](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html)). Plan a warm-up step that shows one burst of each break effect behind the loading screen.

**CPUParticles3D** ([class](https://docs.godotengine.org/en/stable/classes/class_cpuparticles3d.html), [particles overview](https://docs.godotengine.org/en/stable/tutorials/3d/particles/index.html)):
- *"Work on a wider range of hardware and provide better support for older devices and mobile phones"*, but *"are not as performant ... and can't render as many individual particles"*. It loses multiple draw passes, turbulence, sub-emitters, trails, attractors and collision. A single `mesh` property gives one chunk mesh per emitter. `convert_from_particles()` and the editor menu convert a GPU setup to CPU.
- Emission points are a plain array that GDScript can fill on any renderer, for example from the broken mesh's vertices. That is the easy way to make chunks start on the body's surface on Compatibility.
- A break burst is tens of chunks, so CPU cost is small. Simulation runs on the main thread, which the N-body gravity loop also uses.

**Lifecycle.** The emitter must outlive the body, so don't free it with the Character. Either reparent it to the level at break time (keep `local_coords = false` so chunks stay in world space), or hide `Visual`, disable the collider and free the body on `finished`. The second keeps the emitter under the body, but the body must stop moving.

**Recommendation.** Use one break scene with `GPUParticles3D` on both renderers, and add a `CPUParticles3D` twin for the Adreno 3xx fallback. Pick it at runtime with `RenderingServer.get_video_adapter_name()` or a per-device setting. Keep amounts small: 8–24 chunks plus a few dust quads.

## 6. Floating Face following the deformation

| Approach | Face follows? | How |
|---|---|---|
| Transform squash/swell on `Visual` | Yes, for free | Face is a child of `Visual` (outside `Tumble`). Its plane squashes with the body. |
| Tween on `Visual` | Yes, for free | Same as above. |
| Vertex-shader wobble | No, not by itself | Children never see vertex displacement. Run the same deformation function in the face's shader (shared `.gdshaderinc`, same instance uniforms set on both instances), evaluated at the face's anchor point and applied to its vertices in world space. |
| `billboard_mode` + `billboard_keep_scale` | Partly | Keep-scale multiplies by `length(MODEL_MATRIX[i].xyz)` per axis ([`material.cpp`](https://github.com/godotengine/godot/blob/4.7-stable/scene/resources/material.cpp) lines 1234–1255). A squash along a diagonal axis comes out as the wrong per-axis stretch, and the squash direction is lost. Avoid. |

Billboarding isn't needed. ADR 0007 fixes the camera's yaw and tilt, so a quad with a constant world orientation always faces the camera. `FaceAnchor` only has to cancel the body's Y rotation (`basis = body.global_basis.inverse() * fixed_face_basis`) and sit at `centre + toward_camera * radius`. Because the face is a real transform child, squash flows into it. It still depth-tests against other bodies normally (a map standing decision).

## Not verified

- Measured phone frame cost of any approach. Everything above is reasoning from the engine code paths; the min-spec phone (`android-min-spec-phone.md`) should run a prototype with ~20 squashing Characters and a few simultaneous break bursts on both renderers.
- That `instance uniform` works on every Mali/Adreno GLES3 driver. The docs list only the texture-array caveat.
- Whether a vertex-shader wobble also moves the body's shadow on each renderer (the shadow pass runs the material's vertex function, but this wasn't checked in source).
