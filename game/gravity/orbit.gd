class_name Orbit
extends RefCounted
## The one Orbit predicate (ADR 0018), shared by gameplay and tests. A body is in
## Orbit when it stays within a multiple of its primary's Capture Radius, with its
## distance inside a band, and has travelled far enough round the primary. The
## thresholds are in [GravityTuning]. Feed it the body's offset from its primary
## every tick with [method track].

var _tuning: GravityTuning
var _capture_radius_m: float
var _tracking := false
var _closest_m := 0.0
var _furthest_m := 0.0
var _travelled_rad := 0.0
var _last_offset := Vector2.ZERO


func _init(tuning: GravityTuning, capture_radius_m: float) -> void:
	_tuning = tuning
	_capture_radius_m = capture_radius_m


## Records where the body is now: [param offset] is its position minus its primary's.
## Leaving the multiple of the Capture Radius ends the Orbit; breaking the radius band
## starts the count again from here.
func track(offset: Vector3) -> void:
	var on_plane := Vector2(offset.x, offset.z)
	var distance := on_plane.length()
	if distance > _capture_radius_m * _tuning.orbit_radius_multiple or is_zero_approx(distance):
		_tracking = false
		_travelled_rad = 0.0
		return
	if not _tracking:
		_start(on_plane)
		return
	_closest_m = minf(_closest_m, distance)
	_furthest_m = maxf(_furthest_m, distance)
	if _furthest_m > _closest_m * _tuning.orbit_radius_band:
		_start(on_plane)
		return
	_travelled_rad += _last_offset.angle_to(on_plane)
	_last_offset = on_plane


## Whether the body is in Orbit as of the last [method track].
func is_in_orbit() -> bool:
	return _tracking and absf(_travelled_rad) >= deg_to_rad(_tuning.orbit_travel_deg)


func _start(on_plane: Vector2) -> void:
	_tracking = true
	_closest_m = on_plane.length()
	_furthest_m = _closest_m
	_travelled_rad = 0.0
	_last_offset = on_plane
