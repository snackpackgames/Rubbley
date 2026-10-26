# Feature folders, few autoloads, composed bodies and thin nodes

The Godot project keeps each feature in its own folder under `game/`. Only app-lifetime state is an autoload, and everything that belongs to a level is a node in that level. Bodies get behaviour from component child nodes, game rules live in plain classes, and nodes are thin adapters around them. These conventions keep the project readable for agents: every dependency can be traced through a path, an `@export` or a signal, and the rules can be tested headless.

## Folders

```
game/
  gravity/      gravity_system.gd, gravity_solver.gd, gravity_body.gd
  input/        move_input.gd, recognisers/
  camera/       camera_rig.tscn
  bodies/
    rubbley/    rubbley.tscn, asteroid.glb (Rubbley's placeholder body, ADR 0008)
  levels/
  ui/
  store/
  common/       only code that two or more features actually share
```

A feature folder holds that feature's scenes, scripts, resources and imported assets together. Tests mirror it, for example `test/unit/game/gravity/` (ADR 0011).

## Conventions

- **Autoloads hold only app-lifetime state that outlives any level.** The list starts as Move Input (ADR 0013), Platform Services and Save/Settings. Adding one means amending this ADR.
- **Call down, signal up.** A parent calls its children directly. A child emits signals and never reaches up. Siblings talk through their parent, and app-wide services go through autoloads. Per-tick data such as the Move Input frame is polled, not signalled. There is no global event bus.
- **Composition by default.** Gravity participation and targetability are component child nodes, for example a `GravityBody` under a `RigidBody3D`. Script inheritance goes at most one level below a Godot type or a small Rubbley base. Inherited scenes are only for variants of one asset, such as an Anchored planet. Capture-ability and a primary's Capture Radius are type-wide values in the body Tuning (ADR 0017), not components.
- **Rules in plain classes, nodes as adapters.** Logic worth testing lives in `RefCounted` classes with no Node or singleton access. Nodes adapt them to the scene tree.
- **One persistent `Main` scene** owns the current level, the UI layer and transitions, and swaps levels in and out as children. Nothing calls `change_scene_to_file`, and there is no scene-manager autoload. Unloading a level is an interruption (ADR 0013).
- **References** are typed `@export` node references or `%Unique` lookups inside the node's own scene. Absolute paths (`/root/...`) and upward `get_parent()`/`get_node("..")` chains are not allowed.

## Gravity wiring

- A `GravityBody` component holds the body's role (Celestial, Passive or Anchored) and its current Gravega multiplier, and adds itself to the `gravity_bodies` group. Mass is read from `RigidBody3D.mass`, not stored twice. An Anchored GravityBody freezes its body and points at an `AnchoredPull` Area, whose point gravity the system sets each tick; the solver leaves Anchored Bodies out. A `Targetable` component joins its own group, and the targetable-bodies query in ADR 0013 reads that group.
- The level's `GravitySystem` node reads the group every tick, in tree order. There is no explicit register or unregister step, so bodies placed in the editor and bodies spawned at runtime are handled the same way, and freed bodies simply drop out.
- `GravitySolver` is the "bodies in, forces out" seam from ADR 0005: a plain class that takes packed arrays of positions, masses, roles and multipliers and returns forces.
- `GravitySystem` adds up its contributors in a fixed order: the pairwise solver, then capture assist, then Drift (ADR 0006). Each contributor has the same shape as the solver: per-body packed arrays in, one force per body out, though each takes only the arrays it needs (capture assist also reads velocities, damping and the capture values). The system then calls `apply_central_force` once per body. It runs after gameplay in the physics tick (a later `process_physics_priority`), so this tick's Attract and Repel multipliers apply this tick.

## Considered Options

- **Type folders (`scenes/`, `scripts/`, `models/`)**: rejected. One feature would be spread across three trees.
- **Gravity as an autoload**: rejected. Level state would leak between levels, and every test would share one system.
- **A global event bus**: rejected. It hides who listens to what.
- **Explicit `register()`/`unregister()` with a cached list**: rejected. The component would need a reference up to the system, which the reference rules forbid, and it would have to unregister when freed.
- **Each contributor applies its own forces**: rejected. Force application would be spread across nodes, so it would be harder to test or cap.
- **`change_scene_to_file`**: rejected. The UI and transitions would not survive a level change without a scene-manager autoload.
