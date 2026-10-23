extends GdUnitTestSuite
## Checks that the scene runner's simulated input reaches a node's _input.


func test_simulated_screen_touch_reaches_the_scene() -> void:
	var recorder: InputRecorder = auto_free(InputRecorder.new())
	var runner := scene_runner(recorder)

	runner.simulate_screen_touch_pressed(0, Vector2(10, 10))
	@warning_ignore("redundant_await") # gdUnit4 declares it void, but it is a coroutine.
	await runner.await_input_processed()

	var touches := recorder.events.filter(
		func(event: InputEvent) -> bool:
			return event is InputEventScreenTouch,
	)
	assert_array(touches).is_not_empty()


class InputRecorder:
	extends Node

	var events: Array[InputEvent] = []


	func _input(event: InputEvent) -> void:
		events.append(event)
