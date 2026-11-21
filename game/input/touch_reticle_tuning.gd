class_name TouchReticleTuning
extends Resource
## How the touch reticle looks (ADR 0017). Read-only at runtime. Art direction will
## replace the reticle.

## The ring's and the centre dot's colour.
@export var color := Color(1.0, 1.0, 1.0, 0.7)
## The ring's line width, in pixels.
@export_range(0.5, 10.0, 0.5) var width_px := 2.0
## The centre dot's radius, in pixels.
@export_range(0.0, 10.0, 0.5) var dot_radius_px := 3.0
