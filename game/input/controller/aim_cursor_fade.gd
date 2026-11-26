class_name AimCursorFade
extends RefCounted
## Tracks how opaque the controller's aim cursor should be (ADR 0016): stays at full
## opacity while the controller is in use and for [member AimCursorTuning.idle_hold_s]
## afterwards, then fades to 0 over [member AimCursorTuning.fade_out_s].

var _tuning: AimCursorTuning
# Seconds since the controller was last used. Infinite until the first use.
var _idle_s := INF


## Builds a fade tracker driven by [param tuning].
func _init(tuning: AimCursorTuning) -> void:
	_tuning = tuning


## Marks the controller as active right now, snapping opacity back to full.
func mark_active() -> void:
	_idle_s = 0.0


## Hides the cursor immediately (for example when another scheme takes the aim).
func hide_now() -> void:
	_idle_s = INF


## Advances idle time by [param delta_s] seconds, or resets it while [param active].
func advance(delta_s: float, active: bool) -> void:
	if active:
		_idle_s = 0.0
	else:
		_idle_s += delta_s


## Returns the cursor's opacity, from 1 while active or within the hold down to 0 once
## faded out.
func opacity() -> float:
	if _idle_s <= _tuning.idle_hold_s:
		return 1.0
	if _tuning.fade_out_s <= 0.0:
		return 0.0
	var fade_elapsed := _idle_s - _tuning.idle_hold_s
	return clampf(1.0 - fade_elapsed / _tuning.fade_out_s, 0.0, 1.0)
