class_name RubbleyStats
extends Resource
## Rubbley's numbers that advancement can change (ADR 0017). Read-only at runtime.
## For now only Attract's Gravega values; Mass, Stamina and the other moves join them
## with their features.

## The Gravega multiplier on every pair Rubbley is in while he Attracts on self.
@export_range(1.0, 10.0, 0.01, "or_greater") var attract_self_multiplier := 3.0
## The Gravega multiplier on a glowing Celestial Body's pulls while Rubbley Attracts it.
@export_range(1.0, 10.0, 0.01, "or_greater") var attract_celestial_multiplier := 2.0
## How hard a Gravity Well pulls everything inside its radius toward its centre, in
## m/s², the same at any distance. Keep it under Drift speed² / (2 × radius), or the Well
## can hold Rubbley against Drift until it ends (ADR 0018's feel scenario).
@export_range(0.0, 10.0, 0.01, "or_greater") var gravity_well_strength_m_per_s2 := 0.6
## How far a Gravity Well reaches, in metres.
@export_range(0.1, 100.0, 0.1, "or_greater") var gravity_well_radius_m := 12.0
## How long a Gravity Well lasts, in seconds.
@export_range(0.1, 30.0, 0.1, "or_greater") var gravity_well_lifetime_s := 4.0
