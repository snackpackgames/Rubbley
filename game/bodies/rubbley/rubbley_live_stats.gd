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

var _active := ActiveStatModifiers.new()


func _ready() -> void:
	assert(base_stats != null, "%s needs RubbleyStats" % name)
	for modifier in starting_modifiers:
		_active.add(modifier)
	effective = RubbleyStatsBuilder.build(base_stats, _active.modifiers())
	stamina = Stamina.new(effective)


func _physics_process(delta: float) -> void:
	if _active.advance(delta):
		_rebuild()
	stamina.advance(delta)


## Makes [param modifier] active, for its duration or for good, and refolds the Stats.
func add_modifier(modifier: StatModifier) -> void:
	_active.add(modifier)
	_rebuild()


func _rebuild() -> void:
	effective = RubbleyStatsBuilder.build(base_stats, _active.modifiers())
	stamina.set_stats(effective)
