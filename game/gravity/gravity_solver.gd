class_name GravitySolver
extends RefCounted
## The pairwise gravity seam (ADR 0005): bodies in, forces out.
## Celestial Bodies pull each other with equal and opposite forces, and pull
## Passive Bodies one way (ADR 0006). The pull is softened inverse-square and
## stops at the max range in [GravityTuning]. Anchored Bodies pull through their own
## Area point gravity instead, so the solver leaves them out.

var _tuning: GravityTuning


func _init(tuning: GravityTuning) -> void:
	_tuning = tuning


## Returns the gravitational force on each body, indexed like the inputs.
## [param roles] holds [enum GravityBody.Role] values. A pair's pull is scaled by
## the product of both bodies' [param multipliers], so raising one body's
## Gravega multiplier scales every pair it's in.
func forces(
	positions: PackedVector3Array,
	masses: PackedFloat64Array,
	roles: PackedInt32Array,
	multipliers: PackedFloat64Array,
) -> PackedVector3Array:
	var count := positions.size()
	var result := PackedVector3Array()
	result.resize(count)
	var max_range_squared := _tuning.max_range_m * _tuning.max_range_m
	var softening_squared := _tuning.softening_m * _tuning.softening_m
	for i in count:
		if roles[i] != GravityBody.Role.CELESTIAL:
			continue
		for j in count:
			var mutual := roles[j] == GravityBody.Role.CELESTIAL
			# A Celestial pair is computed once, from its lower index.
			if j == i or (mutual and j < i) or roles[j] == GravityBody.Role.ANCHORED:
				continue
			var offset := positions[j] - positions[i]
			var distance_squared := offset.length_squared()
			# Bodies at one point have no direction to pull in.
			if distance_squared > max_range_squared or distance_squared == 0.0:
				continue
			# Plummer softening: G·m1·m2·d / (d² + ε²)^1.5, which is inverse-square far out.
			var softened := distance_squared + softening_squared
			var pair_multiplier := multipliers[i] * multipliers[j]
			# The pull on body i, toward body j.
			var force := (
				offset * (_tuning.gravitational_constant * masses[i] * masses[j] * pair_multiplier)
				/ (softened * sqrt(softened))
			)
			result[j] -= force
			if mutual:
				result[i] += force
	return result
