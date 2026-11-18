class_name AbsorbPopTuning
extends Resource
## How Rubbley's mesh swells when he absorbs debris (ADR 0017). Read-only at runtime.

## How much bigger the mesh jumps on an absorb, as a share of its size: 0.3 is 30% bigger.
@export_range(0.0, 2.0, 0.01) var swell := 0.3
## How long the swell takes to ease back to his own size, in seconds.
@export_range(0.01, 2.0, 0.01, "or_greater") var duration_s := 0.25
