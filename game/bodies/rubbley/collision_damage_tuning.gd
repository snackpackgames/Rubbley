class_name CollisionDamageTuning
extends Resource
## How much of Rubbley's Mass a collision takes (ADR 0017). Read-only at runtime. Tuning,
## not Stats, until advancement needs to change it.

## The hardest hit Rubbley takes without losing Mass, as the impulse between him and what
## hits him, in N·s. Keeps grazes and debris drifting into him free: a 0.5 kg piece must
## close at over 10 m/s to hurt him.
@export_range(0.0, 1000.0, 0.1, "or_greater") var safe_impulse_n_s := 5.0
## The Mass a hit takes per N·s of impulse past the safe impulse, in kg. The impulse grows
## with Rubbley's own Mass, so hitting a planet at a given speed costs him the same share
## of his Mass however big he is.
@export_range(0.0, 1.0, 0.001, "or_greater") var mass_lost_kg_per_n_s := 0.03
