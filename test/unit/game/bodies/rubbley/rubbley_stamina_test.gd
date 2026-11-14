extends SimulationTestSuite
## What Rubbley's moves cost (ADR 0017), driven by injected Move Input frames on the shipped
## Rubbley, planet and debris scenes: Attract drains Stamina while held, less on a Celestial
## Body, a Gravity Well, Repel and Spin each cost a fixed amount, and a
## move Rubbley can't afford doesn't fire. Rates and costs come from the shipped Stats,
## so the bands follow a retune.

const RUBBLEY_SCENE := preload("res://game/bodies/rubbley/rubbley.tscn")
const PLANET_SCENE := preload("res://game/bodies/planet/planet.tscn")
const DEBRIS_SCENE := preload("res://game/bodies/debris/debris.tscn")
const HOLD_S := 1.0
# A drain over the hold must land within this share of its rate × the hold. A tick of
# regen at release, or a tick more or less of draining, is well inside it.
const DRAIN_SHARE := 0.1
# A fixed cost must land within this much of the Stamina it takes: a tick or two of regen.
const COST_TOLERANCE := 1.0
# A body a refused Repel leaves alone moves no faster than this, from gravity alone.
const STILL_M_PER_S := 0.5
# How much Stamina below a cost the pool is left at, for a move it can't afford. More than
# the regen of the ticks before the move fires.
const SHORT_BY := 2.0

var _world: Node3D
var _rubbley: PlayPlaneBody
var _moves: RubbleyMoves
var _live_stats: RubbleyLiveStats
var _frame: MoveInputFrame


## Frees the world a test left behind.
func after_test() -> void:
	if is_instance_valid(_world):
		_world.free()


## Holding Attract on self drains Stamina at its rate.
func test_attract_on_self_drains_at_its_rate() -> void:
	_build_world()
	var start := _stamina()
	await _hold_attract(_rubbley.global_position, HOLD_S)
	var expected := _stats().attract_self_drain_per_second * HOLD_S
	_assert_near_share(start - _stamina(), expected)


## Holding a Targeted Attract on a glowing planet drains Stamina at the lower Celestial rate.
func test_targeted_attract_drains_at_the_celestial_rate() -> void:
	_build_world()
	var planet := _add(PLANET_SCENE, Vector3(0, 0, -20))
	var start := _stamina()
	await _hold_attract(planet.global_position, HOLD_S)
	var expected := _stats().attract_celestial_drain_per_second * HOLD_S
	assert_float(_stats().attract_celestial_drain_per_second).is_less(
		_stats().attract_self_drain_per_second,
	)
	_assert_near_share(start - _stamina(), expected)


## When Stamina runs out mid-Attract, Attract ends though it is still held, and holding on
## doesn't restart it as Stamina refills.
func test_attract_ends_when_stamina_runs_out() -> void:
	_build_world()
	var gravity_body := _rubbley.get_node("GravityBody") as GravityBody
	var tick_s := 1.0 / Engine.physics_ticks_per_second
	var drain_s := 0.25
	_live_stats.stamina.spend(_stamina() - _stats().attract_self_drain_per_second * drain_s)
	await _start_of_tick()
	_frame.aim = _rubbley.global_position
	_frame.attract = MoveInputFrame.Attract.PRESSED
	await step_seconds(tick_s)
	_frame.attract = MoveInputFrame.Attract.HELD
	var multiplier_while_draining := gravity_body.gravega_multiplier
	await step_seconds(drain_s + 0.25)
	var stamina_after := _stamina()
	assert_float(multiplier_while_draining).is_greater(1.0)
	assert_float(gravity_body.gravega_multiplier).is_equal(1.0)
	assert_float(stamina_after).is_greater(0.0)


## An Attract on self pressed with no Stamina doesn't raise Rubbley's pull.
func test_attract_with_no_stamina_doesnt_fire() -> void:
	_build_world()
	var gravity_body := _rubbley.get_node("GravityBody") as GravityBody
	_live_stats.stamina.spend(_stamina())
	await _start_of_tick()
	_frame.aim = _rubbley.global_position
	_frame.attract = MoveInputFrame.Attract.PRESSED
	await step_seconds(1.0 / Engine.physics_ticks_per_second)
	assert_float(gravity_body.gravega_multiplier).is_equal(1.0)


## A Gravity Well costs its fixed amount.
func test_a_gravity_well_costs_its_amount() -> void:
	_build_world()
	var start := _stamina()
	await _hold_attract(Vector3(5, 0, 0), 2.0 / Engine.physics_ticks_per_second)
	_assert_cost(start - _stamina(), _stats().gravity_well_cost)


## A Gravity Well Rubbley can't afford isn't placed, and the pool keeps what it had.
func test_a_gravity_well_it_cant_afford_isnt_placed() -> void:
	_build_world()
	_live_stats.stamina.spend(_stamina() - (_stats().gravity_well_cost - SHORT_BY))
	var start := _stamina()
	await _hold_attract(Vector3(5, 0, 0), 2.0 / Engine.physics_ticks_per_second)
	assert_int(_gravity_well_count()).is_equal(0)
	assert_float(_stamina()).is_greater_equal(start)


