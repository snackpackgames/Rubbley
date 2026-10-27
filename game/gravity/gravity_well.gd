class_name GravityWell
extends Area3D
## A temporary point of pull Rubbley places in empty space with an untargeted Attract
## (ADR 0006). Its Area point gravity pulls every body inside its radius, Rubbley too,
## with the same strength at any distance, and it is never pulled. Its drag slows what
## moves inside it, so it gathers bodies instead of slinging them through. It pulls at
## full strength for its duration, then fades out, and frees itself.

## The sphere the pull reaches across, a child of this Area.
@export var reach: CollisionShape3D

## How hard it pulls toward its centre at full strength, in m/s². Set before it enters the tree.
var strength_m_per_s2 := 0.0
## The linear damping it adds to bodies inside it, per second, until it goes. Set before
## it enters the tree.
var drag_per_second := 0.0
## How far it reaches, in metres. Set before it enters the tree.
var radius_m := 1.0
## How long it pulls at full strength, in seconds. Set before it enters the tree.
var duration_s := 1.0
## How long its pull then takes to fade to nothing, in seconds. Set before it enters the tree.
var fade_s := 0.0

var _age_s := 0.0


func _ready() -> void:
	assert(reach != null and reach.shape is SphereShape3D, "%s needs a sphere reach" % name)
	gravity_space_override = Area3D.SPACE_OVERRIDE_COMBINE
	gravity_point = true
	gravity_point_center = Vector3.ZERO
	# A unit distance of 0 pulls with the same strength across the whole radius.
	gravity_point_unit_distance = 0.0
	gravity = strength_m_per_s2
	# Bodies combine damping, so this adds to their own (see [PlayPlaneBody]).
	linear_damp_space_override = Area3D.SPACE_OVERRIDE_COMBINE
	linear_damp = drag_per_second
	# Each Well has its own sphere, so resizing one never resizes another.
	var sphere := reach.shape.duplicate() as SphereShape3D
	sphere.radius = radius_m
	reach.shape = sphere


func _physics_process(delta: float) -> void:
	_age_s += delta
	var fading_s := _age_s - duration_s
	if fading_s >= fade_s:
		queue_free()
	elif fading_s > 0.0:
		gravity = strength_m_per_s2 * (1.0 - fading_s / fade_s)
