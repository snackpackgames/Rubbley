class_name RubbleyRepelCue
extends Node
## Placeholder feedback for Rubbley's Repel, so every use reads on screen: a red-orange
## wave ([RepelWave]) out from Rubbley to a Repel Pulse's reach, out from the aim to a
## Gravity Ripple's, or ringing the body of a Targeted Repel. Each wave stays where it
## fired. It listens to [RubbleyMoves]. Art direction will replace it.

## How the waves look.
@export var tuning: RepelCueTuning
## Rubbley's moves, which signal each Repel.
@export var moves: RubbleyMoves
## Rubbley's Mass, whose radius a Repel Pulse's wave starts from.
@export var mass: RubbleyMass
## The waves, set to top level at the world origin. Its mesh is an [ImmediateMesh] the
## waves are drawn into each frame ([FlatRings]).
@export var waves: MeshInstance3D

var _live: Array[Wave] = []


func _ready() -> void:
	assert(tuning != null, "%s needs RepelCueTuning" % name)
	assert(moves != null, "%s needs RubbleyMoves" % name)
	assert(mass != null, "%s needs RubbleyMass" % name)
	assert(waves != null and waves.top_level, "%s needs top-level waves" % name)
	assert(waves.mesh is ImmediateMesh, "%s needs waves drawn into an ImmediateMesh" % name)
	moves.repel_pulse_fired.connect(_on_repel_pulse_fired)
	moves.gravity_ripple_fired.connect(_on_gravity_ripple_fired)
	moves.targeted_repel_fired.connect(_on_targeted_repel_fired)


func _process(delta: float) -> void:
	waves.global_transform = Transform3D.IDENTITY
	var mesh := waves.mesh as ImmediateMesh
	FlatRings.clear(mesh)
	for wave in _live:
		wave.age_s += delta
	_live = _live.filter(
		func(wave: Wave) -> bool:
			return wave.age_s < tuning.duration_s,
	)
	for wave in _live:
		var radius_m := RepelWave.radius_m(wave.age_s, tuning.duration_s, wave.from_m, wave.to_m)
		var color := tuning.color
		color.a *= RepelWave.opacity(wave.age_s, tuning.duration_s)
		FlatRings.add(mesh, radius_m, tuning.width_m, color, wave.at)


## How many waves are showing now.
func wave_count() -> int:
	return _live.size()


func _on_repel_pulse_fired(at: Vector3, radius_m: float) -> void:
	_start(at, mass.radius_m(), radius_m)


func _on_gravity_ripple_fired(at: Vector3, radius_m: float) -> void:
	_start(at, 0.0, radius_m)


func _on_targeted_repel_fired(target: Targetable) -> void:
	var radius_m := target.radius_m()
	_start(target.body_position(), radius_m, radius_m * (1.0 + tuning.targeted_growth))


func _start(at: Vector3, from_m: float, to_m: float) -> void:
	_live.append(Wave.new(Vector3(at.x, 0.0, at.z), from_m, to_m))


## One wave on its way out.
class Wave:
	extends RefCounted

	## Where it fired, on the Play Plane.
	var at: Vector3
	## The radius it starts at, in metres.
	var from_m: float
	## The radius it ends at, in metres.
	var to_m: float
	## Seconds since it fired.
	var age_s := 0.0


	func _init(fired_at: Vector3, start_m: float, end_m: float) -> void:
		at = fired_at
		from_m = start_m
		to_m = end_m
