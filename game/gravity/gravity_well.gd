class_name GravityWell
extends Area3D
## A temporary point of pull Rubbley places in empty space with an untargeted Attract
## (ADR 0006). It pulls every body inside its radius, Rubbley too, hardest at its centre
## and falling off to nothing at its edge, as in the controller-aim prototype. It is
## never pulled. Nothing slows what it pulls, so it can fling bodies through. It pulls
## at full strength for its duration, then fades out over its fade, and frees itself.
## Placeholder rings contract from its edge to its core while it pulls ([AttractPulse]),
## fading with it, so players can see how far it reaches.

# Inside this distance from the centre it doesn't pull, so a body at the centre has a
# direction to fall in and doesn't jitter across it. The prototype's 8 px.
const CORE_M := 0.36

# The radius of its core mesh, which the rings close on, in metres.
const CORE_MESH_M := 0.6

## The sphere it reaches across, a child of this Area, which finds the bodies inside.
@export var reach: CollisionShape3D
## How its rings look and move.
@export var cue_tuning: AttractCueTuning
## Its rings: each child is a flat unit ring, scaled to its radius.
@export var rings: Node3D

## How hard it pulls at its centre at full strength, in m/s². Set before it enters the tree.
var strength_m_per_s2 := 0.0
## How far it reaches, in metres. Set before it enters the tree.
var radius_m := 1.0
## How long it pulls at full strength, in seconds. Set before it enters the tree.
var duration_s := 1.0
## How long its pull then takes to fade to nothing, in seconds. 0 ends it at once. Set
## before it enters the tree.
var fade_s := 0.0

var _age_s := 0.0


func _ready() -> void:
	assert(reach != null and reach.shape is SphereShape3D, "%s needs a sphere reach" % name)
	assert(cue_tuning != null, "%s needs AttractCueTuning" % name)
	assert(rings != null, "%s needs rings" % name)
	# Each Well has its own sphere, so resizing one never resizes another.
	var sphere := reach.shape.duplicate() as SphereShape3D
	sphere.radius = radius_m
	reach.shape = sphere


func _process(_delta: float) -> void:
	var count := rings.get_child_count()
	for i in count:
		var ring := rings.get_child(i) as GeometryInstance3D
		var offset := float(i) / count
		var radius_m_now := AttractPulse.ring_radius_m(
			_age_s,
			cue_tuning.pulse_period_s,
			CORE_MESH_M,
			radius_m,
			offset,
		)
		ring.scale = Vector3(radius_m_now, 1.0, radius_m_now)
		var opacity := AttractPulse.ring_opacity(_age_s, cue_tuning.pulse_period_s, offset)
		ring.transparency = 1.0 - opacity * cue_tuning.max_opacity * _strength_share()


func _physics_process(delta: float) -> void:
	_age_s += delta
	var fading_s := _age_s - duration_s
	if fading_s >= fade_s:
		queue_free()
		return
	var strength := strength_m_per_s2 * _strength_share()
	for node in get_overlapping_bodies():
		var body := node as RigidBody3D
		if body != null and not body.freeze:
			body.apply_central_force(pull_on(body.global_position) * strength * body.mass)


## Returns the pull's direction toward the centre, on the Play Plane, scaled by its share
## of full strength at [param point]: 1 at the centre, 0 at the edge and beyond, and 0
## inside the core.
func pull_on(point: Vector3) -> Vector3:
	var offset := global_position - point
	offset.y = 0.0
	var distance := offset.length()
	if distance <= CORE_M or distance >= radius_m:
		return Vector3.ZERO
	return offset / distance * (1.0 - distance / radius_m)


# Its share of full strength now: 1 through its duration, falling to 0 over its fade.
func _strength_share() -> float:
	var fading_s := _age_s - duration_s
	if fading_s <= 0.0:
		return 1.0
	if fade_s <= 0.0:
		return 0.0
	return clampf(1.0 - fading_s / fade_s, 0.0, 1.0)
