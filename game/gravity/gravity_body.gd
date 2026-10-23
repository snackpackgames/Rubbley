class_name GravityBody
extends Node
## Makes a [RigidBody3D] take part in gravity (ADR 0016). It joins the
## [code]gravity_bodies[/code] group, which the level's [GravitySystem] reads every tick.
## Mass is read from [member RigidBody3D.mass], never stored here.

## Whether the body pulls as well as being pulled (ADR 0006).
enum Role {
	## Pulls and is pulled: Rubbley, planets, asteroids, large enemies.
	CELESTIAL,
	## Is pulled but pulls nothing: debris, materials, small enemies.
	PASSIVE,
}

## The group every [GravityBody] joins.
const GROUP := &"gravity_bodies"

## Whether this body pulls other bodies or is only pulled.
@export var role := Role.CELESTIAL
## The body gravity pulls and pushes. It is the component's own parent, wired in its scene.
@export var body: RigidBody3D

## The current Gravega multiplier on every pair this body is in. Attract raises it above 1.
var gravega_multiplier := 1.0


func _enter_tree() -> void:
	add_to_group(GROUP)
