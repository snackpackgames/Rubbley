extends SimulationTestSuite
## The Gravity Well (ADR 0006) on its own: it pulls at full strength for its duration,
## then fades out and goes, and it drags on what moves inside it the whole time.

const WELL_SCENE := preload("res://game/gravity/gravity_well.tscn")
const DEBRIS_SCENE := preload("res://game/bodies/debris/debris.tscn")
const STRENGTH := 10.0

var _world: Node3D


## Builds an empty world.
func before_test() -> void:
	_world = auto_free(Node3D.new())
	add_child(_world)


## Full strength through its duration, half way through its fade at half strength, then gone.
func test_pulls_for_its_duration_then_fades_out_and_goes() -> void:
	var well := _add_well(STRENGTH, 0.0)
	await step_seconds(0.5)
	var during := well.gravity
	await step_seconds(1.0)
	var half_faded := well.gravity
	await step_seconds(0.6)

	assert_float(during).is_equal_approx(STRENGTH, 1e-3)
	assert_float(half_faded).is_equal_approx(STRENGTH * 0.5, 0.3)
	assert_bool(is_instance_valid(well) and not well.is_queued_for_deletion()).is_false()


## Debris coasting through a Well with no pull slows under its drag: 2 per second for
## 0.5 s leaves e⁻¹ ≈ 37% of its speed, so well under half.
func test_drags_on_bodies_inside_it() -> void:
	_add_well(0.0, 2.0)
	var debris := DEBRIS_SCENE.instantiate() as PlayPlaneBody
	debris.linear_velocity = Vector3(1, 0, 0)
	_world.add_child(debris)
	await step_seconds(0.5)
	assert_float(debris.linear_velocity.length()).is_less(0.5)


# A Well of radius 5 m at the origin that lasts 1 s, then fades over 1 s.
func _add_well(strength_m_per_s2: float, drag_per_second: float) -> GravityWell:
	var well := WELL_SCENE.instantiate() as GravityWell
	well.strength_m_per_s2 = strength_m_per_s2
	well.drag_per_second = drag_per_second
	well.radius_m = 5.0
	well.duration_s = 1.0
	well.fade_s = 1.0
	_world.add_child(well)
	return well
