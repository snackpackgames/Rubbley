class_name TriggerPress
extends RefCounted
## Turns one analog trigger's travel into presses and releases, with hysteresis
## (ADR 0013): it presses past the press point and lets go only below the lower release
## point, so a trigger resting near the press point doesn't chatter.

var _tuning: InputTuning
var _down := false


func _init(tuning: InputTuning) -> void:
	_tuning = tuning


## Reads the trigger at [param travel], from 0 to 1. Returns true when that pressed or
## released it; [method is_down] says which.
func update(travel: float) -> bool:
	if not _down and travel > _tuning.trigger_press_point:
		_down = true
		return true
	if _down and travel < _tuning.trigger_release_point:
		_down = false
		return true
	return false


## Whether the trigger is pressed.
func is_down() -> bool:
	return _down


## Forgets a press, for an interruption: the trigger must pass the press point again.
func reset() -> void:
	_down = false
