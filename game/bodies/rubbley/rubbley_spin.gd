class_name RubbleySpin
extends Node
## Rubbley's Spin (ADR 0012): a brief shield all the way round him that deflects whatever
## hits it, from every angle. [method fire] raises it for the Spin's duration, then a
## lockout follows. Firing while the shield is up or locked out does nothing, so holding
## or mashing can't extend it. Each tick the shield is up, every free body inside it that
## is closing on Rubbley has that closing speed sent back, relative to him; he takes
## none of it. [RubbleyMoves] fires it, and it sits after them in the tick, so a Spin
## deflects on the tick it fires.

# The most bodies the shield deflects in one tick.
const _MAX_HITS := 32

## The shield's size, duration, lockout and perfect window.
@export var tuning: SpinTuning
## Rubbley's body, which the shield surrounds.
@export var body: RigidBody3D
## Rubbley's sphere collider, whose surface the shield reaches past.
@export var collider: CollisionShape3D
## Shown, scaled to the shield, while it is up. A unit sphere.
@export var shield_mesh: Node3D

# Seconds since the last Spin fired; INF before the first.
var _elapsed_s := INF
var _shield_shape := SphereShape3D.new()


func _ready() -> void:
	assert(tuning != null, "%s needs SpinTuning" % name)
	assert(body != null, "%s needs a body" % name)
	assert(collider != null and collider.shape is SphereShape3D, "%s needs a sphere" % name)
	_show_shield(false)


func _physics_process(delta: float) -> void:
	var spinning := is_spinning()
	if spinning:
		_deflect()
	_elapsed_s += delta
	_show_shield(spinning and is_spinning())


## Raises the shield, unless it is already up or locked out. Returns whether it fired.
func fire() -> bool:
	if _elapsed_s < tuning.duration_s + tuning.lockout_s:
		return false
	_elapsed_s = 0.0
	_show_shield(true)
	return true


## Whether the shield is up.
func is_spinning() -> bool:
	return _elapsed_s < tuning.duration_s


## Whether the shield is up and still inside its perfect window.
func is_perfect() -> bool:
	return is_spinning() and _elapsed_s < tuning.perfect_window_s


## Returns the shield's radius from Rubbley's centre, in metres.
func shield_radius_m() -> float:
	var sphere := collider.shape as SphereShape3D
	return sphere.radius + tuning.shield_reach_m


# Sends back the closing speed of every free body inside the shield.
func _deflect() -> void:
	_shield_shape.radius = shield_radius_m()
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shield_shape
	query.transform = Transform3D(Basis.IDENTITY, body.global_position)
	query.exclude = [body.get_rid()]
	var hits := body.get_world_3d().direct_space_state.intersect_shape(query, _MAX_HITS)
	# A body with several shapes shows up once per shape, but must be deflected once.
	var deflected := { }
	for hit in hits:
		var collider_hit: Object = hit[&"collider"]
		var other := collider_hit as RigidBody3D
		if other == null or other.freeze or deflected.has(other):
			continue
		deflected[other] = true
		var outward := other.global_position - body.global_position
		outward.y = 0.0
		if outward.is_zero_approx():
			continue
		outward = outward.normalized()
		var closing := (other.linear_velocity - body.linear_velocity).dot(outward)
		if closing < 0.0:
			var change := -outward * closing * (1.0 + tuning.restitution)
			other.apply_central_impulse(change * other.mass)


func _show_shield(shown: bool) -> void:
	if shield_mesh == null:
		return
	shield_mesh.visible = shown
	if shown:
		shield_mesh.scale = Vector3.ONE * shield_radius_m()
