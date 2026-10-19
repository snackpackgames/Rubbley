# No reproducible physics; simulation tests assert bands over seeded variants

Nothing in Rubbley needs one run of the physics to replay exactly, so we don't try to make it. Leaderboards are per store and trust the client (ADR 0015), and there are no replays, ghosts or shared seeds. Jolt repeats itself on the same build, scene and call order, but Godot doesn't build it with cross-platform determinism, and lockstep would cost a fixed insertion order, recorded input and constant care. Instead, gameplay and tests judge outcomes, never trajectories. If replays ever arrive, they record body transforms per tick and play them back. They never re-simulate.

## Outcomes, not trajectories

- Level completion and puzzle checks are game-state predicates: a body is inside a goal Area, an enemy is stunned, a body is in Orbit. No game code or level compares positions to a recorded path, and every puzzle has to be solvable despite run-to-run variance.
- **Orbit** has one runtime predicate in a plain class. A body is in Orbit when it stays inside a multiple of its primary's Capture Radius, with its radius inside a band, and has travelled at least 360° around the primary. Those thresholds are Tuning (ADR 0017). Gameplay (capture Reactions, the capture assist) and tests both use this predicate, and tests never define their own.

## Two layers of physics tests

- **Math tests** cover the plain-class rules (ADR 0016): the pairwise solver, capture assist, Drift, the falloff of impulses and the Gravity Ripple, and the Stat fold. They feed in positions, masses and velocities, run without a physics server, and assert with float-epsilon equality (`is_equal_approx`). Most physics coverage lives here.
- **Simulation tests** step real Jolt. Each one builds a bare `Node3D` in code, adds a `GravitySystem` and instantiates the shipped body scenes with their shipped Tuning. There are no fixture `.tscn` files and no mock bodies. Moves are triggered through the Move Input frame type (ADR 0013), not InputEvents, so these tests run headless in `test/unit/` (ADR 0011). They assert outcome predicates within bands, never exact positions, and never the order signals arrive in.

## Stepping

- A shared test helper, `await step_seconds(s)`, awaits `get_tree().physics_frame` exactly `ceil(s × physics_ticks_per_second)` times. Each tick has a fixed delta however slowly the test runs.
- Scenarios are written in simulated seconds at the shipped tick rate, never in tick counts.
- gdUnit4's `simulate_frames` is not used for physics. It counts process frames or wall-clock time, not physics ticks.
- `scripts/test.sh` runs Godot with `--fixed-fps` equal to the physics tick rate, so headless runs go as fast as the CPU allows.

## Feel scenarios

The shipped-values suite's feel scenarios (ADR 0017) each run over **5 start conditions**: one canonical start plus four perturbed by a fixed-seed RNG (±5% speed, ±5° angle, ±5% distance). Every variant must pass, so "typical" covers a neighbourhood, not one lucky start. Every band is relative to the shipped Tuning it tests, so a retune moves the band with it, and each band has a one-line comment saying why it's that wide.

- **Capture**: a body released at 0.8 × Capture Radius, at 0.9–1.1× circular speed, is in Orbit within 3 orbital periods and stays in Orbit for 2 more.
- **Repel Pulse breaks Orbit**: from an established Orbit, a Repel Pulse leaves the body out of Orbit within 0.5 s and beyond 1.5 × Capture Radius within 2 s. It doesn't re-enter Orbit for the rest of the run.
- **Drift**: Rubbley in empty space covers at least 80% of the distance Drift alone should give (from Drift strength, his Mass and damping) over 5 s, measured after a 1 s settle.
- **A Gravity Well can't trap Rubbley**: Rubbley may stall in a Well, but he leaves its radius within the Well's lifetime plus 1 s. A Well can hold him briefly as a tactic but can never soft-lock him.

**Budget**: at most 10 simulated seconds per variant, and the whole shipped-values suite must finish within 60 s wall time on CI. The suite logs its time, and going over fails it.

## Flaky tests and quarantine

- No automatic retries. An intermittent failure is a bug: either the band is dishonest or the tuning sits too close to an edge.
- While that gets fixed, the test may be quarantined. It stays in the tree, skipped with gdUnit4's `do_skip`, and its `skip_reason` reads `quarantined-by: @<github-user> #<issue>`. The issue is labelled `flaky-test` and records the failing variant, the seed and a CI run link.
- `scripts/check.sh` fails on a skipped test whose reason doesn't match that format, or whose issue is closed.
- A release tag fails while any feel scenario is quarantined, because those scenarios guard the shipped feel. Other quarantined tests don't block a release.

## Randomness

Gameplay randomness (spawn jitter, debris scatter, enemy choices) comes from a `RandomNumberGenerator` that is passed in, never from global `randf()`/`randi()`, so tests can seed it. This is a Rubbley style rule (ADR 0014).

## Considered Options

- **Lockstep determinism** (fixed insertion order, Jolt single-threaded, recorded input, server-side score verification): rejected. No feature needs it, Godot doesn't guarantee it across platforms, and it constrains every system for ever.
- **Exact-position golden tests**: rejected. They break on any engine, Jolt or tuning change while telling us nothing about feel.
- **One canonical start per scenario**: rejected. It can pass on a single lucky start while the feel breaks next to it.
- **A test-only orbit check**: rejected. The game and tests would disagree about what Orbit is.
- **Retrying flaky tests**: rejected. Retries hide edge-of-tuning problems players would hit.
