class_name SpinTimer
extends RefCounted
## Spin's timing (ADR 0012). One [method fire] raises the shield for the Spin's
## duration, then a lockout follows. Firing while the shield is up or locked out does
## nothing and doesn't extend either, so holding or mashing can't keep it up.

var _tuning: SpinTuning
# Seconds since the last Spin fired; INF before the first.
var _elapsed_s := INF


## Builds a timer on [param tuning]'s duration, lockout and perfect window.
func _init(tuning: SpinTuning) -> void:
	_tuning = tuning


## Raises the shield, unless it is already up or locked out.
func fire() -> void:
	if _elapsed_s >= _tuning.duration_s + _tuning.lockout_s:
		_elapsed_s = 0.0


## Moves time on by [param delta_s] seconds.
func advance(delta_s: float) -> void:
	_elapsed_s += delta_s


## Whether the shield is up.
func is_spinning() -> bool:
	return _elapsed_s < _tuning.duration_s


## Whether the shield is up and still inside its perfect window.
func is_perfect() -> bool:
	return is_spinning() and _elapsed_s < _tuning.perfect_window_s
