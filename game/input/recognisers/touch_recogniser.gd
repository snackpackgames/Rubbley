class_name TouchRecogniser
extends RefCounted
## Recognises the touch moves from timestamped touch events (ADRs 0012, 0013). Uses no
## Node and no [Input], so it runs headless.
## [br][br]
## Fingers are allocated as ADR 0013 lays out. A finger going down is a swipe candidate,
## and swipes a Spin once it moves far and fast enough. A second finger down within the
## second-finger window of a swipe candidate pairs with it instead, while no pair is
## active. The pair is classified once, early, and locked until lift: if the gap
## between the fingers changes first it is a pinch, and if their midpoint moves first it
## is a Nudge. A pinch-in starts Attract and a pinch-out fires Repel, both at the moment
## of classification, aimed at the pinch centre. When either paired finger lifts, the
## pair ends (and with it a pinch-in's Attract, or the Nudge), and the other finger is
## ignored until it lifts too. Any finger down while a pair is active is a swipe
## candidate only, so a third finger can Spin. A finger that crosses no threshold stays
## unclassified, with no timeout.

## A one-finger swipe crossed the swipe thresholds.
signal spin_swiped
## A pair classified as a pinch-in, with its centre [param at] in pixels: Attract starts.
signal pinched_in(at: Vector2)
## A pair classified as a pinch-out, with its centre [param at] in pixels: Repel fires.
signal pinched_out(at: Vector2)
## A finger of a pinch-in lifted: Attract ends.
signal pinch_released

## Pixels in half the screen's short side, the unit tuning lengths are fractions of.
## Move Input keeps it in step with the viewport's size.
var unit_px := 1.0

var _tuning: InputTuning
# Each finger down, by touch index.
var _fingers: Dictionary[int, Finger] = { }
# The two paired fingers, or null when no pair is active.
var _pair: Pair


func _init(tuning: InputTuning) -> void:
	_tuning = tuning


## Records finger [param index] going down at [param position] at [param time_s].
func press(index: int, position: Vector2, time_s: float) -> void:
	var finger := Finger.new(position, time_s)
	var partner := -1 if _pair != null else _partner_for(time_s)
	_fingers[index] = finger
	if partner >= 0:
		_pair = Pair.new(partner, index, _fingers[partner].position, position)
		_fingers[partner].role = Finger.Role.PAIRED
		finger.role = Finger.Role.PAIRED


## Records finger [param index] moving to [param position] at [param time_s].
func drag(index: int, position: Vector2, time_s: float) -> void:
	var finger: Finger = _fingers.get(index)
	if finger == null:
		return
	var elapsed := time_s - finger.moved_s
	var travel := finger.position.distance_to(position) / unit_px
	finger.position = position
	finger.moved_s = time_s
	# Fingers move in bursts: a slow stretch restarts the swipe from where it is now.
	if elapsed > 0.0 and travel / elapsed < _tuning.swipe_speed_per_s:
		finger.swipe_from = position
	match finger.role:
		Finger.Role.SWIPE_CANDIDATE:
			if finger.swipe_from.distance_to(position) / unit_px >= _tuning.swipe_distance:
				finger.role = Finger.Role.IGNORED
				spin_swiped.emit()
		Finger.Role.PAIRED:
			if _pair.kind == Pair.Kind.UNCLASSIFIED:
				_classify()


## Records finger [param index] lifting. Ends its pair, if it was in one.
func release(index: int) -> void:
	var finger: Finger = _fingers.get(index)
	if finger == null:
		return
	_fingers.erase(index)
	if finger.role != Finger.Role.PAIRED:
		return
	var other := _pair.second if _pair.first == index else _pair.first
	var other_finger: Finger = _fingers.get(other)
	if other_finger != null:
		other_finger.role = Finger.Role.IGNORED
	var was_attracting := _pair.kind == Pair.Kind.PINCH_IN
	_pair = null
	if was_attracting:
		pinch_released.emit()


## Drops every gesture, emitting nothing, and ignores every finger down until it lifts:
## for a touch cancel or any other interruption. Move Input releases the moves itself.
func drop() -> void:
	_pair = null
	for finger: Finger in _fingers.values():
		finger.role = Finger.Role.IGNORED


## Whether any finger is down, ignored or not.
func is_anything_down() -> bool:
	return not _fingers.is_empty()


