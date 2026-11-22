class_name DebrisLook
extends Node
## Gives a piece of debris one of a few shared chipped rocks from a passed-in
## [RandomNumberGenerator] (ADR 0018), as both its mesh and its collider, at a seeded size,
## so pieces vary while staying reproducible. A piece's Mass scales with its volume, from
## the scene's Mass at size 1.

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

## The RNG passed in by the spawner or level before this node enters the tree.
var rng: RandomNumberGenerator

var _base_mass_kg := 0.0
var _seeded := false


func _ready() -> void:
	assert(
		tuning != null and body != null and mesh != null and collider != null,
		"%s needs its parts" % name,
	)
	_base_mass_kg = body.mass
	if _pool_tuning != tuning:
		_build_pool()
	if rng != null:
		apply_look(rng)
	else:
		var fallback := RandomNumberGenerator.new()
		fallback.seed = 0
		_apply_from(fallback)


## Returns whether an external [RandomNumberGenerator] has seeded this piece's look.
func is_seeded() -> bool:
	return _seeded


## Picks the rock shape, collider, size and volume-scaled Mass from [param source_rng].
func apply_look(source_rng: RandomNumberGenerator) -> void:
	assert(source_rng != null, "%s needs a RandomNumberGenerator" % name)
	rng = source_rng
	_seeded = true
	if is_node_ready():
		_apply_from(source_rng)


func _apply_from(source_rng: RandomNumberGenerator) -> void:
	var pick := source_rng.randi() % _meshes.size()
	mesh.mesh = _meshes[pick]
	collider.shape = _shapes[pick]
	# Squaring a uniform pick leans sizes toward the small end.
	var size := lerpf(tuning.min_size, tuning.max_size, pow(source_rng.randf(), 2.0))
	mesh.scale = Vector3.ONE * size
	collider.scale = Vector3.ONE * size
	body.mass = _base_mass_kg * pow(size, 3.0)


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
