extends GdUnitTestSuite
## The screen shake when Rubbley is hurt: a hit adds trauma, bigger for a hit that takes
## more Mass, the shake's size is the trauma squared, and it dies away.

const TOLERANCE := 1e-4

var _tuning: CameraTuning
var _shake: CameraShake


## Builds a shake on tuning set here, so a retune doesn't break the tests.
func before_test() -> void:
	_tuning = CameraTuning.new()
	_tuning.shake_least_trauma = 0.3
	_tuning.shake_full_hit_kg = 2.0
	_tuning.shake_decay_per_s = 2.0
	_tuning.shake_frequency_hz = 15.0
	_shake = CameraShake.new(_tuning)


## With no hit, nothing shakes.
func test_at_rest_it_doesnt_shake() -> void:
	_shake.advance(0.37)
	assert_vector(_shake.offset()).is_equal(Vector2.ZERO)


## Even a hit that takes no Mass shakes a little, a hit of half the full-hit Mass shakes
## halfway from there to full, and a hit of the full-hit Mass or more shakes fully.
func test_a_hit_adds_trauma_by_the_mass_it_took() -> void:
	_shake.hit(0.0)
	var least := _shake.trauma()
	_shake = CameraShake.new(_tuning)
	_shake.hit(1.0)
	var half := _shake.trauma()
	_shake.hit(10.0)
	assert_float(least).is_equal_approx(0.3, TOLERANCE)
	assert_float(half).is_equal_approx(0.65, TOLERANCE)
	assert_float(_shake.trauma()).is_equal_approx(1.0, TOLERANCE)


## The shake never strays further than the trauma squared, and dies away at its decay.
func test_the_shake_stays_inside_trauma_squared_and_dies_away() -> void:
	# 0.3 + 0.7 × 0.4 / 2 = 0.44 trauma.
	_shake.hit(0.4)
	var furthest := 0.0
	for _step in 20:
		_shake.advance(0.01)
		furthest = maxf(furthest, _shake.offset().length())
	var trauma_then := _shake.trauma()
	_shake.advance(1.0)
	assert_float(furthest).is_less_equal(0.44 * 0.44 * sqrt(2.0) + TOLERANCE)
	assert_float(furthest).is_greater(0.0)
	assert_float(trauma_then).is_equal_approx(0.44 - 0.2 * 2.0, TOLERANCE)
	assert_vector(_shake.offset()).is_equal(Vector2.ZERO)
