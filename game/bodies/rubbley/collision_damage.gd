class_name CollisionDamage
extends RefCounted
## Collision damage maths (ADR 0017). A hit lands the impulse a perfectly inelastic
## collision would: the two bodies' reduced mass times their closing speed along the line
## between them, across the Play Plane. A frozen body counts as immovable, so Rubbley takes
## his whole momentum into it. The impulse past a safe impulse takes Mass at a set rate.


## Returns the impulse in N·s of a hit between Rubbley, at [param rubbley_at] moving at
## [param rubbley_velocity] with [param rubbley_mass_kg], and the body at
## [param other_at] moving at [param other_velocity] with [param other_mass_kg], or
## immovable when [param other_frozen]. Zero for bodies not closing.
static func hit_impulse_n_s(
	rubbley_at: Vector3,
	rubbley_velocity: Vector3,
	rubbley_mass_kg: float,
	other_at: Vector3,
	other_velocity: Vector3,
	other_mass_kg: float,
	other_frozen: bool,
) -> float:
	var toward := other_at - rubbley_at
	toward.y = 0.0
	if toward.is_zero_approx():
		return 0.0
	var closing := (rubbley_velocity - other_velocity).dot(toward.normalized())
	if closing <= 0.0:
		return 0.0
	var reduced_mass_kg := rubbley_mass_kg
	if not other_frozen:
		reduced_mass_kg = rubbley_mass_kg * other_mass_kg / (rubbley_mass_kg + other_mass_kg)
	return reduced_mass_kg * closing


## Returns the Mass in kg a hit of [param impulse_n_s] takes, by [param tuning].
static func mass_lost_kg(impulse_n_s: float, tuning: CollisionDamageTuning) -> float:
	return maxf(impulse_n_s - tuning.safe_impulse_n_s, 0.0) * tuning.mass_lost_kg_per_n_s
