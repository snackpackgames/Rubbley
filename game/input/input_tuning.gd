class_name InputTuning
extends Resource
## The input thresholds Move Input recognises moves by (ADR 0013). Read-only at runtime.
## Seeded with the controller-aim values from ADR 0012 and starting touch thresholds.
## The Spin lockout is a gameplay rule, in [SpinTuning]. Lengths on screen are fractions
## of half the screen's short side.

## Stick travel inside which the stick counts as at rest, aiming at Rubbley.
@export_range(0.0, 1.0, 0.01) var stick_deadzone := 0.2
## How far the controller aim cursor reaches from Rubbley at full travel.
@export_range(0.0, 1.0, 0.01) var aim_range := 0.9
## How close a glowing body's edge must be to the cursor for the aim to snap to it.
@export_range(0.0, 1.0, 0.001) var aim_snap_radius := 0.167
## Stick travel from which the stick counts as fully tilted, so the reach cone picks.
@export_range(0.0, 1.0, 0.01) var full_tilt := 0.95
## The full-tilt reach cone's full angle, in degrees.
@export_range(0.0, 90.0, 0.1) var reach_cone_deg := 12.0
## How far the full-tilt reach cone picks, as a multiple of the aim range.
@export_range(1.0, 5.0, 0.01, "or_greater") var reach_range_multiple := 2.0
## How far past the cone, in degrees, a picked body stays picked.
@export_range(0.0, 45.0, 0.1) var reach_hysteresis_deg := 10.0
## How much nearer bodies are preferred in the cone, as degrees of angle per range.
@export_range(0.0, 45.0, 0.1) var reach_distance_bias_deg := 5.0
## Seconds the last aim is kept after the stick returns to rest.
@export_range(0.0, 1.0, 0.001) var aim_release_grace_s := 0.12
## How far a finger must travel quickly, from where it last went slow, to swipe a Spin.
@export_range(0.0, 1.0, 0.01) var swipe_distance := 0.15
## How fast a finger must move to count toward a swipe, in screen lengths per second.
@export_range(0.0, 10.0, 0.01, "or_greater") var swipe_speed := 1.5
## Seconds after a finger goes down in which a second finger pairs with it for a pinch
## or Nudge, instead of being a swipe candidate of its own.
@export_range(0.0, 1.0, 0.001) var second_finger_window_s := 0.15
## How much the gap between two paired fingers must change to classify them as a pinch.
@export_range(0.0, 1.0, 0.01) var pinch_distance := 0.08
## How far the midpoint of two paired fingers must move to classify them as a Nudge.
@export_range(0.0, 1.0, 0.01) var nudge_distance := 0.08
## How far a two-finger drag's midpoint moves for a full Nudge.
@export_range(0.01, 2.0, 0.01) var nudge_full_drag := 0.4
## How far from a pinch centre Rubbley's or a glowing body's edge may be and still count
## as under it, forgiving the finger. The touch reticle shows it.
@export_range(0.0, 1.0, 0.01) var touch_hit_radius := 0.12
