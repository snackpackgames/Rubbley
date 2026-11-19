extends GdUnitTestSuite
## A flash that jumps to full when struck and fades out over its duration: the HUD's
## refusal flash and Rubbley's hit flash.

const TOLERANCE := 1e-4


## Before it is first struck, a flash is dark.
func test_a_flash_starts_dark() -> void:
	assert_float(FadeFlash.new(0.5).strength()).is_equal_approx(0.0, TOLERANCE)


## Struck, a flash is at full, fades evenly, and is dark at the end of its duration.
func test_a_flash_fades_over_its_duration() -> void:
	var flash := FadeFlash.new(0.5)
	flash.strike()
	var struck := flash.strength()
	flash.advance(0.25)
	var halfway := flash.strength()
	flash.advance(0.5)
	assert_float(struck).is_equal_approx(1.0, TOLERANCE)
	assert_float(halfway).is_equal_approx(0.5, TOLERANCE)
	assert_float(flash.strength()).is_equal_approx(0.0, TOLERANCE)


## Struck again mid-fade, a flash is back at full.
func test_a_new_strike_restarts_it() -> void:
	var flash := FadeFlash.new(0.5)
	flash.strike()
	flash.advance(0.4)
	flash.strike()
	assert_float(flash.strength()).is_equal_approx(1.0, TOLERANCE)
