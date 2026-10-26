class_name Targetable
extends Node
## Makes a Celestial Body a target for Rubbley's moves (ADRs 0012, 0016). It glows, so
## players know they can target it, and joins the [code]targetable_bodies[/code] group,
## which the targetable-bodies query reads.

## The group every [Targetable] joins.
const GROUP := &"targetable_bodies"

## The body's gravity, whose Gravega multiplier a Targeted Attract raises. Wired in its scene.
@export var gravity_body: GravityBody
## The body's sphere collider, whose radius is the edge the aim measures to.
@export var collider: CollisionShape3D
## The mesh that glows.
@export var glow_mesh: GeometryInstance3D
## The glow, drawn over the mesh's own material.
@export var glow_material: Material


## Returns every targetable body in [param tree], in tree order: the targetable-bodies
## query (ADR 0013).
static func all_in(tree: SceneTree) -> Array[Targetable]:
	var targetables: Array[Targetable] = []
	for node in tree.get_nodes_in_group(GROUP):
		var targetable := node as Targetable
		if targetable != null:
			targetables.append(targetable)
	return targetables


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	assert(gravity_body != null, "%s needs a GravityBody" % name)
	assert(collider != null and collider.shape is SphereShape3D, "%s needs a sphere" % name)
	if glow_mesh != null:
		glow_mesh.material_overlay = glow_material


## Returns the body's global position.
func body_position() -> Vector3:
	return gravity_body.body.global_position


## Returns the body's radius in metres, for picks that measure to its edge.
func radius_m() -> float:
	var sphere := collider.shape as SphereShape3D
	return sphere.radius
