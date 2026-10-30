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
	## A Celestial Body level design holds in place: it pulls through Area point gravity
	## ([AnchoredPull]) and is never moved.
	ANCHORED,
}

## The group every [GravityBody] joins.
const GROUP := &"gravity_bodies"

## Whether this body pulls other bodies or is only pulled.
@export var role := Role.CELESTIAL
## The body gravity pulls and pushes. It is the component's own parent, wired in its scene.
@export var body: RigidBody3D
## An Anchored Body's Area point gravity, wired in its scene. Only [constant Role.ANCHORED] uses it.
@export var anchored_pull: AnchoredPull

## The current Gravega multiplier on every pair this body is in. Attract raises it above 1.
var gravega_multiplier := 1.0
## Gravega multipliers on single pairs, keyed by the other body, on top of both bodies'
## own. A Targeted Attract sets one on Rubbley's for the pair with its target.
var pair_multipliers: Dictionary[GravityBody, float] = { }


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	if role == Role.ANCHORED:
		assert(anchored_pull != null, "%s is Anchored but has no AnchoredPull" % body.name)
		# Held in place for good: a static freeze still collides but never moves.
		body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		body.freeze = true
