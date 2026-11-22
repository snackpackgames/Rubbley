extends SimulationTestSuite
## Controller end to end (ADRs 0012, 0013): real joypad InputEvents through
## [method Input.parse_input_event] reach Move Input's frame. The left stick moves the
## aim cursor and the left trigger places a Gravity Well under it; with the stick at rest
## the left trigger Attracts on self. The triggers have hysteresis, the right trigger
## Repels, a face button Spins and the right stick Nudges.

const RUBBLEY_SCENE := preload("res://game/bodies/rubbley/rubbley.tscn")
const RIG_SCENE := preload("res://game/camera/camera_rig.tscn")
const HUD_SCENE := preload("res://game/ui/hud.tscn")
## Long enough for Move Input to read a batch of events and latch it.
const SETTLE_S := 0.1
## Longer than the aim's release grace, so a stick at rest aims at Rubbley.
const PAST_GRACE_S := 0.3
## Every axis a test may move, all zeroed after each test.
const AXES: Array[JoyAxis] = [
	JOY_AXIS_LEFT_X,
	JOY_AXIS_LEFT_Y,
	JOY_AXIS_RIGHT_X,
	JOY_AXIS_RIGHT_Y,
	JOY_AXIS_TRIGGER_LEFT,
	JOY_AXIS_TRIGGER_RIGHT,
]

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


## Centres every axis and lets go of every button a test used, so Move Input starts the
## next test clean.
func after_test() -> void:
	for axis in AXES:
		_axis(axis, 0.0)
	_button(JOY_BUTTON_A, false)
	await step_seconds(SETTLE_S)


## The tilted left stick moves the aim cursor out from Rubbley, the controller takes the
## aim and its cursor shows, and the left trigger places a Gravity Well under it.
func test_the_stick_aims_and_the_left_trigger_places_a_well() -> void:
	_axis(JOY_AXIS_LEFT_X, 0.6)
	await step_seconds(SETTLE_S)
	var aim := _frame().aim
	var scheme := MoveInputService.instance.aim_scheme()
	var cursor_shown := MoveInputService.instance.aim_cursor.visible
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await step_seconds(SETTLE_S)

	assert_int(scheme).is_equal(MoveInputService.Scheme.CONTROLLER)
	assert_bool(cursor_shown).is_true()
	assert_float(aim.x - _rubbley.global_position.x).is_greater(1.0)
	assert_float(absf(aim.z - _rubbley.global_position.z)).is_less(0.1)
	var wells := _moves().get_children().filter(
		func(node: Node) -> bool:
			return node is GravityWell,
	)
	assert_int(wells.size()).is_equal(1)


## A trigger pulled while the mouse owns the aim and the stick has never tilted takes
## the aim for the controller, and Attracts on self.
func test_a_trigger_with_the_stick_at_rest_attracts_on_self() -> void:
	var mouse := InputEventMouseMotion.new()
	mouse.position = Vector2(5.0, 5.0)
	Input.parse_input_event(mouse)
	await step_seconds(SETTLE_S)
	var scheme_before := MoveInputService.instance.aim_scheme()
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await step_seconds(SETTLE_S)
	var attracting := _moves().is_attracting_self()
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await step_seconds(SETTLE_S)

	assert_int(scheme_before).is_equal(MoveInputService.Scheme.MOUSE_KEYBOARD)
	assert_int(MoveInputService.instance.aim_scheme()).is_equal(MoveInputService.Scheme.CONTROLLER)
	assert_bool(attracting).is_true()


## The HUD's prompts follow the scheme that owns the aim: the mouse's, then the
## controller's once a face button is pressed.
func test_the_prompts_follow_the_aims_owner() -> void:
	var hud: Hud = HUD_SCENE.instantiate()
	_world.add_child(hud)
	hud.watch(_rubbley.get_node("Mass") as RubbleyMass)
	var mouse := InputEventMouseMotion.new()
	mouse.position = Vector2(5.0, 5.0)
	Input.parse_input_event(mouse)
	await step_seconds(SETTLE_S)
	var mouse_prompts := hud.prompt_label.text
	_button(JOY_BUTTON_A, true)
	await step_seconds(SETTLE_S)

	assert_str(mouse_prompts).is_equal(Hud.PROMPTS[Hud.SCHEME.MOUSE_KEYBOARD])
	assert_str(hud.prompt_label.text).is_equal(Hud.PROMPTS[Hud.SCHEME.CONTROLLER])


## After an interruption, a trigger resting below its release point doesn't keep input
## swallowed, so the right stick Nudges.
func test_a_trigger_resting_low_does_not_swallow_input() -> void:
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.3)
	await step_seconds(SETTLE_S)
	MoveInputService.instance.interrupt()
	_axis(JOY_AXIS_RIGHT_Y, -1.0)
	await step_seconds(SETTLE_S)
	assert_float(_frame().nudge.y).is_greater(0.9)


