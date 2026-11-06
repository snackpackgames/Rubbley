class_name RubbleyStats
extends Resource
## Rubbley's numbers that advancement can change (ADR 0017). Read-only at runtime.
## For now only Attract's Gravega values; Mass, Stamina and the other moves join them
## with their features.

## The Gravega multiplier on every pair Rubbley is in while he Attracts on self.
@export_range(1.0, 10.0, 0.01, "or_greater") var attract_self_multiplier := 3.0
## The Gravega multiplier on Rubbley's pair with a glowing Celestial Body while he
## Attracts it. The body's other pairs keep their pull.
@export_range(1.0, 10.0, 0.01, "or_greater") var attract_celestial_multiplier := 2.0
## How hard a Gravity Well pulls at its centre, in m/s². The pull falls off to nothing
## at its edge. Strong enough to fling Rubbley through, which can leave him nearly
## stopped against Drift for a while after it ends (ADR 0018).
@export_range(0.0, 200.0, 0.1, "or_greater") var gravity_well_strength_m_per_s2 := 50.0
## How far a Gravity Well reaches, in metres.
@export_range(0.1, 100.0, 0.1, "or_greater") var gravity_well_radius_m := 24.0
## How long a Gravity Well pulls at full strength, in seconds.
@export_range(0.1, 30.0, 0.1, "or_greater") var gravity_well_duration_s := 3.0
## How long a Gravity Well's pull then takes to fade to nothing, in seconds.
@export_range(0.0, 30.0, 0.1, "or_greater") var gravity_well_fade_s := 0.0
