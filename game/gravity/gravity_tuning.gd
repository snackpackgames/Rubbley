class_name GravityTuning
extends Resource
## How gravity and Drift behave across a level (ADR 0017). Read-only at runtime.

## Scales every pairwise pull: force = G × m1 × m2 / d². Not Unity's G; retuned for Godot units.
@export_range(0.0, 100.0, 0.01, "or_greater") var gravitational_constant := 1.0
## Softening length in metres. It keeps the pull finite when two bodies nearly touch.
@export_range(0.0, 10.0, 0.01, "or_greater") var softening_m := 1.0
## Bodies further apart than this, in metres, don't pull each other at all.
@export_range(0.0, 500.0, 0.1, "or_greater") var max_range_m := 60.0
## Drift's steady push on Rubbley, in newtons (mass × m/s²). His Mass and damping
## set the speed it gives.
@export_range(0.0, 100.0, 0.01, "or_greater") var drift_force_n := 1.0
## A body is in Orbit only while it stays within this multiple of its primary's Capture
## Radius (ADR 0018). Going further out ends the Orbit.
@export_range(1.0, 5.0, 0.01, "or_greater") var orbit_radius_multiple := 1.25
## In Orbit, a body's furthest distance from its primary may be at most this multiple
## of its closest, so a body spiralling in or swinging wide isn't in Orbit.
@export_range(1.0, 3.0, 0.01, "or_greater") var orbit_radius_band := 1.3
## How far round its primary a body must travel, in degrees, inside the radius band
## before it counts as in Orbit.
@export_range(0.0, 720.0, 1.0, "or_greater") var orbit_travel_deg := 360.0
## How fast the capture assist closes the gap between a body's velocity and a circular
## Orbit, per second (ADR 0006). Higher holds Orbit more firmly against Drift.
@export_range(0.0, 10.0, 0.01, "or_greater") var capture_assist_rate_per_second := 2.0
## The capture assist helps only a body slower than this multiple of circular speed
## round its primary. Escape speed is √2 ≈ 1.41 times circular.
@export_range(0.0, 2.0, 0.01, "or_greater") var capture_speed_multiple := 1.3
