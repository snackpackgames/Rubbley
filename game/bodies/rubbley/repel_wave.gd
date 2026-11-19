class_name RepelWave
extends RefCounted
## The placeholder look of a Repel, the same for all three uses: a red-orange ring that
## grows out from where the push starts to how far it reaches, fast at first and easing
## out, and fades to nothing as it gets there, as in the controller-aim prototype. Art
## direction will replace it.


## Returns the ring's radius in metres [param age_s] seconds after the Repel, for a wave
## lasting [param duration_s] that grows from [param from_m] to [param to_m].
static func radius_m(age_s: float, duration_s: float, from_m: float, to_m: float) -> float:
	var left := 1.0 - _progress(age_s, duration_s)
	return lerpf(from_m, to_m, 1.0 - left * left)


## Returns the ring's opacity from 1 at the Repel to 0 at the end of [param duration_s].
static func opacity(age_s: float, duration_s: float) -> float:
	return 1.0 - _progress(age_s, duration_s)


static func _progress(age_s: float, duration_s: float) -> float:
	return clampf(age_s / duration_s, 0.0, 1.0)
