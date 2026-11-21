class_name FadeFlash
extends RefCounted
## A flash that jumps to full when struck and fades out evenly over its duration, then
## stays dark until struck again. The HUD's refusal flash and Rubbley's hit flash use it.

var _duration_s: float
# Seconds since the last strike. Infinite until the first.
var _elapsed_s := INF


## Builds a dark flash that fades over [param duration_s] seconds once struck.
func _init(duration_s: float) -> void:
	_duration_s = duration_s


## Lights the flash fully, for something that happened this frame.
func strike() -> void:
	_elapsed_s = 0.0


## Moves time on by [param delta_s] seconds.
func advance(delta_s: float) -> void:
	_elapsed_s += delta_s


## Returns how bright the flash is, from 1 just struck to 0 once faded.
func strength() -> float:
	if _duration_s <= 0.0:
		return 0.0
	return clampf(1.0 - _elapsed_s / _duration_s, 0.0, 1.0)
