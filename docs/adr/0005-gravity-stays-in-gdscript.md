# N-body gravity stays in GDScript, capped to what phones can run

The pairwise gravity loop (the port of the Unity `Attractor`) is written in GDScript like the rest of the game ([ADR 0002](0002-gdscript-only.md)). If it is too slow on the minimum-spec phone, we cap the number of mutually attracting bodies and/or lower the physics tick rate until it fits, as [ADR 0003](0003-3d-physics-on-play-plane.md) already allows. We don't move it to native code. The loop sits behind a single narrow seam (bodies in, forces out), so its implementation can be replaced without touching callers.

## Considered Options

- **Move the hot loop to GDExtension**: rejected as a default fallback. It is much faster, but it needs a native build for Windows, macOS, Linux, Android, iOS (static linking) and web (the dlink-enabled export template). That adds a second toolchain to CI and a second language for agents to maintain, which is what ADR 0002 set out to avoid.

## Consequences

- The minimum-spec phone benchmark sets the body and tick-rate cap, and level design has to stay within it.
- Cheap optimisations come first: compute each pair once (the Unity code computes every pair twice), use typed and packed arrays, and use Area point gravity for one-way wells that don't need mutual attraction.
- GDExtension comes back only if the benchmark produces a cap the GDD can't accept. That decision needs a new ADR that supersedes this one.
