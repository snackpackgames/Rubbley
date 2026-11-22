extends GdUnitTestSuite
## The shipped debris scene: each piece takes one of a few shared chipped rocks from a
## passed-in [RandomNumberGenerator] (ADR 0018), and collides as the rock it shows.

const DEBRIS_SCENE := preload("res://game/bodies/debris/debris.tscn")


## A piece shows a chipped rock and collides as that same rock.
func test_a_piece_collides_as_the_rock_it_shows() -> void:
	var piece := _spawn_debris(_rng(1))
	var mesh := (piece.get_node("Mesh") as MeshInstance3D).mesh
	var shape := (piece.get_node("Collider") as CollisionShape3D).shape as ConvexPolygonShape3D
	assert_object(shape).is_not_null()
	assert_int(mesh.get_faces().size()).is_equal(60)
	var corners := mesh.get_faces()
	for point: Vector3 in shape.points:
		var nearest := INF
		for corner in corners:
			nearest = minf(nearest, corner.distance_to(point))
		assert_float(nearest).is_less(1e-3)


## Pieces don't all look alike: twenty of them drawn from one RNG show more than one rock.
func test_pieces_are_varied() -> void:
	var rng := _rng(2)
	var meshes := { }
	for i in 20:
		var piece := _spawn_debris(rng)
		meshes[(piece.get_node("Mesh") as MeshInstance3D).mesh] = true
	assert_int(meshes.size()).is_greater(1)


## A piece comes in a seeded size inside the tuning's range, and its Mass grows with its
## volume: the cube of its size, times the scene's Mass at size 1.
func test_a_piece_weighs_with_its_size() -> void:
	var nominal_kg := (DEBRIS_SCENE.instantiate() as RigidBody3D)
	var base_kg := nominal_kg.mass
	nominal_kg.free()
	var rng := _rng(3)
	for i in 10:
		var piece := _spawn_debris(rng)
		var look := piece.get_node("Look") as DebrisLook
		var size: float = (piece.get_node("Mesh") as Node3D).scale.x
		assert_float(size).is_between(look.tuning.min_size, look.tuning.max_size)
		assert_float((piece.get_node("Collider") as Node3D).scale.x).is_equal_approx(size, 1e-5)
		assert_float(piece.mass).is_equal_approx(base_kg * pow(size, 3.0), 1e-4)


## Twenty pieces drawn from one RNG span a wide spread of Mass, the heaviest at least twice
## the lightest.
func test_pieces_vary_in_mass() -> void:
	var rng := _rng(4)
	var lightest := INF
	var heaviest := 0.0
	for i in 20:
		var piece := _spawn_debris(rng)
		lightest = minf(lightest, piece.mass)
		heaviest = maxf(heaviest, piece.mass)
	assert_float(heaviest).is_greater(lightest * 2.0)


## Two pieces seeded with the same RNG seed pick the exact same rock, size and Mass.
func test_same_seed_gives_identical_piece() -> void:
	var first := _spawn_debris(_rng(42))
	var second := _spawn_debris(_rng(42))
	assert_object((first.get_node("Mesh") as MeshInstance3D).mesh).is_same(
		(second.get_node("Mesh") as MeshInstance3D).mesh,
	)
	assert_object((first.get_node("Collider") as CollisionShape3D).shape).is_same(
		(second.get_node("Collider") as CollisionShape3D).shape,
	)
	assert_vector((first.get_node("Mesh") as Node3D).scale).is_equal(
		(second.get_node("Mesh") as Node3D).scale,
	)
	assert_float(first.mass).is_equal(second.mass)


func _spawn_debris(rng: RandomNumberGenerator) -> RigidBody3D:
	var piece: RigidBody3D = auto_free(DEBRIS_SCENE.instantiate())
	(piece.get_node("Look") as DebrisLook).rng = rng
	add_child(piece)
	return piece


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
