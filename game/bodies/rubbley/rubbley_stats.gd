class_name RubbleyStats
extends Resource
## Rubbley's numbers that advancement can change (ADR 0017). Read-only at runtime.
## For now only Attract's and Repel's values; Mass, Stamina and Spin join them
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
## The speed change a Repel Pulse gives a body at Rubbley's centre, in m/s, whatever its
## mass, falling off to nothing at its radius. The controller-aim prototype's 800 px/s.
@export_range(0.0, 100.0, 0.1, "or_greater") var repel_pulse_speed_m_per_s := 36.4
## How far a Repel Pulse reaches from Rubbley, in metres. The prototype's 380 px.
@export_range(0.1, 100.0, 0.1, "or_greater") var repel_pulse_radius_m := 17.3
## How long a Repel Pulse stuns what it reaches, in seconds.
@export_range(0.0, 10.0, 0.01, "or_greater") var repel_pulse_stun_s := 1.5
## The speed change a Gravity Ripple gives a body at its centre, in m/s, whatever its mass,
## Rubbley's included, falling off to nothing at its radius. Weaker than a Repel Pulse.
@export_range(0.0, 100.0, 0.1, "or_greater") var gravity_ripple_speed_m_per_s := 27.3
## How far a Gravity Ripple reaches, in metres.
@export_range(0.1, 100.0, 0.1, "or_greater") var gravity_ripple_radius_m := 17.3
## The impulse a Targeted Repel pushes Rubbley and its target apart with, in N·s; each moves
## by it divided by its own mass. The prototype's 550 px/s slingshot on Rubbley's 10 kg.
@export_range(0.0, 2000.0, 1.0, "or_greater") var targeted_repel_impulse_n_s := 250.0
