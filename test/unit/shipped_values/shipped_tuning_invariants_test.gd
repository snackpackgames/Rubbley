extends GdUnitTestSuite
## Invariants over every shipped Stats, Tuning and Stat Modifier [code].tres[/code] under
## [code]game/[/code] (ADRs 0017, 0018). Discovers files dynamically so a newly added or
## retuned resource can never slip past CI.

const GAME_DIR := "res://game"
const MIN_ATTRACT_S := 1.0


## Every shipped Stats, Tuning and Stat Modifier .tres under game/ satisfies its bounds,
## min < max rules, positive speed caps, Capture Radius inside max range, rising
## Mass→size curve, Stamina coverage, trigger release below press, and valid modifier ids.
func test_every_shipped_tuning_stats_and_modifier_satisfies_invariants() -> void:
	var paths := _find_tres_files(GAME_DIR)
	assert_int(paths.size()).is_greater(0)

	var body_tunings: Array[BodyTuning] = []
	var gravity_tunings: Array[GravityTuning] = []
	var stats_count := 0
	var checked_count := 0

	for path in paths:
		var res := ResourceLoader.load(path)
		assert_object(res).override_failure_message("Failed to load %s" % path).is_not_null()
		if res == null:
			continue
		if res is RubbleyStats:
			_check_rubbley_stats(res as RubbleyStats, path)
			stats_count += 1
			checked_count += 1
		elif res is BodyTuning:
			var bt := res as BodyTuning
			_check_body_tuning(bt, path)
			body_tunings.append(bt)
			checked_count += 1
		elif res is GravityTuning:
			var gt := res as GravityTuning
			_check_gravity_tuning(gt, path)
			gravity_tunings.append(gt)
			checked_count += 1
		elif res is CameraTuning:
			_check_camera_tuning(res as CameraTuning, path)
			checked_count += 1
		elif res is CameraZoneFraming:
			_check_camera_zone_framing(res as CameraZoneFraming, path)
			checked_count += 1
		elif res is SpinTuning:
			_check_spin_tuning(res as SpinTuning, path)
			checked_count += 1
		elif res is CollisionDamageTuning:
			_check_collision_damage_tuning(res as CollisionDamageTuning, path)
			checked_count += 1
		elif res is ChippedRockTuning:
			_check_chipped_rock_tuning(res as ChippedRockTuning, path)
			checked_count += 1
		elif res is AbsorbPopTuning:
			_check_absorb_pop_tuning(res as AbsorbPopTuning, path)
			checked_count += 1
		elif res is HitFlashTuning:
			_check_hit_flash_tuning(res as HitFlashTuning, path)
			checked_count += 1
		elif res is RepelCueTuning:
			_check_repel_cue_tuning(res as RepelCueTuning, path)
			checked_count += 1
		elif res is AttractCueTuning:
			_check_attract_cue_tuning(res as AttractCueTuning, path)
			checked_count += 1
		elif res is InputTuning:
			_check_input_tuning(res as InputTuning, path)
			checked_count += 1
		elif res is AimCursorTuning:
			_check_aim_cursor_tuning(res as AimCursorTuning, path)
			checked_count += 1
		elif res is TouchReticleTuning:
			_check_touch_reticle_tuning(res as TouchReticleTuning, path)
			checked_count += 1
		elif res is StatModifier:
			_check_stat_modifier(res as StatModifier, path)
			checked_count += 1
		else:
			# Guard against adding a new *Tuning / *Stats / *Modifier resource without invariants.
			var raw_script: Variant = res.get_script()
			var name_str := ""
			if raw_script is Script:
				var script: Script = raw_script
				name_str = String(script.get_global_name())
			var is_unhandled := (
				name_str.ends_with("Tuning") or name_str.ends_with("Stats")
				or name_str.ends_with("Modifier")
			)
			var msg := "Unhandled shipped resource class %s at %s" % [name_str, path]
			assert_bool(is_unhandled).override_failure_message(msg).is_false()

	assert_int(stats_count).is_greater_equal(1)
	assert_int(body_tunings.size()).is_greater_equal(3)
	assert_int(gravity_tunings.size()).is_greater_equal(1)
	assert_int(checked_count).is_greater_equal(15)

	# Cross-resource invariant: every primary's Capture Radius stays strictly inside max range.
	var primary_count := 0
	var capturable_count := 0
	for bt in body_tunings:
		if bt.capturable:
			capturable_count += 1
		if bt.capture_radius_m > 0.0:
			primary_count += 1
			for gt in gravity_tunings:
				var msg := "%s capture_radius_m must be < %s max_range_m" % [
					bt.resource_path,
					gt.resource_path,
				]
				assert_float(bt.capture_radius_m).override_failure_message(msg).is_less(
					gt.max_range_m,
				)
	assert_int(primary_count).is_greater_equal(1)
	assert_int(capturable_count).is_greater_equal(1)


