extends SimulationTestSuite
## The placeholder Repel cue on the shipped Rubbley scene, driven by injected Move Input
## frames: every use of Repel shows a wave, and each wave is gone once it has played out.

const RUBBLEY_SCENE := preload("res://game/bodies/rubbley/rubbley.tscn")
const ANCHORED_PLANET_SCENE := preload("res://game/bodies/planet/anchored_planet.tscn")

var _world: Node3D
var _rubbley: PlayPlaneBody
var _cue: RubbleyRepelCue
var _frame: MoveInputFrame


## Builds a world with Rubbley at the origin reading injected frames, and an Anchored
## planet to the north to target.
func before_test() -> void:
	_world = auto_free(Node3D.new())
	add_child(_world)
	_rubbley = RUBBLEY_SCENE.instantiate()
	_world.add_child(_rubbley)
	var planet := ANCHORED_PLANET_SCENE.instantiate() as Node3D
	planet.position = Vector3(0, 0, -20)
	_world.add_child(planet)
	_cue = _rubbley.get_node("RepelCue") as RubbleyRepelCue
	_frame = MoveInputFrame.new()
	(_rubbley.get_node("Moves") as RubbleyMoves).injected_frame = _frame


## A Repel Pulse, a Gravity Ripple and a Targeted Repel each show a wave, and the waves
## are gone once they have played out.
func test_every_repel_shows_a_wave_that_plays_out() -> void:
	var counts: Array[int] = []
	for aim: Vector3 in [Vector3.ZERO, Vector3(8, 0, 0), Vector3(0, 0, -20)]:
		await _fire_repel(aim)
		counts.append(_cue.wave_count())
	await step_seconds(_cue.tuning.duration_s + 0.1)
	var waves := _rubbley.get_node("RepelWaves") as MeshInstance3D

	assert_array(counts).contains_exactly([1, 2, 3])
	assert_int(_cue.wave_count()).is_equal(0)
	assert_int((waves.mesh as ImmediateMesh).get_surface_count()).is_equal(0)


# Fires Repel at [param aim] for one tick.
func _fire_repel(aim: Vector3) -> void:
	var tick_s := 1.0 / Engine.physics_ticks_per_second
	await get_tree().physics_frame
	_frame.aim = aim
	_frame.repel_fired = true
	await step_seconds(tick_s)
	_frame.repel_fired = false
