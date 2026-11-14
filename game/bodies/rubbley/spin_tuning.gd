class_name SpinTuning
extends Resource
## How Spin's shield feels (ADRs 0012, 0017): its size, how long it lasts, the lockout
## after it and the perfect window. Read-only at runtime.

## How far the shield reaches past Rubbley's surface, in metres, so it grows with him.
## Small, so a Spin has to be timed: a 15 m/s throw crosses it in a tenth of a second.
@export_range(0.0, 10.0, 0.01, "or_greater") var shield_reach_m := 1.5
## How long the shield stays up after one Spin, in seconds.
@export_range(0.01, 5.0, 0.01, "or_greater") var duration_s := 0.4
## How long after the shield drops before Spin can fire again, in seconds. Spins fired
## while the shield is up or locked out do nothing and don't extend it.
@export_range(0.0, 5.0, 0.01, "or_greater") var lockout_s := 0.6
## How long from the start of a Spin a hit counts as perfectly timed, in seconds. Kept
## for the perfect-Spin blast-back that projectiles will use.
@export_range(0.0, 5.0, 0.01, "or_greater") var perfect_window_s := 0.1
## How much of a body's closing speed the shield sends back, relative to Rubbley. 1 bounces
## it off at the speed it came in; less deadens the bounce.
@export_range(0.0, 2.0, 0.01, "or_greater") var restitution := 1.0
