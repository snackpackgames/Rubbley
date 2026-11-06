class_name MoveInputFrame
extends RefCounted
## One physics tick of input, the same for every control scheme (ADR 0013). Gameplay
## and the CameraRig read only this, never a device.

## Where the held Attract is this tick.
enum Attract {
	## Not held.
	IDLE,
	## Started this tick: gameplay resolves the target under [member MoveInputFrame.aim].
	PRESSED,
	## Still held after the tick it was pressed.
	HELD,
	## Let go this tick, or released by an interruption.
	RELEASED,
}

## Where the held Attract is this tick.
var attract := Attract.IDLE
## Whether Repel was pressed since the last tick. Several presses fire once.
var repel_fired := false
## Whether Spin was pressed since the last tick. Several presses fire once.
var spin_fired := false
## The aim, a world point on the Play Plane.
var aim := Vector3.ZERO
## The Nudge in screen terms, x right and y up, length up to 1.
var nudge := Vector2.ZERO
