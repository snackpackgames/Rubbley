class_name MoveInputLatch
extends RefCounted
## Latches move edges between physics ticks into one [MoveInputFrame] per tick (ADR 0013).
## A press and release inside one tick shows as pressed on that tick and released on the
## next, so a held Attract lasts at least one tick. Several Repel or Spin presses within
## one tick fire once. After an interruption, input is swallowed until nothing is held.

# Whether the Attract input is down right now.
var _attract_down := false
# Edges seen since the last tick.
var _attract_pressed := false
var _attract_released := false
# Whether the frames report Attract as pressed or held.
var _attracting := false
var _repel_pending := false
var _spin_pending := false
var _swallowing := false


## Records that the Attract input went down.
func press_attract() -> void:
	if _swallowing:
		return
	_attract_down = true
	_attract_pressed = true


## Records that the Attract input came up.
func release_attract() -> void:
	_attract_down = false
	_attract_released = true


## Records a Repel press.
func fire_repel() -> void:
	if not _swallowing:
		_repel_pending = true


## Records a Spin press.
func fire_spin() -> void:
	if not _swallowing:
		_spin_pending = true


## Releases a held Attract on the next tick, drops pending presses and swallows input
## until nothing is held: for focus loss, pause, an open menu or a level unload.
func interrupt() -> void:
	_attract_down = false
	_attract_pressed = false
	_attract_released = _attracting
	_repel_pending = false
	_spin_pending = false
	_swallowing = true


## Returns the frame for this tick, with [param aim] on the Play Plane and
## [param nudge] in screen terms. [param anything_held] says whether any move or Nudge
## input is still down; once it is false, an interruption stops swallowing input.
func tick(aim: Vector3, nudge: Vector2, anything_held: bool) -> MoveInputFrame:
	var frame := MoveInputFrame.new()
	frame.aim = aim
	frame.attract = _attract_edge()
	frame.repel_fired = _repel_pending
	frame.spin_fired = _spin_pending
	_repel_pending = false
	_spin_pending = false
	if _swallowing and not anything_held:
		_swallowing = false
	elif not _swallowing:
		frame.nudge = nudge.limit_length(1.0)
	return frame


func _attract_edge() -> MoveInputFrame.Attract:
	if _attracting:
		if not _attract_released:
			return MoveInputFrame.Attract.HELD
		_attracting = false
		_attract_released = false
		# A press after the release starts a new Attract next tick.
		_attract_pressed = _attract_down
		return MoveInputFrame.Attract.RELEASED
	if _attract_pressed:
		_attracting = true
		_attract_pressed = false
		# A release already seen this tick stays pending, so it shows next tick.
		return MoveInputFrame.Attract.PRESSED
	_attract_released = false
	return MoveInputFrame.Attract.IDLE
