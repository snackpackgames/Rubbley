class_name RubbleyStatsBuilder
extends RefCounted
## Builds the Stats Rubbley actually plays with (ADR 0017): his base Stats with every
## active [StatModifier] folded over a copy, all adds first, then all multiplies, and no
## Stat taken below zero. Rerun whenever a modifier is added or expires; the base is never
## written.


## Returns a new [RubbleyStats]: [param base] with [param modifiers] applied, adds before
## multiplies.
static func build(base: RubbleyStats, modifiers: Array[StatModifier]) -> RubbleyStats:
	var effective := base.duplicate() as RubbleyStats
	_apply_all(effective, modifiers, StatModifier.Operation.ADD)
	_apply_all(effective, modifiers, StatModifier.Operation.MULTIPLY)
	return effective


# Applies each of [param modifiers] whose operation is [param operation] to [param stats].
static func _apply_all(
	stats: RubbleyStats,
	modifiers: Array[StatModifier],
	operation: StatModifier.Operation,
) -> void:
	for modifier in modifiers:
		if modifier.operation == operation:
			_apply(stats, modifier)


# Applies [param modifier] to its Stat on [param stats].
static func _apply(stats: RubbleyStats, modifier: StatModifier) -> void:
	match modifier.stat:
		RubbleyStats.Stat.STAMINA_MAX:
			stats.stamina_max = _changed(stats.stamina_max, modifier)
		RubbleyStats.Stat.STAMINA_REGEN_PER_SECOND:
			stats.stamina_regen_per_second = _changed(stats.stamina_regen_per_second, modifier)
		RubbleyStats.Stat.STAMINA_REGEN_DELAY_S:
			stats.stamina_regen_delay_s = _changed(stats.stamina_regen_delay_s, modifier)
		RubbleyStats.Stat.ATTRACT_SELF_DRAIN_PER_SECOND:
			stats.attract_self_drain_per_second = _changed(
				stats.attract_self_drain_per_second,
				modifier,
			)
		RubbleyStats.Stat.ATTRACT_CELESTIAL_DRAIN_PER_SECOND:
			stats.attract_celestial_drain_per_second = _changed(
				stats.attract_celestial_drain_per_second,
				modifier,
			)
		RubbleyStats.Stat.GRAVITY_WELL_COST:
			stats.gravity_well_cost = _changed(stats.gravity_well_cost, modifier)
		RubbleyStats.Stat.REPEL_COST:
			stats.repel_cost = _changed(stats.repel_cost, modifier)
		RubbleyStats.Stat.REPEL_PULSE_COST:
			stats.repel_pulse_cost = _changed(stats.repel_pulse_cost, modifier)
		RubbleyStats.Stat.SPIN_COST:
			stats.spin_cost = _changed(stats.spin_cost, modifier)
		RubbleyStats.Stat.ATTRACT_SELF_MULTIPLIER:
			stats.attract_self_multiplier = _changed(stats.attract_self_multiplier, modifier)
		RubbleyStats.Stat.ATTRACT_CELESTIAL_MULTIPLIER:
			stats.attract_celestial_multiplier = _changed(
				stats.attract_celestial_multiplier,
				modifier,
			)
		RubbleyStats.Stat.GRAVITY_WELL_STRENGTH_M_PER_S2:
			stats.gravity_well_strength_m_per_s2 = _changed(
				stats.gravity_well_strength_m_per_s2,
				modifier,
			)
		RubbleyStats.Stat.GRAVITY_WELL_RADIUS_M:
			stats.gravity_well_radius_m = _changed(stats.gravity_well_radius_m, modifier)
		RubbleyStats.Stat.GRAVITY_WELL_DURATION_S:
			stats.gravity_well_duration_s = _changed(stats.gravity_well_duration_s, modifier)
		RubbleyStats.Stat.GRAVITY_WELL_FADE_S:
			stats.gravity_well_fade_s = _changed(stats.gravity_well_fade_s, modifier)
		RubbleyStats.Stat.REPEL_PULSE_SPEED_M_PER_S:
			stats.repel_pulse_speed_m_per_s = _changed(stats.repel_pulse_speed_m_per_s, modifier)
		RubbleyStats.Stat.REPEL_PULSE_RADIUS_M:
			stats.repel_pulse_radius_m = _changed(stats.repel_pulse_radius_m, modifier)
		RubbleyStats.Stat.REPEL_PULSE_STUN_S:
			stats.repel_pulse_stun_s = _changed(stats.repel_pulse_stun_s, modifier)
		RubbleyStats.Stat.GRAVITY_RIPPLE_SPEED_M_PER_S:
			stats.gravity_ripple_speed_m_per_s = _changed(
				stats.gravity_ripple_speed_m_per_s,
				modifier,
			)
		RubbleyStats.Stat.GRAVITY_RIPPLE_RADIUS_M:
			stats.gravity_ripple_radius_m = _changed(stats.gravity_ripple_radius_m, modifier)
		RubbleyStats.Stat.RADIAL_REPEL_REFERENCE_MASS_KG:
			stats.radial_repel_reference_mass_kg = _changed(
				stats.radial_repel_reference_mass_kg,
				modifier,
			)
		RubbleyStats.Stat.RADIAL_REPEL_MASS_FALLOFF:
			stats.radial_repel_mass_falloff = _changed(stats.radial_repel_mass_falloff, modifier)
		RubbleyStats.Stat.TARGETED_REPEL_IMPULSE_N_S:
			stats.targeted_repel_impulse_n_s = _changed(stats.targeted_repel_impulse_n_s, modifier)
		_:
			assert(false, "RubbleyStatsBuilder doesn't handle Stat %d" % modifier.stat)


# Returns [param value] with [param modifier] added to it or multiplied into it, never
# below zero: no Stat is a negative max, rate or cost.
static func _changed(value: float, modifier: StatModifier) -> float:
	if modifier.operation == StatModifier.Operation.MULTIPLY:
		return maxf(value * modifier.value, 0.0)
	return maxf(value + modifier.value, 0.0)
