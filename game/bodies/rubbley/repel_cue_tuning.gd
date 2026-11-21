class_name RepelCueTuning
extends Resource
## How the placeholder Repel cue looks (ADR 0017): one red-orange wave for all three uses
## of Repel ([RepelWave]). Read-only at runtime. Art direction will replace it.

## The wave's colour, the same for a Repel Pulse, a Targeted Repel and a Gravity Ripple.
@export var color := Color(1.0, 0.4, 0.3)
## How long a wave takes to reach its full size and fade out, in seconds.
@export_range(0.05, 5.0, 0.01, "or_greater") var duration_s := 0.8
## How wide the wave's ring is, in metres.
@export_range(0.01, 5.0, 0.01, "or_greater") var width_m := 0.4
## How far past a Targeted Repel's body the wave grows, as a share of the body's radius.
## The push has no area, so the wave only rings the body.
@export_range(0.0, 2.0, 0.01, "or_greater") var targeted_growth := 0.5
