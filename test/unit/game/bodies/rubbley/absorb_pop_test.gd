extends GdUnitTestSuite
## The swell Rubbley's mesh gives when he absorbs debris: it jumps up by the swell, then
## eases back to his own size over the pop's duration.

const TOLERANCE := 1e-4

var _tuning: AbsorbPopTuning


## Builds a pop that swells by 0.4 and lasts 0.2 s.
func before_test() -> void:
	_tuning = AbsorbPopTuning.new()
	_tuning.swell = 0.4
	_tuning.duration_s = 0.2


## Before anything is absorbed the mesh is at its own size.
func test_no_pop_before_an_absorb() -> void:
	var pop := AbsorbPop.new(_tuning)
	pop.advance(0.05)
	assert_float(pop.scale()).is_equal(1.0)


## An absorb swells the mesh at once by the whole swell.
func test_an_absorb_swells_at_once() -> void:
	var pop := AbsorbPop.new(_tuning)
	pop.start()
	assert_float(pop.scale()).is_equal_approx(1.4, TOLERANCE)


## The swell eases out: halfway through, a quarter of it is left, 1 + 0.4 × 0.5².
func test_the_swell_eases_back() -> void:
	var pop := AbsorbPop.new(_tuning)
	pop.start()
	pop.advance(0.1)
	assert_float(pop.scale()).is_equal_approx(1.1, TOLERANCE)


## Once the duration is over the mesh is back at its own size.
func test_the_pop_ends_after_its_duration() -> void:
	var pop := AbsorbPop.new(_tuning)
	pop.start()
	pop.advance(0.25)
	assert_float(pop.scale()).is_equal(1.0)


## Another absorb mid-pop swells it fully again.
func test_another_absorb_restarts_the_pop() -> void:
	var pop := AbsorbPop.new(_tuning)
	pop.start()
	pop.advance(0.15)
	pop.start()
	assert_float(pop.scale()).is_equal_approx(1.4, TOLERANCE)
