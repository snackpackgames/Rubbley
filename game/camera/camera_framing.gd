class_name CameraFraming
extends RefCounted
## How much of the Play Plane the CameraRig shows (ADR 0007): the screen's short side
## holds an extent that keeps Rubbley's radius a set share of it, between a least and
## a most extent.

var _tuning: CameraTuning
var _started := false
# The extent the zoom has reached, in metres.
var _extent_m := 0.0


## Returns the [enum Camera3D.KeepAspect] that holds the field of view across the
## short side of a screen of [param screen_size]: the width in portrait, the height
## in landscape.
static func keep_aspect_for(screen_size: Vector2) -> Camera3D.KeepAspect:
	return Camera3D.KEEP_WIDTH if screen_size.x < screen_size.y else Camera3D.KEEP_HEIGHT


func _init(tuning: CameraTuning) -> void:
	_tuning = tuning


## Returns the extent in metres the short side heads for, with Rubbley of
## [param radius_m] inside the Camera Zones framed by [param zones]. The highest
## priority zone may widen the view, even past the most extent, but never narrow it.
func target_extent_m(radius_m: float, zones: Array[CameraZoneFraming]) -> float:
	var by_size := clampf(
		radius_m / _tuning.rubbley_screen_fraction,
		_tuning.min_extent_m,
		_tuning.max_extent_m,
	)
	var winner: CameraZoneFraming = null
	for zone in zones:
		if winner == null or zone.priority > winner.priority:
			winner = zone
	return by_size if winner == null else maxf(by_size, winner.extent_m)


## Returns the extent in metres the short side shows after a frame of [param delta]
## seconds, easing toward [method target_extent_m]. The first step starts there.
func step(radius_m: float, zones: Array[CameraZoneFraming], delta: float) -> float:
	var target := target_extent_m(radius_m, zones)
	if not _started:
		_extent_m = target
		_started = true
	_extent_m = lerpf(_extent_m, target, HalfLife.closed_share(_tuning.zoom_half_life_s, delta))
	return _extent_m


## Returns how far from the Play Plane, in metres along its view, the camera sits for
## its field of view to show [param extent_m] metres across the short side.
func distance_m(extent_m: float) -> float:
	return extent_m * 0.5 / tan(deg_to_rad(_tuning.fov_deg) * 0.5)
