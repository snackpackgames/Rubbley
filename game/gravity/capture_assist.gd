class_name CaptureAssist
extends RefCounted
## The capture assist (ADR 0006): a force contributor next to [GravitySolver] and
## [Drift]. It nudges a slow, lighter body inside a heavier body's Capture Radius
## toward a circular Orbit round it, at the body's current distance. It only adds
## force, so the body stays dynamic and Repel or a collision can still knock it out.

var _tuning: GravityTuning


func _init(tuning: GravityTuning) -> void:
	_tuning = tuning


## Returns the capture assist's force on each body, indexed like the inputs.
## [param roles] holds [enum GravityBody.Role] values, [param capture_radii] each
## body's Capture Radius as a primary (0 captures nothing), and [param capturable]
## whether a primary may capture it. A capturable body circles its nearest heavier
## Celestial or Anchored Body whose Capture Radius it is inside, if it's slower than
## [member GravityTuning.capture_speed_multiple] times circular speed there.
func forces(
	positions: PackedVector3Array,
	velocities: PackedVector3Array,
	masses: PackedFloat64Array,
	roles: PackedInt32Array,
	multipliers: PackedFloat64Array,
	linear_damps: PackedFloat64Array,
	capture_radii: PackedFloat64Array,
	capturable: Array[bool],
) -> PackedVector3Array:
	var count := positions.size()
	var result := PackedVector3Array()
	result.resize(count)
	for i in count:
		if not capturable[i] or roles[i] == GravityBody.Role.ANCHORED:
			continue
		var primary := _primary_of(i, positions, masses, roles, capture_radii)
		if primary < 0:
			continue
		var offset := _on_plane(positions[i] - positions[primary])
		var distance := offset.length()
		var pull := _pull(primary, i, distance, masses, roles, multipliers)
		var circular_speed := sqrt(pull * distance)
		var relative := _on_plane(velocities[i] - velocities[primary])
		if relative.length() > circular_speed * _tuning.capture_speed_multiple:
			continue
		var outward := offset / distance
		# Keep the way the body already goes round; one falling straight in goes anticlockwise.
		var way_round := -1.0 if outward.cross(relative).y < 0.0 else 1.0
		var target := Vector3.UP.cross(outward) * way_round * circular_speed
		# The body's own damping would slow even a circular Orbit, so the assist pays it back.
		var damping_payback := (target + _on_plane(velocities[primary])) * linear_damps[i]
		result[i] = (
			((target - relative) * _tuning.capture_assist_rate_per_second + damping_payback)
			* masses[i]
		)
	return result


# The nearest heavier body that pulls, with body i inside its Capture Radius, or -1.
func _primary_of(
	i: int,
	positions: PackedVector3Array,
	masses: PackedFloat64Array,
	roles: PackedInt32Array,
	capture_radii: PackedFloat64Array,
) -> int:
	var primary := -1
	var nearest := INF
	for j in positions.size():
		if j == i or roles[j] == GravityBody.Role.PASSIVE or masses[j] <= masses[i]:
			continue
		var distance := _on_plane(positions[i] - positions[j]).length()
		if distance > 0.0 and distance < capture_radii[j] and distance < nearest:
			primary = j
			nearest = distance
	return primary


# The acceleration toward the primary at this distance, matching what pulls the body:
# the solver's softened pair force, or an Anchored Body's unsoftened Area point gravity.
func _pull(
	primary: int,
	body: int,
	distance: float,
	masses: PackedFloat64Array,
	roles: PackedInt32Array,
	multipliers: PackedFloat64Array,
) -> float:
	var strength := _tuning.gravitational_constant * masses[primary] * multipliers[primary]
	if roles[primary] == GravityBody.Role.ANCHORED:
		return strength / (distance * distance)
	var softened := distance * distance + _tuning.softening_m * _tuning.softening_m
	return strength * multipliers[body] * distance / (softened * sqrt(softened))


func _on_plane(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)
