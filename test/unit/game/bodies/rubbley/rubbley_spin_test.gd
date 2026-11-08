extends SimulationTestSuite
## Rubbley's Spin (ADRs 0012, 0017), driven by injected Move Input frames on the shipped
## Rubbley and debris scenes: the shield it raises, and the lockout after it.

const RUBBLEY_SCENE := preload("res://game/bodies/rubbley/rubbley.tscn")
const DEBRIS_SCENE := preload("res://game/bodies/debris/debris.tscn")
# How fast debris is thrown at Rubbley, in m/s. Under the debris speed cap.
const THROW_M_PER_S := 15.0
# Where thrown debris starts, in metres from Rubbley: reached by the shield in well under
# the shipped Spin's duration.
const THROW_FROM_M := 4.0
# A deflected body must be moving away from Rubbley at least this fast. Gravity from
# Rubbley in the few ticks it takes can't turn a 15 m/s throw round on its own.
const MIN_BOUNCE_M_PER_S := 5.0
# Rubbley moves no faster than this when nothing hits him: gravity from 0.5 kg of debris
# in under half a second gives him well under 0.1 m/s. A 15 m/s hit from it gives him
# about 1 m/s.
const STILL_M_PER_S := 0.3

var _world: Node3D
var _rubbley: PlayPlaneBody
var _spin: RubbleySpin
var _frame: MoveInputFrame


## Frees the world a test left behind.
func after_test() -> void:
	if is_instance_valid(_world):
		_world.free()


## Debris thrown at a spinning Rubbley bounces off the shield.
func test_the_shield_deflects_debris() -> void:
	_build_world()
	var debris := _throw_debris(Vector3.RIGHT)
	await _fire_spin()
	await step_seconds(_spin.tuning.duration_s * 0.8)
	var away := _rubbley.global_position.direction_to(debris.global_position)
	assert_float(debris.linear_velocity.dot(away)).is_greater(MIN_BOUNCE_M_PER_S)


## The shield works all the way round: debris thrown from any of eight directions bounces
## off, and Rubbley takes none of the hit.
func test_the_shield_deflects_from_every_angle() -> void:
	for step in 8:
		var from := Vector3.RIGHT.rotated(Vector3.UP, TAU * step / 8.0)
		_build_world()
		var debris := _throw_debris(from)
		await _fire_spin()
		await step_seconds(_spin.tuning.duration_s * 0.8)
		var away := _rubbley.global_position.direction_to(debris.global_position)
		assert_float(debris.linear_velocity.dot(away)) \
				.override_failure_message("Not deflected from %s" % from) \
				.is_greater(MIN_BOUNCE_M_PER_S)
		assert_float(_rubbley.linear_velocity.length()) \
				.override_failure_message("Rubbley knocked from %s" % from) \
				.is_less(STILL_M_PER_S)
		_world.free()


## Without a Spin the same throw hits Rubbley: the debris doesn't bounce clear, and the
## hit knocks him.
func test_without_a_spin_debris_hits_rubbley() -> void:
	_build_world()
	var debris := _throw_debris(Vector3.RIGHT)
	await step_seconds(_spin.tuning.duration_s)
	var away := _rubbley.global_position.direction_to(debris.global_position)
	assert_float(debris.linear_velocity.dot(away)).is_less(MIN_BOUNCE_M_PER_S)
	assert_float(_rubbley.linear_velocity.length()).is_greater(STILL_M_PER_S)


## Mashing Spin every tick doesn't keep the shield up: it drops after one Spin's duration.
func test_mashing_doesnt_extend_the_shield() -> void:
	_build_world()
	await _start_of_tick()
	_frame.spin_fired = true
	await step_seconds(_spin.tuning.duration_s * 1.5)
	assert_bool(_spin.is_spinning()).is_false()


## Mashing through the lockout doesn't lengthen it: the first press after it ends fires a
## new Spin.
func test_spin_fires_again_once_the_lockout_ends() -> void:
	_build_world()
	var tick_s := 1.0 / Engine.physics_ticks_per_second
	await _start_of_tick()
	_frame.spin_fired = true
	await step_seconds(_spin.tuning.duration_s + _spin.tuning.lockout_s + tick_s * 2.0)
	assert_bool(_spin.is_spinning()).is_true()


## A single press during the lockout does nothing.
func test_a_press_during_the_lockout_does_nothing() -> void:
	_build_world()
	await _fire_spin()
	await step_seconds(_spin.tuning.duration_s + _spin.tuning.lockout_s * 0.5)
	await _fire_spin()
	assert_bool(_spin.is_spinning()).is_false()


## Spin fires while Rubbley holds Attract on self: the shield deflects debris, and the
## Attract keeps going.
func test_spin_works_during_attract() -> void:
	_build_world()
	var gravity_body := _rubbley.get_node("GravityBody") as GravityBody
	var tick_s := 1.0 / Engine.physics_ticks_per_second
	await _start_of_tick()
	_frame.aim = _rubbley.global_position
	_frame.attract = MoveInputFrame.Attract.PRESSED
	await step_seconds(tick_s)
	_frame.attract = MoveInputFrame.Attract.HELD
	var debris := _throw_debris(Vector3.BACK)
	await _fire_spin()
	await step_seconds(_spin.tuning.duration_s * 0.8)
	var away := _rubbley.global_position.direction_to(debris.global_position)
	assert_float(debris.linear_velocity.dot(away)).is_greater(MIN_BOUNCE_M_PER_S)
	assert_float(gravity_body.gravega_multiplier).is_greater(1.0)


## A Spin is perfectly timed only at its start, for the perfect window.
func test_the_perfect_window_opens_at_the_start_of_a_spin() -> void:
	_build_world()
	await _fire_spin()
	var perfect_at_start := _spin.is_perfect()
	await step_seconds(_spin.tuning.perfect_window_s)
	assert_bool(perfect_at_start).is_true()
	assert_bool(_spin.is_perfect()).is_false()
	assert_bool(_spin.is_spinning()).is_true()


# A bare world with gravity, no Drift, and Rubbley at the origin reading injected frames.
func _build_world() -> void:
	_world = Node3D.new()
	add_child(_world)
	var gravity_system := GravitySystem.new()
	gravity_system.tuning = GravityTuning.new()
	_world.add_child(gravity_system)
	_rubbley = _add(RUBBLEY_SCENE, Vector3.ZERO)
	_spin = _rubbley.get_node("Spin") as RubbleySpin
	_frame = MoveInputFrame.new()
	(_rubbley.get_node("Moves") as RubbleyMoves).injected_frame = _frame


func _add(scene: PackedScene, at: Vector3) -> PlayPlaneBody:
	var body := scene.instantiate() as PlayPlaneBody
	body.position = at
	_world.add_child(body)
	return body


# Adds debris [constant THROW_FROM_M] from Rubbley in [param from], flying straight at him.
func _throw_debris(from: Vector3) -> PlayPlaneBody:
	var debris := _add(DEBRIS_SCENE, from.normalized() * THROW_FROM_M)
	debris.linear_velocity = -from.normalized() * THROW_M_PER_S
	return debris


# Fires Spin for one tick.
func _fire_spin() -> void:
	await _start_of_tick()
	_frame.spin_fired = true
	await step_seconds(1.0 / Engine.physics_ticks_per_second)
	_frame.spin_fired = false


# Resumes at the start of a physics tick, before any node's _physics_process, so a frame
# set next is read in this tick.
func _start_of_tick() -> void:
	await get_tree().physics_frame
