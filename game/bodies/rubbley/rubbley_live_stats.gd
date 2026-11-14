class_name RubbleyLiveStats
extends Node
## Rubbley's Stats as he plays (ADR 0017): his base Stats with the active Stat Modifiers
## folded over them by [RubbleyStatsBuilder], and his live [Stamina], which reads its
## limits from them. The fold reruns when a modifier is added or a timed one expires, and
## Stamina is cut down to a smaller max. [RubbleyMoves] reads both each tick.

## Rubbley's base Stats, before any modifier.
@export var base_stats: RubbleyStats
## The modifiers active from level load, such as owned upgrades. Timed ones count down
## from then.
@export var starting_modifiers: Array[StatModifier] = []

## The Stats Rubbley plays with: [member base_stats] with every active modifier applied.
## A fresh copy each fold; never written.
var effective: RubbleyStats
## Rubbley's live Stamina.
var stamina: Stamina

var _modifiers: Array[StatModifier] = []
# Seconds each modifier in _modifiers has left; INF for one that lasts for good.
var _remaining_s := PackedFloat64Array()


func _ready() -> void:
	assert(base_stats != null, "%s needs RubbleyStats" % name)
	for modifier in starting_modifiers:
		_track(modifier)
	effective = RubbleyStatsBuilder.build(base_stats, _modifiers)
	stamina = Stamina.new(effective)


func _physics_process(delta: float) -> void:
	var expired := false
	for i in range(_modifiers.size() - 1, -1, -1):
		_remaining_s[i] -= delta
		if _remaining_s[i] <= 0.0:
			_modifiers.remove_at(i)
			_remaining_s.remove_at(i)
			expired = true
	if expired:
		_rebuild()
	stamina.advance(delta)


## Makes [param modifier] active, for its duration or for good, and refolds the Stats.
func add_modifier(modifier: StatModifier) -> void:
	_track(modifier)
	_rebuild()


func _track(modifier: StatModifier) -> void:
	_modifiers.append(modifier)
	_remaining_s.append(modifier.duration_s if modifier.duration_s > 0.0 else INF)


func _rebuild() -> void:
	effective = RubbleyStatsBuilder.build(base_stats, _modifiers)
	stamina.set_stats(effective)
