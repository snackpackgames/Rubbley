class_name RubbleyMass
extends Node
## Rubbley's Mass as his health and size (ADR 0017). Mass is [member RigidBody3D.mass],
## never stored twice, and held inside the min–max of his effective Stats, which a Stat
## Modifier can move. His collider and mesh take the radius the Stats' Mass→size curve
## gives, and the CameraRig zooms to it (ADR 0007).
## A body that starts touching him takes Mass by [CollisionDamage], measured from the
## velocities both had before the tick's contact was solved. While Spin's shield is up he is
## impervious to it. Debris that touches him during Attract on self does no damage: it is
## absorbed, and its mass is added to his. Debris already resting on him when Attract on
## self starts is absorbed too. It sits after [RubbleyMoves] in the tick, so it sees this
## tick's Attract.

## Rubbley absorbed a piece of debris of [param mass_kg].
signal absorbed(mass_kg: float)

## The group a body joins, in its scene, to be Debris that Attract on self absorbs.
const DEBRIS_GROUP := &"debris"

## How much Mass a collision takes.
@export var damage_tuning: CollisionDamageTuning
## Rubbley's effective Stats, for his Mass limits and size curve.
@export var live_stats: RubbleyLiveStats
## Rubbley's body, whose mass this is.
@export var body: RigidBody3D
## Rubbley's sphere collider, resized with his Mass. Its shape must be local to the scene.
@export var collider: CollisionShape3D
## Rubbley's mesh, scaled with his Mass from the size it has at the collider's radius.
@export var mesh: Node3D
## Rubbley's moves, which say when he is Attracting on self.
@export var moves: RubbleyMoves
## Rubbley's Spin, whose shield makes him impervious to collision damage.
@export var spin: RubbleySpin

# The mesh's scale per metre of radius, from how the scene places it.
var _mesh_scale_per_m: Vector3
# Every gravity body's velocity before this tick's physics step, Rubbley's included,
# keyed by body: by the time a contact is reported, it has already been solved.
var _velocities_before: Dictionary[RigidBody3D, Vector3] = { }


func _ready() -> void:
	assert(damage_tuning != null, "%s needs CollisionDamageTuning" % name)
	assert(live_stats != null, "%s needs RubbleyLiveStats" % name)
	assert(body != null, "%s needs a body" % name)
	assert(collider != null and collider.shape is SphereShape3D, "%s needs a sphere" % name)
	assert(mesh != null, "%s needs a mesh" % name)
	assert(moves != null, "%s needs RubbleyMoves" % name)
	assert(spin != null, "%s needs a RubbleySpin" % name)
	assert(live_stats.effective.mass_to_radius_m != null, "%s needs a size curve" % name)
	_mesh_scale_per_m = mesh.scale / radius_m()
	_set_mass(live_stats.effective.starting_mass_kg)
	body.body_entered.connect(_on_body_entered)
	live_stats.rebuilt.connect(_on_stats_rebuilt)


func _physics_process(_delta: float) -> void:
	if moves.is_attracting_self():
		for other in body.get_colliding_bodies():
			_absorb_if_debris(other)
	_velocities_before.clear()
	for node in get_tree().get_nodes_in_group(GravityBody.GROUP):
		var other := (node as GravityBody).body
		if other != null:
			_velocities_before[other] = other.linear_velocity


## Returns Rubbley's radius in metres: his collider's, which follows his Mass.
func radius_m() -> float:
	var sphere := collider.shape as SphereShape3D
	return sphere.radius


func _on_body_entered(other: Node) -> void:
	var other_body := other as RigidBody3D
	if other_body == null or other_body.is_queued_for_deletion():
		return
	if moves.is_attracting_self() and _absorb_if_debris(other_body):
		return
	if spin.is_spinning():
		return
	var impulse := CollisionDamage.hit_impulse_n_s(
		body.global_position,
		_velocity_before(body),
		body.mass,
		other_body.global_position,
		_velocity_before(other_body),
		other_body.mass,
		other_body.freeze,
	)
	var lost_kg := CollisionDamage.mass_lost_kg(impulse, damage_tuning)
	if lost_kg > 0.0:
		_set_mass(body.mass - lost_kg)


# Absorbs [param other] into Rubbley's Mass and frees it, if it is debris not already
# absorbed. Returns whether it was absorbed.
func _absorb_if_debris(other: Node) -> bool:
	var piece := other as RigidBody3D
	if piece == null or piece.is_queued_for_deletion() or not piece.is_in_group(DEBRIS_GROUP):
		return false
	_set_mass(body.mass + piece.mass)
	piece.queue_free()
	absorbed.emit(piece.mass)
	return true


func _on_stats_rebuilt() -> void:
	_set_mass(body.mass)


# Returns [param of]'s velocity before this tick's step, or its velocity now for a body
# that wasn't in gravity then.
func _velocity_before(of: RigidBody3D) -> Vector3:
	if _velocities_before.has(of):
		return _velocities_before[of]
	return of.linear_velocity


# Sets Rubbley's Mass to [param mass_kg], held inside his limits, and resizes him to match.
func _set_mass(mass_kg: float) -> void:
	var stats := live_stats.effective
	body.mass = clampf(mass_kg, stats.min_mass_kg, stats.max_mass_kg)
	var radius := stats.mass_to_radius_m.sample(body.mass)
	(collider.shape as SphereShape3D).radius = radius
	mesh.scale = _mesh_scale_per_m * radius
