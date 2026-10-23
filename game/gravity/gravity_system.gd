class_name GravitySystem
extends Node
## A level's gravity (ADR 0016). Every physics tick it reads the
## [code]gravity_bodies[/code] group in tree order, adds up its force contributors
## (the pairwise [GravitySolver], then [Drift]) and applies the sum to each body once.

## Runs after gameplay's physics tick, so this tick's Gravega multipliers apply this tick.
const PHYSICS_PRIORITY := 100

## How gravity and Drift behave in this level.
@export var tuning: GravityTuning
## The body Drift carries along the stage, normally Rubbley. Nothing drifts when unset.
@export var drift_body: GravityBody
## The way Drift carries [member drift_body], on the Play Plane.
@export var drift_direction := Vector3.RIGHT

var _solver: GravitySolver
var _drift: Drift


func _ready() -> void:
	assert(tuning != null, "GravitySystem needs a GravityTuning")
	process_physics_priority = PHYSICS_PRIORITY
	_solver = GravitySolver.new(tuning)
	_drift = Drift.new(tuning)


func _physics_process(_delta: float) -> void:
	var gravity_bodies: Array[GravityBody] = []
	for node in get_tree().get_nodes_in_group(GravityBody.GROUP):
		var gravity_body := node as GravityBody
		if gravity_body != null and gravity_body.body != null:
			gravity_bodies.append(gravity_body)

	var count := gravity_bodies.size()
	var positions := PackedVector3Array()
	var masses := PackedFloat64Array()
	var roles := PackedInt32Array()
	var multipliers := PackedFloat64Array()
	positions.resize(count)
	masses.resize(count)
	roles.resize(count)
	multipliers.resize(count)
	for i in count:
		var gravity_body := gravity_bodies[i]
		positions[i] = gravity_body.body.global_position
		masses[i] = gravity_body.body.mass
		roles[i] = gravity_body.role
		multipliers[i] = gravity_body.gravega_multiplier

	var totals := _solver.forces(positions, masses, roles, multipliers)
	var drift := _drift.forces(count, gravity_bodies.find(drift_body), drift_direction)
	for i in count:
		var force := totals[i] + drift[i]
		if force != Vector3.ZERO:
			gravity_bodies[i].body.apply_central_force(force)