## With the stick back at rest past the release grace, the left trigger Attracts on self
## while held.
func test_a_stick_at_rest_attracts_on_self() -> void:
	_axis(JOY_AXIS_LEFT_X, 0.6)
	await step_seconds(SETTLE_S)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	await step_seconds(PAST_GRACE_S)
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await step_seconds(SETTLE_S)
	var attracting := _moves().is_attracting_self()
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await step_seconds(SETTLE_S)

	assert_bool(attracting).is_true()
	assert_bool(_moves().is_attracting_self()).is_false()


## A pulled trigger eased back between its points stays held, and lets go below the
## release point.
func test_the_left_trigger_has_hysteresis() -> void:
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.8)
	await step_seconds(SETTLE_S)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.5)
	var eased := await _attract_states_over(SETTLE_S)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.2)
	var released := await _attract_states_over(SETTLE_S)

	assert_array(eased).contains_exactly([MoveInputFrame.Attract.HELD])
	assert_array(released).contains([MoveInputFrame.Attract.RELEASED])


## The right trigger fires one Repel however long it is held.
func test_the_right_trigger_fires_one_repel() -> void:
	var counted := [0]
	var count := func() -> void:
		counted[0] += int(_frame().repel_fired)
	get_tree().physics_frame.connect(count)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await step_seconds(SETTLE_S * 3.0)
	get_tree().physics_frame.disconnect(count)
	assert_int(counted[0]).is_equal(1)


## A face button fires one Spin.
func test_a_face_button_fires_spin() -> void:
	var counted := [0]
	var count := func() -> void:
		counted[0] += int(_frame().spin_fired)
	get_tree().physics_frame.connect(count)
	_button(JOY_BUTTON_A, true)
	await step_seconds(SETTLE_S)
	get_tree().physics_frame.disconnect(count)
	assert_int(counted[0]).is_equal(1)


## The right stick pushed up Nudges up, and Nudge springs back when it is let go.
func test_the_right_stick_nudges() -> void:
	_axis(JOY_AXIS_RIGHT_Y, -1.0)
	await step_seconds(SETTLE_S)
	var nudge := _frame().nudge
	_axis(JOY_AXIS_RIGHT_Y, 0.0)
	await step_seconds(SETTLE_S)

	assert_float(nudge.y).is_greater(0.9)
	assert_float(absf(nudge.x)).is_less(1e-3)
	assert_vector(_frame().nudge).is_equal(Vector2.ZERO)


## Past its deadzone, the right stick Nudges by its raw travel, as in the prototype.
func test_a_small_push_nudges_by_its_raw_travel() -> void:
	_axis(JOY_AXIS_RIGHT_X, 0.3)
	await step_seconds(SETTLE_S)
	assert_float(_frame().nudge.x).is_equal_approx(0.3, 0.01)


## Leaving the controller idle past the cursor's hold and fade hides the cursor without
## giving up controller aim ownership, and using a skill or stick brings it right back.
func test_the_aim_cursor_fades_out_when_idle_and_returns_on_input() -> void:
	var cursor := MoveInputService.instance.aim_cursor
	_axis(JOY_AXIS_LEFT_X, 0.6)
	await step_seconds(SETTLE_S)
	var visible_while_tilted := cursor.visible
	var alpha_while_tilted := cursor.modulate.a
	_axis(JOY_AXIS_LEFT_X, 0.0)
	var fade_total_s := cursor.tuning.idle_hold_s + cursor.tuning.fade_out_s + 0.1
	await step_seconds(fade_total_s)
	var visible_when_idle := cursor.visible
	var scheme_when_idle := MoveInputService.instance.aim_scheme()
	_button(JOY_BUTTON_A, true)
	await step_seconds(SETTLE_S)
	var visible_after_input := cursor.visible
	var alpha_after_input := cursor.modulate.a

	assert_bool(visible_while_tilted).is_true()
	assert_float(alpha_while_tilted).is_equal_approx(1.0, 1e-3)
	assert_bool(visible_when_idle).is_false()
	assert_int(scheme_when_idle).is_equal(MoveInputService.Scheme.CONTROLLER)
	assert_bool(visible_after_input).is_true()
	assert_float(alpha_after_input).is_equal_approx(1.0, 1e-3)


func _frame() -> MoveInputFrame:
	return MoveInputService.instance.frame


func _moves() -> RubbleyMoves:
	return _rubbley.get_node("Moves") as RubbleyMoves


# Every distinct Attract state Move Input's frame showed over [param seconds], in order.
func _attract_states_over(seconds: float) -> Array[MoveInputFrame.Attract]:
	var states: Array[MoveInputFrame.Attract] = []
	for _tick in ceili(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		var state := _frame().attract
		if states.is_empty() or states.back() != state:
			states.append(state)
	return states


func _axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func _button(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
