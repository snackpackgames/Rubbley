class_name RubbleySpin
extends Node
## Rubbley's Spin (ADR 0012): a brief shield all the way round him that deflects whatever
## hits it, from every angle. It adapts a [SpinTimer], which owns the duration and
## lockout, and [SpinShield], which owns the bounce: each tick the shield is up, every
## free body inside it that is closing on Rubbley bounces, the lighter of the two off the
## heavier. [RubbleyMoves] fires it, and it sits after them in the tick, so a Spin
## deflects on the tick it fires.

# The most bodies one shield query returns, an engine query limit rather than a feel
# value: far more than can crowd inside a shield a metre or two across.
const _MAX_HITS := 32

## The shield's size, duration, lockout and perfect window.
@export var tuning: SpinTuning
## Rubbley's body, which the shield surrounds.
@export var body: RigidBody3D
## Rubbley's sphere collider, whose surface the shield reaches past.
@export var collider: CollisionShape3D
## A unit sphere, shown scaled to the shield while it is up.
@export var shield_mesh: Node3D

var _timer: SpinTimer
var _shield_shape := SphereShape3D.new()


func _ready() -> void:
	assert(tuning != null, "%s needs SpinTuning" % name)
	assert(body != null, "%s needs a body" % name)
	assert(collider != null and collider.shape is SphereShape3D, "%s needs a sphere" % name)
	assert(shield_mesh != null, "%s needs a shield mesh" % name)
	_timer = SpinTimer.new(tuning)
	shield_mesh.visible = false


func _physics_process(delta: float) -> void:
	if _timer.is_spinning():
		_deflect()
	_timer.advance(delta)
	_show_shield()


## Raises the shield and returns true, or returns false when it is already up or locked out.
func fire() -> bool:
	var fired := _timer.fire()
	_show_shield()
	return fired


## Whether the shield is up.
func is_spinning() -> bool:
	return _timer.is_spinning()


## Whether the shield is up and still inside its perfect window, for the perfect-Spin
## blast-back that projectiles will use.
func is_perfect() -> bool:
	return _timer.is_perfect()


## Returns the shield's radius from Rubbley's centre, in metres.
func shield_radius_m() -> float:
	var sphere := collider.shape as SphereShape3D
	return sphere.radius + tuning.shield_reach_m


# Bounces every free body inside the shield that is closing on Rubbley, or Rubbley off
# it when it is the heavier.
func _deflect() -> void:
	_shield_shape.radius = shield_radius_m()
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shield_shape
	query.transform = Transform3D(Basis.IDENTITY, body.global_position)
	query.exclude = [body.get_rid()]
	var hits := body.get_world_3d().direct_space_state.intersect_shape(query, _MAX_HITS)
	# A body with several shapes shows up once per shape, but must bounce once.
	var bounced := { }
	for hit in hits:
		var collider_hit: Object = hit[&"collider"]
		var other := collider_hit as RigidBody3D
		if other == null or other.freeze or bounced.has(other):
			continue
		bounced[other] = true
		if other.mass <= body.mass:
			_bounce(other, body)
		else:
			_bounce(body, other)


# Bounces [param lighter] off [param heavier], which takes none of it.
func _bounce(lighter: RigidBody3D, heavier: RigidBody3D) -> void:
	var change := SpinShield.bounce_change(
		heavier.global_position,
		heavier.linear_velocity,
		lighter.global_position,
		lighter.linear_velocity,
		tuning.restitution,
	)
	lighter.apply_central_impulse(change * lighter.mass)


func _show_shield() -> void:
	shield_mesh.visible = _timer.is_spinning()
	shield_mesh.scale = Vector3.ONE * shield_radius_m()
