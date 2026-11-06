class_name RubbleyMoves
extends Node
## Turns each tick's Move Input frame into Rubbley's moves (ADR 0012). When Attract
## starts, whatever is under the aim decides its use, and that target stays locked
## until release: Attract on self raises Rubbley's Gravega multiplier, a Targeted
## Attract raises the multiplier on his pair with the glowing body, and Attract into empty
## space places a Gravity Well, replacing any Well still active.
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


func _start_attract(aim: Vector3) -> void:
	var targetables := Targetable.all_in(get_tree())
	var positions := PackedVector3Array()
	var radii := PackedFloat64Array()
	for targetable in targetables:
		positions.append(targetable.body_position())
		radii.append(targetable.radius_m())
	var sphere := collider.shape as SphereShape3D
	var rubbley_at := gravity_body.body.global_position
	var target := AimTarget.resolve(aim, rubbley_at, sphere.radius, positions, radii)
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
