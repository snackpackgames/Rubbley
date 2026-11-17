class_name PlayPlaneBody
extends RigidBody3D
## A rigid body locked to the Play Plane (ADR 0003): it moves only in XZ, and turns
## freely on every axis. Its damping, speed cap and CCD come from its [BodyTuning].

## The type-wide values for this body's type.
@export var tuning: BodyTuning


func _ready() -> void:
	assert(tuning != null, "%s needs a BodyTuning" % name)
	axis_lock_linear_y = true
	# The body turns round its origin, so an off-centre shape can't lift it off the plane.
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3.ZERO
	# The project's default gravity is zero, so the only gravity a body feels through
	# the physics engine is an Anchored Body's Area point gravity; the GravitySystem adds the rest.
	gravity_scale = 1.0
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = tuning.linear_damp_per_second
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = tuning.angular_damp_per_second
	continuous_cd = tuning.continuous_cd
	angular_velocity = _starting_spin()


# A spin round a random axis, at a random speed inside the tuning's starting range.
func _starting_spin() -> Vector3:
	if tuning.max_starting_spin_rad_per_s <= 0.0:
		return Vector3.ZERO
	var axis := Vector3(randfn(0.0, 1.0), randfn(0.0, 1.0), randfn(0.0, 1.0)).normalized()
	return axis * randf_range(
		tuning.min_starting_spin_rad_per_s,
		tuning.max_starting_spin_rad_per_s,
	)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	state.linear_velocity = state.linear_velocity.limit_length(tuning.speed_cap_m_per_s)
