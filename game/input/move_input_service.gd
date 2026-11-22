class_name MoveInputService
extends Node
## Move Input, the autoload every control scheme feeds (ADR 0013). Once per physics tick,
## before gameplay, it latches the scheme's presses into one [MoveInputFrame]. Mouse +
## keyboard bind named [InputMap] actions and aim with the mouse. Touch goes through a
## [TouchRecogniser]: a swipe is Spin, a pinch-in Attract, a pinch-out Repel and a
## two-finger drag Nudge, aimed at the pinch centre with a forgiving hit radius that the
## [TouchReticle] shows. Both aim by a ray from the camera the [CameraRig] registers onto
## the Play Plane. A controller Attracts and Repels with the triggers, with hysteresis
## ([TriggerPress]), Spins with any face button, Nudges with the right stick and aims with
## a [ControllerAim] cursor around the Rubbley that registers himself, which the
## [AimCursor] shows. Every scheme is live at once, and the one that last moved the aim
## owns it. Focus loss, pause, an open menu, a level unload, a touch cancel or a
## controller disconnect interrupt it: every move is released and input is swallowed
## until nothing is held. Callers reach it through [member instance], typed, since Godot
## types a scene autoload's global only as its root's base type.

## A control scheme, as the owner of the aim.
enum Scheme {
	## The mouse aims.
	MOUSE_KEYBOARD,
	## A pinch centre aims.
	TOUCH,
	## The left stick's cursor aims.
	CONTROLLER,
}

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
	&"cycle_target",
]
# The Play Plane, y = 0, that the mouse aims onto.
const _PLAY_PLANE := Plane(Vector3.UP, 0.0)

## The running Move Input, set while the autoload is in the tree.
static var instance: MoveInputService

## The thresholds moves are recognised by.
@export var tuning: InputTuning
## Shows where a pinch-in aims, and how forgiving that aim is.
@export var reticle: TouchReticle
## Shows where the controller aims, while it owns the aim.
@export var aim_cursor: AimCursor

## This tick's frame. Gameplay and the CameraRig read it and never write to it.
var frame := MoveInputFrame.new()

var _latch := MoveInputLatch.new()
var _touch: TouchRecogniser
var _controller: ControllerAim
var _attract_trigger: TriggerPress
var _repel_trigger: TriggerPress
var _camera: Camera3D
# The Rubbley a controller aims around.
var _rubbley: Node3D
var _aim_scheme := Scheme.MOUSE_KEYBOARD
# The last mouse or touch aim in the viewport: the mouse, or a pinch centre.
var _pointer := Vector2.ZERO
# Half the screen's short side in pixels, the unit screen lengths in tuning are shares of.
var _unit_px := 1.0
var _was_paused := false
# Physics time in seconds, which the controller's release grace runs on.
var _physics_s := 0.0


