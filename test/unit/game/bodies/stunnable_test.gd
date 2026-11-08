extends SimulationTestSuite
## A Stunnable body (ADR 0006): a Repel Pulse stuns it for a duration, and a longer stun
## while stunned extends it but a shorter one never cuts it short.

const DEBRIS_SCENE := preload("res://game/bodies/debris/debris.tscn")

var _stunnable: Stunnable


## Builds debris that can be stunned.
func before_test() -> void:
	var debris := DEBRIS_SCENE.instantiate() as RigidBody3D
	auto_free(debris)
	add_child(debris)
	_stunnable = Stunnable.new()
	_stunnable.body = debris
	debris.add_child(_stunnable)


## Nothing is stunned until something stuns it.
func test_starts_unstunned() -> void:
	assert_bool(_stunnable.is_stunned()).is_false()


## A stun lasts its duration, then wears off.
func test_a_stun_lasts_its_duration() -> void:
	_stunnable.stun(0.5)
	await step_seconds(0.4)
	var stunned_before := _stunnable.is_stunned()
	await step_seconds(0.2)
	assert_bool(stunned_before).is_true()
	assert_bool(_stunnable.is_stunned()).is_false()


## A shorter stun while stunned leaves the longer one running.
func test_a_shorter_stun_does_not_cut_one_short() -> void:
	_stunnable.stun(1.0)
	await step_seconds(0.2)
	_stunnable.stun(0.2)
	await step_seconds(0.5)
	assert_bool(_stunnable.is_stunned()).is_true()


## A longer stun while stunned runs its full length from now.
func test_a_longer_stun_extends_it() -> void:
	_stunnable.stun(0.3)
	await step_seconds(0.2)
	_stunnable.stun(0.5)
	await step_seconds(0.4)
	assert_bool(_stunnable.is_stunned()).is_true()


## Stunning emits [signal Stunnable.stunned] with the duration, for whatever reacts.
func test_stunning_is_announced() -> void:
	var durations: Array[float] = []
	_stunnable.stunned.connect(
		func(duration_s: float) -> void:
			durations.append(duration_s),
	)
	_stunnable.stun(0.5)
	assert_array(durations).contains_exactly([0.5])
