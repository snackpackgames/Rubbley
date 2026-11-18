class_name ChippedRockTuning
extends Resource
## The placeholder look of a piece of debris (ADR 0017): a small stone, chipped and
## stretched at random. Art direction will replace it.

## The rock's width in metres before it is chipped or stretched.
@export_range(0.05, 5.0, 0.01, "or_greater") var width_m := 0.6
## How far each corner may be chipped in, as a share of the radius.
@export_range(0.0, 0.9, 0.01) var chip := 0.3
## How far the rock may be squashed or stretched along each axis, as a share of its width.
@export_range(0.0, 0.9, 0.01) var max_stretch := 0.3
## How many rock shapes the debris shares; each piece picks one at random.
@export_range(1, 64, 1) var shapes := 8
