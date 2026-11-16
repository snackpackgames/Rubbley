class_name AttractPulse
extends RefCounted
## The placeholder look of a pull, shared by Attract on self and the Gravity Well: rings
## that start at an outer radius and contract onto an inner one over a period, fading in
## as they close, then start again. Several rings, each offset by a share of the period,
## make a steady stream inward. Art direction will replace it.


## Returns a ring's radius in metres at [param time_s], contracting from
## [param outer_m] to [param inner_m] once every [param period_s] seconds, started
## [param offset] of a period ahead.
static func ring_radius_m(
	time_s: float,
	period_s: float,
	inner_m: float,
	outer_m: float,
	offset: float,
) -> float:
	return lerpf(outer_m, inner_m, _progress(time_s, period_s, offset))


## Returns a ring's opacity from 0 to 1 at [param time_s], for a ring that contracts once
## every [param period_s] seconds, started [param offset] of a period ahead: 0 as it
## appears at the outer radius, rising as it closes.
static func ring_opacity(time_s: float, period_s: float, offset: float) -> float:
	return _progress(time_s, period_s, offset)


# How far through its contraction the ring is, from 0 at the outer radius up to 1.
static func _progress(time_s: float, period_s: float, offset: float) -> float:
	return fposmod(time_s / period_s + offset, 1.0)
