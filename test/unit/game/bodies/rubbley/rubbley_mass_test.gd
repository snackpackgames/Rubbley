extends SimulationTestSuite
## Rubbley's Mass as his health and size (ADR 0017), on the shipped Rubbley, planet and
## debris scenes stepped in real physics: collisions take Mass, Spin makes him impervious,
## debris that hits him during Attract on self is absorbed and adds Mass, and his collider
## and mesh follow the Mass→size curve. Amounts come from the shipped Stats and Tuning, so
## the bands follow a retune.

const RUBBLEY_SCENE := preload("res://game/bodies/rubbley/rubbley.tscn")
const ANCHORED_PLANET_SCENE := preload("res://game/bodies/planet/anchored_planet.tscn")
const DEBRIS_SCENE := preload("res://game/bodies/debris/debris.tscn")
# How fast Rubbley is flung into a planet, in m/s: well past the safe impulse at his Mass.
const IMPACT_M_PER_S := 12.0
# A hit's Mass loss must land within this share of the loss at the launch speed. The
# planet's pull speeds him up a little before he lands, and contact solves within a tick.
const LOSS_SHARE := 0.2
# How fast debris is thrown at Rubbley, in m/s: fast enough that its hit would take Mass.
const DEBRIS_M_PER_S := 20.0
# How far a radius may sit from the curve's, in metres, for float error.
const RADIUS_EPSILON_M := 1e-4

var _world: Node3D
var _rubbley: PlayPlaneBody
var _mass: RubbleyMass
var _live_stats: RubbleyLiveStats
var _frame: MoveInputFrame


## Frees the world a test left behind.
func after_test() -> void:
	if is_instance_valid(_world):
		_world.free()


## Rubbley starts at his starting Mass, with the collider radius the curve gives for it
## and his mesh scaled to match.
func test_rubbley_starts_at_his_starting_mass_and_size() -> void:
	_build_world()
	await step_seconds(1.0 / Engine.physics_ticks_per_second)
	assert_float(_rubbley.mass).is_equal_approx(_stats().starting_mass_kg, 1e-6)
	_assert_size_matches_mass()


## Rubbley flung into an Anchored planet loses the Mass the collision damage rule gives
## for his momentum, and shrinks to match.
func test_a_hard_collision_takes_mass_and_shrinks_rubbley() -> void:
	_build_world()
	var start_kg := _rubbley.mass
	await _fling_into_planet()
	var tuning := _mass.damage_tuning
	var expected_kg := CollisionDamage.mass_lost_kg(start_kg * IMPACT_M_PER_S, tuning)
	assert_float(expected_kg).is_greater(0.0)
	assert_float(start_kg - _rubbley.mass).is_between(
		expected_kg * (1.0 - LOSS_SHARE),
		expected_kg * (1.0 + LOSS_SHARE),
	)
	_assert_size_matches_mass()


## The same hit while Spin's shield is up takes no Mass.
func test_spin_makes_rubbley_impervious_to_collision_damage() -> void:
	_build_world()
	var start_kg := _rubbley.mass
	await _start_of_tick()
	_frame.spin_fired = true
	await step_seconds(1.0 / Engine.physics_ticks_per_second)
	_frame.spin_fired = false
	var spin := _rubbley.get_node("Spin") as RubbleySpin
	await _fling_into_planet()
	assert_bool(spin.is_spinning()).is_true()
	assert_float(_rubbley.mass).is_equal(start_kg)


## Debris that hits Rubbley during Attract on self is absorbed: it is gone, he gains its
## Mass, takes no damage from it, and grows to match.
func test_debris_hitting_during_attract_on_self_is_absorbed() -> void:
	_build_world()
	var start_kg := _rubbley.mass
	await _start_of_tick()
	_frame.aim = _rubbley.global_position
	_frame.attract = MoveInputFrame.Attract.PRESSED
	await step_seconds(1.0 / Engine.physics_ticks_per_second)
	_frame.attract = MoveInputFrame.Attract.HELD
	var debris := _throw_debris()
	var debris_kg := debris.mass
	await step_seconds(0.5)
	assert_bool(is_instance_valid(debris)).is_false()
	assert_float(_rubbley.mass).is_equal_approx(start_kg + debris_kg, 1e-4)
	_assert_size_matches_mass()


