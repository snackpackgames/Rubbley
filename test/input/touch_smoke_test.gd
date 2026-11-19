extends SimulationTestSuite
## Touch end to end (ADRs 0012, 0013): real InputEvents through [method Input.parse_input_event]
## reach Move Input's frame. A pinch-in into empty space places a Gravity Well at the
## pinch centre, a pinch-out fires Repel, a swipe fires Spin and a two-finger drag Nudges.

const RUBBLEY_SCENE := preload("res://game/bodies/rubbley/rubbley.tscn")
const RIG_SCENE := preload("res://game/camera/camera_rig.tscn")
## How far from the pinched point the aim may land, in metres, for the camera's follow.
const AIM_TOLERANCE_M := 0.5
## Long enough for Move Input to read a batch of events and latch it.
const SETTLE_S := 0.1
## How far a finger moves each frame of a gesture, in pixels.
const STEP_PX := 4.0
## How many frames a pinch or drag lasts.
const GESTURE_FRAMES := 10
## Every touch index a test may use, all lifted after each test.
const FINGERS := [0, 1, 2]

var _world: Node3D
var _rubbley: PlayPlaneBody
var _rig: CameraRig


## Builds a world with Rubbley at rest at the origin and the CameraRig on him, and lets
## any interruption from the window opening wear off.
func before_test() -> void:
	_world = auto_free(Node3D.new())
	add_child(_world)
	_rubbley = RUBBLEY_SCENE.instantiate()
	_world.add_child(_rubbley)
	_rig = RIG_SCENE.instantiate()
	_rig.target = _rubbley
	_rig.target_mass = _rubbley.get_node("Mass") as RubbleyMass
	_world.add_child(_rig)
	await step_seconds(SETTLE_S)


## Lifts every finger a test left down, so Move Input starts the next test clean.
func after_test() -> void:
	for index: int in FINGERS:
		_touch(index, false, Vector2.ZERO)
	await step_seconds(SETTLE_S)


## A pinch-in Attracts at the pinch centre while both fingers stay down, shows the
## reticle, and places a Gravity Well there; lifting one finger releases it.
func test_a_pinch_in_attracts_at_the_pinch_centre() -> void:
	var pinched := Vector3(6, 0, 3)
	var centre := _rig.camera.unproject_position(pinched)
	var a := centre + Vector2(-60, 0)
	var b := centre + Vector2(60, 0)
	_touch(0, true, a)
	_touch(1, true, b)
	await get_tree().process_frame
	var states := await _pinch(a, b, STEP_PX)
	states.append_array(await _attract_states_over(SETTLE_S))
	var aim := _frame().aim
	var reticle_shown := MoveInputService.instance.reticle.visible
	_touch(1, false, b)
	states.append_array(await _attract_states_over(SETTLE_S))

	assert_array(states).contains([MoveInputFrame.Attract.PRESSED, MoveInputFrame.Attract.HELD])
	assert_array(states).contains([MoveInputFrame.Attract.RELEASED])
	assert_bool(reticle_shown).is_true()
	assert_float(Vector2(aim.x - pinched.x, aim.z - pinched.z).length()).is_less(AIM_TOLERANCE_M)
	var moves := _rubbley.get_node("Moves") as RubbleyMoves
	var wells := moves.get_children().filter(
		func(node: Node) -> bool:
			return node is GravityWell,
	)
	assert_int(wells.size()).is_equal(1)


## A pinch-out fires one Repel, and never Attracts.
func test_a_pinch_out_fires_repel() -> void:
	var centre := _rig.camera.unproject_position(Vector3(6, 0, 3))
	var a := centre + Vector2(-40, 0)
	var b := centre + Vector2(40, 0)
	_touch(0, true, a)
	_touch(1, true, b)
	await get_tree().process_frame
	var repels := [0]
	var attracted := [false]
	var count := func() -> void:
		repels[0] += int(_frame().repel_fired)
		attracted[0] = attracted[0] or _frame().attract != MoveInputFrame.Attract.IDLE
	get_tree().physics_frame.connect(count)
	await _pinch(a, b, -STEP_PX)
	await step_seconds(SETTLE_S)
	get_tree().physics_frame.disconnect(count)

	assert_int(repels[0]).is_equal(1)
	assert_bool(attracted[0]).is_false()


## A one-finger swipe fires one Spin.
func test_a_swipe_fires_spin() -> void:
	var at := Vector2(200, 200)
	_touch(0, true, at)
	var fired := 0
	for step in range(1, GESTURE_FRAMES + 1):
		_drag(0, at + Vector2(30 * step, 0))
		await get_tree().physics_frame
		fired += int(_frame().spin_fired)
	_touch(0, false, at)
	await step_seconds(SETTLE_S)
	assert_int(fired).is_equal(1)


## Two fingers dragged up together Nudge up, and Nudge springs back when they lift.
func test_a_two_finger_drag_nudges() -> void:
	var a := Vector2(300, 300)
	var b := Vector2(400, 300)
	_touch(0, true, a)
	_touch(1, true, b)
	await get_tree().process_frame
	for step in range(1, GESTURE_FRAMES + 1):
		var by := Vector2(0, -STEP_PX * 2.0 * step)
		_drag(0, a + by)
		_drag(1, b + by)
		await get_tree().physics_frame
	await get_tree().physics_frame
	var nudge := _frame().nudge
	_touch(0, false, a)
	_touch(1, false, b)
	await step_seconds(SETTLE_S)

	assert_float(nudge.y).is_greater(0.0)
	assert_float(absf(nudge.x)).is_less(1e-3)
	assert_vector(_frame().nudge).is_equal(Vector2.ZERO)


func _frame() -> MoveInputFrame:
	return MoveInputService.instance.frame


# Moves fingers 0 and 1, from [param a] and [param b], [param step_px] toward each other
# each frame (apart when negative), and returns every distinct Attract state on the way.
func _pinch(a: Vector2, b: Vector2, step_px: float) -> Array[MoveInputFrame.Attract]:
	var states: Array[MoveInputFrame.Attract] = []
	for step in range(1, GESTURE_FRAMES + 1):
		_drag(0, a.move_toward(b, step_px * step))
		_drag(1, b.move_toward(a, step_px * step))
		await get_tree().physics_frame
		var state := _frame().attract
		if states.is_empty() or states.back() != state:
			states.append(state)
	return states


# Every distinct Attract state Move Input's frame showed over [param seconds], in order.
func _attract_states_over(seconds: float) -> Array[MoveInputFrame.Attract]:
	var states: Array[MoveInputFrame.Attract] = []
	for _tick in ceili(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		var state := _frame().attract
		if states.is_empty() or states.back() != state:
			states.append(state)
	return states


func _touch(index: int, pressed: bool, at: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = at
	Input.parse_input_event(event)


func _drag(index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	Input.parse_input_event(event)
