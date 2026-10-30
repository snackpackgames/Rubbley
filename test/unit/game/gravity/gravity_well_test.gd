extends SimulationTestSuite
## The Gravity Well (ADR 0006) on its own: it pulls hardest at its centre and not at all
## past its edge, at full strength for its duration, then fades out and goes.

const WELL_SCENE := preload("res://game/gravity/gravity_well.tscn")
const DEBRIS_SCENE := preload("res://game/bodies/debris/debris.tscn")
const STRENGTH := 10.0
const RADIUS_M := 8.0

var _world: Node3D


## Builds an empty world.
func before_test() -> void:
	_world = auto_free(Node3D.new())
	add_child(_world)


## The pull falls off linearly from the centre: a quarter of the way out it pulls at
## three quarters, three quarters of the way out at a quarter, toward the centre.
func test_pulls_hardest_at_its_centre() -> void:
	var well := _add_well(1.0, 0.0)
	assert_vector(well.pull_on(Vector3(2, 0, 0))).is_equal_approx(
		Vector3(-0.75, 0, 0),
		Vector3.ONE * 1e-5,
	)
	assert_vector(well.pull_on(Vector3(0, 0, -6))).is_equal_approx(
		Vector3(0, 0, 0.25),
		Vector3.ONE * 1e-5,
	)


## Nothing past its edge is pulled, and nothing in its core, which has no direction to fall in.
func test_does_not_pull_past_its_edge_or_in_its_core() -> void:
	var well := _add_well(1.0, 0.0)
	assert_vector(well.pull_on(Vector3(RADIUS_M * 1.1, 0, 0))).is_equal(Vector3.ZERO)
	assert_vector(well.pull_on(Vector3(0.1, 0, 0))).is_equal(Vector3.ZERO)


## Debris inside a Well falls toward its centre.
func test_pulls_bodies_inside_it() -> void:
	_add_well(1.0, 0.0)
	var debris := _add_debris(Vector3(4, 0, 0))
	await step_seconds(0.25)
	assert_float(debris.linear_velocity.x).is_less(0.0)


## Full strength through its duration, half way through its fade at half strength, then gone.
func test_pulls_for_its_duration_then_fades_out_and_goes() -> void:
	var well := _add_well(1.0, 1.0)
	var during := await _speed_gained_over(0.1, Vector3(4, 0, 0))
	await step_seconds(1.4)
	var half_faded := await _speed_gained_over(0.1, Vector3(4, 0, 0))
	await step_seconds(0.6)

	# Moving 0.1 s apart barely changes where the debris is, so strength alone sets the ratio.
	assert_float(half_faded / during).is_between(0.4, 0.6)
	assert_bool(is_instance_valid(well) and not well.is_queued_for_deletion()).is_false()


# How much speed fresh debris placed at [param at] gains over [param seconds].
func _speed_gained_over(seconds: float, at: Vector3) -> float:
	var debris := _add_debris(at)
	await step_seconds(seconds)
	var speed := debris.linear_velocity.length()
	debris.free()
	return speed


func _add_debris(at: Vector3) -> PlayPlaneBody:
	var debris := DEBRIS_SCENE.instantiate() as PlayPlaneBody
	debris.position = at
	_world.add_child(debris)
	return debris


# A Well at the origin that pulls for [param duration_s], then fades over [param fade_s].
func _add_well(duration_s: float, fade_s: float) -> GravityWell:
	var well := WELL_SCENE.instantiate() as GravityWell
	well.strength_m_per_s2 = STRENGTH
	well.radius_m = RADIUS_M
	well.duration_s = duration_s
	well.fade_s = fade_s
	_world.add_child(well)
	return well