## The Nudge from a two-finger drag in screen terms, x right and y up, length up to 1;
## zero when no pair is Nudging.
func nudge() -> Vector2:
	if _pair == null or _pair.kind != Pair.Kind.NUDGE:
		return Vector2.ZERO
	var moved := (_midpoint() - _pair.start_midpoint) / unit_px / _tuning.nudge_full_drag
	return Vector2(moved.x, -moved.y).limit_length(1.0)


## Whether a pinch-in is holding Attract: from its classification until a finger lifts.
func is_pinching_in() -> bool:
	return _pair != null and _pair.kind == Pair.Kind.PINCH_IN


## The pinch-in's centre in pixels, locked at classification; zero when
## [method is_pinching_in] is false.
func pinch_centre() -> Vector2:
	return _pair.aim if is_pinching_in() else Vector2.ZERO


# The most recent swipe candidate still inside the second-finger window at
# [param time_s], or -1 if there is none.
func _partner_for(time_s: float) -> int:
	var partner := -1
	var latest := -INF
	for index: int in _fingers:
		var finger := _fingers[index]
		if finger.role != Finger.Role.SWIPE_CANDIDATE:
			continue
		var since := time_s - finger.down_s
		if since <= _tuning.second_finger_window_s and finger.down_s > latest and since >= 0.0:
			partner = index
			latest = finger.down_s
	return partner


# Classifies the pair as a pinch or a Nudge once its gap or its midpoint has changed
# enough. If both cross in one move, the one further past its threshold wins.
func _classify() -> void:
	var gap := _fingers[_pair.first].position.distance_to(_fingers[_pair.second].position)
	var gap_change := (gap - _pair.start_gap) / unit_px
	var pinch := absf(gap_change) / _tuning.pinch_distance
	var shift := _midpoint().distance_to(_pair.start_midpoint) / unit_px / _tuning.nudge_distance
	if pinch < 1.0 and shift < 1.0:
		return
	if shift > pinch:
		_pair.kind = Pair.Kind.NUDGE
		return
	_pair.aim = _midpoint()
	if gap_change < 0.0:
		_pair.kind = Pair.Kind.PINCH_IN
		pinched_in.emit(_pair.aim)
	else:
		_pair.kind = Pair.Kind.PINCH_OUT
		pinched_out.emit(_pair.aim)


func _midpoint() -> Vector2:
	return (_fingers[_pair.first].position + _fingers[_pair.second].position) / 2.0


## One finger on the screen.
class Finger:
	extends RefCounted

	## What the finger is doing.
	enum Role {
		## On its own, and may still swipe a Spin.
		SWIPE_CANDIDATE,
		## One of the active pair.
		PAIRED,
		## Has done its move, or was left over or dropped: nothing more until it lifts.
		IGNORED,
	}

	## What the finger is doing.
	var role := Role.SWIPE_CANDIDATE
	## Where the finger is now, in pixels.
	var position: Vector2
	## When the finger went down.
	var down_s: float
	## When the finger last moved, or went down.
	var moved_s: float
	## Where the finger last moved slower than a swipe.
	var swipe_from: Vector2


	func _init(at: Vector2, at_time_s: float) -> void:
		position = at
		down_s = at_time_s
		moved_s = at_time_s
		swipe_from = at


## Two fingers classified together as a pinch or a Nudge.
class Pair:
	extends RefCounted

	## What the pair was classified as.
	enum Kind {
		## Neither threshold crossed yet.
		UNCLASSIFIED,
		## The gap closed first: Attract.
		PINCH_IN,
		## The gap opened first: Repel.
		PINCH_OUT,
		## The midpoint moved first.
		NUDGE,
	}

	## What the pair was classified as.
	var kind := Kind.UNCLASSIFIED
	## The first finger's touch index.
	var first: int
	## The second finger's touch index.
	var second: int
	## The gap between the fingers when they paired, in pixels.
	var start_gap: float
	## The fingers' midpoint when they paired, in pixels.
	var start_midpoint: Vector2
	## The pinch centre at classification, in pixels.
	var aim: Vector2


	func _init(first_index: int, second_index: int, first_at: Vector2, second_at: Vector2) -> void:
		first = first_index
		second = second_index
		start_gap = first_at.distance_to(second_at)
		start_midpoint = (first_at + second_at) / 2.0
