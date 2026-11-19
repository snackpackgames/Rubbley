class_name RubbleyAttractCue
extends Node
## Placeholder feedback for Rubbley's Attract, so players can see when it is on. While he
## Attracts on self, rings contract onto him from a few times his radius, thickening as
## they close, as a Gravity Well's do ([AttractPulse]).
## While a Targeted Attract holds a glowing body, a tether joins his surface to its
## surface. It polls [RubbleyMoves] each frame. Art direction will replace it.

## How the rings and tether look and move.
@export var tuning: AttractCueTuning
## Rubbley's moves, which say which Attract is on.
@export var moves: RubbleyMoves
## Rubbley's Mass, whose radius the rings close on.
@export var mass: RubbleyMass
## The rings round Rubbley, set to top level so they lie flat however he tumbles. Its
## mesh is an [ImmediateMesh] the rings are drawn into each frame ([FlatRings]).
@export var rings: MeshInstance3D
## The tether, a unit box set to top level, stretched between Rubbley and the target.
@export var tether: MeshInstance3D

var _time_s := 0.0


func _ready() -> void:
	assert(tuning != null, "%s needs AttractCueTuning" % name)
	assert(moves != null, "%s needs RubbleyMoves" % name)
	assert(mass != null, "%s needs RubbleyMass" % name)
	assert(rings != null and rings.top_level, "%s needs top-level rings" % name)
	assert(rings.mesh is ImmediateMesh, "%s needs rings drawn into an ImmediateMesh" % name)
	assert(tether != null and tether.top_level, "%s needs a top-level tether" % name)
	rings.visible = false
	tether.visible = false


func _process(delta: float) -> void:
	_time_s += delta
	_show_rings(moves.is_attracting_self())
	_show_tether(moves.attract_target())


func _show_rings(on: bool) -> void:
	rings.visible = on
	if not on:
		return
	rings.global_transform = Transform3D(
		Basis.IDENTITY,
		mass.body.get_global_transform_interpolated().origin,
	)
	var inner_m := mass.radius_m()
	var outer_m := inner_m * tuning.self_reach
	var mesh := rings.mesh as ImmediateMesh
	FlatRings.clear(mesh)
	for i in tuning.ring_count:
		var offset := float(i) / tuning.ring_count
		var radius_m := AttractPulse.ring_radius_m(
			_time_s,
			tuning.pulse_period_s,
			inner_m,
			outer_m,
			offset,
		)
		var width_m := AttractPulse.ring_width_m(radius_m, outer_m, outer_m * tuning.widest_ring)
		var opacity := AttractPulse.ring_opacity(_time_s, tuning.pulse_period_s, offset)
		FlatRings.add(mesh, radius_m, width_m, Color(1, 1, 1, opacity * tuning.max_opacity))


func _show_tether(target: Targetable) -> void:
	tether.visible = target != null
	if target == null:
		return
	var from := mass.body.global_position
	var to := target.body_position()
	var along := to - from
	along.y = 0.0
	if along.is_zero_approx():
		tether.visible = false
		return
	var direction := along.normalized()
	var start := from + direction * mass.radius_m()
	var end := to - direction * target.radius_m()
	var length_m := maxf(start.distance_to(end), 0.0)
	var basis := Basis.looking_at(direction, Vector3.UP).scaled_local(
		Vector3(tuning.tether_width_m, tuning.tether_width_m * 0.2, length_m),
	)
	tether.global_transform = Transform3D(basis, (start + end) * 0.5)
	tether.transparency = 1.0 - tuning.max_opacity
