class_name AttractCueTuning
extends Resource
## How the placeholder Attract cues look and move (ADR 0017): the rings that contract
## onto Rubbley and into a Gravity Well, and the tether of a Targeted Attract. Read-only
## at runtime. Art direction will replace the cues.

## How long each ring takes to contract from its outer to its inner radius, in seconds.
@export_range(0.05, 5.0, 0.01, "or_greater") var pulse_period_s := 0.7
## How far out Attract on self's rings start, as a multiple of Rubbley's radius.
@export_range(1.0, 20.0, 0.1, "or_greater") var self_reach := 5.0
## How many rings stream inward at once.
@export_range(1, 8) var ring_count := 3
## How wide a ring is at the centre, where the pull is full, as a share of the outer
## radius. Rings narrow to nothing at the outer radius, where the pull runs out.
@export_range(0.0, 0.5, 0.01) var widest_ring := 0.1
## The most opaque a ring or the tether gets, from 0 to 1.
@export_range(0.0, 1.0, 0.01) var max_opacity := 0.7
## How wide a Targeted Attract's tether is, in metres.
@export_range(0.01, 5.0, 0.01, "or_greater") var tether_width_m := 0.3
