extends GdUnitTestSuite

const CELESTIAL := GravityBody.Role.CELESTIAL
const PASSIVE := GravityBody.Role.PASSIVE
const ANCHORED := GravityBody.Role.ANCHORED

var _tuning: GravityTuning


## Builds Gravity Tuning with no softening and a range wide enough for every test.
func before_test() -> void:
	_tuning = GravityTuning.new()
	_tuning.gravitational_constant = 2.0
	_tuning.softening_m = 0.0
	_tuning.max_range_m = 100.0


## Two Celestial Bodies pull each other with G·m1·m2/d², equal and opposite.
func test_celestial_bodies_pull_each_other_equally_and_oppositely() -> void:
	var forces := _solve([Vector3.ZERO, Vector3(4, 0, 0)], [3.0, 8.0], [CELESTIAL, CELESTIAL])
	# 2 × 3 × 8 / 4² = 3
	assert_vector(forces[0]).is_equal_approx(Vector3(3, 0, 0), Vector3.ONE * 1e-5)
	assert_vector(forces[1]).is_equal_approx(Vector3(-3, 0, 0), Vector3.ONE * 1e-5)


## A Celestial Body pulls a Passive Body, which pulls nothing back.
func test_passive_body_is_pulled_but_pulls_nothing() -> void:
	var forces := _solve([Vector3.ZERO, Vector3(0, 0, 2)], [5.0, 0.5], [CELESTIAL, PASSIVE])
	# 2 × 5 × 0.5 / 2² = 1.25, toward the Celestial Body.
	assert_vector(forces[0]).is_equal_approx(Vector3.ZERO, Vector3.ONE * 1e-5)
	assert_vector(forces[1]).is_equal_approx(Vector3(0, 0, -1.25), Vector3.ONE * 1e-5)


## Passive Bodies don't pull each other.
func test_passive_bodies_ignore_each_other() -> void:
	var forces := _solve([Vector3.ZERO, Vector3(1, 0, 0)], [1.0, 1.0], [PASSIVE, PASSIVE])
	assert_vector(forces[0]).is_equal(Vector3.ZERO)
	assert_vector(forces[1]).is_equal(Vector3.ZERO)


## Bodies beyond the max range don't pull each other; bodies just inside it do.
func test_bodies_beyond_max_range_ignore_each_other() -> void:
	_tuning.max_range_m = 10.0
	var forces := _solve(
		[Vector3.ZERO, Vector3(10.5, 0, 0), Vector3(0, 0, -9.5)],
		[1.0, 1.0, 1.0],
		[CELESTIAL, CELESTIAL, PASSIVE],
	)
	assert_vector(forces[1]).is_equal(Vector3.ZERO)
	assert_float(forces[2].z).is_greater(0.0)


## Softening weakens the pull at short range: G·m1·m2·d / (d² + ε²)^1.5.
func test_softening_weakens_a_close_pull() -> void:
	_tuning.softening_m = 4.0
	var forces := _solve([Vector3.ZERO, Vector3(3, 0, 0)], [1.0, 1.0], [CELESTIAL, CELESTIAL])
	# 2 × 1 × 1 × 3 / 5³ = 0.048
	assert_vector(forces[0]).is_equal_approx(Vector3(0.048, 0, 0), Vector3.ONE * 1e-6)


## Two bodies at the same point exert no force instead of an infinite one.
func test_coincident_bodies_exert_no_force() -> void:
	_tuning.softening_m = 1.0
	var forces := _solve([Vector3(2, 0, 2), Vector3(2, 0, 2)], [1.0, 1.0], [CELESTIAL, CELESTIAL])
	assert_vector(forces[0]).is_equal(Vector3.ZERO)
	assert_vector(forces[1]).is_equal(Vector3.ZERO)


