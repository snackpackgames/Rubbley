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
@export_range(0.0, 100.0, 0.01, "or_greater") var drift_force_n := 6.0
