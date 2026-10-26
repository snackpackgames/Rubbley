extends GdUnitTestSuite
## A Targetable body glows and is found by the targetable-bodies query (ADRs 0012, 0013),
## on the shipped planet scene.

const PLANET_SCENE := preload("res://game/bodies/planet/planet.tscn")
const RUBBLEY_SCENE := preload("res://game/bodies/rubbley/rubbley.tscn")


## A planet in the tree is found by the query, and Rubbley, who is no target, is not.
func test_the_query_finds_targetable_bodies_only() -> void:
	var world: Node3D = auto_free(Node3D.new())
	add_child(world)
	var planet: PlayPlaneBody = PLANET_SCENE.instantiate()
	world.add_child(planet)
	world.add_child(RUBBLEY_SCENE.instantiate())

	var found := Targetable.all_in(get_tree())
	assert_int(found.size()).is_equal(1)
	assert_object(found[0].gravity_body.body).is_same(planet)
	assert_float(found[0].radius_m()).is_equal(8.0)


## A Targetable planet draws its glow over its own material.
func test_a_targetable_body_glows() -> void:
	var planet: PlayPlaneBody = auto_free(PLANET_SCENE.instantiate())
	add_child(planet)
	var mesh := planet.get_node("Mesh") as MeshInstance3D
	assert_object(mesh.material_overlay).is_not_null()
