class_name GravityWell
extends Area3D
## A temporary point of pull Rubbley places in empty space with an untargeted Attract
## (ADR 0006). Its Area point gravity pulls every body inside its radius, Rubbley too,
## with the same strength at any distance, and it is never pulled. It frees itself when
## its lifetime runs out.

## The sphere the pull reaches across, a child of this Area.
@export var reach: CollisionShape3D

## How hard it pulls toward its centre, in m/s². Set before it enters the tree.
var strength_m_per_s2 := 0.0
## How far it reaches, in metres. Set before it enters the tree.
var radius_m := 1.0
## How long it lasts, in seconds. Set before it enters the tree.
var lifetime_s := 1.0

var _remaining_s := 0.0


func _ready() -> void:
	assert(reach != null and reach.shape is SphereShape3D, "%s needs a sphere reach" % name)
	gravity_space_override = Area3D.SPACE_OVERRIDE_COMBINE
	gravity_point = true
	gravity_point_center = Vector3.ZERO
	# A unit distance of 0 pulls with the same strength across the whole radius.
	gravity_point_unit_distance = 0.0
	gravity = strength_m_per_s2
	# Each Well has its own sphere, so resizing one never resizes another.
	var sphere := reach.shape.duplicate() as SphereShape3D
	sphere.radius = radius_m
	reach.shape = sphere
	_remaining_s = lifetime_s


func _physics_process(delta: float) -> void:
	_remaining_s -= delta
	if _remaining_s <= 0.0:
		queue_free()
