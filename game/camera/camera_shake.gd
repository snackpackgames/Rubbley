class_name CameraShake
extends RefCounted
## The screen shake when Rubbley is hurt. Each hit adds trauma, from the tuned least for a
## hit that takes no Mass up to full for a hit of the full-hit Mass, and trauma dies away
## at the decay rate. The shake's size is the trauma squared, so small hits nudge and big
## ones jolt. Its direction swings on two sines, so it needs no randomness.

var _tuning: CameraTuning
var _trauma := 0.0
var _time_s := 0.0


func _init(tuning: CameraTuning) -> void:
	_tuning = tuning


## Adds the trauma of a hit that took [param lost_kg] of Rubbley's Mass.
func hit(lost_kg: float) -> void:
	var added := _tuning.shake_least_trauma
	added += (1.0 - _tuning.shake_least_trauma) * lost_kg / _tuning.shake_full_hit_kg
	_trauma = clampf(_trauma + added, 0.0, 1.0)


## Moves time on by [param delta_s] seconds, letting the trauma die away.
func advance(delta_s: float) -> void:
	_time_s += delta_s
	_trauma = maxf(_trauma - _tuning.shake_decay_per_s * delta_s, 0.0)


## Returns the trauma now, from 0 at rest to 1.
func trauma() -> float:
	return _trauma


## Returns the shake's offset now, each axis within the trauma squared. The rig scales it
## to the screen.
func offset() -> Vector2:
	var size := _trauma * _trauma
	if size <= 0.0:
		return Vector2.ZERO
	var phase := TAU * _tuning.shake_frequency_hz * _time_s
	return Vector2(sin(phase), sin(phase * 1.31 + 1.7)) * size
