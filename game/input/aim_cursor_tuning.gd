class_name AimCursorTuning
extends Resource
## How the controller's aim cursor looks and fades when idle (ADR 0017). Read-only at
## runtime. Art direction will replace the cursor.

## The cursor's colour while it aims away from Rubbley.
@export var color := Color(0.3, 1.0, 1.0, 1.0)
## The cursor's colour while the stick is at rest and it aims at Rubbley.
@export var on_rubbley_color := Color(1.0, 1.0, 1.0, 0.6)
## The ring's radius, in pixels.
@export_range(1.0, 64.0, 0.5) var radius_px := 14.0
## How far the crosshair reaches from the centre, in pixels.
@export_range(0.0, 64.0, 0.5) var crosshair_px := 20.0
## The ring's line width, in pixels.
@export_range(0.5, 10.0, 0.5) var width_px := 2.0
## How long the cursor stays at full opacity after controller input stops, in seconds.
@export_range(0.0, 10.0, 0.05, "or_greater") var idle_hold_s := 1.0
## How long the cursor takes to fade out once idle past [member idle_hold_s], in seconds.
@export_range(0.0, 5.0, 0.05, "or_greater") var fade_out_s := 0.3