## A Repel Pulse costs its fixed amount.
func test_a_repel_pulse_costs_its_amount() -> void:
	_build_world()
	var start := _stamina()
	await _fire_repel(_rubbley.global_position)
	_assert_cost(start - _stamina(), _stats().repel_pulse_cost)


## A Targeted Repel costs Repel's fixed amount.
func test_a_targeted_repel_costs_its_amount() -> void:
	_build_world()
	var planet := _add(PLANET_SCENE, Vector3(0, 0, -20))
	var start := _stamina()
	await _fire_repel(planet.global_position)
	_assert_cost(start - _stamina(), _stats().repel_cost)


## A Gravity Ripple costs Repel's fixed amount.
func test_a_gravity_ripple_costs_its_amount() -> void:
	_build_world()
	var start := _stamina()
	await _fire_repel(Vector3(-5, 0, 0))
	_assert_cost(start - _stamina(), _stats().repel_cost)


## A Repel Pulse Rubbley can't afford doesn't fire: debris beside him stays put, and the
## pool keeps what it had.
func test_a_repel_pulse_it_cant_afford_doesnt_fire() -> void:
	_build_world()
	var debris := _add(DEBRIS_SCENE, Vector3(4, 0, 0))
	_live_stats.stamina.spend(_stamina() - (_stats().repel_pulse_cost - SHORT_BY))
	var start := _stamina()
	await _fire_repel(_rubbley.global_position)
	assert_float(debris.linear_velocity.length()).is_less(STILL_M_PER_S)
	assert_float(_stamina()).is_greater_equal(start)


## A Spin costs its fixed amount.
func test_a_spin_costs_its_amount() -> void:
	_build_world()
	var start := _stamina()
	await _fire_spin()
	_assert_cost(start - _stamina(), _stats().spin_cost)


## A Spin Rubbley can't afford doesn't raise the shield.
func test_a_spin_it_cant_afford_doesnt_fire() -> void:
	_build_world()
	var spin := _rubbley.get_node("Spin") as RubbleySpin
	_live_stats.stamina.spend(_stamina() - (_stats().spin_cost - SHORT_BY))
	await _fire_spin()
	assert_bool(spin.is_spinning()).is_false()


## A Spin its lockout refuses costs nothing.
func test_a_spin_the_lockout_refuses_costs_nothing() -> void:
	_build_world()
	await _fire_spin()
	var after_first := _stamina()
	await _fire_spin()
	assert_float(_stamina()).is_greater_equal(after_first)


## Stamina refills once Rubbley stops using it.
func test_stamina_refills_after_use() -> void:
	_build_world()
	await _fire_repel(_rubbley.global_position)
	var after_use := _stamina()
	await step_seconds(_stats().stamina_regen_delay_s + 0.5)
	assert_float(_stamina()).is_greater(after_use)


## A timed Stat Modifier that halves the max cuts Stamina down while it lasts, and the
## max comes back when it expires.
func test_a_timed_modifier_changes_the_max_until_it_expires() -> void:
	_build_world()
	var base_max := _stats().stamina_max
	var modifier := StatModifier.new()
	modifier.stat = RubbleyStats.Stat.STAMINA_MAX
	modifier.operation = StatModifier.Operation.MULTIPLY
	modifier.value = 0.5
	modifier.duration_s = 0.5
	_live_stats.add_modifier(modifier)
	var max_while_active := _stats().stamina_max
	var stamina_while_active := _stamina()
	await step_seconds(0.6)
	assert_float(max_while_active).is_equal_approx(base_max * 0.5, 1e-6)
	assert_float(stamina_while_active).is_equal_approx(base_max * 0.5, 1e-6)
	assert_float(_stats().stamina_max).is_equal_approx(base_max, 1e-6)


func _stats() -> RubbleyStats:
	return _live_stats.effective


func _stamina() -> float:
	return _live_stats.stamina.current()


func _assert_near_share(drained: float, expected: float) -> void:
	assert_float(drained).is_between(expected * (1.0 - DRAIN_SHARE), expected * (1.0 + DRAIN_SHARE))


func _assert_cost(spent: float, cost: float) -> void:
	assert_float(spent).is_between(cost - COST_TOLERANCE, cost)


func _gravity_well_count() -> int:
	var count := 0
	for child in _moves.get_children():
		if child is GravityWell and not child.is_queued_for_deletion():
			count += 1
	return count


# A bare world with gravity, no Drift, and Rubbley at the origin reading injected frames.
func _build_world() -> void:
	_world = Node3D.new()
	add_child(_world)
	var gravity_system := GravitySystem.new()
	gravity_system.tuning = GravityTuning.new()
	_world.add_child(gravity_system)
	_rubbley = _add(RUBBLEY_SCENE, Vector3.ZERO)
	_moves = _rubbley.get_node("Moves") as RubbleyMoves
	_live_stats = _rubbley.get_node("LiveStats") as RubbleyLiveStats
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


# Fires Repel at [param aim] for one tick, then lets the push take effect for another.
func _fire_repel(aim: Vector3) -> void:
	var tick_s := 1.0 / Engine.physics_ticks_per_second
	await _start_of_tick()
	_frame.aim = aim
	_frame.repel_fired = true
	await step_seconds(tick_s)
	_frame.repel_fired = false
	await step_seconds(tick_s)


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
