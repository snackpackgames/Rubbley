class_name ActiveStatModifiers
extends RefCounted
## The Stat Modifiers active on Rubbley (ADR 0017), each with the time it has left. A timed
## modifier goes once its duration is over; one with no duration lasts for good.

var _modifiers: Array[StatModifier] = []
# Seconds each modifier in _modifiers has left, by index; a modifier that lasts for good
# isn't counted down.
var _remaining_s := PackedFloat64Array()


## Makes [param modifier] active, for its duration or for good.
func add(modifier: StatModifier) -> void:
	_modifiers.append(modifier)
	_remaining_s.append(modifier.duration_s)


## Moves time on by [param delta_s] seconds and returns whether any modifier went.
func advance(delta_s: float) -> bool:
	var expired := false
	for i in range(_modifiers.size() - 1, -1, -1):
		if _modifiers[i].duration_s <= 0.0:
			continue
		_remaining_s[i] -= delta_s
		if _remaining_s[i] <= 0.0:
			_modifiers.remove_at(i)
			_remaining_s.remove_at(i)
			expired = true
	return expired


## Returns the modifiers active now.
func modifiers() -> Array[StatModifier]:
	return _modifiers
