extends SimulationTestSuite
## Mouse + keyboard end to end (ADRs 0012, 0013): real InputEvents through
## [method Input.parse_input_event] reach Move Input's frame, and a left click into
## empty space places a Gravity Well where the mouse points.

const RUBBLEY_SCENE := preload("res://game/bodies/rubbley/rubbley.tscn")
const RIG_SCENE := preload("res://game/camera/camera_rig.tscn")
## How far from the clicked point the aim may land, in metres, for the camera's follow.
const AIM_TOLERANCE_M := 0.5
## Long enough for Move Input to read a batch of events and latch it.
const SETTLE_S := 0.1

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
	_world.add_child(_rig)
	await step_seconds(SETTLE_S)


## Releases anything a test left held, so Move Input starts the next test clean.
func after_test() -> void:
	_mouse_button(MOUSE_BUTTON_LEFT, false, Vector2.ZERO)
	for key: Key in [KEY_W, KEY_D, KEY_SPACE]:
		_key(key, false)
	await step_seconds(SETTLE_S)


## A left click aims at the mouse: pressed, then held, then released, and Rubbley places
## a Gravity Well under it.
func test_a_left_click_attracts_at_the_mouse() -> void:
	var clicked := Vector3(6, 0, 3)
	var screen_point := _rig.camera.unproject_position(clicked)
	_mouse_motion(screen_point)
	_mouse_button(MOUSE_BUTTON_LEFT, true, screen_point)
	var states := await _attract_states_over(SETTLE_S)
	var aim := _frame().aim
	_mouse_button(MOUSE_BUTTON_LEFT, false, screen_point)
	states.append_array(await _attract_states_over(SETTLE_S))

	assert_array(states).contains([MoveInputFrame.Attract.PRESSED, MoveInputFrame.Attract.HELD])
	assert_array(states).contains([MoveInputFrame.Attract.RELEASED])
	assert_float(Vector2(aim.x - clicked.x, aim.z - clicked.z).length()).is_less(AIM_TOLERANCE_M)
	var moves := _rubbley.get_node("Moves") as RubbleyMoves
	var wells := moves.get_children().filter(
		func(node: Node) -> bool:
			return node is GravityWell,
	)
	assert_int(wells.size()).is_equal(1)


## Pausing mid-Attract releases it, and the button still held after unpausing is swallowed.
func test_pausing_releases_attract_and_swallows_the_held_button() -> void:
	var screen_point := _rig.camera.unproject_position(Vector3(6, 0, 3))
	_mouse_button(MOUSE_BUTTON_LEFT, true, screen_point)
	await step_seconds(SETTLE_S)
	get_tree().paused = true
	var paused_states := await _attract_states_over(SETTLE_S)
	get_tree().paused = false
	var resumed_states := await _attract_states_over(SETTLE_S)

	assert_array(paused_states).contains([MoveInputFrame.Attract.RELEASED])
	assert_array(resumed_states).contains_exactly([MoveInputFrame.Attract.IDLE])


## Spacebar fires one Spin.
func test_spacebar_fires_spin() -> void:
	_key(KEY_SPACE, true)
	var fired := 0
	for _tick in ceili(SETTLE_S * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		if _frame().spin_fired:
			fired += 1
	assert_int(fired).is_equal(1)


## Held WASD Nudges at full in its direction, diagonals combine, and Nudge is zero on release.
func test_wasd_nudges_digitally() -> void:
	_key(KEY_W, true)
	await step_seconds(SETTLE_S)
	var up := _frame().nudge
	_key(KEY_D, true)
	await step_seconds(SETTLE_S)
	var diagonal := _frame().nudge
	_key(KEY_W, false)
	_key(KEY_D, false)
	await step_seconds(SETTLE_S)

	assert_vector(up).is_equal_approx(Vector2(0, 1), Vector2.ONE * 1e-3)
	assert_vector(diagonal).is_equal_approx(Vector2(1, 1).normalized(), Vector2.ONE * 1e-3)
	assert_vector(_frame().nudge).is_equal(Vector2.ZERO)


func _frame() -> MoveInputFrame:
	return MoveInputService.instance.frame


# Every distinct Attract state Move Input's frame showed over [param seconds], in order.
func _attract_states_over(seconds: float) -> Array[MoveInputFrame.Attract]:
	var states: Array[MoveInputFrame.Attract] = []
	for _tick in ceili(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		var state := _frame().attract
		if states.is_empty() or states.back() != state:
			states.append(state)
	return states


func _mouse_motion(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	Input.parse_input_event(event)


func _mouse_button(button: MouseButton, pressed: bool, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = at
	event.global_position = at
	Input.parse_input_event(event)


func _key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
