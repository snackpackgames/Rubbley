# Pin Godot 4.7 at an exact patch version

Rubbley targets Godot 4.7, pinned to an exact patch release (4.7.2 at the time of writing). The version is set once in a checked-in `.godot-version` file, and CI, the `setup-godot` action and agents all read it. The project is mostly agent-built, so a failure has to be reproducible on the exact engine that produced it. Floating to the latest 4.7.x would let CI break without any commit to blame.

## Considered Options

- **Wait for 4.8**: rejected. 4.8 was still in dev snapshots and had no release date. Our test frameworks (gdUnit4 6.2.x supports 4.5–4.7, GUT 9.7.1 supports 4.7 only) would have to catch up after it ships. Nothing in 4.8 fixes a blocker we have, and waiting would stall every Godot decision after this one.
- **Pin the minor only (4.7.x, latest patch)**: rejected because builds could change with no change to the repo.

## Consequences

- A patch bump is a routine PR that changes `.godot-version` and has to pass CI.
- A minor bump (for example to 4.8) is a deliberate upgrade. It waits until that version is stable and our test framework supports it.