## Every value of [enum RubbleyStats.Stat] maps bijectively to one float field in
## [RubbleyStatsBuilder] when folded onto the shipped Rubbley Stats resource.
func test_every_stat_enum_is_handled_by_the_fold() -> void:
	var shipped := preload("res://game/bodies/rubbley/rubbley_stats.tres") as RubbleyStats
	var fields := _float_fields(shipped)
	var seen_fields: Dictionary[StringName, bool] = { }
	for stat_val: int in RubbleyStats.Stat.values():
		var mod := StatModifier.new()
		mod.stat = stat_val as RubbleyStats.Stat
		mod.operation = StatModifier.Operation.ADD
		mod.value = 1.0
		var effective := RubbleyStatsBuilder.build(shipped, [mod])
		var changed: Array[StringName] = []
		for field in fields:
			var before_val: float = shipped.get(field)
			var after_val: float = effective.get(field)
			if not is_equal_approx(before_val, after_val):
				changed.append(field)
		var key_name := str(RubbleyStats.Stat.find_key(stat_val))
		var msg := "Stat %s changed %s (expected 1 field)" % [key_name, changed]
		assert_int(changed.size()).override_failure_message(msg).is_equal(1)
		if changed.size() == 1:
			var dup_msg := "Stat %s maps to already-mapped field %s" % [key_name, changed[0]]
			assert_bool(seen_fields.has(changed[0])).override_failure_message(dup_msg).is_false()
			seen_fields[changed[0]] = true
	assert_int(seen_fields.size()).is_equal(fields.size())


