extends SimulationTestSuite
## Rubbley's Attract (ADRs 0006, 0012), driven by injected Move Input frames on the
## shipped Rubbley, planet and debris scenes. Each outcome is compared with the same
## world left alone, so the bands follow any retune of the shipped Stats.

const RUBBLEY_SCENE := preload("res://game/bodies/rubbley/rubbley.tscn")
const PLANET_SCENE := preload("res://game/bodies/planet/planet.tscn")
const DEBRIS_SCENE := preload("res://game/bodies/debris/debris.tscn")
const HOLD_S := 1.0
# Attract must at least add this share to what gravity alone does. Every shipped
# multiplier is well above it, while a move that does nothing fails.
const MIN_GAIN := 1.3
# A Targeted Attract leaves the target's other pulls alone, so debris it pulls speeds up
# by no more than this share, from Rubbley falling into range of it. Raising the target's
# own multiplier instead doubles it.
const UNCHANGED_SHARE := 0.15

var _world: Node3D
var _rubbley: PlayPlaneBody
var _moves: RubbleyMoves
var _frame: MoveInputFrame


## Frees the world a test left behind.
func after_test() -> void:
	if is_instance_valid(_world):
		_world.free()


## Attract on self pulls debris toward Rubbley harder than his gravity alone.
func test_attract_on_self_pulls_debris_harder() -> void:
	var alone := await _debris_pulled_in_m(false)
	var attracted := await _debris_pulled_in_m(true)
	assert_float(attracted).is_greater(alone * MIN_GAIN)


## Attract on self raises his pull while held, and releasing it puts it back to normal.
func test_releasing_attract_on_self_restores_his_pull() -> void:
	_build_world()
	var gravity_body := _rubbley.get_node("GravityBody") as GravityBody
	var tick_s := 1.0 / Engine.physics_ticks_per_second
	await _start_of_tick()
	_frame.aim = _rubbley.global_position
	_frame.attract = MoveInputFrame.Attract.PRESSED
	await step_seconds(tick_s)
	_frame.attract = MoveInputFrame.Attract.HELD
	await step_seconds(tick_s)
	var held_multiplier := gravity_body.gravega_multiplier
	_frame.attract = MoveInputFrame.Attract.RELEASED
	await step_seconds(tick_s)

	assert_float(held_multiplier).is_greater(1.0)
	assert_float(gravity_body.gravega_multiplier).is_equal(1.0)


## An Attract whose release frame gameplay missed, as while paused, ends on the next frame
## that isn't held.
func test_a_missed_release_still_ends_attract() -> void:
	_build_world()
	var gravity_body := _rubbley.get_node("GravityBody") as GravityBody
	var tick_s := 1.0 / Engine.physics_ticks_per_second
	await _start_of_tick()
	_frame.aim = _rubbley.global_position
	_frame.attract = MoveInputFrame.Attract.PRESSED
	await step_seconds(tick_s)
	_frame.attract = MoveInputFrame.Attract.IDLE
	await step_seconds(tick_s)
	assert_float(gravity_body.gravega_multiplier).is_equal(1.0)


## A Targeted Attract on a glowing planet pulls Rubbley toward it harder than its gravity alone.
func test_targeted_attract_pulls_rubbley_toward_the_body() -> void:
	var alone := await _rubbley_speed_toward_planet(false)
	var attracted := await _rubbley_speed_toward_planet(true)
	assert_float(attracted).is_greater(alone * MIN_GAIN)


## A Targeted Attract strengthens only the Rubbley↔target pair: debris by the planet
## falls toward it no faster.
func test_targeted_attract_leaves_the_targets_other_pulls_alone() -> void:
	var alone := await _debris_speed_toward_planet(false)
	var attracted := await _debris_speed_toward_planet(true)
	assert_float(attracted).is_between(
		alone * (1.0 - UNCHANGED_SHARE),
		alone * (1.0 + UNCHANGED_SHARE),
	)


## The body under the aim when Attract starts stays the target while the aim moves off it,
## and is let go on release.
func test_the_target_stays_locked_until_release() -> void:
	_build_world()
	var planet := _add(PLANET_SCENE, Vector3(0, 0, -20))
	var planet_gravity := planet.get_node("GravityBody") as GravityBody
	var rubbley_gravity := _rubbley.get_node("GravityBody") as GravityBody
	var tick_s := 1.0 / Engine.physics_ticks_per_second
	await _start_of_tick()
	_frame.aim = planet.global_position
	_frame.attract = MoveInputFrame.Attract.PRESSED
	await step_seconds(tick_s)
	_frame.attract = MoveInputFrame.Attract.HELD
	_frame.aim = Vector3(30, 0, 30)
	await step_seconds(0.5)
	var held_multiplier: float = rubbley_gravity.pair_multipliers.get(planet_gravity, 1.0)
	var wells_while_held := _gravity_wells().size()
	_frame.attract = MoveInputFrame.Attract.RELEASED
	await step_seconds(tick_s)

	assert_float(held_multiplier).is_greater(1.0)
	assert_int(wells_while_held).is_equal(0)
	assert_dict(rubbley_gravity.pair_multipliers).is_empty()


