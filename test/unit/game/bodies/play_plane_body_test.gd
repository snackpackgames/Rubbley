extends SimulationTestSuite
## Bodies on the Play Plane (ADR 0003): they move only in XZ, but turn freely on every axis.

const DEBRIS_SCENE := preload("res://game/bodies/debris/debris.tscn")

var _world: Node3D


## Frees the world a test left behind.
func after_test() -> void:
	if is_instance_valid(_world):
		_world.free()


## A body set tumbling end over end keeps tumbling and never leaves the plane.
func test_a_body_tumbles_on_every_axis_but_stays_on_the_plane() -> void:
	_world = Node3D.new()
	add_child(_world)
	var piece := DEBRIS_SCENE.instantiate() as PlayPlaneBody
	_world.add_child(piece)
	piece.linear_velocity = Vector3(1.0, 0.0, 0.0)
	piece.angular_velocity = Vector3(2.0, 0.0, 2.0)
	await step_seconds(0.5)
	assert_float(absf(piece.angular_velocity.x)).is_greater(0.5)
	assert_float(absf(piece.angular_velocity.z)).is_greater(0.5)
	assert_float(piece.global_basis.y.dot(Vector3.UP)).is_less(0.99)
	assert_float(piece.global_position.y).is_equal_approx(0.0, 1e-4)
