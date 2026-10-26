class_name DebrisField
extends Node3D
## Scatters debris when the level starts. With a [member primary], each piece is
## launched into its own Orbit round it: a random distance, a random way round and a
## random speed multiple, so some circle and some swing out on ellipses or escape.
## Without one, the pieces float in a patch round the field, moving slowly in random
## directions. The pieces fly free afterwards: nothing holds them in Orbit.

## The most a piece starts spinning round Y, either way, in radians per second.
const MAX_SPIN_RAD_PER_S := 1.5

## The debris to scatter.
@export var debris_scene: PackedScene
## The level's gravity, for the primary's pull.
@export var gravity_tuning: GravityTuning
## Seeds the scatter, so a field lays out the same every run (ADR 0018).
@export var scatter_seed := 0
## How many pieces to scatter.
@export_range(1, 200) var count := 8
## The closest a piece starts to the primary, or to the field's centre when floating.
@export_range(0.0, 100.0, 0.1, "or_greater") var min_distance_m := 12.0
## The furthest a piece starts from the primary, or from the field's centre when floating.
@export_range(0.0, 100.0, 0.1, "or_greater") var max_distance_m := 20.0

@export_group("Orbit")
## The Anchored Body the pieces orbit. Unset, they float instead.
@export var primary: RigidBody3D
## The slowest launch, as a multiple of circular speed. Launches are raised as needed to
## keep each Orbit above [member lowest_point_m].
@export_range(0.0, 2.0, 0.01) var min_speed_multiple := 0.9
## The fastest launch, as a multiple of circular speed. From √2 (about 1.41) a piece escapes.
@export_range(0.0, 2.0, 0.01) var max_speed_multiple := 1.1
## The closest any Orbit may come to the primary's centre, clear of its surface.
@export_range(0.0, 100.0, 0.1, "or_greater") var lowest_point_m := 10.0
## The share of pieces that go round anticlockwise seen from above; the rest go clockwise.
@export_range(0.0, 1.0, 0.01) var anticlockwise_share := 1.0

@export_group("Floating")
## The fastest a floating piece starts moving, in metres per second.
@export_range(0.0, 20.0, 0.1, "or_greater") var floating_speed_m_per_s := 1.0


func _ready() -> void:
	assert(debris_scene != null, "%s needs a debris scene" % name)
	assert(primary == null or gravity_tuning != null, "%s needs Gravity Tuning to orbit" % name)
	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_seed
	for i in count:
		var piece := debris_scene.instantiate() as RigidBody3D
		add_child(piece)
		if primary != null:
			_launch_into_orbit(piece, rng)
		else:
			_set_floating(piece, rng)
		var spin := rng.randf_range(-MAX_SPIN_RAD_PER_S, MAX_SPIN_RAD_PER_S)
		piece.angular_velocity = Vector3.UP * spin


func _launch_into_orbit(piece: RigidBody3D, rng: RandomNumberGenerator) -> void:
	var distance := rng.randf_range(min_distance_m, max_distance_m)
	var offset := Vector3.RIGHT.rotated(Vector3.UP, rng.randf() * TAU) * distance
	var slowest := maxf(
		min_speed_multiple,
		OrbitLaunch.slowest_speed_multiple(distance, lowest_point_m),
	)
	var speed_multiple := rng.randf_range(slowest, maxf(slowest, max_speed_multiple))
	var pull_strength := gravity_tuning.gravitational_constant * primary.mass
	piece.global_position = primary.global_position + offset
	piece.linear_velocity = OrbitLaunch.velocity(
		offset,
		pull_strength,
		speed_multiple,
		rng.randf() < anticlockwise_share,
	)


func _set_floating(piece: RigidBody3D, rng: RandomNumberGenerator) -> void:
	# The square root spreads the pieces evenly over the ring's area, not bunched at its centre.
	var share := rng.randf()
	var inner := min_distance_m * min_distance_m
	var outer := max_distance_m * max_distance_m
	var distance := sqrt(lerpf(inner, outer, share))
	var bearing := Vector3.RIGHT.rotated(Vector3.UP, rng.randf() * TAU)
	piece.global_position = global_position + bearing * distance
	var heading := Vector3.RIGHT.rotated(Vector3.UP, rng.randf() * TAU)
	piece.linear_velocity = heading * rng.randf_range(0.0, floating_speed_m_per_s)
