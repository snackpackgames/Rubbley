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
## The piece's RNG component, whose [signal Rng.seeded] picks the rock shape and size.
@export var rng: Rng

var _base_mass_kg := 0.0


func _ready() -> void:
	assert(
		tuning != null and body != null and mesh != null and collider != null,
		"%s needs its parts" % name,
	)
	_base_mass_kg = body.mass
	if _pool_tuning != tuning:
		_build_pool()
	_apply_rock(0, 1.0)
	if rng != null:
		rng.seeded.connect(_on_seeded)


func _on_seeded(source: RandomNumberGenerator) -> void:
	var pick := source.randi() % _meshes.size()
	# Squaring a uniform pick leans sizes toward the small end.
	var size := lerpf(tuning.min_size, tuning.max_size, pow(source.randf(), 2.0))
	_apply_rock(pick, size)


func _apply_rock(pick: int, size: float) -> void:
	mesh.mesh = _meshes[pick]
	collider.shape = _shapes[pick]
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
