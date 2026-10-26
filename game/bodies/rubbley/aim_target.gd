class_name AimTarget
extends RefCounted
## What is under the aim when a move starts (ADR 0012), which decides the use of the move
## that fires. Rubbley wins ties, so a self-move never misfires onto a body next to him.

## What the aim is on.
enum Kind {
	## Rubbley himself: Attract on self, or a Repel Pulse.
	RUBBLEY,
	## A glowing Celestial Body: Targeted Attract, or Targeted Repel.
	CELESTIAL_BODY,
	## Anything else: a Gravity Well, or a Gravity Ripple.
	EMPTY_SPACE,
}

## What the aim is on.
var kind := Kind.EMPTY_SPACE
## For [constant Kind.CELESTIAL_BODY], the body's index in the arrays given to
## [method resolve]; -1 otherwise.
var body_index := -1


## Returns what is under [param aim]: Rubbley at [param rubbley_at] with radius
## [param rubbley_radius_m], else the glowing body at [param body_positions] with
## [param body_radii] whose edge the aim is deepest behind, else empty space.
## Distances are measured on the Play Plane.
static func resolve(
	aim: Vector3,
	rubbley_at: Vector3,
	rubbley_radius_m: float,
	body_positions: PackedVector3Array,
	body_radii: PackedFloat64Array,
) -> AimTarget:
	var target := AimTarget.new()
	var on_plane := _flat(aim)
	if on_plane.distance_to(_flat(rubbley_at)) <= rubbley_radius_m:
		target.kind = Kind.RUBBLEY
		return target
	var deepest := 0.0
	for i in body_positions.size():
		var past_edge := on_plane.distance_to(_flat(body_positions[i])) - body_radii[i]
		if past_edge <= deepest:
			deepest = past_edge
			target.kind = Kind.CELESTIAL_BODY
			target.body_index = i
	return target


static func _flat(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)
