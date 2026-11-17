class_name ChippedRock
extends RefCounted
## A placeholder debris rock: an icosahedron whose 12 corners are chipped in by random
## amounts, stretched along its axes, and drawn as 20 flat faces. The same seed always
## gives the same rock.

const _GOLDEN := 1.618034
# The icosahedron's corners, and its 20 faces as corner indices.
const _CORNERS: Array[Vector3] = [
	Vector3(-1, _GOLDEN, 0),
	Vector3(1, _GOLDEN, 0),
	Vector3(-1, -_GOLDEN, 0),
	Vector3(1, -_GOLDEN, 0),
	Vector3(0, -1, _GOLDEN),
	Vector3(0, 1, _GOLDEN),
	Vector3(0, -1, -_GOLDEN),
	Vector3(0, 1, -_GOLDEN),
	Vector3(_GOLDEN, 0, -1),
	Vector3(_GOLDEN, 0, 1),
	Vector3(-_GOLDEN, 0, -1),
	Vector3(-_GOLDEN, 0, 1),
]
const _FACES: Array[Vector3i] = [
	Vector3i(0, 11, 5),
	Vector3i(0, 5, 1),
	Vector3i(0, 1, 7),
	Vector3i(0, 7, 10),
	Vector3i(0, 10, 11),
	Vector3i(1, 5, 9),
	Vector3i(5, 11, 4),
	Vector3i(11, 10, 2),
	Vector3i(10, 7, 6),
	Vector3i(7, 1, 8),
	Vector3i(3, 9, 4),
	Vector3i(3, 4, 2),
	Vector3i(3, 2, 6),
	Vector3i(3, 6, 8),
	Vector3i(3, 8, 9),
	Vector3i(4, 9, 5),
	Vector3i(2, 4, 11),
	Vector3i(6, 2, 10),
	Vector3i(8, 6, 7),
	Vector3i(9, 8, 1),
]

var _points: PackedVector3Array = []


func _init(tuning: ChippedRockTuning, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var stretch := Vector3(
		1.0 + rng.randf_range(-tuning.max_stretch, tuning.max_stretch),
		1.0 + rng.randf_range(-tuning.max_stretch, tuning.max_stretch),
		1.0 + rng.randf_range(-tuning.max_stretch, tuning.max_stretch),
	)
	var radius := tuning.width_m * 0.5
	for corner in _CORNERS:
		var chipped := radius * (1.0 - rng.randf_range(0.0, tuning.chip))
		_points.append(corner.normalized() * chipped * stretch)


## Returns the rock's 12 corners in metres, round its centre.
func points() -> PackedVector3Array:
	return _points


## Returns the rock as 20 flat-shaded triangles facing outward.
func mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for face in _FACES:
		var a := _points[face.x]
		var b := _points[face.y]
		var c := _points[face.z]
		var normal := (b - a).cross(c - a).normalized()
		# Godot draws a face whose corners run clockwise seen from outside, so its
		# corners' cross product points in.
		if normal.dot(a + b + c) > 0.0:
			var swap := b
			b = c
			c = swap
			normal = -normal
		vertices.append_array([a, b, c])
		for i in 3:
			normals.append(-normal)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var built := ArrayMesh.new()
	built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return built
