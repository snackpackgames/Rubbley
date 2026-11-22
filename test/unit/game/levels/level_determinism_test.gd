extends SimulationTestSuite
## Building the same level twice yields identical Debris shapes, sizes, Masses and starting
## spins for every body (ADR 0018).

const SANDBOX_SCENE := preload("res://game/levels/sandbox_level.tscn")


## Building SandboxLevel twice produces identical Debris meshes, collider shapes, scales,
## Masses, positions, linear velocities and starting spins, as well as identical starting
## spins for placed bodies (Rubbley and planets).
func test_building_the_same_level_twice_is_identical() -> void:
	var first := await _snapshot_sandbox()
	var second := await _snapshot_sandbox()

	assert_int(first.size()).is_greater(10)
	assert_int(second.size()).is_equal(first.size())

	var distinct_debris_masses := { }
	var spinning_planets := 0
	var spinning_debris := 0
	for i in first.size():
		var a := first[i]
		var b := second[i]
		assert_str(a.slot).is_equal(b.slot)
		assert_float(a.mass).is_equal(b.mass)
		assert_vector(a.position).is_equal(b.position)
		assert_vector(a.linear_velocity).is_equal(b.linear_velocity)
		assert_vector(a.angular_velocity).is_equal(b.angular_velocity)
		assert_vector(a.visual_spin).is_equal(b.visual_spin)
		assert_vector(a.mesh_scale).is_equal(b.mesh_scale)
		assert_vector(a.collider_scale).is_equal(b.collider_scale)
		if a.is_debris:
			assert_object(a.mesh).is_same(b.mesh)
			assert_object(a.shape).is_same(b.shape)
			distinct_debris_masses[snappedf(a.mass, 1e-4)] = true
			if not a.angular_velocity.is_zero_approx():
				spinning_debris += 1
		elif a.is_frozen and not a.visual_spin.is_zero_approx():
			spinning_planets += 1

	assert_int(distinct_debris_masses.size()).is_greater(1)
	assert_int(spinning_debris).is_greater(0)
	assert_int(spinning_planets).is_greater(0)


func _snapshot_sandbox() -> Array[_BodySnapshot]:
	var level: Node3D = SANDBOX_SCENE.instantiate()
	add_child(level)
	await get_tree().process_frame
	var snapshots: Array[_BodySnapshot] = []
	_collect_bodies(level, level, snapshots)
	remove_child(level)
	level.free()
	return snapshots


func _collect_bodies(root: Node, node: Node, out: Array[_BodySnapshot]) -> void:
	var body := node as PlayPlaneBody
	if body != null:
		var snap := _BodySnapshot.new()
		var parent_path := String(root.get_path_to(body.get_parent()))
		snap.slot = "%s#%d" % [parent_path, body.get_index()]
		snap.mass = body.mass
		snap.position = body.position
		snap.linear_velocity = body.linear_velocity
		snap.angular_velocity = body.angular_velocity
		snap.visual_spin = body.visual_spin()
		snap.is_frozen = body.freeze
		snap.is_debris = body.is_in_group("debris")
		var mesh_node := body.get_node_or_null("Mesh") as MeshInstance3D
		if mesh_node != null:
			snap.mesh = mesh_node.mesh
			snap.mesh_scale = mesh_node.scale
		var collider_node := body.get_node_or_null("Collider") as CollisionShape3D
		if collider_node != null:
			snap.shape = collider_node.shape
			snap.collider_scale = collider_node.scale
		out.append(snap)
	for child in node.get_children():
		_collect_bodies(root, child, out)


class _BodySnapshot:
	var slot := ""
	var mass := 0.0
	var position := Vector3.ZERO
	var linear_velocity := Vector3.ZERO
	var angular_velocity := Vector3.ZERO
	var visual_spin := Vector3.ZERO
	var is_frozen := false
	var is_debris := false
	var mesh: Mesh
	var shape: Shape3D
	var mesh_scale := Vector3.ONE
	var collider_scale := Vector3.ONE
