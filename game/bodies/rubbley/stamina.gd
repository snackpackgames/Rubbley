class_name Stamina
extends RefCounted
## Rubbley's live Stamina (ADR 0017): the one pool every move draws on. Moves spend a
## fixed cost or drain it while held, and a move it can't afford doesn't fire. It refills
## at the regen rate once no move has used it for the regen delay. Its limits come from
## the effective [RubbleyStats], and new Stats cut it down to a smaller max.

var _stats: RubbleyStats
var _current: float
# Seconds since a move last used Stamina, counted by [method advance].
var _idle_s := 0.0
# Whether a move used Stamina since the last [method advance].
var _used := false


## Builds a full pool on [param stats]'s limits.
func _init(stats: RubbleyStats) -> void:
	_stats = stats
	_current = stats.stamina_max


## Returns how much Stamina is left.
func current() -> float:
	return _current


## Switches to [param stats]'s limits, cutting Stamina down to a smaller max.
func set_stats(stats: RubbleyStats) -> void:
	_stats = stats
	_current = minf(_current, stats.stamina_max)


## Whether the pool covers [param cost].
func can_afford(cost: float) -> bool:
	return _current >= cost


## Takes [param cost] and returns true, or takes nothing and returns false when the pool
## can't cover it.
func spend(cost: float) -> bool:
	if not can_afford(cost):
		return false
	_current -= cost
	_used = true
	return true


## Drains [param per_second] for a tick of [param delta_s] seconds, stopping at empty.
## Returns false, draining nothing, when the pool was already empty.
func drain(per_second: float, delta_s: float) -> bool:
	if _current <= 0.0:
		return false
	_current = maxf(_current - per_second * delta_s, 0.0)
	_used = true
	return true


## Moves time on by [param delta_s] seconds: refills at the regen rate for the part of the
## tick past the regen delay, unless a move used Stamina since the last call.
func advance(delta_s: float) -> void:
	if _used:
		_used = false
		_idle_s = 0.0
		return
	var idle_before_s := _idle_s
	_idle_s += delta_s
	var regen_s := minf(delta_s, _idle_s - maxf(idle_before_s, _stats.stamina_regen_delay_s))
	if regen_s > 0.0:
		_current = minf(_current + _stats.stamina_regen_per_second * regen_s, _stats.stamina_max)
