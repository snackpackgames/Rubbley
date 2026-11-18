extends GdUnitTestSuite
## The placeholder debris rock: a flat-shaded stone whose corners are chipped in by
## random amounts and stretched along its axes, the same for the same seed.

var _tuning: ChippedRockTuning


## A 0.6 m rock, chipped up to a quarter of its radius and stretched up to 30%.
func before_test() -> void:
	_tuning = ChippedRockTuning.new()
	_tuning.width_m = 0.6
	_tuning.chip = 0.25
	_tuning.max_stretch = 0.3


## The rock never reaches past its width stretched by the most it may be stretched.
func test_a_rock_stays_inside_its_width() -> void:
	var rock := ChippedRock.new(_tuning, 7)
	var reach := 0.0
	for point: Vector3 in rock.points():
		reach = maxf(reach, point.length())
	assert_float(reach).is_less_equal(0.3 * 1.3 + 1e-4)
	assert_float(reach).is_greater(0.3 * 0.5)


## The same seed gives the same rock, and another seed gives another.
func test_a_seed_picks_the_shape() -> void:
	var first := ChippedRock.new(_tuning, 1).points()
	var again := ChippedRock.new(_tuning, 1).points()
	var other := ChippedRock.new(_tuning, 2).points()
	assert_array(again).is_equal(first)
	assert_array(other).is_not_equal(first)


## The mesh is the rock's 20 faces, each flat: all three corners share the face's normal.
func test_the_mesh_has_twenty_flat_faces() -> void:
	var arrays := ChippedRock.new(_tuning, 3).mesh().surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_int(normals.size()).is_equal(60)
	for face in 20:
		assert_vector(normals[face * 3 + 1]).is_equal(normals[face * 3])
		assert_vector(normals[face * 3 + 2]).is_equal(normals[face * 3])


## Each face's normal points out of the rock, so it is lit and drawn from outside.
func test_faces_face_outward() -> void:
	var arrays := ChippedRock.new(_tuning, 4).mesh().surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for face in 20:
		var middle := (vertices[face * 3] + vertices[face * 3 + 1] + vertices[face * 3 + 2]) / 3.0
		assert_float(normals[face * 3].dot(middle)).is_greater(0.0)
