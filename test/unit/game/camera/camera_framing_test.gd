extends GdUnitTestSuite

const NO_ZONES: Array[CameraZoneFraming] = []

var _tuning: CameraTuning


## Builds Camera Tuning where Rubbley's 1 m reference radius is a tenth of the short
## side and the view widens in proportion to his radius, between 10 m and 50 m, with a
## 1 s zoom half-life.
func before_test() -> void:
	_tuning = CameraTuning.new()
	_tuning.rubbley_screen_fraction = 0.1
	_tuning.reference_radius_m = 1.0
	_tuning.size_zoom_exponent = 1.0
	_tuning.min_extent_m = 10.0
	_tuning.max_extent_m = 50.0
	_tuning.zoom_half_life_s = 1.0


## Rubbley's radius stays the same share of the short side as he grows: 2 m shows 20 m.
func test_the_extent_follows_rubbleys_size() -> void:
	var framing := CameraFraming.new(_tuning)
	assert_float(framing.target_extent_m(2.0, NO_ZONES)).is_equal_approx(20.0, 1e-4)


## With an exponent below 1 the view widens more slowly than Rubbley grows, so he fills
## more of the screen: at 0.5, a 4 m Rubbley shows 10 m × √4 = 20 m, not 40 m.
func test_the_view_widens_slower_than_rubbley_grows() -> void:
	_tuning.size_zoom_exponent = 0.5
	var framing := CameraFraming.new(_tuning)
	assert_float(framing.target_extent_m(4.0, NO_ZONES)).is_equal_approx(20.0, 1e-4)


## At the reference radius the exponent changes nothing: he is the tuned share of the
## short side, 1 m of 10 m.
func test_the_reference_radius_shows_the_tuned_share() -> void:
	_tuning.size_zoom_exponent = 0.5
	var framing := CameraFraming.new(_tuning)
	assert_float(framing.target_extent_m(1.0, NO_ZONES)).is_equal_approx(10.0, 1e-4)


## A tiny Rubbley still shows the least extent.
func test_the_extent_never_drops_below_the_minimum() -> void:
	var framing := CameraFraming.new(_tuning)
	assert_float(framing.target_extent_m(0.5, NO_ZONES)).is_equal_approx(10.0, 1e-4)


## A huge Rubbley shows no more than the most extent his size allows.
func test_the_extent_never_rises_above_the_maximum() -> void:
	var framing := CameraFraming.new(_tuning)
	assert_float(framing.target_extent_m(9.0, NO_ZONES)).is_equal_approx(50.0, 1e-4)


## Inside a Camera Zone the view widens to the zone's extent, even past the size maximum.
func test_a_camera_zone_widens_the_view() -> void:
	var framing := CameraFraming.new(_tuning)
	var zones: Array[CameraZoneFraming] = [_zone(0, 80.0)]
	assert_float(framing.target_extent_m(2.0, zones)).is_equal_approx(80.0, 1e-4)


## A Camera Zone never shows less than Rubbley's size calls for.
func test_a_camera_zone_never_narrows_the_view() -> void:
	var framing := CameraFraming.new(_tuning)
	var zones: Array[CameraZoneFraming] = [_zone(0, 15.0)]
	assert_float(framing.target_extent_m(2.0, zones)).is_equal_approx(20.0, 1e-4)


## Where Camera Zones overlap, the highest priority wins, even if it is narrower.
func test_the_highest_priority_zone_wins() -> void:
	var framing := CameraFraming.new(_tuning)
	var zones: Array[CameraZoneFraming] = [_zone(1, 90.0), _zone(3, 40.0), _zone(2, 70.0)]
	assert_float(framing.target_extent_m(2.0, zones)).is_equal_approx(40.0, 1e-4)


## The first step frames Rubbley's size at once, with no zoom in from nothing.
func test_the_first_step_starts_at_the_target_extent() -> void:
	var framing := CameraFraming.new(_tuning)
	assert_float(framing.step(2.0, NO_ZONES, 0.1)).is_equal_approx(20.0, 1e-4)


## Entering a Camera Zone eases the zoom out: one half-life covers half of 20 m → 80 m.
func test_the_zoom_eases_toward_a_new_extent() -> void:
	var framing := CameraFraming.new(_tuning)
	framing.step(2.0, NO_ZONES, 0.1)
	var zones: Array[CameraZoneFraming] = [_zone(0, 80.0)]
	assert_float(framing.step(2.0, zones, 1.0)).is_equal_approx(50.0, 1e-4)


## Zoom moves the camera, not its field of view: a 40° view shows 10 m of short side
## from 10 / (2 × tan 20°) = 13.737 m away.
func test_the_distance_shows_the_extent_on_the_short_side() -> void:
	_tuning.fov_deg = 40.0
	var framing := CameraFraming.new(_tuning)
	assert_float(framing.distance_m(10.0)).is_equal_approx(13.737, 1e-3)


## A portrait phone holds its field of view across the width, its short side.
func test_portrait_holds_the_width() -> void:
	(assert_int(CameraFraming.keep_aspect_for(Vector2(1080, 2400))).is_equal(Camera3D.KEEP_WIDTH))


## A landscape desktop holds its field of view across the height, its short side.
func test_landscape_holds_the_height() -> void:
	(assert_int(CameraFraming.keep_aspect_for(Vector2(1920, 1080))).is_equal(Camera3D.KEEP_HEIGHT))


func _zone(priority: int, extent_m: float) -> CameraZoneFraming:
	var zone := CameraZoneFraming.new()
	zone.priority = priority
	zone.extent_m = extent_m
	return zone
