class_name HitFlashTuning
extends Resource
## How Rubbley flashes when a hit hurts him (ADR 0017). Read-only at runtime. Art
## direction will replace the flash.

## The flash's colour over his rock; its alpha is the strongest the flash gets.
@export var color := Color(1.0, 0.25, 0.2, 0.8)
## How long the flash takes to fade out, in seconds.
@export_range(0.01, 2.0, 0.01, "or_greater") var duration_s := 0.25
