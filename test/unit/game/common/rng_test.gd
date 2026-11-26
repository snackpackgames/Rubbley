extends GdUnitTestSuite
## [Rng] distributes a seeded [RandomNumberGenerator] to sibling components once and walks
## subtrees in deterministic tree order (ADRs 0016, 0018).


## Calling seed_with emits [signal Rng.seeded] once and ignores later calls.
func test_seed_with_emits_once_and_marks_seeded() -> void:
	var rng: Rng = auto_free(Rng.new())
	var received: Array[RandomNumberGenerator] = []
	rng.seeded.connect(
		func(source: RandomNumberGenerator) -> void:
			received.append(source),
	)

	assert_bool(rng.is_seeded()).is_false()
	var first := _source(1)
	var second := _source(2)
	rng.seed_with(first)
	rng.seed_with(second)

	assert_bool(rng.is_seeded()).is_true()
	assert_int(received.size()).is_equal(1)
	assert_object(received[0]).is_same(first)


## seed_subtree visits unseeded [Rng] nodes in tree order and skips already-seeded ones.
func test_seed_subtree_walks_in_order_and_skips_seeded() -> void:
	var root: Node = auto_free(Node.new())
	var first_branch := Node.new()
	var first_rng := Rng.new()
	first_branch.add_child(first_rng)
	var skipped_branch := Node.new()
	var skipped_rng := Rng.new()
	skipped_branch.add_child(skipped_rng)
	var last_rng := Rng.new()
	root.add_child(first_branch)
	root.add_child(skipped_branch)
	root.add_child(last_rng)

	var order: Array[String] = []
	first_rng.seeded.connect(
		func(_s: RandomNumberGenerator) -> void:
			order.append("first"),
	)
	skipped_rng.seeded.connect(
		func(_s: RandomNumberGenerator) -> void:
			order.append("skipped"),
	)
	last_rng.seeded.connect(
		func(_s: RandomNumberGenerator) -> void:
			order.append("last"),
	)

	skipped_rng.seed_with(_source(10))
	order.clear()

	Rng.seed_subtree(root, _source(20))

	assert_array(order).contains_exactly(["first", "last"])
	assert_bool(first_rng.is_seeded()).is_true()
	assert_bool(skipped_rng.is_seeded()).is_true()
	assert_bool(last_rng.is_seeded()).is_true()


func _source(seed_value: int) -> RandomNumberGenerator:
	var source := RandomNumberGenerator.new()
	source.seed = seed_value
	return source
