extends GdUnitTestSuite
## Collision damage maths (ADR 0017): how hard a hit lands on Rubbley, as the impulse
## between him and what hits him, and how much of his Mass that impulse takes.

const TOLERANCE := 1e-4


## A 0.5 kg piece flying at a still 10 kg Rubbley at 21 m/s lands an impulse of their
## reduced mass, 10 × 0.5 ÷ 10.5 kg, times the closing speed: 10 N·s.
func test_the_impulse_is_the_reduced_mass_times_the_closing_speed() -> void:
	var impulse := CollisionDamage.hit_impulse_n_s(
		Vector3.ZERO,
		Vector3.ZERO,
		10.0,
		Vector3(2, 0, 0),
		Vector3(-21, 0, 0),
		0.5,
		false,
	)
	assert_float(impulse).is_equal_approx(10.0, TOLERANCE)


## Only the closing part counts: a piece crossing in front of Rubbley at an angle lands
## only its speed along the line between them.
func test_only_the_closing_speed_counts() -> void:
	var impulse := CollisionDamage.hit_impulse_n_s(
		Vector3.ZERO,
		Vector3.ZERO,
		10.0,
		Vector3(2, 0, 0),
		Vector3(-21, 0, 50),
		0.5,
		false,
	)
	assert_float(impulse).is_equal_approx(10.0, TOLERANCE)


## Rubbley flying into a frozen planet at 6 m/s takes the whole of his own momentum,
## 10 kg × 6 m/s, however heavy the planet.
func test_a_frozen_body_takes_rubbleys_whole_momentum() -> void:
	var impulse := CollisionDamage.hit_impulse_n_s(
		Vector3.ZERO,
		Vector3(6, 0, 0),
		10.0,
		Vector3(9, 0, 0),
		Vector3.ZERO,
		400.0,
		true,
	)
	assert_float(impulse).is_equal_approx(60.0, TOLERANCE)


## Bodies moving apart, or touching side by side, land nothing.
func test_bodies_not_closing_land_nothing() -> void:
	var parting := CollisionDamage.hit_impulse_n_s(
		Vector3.ZERO,
		Vector3(-3, 0, 0),
		10.0,
		Vector3(2, 0, 0),
		Vector3(3, 0, 0),
		0.5,
		false,
	)
	var level := CollisionDamage.hit_impulse_n_s(
		Vector3.ZERO,
		Vector3(0, 0, 5),
		10.0,
		Vector3(2, 0, 0),
		Vector3(0, 0, 5),
		0.5,
		false,
	)
	assert_float(parting).is_equal(0.0)
	assert_float(level).is_equal(0.0)


## A hit takes Mass for the impulse past the safe impulse: (25 − 5) N·s × 0.05 kg per
## N·s is 1 kg.
func test_mass_lost_is_the_impulse_past_the_safe_impulse() -> void:
	var tuning := CollisionDamageTuning.new()
	tuning.safe_impulse_n_s = 5.0
	tuning.mass_lost_kg_per_n_s = 0.05
	assert_float(CollisionDamage.mass_lost_kg(25.0, tuning)).is_equal_approx(1.0, TOLERANCE)


## A hit no harder than the safe impulse takes nothing.
func test_a_gentle_hit_takes_nothing() -> void:
	var tuning := CollisionDamageTuning.new()
	tuning.safe_impulse_n_s = 5.0
	tuning.mass_lost_kg_per_n_s = 0.05
	assert_float(CollisionDamage.mass_lost_kg(4.0, tuning)).is_equal(0.0)