func _check_rubbley_stats(stats: RubbleyStats, path: String) -> void:
	assert_float(stats.min_mass_kg).override_failure_message(path).is_greater(0.0)
	assert_float(stats.min_mass_kg).override_failure_message(path).is_less(stats.max_mass_kg)
	assert_float(stats.starting_mass_kg).override_failure_message(path).is_between(
		stats.min_mass_kg,
		stats.max_mass_kg,
	)
	var curve := stats.mass_to_radius_m
	assert_object(curve).override_failure_message(path).is_not_null()
	if curve != null:
		assert_float(curve.min_domain).override_failure_message(path).is_less_equal(
			stats.min_mass_kg,
		)
		assert_float(curve.max_domain).override_failure_message(path).is_greater_equal(
			stats.max_mass_kg,
		)
		assert_float(curve.sample(stats.min_mass_kg)).override_failure_message(path).is_greater(0.0)
		var previous := -INF
		for i in 101:
			var mass_kg := lerpf(stats.min_mass_kg, stats.max_mass_kg, float(i) / 100.0)
			var radius_m := curve.sample(mass_kg)
			assert_float(radius_m).override_failure_message(path).is_greater_equal(previous)
			previous = radius_m
		assert_float(curve.sample(stats.max_mass_kg)).override_failure_message(path).is_greater(
			curve.sample(stats.min_mass_kg),
		)

	assert_float(stats.stamina_max).override_failure_message(path).is_greater(0.0)
	assert_float(stats.stamina_regen_per_second).override_failure_message(path).is_greater(0.0)
	assert_float(stats.stamina_regen_delay_s).override_failure_message(path).is_greater_equal(0.0)
	assert_float(stats.gravity_well_cost).override_failure_message(path).is_greater_equal(0.0)
	assert_float(stats.repel_pulse_cost).override_failure_message(path).is_greater_equal(0.0)
	assert_float(stats.repel_cost).override_failure_message(path).is_greater_equal(0.0)
	assert_float(stats.spin_cost).override_failure_message(path).is_greater_equal(0.0)
	assert_float(stats.stamina_max).override_failure_message(path).is_greater_equal(
		stats.gravity_well_cost,
	)
	assert_float(stats.stamina_max).override_failure_message(path).is_greater_equal(
		stats.repel_pulse_cost,
	)
	assert_float(stats.stamina_max).override_failure_message(path).is_greater_equal(
		stats.repel_cost,
	)
	assert_float(stats.stamina_max).override_failure_message(path).is_greater_equal(stats.spin_cost)
	assert_float(stats.attract_self_drain_per_second).override_failure_message(path).is_greater(0.0)
	assert_float(stats.attract_celestial_drain_per_second).override_failure_message(path) \
			.is_greater(0.0)
	if stats.attract_self_drain_per_second > 0.0:
		assert_float(stats.stamina_max / stats.attract_self_drain_per_second) \
				.override_failure_message(path) \
				.is_greater_equal(MIN_ATTRACT_S)
	if stats.attract_celestial_drain_per_second > 0.0:
		assert_float(stats.stamina_max / stats.attract_celestial_drain_per_second) \
				.override_failure_message(path) \
				.is_greater_equal(MIN_ATTRACT_S)
	assert_float(stats.attract_celestial_drain_per_second).override_failure_message(path).is_less(
		stats.attract_self_drain_per_second,
	)
	assert_float(stats.attract_self_multiplier).override_failure_message(path).is_greater(1.0)
	assert_float(stats.attract_celestial_multiplier).override_failure_message(path).is_greater(1.0)
	assert_float(stats.gravity_well_strength_m_per_s2).override_failure_message(path).is_greater(
		0.0,
	)
	assert_float(stats.gravity_well_radius_m).override_failure_message(path).is_greater(0.0)
	assert_float(stats.gravity_well_duration_s).override_failure_message(path).is_greater(0.0)
	assert_float(stats.gravity_well_fade_s).override_failure_message(path).is_greater_equal(0.0)
	assert_float(stats.repel_pulse_speed_m_per_s).override_failure_message(path).is_greater(0.0)
	assert_float(stats.repel_pulse_radius_m).override_failure_message(path).is_greater(0.0)
	assert_float(stats.repel_pulse_stun_s).override_failure_message(path).is_greater(0.0)
	assert_float(stats.gravity_ripple_speed_m_per_s).override_failure_message(path).is_greater(0.0)
	assert_float(stats.gravity_ripple_radius_m).override_failure_message(path).is_greater(0.0)
	assert_float(stats.gravity_ripple_speed_m_per_s).override_failure_message(path).is_less(
		stats.repel_pulse_speed_m_per_s,
	)
	assert_float(stats.radial_repel_reference_mass_kg).override_failure_message(path).is_greater(
		0.0,
	)
	assert_float(stats.radial_repel_mass_falloff).override_failure_message(path).is_greater_equal(
		0.0,
	)
	assert_float(stats.targeted_repel_impulse_n_s).override_failure_message(path).is_greater(0.0)


func _check_body_tuning(tuning: BodyTuning, path: String) -> void:
	assert_float(tuning.speed_cap_m_per_s).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.linear_damp_per_second).override_failure_message(path).is_greater_equal(0.0)
	assert_float(tuning.angular_damp_per_second).override_failure_message(path).is_greater_equal(
		0.0,
	)
	assert_float(tuning.min_starting_spin_rad_per_s).override_failure_message(path) \
			.is_greater_equal(0.0)
	assert_float(tuning.min_starting_spin_rad_per_s).override_failure_message(path).is_less_equal(
		tuning.max_starting_spin_rad_per_s,
	)
	assert_float(tuning.capture_radius_m).override_failure_message(path).is_greater_equal(0.0)


