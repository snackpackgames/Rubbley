class_name AttractPulse
extends RefCounted
## The placeholder look of a pull, shared by Attract on self and the Gravity Well: rings
## that start at an outer radius and contract onto an inner one over a period, fading in
## as they close, then start again. Several rings, each offset by a share of the period,
## make a steady stream inward. A ring is as wide as the pull is strong where it is, so
## rings start as hairlines at the edge and thicken toward the centre. Art direction
## will replace it.


## Draws the rings into [param mesh] at [param time_s], by [param tuning]: contracting
## from [param outer_m] onto [param inner_m], as wide as a pull that runs out at the outer
## radius, and as opaque as they are closed in, times [param strength].
static func draw(
	mesh: ImmediateMesh,
	tuning: AttractCueTuning,
	time_s: float,
	inner_m: float,
	outer_m: float,
	strength := 1.0,
) -> void:
	FlatRings.clear(mesh)
	for i in tuning.ring_count:
		var offset := float(i) / tuning.ring_count
		var radius_m := ring_radius_m(time_s, tuning.pulse_period_s, inner_m, outer_m, offset)
		var width_m := ring_width_m(radius_m, outer_m, outer_m * tuning.widest_ring)
		var alpha := ring_opacity(time_s, tuning.pulse_period_s, offset) * tuning.max_opacity
		FlatRings.add(mesh, radius_m, width_m, Color(1, 1, 1, alpha * strength))


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


## Returns a ring's width in metres at [param radius_m], for a pull that falls off in a
## straight line from full at the centre to nothing at [param outer_m], as the Gravity
## Well's does: [param widest_m] at the centre, 0 at the outer radius and beyond.
static func ring_width_m(radius_m: float, outer_m: float, widest_m: float) -> float:
	return widest_m * clampf(1.0 - radius_m / outer_m, 0.0, 1.0)


## Returns a ring's opacity from 0 to 1 at [param time_s], for a ring that contracts once
## every [param period_s] seconds, started [param offset] of a period ahead: 0 as it
## appears at the outer radius, rising as it closes.
static func ring_opacity(time_s: float, period_s: float, offset: float) -> float:
	return _progress(time_s, period_s, offset)


# How far through its contraction the ring is, from 0 at the outer radius up to 1.
static func _progress(time_s: float, period_s: float, offset: float) -> float:
	return fposmod(time_s / period_s + offset, 1.0)
