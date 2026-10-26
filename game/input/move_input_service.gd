class_name MoveInputService
extends Node
## Move Input, the autoload every control scheme feeds (ADR 0013). Once per physics tick,
## before gameplay, it latches the scheme's presses into one [MoveInputFrame]. Mouse +
## keyboard bind named [InputMap] actions and aim with the mouse, by a ray from the
## camera the [CameraRig] registers onto the Play Plane. Focus loss, pause, an open menu or a
## level unload interrupt it: every move is released and input is swallowed until
## nothing is held. Callers reach it through [member instance], typed, since Godot
## types a scene autoload's global only as its root's base type.

## Runs before gameplay's physics tick, so gameplay reads this tick's frame.
const PHYSICS_PRIORITY := -100
## Every action Move Input reads, all of which must be let go after an interruption.
const ACTIONS: Array[StringName] = [
	&"attract",
	&"repel",
	&"spin",
	&"nudge_up",
	&"nudge_down",
	&"nudge_left",
	&"nudge_right",
]
# The Play Plane, y = 0, that the mouse aims onto.
const _PLAY_PLANE := Plane(Vector3.UP, 0.0)

## The running Move Input, set while the autoload is in the tree.
static var instance: MoveInputService

## The thresholds moves are recognised by.
@export var tuning: InputTuning

## This tick's frame. Gameplay and the CameraRig read it and never write to it.
var frame := MoveInputFrame.new()

var _latch := MoveInputLatch.new()
var _camera: Camera3D
# The mouse's last position in the viewport.
var _pointer := Vector2.ZERO
var _was_paused := false


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	assert(tuning != null, "Move Input needs an InputTuning")
	# It keeps tracking releases while the game is paused, so input can stop being swallowed.
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = PHYSICS_PRIORITY


func _physics_process(_delta: float) -> void:
	var paused := get_tree().paused
	if paused and not _was_paused:
		interrupt()
	_was_paused = paused
	var nudge := Input.get_vector(&"nudge_left", &"nudge_right", &"nudge_down", &"nudge_up")
	frame = _latch.tick(_play_plane_point(_pointer), nudge, _anything_held())


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _input(event: InputEvent) -> void:
	var mouse := event as InputEventMouse
	if mouse != null:
		_pointer = mouse.position


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"attract"):
		_latch.press_attract()
	elif event.is_action_released(&"attract"):
		_latch.release_attract()
	if event.is_action_pressed(&"repel"):
		_latch.fire_repel()
	if event.is_action_pressed(&"spin"):
		_latch.fire_spin()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		interrupt()


## Releases every move and swallows input until nothing is held. Menus call it when they
## open, and Main when it unloads a level.
func interrupt() -> void:
	_latch.interrupt()


## Makes [param camera] the one the mouse aims through. The CameraRig calls it on
## entering the tree.
func register_camera(camera: Camera3D) -> void:
	_camera = camera


## Stops aiming through [param camera], if it is the registered one.
func unregister_camera(camera: Camera3D) -> void:
	if _camera == camera:
		_camera = null


# The point on the Play Plane under a point in the registered camera's viewport, or the
# last aim if there is no camera or its ray misses the plane.
func _play_plane_point(screen_point: Vector2) -> Vector3:
	if _camera == null:
		return frame.aim
	var origin := _camera.project_ray_origin(screen_point)
	var direction := _camera.project_ray_normal(screen_point)
	var hit: Variant = _PLAY_PLANE.intersects_ray(origin, direction)
	if hit is Vector3:
		return hit
	return frame.aim


func _anything_held() -> bool:
	for action in ACTIONS:
		if Input.is_action_pressed(action):
			return true
	return false
