extends SimulationTestSuite
## Bodies on the Play Plane (ADR 0003): they move only in XZ, and turn freely on every
## axis, drawing starting spin from a passed-in [RandomNumberGenerator] (ADR 0018).

const DEBRIS_SCENE := preload("res://game/bodies/debris/debris.tscn")

var _world: Node3D


## Frees the world a test left behind.
func after_test() -> void:
	if is_instance_valid(_world):
		_world.free()


## A body set tumbling end over end keeps tumbling and never leaves the plane.
func test_a_body_tumbles_on_every_axis_but_stays_on_the_plane() -> void:
	_world = Node3D.new()
	add_child(_world)
	var piece := DEBRIS_SCENE.instantiate() as PlayPlaneBody
	_world.add_child(piece)
	piece.linear_velocity = Vector3(1.0, 0.0, 0.0)
	piece.angular_velocity = Vector3(2.0, 0.0, 2.0)
	await step_seconds(0.5)
	assert_float(absf(piece.angular_velocity.x)).is_greater(0.5)
	assert_float(absf(piece.angular_velocity.z)).is_greater(0.5)
	assert_float(piece.global_basis.y.dot(Vector3.UP)).is_less(0.99)
	assert_float(piece.global_position.y).is_equal_approx(0.0, 1e-4)


## A body whose tuning gives a starting spin starts turning inside that range, round some
## axis, and a light angular damping lets the drift carry on.
func test_a_body_starts_with_a_drifting_spin_inside_its_range() -> void:
	var tuning := BodyTuning.new()
	tuning.min_starting_spin_rad_per_s = 0.3
	tuning.max_starting_spin_rad_per_s = 0.6
	tuning.angular_damp_per_second = 0.0
	var piece := _add_body(tuning, _rng(1))
	var start := piece.angular_velocity.length()
	await step_seconds(1.0)
	assert_float(start).is_between(0.3, 0.6)
	assert_float(piece.angular_velocity.length()).is_between(0.3, 0.6)


## Starting spins are random across draws from one RNG, so two bodies don't turn alike.
func test_starting_spins_are_random() -> void:
	var tuning := BodyTuning.new()
	tuning.min_starting_spin_rad_per_s = 0.3
	tuning.max_starting_spin_rad_per_s = 0.6
	var rng := _rng(2)
	var first := _add_body(tuning, rng)
	var second := _add_body(tuning, rng)
	assert_vector(first.angular_velocity).is_not_equal(second.angular_velocity)


## Two bodies seeded with the same RNG seed start with the exact same spin.
func test_same_seed_gives_identical_starting_spin() -> void:
	var tuning := BodyTuning.new()
	tuning.min_starting_spin_rad_per_s = 0.3
	tuning.max_starting_spin_rad_per_s = 0.6
	var first := _add_body(tuning, _rng(99))
	var second := _add_body(tuning, _rng(99))
	assert_vector(first.angular_velocity).is_equal(second.angular_velocity)


## By default a body starts still.
func test_a_body_starts_still_by_default() -> void:
	var piece := _add_body(BodyTuning.new(), _rng(3))
	assert_vector(piece.angular_velocity).is_equal(Vector3.ZERO)


## A frozen body can't turn in the physics, so its starting spin turns only the visual it
## names, and the body itself stays put.
func test_a_frozen_body_spins_only_its_visual() -> void:
	var tuning := BodyTuning.new()
	tuning.min_starting_spin_rad_per_s = 0.3
	tuning.max_starting_spin_rad_per_s = 0.6
	var body := PlayPlaneBody.new()
	body.tuning = tuning
	body.freeze = true
	var body_rng := Rng.new()
	body.add_child(body_rng)
	body.rng = body_rng
	var visual := Node3D.new()
	visual.scale = Vector3(8.0, 8.0, 8.0)
	body.add_child(visual)
	body.spin_visual = visual
	_world = Node3D.new()
	add_child(_world)
	_world.add_child(body)
	body.rng.seed_with(_rng(4))
	var start := visual.basis
	await step_seconds(1.0)
	var turned := visual.basis.orthonormalized().get_rotation_quaternion().angle_to(
		start.orthonormalized().get_rotation_quaternion(),
	)
	assert_float(turned).is_between(0.2, 0.7)
	assert_vector(visual.basis.get_scale()).is_equal_approx(Vector3(8, 8, 8), Vector3.ONE * 1e-3)
	assert_bool(body.basis.is_equal_approx(Basis.IDENTITY)).is_true()


func _add_body(tuning: BodyTuning, source_rng: RandomNumberGenerator = null) -> PlayPlaneBody:
	if not is_instance_valid(_world):
		_world = Node3D.new()
		add_child(_world)
	var body := PlayPlaneBody.new()
	body.tuning = tuning
	var body_rng := Rng.new()
	body.add_child(body_rng)
	body.rng = body_rng
	var collider := CollisionShape3D.new()
	collider.shape = SphereShape3D.new()
	body.add_child(collider)
	_world.add_child(body)
	if source_rng != null:
		body.rng.seed_with(source_rng)
	return body


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
