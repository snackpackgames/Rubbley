class_name RubbleyMoves
extends Node
## Turns each tick's Move Input frame into Rubbley's moves (ADR 0012). When Attract
## starts, whatever is under the aim decides its use, and that target stays locked
## until release: Attract on self raises Rubbley's Gravega multiplier, a Targeted
## Attract raises the multiplier on his pair with the glowing body, and Attract into empty
## space places a Gravity Well, replacing any Well still active. Repel fires once, and the
## aim decides its use too: a Repel Pulse on Rubbley, a Targeted Repel on a glowing body,
## or a Gravity Ripple in empty space ([RepelImpulse] has the maths).
## It runs before the [GravitySystem] in the tick, so a multiplier applies at once.

## Rubbley's Gravega values.
@export var stats: RubbleyStats
## Rubbley's gravity, whose Gravega multipliers Attract raises.
@export var gravity_body: GravityBody
## Rubbley's sphere collider, whose radius decides when the aim is on him.
@export var collider: CollisionShape3D
## What an untargeted Attract places.
@export var gravity_well_scene: PackedScene

## A frame to read instead of Move Input's, for simulation tests (ADR 0018). Null in play.
var injected_frame: MoveInputFrame

var _attracting_self := false
# The glowing body a Targeted Attract has locked, until release.
var _attract_target: Targetable
# The one Gravity Well that may be active, until it ends or a new one replaces it.
var _gravity_well: GravityWell


func _ready() -> void:
	assert(stats != null, "%s needs RubbleyStats" % name)
	assert(gravity_body != null, "%s needs a GravityBody" % name)
	assert(collider != null and collider.shape is SphereShape3D, "%s needs a sphere" % name)
	assert(gravity_well_scene != null, "%s needs a Gravity Well scene" % name)


func _physics_process(_delta: float) -> void:
	var frame := injected_frame
	if frame == null:
		frame = MoveInputService.instance.frame
	match frame.attract:
		MoveInputFrame.Attract.PRESSED:
			_end_attract()
			_start_attract(frame.aim)
		MoveInputFrame.Attract.HELD:
			pass
		_:
			# Released, or idle after a release missed while the tree was paused.
			_end_attract()
	if frame.repel_fired:
		_repel(frame.aim)


func _start_attract(aim: Vector3) -> void:
	var targetables := Targetable.all_in(get_tree())
	var target := _target_under(aim, targetables)
	match target.kind:
		AimTarget.Kind.RUBBLEY:
			_attracting_self = true
			gravity_body.gravega_multiplier = stats.attract_self_multiplier
		AimTarget.Kind.CELESTIAL_BODY:
			_attract_target = targetables[target.body_index]
			gravity_body.pair_multipliers[_attract_target.gravity_body] = (
				stats.attract_celestial_multiplier
			)
		AimTarget.Kind.EMPTY_SPACE:
			_place_gravity_well(aim)


func _repel(aim: Vector3) -> void:
	var targetables := Targetable.all_in(get_tree())
	var target := _target_under(aim, targetables)
	var rubbley := gravity_body.body
	match target.kind:
		AimTarget.Kind.RUBBLEY:
			_push_away(
				rubbley.global_position,
				stats.repel_pulse_speed_m_per_s,
				stats.repel_pulse_radius_m,
				rubbley,
			)
			_stun_around(rubbley.global_position)
		AimTarget.Kind.CELESTIAL_BODY:
			var body := targetables[target.body_index].body()
			var impulse := RepelImpulse.targeted_impulse(
				rubbley.global_position,
				body.global_position,
				stats.targeted_repel_impulse_n_s,
			)
			# An Anchored Body is frozen and takes none of it: Rubbley takes the whole push.
			if not body.freeze:
				body.apply_central_impulse(impulse)
			rubbley.apply_central_impulse(-impulse)
		AimTarget.Kind.EMPTY_SPACE:
			_push_away(aim, stats.gravity_ripple_speed_m_per_s, stats.gravity_ripple_radius_m, null)


# What is under [param aim], with [param targetables] as the glowing bodies to pick from.
func _target_under(aim: Vector3, targetables: Array[Targetable]) -> AimTarget:
	var positions := PackedVector3Array()
	var radii := PackedFloat64Array()
	for targetable in targetables:
		positions.append(targetable.body_position())
		radii.append(targetable.radius_m())
	var sphere := collider.shape as SphereShape3D
	var rubbley_at := gravity_body.body.global_position
	return AimTarget.resolve(aim, rubbley_at, sphere.radius, positions, radii)


# Gives every gravity body in range of [param centre], except [param spared], a radial
# speed change, shrunk for bodies past the reference mass. Frozen bodies don't move.
func _push_away(
	centre: Vector3,
	speed_m_per_s: float,
	radius_m: float,
	spared: RigidBody3D,
) -> void:
	for node in get_tree().get_nodes_in_group(GravityBody.GROUP):
		var body := (node as GravityBody).body
		if body == null or body == spared or body.freeze:
			continue
		var change := RepelImpulse.radial_velocity_change(
			centre,
			body.global_position,
			radius_m,
			speed_m_per_s,
		)
		if change != Vector3.ZERO:
			var share := RepelImpulse.mass_share(
				body.mass,
				stats.radial_repel_reference_mass_kg,
				stats.radial_repel_mass_falloff,
			)
			body.apply_central_impulse(change * share * body.mass)


# Stuns every Stunnable body other than Rubbley within a Repel Pulse's radius of
# [param centre], measured on the Play Plane.
func _stun_around(centre: Vector3) -> void:
	var flat_centre := Vector2(centre.x, centre.z)
	for stunnable in Stunnable.all_in(get_tree()):
		if stunnable.body == gravity_body.body:
			continue
		var at := stunnable.body.global_position
		if flat_centre.distance_to(Vector2(at.x, at.z)) < stats.repel_pulse_radius_m:
			stunnable.stun(stats.repel_pulse_stun_s)


func _end_attract() -> void:
	if _attracting_self:
		gravity_body.gravega_multiplier = 1.0
		_attracting_self = false
	if is_instance_valid(_attract_target):
		gravity_body.pair_multipliers.erase(_attract_target.gravity_body)
	elif _attract_target != null:
		# The target was freed mid-Attract, so its pair can only be found as a freed key.
		for other: Variant in gravity_body.pair_multipliers.keys():
			if not is_instance_valid(other):
				gravity_body.pair_multipliers.erase(other)
	_attract_target = null


func _place_gravity_well(aim: Vector3) -> void:
	# Freed now, not queued, so the old Well pulls nothing more this tick.
	if is_instance_valid(_gravity_well):
		_gravity_well.free()
	var well := gravity_well_scene.instantiate() as GravityWell
	well.strength_m_per_s2 = stats.gravity_well_strength_m_per_s2
	well.radius_m = stats.gravity_well_radius_m
	well.duration_s = stats.gravity_well_duration_s
	well.fade_s = stats.gravity_well_fade_s
	well.position = Vector3(aim.x, 0.0, aim.z)
	# This component is a plain Node, so a Well under it sits in world space and stays
	# where it was placed while Rubbley moves on.
	add_child(well)
	_gravity_well = well
