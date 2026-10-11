# How can Godot do N-body gravity and orbits?

Research for [#24](https://github.com/snackpackgames/Rubbley/issues/24), part of map [#20](https://github.com/snackpackgames/Rubbley/issues/20). Researched 2026-10-11 against the Godot 4.7 stable docs and the `master` branch (4.8-dev) of `godotengine/godot`.

## Short answer

Godot has no built-in mutual (N-body) gravity. It gives you three building blocks:

1. **Script forces**: compute the pairwise forces yourself and push them into the physics engine with `apply_central_force` (from `_physics_process` or `_integrate_forces`). This is the direct port of `Attractor.cs`, and the only option that gives true two-way, mass-dependent Newtonian gravity.
2. **Area point gravity**: an `Area2D`/`Area3D` with `gravity_point = true` pulls every rigid body inside its shape toward a point, with optional inverse-square falloff. It is native and cheap, but one-way and mass-independent (an acceleration, not a force). It fits fixed gravity wells and "planets".
3. **Custom integrator**: `custom_integrator = true` turns off the engine's force integration for that body, and you own its velocity in `_integrate_forces`. Collision response still runs. Use it for bodies that should follow a scripted path, such as the `Orbit.cs` "captured" state, without leaving the physics world.

Both engines (Godot Physics 2D/3D and Jolt 3D) integrate with semi-implicit (symplectic) Euler. That integrator keeps orbits bounded at a fixed timestep, so dynamic orbits are feasible. The `Orbit.cs` kinematic pivot is not required for stability.

## Unity reference behaviour

- `Assets/Scripts/Attractor.cs`: every `Attractor` calls `FindObjectsOfType<Attractor>()` in each `FixedUpdate` and applies `G * m1 * m2 / d^2` (G = 66.74) to every other body via `AddForce`. Each pair is computed twice (once from each side), and the per-tick `FindObjectsOfType` adds a scene scan per body. A `gravigaTarget` / `gravigaMultiplier` scales the pull on one chosen body; this is the hook for Attract and Repel.
- `Assets/Scripts/Orbit.cs`: when a lighter `Attractor` enters a heavier body's trigger sphere, the script makes it kinematic, reparents it under a new pivot, and rotates the pivot a fixed angle per `FixedUpdate`. This is a scripted circular orbit, not physics.
- GDD (`docs/gdd/rubbley-gdd.md`, Resources > Mass): "When Rubbley has more mass, the Graviga draws and repels the body from Rubbley as the center point. When the other body has more mass, Rubbley is drawn to and repelled from the other body as the center point." The rule is mass-relative, so the gravity model must know both masses.

## Option 1: script-computed pairwise forces

**How it works.** Each physics tick, loop over the bodies, compute `F = G * m_a * m_b / max(d^2, eps)` along the line between them, and call `apply_central_force(F)` on one body and `apply_central_force(-F)` on the other.

- `RigidBody2D/3D.apply_central_force`: "Applies a directional force without affecting rotation." On the direct state: "A force is time dependent and meant to be applied every physics update." ([PhysicsDirectBodyState3D](https://docs.godotengine.org/en/stable/classes/class_physicsdirectbodystate3d.html), [RigidBody2D](https://docs.godotengine.org/en/stable/classes/class_rigidbody2d.html))
- `_integrate_forces(state)` is "Called during physics processing, allowing you to read and safely modify the simulation state for the object. By default, it is called before the standard force integration." ([RigidBody3D](https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html))
- The rigid body tutorial says to steer rigid bodies by adding forces or impulses, or by setting velocity, in `_integrate_forces()`. It warns that setting the transform every frame stops the engine from "correctly simulat[ing]" the body. ([Rigid body tutorial](https://docs.godotengine.org/en/stable/tutorials/physics/rigid_body.html))

**Where the force goes in.** In Godot Physics 2D, accumulated forces are integrated as `force = gravity * mass + applied_force + constant_force; linear_velocity += inv_mass * force * step`, and then position advances by `linear_velocity * step` ([`godot_body_2d.cpp`](https://github.com/godotengine/godot/blob/master/modules/godot_physics_2d/godot_body_2d.cpp), `integrate_forces` / `integrate_velocities`). Jolt adds Godot's gravity as a force (`AddForce(total_gravity / inverse_mass + constant_force)`) and integrates in Jolt ([`jolt_body_3d.cpp`](https://github.com/godotengine/godot/blob/master/modules/jolt_physics/objects/jolt_body_3d.cpp)).

**Recommended shape.** Use one manager node (a "gravity system") that owns the body list and computes each pair once (N(N-1)/2 pairs, using Newton's third law). Don't have every body scan the scene the way `Attractor.cs` does. Attract and Repel then become per-pair multipliers (Repel = negative), and the GDD's "heavier body is the centre" rule becomes a per-pair decision in the same loop, for example applying force only to the lighter body. That is a design question, not an engine one.

**Cost.** The work is O(N^2) per tick. Each pair is a subtraction, a length-squared, a division, and two force calls. The engine calls cost the same from any language. The loop arithmetic is what varies. Godot's CPU optimisation guide says that in GDScript "ease of use is considered more important than performance". It calls C# "a good compromise between speed and ease of use" (with GC pauses as a risk), and says "Using C++ will usually result in the fastest code" (via GDExtension) ([CPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html)). Neither the docs nor the source publish per-body figures for mobile. If the scene stays in the tens of attractors, the pair loop is small. It still needs a device benchmark before it is trusted at 60 Hz on a low-end phone (see open questions).

**2D vs 3D.** Same API on `RigidBody2D` and `RigidBody3D`. In 2D, units are pixels (Area2D default gravity is 980 px/s^2). In 3D, units are metres.

## Option 2: Area point gravity

**How it works.** Set `gravity_space_override` to a non-disabled mode, set `gravity_point = true`, and set `gravity_point_center` and `gravity`. With `gravity_point_unit_distance > 0`, "The gravity will have falloff according to the inverse square law"; at 0 "the gravity will be constant regardless of distance" ([Area3D](https://docs.godotengine.org/en/stable/classes/class_area3d.html), [Area2D](https://docs.godotengine.org/en/stable/classes/class_area2d.html)).

The formula, identical in Godot Physics 2D, Godot Physics 3D, and Jolt:

```
v = area_transform.xform(gravity_point_center) - body_origin
g = gravity * unit_distance^2 / |v|^2   (direction v.normalized())
```

Sources: `GodotArea2D::compute_gravity` ([godot_area_2d.cpp](https://github.com/godotengine/godot/blob/master/modules/godot_physics_2d/godot_area_2d.cpp)), `GodotArea3D::compute_gravity` ([godot_area_3d.cpp](https://github.com/godotengine/godot/blob/master/modules/godot_physics_3d/godot_area_3d.cpp)), `JoltArea3D::compute_gravity` ([jolt_area_3d.cpp](https://github.com/godotengine/godot/blob/master/modules/jolt_physics/objects/jolt_area_3d.cpp)).

What follows from that code:

- **The result is an acceleration, not a force.** The body multiplies it by its own mass (`gravity * mass` in Godot Physics, `total_gravity / inverse_mass` in Jolt), so every body in the area falls the same way regardless of mass. The pulled body's mass doesn't change anything, so the GDD's mass rules can't be expressed with Areas alone.
- **One-way.** The Area's owner feels no reaction, so there is no mutual attraction.
- **The centre is in the Area's local space** (`transform.xform(...)`). An Area parented to a moving body carries its well along with it. It only affects bodies whose shapes overlap the Area's shape.
- **Stacking.** Several overlapping areas combine in `priority` order using the `SpaceOverride` modes (Combine, Combine-Replace, Replace, Replace-Combine). "The World3D's physics is always processed last, after all areas." ([Area2D](https://docs.godotengine.org/en/stable/classes/class_area2d.html)) Set the project's default gravity to 0 for a space game.
- **Body scaling.** `gravity_scale` "Multiplies the gravity applied to the body", covering both default and Area gravity ([RigidBody2D](https://docs.godotengine.org/en/stable/classes/class_rigidbody2d.html)). That allows per-body tuning such as "Rubbley feels wells less", but it is still not mass-based.

**Cost.** The overlap test and the gravity sum run in native code inside the step. Jolt re-evaluates environmental gravity every step only for bodies inside a point-gravity area (`_needs_update_environmental_properties` returns true when `has_point_gravity`, [jolt_body_3d.cpp](https://github.com/godotengine/godot/blob/master/modules/jolt_physics/objects/jolt_body_3d.cpp)). There is no script cost per body. This is the cheapest option, and it scales with overlaps, not N^2.

**Fit for Rubbley.** It is a good fit for the GDD's untargeted Attract ("place a gravity well at the center of the pinch gesture" for a duration): spawn an Area with point gravity, then free it. It also suits static celestial bodies that should pull everything near them. It doesn't fit mutual or mass-relative pulls.

## Option 3: custom integrator (scripted motion inside physics)

- `custom_integrator`: "If true, the standard force integration (like gravity or damping) will be disabled for this body. Other than collision response, the body will only move as determined by the `_integrate_forces()` method" ([RigidBody3D](https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html)).
- Gotcha: with `custom_integrator` on, Jolt's `apply_force`/`apply_central_force` return early and do nothing ([jolt_body_3d.cpp](https://github.com/godotengine/godot/blob/master/modules/jolt_physics/objects/jolt_body_3d.cpp), `apply_central_force`). In Godot Physics 2D the force is accumulated but the integration block is skipped (`if (!omit_force_integration)`, [godot_body_2d.cpp](https://github.com/godotengine/godot/blob/master/modules/godot_physics_2d/godot_body_2d.cpp)). Either way you must set `state.linear_velocity` yourself.
- Use: a captured body's velocity can be set each tick to the tangent of a circle around its parent, which keeps collisions working. This is the physics-friendly port of `Orbit.cs`.

**Alternative for `Orbit.cs`: freeze it.** `freeze = true` with `FREEZE_MODE_KINEMATIC`: "Similar to FREEZE_MODE_STATIC, but collides with other bodies along its path when moved. Useful for a frozen body that needs to be animated" ([RigidBody3D](https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html)). For kinematic bodies Godot derives the velocity from the transform change (`linear_velocity = motion / step`, [godot_body_2d.cpp](https://github.com/godotengine/godot/blob/master/modules/godot_physics_2d/godot_body_2d.cpp)), so the body pushes what it hits. This is the closest match to Unity's `isKinematic` plus a rotating pivot, and it is easy to unfreeze when Repel breaks the orbit.

## Option 4: integrator fully outside the physics engine

You can also simulate positions in your own code (for example, a packed array of positions and velocities in C#/C++, or a fixed-step loop in `_physics_process`) and write transforms to nodes, `AnimatableBody`, or frozen kinematic bodies. That gives full control over the integrator (leapfrog/Verlet, sub-stepping) and determinism, but you lose engine collision response for those bodies unless they are kinematic. You also own every interaction with real rigid bodies. The servers doc notes that the scene system's cost only matters at "tens of thousands of instances", and that reading values back from servers can stall them ([Using servers](https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html)). At Rubbley's likely scale, the main reason to do this is control, not speed.

## Orbit stability

- Godot Physics integrates velocity first and then position with the new velocity (semi-implicit Euler; see `integrate_forces` then `integrate_velocities` in [godot_body_2d.cpp](https://github.com/godotengine/godot/blob/master/modules/godot_physics_2d/godot_body_2d.cpp)).
- Jolt's docs: "Jolt Physics uses a Symplectic Euler integrator" ([Jolt Physics docs](https://jrouwe.github.io/JoltPhysics/)).
- Symplectic Euler keeps energy bounded at a fixed timestep, so a dynamic body given the circular speed `v = sqrt(G*M/r)` keeps orbiting instead of spiralling out. Problems come from close passes (force blows up as d goes to 0, so clamp `d^2` with an epsilon or softening term), damping (keep `linear_damp` at 0 for orbiters), and changing the tick rate. Godot's interpolation intro warns that at a different tick rate "the physics will behave completely differently" ([Physics interpolation intro](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html)).

## 2D vs 3D physics for a 2.5D game

- **3D physics:** Jolt is the default for new 3D projects since 4.6: "make Jolt the default physics engine for all new 3D projects" ([Godot 4.6 release](https://godotengine.org/releases/4.6/)). Lock the vertical axis with `axis_lock_linear_y` ("Lock the body's linear movement in the Y axis") ([PhysicsBody3D](https://docs.godotengine.org/en/stable/classes/class_physicsbody3d.html)). Area point gravity and `_integrate_forces` work the same as in Godot Physics, with the `custom_integrator` force gotcha above. The Jolt page lists joint gaps and calls thread safety "experimental" but says nothing about gravity ([Using Jolt Physics](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html)).
- **2D physics:** Only Godot Physics 2D is built in (Jolt is 3D-only). The game is top-down on a plane, so 2D physics with 3D rendering is viable, but you have to sync 2D bodies to 3D visuals yourself. All the APIs above exist in 2D with pixel units.
- **Interpolation:** Physics interpolation landed for 2D in 4.3 and for 3D in 4.4: "Mobile games in particular benefit from this change, since you can now lower the tick rate" ([Godot 4.4 release](https://godotengine.org/releases/4.4/)). The CPU optimisation guide says dropping from 60 to 30 or 20 Hz "can greatly reduce CPU load". It also notes that the trade-offs are jitter and input lag, and it recommends keeping 60 Hz for real-time player movement ([CPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html)).

## Language note (mobile)

C# on mobile: "Android support is currently experimental", "iOS support is currently experimental and has a few limitations", and "projects written in C# cannot be exported to the web platform" ([C# docs](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/index.html)). If the gravity loop turns out too slow in GDScript, the mobile-safe fast path is GDExtension (C++/Rust), not C#.

## Comparison

| Option | Mutual / mass-aware | Per-body cost | Engine support | Best fit in Rubbley |
|---|---|---|---|---|
| Script pairwise forces | Yes | O(N^2) script loop + native force calls | 2D, 3D, Jolt | Celestial bodies attracting each other and Rubbley, Attract/Repel multipliers |
| Area point gravity | No (one-way acceleration) | Native, per overlap | 2D, 3D, Jolt (same formula) | Placed gravity wells, fixed planets |
| Custom integrator / kinematic freeze | n/a (scripted) | One callback per body | 2D, 3D, Jolt (Jolt ignores forces) | `Orbit.cs` captured-orbit state |
| Own integrator outside physics | Yes | Your code | Any | Only if determinism or a custom integrator is needed |

A hybrid seems likely: Option 1 for the body-to-body Graviga rules, Option 2 for spawned wells, and a kinematic freeze or custom integrator for captured orbits. That is a design call for the map, not a finding.

## Open questions surfaced

- **Physics dimension:** 2D physics + 3D rendering, or 3D physics (Jolt) with a locked axis? This affects every gameplay system.
- **Scripting language:** GDScript vs GDExtension for the gravity loop. C# is experimental on Android/iOS.
- **Captured orbits:** emergent (dynamic bodies at circular speed), or scripted (kinematic freeze, like `Orbit.cs`)? This decides whether Repel can "slingshot" bodies out of orbit naturally.
- **Mass rule semantics:** does force apply to both bodies (Newtonian), or only to the lighter one (the GDD's "centre point" reading)?
- **Physics tick rate and interpolation:** settle these on a target device. No primary source gives per-body mobile cost, so a benchmark spike is needed (N = 10/50/200 attractors on a low-end Android device).
