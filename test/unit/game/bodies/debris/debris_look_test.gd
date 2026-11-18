extends GdUnitTestSuite
## The shipped debris scene: each piece takes one of a few shared chipped rocks at random,
## and collides as the rock it shows.

const DEBRIS_SCENE := preload("res://game/bodies/debris/debris.tscn")


## A piece shows a chipped rock and collides as that same rock.
func test_a_piece_collides_as_the_rock_it_shows() -> void:
	var piece: Node3D = auto_free(DEBRIS_SCENE.instantiate())
	add_child(piece)
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


## Pieces don't all look alike: twenty of them show more than one rock.
func test_pieces_are_varied() -> void:
	var meshes := { }
	for i in 20:
		var piece: Node3D = auto_free(DEBRIS_SCENE.instantiate())
		add_child(piece)
		meshes[(piece.get_node("Mesh") as MeshInstance3D).mesh] = true
	assert_int(meshes.size()).is_greater(1)
