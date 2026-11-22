class_name FreeTierGate
extends RefCounted
## The Free Tier gate rule (ADRs 0015, 0019). Reads only [code]has_full_game()[/code] and
## the always-free levels list; nothing else is gated.

var _has_full_game: Callable
var _free_levels: Array[StringName]


## Creates a gate reading [param has_full_game_fn] and the [param free_levels] ids.
func _init(has_full_game_fn: Callable, free_levels: Array[StringName]) -> void:
	_has_full_game = has_full_game_fn
	_free_levels = free_levels.duplicate()


## Returns true if [param level_id] can be played right now: either the player has the
## Full Game or the level is always free.
func can_play_level(level_id: StringName) -> bool:
	if _has_full_game.call() == true:
		return true
	return is_level_free(level_id)


## Returns true if [param level_id] is in the always-free levels list.
func is_level_free(level_id: StringName) -> bool:
	return _free_levels.has(level_id)
