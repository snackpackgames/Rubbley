class_name InputTuning
extends Resource
## The input thresholds Move Input recognises moves by (ADR 0013). Read-only at runtime.
## Seeded with the controller-aim values from ADR 0012; touch thresholds and the Spin
## lockout join them with their schemes. Lengths on screen are fractions of half the
## screen's short side.

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