## A body's Gravega multiplier scales every pair it's in and leaves other pairs alone.
func test_gravega_multiplier_scales_only_that_bodys_pairs() -> void:
	# Bodies 1 and 2 are each in range of body 0 only; bodies 3 and 4 are a separate pair.
	_tuning.max_range_m = 3.0
	var forces := _solve(
		[Vector3.ZERO, Vector3(2, 0, 0), Vector3(-2, 0, 0), Vector3(50, 0, 0), Vector3(52, 0, 0)],
		[1.0, 1.0, 1.0, 1.0, 1.0],
		[CELESTIAL, CELESTIAL, PASSIVE, CELESTIAL, CELESTIAL],
		[3.0, 1.0, 1.0, 1.0, 1.0],
	)
	# Body 0's pairs: 2 × 1 × 1 / 2² × 3 = 1.5 each.
	assert_vector(forces[1]).is_equal_approx(Vector3(-1.5, 0, 0), Vector3.ONE * 1e-5)
	assert_vector(forces[2]).is_equal_approx(Vector3(1.5, 0, 0), Vector3.ONE * 1e-5)
	# The other pair is unscaled: 2 × 1 × 1 / 2² = 0.5.
	assert_vector(forces[3]).is_equal_approx(Vector3(0.5, 0, 0), Vector3.ONE * 1e-5)


## An Anchored Body pulls through its own Area point gravity, so the solver neither
## pulls with it nor pulls on it, and other pairs are unchanged.
func test_anchored_bodies_are_left_out_of_the_solver() -> void:
	var forces := _solve(
		[Vector3.ZERO, Vector3(4, 0, 0), Vector3(0, 0, 2)],
		[3.0, 8.0, 0.5],
		[CELESTIAL, ANCHORED, PASSIVE],
	)
	assert_vector(forces[1]).is_equal(Vector3.ZERO)
	# Only body 0 pulls body 2: 2 × 3 × 0.5 / 2² = 0.75.
	assert_vector(forces[2]).is_equal_approx(Vector3(0, 0, -0.75), Vector3.ONE * 1e-5)
	assert_vector(forces[0]).is_equal_approx(Vector3.ZERO, Vector3.ONE * 1e-5)


## A pair multiplier scales that one pair and leaves both bodies' other pairs alone.
func test_a_pair_multiplier_scales_only_that_pair() -> void:
	var pair_multipliers: Dictionary[Vector2i, float] = { Vector2i(0, 1): 3.0 }
	var forces := _solve(
		[Vector3.ZERO, Vector3(2, 0, 0), Vector3(-2, 0, 0)],
		[1.0, 1.0, 1.0],
		[CELESTIAL, CELESTIAL, CELESTIAL],
		[],
		pair_multipliers,
	)
	# Pair 0–1: 2 × 1 × 1 / 2² × 3 = 1.5. Pair 1–2 at 4 m: 2 / 4² = 0.125.
	assert_vector(forces[1]).is_equal_approx(Vector3(-1.625, 0, 0), Vector3.ONE * 1e-5)
	# Pair 0–2 is unscaled: 0.5, and pair 1–2 pulls body 2 the same way.
	assert_vector(forces[2]).is_equal_approx(Vector3(0.625, 0, 0), Vector3.ONE * 1e-5)


## An Anchored Body's Area point gravity pulls at its plain strength, so a pair multiplier
## on a pair with one adds only the share above 1, on the other body, unsoftened.
func test_a_pair_multiplier_on_an_anchored_body_adds_the_extra_pull() -> void:
	_tuning.softening_m = 1.0
	var pair_multipliers: Dictionary[Vector2i, float] = { Vector2i(0, 1): 3.0 }
	var forces := _solve(
		[Vector3.ZERO, Vector3(4, 0, 0)],
		[3.0, 8.0],
		[CELESTIAL, ANCHORED],
		[],
		pair_multipliers,
	)
	# (3 − 1) × 2 × 8 × 3 / 4² = 6, toward the Anchored Body, which never moves.
	assert_vector(forces[0]).is_equal_approx(Vector3(6, 0, 0), Vector3.ONE * 1e-5)
	assert_vector(forces[1]).is_equal(Vector3.ZERO)


func _solve(
	positions: Array[Vector3],
	masses: Array[float],
	roles: Array[GravityBody.Role],
	multipliers: Array[float] = [],
	pair_multipliers: Dictionary[Vector2i, float] = { },
) -> PackedVector3Array:
	if multipliers.is_empty():
		multipliers.resize(positions.size())
		multipliers.fill(1.0)
	var packed_roles := PackedInt32Array()
	for role in roles:
		packed_roles.append(role)
	return GravitySolver.new(_tuning).forces(
		PackedVector3Array(positions),
		PackedFloat64Array(masses),
		packed_roles,
		PackedFloat64Array(multipliers),
		pair_multipliers,
	)