func _check_gravity_tuning(tuning: GravityTuning, path: String) -> void:
	assert_float(tuning.gravitational_constant).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.softening_m).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.max_range_m).override_failure_message(path).is_greater(tuning.softening_m)
	assert_float(tuning.drift_speed_m_per_s).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.orbit_radius_multiple).override_failure_message(path).is_greater(1.0)
	assert_float(tuning.orbit_radius_band).override_failure_message(path).is_greater(1.0)
	assert_float(tuning.orbit_travel_deg).override_failure_message(path).is_greater_equal(360.0)
	assert_float(tuning.capture_assist_rate_per_second).override_failure_message(path).is_greater(
		0.0,
	)
	assert_float(tuning.capture_speed_multiple).override_failure_message(path).is_between(
		0.1,
		sqrt(2.0),
	)


func _check_camera_tuning(tuning: CameraTuning, path: String) -> void:
	assert_float(tuning.min_extent_m).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.min_extent_m).override_failure_message(path).is_less(tuning.max_extent_m)
	assert_float(tuning.max_extent_m).override_failure_message(path).is_less_equal(1000.0)
	assert_float(tuning.nudge_radius).override_failure_message(path).is_greater_equal(0.0)
	assert_float(tuning.nudge_radius).override_failure_message(path).is_less_equal(
		tuning.max_offset,
	)
	assert_float(tuning.max_offset).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.max_offset).override_failure_message(path).is_less(0.5)
	assert_float(tuning.follow_half_life_s).override_failure_message(path).is_greater_equal(0.0)
	assert_float(tuning.nudge_half_life_s).override_failure_message(path).is_greater_equal(0.0)
	assert_float(tuning.zoom_half_life_s).override_failure_message(path).is_greater_equal(0.0)
	assert_float(tuning.fov_deg).override_failure_message(path).is_between(30.0, 40.0)
	assert_float(tuning.rubbley_screen_fraction).override_failure_message(path).is_between(
		0.001,
		0.5,
	)
	assert_float(tuning.reference_radius_m).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.size_zoom_exponent).override_failure_message(path).is_between(0.0, 1.0)
	assert_float(tuning.shake_full_hit_kg).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.shake_decay_per_s).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.shake_frequency_hz).override_failure_message(path).is_greater(0.0)


func _check_camera_zone_framing(framing: CameraZoneFraming, path: String) -> void:
	assert_float(framing.extent_m).override_failure_message(path).is_between(1.0, 1000.0)


func _check_spin_tuning(tuning: SpinTuning, path: String) -> void:
	assert_float(tuning.shield_reach_m).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.duration_s).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.lockout_s).override_failure_message(path).is_greater_equal(0.0)
	assert_float(tuning.perfect_window_s).override_failure_message(path).is_between(
		0.001,
		tuning.duration_s,
	)
	assert_float(tuning.restitution).override_failure_message(path).is_greater_equal(0.0)


func _check_collision_damage_tuning(tuning: CollisionDamageTuning, path: String) -> void:
	assert_float(tuning.safe_impulse_n_s).override_failure_message(path).is_greater_equal(0.0)
	assert_float(tuning.mass_lost_kg_per_n_s).override_failure_message(path).is_greater(0.0)


func _check_chipped_rock_tuning(tuning: ChippedRockTuning, path: String) -> void:
	assert_float(tuning.width_m).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.chip).override_failure_message(path).is_between(0.0, 0.9)
	assert_float(tuning.max_stretch).override_failure_message(path).is_between(0.0, 0.9)
	assert_float(tuning.min_size).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.min_size).override_failure_message(path).is_less(tuning.max_size)
	assert_int(tuning.shapes).override_failure_message(path).is_greater_equal(1)


func _check_absorb_pop_tuning(tuning: AbsorbPopTuning, path: String) -> void:
	assert_float(tuning.swell).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.duration_s).override_failure_message(path).is_greater(0.0)


func _check_hit_flash_tuning(tuning: HitFlashTuning, path: String) -> void:
	assert_float(tuning.duration_s).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.color.a).override_failure_message(path).is_between(0.01, 1.0)


