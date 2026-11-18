class_name DebrisLook
extends Node
## Gives a piece of debris one of a few shared chipped rocks at random, as both its mesh
## and its collider, at a random size, so pieces vary but share their meshes. A piece's
## Mass scales with its volume, from the scene's Mass at size 1.

static var _pool_tuning: ChippedRockTuning
static var _meshes: Array[ArrayMesh] = []
static var _shapes: Array[ConvexPolygonShape3D] = []

## The rocks' look, how many the debris shares, and their range of sizes.
@export var tuning: ChippedRockTuning
## The piece's body, whose Mass follows its size.
@export var body: RigidBody3D
## The piece's mesh, which shows the rock.
@export var mesh: MeshInstance3D
## The piece's collider, which takes the rock's shape.
@export var collider: CollisionShape3D


func _ready() -> void:
	assert(
		tuning != null and body != null and mesh != null and collider != null,
		"%s needs its parts" % name,
	)
	if _pool_tuning != tuning:
		_build_pool()
	var pick := randi() % _meshes.size()
	mesh.mesh = _meshes[pick]
	collider.shape = _shapes[pick]
	# Squaring a uniform pick leans sizes toward the small end.
	var size := lerpf(tuning.min_size, tuning.max_size, pow(randf(), 2.0))
	mesh.scale = Vector3.ONE * size
	collider.scale = Vector3.ONE * size
	body.mass *= pow(size, 3.0)


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
