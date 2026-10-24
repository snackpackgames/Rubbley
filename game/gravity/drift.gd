class_name Drift
extends RefCounted
## Drift: the steady carry that moves Rubbley along a stage's path (ADR 0006).
## A force contributor next to [GravitySolver]: it returns one force per body.
## The drifting body moves at Drift speed along the direction on top of its own
## motion, as in the controller-aim prototype: damping never slows the carried share,
## and it turns at once when the direction does.

var _tuning: GravityTuning
# The velocity Drift carried the body at last tick, so a turn can be paid for.
var _carried := Vector3.ZERO


func _init(tuning: GravityTuning) -> void:
	_tuning = tuning


## Returns the Drift force on each of [param body_count] bodies for a tick of
## [param delta] seconds. Only the body at [param drifting_index], of [param mass]
## and linear damping [param linear_damp] (per second), is pushed: by the change in
## its carried velocity along [param direction] (flattened onto the Play Plane),
## plus the damping on that velocity. The first call adds the whole Drift speed.
## An index of -1 pushes nothing and drops the carry.
func forces(
	body_count: int,
	drifting_index: int,
	direction: Vector3,
	mass: float,
	linear_damp: float,
	delta: float,
) -> PackedVector3Array:
	var result := PackedVector3Array()
	result.resize(body_count)
	if drifting_index < 0:
		_carried = Vector3.ZERO
		return result
	var on_plane := Vector3(direction.x, 0.0, direction.z).normalized()
	var carry := on_plane * _tuning.drift_speed_m_per_s
	result[drifting_index] = ((carry - _carried) / delta + carry * linear_damp) * mass
	_carried = carry
	return result


## Returns how far a carried body travels along a fixed Drift direction between
## [param from_s] and [param to_s] seconds after Drift starts, if it also starts with
## [param start_speed] (m/s along the Drift) of its own that fades under linear damping
## [param linear_damp] (per second), and nothing else acts on it.
func expected_distance(linear_damp: float, start_speed: float, from_s: float, to_s: float) -> float:
	var carried := _tuning.drift_speed_m_per_s * (to_s - from_s)
	if is_zero_approx(linear_damp):
		return carried + start_speed * (to_s - from_s)
	# The body's own speed is v₀·e^(−c·t).
	var decay := (exp(-linear_damp * from_s) - exp(-linear_damp * to_s)) / linear_damp
	return carried + start_speed * decay
