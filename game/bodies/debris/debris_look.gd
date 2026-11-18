class_name DebrisLook
extends Node
## Gives a piece of debris one of a few shared chipped rocks at random, as both its mesh
## and its collider, so pieces vary but share their meshes.

static var _pool_tuning: ChippedRockTuning
static var _meshes: Array[ArrayMesh] = []
static var _shapes: Array[ConvexPolygonShape3D] = []

## The rocks' look, and how many the debris shares.
@export var tuning: ChippedRockTuning
## The piece's mesh, which shows the rock.
@export var mesh: MeshInstance3D
## The piece's collider, which takes the rock's shape.
@export var collider: CollisionShape3D


func _ready() -> void:
	assert(tuning != null and mesh != null and collider != null, "%s needs its parts" % name)
	if _pool_tuning != tuning:
		_build_pool()
	var pick := randi() % _meshes.size()
	mesh.mesh = _meshes[pick]
	collider.shape = _shapes[pick]


func _build_pool() -> void:
	_pool_tuning = tuning
	_meshes.clear()
	_shapes.clear()
	for seed_value in tuning.shapes:
		var rock := ChippedRock.new(tuning, seed_value)
		_meshes.append(rock.mesh())
		var shape := ConvexPolygonShape3D.new()
		shape.points = rock.points()
		_shapes.append(shape)
