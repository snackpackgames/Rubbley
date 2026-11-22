extends GdUnitTestSuite
## Idle fade for the controller's aim cursor (ADR 0016, 0017): stays at full opacity while
## active and through [member AimCursorTuning.idle_hold_s], then fades to 0 over
## [member AimCursorTuning.fade_out_s].


## Stays at full opacity for as long as the controller remains active.
func test_stays_full_opacity_while_active() -> void:
	var fade := AimCursorFade.new(_tuning(1.0, 0.3))
	fade.advance(5.0, true)
	assert_float(fade.opacity()).is_equal_approx(1.0, 1e-5)


## Holds at full opacity until idle_hold_s elapses, fades evenly over fade_out_s, then
## reaches 0 and stays hidden.
func test_holds_then_fades_out_when_idle() -> void:
	var fade := AimCursorFade.new(_tuning(1.0, 0.4))
	fade.mark_active()
	fade.advance(0.99, false)
	assert_float(fade.opacity()).is_equal_approx(1.0, 1e-5)
	fade.advance(0.21, false)
	assert_float(fade.opacity()).is_equal_approx(0.5, 1e-4)
	fade.advance(0.25, false)
	assert_float(fade.opacity()).is_equal_approx(0.0, 1e-5)


## Returning to controller input after fading snaps opacity back to full and restarts the
## hold timer.
func test_activity_after_fade_snaps_back_to_full() -> void:
	var fade := AimCursorFade.new(_tuning(1.0, 0.3))
	fade.mark_active()
	fade.advance(2.0, false)
	assert_float(fade.opacity()).is_equal_approx(0.0, 1e-5)
	fade.mark_active()
	assert_float(fade.opacity()).is_equal_approx(1.0, 1e-5)
	fade.advance(0.5, false)
	assert_float(fade.opacity()).is_equal_approx(1.0, 1e-5)


## A zero fade duration hides the cursor immediately once the idle hold ends.
func test_zero_fade_duration_hides_immediately_after_hold() -> void:
	var fade := AimCursorFade.new(_tuning(1.0, 0.0))
	fade.mark_active()
	fade.advance(1.0, false)
	assert_float(fade.opacity()).is_equal_approx(1.0, 1e-5)
	fade.advance(0.01, false)
	assert_float(fade.opacity()).is_equal_approx(0.0, 1e-5)


## Hiding immediately drops opacity to 0 even when recently active.
func test_hide_now_drops_opacity_to_zero() -> void:
	var fade := AimCursorFade.new(_tuning(1.0, 0.3))
	fade.mark_active()
	fade.hide_now()
	assert_float(fade.opacity()).is_equal_approx(0.0, 1e-5)


func _tuning(idle_hold_s: float, fade_out_s: float) -> AimCursorTuning:
	var tuning := AimCursorTuning.new()
	tuning.idle_hold_s = idle_hold_s
	tuning.fade_out_s = fade_out_s
	return tuning
