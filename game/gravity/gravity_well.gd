class_name GravityWell
extends Area3D
## A temporary point of pull Rubbley places in empty space with an untargeted Attract
## (ADR 0006). It pulls every body inside its radius, Rubbley too, hardest at its centre
## and falling off to nothing at its edge, as in the controller-aim prototype. It is
## never pulled. Nothing slows what it pulls, so it can fling bodies through. It pulls
## at full strength for its duration, then fades out over its fade, and frees itself.

# Inside this distance from the centre it doesn't pull, so a body at the centre has a
# direction to fall in and doesn't jitter across it. The prototype's 8 px.
const CORE_M := 0.36

## The sphere it reaches across, a child of this Area, which finds the bodies inside.
@export var reach: CollisionShape3D

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
	# Each Well has its own sphere, so resizing one never resizes another.
	var sphere := reach.shape.duplicate() as SphereShape3D
	sphere.radius = radius_m
	reach.shape = sphere


func _physics_process(delta: float) -> void:
	_age_s += delta
	var fading_s := _age_s - duration_s
	if fading_s >= fade_s:
		queue_free()
		return
	var strength := strength_m_per_s2
	if fading_s > 0.0:
		strength *= 1.0 - fading_s / fade_s
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