static func _flat(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	assert(tuning != null, "Move Input needs an InputTuning")
	assert(reticle != null, "Move Input needs a TouchReticle")
	assert(aim_cursor != null, "Move Input needs an AimCursor")
	_controller = ControllerAim.new(tuning)
	_attract_trigger = TriggerPress.new(tuning)
	_repel_trigger = TriggerPress.new(tuning)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_touch = TouchRecogniser.new(tuning)
	_touch.spin_swiped.connect(_latch.fire_spin)
	_touch.pinched_in.connect(_on_pinched_in)
	_touch.pinched_out.connect(_on_pinched_out)
	_touch.pinch_released.connect(_latch.release_attract)
	_size_unit()
	get_viewport().size_changed.connect(_size_unit)
	# It keeps tracking releases while the game is paused, so input can stop being swallowed.
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = PHYSICS_PRIORITY


func _process(_delta: float) -> void:
	if _touch.is_pinching_in():
		reticle.show_at(_touch.pinch_centre(), _touch_hit_radius_px())
	else:
		reticle.hide()
	if _aim_scheme == Scheme.CONTROLLER and _camera != null:
		aim_cursor.show_at(_camera.unproject_position(frame.aim), _controller.is_on_rubbley())
	else:
		aim_cursor.hide()


func _physics_process(delta: float) -> void:
	_physics_s += delta
	var paused := get_tree().paused
	if paused and not _was_paused:
		interrupt()
	_was_paused = paused
	var nudge := Input.get_vector(
		&"nudge_left",
		&"nudge_right",
		&"nudge_down",
		&"nudge_up",
		tuning.nudge_deadzone,
	)
	nudge += _touch.nudge()
	_aim_controller()
	frame = _latch.tick(_aim(), nudge, _anything_held())
	if _aim_scheme == Scheme.TOUCH:
		frame.aim_hit_radius_m = _metres_across(_pointer, _touch_hit_radius_px())


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _input(event: InputEvent) -> void:
	var mouse := event as InputEventMouse
	if mouse != null:
		_pointer = mouse.position
		_aim_scheme = Scheme.MOUSE_KEYBOARD
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
	# Triggers press and release with hysteresis, not at the action's deadzone.
	var motion := event as InputEventJoypadMotion
	if motion != null:
		_trigger_input(motion)
		return
	if event.is_action_pressed(&"cycle_target"):
		_controller.cycle()
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
	_attract_trigger.reset()
	_repel_trigger.reset()


## Which scheme last moved the aim, and so owns the aim, the button prompts and whether
## the reticle or the aim cursor shows.
func aim_scheme() -> Scheme:
	return _aim_scheme


## Makes [param camera] the one the mouse aims through. The CameraRig calls it on
## entering the tree.
func register_camera(camera: Camera3D) -> void:
	_camera = camera


## Stops aiming through [param camera], if it is the registered one.
func unregister_camera(camera: Camera3D) -> void:
	if _camera == camera:
		_camera = null


## Makes [param rubbley] the one a controller aims around, and at when its stick is at
## rest. Rubbley calls it on entering the tree.
func register_rubbley(rubbley: Node3D) -> void:
	_rubbley = rubbley


## Stops aiming around [param rubbley], if he is the registered one.
func unregister_rubbley(rubbley: Node3D) -> void:
	if _rubbley == rubbley:
		_rubbley = null


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
	_aim_scheme = Scheme.TOUCH


# How far a pinch centre forgives, in pixels.
func _touch_hit_radius_px() -> float:
	return tuning.touch_hit_radius * _unit_px


# Sizes the unit, half the screen's short side, to the viewport.
func _size_unit() -> void:
	var screen := get_viewport().get_visible_rect().size
	_unit_px = minf(screen.x, screen.y) / 2.0
	_touch.unit_px = _unit_px


# This tick's aim on the Play Plane, from whichever scheme owns it.
func _aim() -> Vector3:
	if _aim_scheme == Scheme.CONTROLLER:
		var point := _controller.point()
		return Vector3(point.x, 0.0, point.y)
	return _play_plane_point(_pointer)


# Moves the controller's cursor with the left stick, and gives the controller the aim
# when the stick tilts.
func _aim_controller() -> void:
	if _rubbley == null or _camera == null:
		return
	var stick := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down", 0.0)
	var rubbley_at := _rubbley.global_position
	var unit_m := _metres_across(_camera.unproject_position(rubbley_at), _unit_px)
	_controller.update(stick, _flat(rubbley_at), unit_m, _aim_bodies(), _physics_s)
	if _controller.is_tilted():
		_aim_scheme = Scheme.CONTROLLER


# Every glowing body the controller's cursor can pick.
func _aim_bodies() -> Array[ControllerAim.Body]:
	var bodies: Array[ControllerAim.Body] = []
	for targetable in Targetable.all_in(get_tree()):
		var at := _flat(targetable.body_position())
		var id := targetable.get_instance_id()
		bodies.append(ControllerAim.Body.new(id, at, targetable.radius_m()))
	return bodies


# How many metres on the Play Plane [param length_px] spans, rightward from
# [param screen_point].
func _metres_across(screen_point: Vector2, length_px: float) -> float:
	var from := _play_plane_point(screen_point)
	var to := _play_plane_point(screen_point + Vector2(length_px, 0.0))
	return _flat(to).distance_to(_flat(from))


# Presses or releases Attract and fires Repel as a trigger crosses its points.
func _trigger_input(motion: InputEventJoypadMotion) -> void:
	if motion.is_action(&"attract") and _attract_trigger.update(motion.axis_value):
		if _attract_trigger.is_down():
			_latch.press_attract()
		else:
			_latch.release_attract()
	if motion.is_action(&"repel") and _repel_trigger.update(motion.axis_value):
		if _repel_trigger.is_down():
			_latch.fire_repel()


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if not connected:
		interrupt()


func _anything_held() -> bool:
	if _touch.is_anything_down():
		return true
	for action in ACTIONS:
		if Input.is_action_pressed(action):
			return true
	return false
