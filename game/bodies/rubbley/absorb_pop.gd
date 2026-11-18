class_name AbsorbPop
extends RefCounted
## The swell Rubbley's mesh gives when he absorbs debris, so every pickup reads on screen:
## it jumps up by the tuned swell, then eases out back to his own size over the pop's
## duration. Another absorb mid-pop swells it fully again.

var _tuning: AbsorbPopTuning
# Seconds since the last absorb. Infinite until the first.
var _elapsed_s := INF


func _init(tuning: AbsorbPopTuning) -> void:
	_tuning = tuning


## Swells the mesh fully, for an absorb this frame.
func start() -> void:
	_elapsed_s = 0.0


## Moves time on by [param delta_s] seconds.
func advance(delta_s: float) -> void:
	_elapsed_s += delta_s


## Returns the mesh's scale on top of its size: 1 at rest, 1 + the swell just after an
## absorb.
func scale() -> float:
	if _elapsed_s >= _tuning.duration_s:
		return 1.0
	var left := 1.0 - _elapsed_s / _tuning.duration_s
	return 1.0 + _tuning.swell * left * left