## Attract into empty space places a Gravity Well at the aim, which pulls Rubbley toward it.
func test_attract_into_empty_space_places_a_gravity_well_that_pulls_rubbley() -> void:
	_build_world()
	var aim := Vector3(5, 0, 0)
	await _hold_attract(aim, 0.5)
	var wells := _gravity_wells()
	assert_int(wells.size()).is_equal(1)
	assert_vector(wells[0].global_position).is_equal_approx(aim, Vector3.ONE * 1e-3)
	assert_float(_rubbley.linear_velocity.x).is_greater(0.0)


## A Gravity Well lasts its duration and its fade, then goes.
func test_a_gravity_well_lasts_its_duration_and_fade() -> void:
	_build_world()
	await _hold_attract(Vector3(5, 0, 0), 1.0 / Engine.physics_ticks_per_second * 2.0)
	var lifetime_s := _moves.stats.gravity_well_duration_s + _moves.stats.gravity_well_fade_s
	await step_seconds(lifetime_s * 0.9)
	var wells_before := _gravity_wells().size()
	await step_seconds(lifetime_s * 0.2)
	assert_int(wells_before).is_equal(1)
	assert_int(_gravity_wells().size()).is_equal(0)


# Rubbley's speed toward a free planet 20 m away after the hold time, with or without
# a Targeted Attract on it.
func _rubbley_speed_toward_planet(attract: bool) -> float:
	_build_world()
	var planet := _add(PLANET_SCENE, Vector3(0, 0, -20))
	if attract:
		await _hold_attract(planet.global_position, HOLD_S)
	else:
		await step_seconds(HOLD_S)
	var toward := _rubbley.global_position.direction_to(planet.global_position)
	var speed := _rubbley.linear_velocity.dot(toward)
	_world.free()
	return speed


# How fast debris falls toward a free planet 20 m from Rubbley after the hold time, with
# or without a Targeted Attract on the planet. The debris sits beyond the planet's Capture
# Radius, so the capture assist leaves it alone, and out of Rubbley's range.
func _debris_speed_toward_planet(attract: bool) -> float:
	_build_world()
	var planet := _add(PLANET_SCENE, Vector3(0, 0, -20))
	var debris := _add(DEBRIS_SCENE, Vector3(0, 0, -44))
	if attract:
		await _hold_attract(planet.global_position, HOLD_S)
	else:
		await step_seconds(HOLD_S)
	var toward := debris.global_position.direction_to(planet.global_position)
	var speed := debris.linear_velocity.dot(toward)
	_world.free()
	return speed


func _gravity_wells() -> Array[GravityWell]:
	var wells: Array[GravityWell] = []
	for child in _moves.get_children():
		var well := child as GravityWell
		if well != null and not well.is_queued_for_deletion():
			wells.append(well)
	return wells


# How far debris 6 m from Rubbley closes on him in the hold time, with or without
# Attract on self.
func _debris_pulled_in_m(attract: bool) -> float:
	_build_world()
	var debris := _add(DEBRIS_SCENE, Vector3(6, 0, 0))
	var before_m := debris.global_position.distance_to(_rubbley.global_position)
	if attract:
		await _hold_attract(_rubbley.global_position, HOLD_S)
	else:
		await step_seconds(HOLD_S)
	var closed_m := before_m - debris.global_position.distance_to(_rubbley.global_position)
	_world.free()
	return closed_m


# A bare world with gravity, no Drift, and Rubbley at the origin reading injected frames.
func _build_world() -> void:
	_world = Node3D.new()
	add_child(_world)
	var gravity_system := GravitySystem.new()
	gravity_system.tuning = GravityTuning.new()
	_world.add_child(gravity_system)
	_rubbley = _add(RUBBLEY_SCENE, Vector3.ZERO)
	_moves = _rubbley.get_node("Moves") as RubbleyMoves
	_frame = MoveInputFrame.new()
	_moves.injected_frame = _frame


func _add(scene: PackedScene, at: Vector3) -> PlayPlaneBody:
	var body := scene.instantiate() as PlayPlaneBody
	body.position = at
	_world.add_child(body)
	return body


# Presses Attract at [param aim] for one tick, holds it for [param seconds], then
# releases it for one tick.
func _hold_attract(aim: Vector3, seconds: float) -> void:
	var tick_s := 1.0 / Engine.physics_ticks_per_second
	await _start_of_tick()
	_frame.aim = aim
	_frame.attract = MoveInputFrame.Attract.PRESSED
	await step_seconds(tick_s)
	_frame.attract = MoveInputFrame.Attract.HELD
	await step_seconds(seconds - tick_s)
	_frame.attract = MoveInputFrame.Attract.RELEASED
	await step_seconds(tick_s)
	_frame.attract = MoveInputFrame.Attract.IDLE


# Resumes at the start of a physics tick, before any node's _physics_process, so a frame
# set next is read in this tick. Set any earlier, and the first await would resume the
# test and change the frame before gameplay read it.
func _start_of_tick() -> void:
	await get_tree().physics_frame
