class_name RepelImpulse
extends RefCounted
## Repel's impulse maths (ADRs 0006, 0012). A Repel Pulse and a Gravity Ripple are radial
## pushes: every body in range up to a reference mass gets the same speed change, as in
## the controller-aim prototype, falling off linearly to nothing at the edge, and heavier
## bodies take a shrinking share of it ([method mass_share]). A Targeted
## Repel is one impulse along the Rubbley↔target line, equal and opposite on the two
## bodies, so each moves by the impulse divided by its own mass.


## Returns the speed change a radial push from [param centre] gives a body at
## [param point]: away from the centre across the Play Plane, at [param speed_m_per_s]
## at the centre falling off linearly to 0 at [param radius_m]. A body at the edge, past
## it, or at the exact centre is not pushed.
static func radial_velocity_change(
	centre: Vector3,
	point: Vector3,
	radius_m: float,
	speed_m_per_s: float,
) -> Vector3:
	var offset := point - centre
	offset.y = 0.0
	var distance := offset.length()
	if is_zero_approx(distance) or distance >= radius_m:
		return Vector3.ZERO
	return offset / distance * speed_m_per_s * (1.0 - distance / radius_m)


## Returns the impulse, in N·s, a Targeted Repel of [param impulse_n_s] gives the target
## at [param target_at]: straight away from Rubbley at [param rubbley_at], across the Play
## Plane. Rubbley takes the same impulse the other way. Zero if they share a point.
static func targeted_impulse(
	rubbley_at: Vector3,
	target_at: Vector3,
	impulse_n_s: float,
) -> Vector3:
	var offset := target_at - rubbley_at
	offset.y = 0.0
	if offset.is_zero_approx():
		return Vector3.ZERO
	return offset.normalized() * impulse_n_s


## Returns the share of a radial push a body of [param mass_kg] takes: all of it up to
## [param reference_mass_kg], then (reference ÷ mass) to [param falloff]. A falloff of 0
## pushes every body alike; 1 gives bodies past the reference the same impulse.
static func mass_share(mass_kg: float, reference_mass_kg: float, falloff: float) -> float:
	if mass_kg <= reference_mass_kg:
		return 1.0
	return pow(reference_mass_kg / mass_kg, falloff)
