# Simulate in 3D physics locked to the Play Plane

All gameplay physics runs in 3D on Jolt, locked to the Play Plane: the world XZ plane at `y = 0`, with +Y up. Each body locks linear Y and angular X/Z, so it moves only within the plane and rotates only around Y. Rubbley is 2.5D: gameplay happens on one plane and height is only visual. With 3D physics, an entity's body, mesh, effects and colliders form one node tree under the tilted `Camera3D`, so nothing has to be kept in sync. The Unity prototype also works this way, simulating on XY with Z locked. Behaviour ported from it maps Unity (x, y) to Godot (x, z).

## Considered Options

- **2D physics with 3D visuals** (Godot Physics 2D, with a separate 3D scene copying each body's transform): rejected. Physics per body is cheaper and `Vector2` maths is cleaner. But every entity needs two nodes plus sync code, and interpolation, particles and Area gravity all have to be bridged from 2D into 3D. It doesn't simplify the camera or picking either, since the tilted 3D camera still raycasts onto the plane.

## Consequences

- Gameplay never uses height. A mesh can tumble on all three axes for looks, but physics rotation stays locked to Y.
- Touch and mouse aiming come from a camera ray intersected with the Play Plane.
- Jolt has more per-body overhead than Godot Physics 2D. If the minimum-spec phone benchmark fails, we cut body count or lower the physics tick rate (with physics interpolation) before reconsidering 2D.
