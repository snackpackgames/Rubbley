class_name CameraRig
extends Node3D
## The player-centred camera (ADR 0007). It sits outside Rubbley's tree with a fixed
## yaw and tilt, so his tumble never reaches it, and moves to the point [CameraFollow]
## picks each frame, at the distance [CameraFraming] picks. The screen's short side
## shows the same extent in portrait and landscape.

## The camera's follow, framing and zoom values.
@export var tuning: CameraTuning
## The body the camera keeps centred: Rubbley.
@export var target: PhysicsBody3D
## The radius of [member target] in metres, which sets the zoom. Fixed until Mass sets
## his size.
@export_range(0.1, 100.0, 0.01, "or_greater") var target_radius_m := 1.0
## The camera, a child of the rig, leaning back by the tuned tilt.
@export var camera: Camera3D
## The background, scrolled against the rig every frame. Optional.
@export var starfield: Starfield

## The Nudge input in screen terms, x right and y up, length up to 1. The input layer
## sets it every frame; zero springs the view back.
var nudge := Vector2.ZERO
## How many metres the screen's short side shows this frame.
var visible_extent_m := 0.0

var _follow: CameraFollow
var _framing: CameraFraming


func _ready() -> void:
	assert(tuning != null, "%s needs a CameraTuning" % name)
	assert(target != null, "%s needs a target" % name)
	assert(camera != null, "%s needs a camera" % name)
	_follow = CameraFollow.new(tuning)
	_framing = CameraFraming.new(tuning)
	# The rig moves every rendered frame from the target's interpolated position, so
	# physics interpolation must not smooth it a second time.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.rotation = Vector3(deg_to_rad(tuning.tilt_deg - 90.0), 0.0, 0.0)
	camera.fov = tuning.fov_deg


func _process(delta: float) -> void:
	visible_extent_m = _framing.step(target_radius_m, _active_zones(), delta)
	var at := target.get_global_transform_interpolated().origin
	# Screen up is away from the camera's lean, along -Z.
	var nudge_on_plane := Vector3(nudge.x, 0.0, -nudge.y)
	global_position = _follow.step(at, nudge_on_plane, visible_extent_m, delta)
	camera.keep_aspect = CameraFraming.keep_aspect_for(get_viewport().get_visible_rect().size)
	camera.position = camera.basis.z * _framing.distance_m(visible_extent_m)
	if starfield != null:
		starfield.scroll(global_position, visible_extent_m)


func _active_zones() -> Array[CameraZoneFraming]:
	var zones: Array[CameraZoneFraming] = []
	for node in get_tree().get_nodes_in_group(CameraZone.GROUP):
		var zone := node as CameraZone
		if zone.overlaps_body(target):
			zones.append(zone.framing)
	return zones
