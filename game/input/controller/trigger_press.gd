class_name TriggerPress
extends RefCounted
## Turns one analog trigger's travel into presses and releases, with hysteresis
## (ADR 0013): it presses past the press point and lets go only below the lower release
## point, so a trigger resting near the press point doesn't chatter.

## What a reading of the trigger did.
enum Edge {
	## Nothing changed.
	NONE,
	## The trigger pressed.
	PRESSED,
	## The trigger let go.
	RELEASED,
}

var _tuning: InputTuning
var _down := false
var _travel := 0.0


func _init(tuning: InputTuning) -> void:
	_tuning = tuning


## Reads the trigger at [param travel], from 0 to 1, and returns whether that pressed or
## released it.
func update(travel: float) -> Edge:
	_travel = travel
	if not _down and travel > _tuning.trigger_press_point:
		_down = true
		return Edge.PRESSED
	if _down and travel < _tuning.trigger_release_point:
		_down = false
		return Edge.RELEASED
	return Edge.NONE


## Whether the trigger is pressed.
func is_down() -> bool:
	return _down


## Whether the trigger hasn't been let go: it rests at or past the release point, pressed
## or not. Input stays swallowed after an interruption while it does.
func is_held() -> bool:
	return _travel >= _tuning.trigger_release_point


## Forgets a press, for an interruption: the trigger must pass the press point again.
func reset() -> void:
	_down = false
