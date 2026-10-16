# Newtonian gravity between Celestial Bodies, with emergent orbits

Gravity is Newtonian (equal and opposite forces), but only a few **Celestial Bodies** pull. Everything else is a **Passive Body**: it gets pulled but pulls nothing back. The GDD's mass rule ("the heavier body is the centre point") isn't coded anywhere. It follows from Newton, because the heavier body barely moves. Orbits are real physics, not scripted. An always-on capture assist nudges a slow, lighter body inside a Capture Radius toward a circular orbit, but the body stays dynamic, so Repel or a collision can still sling it out. Gravega moves are multipliers on the pairwise force: Attract is a multiplier above 1, Repel is negative, and Attract on self multiplies all of Rubbley's pairs.

## Considered Options

- **Port Unity's `Orbit.cs` (kinematic pivot)**: rejected. A captured body becomes kinematic and leaves the simulation, so Repel can't slingshot it and collisions ignore it.
- **Pure emergent orbits with no assist**: rejected, because players would rarely land a stable orbit.
- **Force only on the lighter body**: rejected. Behaviour would flip abruptly when two masses cross, and mass changes during play.
- **Every body attracts every other (Unity's N²)**: rejected because of the phone budget in [ADR 0005](0005-gravity-stays-in-gdscript.md). The cost becomes N_celestial × N_total.

## Consequences

- Inverse-square falloff is softened and cut off at a maximum range. Unity's `G` and masses are not carried over; all values are retuned and kept in tuning data.
- Gravity Wells and Anchored Bodies use Area point gravity. Wells pull Rubbley too. Only bodies that both pull and move go through the GDScript seam.
- Capture assist and Drift are separate force contributors next to the pairwise loop, not inside it.
- Repel Pulse and Spin are impulses and collision shapes outside the gravity seam.
- Each body type has a speed cap and light damping. Rubbley and projectiles use continuous collision detection.
