extends SimulationTestSuite
## The CameraRig in a world with the shipped Rubbley and Camera Tuning: it keeps him on
## screen at speed, and widens the view inside a Camera Zone (ADR 0007).

const RUBBLEY_SCENE := preload("res://game/bodies/rubbley/rubbley.tscn")
const RIG_SCENE := preload("res://game/camera/camera_rig.tscn")
const ZONE_SCENE := preload("res://game/camera/camera_zone.tscn")
## How far past the max offset a frame may sit, in metres, for float error.
const OFFSET_EPSILON_M := 1e-3

var _world: Node3D
var _rubbley: PlayPlaneBody
var _rig: CameraRig


## Builds a world with Rubbley at the origin and a rig following him.
func before_test() -> void:
	_world = auto_free(Node3D.new())
	add_child(_world)
	_rubbley = RUBBLEY_SCENE.instantiate()
	_world.add_child(_rubbley)
	_rig = RIG_SCENE.instantiate()
	_rig.target = _rubbley
	_world.add_child(_rig)


## Rubbley at his speed cap never gets further from the centre of the screen than the
## max offset allows, on any frame.
func test_rubbley_stays_within_the_max_offset_at_speed() -> void:
	_rubbley.linear_velocity = Vector3(1, 0, -1).normalized() * _rubbley.tuning.speed_cap_m_per_s
	var worst_m := -INF
	for _frame in 120:
		await get_tree().process_frame
		var offset_m := _flat(_rig.global_position).distance_to(_flat(_rubbley.global_position))
		worst_m = maxf(worst_m, offset_m - _rig.tuning.max_offset * _rig.visible_extent_m)
	assert_float(worst_m).is_less_equal(OFFSET_EPSILON_M)


## Rubbley moved into a Camera Zone widens the view to the zone's extent.
func test_a_camera_zone_widens_the_view_while_rubbley_is_inside() -> void:
	var zone: CameraZone = ZONE_SCENE.instantiate()
	zone.position = Vector3(30, 0, 0)
	zone.framing = CameraZoneFraming.new()
	zone.framing.extent_m = _rig.tuning.max_extent_m * 2.0
	_world.add_child(zone)
	await step_seconds(0.5)
	var before_m := _rig.visible_extent_m

	_rubbley.global_position = zone.global_position
	await step_seconds(_rig.tuning.zoom_half_life_s * 10.0)

	assert_float(before_m).is_less(zone.framing.extent_m * 0.5)
	assert_float(_rig.visible_extent_m).is_equal_approx(zone.framing.extent_m, 1.0)


## The camera looks at the rig's focus, so Rubbley at the focus is at the centre of the screen.
func test_the_camera_centres_its_focus() -> void:
	await step_seconds(0.2)
	var screen := _rig.camera.get_viewport().get_visible_rect().size
	var at := _rig.camera.unproject_position(_rig.global_position)
	assert_vector(at).is_equal_approx(screen * 0.5, Vector2.ONE)


func _flat(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)