## The same debris hitting Rubbley with no Attract isn't absorbed, and takes Mass.
func test_debris_hitting_without_attract_does_damage() -> void:
	_build_world()
	var start_kg := _rubbley.mass
	var debris := _throw_debris()
	await step_seconds(0.5)
	assert_bool(is_instance_valid(debris)).is_true()
	assert_float(_rubbley.mass).is_less(start_kg)


## A Stat Modifier that lowers the most Mass below Rubbley's cuts his Mass down to it,
## and he shrinks to match.
func test_a_lower_max_mass_cuts_mass_down() -> void:
	_build_world()
	await step_seconds(1.0 / Engine.physics_ticks_per_second)
	var new_max_kg := (_stats().min_mass_kg + _rubbley.mass) * 0.5
	var modifier := StatModifier.new()
	modifier.stat = RubbleyStats.Stat.MAX_MASS_KG
	modifier.operation = StatModifier.Operation.ADD
	modifier.value = new_max_kg - _stats().max_mass_kg
	_live_stats.add_modifier(modifier)
	await step_seconds(1.0 / Engine.physics_ticks_per_second)
	assert_float(_rubbley.mass).is_equal_approx(new_max_kg, 1e-4)
	_assert_size_matches_mass()


## A hit that would take more Mass than Rubbley has past his least leaves him at the least.
func test_a_hit_never_takes_mass_below_the_least() -> void:
	_build_world()
	var harsh := CollisionDamageTuning.new()
	harsh.safe_impulse_n_s = 0.0
	harsh.mass_lost_kg_per_n_s = 1.0
	_mass.damage_tuning = harsh
	await _fling_into_planet()
	assert_float(_rubbley.mass).is_equal_approx(_stats().min_mass_kg, 1e-4)
	_assert_size_matches_mass()


func _stats() -> RubbleyStats:
	return _live_stats.effective


# Asserts Rubbley's collider radius is the curve's radius for his Mass, and his mesh is
# scaled in proportion to it.
func _assert_size_matches_mass() -> void:
	var expected_m := _stats().mass_to_radius_m.sample(_rubbley.mass)
	var sphere := (_rubbley.get_node("Collider") as CollisionShape3D).shape as SphereShape3D
	assert_float(sphere.radius).is_equal_approx(expected_m, RADIUS_EPSILON_M)
	assert_float(_mass.radius_m()).is_equal_approx(expected_m, RADIUS_EPSILON_M)
	# The shipped mesh is 0.75 × its import at the 1 m radius it was placed for.
	var mesh := _rubbley.get_node("Mesh") as Node3D
	assert_float(mesh.scale.x).is_equal_approx(0.75 * expected_m, RADIUS_EPSILON_M)


# A bare world with gravity, no Drift, and Rubbley at the origin reading injected frames.
func _build_world() -> void:
	_world = Node3D.new()
	add_child(_world)
	var gravity_system := GravitySystem.new()
	gravity_system.tuning = GravityTuning.new()
	_world.add_child(gravity_system)
	_rubbley = _add(RUBBLEY_SCENE, Vector3.ZERO)
	_mass = _rubbley.get_node("Mass") as RubbleyMass
	_live_stats = _rubbley.get_node("LiveStats") as RubbleyLiveStats
	_frame = MoveInputFrame.new()
	(_rubbley.get_node("Moves") as RubbleyMoves).injected_frame = _frame


# Flings Rubbley at an Anchored planet whose surface starts 1 m from his, and lets him land.
func _fling_into_planet() -> void:
	var planet := ANCHORED_PLANET_SCENE.instantiate() as PlayPlaneBody
	planet.position = Vector3(_mass.radius_m() + 9.0, 0, 0)
	_world.add_child(planet)
	await get_tree().physics_frame
	_rubbley.linear_velocity = Vector3(IMPACT_M_PER_S, 0, 0)
	await step_seconds(0.3)


# Throws a piece of debris at Rubbley from 4 m away.
func _throw_debris() -> PlayPlaneBody:
	var debris := _add(DEBRIS_SCENE, Vector3(4, 0, 0))
	debris.linear_velocity = Vector3(-DEBRIS_M_PER_S, 0, 0)
	return debris


# Resumes at the start of a physics tick, before any node's _physics_process, so a frame
# set next is read in this tick.
func _start_of_tick() -> void:
	await get_tree().physics_frame


func _add(scene: PackedScene, at: Vector3) -> PlayPlaneBody:
	var body := scene.instantiate() as PlayPlaneBody
	body.position = at
	_world.add_child(body)
	return body
