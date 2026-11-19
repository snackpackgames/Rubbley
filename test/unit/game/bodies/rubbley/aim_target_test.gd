extends GdUnitTestSuite
## What is under the aim when a move starts (ADR 0012): Rubbley, a glowing Celestial
## Body, or empty space.

const RUBBLEY_AT := Vector3(10, 0, 0)
const RUBBLEY_RADIUS_M := 1.0
# Two glowing bodies: a big one north of Rubbley and a small one east of it.
const BODY_POSITIONS: PackedVector3Array = [Vector3(10, 0, -20), Vector3(30, 0, 0)]
const BODY_RADII: PackedFloat64Array = [8.0, 2.0]


## An aim inside Rubbley picks Rubbley.
func test_an_aim_on_rubbley_picks_rubbley() -> void:
	var target := _resolve(Vector3(10.5, 0, 0.5))
	assert_int(target.kind).is_equal(AimTarget.Kind.RUBBLEY)


## An aim inside a glowing body picks that body.
func test_an_aim_on_a_body_picks_it() -> void:
	var target := _resolve(Vector3(31, 0, 1))
	assert_int(target.kind).is_equal(AimTarget.Kind.CELESTIAL_BODY)
	assert_int(target.body_index).is_equal(1)


## Rubbley wins a tie with a body that overlaps him.
func test_rubbley_wins_ties() -> void:
	var positions: PackedVector3Array = [Vector3(11, 0, 0)]
	var radii: PackedFloat64Array = [3.0]
	var target := AimTarget.resolve(RUBBLEY_AT, RUBBLEY_AT, RUBBLEY_RADIUS_M, positions, radii)
	assert_int(target.kind).is_equal(AimTarget.Kind.RUBBLEY)


## Inside two overlapping bodies, the aim picks the one whose edge it is deepest behind.
func test_overlapping_bodies_pick_the_deepest() -> void:
	var positions: PackedVector3Array = [Vector3(0, 0, 0), Vector3(5, 0, 0)]
	var radii: PackedFloat64Array = [10.0, 2.0]
	# 4 m inside the big body's edge, 1.5 m inside the small one's.
	var target := AimTarget.resolve(Vector3(5.5, 0, 0), RUBBLEY_AT * 3.0, 1.0, positions, radii)
	assert_int(target.body_index).is_equal(0)


## An aim on nothing is empty space, where Attract places a Gravity Well.
func test_an_aim_on_nothing_is_empty_space() -> void:
	var target := _resolve(Vector3(20, 0, 5))
	assert_int(target.kind).is_equal(AimTarget.Kind.EMPTY_SPACE)
	assert_int(target.body_index).is_equal(-1)


## Distances are measured on the Play Plane, whatever the height.
func test_height_is_ignored() -> void:
	var target := _resolve(Vector3(10, 50, 0))
	assert_int(target.kind).is_equal(AimTarget.Kind.RUBBLEY)


## A forgiving hit radius picks Rubbley from just outside him.
func test_a_hit_radius_reaches_rubbley() -> void:
	var aim := Vector3(11.5, 0, 0)
	var precise := _resolve(aim)
	var forgiving := AimTarget.resolve(
		aim,
		RUBBLEY_AT,
		RUBBLEY_RADIUS_M,
		BODY_POSITIONS,
		BODY_RADII,
		1.0,
	)
	assert_int(precise.kind).is_equal(AimTarget.Kind.EMPTY_SPACE)
	assert_int(forgiving.kind).is_equal(AimTarget.Kind.RUBBLEY)


## A forgiving hit radius picks a glowing body from just past its edge.
func test_a_hit_radius_reaches_a_body() -> void:
	# 1 m past the small body's edge.
	var target := AimTarget.resolve(
		Vector3(33, 0, 0),
		RUBBLEY_AT,
		RUBBLEY_RADIUS_M,
		BODY_POSITIONS,
		BODY_RADII,
		1.5,
	)
	assert_int(target.kind).is_equal(AimTarget.Kind.CELESTIAL_BODY)
	assert_int(target.body_index).is_equal(1)


## When the hit radius reaches both Rubbley and a body, and the aim is inside neither,
## Rubbley wins the tie.
func test_rubbley_wins_ties_inside_the_hit_radius() -> void:
	var positions: PackedVector3Array = [Vector3(15, 0, 0)]
	var radii: PackedFloat64Array = [2.0]
	# 1.5 m outside Rubbley, 1.5 m outside the body.
	var aim := Vector3(11.5 + 1.0, 0, 0)
	var target := AimTarget.resolve(aim, RUBBLEY_AT, RUBBLEY_RADIUS_M, positions, radii, 2.0)
	assert_int(target.kind).is_equal(AimTarget.Kind.RUBBLEY)


## An aim squarely inside a body picks it over Rubbley, who is only within the hit radius.
func test_an_aim_inside_a_body_beats_a_forgiven_rubbley() -> void:
	var positions: PackedVector3Array = [Vector3(14, 0, 0)]
	var radii: PackedFloat64Array = [2.0]
	# Inside the body, 1.5 m outside Rubbley.
	var aim := Vector3(12.5, 0, 0)
	var target := AimTarget.resolve(aim, RUBBLEY_AT, RUBBLEY_RADIUS_M, positions, radii, 2.0)
	assert_int(target.kind).is_equal(AimTarget.Kind.CELESTIAL_BODY)


func _resolve(aim: Vector3) -> AimTarget:
	return AimTarget.resolve(aim, RUBBLEY_AT, RUBBLEY_RADIUS_M, BODY_POSITIONS, BODY_RADII)
