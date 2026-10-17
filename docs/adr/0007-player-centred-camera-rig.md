# Player-centred soft-follow camera rig

The camera is a hand-rolled `CameraRig`: a `Node3D` outside Rubbley's tree with fixed yaw and fixed tilt, holding a narrow-FOV (30–40°) perspective `Camera3D`. It sits outside the tree so Rubbley's rotation and tumble never reach the camera. It follows Rubbley's interpolated position with exponential smoothing. Setting the half-life to 0 makes it a hard lock, so the GDD's "always in the centre" is a tuning value rather than hard-coded behaviour. Phones play in portrait and desktop in landscape. The camera holds the screen's short side to the same world extent on both, so every platform sees at least the same circle around Rubbley. The camera never clamps at level edges: levels are open space bounded by gameplay, not by the camera.

## Considered Options

- **Camera as a child of Rubbley**: rejected, because it inherits his Y rotation and cosmetic tumble.
- **Hard lock only**: rejected. A fast slingshot out of an Orbit reads better with some lag. The half-life can still go to 0.
- **Clamp the camera at level edges**: rejected, because it breaks centring and makes aiming near edges inconsistent.
- **Phantom Camera addon**: rejected. Follow, nudge and zoom are a short script, and the addon would be a third-party dependency for something that needs little.
- **Orthographic projection**: deferred to art direction. Switching later is a single property on the camera.

## Consequences

- Follow lag and Nudge add into one offset, and a single `max_offset` (a fraction of the screen's short side) clamps it so Rubbley never leaves the screen. Screen shake and other effects add into the same offset later.
- Nudge is a peek, not a pan. It springs back to centre when released. The camera exposes a device-agnostic nudge input; the input layer maps the right stick, Alt+drag and multi-touch drag onto it.
- Zoom changes camera distance, not FOV. By default it keeps Rubbley's radius at a fixed fraction of the short side, between a minimum and maximum visible extent. **Camera Zones** (`Area3D` plus a framing resource, highest priority wins) can raise the visible extent but never shrink it below the size-driven value. Players have no zoom control, because pinch belongs to Attract and Repel.
- Tuning lives in a resource: `follow_half_life`, `max_offset`, tilt and distance, nudge radius and spring, `rubbley_screen_fraction`, `min_extent`, `max_extent` and `zoom_half_life`. Its format follows whatever the tuning-data decision settles.
- Desktop sees more along its long side than a portrait phone does, and leaderboards are global. We accept that advantage. If it ever matters, leaderboards could be split per input scheme.
