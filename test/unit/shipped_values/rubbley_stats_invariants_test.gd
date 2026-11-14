extends GdUnitTestSuite
## Invariants on Rubbley's shipped Stats (ADR 0017), so a bad retune can't leave a move he
## can never use.

const STATS := preload("res://game/bodies/rubbley/rubbley_stats.tres")
## The shortest Attract a full pool must hold, on self or on a body, in seconds. Long
## enough to pull debris in or swing toward a planet.
const MIN_ATTRACT_S := 1.0


## A full pool covers one Repel Pulse, one Targeted Repel or Gravity Ripple, and one Spin.
func test_a_full_pool_covers_each_fixed_cost() -> void:
	assert_float(STATS.stamina_max).is_greater_equal(STATS.repel_pulse_cost)
	assert_float(STATS.stamina_max).is_greater_equal(STATS.repel_cost)
	assert_float(STATS.stamina_max).is_greater_equal(STATS.spin_cost)


## A full pool holds either use of Attract for at least the minimum hold.
func test_a_full_pool_holds_attract() -> void:
	var self_s := STATS.stamina_max / maxf(STATS.attract_self_drain_per_second, 1e-6)
	var celestial_s := STATS.stamina_max / maxf(STATS.attract_celestial_drain_per_second, 1e-6)
	assert_float(self_s).is_greater_equal(MIN_ATTRACT_S)
	assert_float(celestial_s).is_greater_equal(MIN_ATTRACT_S)


## Stamina refills, and Attract on a Celestial Body drains less than on self (GDD).
func test_stamina_refills_and_celestial_attract_drains_less() -> void:
	assert_float(STATS.stamina_regen_per_second).is_greater(0.0)
	assert_float(STATS.attract_celestial_drain_per_second).is_less(
		STATS.attract_self_drain_per_second,
	)
