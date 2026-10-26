class_name OrbitLaunch
extends RefCounted
## Starting velocities that put a body in Orbit round a primary that pulls with the
## inverse square and does not move, such as an Anchored Body. At 1 × circular speed
## the Orbit is a circle; slower or faster launches make ellipses, and from √2 × the
## body escapes.


## The velocity that launches a body at [param offset] from its primary across the
## offset, at [param speed_multiple] × circular speed for a pull of
## [param pull_strength] (G × mass, in m³/s²). [param anticlockwise] turns it
## anticlockwise seen from above, about +Y by the right-hand rule.
static func velocity(
	offset: Vector3,
	pull_strength: float,
	speed_multiple: float,
	anticlockwise: bool,
) -> Vector3:
	var on_plane := Vector3(offset.x, 0.0, offset.z)
	var radius := on_plane.length()
	var across := Vector3.UP.cross(on_plane) / radius
	if not anticlockwise:
		across = -across
	return across * speed_multiple * sqrt(pull_strength / radius)


## The smallest speed multiple a body launched across its offset at [param radius_m]
## can have and still keep its Orbit's closest point at [param lowest_m] or further
## out. [param lowest_m] must be below [param radius_m].
static func slowest_speed_multiple(radius_m: float, lowest_m: float) -> float:
	# Vis-viva: launched slower than circular, the launch point is the furthest point
	# and the closest is radius × k² / (2 − k²). Solved for k.
	return sqrt(2.0 * lowest_m / (radius_m + lowest_m))
