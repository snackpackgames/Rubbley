extends Node3D
## The gravity sandbox. Until levels have stage paths, Drift's direction meanders as
## in the controller-aim prototype, and a plain overhead camera follows Rubbley at the
## prototype's framing until the camera rig lands (ADR 0007).

# The prototype's meander: the heading turns at up to this many radians per second...
const MEANDER_TURN_RAD_PER_S := 0.4
# ...swaying back and forth at this angular frequency, in radians per second.
const MEANDER_SWAY_RAD_PER_S := 0.3

## The level's gravity, whose Drift direction meanders.
@export var gravity_system: GravitySystem
## The body the camera follows.
@export var rubbley: Node3D
## The overhead camera. It keeps its height and looks straight down.
@export var camera: Camera3D

var _time_s := 0.0
var _heading_rad := 0.0


func _process(_delta: float) -> void:
	var at := rubbley.get_global_transform_interpolated().origin
	camera.global_position = Vector3(at.x, camera.global_position.y, at.z)


func _physics_process(delta: float) -> void:
	_time_s += delta
	_heading_rad += delta * MEANDER_TURN_RAD_PER_S * sin(_time_s * MEANDER_SWAY_RAD_PER_S)
	gravity_system.drift_direction = Vector3.RIGHT.rotated(Vector3.UP, -_heading_rad)
