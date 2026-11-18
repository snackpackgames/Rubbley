extends SimulationTestSuite
## The placeholder cues that show Attract on the shipped Rubbley and planet scenes, driven
## by injected Move Input frames: rings contract onto Rubbley while he Attracts on self,
## a tether joins him to the body a Targeted Attract has locked, and both go when
## Attract is released.

const RUBBLEY_SCENE := preload("res://game/bodies/rubbley/rubbley.tscn")
const PLANET_SCENE := preload("res://game/bodies/planet/planet.tscn")

var _world: Node3D
var _rubbley: PlayPlaneBody
var _frame: MoveInputFrame
var _rings: Node3D
var _tether: MeshInstance3D


## Frees the world a test left behind.
func after_test() -> void:
	if is_instance_valid(_world):
		_world.free()


## Nothing shows while Rubbley isn't Attracting.
func test_no_cue_without_attract() -> void:
	_build_world()
	await step_seconds(0.1)
	assert_bool(_rings.visible).is_false()
	assert_bool(_tether.visible).is_false()


## Holding Attract on self shows the rings round Rubbley, and releasing it hides them.
func test_attract_on_self_shows_rings_until_released() -> void:
	_build_world()
	await _press_attract(_rubbley.global_position)
	await step_seconds(0.2)
	var shown := _rings.visible
	var tether_shown := _tether.visible
	await _release_attract()
	assert_bool(shown).is_true()
	assert_bool(tether_shown).is_false()
	assert_bool(_rings.visible).is_false()


## The rings lie flat on the Play Plane round Rubbley however he tumbles.
func test_rings_stay_flat_and_centred_while_he_tumbles() -> void:
	_build_world()
	_rubbley.angular_velocity = Vector3(3.0, 0.0, 2.0)
	_rubbley.linear_velocity = Vector3(2.0, 0.0, 0.0)
	await _press_attract(_rubbley.global_position)
	await step_seconds(0.5)
	var up := _rings.global_basis.y.normalized()
	var offset := _rings.global_position - _rubbley.global_position
	await _release_attract()
	assert_float(up.dot(Vector3.UP)).is_greater(0.999)
	# They follow his drawn, interpolated position, which can trail the physics by a tick.
	assert_float(offset.length()).is_less(0.2)


## A Targeted Attract shows a tether reaching from Rubbley toward the glowing planet,
## and releasing it hides the tether.
func test_targeted_attract_shows_a_tether_until_released() -> void:
	_build_world()
	var planet := _add(PLANET_SCENE, Vector3(0, 0, -20))
	await _press_attract(planet.global_position)
	await step_seconds(0.2)
	var shown := _tether.visible
	var rings_shown := _rings.visible
	var middle := _tether.global_position
	var between := (_rubbley.global_position + planet.global_position) * 0.5
	await _release_attract()
	assert_bool(shown).is_true()
	assert_bool(rings_shown).is_false()
	# The tether runs surface to surface, so its middle sits on the line between them.
	assert_float(absf(middle.x - between.x)).is_less(0.5)
	assert_float(middle.z).is_between(planet.global_position.z, _rubbley.global_position.z)
	assert_bool(_tether.visible).is_false()


# A bare world with gravity, no Drift, and Rubbley at the origin reading injected frames.
func _build_world() -> void:
	_world = Node3D.new()
	add_child(_world)
	var gravity_system := GravitySystem.new()
	gravity_system.tuning = GravityTuning.new()
	_world.add_child(gravity_system)
	_rubbley = _add(RUBBLEY_SCENE, Vector3.ZERO)
	_frame = MoveInputFrame.new()
	(_rubbley.get_node("Moves") as RubbleyMoves).injected_frame = _frame
	_rings = _rubbley.get_node("AttractRings") as Node3D
	_tether = _rubbley.get_node("AttractTether") as MeshInstance3D


func _add(scene: PackedScene, at: Vector3) -> PlayPlaneBody:
	var body := scene.instantiate() as PlayPlaneBody
	body.position = at
	_world.add_child(body)
	return body


# Presses Attract at [param aim] for a tick, then holds it.
func _press_attract(aim: Vector3) -> void:
	await get_tree().physics_frame
	_frame.aim = aim
	_frame.attract = MoveInputFrame.Attract.PRESSED
	await step_seconds(1.0 / Engine.physics_ticks_per_second)
	_frame.attract = MoveInputFrame.Attract.HELD


# Releases Attract for a tick and lets the cue catch up for another.
func _release_attract() -> void:
	_frame.attract = MoveInputFrame.Attract.RELEASED
	await step_seconds(1.0 / Engine.physics_ticks_per_second)
	_frame.attract = MoveInputFrame.Attract.IDLE
	await step_seconds(2.0 / Engine.physics_ticks_per_second)
