class_name MoveInputService
extends Node
## Move Input, the autoload every control scheme feeds (ADR 0013). Once per physics tick,
## before gameplay, it latches the scheme's presses into one [MoveInputFrame]. Mouse +
## keyboard bind named [InputMap] actions and aim with the mouse. Touch goes through a
## [TouchRecogniser]: a swipe is Spin, a pinch-in Attract, a pinch-out Repel and a
## two-finger drag Nudge, aimed at the pinch centre with a forgiving hit radius that the
## [TouchReticle] shows. Both aim by a ray from the camera the [CameraRig] registers onto
## the Play Plane, and whichever last aimed owns the aim. Focus loss, pause, an open
## menu, a level unload or a touch cancel interrupt it: every move is released and input
## is swallowed until nothing is held. Callers reach it through [member instance],
## typed, since Godot types a scene autoload's global only as its root's base type.

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
## Shows where a pinch-in aims, and how forgiving that aim is.
@export var reticle: TouchReticle

## This tick's frame. Gameplay and the CameraRig read it and never write to it.
var frame := MoveInputFrame.new()

var _latch := MoveInputLatch.new()
var _touch: TouchRecogniser
var _camera: Camera3D
# The last aim in the viewport: the mouse, or a pinch centre.
var _pointer := Vector2.ZERO
# The hit radius around [member _pointer] in pixels: 0 for the mouse, which is precise.
var _hit_radius_px := 0.0
var _was_paused := false


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	assert(tuning != null, "Move Input needs an InputTuning")
	assert(reticle != null, "Move Input needs a TouchReticle")
	_touch = TouchRecogniser.new(tuning)
	_touch.spin_swiped.connect(_latch.fire_spin)
	_touch.pinched_in.connect(_on_pinched_in)
	_touch.pinched_out.connect(_on_pinched_out)
	_touch.pinch_released.connect(_latch.release_attract)
	_size_touch_unit()
	get_viewport().size_changed.connect(_size_touch_unit)
	# It keeps tracking releases while the game is paused, so input can stop being swallowed.
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = PHYSICS_PRIORITY


func _process(_delta: float) -> void:
	if _touch.is_pinching_in():
		reticle.show_at(_touch.pinch_centre(), _touch_hit_radius_px())
	else:
		reticle.hide()


func _physics_process(_delta: float) -> void:
	var paused := get_tree().paused
	if paused and not _was_paused:
		interrupt()
	_was_paused = paused
	var nudge := Input.get_vector(&"nudge_left", &"nudge_right", &"nudge_down", &"nudge_up")
	nudge += _touch.nudge()
	var aim := _play_plane_point(_pointer)
	frame = _latch.tick(aim, nudge, _anything_held())
	if _hit_radius_px > 0.0:
		var edge := _play_plane_point(_pointer + Vector2(_hit_radius_px, 0.0))
		frame.aim_hit_radius_m = Vector2(edge.x - aim.x, edge.z - aim.z).length()


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _input(event: InputEvent) -> void:
	var mouse := event as InputEventMouse
	if mouse != null:
		_pointer = mouse.position
		_hit_radius_px = 0.0
	# Drags and lifts are read here, before UI can take them, so no finger stays down for
	# good. Only a finger going down over UI is left to it.
	var touch := event as InputEventScreenTouch
	if event is InputEventScreenDrag or (touch != null and not touch.pressed):
		_touch_input(event)


func _unhandled_input(event: InputEvent) -> void:
	# Lifts were already read in _input.
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_touch_input(touch)
		return
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
	_touch.drop()


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


# Feeds a touch or drag to the recogniser, timestamped now. A touch cancel interrupts.
func _touch_input(event: InputEvent) -> void:
	var now_s := Time.get_ticks_usec() / 1_000_000.0
	var drag := event as InputEventScreenDrag
	if drag != null:
		_touch.drag(drag.index, drag.position, now_s)
		return
	var touch := event as InputEventScreenTouch
	if touch.pressed:
		_touch.press(touch.index, touch.position, now_s)
		return
	if touch.canceled:
		interrupt()
	_touch.release(touch.index)


func _on_pinched_in(at: Vector2) -> void:
	_aim_by_touch(at)
	_latch.press_attract()


func _on_pinched_out(at: Vector2) -> void:
	_aim_by_touch(at)
	_latch.fire_repel()


# Makes the pinch centre [param at] the aim, forgiving a finger's imprecision.
func _aim_by_touch(at: Vector2) -> void:
	_pointer = at
	_hit_radius_px = _touch_hit_radius_px()


# How far a pinch centre forgives, in pixels.
func _touch_hit_radius_px() -> float:
	return tuning.touch_hit_radius * _touch.unit_px


# Sizes the recogniser's unit, half the screen's short side, to the viewport.
func _size_touch_unit() -> void:
	var screen := get_viewport().get_visible_rect().size
	_touch.unit_px = minf(screen.x, screen.y) / 2.0


func _anything_held() -> bool:
	if _touch.is_anything_down():
		return true
	for action in ACTIONS:
		if Input.is_action_pressed(action):
			return true
	return false
