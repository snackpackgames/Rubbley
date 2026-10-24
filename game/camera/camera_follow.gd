class_name CameraFollow
extends RefCounted
## Where the CameraRig looks each frame (ADR 0007): an exponential follow of Rubbley.
## Follow lag is an offset from Rubbley, clamped by the max offset so he never leaves
## the screen.

var _tuning: CameraTuning
var _started := false
# The point the follow has reached.
var _follow := Vector3.ZERO
# How far the Nudge peeks from Rubbley, in metres.
var _nudge := Vector3.ZERO


func _init(tuning: CameraTuning) -> void:
	_tuning = tuning


## Returns the point the camera centres on after a frame of [param delta] seconds,
## with Rubbley at [param target], a Nudge of [param nudge_input] (on the Play Plane,
## length up to 1; zero when released) and the screen's short side showing
## [param extent_m] metres. The first step starts on him.
func step(target: Vector3, nudge_input: Vector3, extent_m: float, delta: float) -> Vector3:
	if not _started:
		_follow = target
		_started = true
	_follow = _follow.lerp(target, HalfLife.closed_share(_tuning.follow_half_life_s, delta))
	var nudge_goal := nudge_input.limit_length(1.0) * _tuning.nudge_radius * extent_m
	_nudge = _nudge.lerp(nudge_goal, HalfLife.closed_share(_tuning.nudge_half_life_s, delta))
	var offset := (_follow - target + _nudge).limit_length(_tuning.max_offset * extent_m)
	# The follow carries on from what is shown, so a clamped lag never snaps back later.
	_follow = target + offset - _nudge
	return target + offset
