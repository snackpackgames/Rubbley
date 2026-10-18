# Stats and Tuning as typed, read-only resources

Rubbley's numbers come in two kinds. **Stats** belong to a character and advancement can change them. **Tuning** is fixed and sets how the game feels and how the simulation behaves. When it's unclear which kind a value is, it starts in Tuning, because moving a value from Tuning to Stats later is cheap. Both kinds are typed `Resource` subclasses saved as text `.tres`. Each resource lives in the folder of the feature that owns it (ADR 0016) and reaches its node through a typed `@export`. Resources are read-only at runtime. Live values (current Mass, current Stamina, the active Gravega multiplier) sit in state objects that read their limits from the resource. Upgrades and power-ups are Stat Modifiers, which a plain class folds over the base Stats to make the effective Stats that Rubbley actually plays with.

## Format

- `class_name XStats extends Resource` or `XTuning extends Resource`, with typed `@export` fields, `@export_range` where a range makes sense, and a `##` doc comment on every field so it shows as an inspector tooltip.
- Godot units throughout: metres on the Play Plane, seconds, and mass in Godot's units. A rate carries its unit in the field name, for example `regen_per_second`.
- One resource per concern, for example `game/gravity/gravity_tuning.tres`, `game/input/input_tuning.tres` (ADR 0013), `game/camera/camera_tuning.tres` (ADR 0007), `game/bodies/rubbley/rubbley_stats.tres`, plus a body Tuning per body type. Nodes never `load("res://...")` their own tuning.
- Code never writes to a loaded resource. A loaded `.tres` is shared by reference, so writing to it would change every body that uses it, and the editor can save the change back to disk.

## What goes where

- **Rubbley's Stats**: starting Mass, his min–max Mass, and the Mass→size `Curve` that gives his visual and collider radius (the camera's zoom reads this, ADR 0007). The Stamina max, regen rate, `regen_delay` (starts at 0) and every move's cost: Attract drain per second on self and on a Celestial Body, and a fixed cost each for Repel, Repel Pulse and Spin. The Gravega values: the Attract multiplier on self and on a Celestial Body, the targeted Repel impulse, the Repel Pulse impulse, radius and stun duration, the Gravity Well's strength, radius and lifetime, and the Gravity Ripple's impulse and radius.
- **Tuning**: softening, max range, Capture Radius and the capture-assist strength, Drift strength, the Spin perfect window and shield size, the input thresholds (ADR 0013) and the camera values (ADR 0007).
- **Body Tuning** for each body type (asteroid, debris, each enemy) holds the type-wide values: speed cap, damping, CCD and whether the body can be captured. A placed body that needs different values gets a variant `.tres`, not per-instance override fields.
- **Mass is `RigidBody3D.mass`**, one number for health, gravitational weight and size. Damage that takes Rubbley's Mass from 10 to 7 really does weaken his pull and make him easier to fling. Other bodies set their mass on the node in the level scene, not in their body Tuning.
- **Rubbley is the only character with Stats for now.** Nothing upgrades other bodies. If difficulty scaling or enemy upgrades show up later, they use the same mechanism.
- A Gravity Well costing half the *current* Stamina is a rule in code, not a Stat.

## Stat Modifiers

- A Stat Modifier is a resource holding a stat id, an operation (add or multiply), a value and an optional duration. Owned upgrades, in-level power-ups and consumables are all Stat Modifiers.
- The stat id is a typed `enum` of Rubbley's stats. The fold uses a `match` on it to apply the modifier through typed field access, so no `get()`/`set()` by name. Adding a Stat means adding a field and an enum entry plus its `match` arm.
- A plain `RefCounted` class takes the base Stats and the active modifiers and returns a new effective Stats instance. It applies all adds first, then all multiplies. The fold runs at level load and again whenever a modifier is added or expires. Live state is then clamped to the new limits: Stamina is cut down to a smaller max, and Mass is held inside the min–max range.
- Save data (the Save/Settings autoload, ADR 0016) stores owned modifier ids, never folded numbers, so retuning an upgrade also reaches existing saves.

## Testing

- Unit tests build their own resources (`GravityTuning.new()`), set only the fields they assert on, and never load a shipped `.tres`. Retuning the game doesn't break them.
- A shipped-values suite in `test/unit/` (ADR 0011) stops a bad retune from breaking the game.
  - **Invariants** checked on every shipped Stats, Tuning and Stat Modifier `.tres`: min < max, positive speed caps, a Mass→size curve that only ever rises, the Capture Radius inside max range, a Stamina pool that covers at least one use of each move, input release points below press points, and every stat enum value handled by the fold.
  - **Feel scenarios** run short simulations on the shipped Tuning. A body released inside the Capture Radius at typical speed ends up in Orbit. Repel Pulse breaks that Orbit. Drift carries Rubbley a minimum distance per second. A Gravity Well can't trap Rubbley against Drift for good. Step counts and tolerances follow the reproducible-physics decision.
- There's no in-game tuning UI, in shipped builds or in playtest builds. Developers tune live with the remote inspector while running from the editor. If a debug panel is ever added, it edits a `duplicate()` of the resource, never the shared one.

## Considered Options

- **JSON or `ConfigFile`**: rejected. They lose static typing (ADR 0014), inspector editing and `Curve` values.
- **`const` values in scripts**: rejected. Consts can't vary per body type or per test, and every retune becomes a code change.
- **One big `tuning.tres`**: rejected. It merges badly and couples every feature together.
- **A separate health stat scaled into physics mass**: rejected. Two numbers for one idea would drift apart.
- **A whole Stats `.tres` per upgrade tier**: rejected. The tiers multiply across every stat, and power-ups can't stack.
- **`StringName` stat names applied with `get()`/`set()`**: rejected. Two edits per new Stat cost less than the one untyped path in otherwise typed code.
- **An in-game tuning panel**: deferred. The remote inspector covers developers, and a panel can be added later without breaking the read-only rule.
