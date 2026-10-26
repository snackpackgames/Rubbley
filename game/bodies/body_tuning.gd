class_name BodyTuning
extends Resource
## Type-wide physics values for one body type, such as Rubbley, a planet or debris
## (ADR 0017). A placed body that needs other values gets a variant [code].tres[/code].

## The fastest the body may move across the Play Plane, in metres per second.
@export_range(0.1, 100.0, 0.1, "or_greater") var speed_cap_m_per_s := 20.0
## Light linear damping, as the fraction of speed lost per second. It replaces the project default.
@export_range(0.0, 5.0, 0.01) var linear_damp_per_second := 0.1
## Angular damping on the body's spin around Y, per second. It replaces the project default.
@export_range(0.0, 5.0, 0.01) var angular_damp_per_second := 0.5
## Whether the body uses continuous collision detection, so it can't tunnel through others at speed.
@export var continuous_cd := false
## Whether a heavier body's capture assist can help this body into Orbit (ADR 0006).
@export var capturable := false
## As a primary, the distance in metres inside which a slower, lighter capturable body
## is helped into Orbit round it. 0 captures nothing. Keep it inside the max range.
@export_range(0.0, 100.0, 0.1, "or_greater") var capture_radius_m := 0.0
