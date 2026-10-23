class_name Drift
extends RefCounted
## Drift: the steady push that carries Rubbley along a stage's path (ADR 0006).
## A force contributor next to [GravitySolver]: it returns one force per body.

var _tuning: GravityTuning


func _init(tuning: GravityTuning) -> void:
	_tuning = tuning


## Returns the Drift force on each of [param body_count] bodies. Only the body at
## [param drifting_index] is pushed, along [param direction] flattened onto the
## Play Plane. An index of -1 pushes nothing.
func forces(body_count: int, drifting_index: int, direction: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	result.resize(body_count)
	if drifting_index >= 0:
		var on_plane := Vector3(direction.x, 0.0, direction.z).normalized()
		result[drifting_index] = on_plane * _tuning.drift_force_n
	return result


## Returns how far Drift alone carries a body of [param mass] along its direction,
## between [param from_s] and [param to_s] seconds after it starts at
## [param start_speed] (m/s along the Drift), under linear damping
## [param linear_damp] (per second) and nothing else.
func expected_distance(
	mass: float,
	linear_damp: float,
	start_speed: float,
	from_s: float,
	to_s: float,
) -> float:
	var acceleration := _tuning.drift_force_n / mass
	if is_zero_approx(linear_damp):
		return (
			start_speed * (to_s - from_s) + acceleration / 2.0 * (to_s * to_s - from_s * from_s)
		)
	# Speed is v(t) = vₜ + (v₀ − vₜ)·e^(−c·t), with terminal speed vₜ = a / c.
	var terminal_speed := acceleration / linear_damp
	var decay := (exp(-linear_damp * from_s) - exp(-linear_damp * to_s)) / linear_damp
	return terminal_speed * (to_s - from_s) + (start_speed - terminal_speed) * decay
