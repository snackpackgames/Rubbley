class_name AnchoredPull
extends Area3D
## An Anchored Body's pull (ADR 0006): Area point gravity centred on the body, reaching
## out to the max range and falling off with the inverse square. The level's
## [GravitySystem] sets its strength every tick from the body's mass, so it pulls like
## the pairwise solver would but never moves the Anchored Body.

## The sphere the pull reaches across, a child of this Area.
@export var reach: CollisionShape3D


func _ready() -> void:
	assert(reach != null and reach.shape is SphereShape3D, "%s needs a sphere reach" % name)
	gravity_space_override = Area3D.SPACE_OVERRIDE_COMBINE
	gravity_point = true
	gravity_point_center = Vector3.ZERO
	# Strength is given at 1 m, so it is G × M like the solver's pull.
	gravity_point_unit_distance = 1.0


## Pulls with [param strength] (G × mass × Gravega multiplier, in m³/s²) out to
## [param range_m] metres.
func pull(strength: float, range_m: float) -> void:
	gravity = strength
	var sphere := reach.shape as SphereShape3D
	# Resizing rebuilds the shape in the physics server, so only do it when the range changes.
	if sphere.radius != range_m:
		sphere.radius = range_m
