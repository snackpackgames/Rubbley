class_name Stunnable
extends Node
## Makes a body stunnable by a Repel Pulse (ADR 0006). It only keeps time: whatever
## drives the body, such as an enemy's behaviour, asks [method is_stunned] or listens to
## [signal stunned]. Joins the [code]stunnable_bodies[/code] group, which the Pulse reads.

## A stun started or extended, for [param duration_s] seconds from now.
signal stunned(duration_s: float)

## The group every [Stunnable] joins.
const GROUP := &"stunnable_bodies"

## The body a Repel Pulse must reach to stun. Wired in its scene.
@export var body: Node3D

var _remaining_s := 0.0


## Returns every stunnable body in [param tree], in tree order.
static func all_in(tree: SceneTree) -> Array[Stunnable]:
	var stunnables: Array[Stunnable] = []
	for node in tree.get_nodes_in_group(GROUP):
		var stunnable := node as Stunnable
		if stunnable != null:
			stunnables.append(stunnable)
	return stunnables


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	assert(body != null, "%s needs a body" % name)


func _physics_process(delta: float) -> void:
	_remaining_s = maxf(_remaining_s - delta, 0.0)


## Stuns the body for [param duration_s] seconds from now. A stun already running longer
## is left as it is.
func stun(duration_s: float) -> void:
	_remaining_s = maxf(_remaining_s, duration_s)
	stunned.emit(duration_s)


## Whether the body is stunned now.
func is_stunned() -> bool:
	return _remaining_s > 0.0