func _check_repel_cue_tuning(tuning: RepelCueTuning, path: String) -> void:
	assert_float(tuning.duration_s).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.width_m).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.targeted_growth).override_failure_message(path).is_greater_equal(0.0)


func _check_attract_cue_tuning(tuning: AttractCueTuning, path: String) -> void:
	assert_float(tuning.pulse_period_s).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.self_reach).override_failure_message(path).is_greater(1.0)
	assert_int(tuning.ring_count).override_failure_message(path).is_greater_equal(1)
	assert_float(tuning.widest_ring).override_failure_message(path).is_between(0.001, 0.5)
	assert_float(tuning.max_opacity).override_failure_message(path).is_between(0.01, 1.0)
	assert_float(tuning.tether_width_m).override_failure_message(path).is_greater(0.0)


func _check_input_tuning(tuning: InputTuning, path: String) -> void:
	assert_float(tuning.trigger_release_point).override_failure_message(path).is_less(
		tuning.trigger_press_point,
	)
	assert_float(tuning.trigger_release_point).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.trigger_press_point).override_failure_message(path).is_less(1.0)
	assert_float(tuning.stick_deadzone).override_failure_message(path).is_greater_equal(0.0)
	assert_float(tuning.stick_deadzone).override_failure_message(path).is_less(
		tuning.stick_saturation,
	)
	assert_float(tuning.stick_saturation).override_failure_message(path).is_less_equal(1.0)
	assert_float(tuning.full_tilt).override_failure_message(path).is_between(0.0, 1.0)
	assert_float(tuning.aim_range).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.aim_snap_radius).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.reach_range_multiple).override_failure_message(path).is_greater_equal(1.0)
	assert_float(tuning.reach_hysteresis_deg).override_failure_message(path).is_greater_equal(0.0)
	assert_float(tuning.nudge_deadzone).override_failure_message(path).is_between(0.01, 0.99)
	assert_float(tuning.swipe_distance).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.swipe_speed_per_s).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.pinch_distance).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.nudge_distance).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.nudge_distance).override_failure_message(path).is_less(
		tuning.nudge_full_drag,
	)
	assert_float(tuning.touch_hit_radius).override_failure_message(path).is_greater(0.0)


func _check_aim_cursor_tuning(tuning: AimCursorTuning, path: String) -> void:
	assert_float(tuning.radius_px).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.width_px).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.crosshair_px).override_failure_message(path).is_greater_equal(0.0)
	assert_float(tuning.idle_hold_s).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.fade_out_s).override_failure_message(path).is_greater_equal(0.0)


func _check_touch_reticle_tuning(tuning: TouchReticleTuning, path: String) -> void:
	assert_float(tuning.width_px).override_failure_message(path).is_greater(0.0)
	assert_float(tuning.dot_radius_px).override_failure_message(path).is_greater_equal(0.0)


func _check_stat_modifier(mod: StatModifier, path: String) -> void:
	assert_bool(RubbleyStats.Stat.values().has(mod.stat)).override_failure_message(path).is_true()
	assert_bool(StatModifier.Operation.values().has(mod.operation)) \
			.override_failure_message(path) \
			.is_true()
	assert_bool(is_finite(mod.value)).override_failure_message(path).is_true()
	assert_bool(is_finite(mod.duration_s)).override_failure_message(path).is_true()
	assert_float(mod.duration_s).override_failure_message(path).is_greater_equal(0.0)
	if mod.operation == StatModifier.Operation.MULTIPLY:
		assert_float(mod.value).override_failure_message(path).is_greater_equal(0.0)


func _find_tres_files(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			var full := "%s/%s" % [dir_path, entry]
			if dir.current_is_dir():
				found.append_array(_find_tres_files(full))
			elif entry.ends_with(".tres"):
				found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	found.sort()
	return found


func _float_fields(stats: RubbleyStats) -> Array[StringName]:
	var fields: Array[StringName] = []
	for property in stats.get_property_list():
		var usage: int = property[&"usage"]
		if property[&"type"] == TYPE_FLOAT and usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(property[&"name"])
	return fields
