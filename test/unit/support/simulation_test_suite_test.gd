extends SimulationTestSuite

var _ticks := 0


func before_test() -> void:
	_ticks = 0
	# Connected before step_seconds awaits, so the count includes the tick it resumes on.
	get_tree().physics_frame.connect(_count_tick)


func after_test() -> void:
	get_tree().physics_frame.disconnect(_count_tick)


# Expected tick counts are at the shipped 60 Hz tick rate.
func test_step_seconds_awaits_one_tick_per_tick_duration() -> void:
	await step_seconds(0.5)
	assert_int(_ticks).is_equal(30)


func test_step_seconds_rounds_a_partial_tick_up() -> void:
	await step_seconds(0.51)
	assert_int(_ticks).is_equal(31)


func test_step_seconds_ignores_float_error_in_the_product() -> void:
	# 4.15 × 60 is 249.00000000000003 in floating point.
	await step_seconds(4.15)
	assert_int(_ticks).is_equal(249)


func test_step_seconds_of_zero_awaits_no_ticks() -> void:
	await step_seconds(0.0)
	assert_int(_ticks).is_equal(0)


func _count_tick() -> void:
	_ticks += 1
