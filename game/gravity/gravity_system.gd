class_name GravitySystem
extends Node
## A level's gravity (ADR 0016). Every physics tick it reads the
## [code]gravity_bodies[/code] group in tree order, adds up its force contributors
## (the pairwise [GravitySolver], then [CaptureAssist], then [Drift]) and applies the
## sum to each body once. Anchored Bodies pull through their [AnchoredPull] instead,
## which it sets every tick.

## Runs after gameplay's physics tick, so this tick's Gravega multipliers apply this tick.
const PHYSICS_PRIORITY := 100

## How gravity and Drift behave in this level.
@export var tuning: GravityTuning
## The body Drift carries along the stage, normally Rubbley. Nothing drifts when unset.
@export var drift_body: GravityBody
## The way Drift carries [member drift_body], on the Play Plane.
@export var drift_direction := Vector3.RIGHT

var _solver: GravitySolver
var _capture_assist: CaptureAssist
var _drift: Drift


func _ready() -> void:
	assert(tuning != null, "GravitySystem needs a GravityTuning")
	process_physics_priority = PHYSICS_PRIORITY
	_solver = GravitySolver.new(tuning)
	_capture_assist = CaptureAssist.new(tuning)
	_drift = Drift.new(tuning)


func _physics_process(delta: float) -> void:
	var gravity_bodies: Array[GravityBody] = []
	for node in get_tree().get_nodes_in_group(GravityBody.GROUP):
		var gravity_body := node as GravityBody
		if gravity_body != null and gravity_body.body != null:
			gravity_bodies.append(gravity_body)

	var count := gravity_bodies.size()
	var positions := PackedVector3Array()
	var masses := PackedFloat64Array()
	var roles := PackedInt32Array()
	var multipliers := PackedFloat64Array()
	var velocities := PackedVector3Array()
	var linear_damps := PackedFloat64Array()
	var capture_radii := PackedFloat64Array()
	var capturable: Array[bool] = []
	positions.resize(count)
	masses.resize(count)
	roles.resize(count)
	multipliers.resize(count)
	velocities.resize(count)
	linear_damps.resize(count)
	capture_radii.resize(count)
	capturable.resize(count)
	for i in count:
		var gravity_body := gravity_bodies[i]
		var body := gravity_body.body
		positions[i] = body.global_position
		masses[i] = body.mass
		roles[i] = gravity_body.role
		multipliers[i] = gravity_body.gravega_multiplier
		velocities[i] = body.linear_velocity
		linear_damps[i] = body.linear_damp
		var play_plane_body := body as PlayPlaneBody
		if play_plane_body != null:
			capture_radii[i] = play_plane_body.tuning.capture_radius_m
			capturable[i] = play_plane_body.tuning.capturable
		if gravity_body.role == GravityBody.Role.ANCHORED and gravity_body.anchored_pull != null:
			gravity_body.anchored_pull.pull(
				tuning.gravitational_constant * masses[i] * multipliers[i],
				tuning.max_range_m,
			)

	var pair_multipliers := _pair_multipliers(gravity_bodies)
	var totals := _solver.forces(positions, masses, roles, multipliers, pair_multipliers)
	var capture := _capture_assist.forces(
		positions,
		velocities,
		masses,
		roles,
		multipliers,
		linear_damps,
		capture_radii,
		capturable,
		pair_multipliers,
	)
	var drifting_index := gravity_bodies.find(drift_body)
	var drifting_mass := masses[drifting_index] if drifting_index >= 0 else 0.0
	var drifting_damp := linear_damps[drifting_index] if drifting_index >= 0 else 0.0
	var drift := _drift.forces(
		count,
		drifting_index,
		drift_direction,
		drifting_mass,
		drifting_damp,
		delta,
	)
	for i in count:
		var force := totals[i] + capture[i] + drift[i]
		if force != Vector3.ZERO:
			gravity_bodies[i].body.apply_central_force(force)


# Every body's pair multipliers, keyed by the pair's indices in [param gravity_bodies],
# lower first. A pair both bodies multiply takes the product.
func _pair_multipliers(gravity_bodies: Array[GravityBody]) -> Dictionary[Vector2i, float]:
	var pairs: Dictionary[Vector2i, float] = { }
	for i in gravity_bodies.size():
		# A Variant, as a body freed this tick is still a key until its pair is let go.
		for other: Variant in gravity_bodies[i].pair_multipliers:
			if not is_instance_valid(other):
				continue
			var j := gravity_bodies.find(other)
			if j < 0 or j == i:
				continue
			var pair := Vector2i(mini(i, j), maxi(i, j))
			pairs[pair] = pairs.get(pair, 1.0) * gravity_bodies[i].pair_multipliers[other]
	return pairs
