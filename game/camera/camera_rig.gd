class_name CameraRig
extends Node3D
## The player-centred camera (ADR 0007). It sits outside Rubbley's tree with a fixed
## yaw and tilt, so his tumble never reaches it, and moves to the point [CameraFollow]
## picks each frame, at the distance [CameraFraming] picks. The screen's short side
## shows the same extent in portrait and landscape. It registers its camera with Move
## Input, which aims the mouse through it, and peeks by the Nudge in Move Input's frame.
## The screen shakes when Rubbley is hurt ([CameraShake]).

## The camera's follow, framing and zoom values.
@export var tuning: CameraTuning
## The body the camera keeps centred: Rubbley.
@export var target: PhysicsBody3D
## The target's Mass, whose radius sets the zoom: the view zooms out as Rubbley grows. Its
## hits shake the screen.
@export var target_mass: RubbleyMass
## The camera, a child of the rig, leaning back by the tuned tilt.
@export var camera: Camera3D
## The background, scrolled against the rig every frame. Optional.
@export var starfield: Starfield

## How many metres the screen's short side shows this frame.
var visible_extent_m := 0.0

var _follow: CameraFollow
var _framing: CameraFraming
var _shake: CameraShake


func _enter_tree() -> void:
	MoveInputService.instance.register_camera(camera)


func _ready() -> void:
	assert(tuning != null, "%s needs a CameraTuning" % name)
	assert(target != null, "%s needs a target" % name)
	assert(target_mass != null, "%s needs the target's RubbleyMass" % name)
	assert(camera != null, "%s needs a camera" % name)
	_follow = CameraFollow.new(tuning)
	_framing = CameraFraming.new(tuning)
	_shake = CameraShake.new(tuning)
	target_mass.hurt.connect(_shake.hit)
	# The rig moves every rendered frame from the target's interpolated position, so
	# physics interpolation must not smooth it a second time.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.rotation = Vector3(deg_to_rad(tuning.tilt_deg - 90.0), 0.0, 0.0)
	camera.fov = tuning.fov_deg


func _process(delta: float) -> void:
	visible_extent_m = _framing.step(target_mass.radius_m(), _active_zones(), delta)
	var rubbley_at := target.get_global_transform_interpolated().origin
	# Screen up is away from the camera's lean, along -Z. Zero springs the view back.
	var nudge := MoveInputService.instance.frame.nudge
	var nudge_on_play_plane := Vector3(nudge.x, 0.0, -nudge.y)
	global_position = _follow.step(rubbley_at, nudge_on_play_plane, visible_extent_m, delta)
	camera.keep_aspect = CameraFraming.keep_aspect_for(get_viewport().get_visible_rect().size)
	camera.position = camera.basis.z * _framing.distance_m(visible_extent_m)
	_shake.advance(delta)
	var shake := _shake.offset() * tuning.shake_max_offset * visible_extent_m
	camera.position += camera.basis.x * shake.x + camera.basis.y * shake.y
	if starfield != null:
		starfield.scroll(global_position, visible_extent_m)


func _exit_tree() -> void:
	# On quit the autoload can leave the tree first.
	if MoveInputService.instance != null:
		MoveInputService.instance.unregister_camera(camera)


func _active_zones() -> Array[CameraZoneFraming]:
	var zones: Array[CameraZoneFraming] = []
	for node in get_tree().get_nodes_in_group(CameraZone.GROUP):
		var zone := node as CameraZone
		if zone.overlaps_body(target):
			zones.append(zone.framing)
	return zones
