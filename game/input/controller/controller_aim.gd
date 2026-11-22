class_name ControllerAim
extends RefCounted
## The controller's aim cursor (ADR 0012), worked out on the Play Plane once per tick.
## Uses no Node and no [Input], so it runs headless.
## [br][br]
## The cursor sits at Rubbley + stick × range, the range being a share of the aim unit:
## half the screen's short side, in metres. A stick at rest aims at Rubbley. A glowing
## body whose edge is within the snap radius of the cursor is picked, the nearest edge
## first. At full tilt with nothing to snap to, a narrow cone picks the best body in the
## stick's direction, out to the reach. [method cycle] steps through the bodies
## selectable right now, best first. A picked body stays picked while its edge stays
## within 1.5× the snap radius of the cursor, or inside the cone plus the hysteresis
## margin. For a short grace after the stick returns to rest, the last aim is kept, so
## flicking back while pressing a trigger doesn't fire on Rubbley.

# How far past the snap radius a picked body stays picked, as a multiple of it.
const _SNAP_KEEP := 1.5

var _tuning: InputTuning
# Whether the stick is out of its deadzone this tick.
var _tilted := false
# Whether the aim is on Rubbley: the stick at rest, past the release grace.
var _on_rubbley := true
# When the stick was last out of its deadzone, for the release grace.
var _tilted_s := -INF
# The cursor's offset from Rubbley, kept through the release grace.
var _offset := Vector2.ZERO
# The picked body's id, or -1.
var _picked := -1
# The ids of the bodies selectable now, best first, which [method cycle] steps through.
var _selectable: Array[int] = []
# This tick's bodies, by id.
var _bodies: Dictionary[int, Body] = { }
var _point := Vector2.ZERO


func _init(tuning: InputTuning) -> void:
	_tuning = tuning


## Aims for this tick with the left stick at [param stick], in screen terms with y down
## and length up to 1, from Rubbley at [param rubbley_at] on the Play Plane.
## [param unit_m] is half the screen's short side in metres, [param bodies] the glowing
## bodies that can be picked, and [param now_s] the time in seconds.
func update(
	stick: Vector2,
	rubbley_at: Vector2,
	unit_m: float,
	bodies: Array[Body],
	now_s: float,
) -> void:
	_bodies.clear()
	for body in bodies:
		_bodies[body.id] = body
	if not _bodies.has(_picked):
		_picked = -1
	var travel := minf(stick.length(), 1.0)
	_tilted = travel >= _tuning.stick_deadzone
	if not _tilted:
		_rest(rubbley_at, now_s)
		return
	_tilted_s = now_s
	_on_rubbley = false
	var direction := stick.normalized()
	var tilt := clampf(inverse_lerp(_tuning.stick_deadzone, _tuning.full_tilt, travel), 0.0, 1.0)
	var range_m := _tuning.aim_range * unit_m
	_offset = direction * tilt * range_m
	var cursor := rubbley_at + _offset
	# Both picks read the last pick, to keep it, so it changes only once they're done.
	var pick := _snap_pick(cursor, _tuning.aim_snap_radius * unit_m)
	if pick < 0 and travel >= _tuning.full_tilt:
		pick = _reach_pick(direction, rubbley_at, range_m * _tuning.reach_range_multiple)
	_picked = pick
	_point = _bodies[_picked].at if _picked >= 0 else cursor


## Picks the next selectable body, best first, wrapping round.
func cycle() -> void:
	if _selectable.is_empty():
		return
	var index := _selectable.find(_picked)
	_picked = _selectable[(index + 1) % _selectable.size()]
	_point = _bodies[_picked].at


## The aim on the Play Plane: Rubbley, the cursor, or the picked body's centre.
func point() -> Vector2:
	return _point


## The picked body's id, or -1 when none is picked.
func picked() -> int:
	return _picked


## Whether the stick is out of its deadzone this tick, moving the aim.
func is_tilted() -> bool:
	return _tilted


## Whether the aim is on Rubbley: the stick at rest, past the release grace.
func is_on_rubbley() -> bool:
	return _on_rubbley


# Keeps the last aim through the release grace, then aims at Rubbley.
func _rest(rubbley_at: Vector2, now_s: float) -> void:
	if now_s - _tilted_s < _tuning.aim_release_grace_s:
		_point = _bodies[_picked].at if _picked >= 0 else rubbley_at + _offset
		return
	_on_rubbley = true
	_picked = -1
	_selectable.clear()
	_point = rubbley_at


# The body to pick with the cursor at [param cursor]: the picked one while it stays
# near, else the nearest edge within [param snap_m], else -1. Sets the selectable bodies.
func _snap_pick(cursor: Vector2, snap_m: float) -> int:
	var scored: Array[Array] = []
	for body: Body in _bodies.values():
		var gap := body.gap_to(cursor)
		if gap <= snap_m:
			scored.append([gap, body.id])
	_selectable = _best_first(scored)
	if _picked >= 0 and _bodies[_picked].gap_to(cursor) <= snap_m * _SNAP_KEEP:
		return _picked
	return _selectable[0] if not _selectable.is_empty() else -1


# The body the full-tilt cone picks in [param direction] from [param from], out to
# [param reach_m]: the picked one while it stays inside the cone plus the hysteresis
# margin, else the best scored, else -1. Sets the selectable bodies.
func _reach_pick(direction: Vector2, from: Vector2, reach_m: float) -> int:
	var half_deg := _tuning.reach_cone_deg / 2.0
	var scored: Array[Array] = []
	for body: Body in _bodies.values():
		var off_deg := body.degrees_off(direction, from)
		var gap := body.gap_to(from)
		if gap <= reach_m and off_deg <= half_deg:
			var score := off_deg + _tuning.reach_distance_bias_deg * gap / reach_m
			scored.append([score, body.id])
	_selectable = _best_first(scored)
	if _picked >= 0:
		var kept := _bodies[_picked]
		var keep_deg := half_deg + _tuning.reach_hysteresis_deg
		if kept.gap_to(from) <= reach_m and kept.degrees_off(direction, from) <= keep_deg:
			return _picked
	return _selectable[0] if not _selectable.is_empty() else -1


# The ids in [param scored], each [score, id], lowest score first.
func _best_first(scored: Array[Array]) -> Array[int]:
	scored.sort_custom(
		func(a: Array, b: Array) -> bool:
			return a[0] < b[0],
	)
	var ids: Array[int] = []
	for entry in scored:
		ids.append(entry[1])
	return ids


## A glowing body the cursor can pick, on the Play Plane.
class Body:
	extends RefCounted

	## Identifies the body from tick to tick, so a pick can stay on it.
	var id: int
	## Its centre on the Play Plane.
	var at: Vector2
	## Its radius in metres. Picks measure to its edge.
	var radius_m: float


	func _init(body_id: int, centre: Vector2, radius: float) -> void:
		id = body_id
		at = centre
		radius_m = radius


	## How far [param point] is outside the body's edge, negative inside it.
	func gap_to(point: Vector2) -> float:
		return point.distance_to(at) - radius_m


	## Degrees between [param direction] from [param from] and the nearest edge of the
	## body, 0 when the direction points into it.
	func degrees_off(direction: Vector2, from: Vector2) -> float:
		var to := at - from
		var distance := maxf(to.length(), 0.001)
		var off := rad_to_deg(absf(direction.angle_to(to)))
		var edge := rad_to_deg(asin(minf(1.0, radius_m / distance)))
		return maxf(0.0, off - edge)
