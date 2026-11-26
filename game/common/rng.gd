class_name Rng
extends Node
## Distributes a seeded [RandomNumberGenerator] to sibling components on an entity
## (ADRs 0016, 0018). Spawners and levels seed a subtree with [method seed_subtree], and
## each sibling connects to [signal seeded] in its [method Node._ready].

## Emitted once when this node receives its seeded [RandomNumberGenerator].
signal seeded(source: RandomNumberGenerator)

var _seeded := false


## Walks [param root] and its descendants in deterministic tree order, seeding every
## unseeded [Rng] node with [param source].
static func seed_subtree(root: Node, source: RandomNumberGenerator) -> void:
	assert(root != null, "Rng.seed_subtree needs a root node")
	assert(source != null, "Rng.seed_subtree needs a RandomNumberGenerator")
	_seed_node(root, source)


static func _seed_node(node: Node, source: RandomNumberGenerator) -> void:
	var rng := node as Rng
	if rng != null and not rng.is_seeded():
		rng.seed_with(source)
	for child in node.get_children():
		_seed_node(child, source)


## Emits [signal seeded] once with [param source]. Later calls are ignored so an outer
## [method seed_subtree] never re-seeds an entity its own spawner already seeded.
func seed_with(source: RandomNumberGenerator) -> void:
	assert(source != null, "%s needs a RandomNumberGenerator" % name)
	if _seeded:
		return
	_seeded = true
	seeded.emit(source)


## Returns whether this [Rng] has already been seeded.
func is_seeded() -> bool:
	return _seeded
