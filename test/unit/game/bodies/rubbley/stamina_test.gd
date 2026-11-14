extends GdUnitTestSuite
## Rubbley's Stamina pool (ADR 0017): moves spend it or drain it, a move it can't afford
## doesn't fire, it refills once no move has used it for the regen delay, and a smaller
## max cuts it down.

var _stats: RubbleyStats
var _stamina: Stamina


## Builds a full 100-point pool that refills 20 a second with no delay.
func before_test() -> void:
	_stats = RubbleyStats.new()
	_stats.stamina_max = 100.0
	_stats.stamina_regen_per_second = 20.0
	_stats.stamina_regen_delay_s = 0.0
	_stamina = Stamina.new(_stats)


## A new pool starts full.
func test_starts_full() -> void:
	assert_float(_stamina.current()).is_equal(100.0)


## Spending a fixed cost takes it off the pool.
func test_spending_takes_the_cost() -> void:
	var paid := _stamina.spend(30.0)
	assert_bool(paid).is_true()
	assert_float(_stamina.current()).is_equal(70.0)


## A cost the pool can't cover isn't paid, and takes nothing.
func test_a_cost_it_cant_afford_takes_nothing() -> void:
	_stamina.spend(80.0)
	var paid := _stamina.spend(30.0)
	assert_bool(paid).is_false()
	assert_float(_stamina.current()).is_equal(20.0)


## Spending half takes half of what is left, so two in a row leave a quarter.
func test_spending_half_twice_leaves_a_quarter() -> void:
	_stamina.spend(20.0)
	_stamina.spend_half()
	var paid := _stamina.spend_half()
	assert_bool(paid).is_true()
	assert_float(_stamina.current()).is_equal_approx(20.0, 1e-6)


## An empty pool can't spend half.
func test_an_empty_pool_cant_spend_half() -> void:
	_stamina.spend(100.0)
	assert_bool(_stamina.spend_half()).is_false()


## Draining takes the rate times the tick, and stops at empty, after which nothing drains.
func test_draining_stops_at_empty() -> void:
	var drained := _stamina.drain(40.0, 0.5)
	var drained_to_empty := _stamina.drain(400.0, 0.5)
	var drained_from_empty := _stamina.drain(40.0, 0.5)
	assert_bool(drained).is_true()
	assert_bool(drained_to_empty).is_true()
	assert_bool(drained_from_empty).is_false()
	assert_float(_stamina.current()).is_equal(0.0)


## Stamina doesn't refill on a tick a move used it, and refills at its rate on the next
## tick no move does, up to the max.
func test_refills_only_while_unused() -> void:
	_stamina.spend(50.0)
	_stamina.advance(0.5)
	var after_use := _stamina.current()
	_stamina.advance(0.5)
	var after_idle := _stamina.current()
	_stamina.advance(10.0)
	assert_float(after_use).is_equal(50.0)
	assert_float(after_idle).is_equal_approx(60.0, 1e-6)
	assert_float(_stamina.current()).is_equal(100.0)


## With a regen delay, Stamina waits that long after its last use before refilling, then
## refills only for the part of a tick past the delay: 0.4 s of a 0.5 s tick gives 8.
func test_waits_the_regen_delay_before_refilling() -> void:
	_stats.stamina_regen_delay_s = 1.0
	_stamina = Stamina.new(_stats)
	_stamina.spend(50.0)
	_stamina.advance(0.1)
	_stamina.advance(0.9)
	var after_delay := _stamina.current()
	_stamina.advance(0.5)
	assert_float(after_delay).is_equal(50.0)
	assert_float(_stamina.current()).is_equal_approx(58.0, 1e-6)


## New Stats with a smaller max cut the pool down to it; a larger max leaves it as it was.
func test_new_stats_clamp_to_their_max() -> void:
	var smaller := RubbleyStats.new()
	smaller.stamina_max = 60.0
	_stamina.set_stats(smaller)
	var after_smaller := _stamina.current()
	var larger := RubbleyStats.new()
	larger.stamina_max = 150.0
	_stamina.set_stats(larger)
	assert_float(after_smaller).is_equal(60.0)
	assert_float(_stamina.current()).is_equal(60.0)
