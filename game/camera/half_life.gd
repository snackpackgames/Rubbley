class_name HalfLife
extends RefCounted
## Exponential easing set by a half-life, so it eases the same at any frame rate.


## Returns the share of a gap that an approach with [param half_life_s] closes in
## [param delta] seconds. A half-life of 0 closes all of it.
static func closed_share(half_life_s: float, delta: float) -> float:
	if half_life_s <= 0.0:
		return 1.0
	return 1.0 - pow(0.5, delta / half_life_s)
