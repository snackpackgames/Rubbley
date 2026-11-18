# Restoring a physics stage on respawn in Godot 4.7

Researched 2026-11-18 for [#152](https://github.com/snackpackgames/Rubbley/issues/152), on the death map [#143](https://github.com/snackpackgames/Rubbley/issues/143).

**Question:** what are the ways to restore a Godot 4.7 physics stage on respawn? Compare reloading the scene, restoring a snapshot, and resetting each body in place for a stage in Rubbley's Godot 4.7 project. Cover RigidBody3D state (transforms, velocities, sleeping, mass), gravity bodies and Orbits, Debris already absorbed and freed, seeded DebrisField RNG, and the camera rig. What does each cost in load time and hitches on the Minimum-Spec Device, and what does each mean for the banded sim tests (ADR 0018)?

Whether checkpoints exist is still open ([#151](https://github.com/snackpackgames/Rubbley/issues/151)), so this covers both a full stage restart and a mid-stage checkpoint restore.

## Answer

- **For a full stage restart, reload the level.** `Main.load_level()` already frees the current level and instantiates a fresh copy of its `PackedScene` ([ADR 0016](../adr/0016-architecture-conventions.md)). Calling it again with the same scene puts back every body, Orbit, absorbed Debris piece, timer and camera value. There is nothing to forget. On a desktop i7-13700K, headless, it takes about **4.5–5 ms** of CPU for the sandbox level (52 rigid bodies): about 1–2 ms to free the old level, then about 3.3 ms to instantiate and run `_ready`. The phone will be several times slower, but this should still fit inside a death animation or a fade. This measurement has no GPU work; see "Costs".
- **`SceneTree.reload_current_scene()` is the wrong tool for Rubbley.** The current scene is `Main`, so it would reload the UI and the whole app. ADR 0016 also forbids `change_scene_*`.
- **Resetting each body in place is about 15× cheaper** (about 0.27 ms for 52 bodies on the same desktop). But Rubbley's state is not only in bodies. About 20 fields in 15 classes hold live state: Stamina, Drift's carried velocity, Gravega multipliers, the Gravity Well, the Spin timer, stuns, the camera's follow and zoom, and more. Each one needs a reset path, and any field that is missed becomes a bug that a fresh start can never show. Absorbed Debris is freed, so it has to be re-instantiated anyway.
- **A snapshot is resetting in place with recorded values.** A snapshot for Rubbley means a record of each body's transform, velocities and mass, plus the gameplay state, written back in place. Godot has no built-in "save this live world" call. `PackedScene.pack()` skips nodes without an owner, and runtime-spawned Debris has none. `Node.duplicate()` of a live level re-runs every `_ready` when the copy is added: tested, the 52-body sandbox came back with 100 bodies because each DebrisField scattered a second set.
- **A mid-stage checkpoint is where the approaches differ.** With a reload, the checkpoint shows the stage as it was at the start, with Rubbley moved to the checkpoint. Any "what changed before the checkpoint" (absorbed Debris, defeated enemies) has to be applied on top. Only a snapshot can bring back orbiting Debris where it actually was when the checkpoint was reached. Which of these the player should see is a design question (see "Open questions").
- **A restart is not the same stage today.** DebrisField seeds the scatter, but each piece's size, and so its Mass, comes from global `randf()`/`randi()` in `DebrisLook`. So does every body's starting spin, in `PlayPlaneBody`. A reload therefore lays out the same positions with different Debris masses and spins. That breaks ADR 0018's "RNG passed in" rule. It matters for a score chaser and for any test that asserts "restart gives the same stage".
- **For tests (ADR 0018):** a reload restores the same way the sim tests already build a stage (fresh instances of shipped scenes), so a restore test is short and cheap. Resetting in place needs a test per stateful field, plus banded "after restore plays like a fresh start" scenarios, because Jolt's internal state after a teleport is not the same as after a fresh build. Neither approach replays a run exactly, and ADR 0018 says nothing should rely on that.

## Comparison

| | Reload the level (`Main.load_level`) | Snapshot (record, then write back) | Reset each body in place (to stage-start values) |
|---|---|---|---|
| **What it restores** | Everything in the level: bodies, Debris (including absorbed pieces), Orbits, Stamina, modifiers, Gravity Wells, stuns, camera, Drift, level scripts. Positions from the seeded scatter come back exactly. | Whatever the snapshot records, as of the moment it was taken. This is the only way to bring back mid-stage motion (orbiting Debris where it was at the checkpoint). | Whatever reset code exists, back to stage-start values stored at load. |
| **What it misses** | Autoload state (Move Input still needs `interrupt()`, which `load_level` already does). Debris masses and spins change, because of the unseeded global RNG. At a checkpoint, mid-stage world state is lost unless it is applied on top. | Unrecorded fields. Absorbed (freed) Debris has to be re-instantiated, and it gets a new random size. Jolt-internal state (contact cache, sleep timers) is not captured. | Same as the snapshot, plus every field nobody wrote a reset for. Freed nodes are gone. |
| **CPU cost (desktop, headless, sandbox, 52 bodies)** | about 1–2 ms free + about 3.3 ms instantiate and `_ready` (median of 21; worst 4.5–10 ms). | Recording about 0.24 ms; writing back about 0.27 ms (median), plus instantiating any absorbed Debris. `Node.duplicate()` as a snapshot: 7.6 ms, and it is broken (see above). | about 0.27 ms (median of 21) for transform, velocities, mass and `reset_physics_interpolation()` on 52 bodies. |
| **Hitch risk on the phone** | One spike frame on the CPU. It grows with body count and `_ready` work, mainly DebrisField spawning. GPU: the materials and meshes are already loaded and compiled, so a re-add should be cheap (reasoned, not measured; see Costs). It can be hidden behind the explosion or a fade, or pre-instantiated off the tree. | Small, unless many absorbed pieces have to be re-instantiated. | Smallest. |
| **Interpolation / teleport** | Automatic: Node3D resets interpolation when a node enters the tree. | Must call `reset_physics_interpolation()` after writing each transform. | Same as the snapshot. |
| **Correctness risk** | Low. A fresh start is the code path every play and every test already uses. | Medium to high: two code paths (build and restore) that must agree. | High: a reset path for every stateful field, kept in sync as features land. |
| **Sim tests (ADR 0018)** | One cheap test: build, play, die, reload, assert the start predicates. No new kind of test. | Tests per recorded field, plus banded "after restore" scenarios. | Tests per field, plus banded "after reset plays like a fresh start" scenarios. |

## 1. Reloading the level

### How Godot does it

- `SceneTree.change_scene_to_packed()` instantiates the new scene immediately. `change_scene_to_node()` removes the current scene from the tree right away. The old scene is deleted and the new one added in `_flush_scene_change()`, at the end of that process frame. [1][2]
- `reload_current_scene()` just calls `change_scene_to_file(current_scene.scene_file_path)`. That `ResourceLoader.load()`s the path (a cache hit if the `PackedScene` is still referenced) and instantiates it. [1]
- In Rubbley the current scene is `Main`, which by ADR 0016 is persistent and owns the level as a child. So `reload_current_scene()` would rebuild `Main`, the UI layer and transitions included. **Rubbley's "reload" is `Main.load_level(same_packed_scene)`.** It `remove_child`s and `queue_free`s the old level, then `instantiate()`s and `add_child`s the new one in the same call (`game/main/main.gd`). This matches what the "Change scenes manually" doc calls "delete the existing scene": memory is unloaded and processing stops. [3]
- **Load time:** `Main` holds `start_level` as an exported `PackedScene`, so the resource stays loaded. A second `load()` of the sandbox level took 14 µs (cache hit) against 115 ms cold. `ResourceLoader.load()` defaults to `CACHE_MODE_REUSE`. [4] A restart never touches disk.
- **Threading:** "creating scene chunks (nodes in tree arrangement) outside the active tree is fine". The scene can be instantiated on a worker thread and added on the main thread. The doc warns that resources shared across threads can be modified concurrently. [5] `load_threaded_request()` only helps the load step, which is already cached here. [4]
- **Physics interpolation:** when a Node3D enters the tree with physics interpolation on, Godot "always reset[s] FTI when entering tree". It also requests another reset at the end of the first tick or frame, in case the transform changes during it. Freshly spawned bodies therefore never streak from the origin. [6]

### What it restores in Rubbley

All of it: the RigidBody3D transforms and velocities from the `.tscn`, DebrisField's seeded positions and launch velocities, every Debris piece (absorbed pieces included, since they are spawned again), Rubbley's mass from `starting_mass_kg` through `RubbleyMass._ready`, Stamina, active modifiers, the Gravity Well (it is under `RubbleyMoves`, so it is freed with the level), Stunnable timers, `Drift._carried`, the sandbox meander, and a new `CameraRig`. `CameraFollow` and `CameraFraming` start with `_started = false`, so the first frame snaps the camera onto Rubbley at the size-driven zoom, with no swoop.

### What it doesn't restore

- **Global RNG.** `PlayPlaneBody._starting_spin()` uses `randfn`/`randf_range`, and `DebrisLook._ready()` uses `randi()` for the rock shape and `randf()` for the size (`body.mass *= size³`). After a reload, the Debris positions are the same, but every piece's shape, size and Mass are different, and so is every body's starting spin. The total Mass available in a stage therefore changes from one attempt to the next.
- **Autoloads.** Move Input is interrupted by `load_level` already, so a move held through death is released.
- **Static state.** `DebrisLook`'s static mesh and shape pool survives the reload. It is keyed on the `ChippedRockTuning` and seeded per shape, so this is harmless and useful: the 8 rocks are not rebuilt (`DebrisLook._meshes.size()` stayed 8 across 6 reloads).

### Checkpoint restore by reload

A reload gives the stage-start world. To resume at a checkpoint, the level would reload, then:

1. move Rubbley to the checkpoint, before the first physics tick or with `reset_physics_interpolation()`;
2. apply whatever the checkpoint records: Mass, which Debris pieces were absorbed, enemies defeated, and so on.

Removing absorbed Debris needs a stable identity per piece, such as DebrisField plus spawn index, which the seeded scatter already makes reproducible. Orbiting Debris starts again from its t = 0 positions, not where it was at the checkpoint.

## 2. Restoring a snapshot

Godot has no API that captures and restores a live physics world.

- **`PackedScene.pack()`** saves "the path node, and all owned sub-nodes". A node without an owner is not saved. [7] DebrisField's `add_child(piece)` sets no owner, so packing a live level drops every Debris piece. Non-exported script variables (Stamina, timers) are not stored properties either.
- **`Node.duplicate()`** copies children whether or not they have an owner [8], and `DUPLICATE_INTERNAL_STATE` also copies non-storage variables. [9] But adding the copy runs every `_ready` again. **Tested:** duplicating the live 52-body sandbox gave 52 bodies out of the tree and 100 after `add_child`, because each DebrisField scattered a second set. Duplicating took 7.6 ms, about 20× an `instantiate()`. The copy kept Rubbley's velocity, but re-running `_ready` also resets anything set there, such as `RubbleyMass` setting his Mass to `starting_mass_kg`. Not usable as-is.
- **A hand-rolled snapshot** is the practical version. It records each body's `global_transform`, `linear_velocity`, `angular_velocity` and `mass`, plus the gameplay state (Rubbley's Mass, Stamina, modifiers, live Debris identities), then writes them back as in section 3. Recording 52 bodies took about 0.24 ms on desktop.

A snapshot is the only approach that can put the stage back as it was at a checkpoint, mid-motion. It has all of section 3's costs. On top of those:

- **Absorbed pieces:** pieces absorbed after the snapshot must be instantiated again, with their recorded size and mass. Their recorded shape has to be forced too, because `DebrisLook._ready` would pick a random one.
- **Freed pieces:** a piece that was freed can't be "restored". It is a new node with a new physics RID.
- **Scale:** the snapshot grows with stage size, and it has to be taken at a moment when nothing is mid-collision.

## 3. Resetting each body in place

### RigidBody3D state, traced through Godot and Jolt

- **Transform.** Setting `global_transform` or `global_position` on a RigidBody3D sends `NOTIFICATION_TRANSFORM_CHANGED`. `CollisionObject3D` turns that into `body_set_state(BODY_STATE_TRANSFORM)`. [10] Jolt's `JoltBody3D::set_transform` calls `SetPositionAndRotation(..., DontActivate)` and then `_transform_changed()`, which calls `wake_up()`. [11]
  - The docs warn against doing this "very often" or every frame. [12][13] A one-off teleport on respawn is the case the docs allow ("If you only need to place a rigid body once...").
  - Inside `_integrate_forces`, Godot compares the node transform before and after the callback and pushes a changed one to the server, so it isn't overwritten. [14] `PlayPlaneBody` overrides `_integrate_forces` only to cap speed. A respawn can therefore set state from `_physics_process` or through `PhysicsDirectBodyState3D` in `_integrate_forces`. The latter is what the docs call "safe". [15]
- **Velocities.** `set_linear_velocity` and `set_angular_velocity` go straight to `body_set_state`. [14] Jolt sets the motion properties (`SetLinearVelocityClamped`) and wakes the body (`_motion_changed()`). [11]
- **Sleeping.** Setting the transform or a velocity wakes a Jolt body, as above. Setting `sleeping = true` goes through `space->set_is_object_sleeping()`. [11] A snapshot that records "was asleep" must therefore write it after the transform and velocities, or they will wake the body again. Under Rubbley's always-on gravity, bodies rarely sleep anyway.
- **Mass.** `set_mass` sends `BODY_PARAM_MASS`, and Jolt recomputes the mass properties. [11][14] Rubbley's Mass must go through `RubbleyMass._set_mass()`, which also resizes his collider shape (local to the scene) and his mesh. Setting `body.mass` alone would leave him the wrong size. Debris Mass was scaled by size in `DebrisLook._ready`, so it must be restored from a recorded value, not recomputed.
- **Forces already applied this tick.** `GravitySystem` calls `apply_central_force` at `process_physics_priority = 100`. Jolt adds that to the body's accumulated force (`AddForce`), and setting a transform does not clear it. [11] So a reset that runs after `GravitySystem` in a tick lets one tick of pre-reset forces act on the restored body. Run the reset before priority 100, at the start of the tick, or accept a one-tick nudge. (That Jolt clears accumulated forces after each step is standard Jolt behaviour; I did not trace it in this module.)
- **Interpolation.** With `physics/common/physics_interpolation=true`, a teleported body would visibly slide from the old spot to the new for a frame. Call `reset_physics_interpolation()` after setting the transform. The docs say to set the transform first and then reset, in that order. For a body that should be moving from the first frame, also set the transform it should have after the first tick. [16] An explicit reset also turns off Godot's deferred auto-reset for that node. [17] `CameraRig` sets its own interpolation to off, so it needs no reset.
- **Contacts.** Rubbley uses `body_entered` with contact monitoring. Teleporting him onto a body that is already there triggers `body_entered` on the next step and a collision-damage check. `RubbleyMass._velocities_before` holds velocities from the tick before the reset, keyed by body. A reset must clear it, or the damage check can use pre-death velocities. Jolt's internal contact cache and sleep timers are not reset by a teleport. This is unverified in detail, but it means the first ticks after a reset are not the same as a fresh build's.

### Gameplay state a reset must clear

From the current code (`grep "^var"` across `game/`), each of these needs a reset path:

| Owner | State |
|---|---|
| `RubbleyMass` | `body.mass` (through `_set_mass`), `_velocities_before` |
| `RubbleyLiveStats` | `_active` modifiers, `effective`, `stamina` (`Stamina._current`, `_idle_s`, `_used`) |
| `RubbleyMoves` | `_attracting_self`, `_attract_target`, `_gravity_well` (free the live Well, which keeps pulling) |
| `RubbleySpin` / `SpinTimer` | `_elapsed_s` |
| `AbsorbPop`, `RubbleyAttractCue` | `_elapsed_s`, `_time_s` (cosmetic) |
| `GravityBody` (every body) | `gravega_multiplier`, `pair_multipliers` |
| `Drift` (inside `GravitySystem`) | `_carried` |
| `Stunnable` | `_remaining_s` |
| `GravityWell` | `_age_s`, or free it |
| `PlayPlaneBody` | `_visual_spin` (cosmetic), and the angular velocity from `_starting_spin()` |
| `CameraFollow` | `_started`, `_followed_point`, `_nudge` |
| `CameraFraming` | `_started`, `_extent_m` |
| `SandboxLevel` (and future level scripts) | `_time_s`, `_heading_rad` |
| `Orbit` trackers (once gameplay holds them) | `_tracking`, `_travelled_rad` and the rest: history-based, so they must restart |
| Move Input (autoload) | `interrupt()` |

`CaptureAssist` and `GravitySolver` are stateless. The capture assist recomputes every tick from positions and velocities, so restored bodies are captured again naturally, but the `Orbit` predicate's "travelled 360°" history starts again. Anchored planets are frozen static, so only their cosmetic visual spin changes. A free planet needs a full reset.

**Absorbed and freed Debris.** `RubbleyMass._absorb_if_debris` calls `queue_free()`. The node and its physics RID are gone, so "in place" has to fall back to instantiating the scene again for those pieces. Because `GravityBody` joins its group in `_enter_tree`, `GravitySystem` picks the new pieces up automatically (ADR 0016). They get a new random rock and size, unless the RNG is seeded per piece.

**Camera.** With no reset, `CameraFollow` would ease from its last point to the respawn point at `follow_half_life_s`. On a long restart that is a swoop across the whole stage, clamped by `max_offset`, so Rubbley stays on screen. Whether that swoop is wanted is a design question. A snap needs a reset method on `CameraFollow` and `CameraFraming` (set `_started = false`). Neither class has one today.

### Cost

About 0.27 ms median for 52 bodies on desktop (transform, two velocities, mass, interpolation reset), with no measurable change in the next physics ticks. The gameplay-state resets are a few field writes each. On the phone this approach does not cause a hitch. Its cost is in code and correctness, not frame time.

## Costs on the Minimum-Spec Device

Measured on desktop only (i7-13700K, Windows 11, Godot 4.7.2 `--headless`, the sandbox level: 3 Anchored planets, Rubbley, 48 Debris). The scripts are in the session scratchpad, not the repo.

| Operation | Median | Worst seen |
|---|---|---|
| `load()` of the level, cold / cached | 115 ms / 14 µs | — |
| Free the level (`remove_child` + `free`) | 1.2–2.0 ms | 4.4 ms |
| `instantiate()` + `add_child` (`_ready`, Debris scatter) | 3.3 ms | 4.5–10 ms |
| `duplicate()` of the live level | 7.6 ms (one run) | — |
| Record 52 bodies' state | 0.24 ms (one run) | — |
| Write back 52 bodies' state + interpolation reset | 0.27 ms | 0.9–2.9 ms |

- **These are an indicator, not phone numbers.** The Galaxy A16's Exynos 1330 (2× A78 + 6× A55; [android-min-spec-phone.md](android-min-spec-phone.md)) is much slower per core than a 13700K. No ratio was measured. As an unverified rough bound, even a 10× slowdown puts a full reload at about 50 ms of CPU, or 3 frames at 60 Hz. That is fine behind an explosion or a fade, but visible if it lands mid-gameplay. Resetting in place stays under a frame. Measure on the device before deciding on cost grounds.
- **Headless means no GPU work.** The dummy renderer skips mesh upload and shader compilation. On a reload, Rubbley's materials and meshes are the same resources the `PackedScene` already holds, and `DebrisLook`'s meshes sit in a static pool. A reload should therefore create new render instances without uploading or compiling anything new. This is reasoned, not measured.
  - The known Compatibility-renderer freeze on low-end Android, [godot#102665](https://github.com/godotengine/godot/issues/102665) (open), happens "only the first time" a scene is shown after install. It is caused by `RenderingServer` work on viewport update. It bears on the first time a stage loads, and on the first explosion effect, not on a repeat of a stage already on screen.
- **Hiding the spike.** `Main.load_level` does everything in one frame. If on-device numbers show a visible hitch, the next level copy can be instantiated during the death sequence, or off the tree on a worker thread [5], and added when the screen is covered. This is cheap here, because the `PackedScene` stays cached.
- **Scaling.** Reload cost grows with node count and `_ready` work, mostly DebrisField's per-piece `instantiate()`. Reset-in-place cost grows only with body count. Real stages will be longer than the sandbox; how long is unknown ([#137](https://github.com/snackpackgames/Rubbley/issues/137)).

## What each approach means for the banded sim tests (ADR 0018)

- **Neither approach replays a run.** Jolt repeats itself only on "the same build, scene and call order" (ADR 0018). A reload gives new RIDs and global-RNG spins and sizes. A reset in place leaves Jolt's internal caches warm. Tests compare outcomes after a restore, never trajectories, which ADR 0018 already requires.
- **Reload tests** fit the existing pattern. A `SimulationTestSuite` builds the level, plays (for example, triggers Attract on self through the Move Input frame until Debris is absorbed), simulates a death, reloads, and asserts the stage-start predicates:
  - Rubbley at the spawn point with `starting_mass_kg`, and full Stamina;
  - the Debris count equals the sum of the field counts;
  - no Gravity Well;
  - each DebrisField's positions match its seeded scatter. This is checked before the first step, so the comparison is exact data, not a trajectory.

  Once the global RNG is replaced by RNGs passed in (ADR 0018's randomness rule), the same test can also assert identical Debris masses.
- **Reset-in-place and snapshot tests** need a unit test per reset path (each row in the state table above), since a missed field only shows up after a death. They also need banded feel scenarios run after a restore, for example "Capture still lands within 3 periods after a reset", with the 5 seeded variants. These show the warm-Jolt-state start plays inside the same bands as a fresh one. That is more tests to keep and more risk of quarantine.
- **Interpolation** can't be checked by outcome predicates. A unit test can assert `get_global_transform_interpolated()` equals the restored transform after the reset. Whether that is meaningful headless is unverified.

## Rubbley-specific notes

- **Reload is already built.** `Main.load_level()` exists and calls `MoveInputService.interrupt()`. A restart needs a way to call it again with the current level's scene. No death code exists yet, and `RubbleyMass._set_mass` clamps at the minimum, so nothing can reach "failed" today (#141).
- **The unseeded global RNG breaks "same stage on restart".** This affects `PlayPlaneBody._starting_spin()` and `DebrisLook._ready()`, and with them Debris Mass. Every approach that re-creates Debris (reload, or re-instantiating absorbed pieces) is affected. DebrisField already has `scatter_seed`; it could pass a per-piece seed or RNG down. This conflicts with ADR 0018's randomness rule as it stands.
- **The Gravity Well lives under `RubbleyMoves`.** A reload frees it. Any in-place approach must free it explicitly, or it keeps pulling for the rest of its lifetime.
- **Collision damage on respawn.** Respawning onto a body triggers `body_entered` damage. A stage-start spawn is clear by level design. A checkpoint spot can have Debris orbiting through it.
- **The `Orbit` predicate has no gameplay holder yet** (only tests use it). Whatever holds trackers later must reset them on restore, or be part of the level so a reload clears them.
- **Physics interpolation is on project-wide.** Reload gets the reset for free when nodes enter the tree. Any teleport needs `reset_physics_interpolation()` after the transform.

## Open questions for the user

1. **Checkpoints** ([#151](https://github.com/snackpackgames/Rubbley/issues/151)): if they exist, does a checkpoint bring back the world *as it was* when reached (orbiting Debris mid-motion, which needs a snapshot), or the stage-start world with Rubbley moved forward plus a record of what changed (reload plus overlay)?
2. **Is Debris already absorbed before a checkpoint gone after a restore, or back?** This changes how much Mass a struggling player can recover, which ties into the critical-state threshold (#143).
3. **What Mass does Rubbley come back with** at a checkpoint: stage-start Mass, the Mass he had at the checkpoint, or something else?
4. **Should a restart be the identical stage** (same Debris shapes, sizes and Mass totals, same spins)? For a score chaser this looks important. It means seeding `DebrisLook` and `PlayPlaneBody` from a passed-in RNG.
5. **Camera on respawn:** snap onto Rubbley (what a reload does) or ease over (what an in-place reset does without a camera reset)?
6. **What covers the restore:** the explosion, a fade, a short countdown? This decides how much hitch is acceptable, and whether pre-instantiating is worth it.
7. **Do Stat Modifiers picked up mid-stage (power-ups) survive a checkpoint restore?**

## Not verified

- **Phone timings.** All numbers are desktop and headless. There is no measured desktop-to-A16 ratio.
- **GPU cost of re-adding a level** in the Compatibility renderer on Mali: I reasoned that it needs no new upload or compile, but did not measure it.
- **Jolt clearing accumulated forces after each step,** and what a teleport does to Jolt's contact cache, warm starting and sleep timers. I read the Godot module's `set_transform` but not Jolt's step internals.
- **Whether `get_global_transform_interpolated()` is meaningful in headless test runs.**
- **The `ResourceCache` lifetime** ("cached while referenced"). The class docs say only that loaded resources are cached. Rubbley sidesteps this by holding the `PackedScene` in `Main`.

## Sources

Godot source is pinned to the `4.7.2-stable` tag, the version in `.godot-version`. Docs pages are the 4.7 "stable" docs, read 2026-11-18.

1. `SceneTree` scene change and reload: [scene/main/scene_tree.cpp L1673–1752](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/main/scene_tree.cpp#L1673-L1752), flush point in `process()` [L725](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/main/scene_tree.cpp#L725)
2. SceneTree class reference (`change_scene_to_node` order of operations, `reload_current_scene`): https://docs.godotengine.org/en/stable/classes/class_scenetree.html
3. Change scenes manually: https://docs.godotengine.org/en/stable/tutorials/scripting/change_scenes_manually.html
4. ResourceLoader class reference (`load` cache modes, `load_threaded_request`, `load_threaded_get`): https://docs.godotengine.org/en/stable/classes/class_resourceloader.html
5. Thread-safe APIs: https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html
6. Node3D enter-tree FTI reset: [scene/3d/node_3d.cpp L185–200](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/3d/node_3d.cpp#L185-L200)
7. PackedScene class reference (`pack` and the owner rule): https://docs.godotengine.org/en/stable/classes/class_packedscene.html
8. `Node::_duplicate` child loop: [scene/main/node.cpp L2889–2903](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/main/node.cpp#L2889-L2903)
9. Node class reference (`DuplicateFlags`, `physics_interpolation_mode`): https://docs.godotengine.org/en/stable/classes/class_node.html
10. `CollisionObject3D` transform sync: [scene/3d/physics/collision_object_3d.cpp L96–104](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/3d/physics/collision_object_3d.cpp#L96-L104)
11. Jolt body: [modules/jolt_physics/objects/jolt_body_3d.cpp](https://github.com/godotengine/godot/blob/4.7.2-stable/modules/jolt_physics/objects/jolt_body_3d.cpp): `_transform_changed`/`_motion_changed` wake ([L478–484](https://github.com/godotengine/godot/blob/4.7.2-stable/modules/jolt_physics/objects/jolt_body_3d.cpp#L478-L484)), `set_transform` ([L518](https://github.com/godotengine/godot/blob/4.7.2-stable/modules/jolt_physics/objects/jolt_body_3d.cpp#L518)), `set_is_sleeping` ([L691](https://github.com/godotengine/godot/blob/4.7.2-stable/modules/jolt_physics/objects/jolt_body_3d.cpp#L691)), `set_linear_velocity` ([L739](https://github.com/godotengine/godot/blob/4.7.2-stable/modules/jolt_physics/objects/jolt_body_3d.cpp#L739)), `apply_central_force` ([L899](https://github.com/godotengine/godot/blob/4.7.2-stable/modules/jolt_physics/objects/jolt_body_3d.cpp#L899)), `set_mass` ([L1195](https://github.com/godotengine/godot/blob/4.7.2-stable/modules/jolt_physics/objects/jolt_body_3d.cpp#L1195))
12. RigidBody3D class reference: https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html
13. Using RigidBody: https://docs.godotengine.org/en/stable/tutorials/physics/rigid_body.html
14. `RigidBody3D` node: [scene/3d/physics/rigid_body_3d.cpp](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/3d/physics/rigid_body_3d.cpp): `_body_state_changed` ([L170–187](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/3d/physics/rigid_body_3d.cpp#L170-L187)), `set_mass` ([L341](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/3d/physics/rigid_body_3d.cpp#L341)), `set_linear_velocity` ([L478](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/3d/physics/rigid_body_3d.cpp#L478)), `set_sleeping` ([L513](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/3d/physics/rigid_body_3d.cpp#L513))
15. PhysicsDirectBodyState3D class reference: https://docs.godotengine.org/en/stable/classes/class_physicsdirectbodystate3d.html
16. Using physics interpolation: https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/using_physics_interpolation.html
17. `Node::reset_physics_interpolation`: [scene/main/node.cpp L976–985](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/main/node.cpp#L976-L985)
18. Compatibility first-load freeze on low-end Android: [godotengine/godot#102665](https://github.com/godotengine/godot/issues/102665) (open, read 2026-11-18)
19. Rubbley code read: `game/main/main.gd`, `game/bodies/play_plane_body.gd`, `game/bodies/rubbley/rubbley_mass.gd`, `game/bodies/rubbley/rubbley_moves.gd`, `game/bodies/debris/debris_field.gd`, `game/bodies/debris/debris_look.gd`, `game/gravity/*.gd`, `game/camera/*.gd`, `game/levels/sandbox_level.tscn`; ADRs 0003, 0006, 0007, 0016, 0017, 0018.
