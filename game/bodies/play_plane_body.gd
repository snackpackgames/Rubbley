class_name PlayPlaneBody
extends RigidBody3D
## A rigid body locked to the Play Plane (ADR 0003): it moves only in XZ, and turns
## freely on every axis. Its damping, speed cap and CCD come from its [BodyTuning].
## Starting spin comes from a passed-in [RandomNumberGenerator] (ADR 0018).

## The type-wide values for this body's type.
@export var tuning: BodyTuning
## What turns in place of the body while it is frozen, such as an Anchored planet's
## mesh: a frozen body can't turn in the physics, so its starting spin turns this instead.
@export var spin_visual: Node3D

## The RNG passed in by the spawner or level before this body enters the tree.
var rng: RandomNumberGenerator

# The starting spin a frozen body's visual turns at, in radians per second round its axis.
var _visual_spin := Vector3.ZERO
var _spin_seeded := false


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
	set_process(false)
	# A GravityBody child freezes an Anchored body in its own _ready, before this one.
	if rng != null:
		apply_starting_spin(rng)


func _process(delta: float) -> void:
	var speed := _visual_spin.length()
	spin_visual.basis = Basis(_visual_spin / speed, speed * delta) * spin_visual.basis


## Returns whether an external [RandomNumberGenerator] has seeded this body's starting spin.
func is_spin_seeded() -> bool:
	return _spin_seeded


## Returns the starting visual spin vector applied to [member spin_visual] while frozen.
func visual_spin() -> Vector3:
	return _visual_spin


## Rolls and applies this body's starting spin from [param source_rng].
func apply_starting_spin(source_rng: RandomNumberGenerator) -> void:
	assert(source_rng != null, "%s needs a RandomNumberGenerator" % name)
	rng = source_rng
	_spin_seeded = true
	if not is_node_ready():
		return
	var spin := _starting_spin(source_rng)
	if freeze:
		_visual_spin = spin
	else:
		_visual_spin = Vector3.ZERO
		angular_velocity = spin
	set_process(spin_visual != null and not _visual_spin.is_zero_approx())


# A spin round a random axis, at a random speed inside the tuning's starting range.
func _starting_spin(source_rng: RandomNumberGenerator) -> Vector3:
	if tuning.max_starting_spin_rad_per_s <= 0.0:
		return Vector3.ZERO
	var axis := Vector3(
		source_rng.randfn(0.0, 1.0),
		source_rng.randfn(0.0, 1.0),
		source_rng.randfn(0.0, 1.0),
	)
	axis = Vector3.UP if axis.is_zero_approx() else axis.normalized()
	return (
		axis
		* source_rng.randf_range(
			tuning.min_starting_spin_rad_per_s,
			tuning.max_starting_spin_rad_per_s,
		)
	)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	state.linear_velocity = state.linear_velocity.limit_length(tuning.speed_cap_m_per_s)
