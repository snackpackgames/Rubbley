class_name CloudPushDebouncer
extends RefCounted
## Trailing debounce timer for [constant StoreBackend.CloudCapability.IN_CODE] cloud save
## pushes (ADR 0019). Coalesces rapid local saves into one cloud push after a quiet
## window, and supports immediate flushing on app exit or backgrounding.

var _delay_s: float
var _pending := false
var _remaining_s := 0.0


## Creates a debouncer waiting [param delay_s] seconds of quiet after each save.
func _init(delay_s: float = 2.0) -> void:
	_delay_s = maxf(delay_s, 0.0)


## Marks the save dirty and resets the debounce countdown.
func mark_dirty() -> void:
	_pending = true
	_remaining_s = _delay_s


## Cancels any pending push without firing it.
func cancel() -> void:
	_pending = false
	_remaining_s = 0.0


## Returns whether a cloud push is currently scheduled.
func is_pending() -> bool:
	return _pending


## Advances time by [param delta_s] seconds. Returns true on the tick the push should run.
func tick(delta_s: float) -> bool:
	if not _pending:
		return false
	_remaining_s -= maxf(delta_s, 0.0)
	if _remaining_s <= 0.0:
		_pending = false
		_remaining_s = 0.0
		return true
	return false


## Immediately consumes a pending push if one is scheduled, returning true when the caller
## should push now.
func flush() -> bool:
	if not _pending:
		return false
	_pending = false
	_remaining_s = 0.0
	return true
