class_name PlayPlaneBody
extends RigidBody3D
## A rigid body locked to the Play Plane (ADR 0003): it moves only in XZ and turns
## only around Y. Its damping, speed cap and CCD come from its [BodyTuning].

## The type-wide values for this body's type.
@export var tuning: BodyTuning


func _ready() -> void:
	assert(tuning != null, "%s needs a BodyTuning" % name)
	axis_lock_linear_y = true
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	# The project's default gravity is zero, so the only gravity a body feels through
	# the physics engine is an Anchored Body's Area point gravity; the GravitySystem adds the rest.
	gravity_scale = 1.0
	# Combined, so a Gravity Well's drag adds to it. The project default is zero.
	linear_damp_mode = RigidBody3D.DAMP_MODE_COMBINE
	linear_damp = tuning.linear_damp_per_second
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = tuning.angular_damp_per_second
	continuous_cd = tuning.continuous_cd


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	state.linear_velocity = state.linear_velocity.limit_length(tuning.speed_cap_m_per_s)
