class_name SpinShield
extends RefCounted
## Spin's deflection maths (ADR 0012). Where Rubbley's shield meets another body, the
## lighter of the two bounces off the heavier: its closing speed, relative to the
## heavier, is sent back across the Play Plane, and the heavier takes none of it. So
## debris bounces off Rubbley, and Rubbley bounces off a planet.


## Returns the speed change that bounces the body at [param to_at], moving at
## [param to_velocity], off the body at [param from_at], moving at
## [param from_velocity]. Only the closing part of their relative velocity, along the
## line between them, is sent back, scaled by [param restitution]; the sideways part is
## kept. Zero for a body not closing, or one at the same point.
static func bounce_change(
	from_at: Vector3,
	from_velocity: Vector3,
	to_at: Vector3,
	to_velocity: Vector3,
	restitution: float,
) -> Vector3:
	var outward := to_at - from_at
	outward.y = 0.0
	if outward.is_zero_approx():
		return Vector3.ZERO
	outward = outward.normalized()
	var closing := (to_velocity - from_velocity).dot(outward)
	if closing >= 0.0:
		return Vector3.ZERO
	return -outward * closing * (1.0 + restitution)
