extends GdUnitTestSuite
## Building Rubbley's effective Stats from his base Stats and active Stat Modifiers
## (ADR 0017): every add applies before any multiply, and the base is never written.


## With no modifiers the effective Stats match the base.
func test_no_modifiers_keeps_the_base() -> void:
	var base := RubbleyStats.new()
	base.stamina_max = 100.0
	var effective := RubbleyStatsBuilder.build(base, [])
	assert_float(effective.stamina_max).is_equal(100.0)


## Adds apply before multiplies, whatever order the modifiers come in:
## (100 + 20) × 1.5 = 180, not 100 × 1.5 + 20 = 170.
func test_adds_apply_before_multiplies() -> void:
	var base := RubbleyStats.new()
	base.stamina_max = 100.0
	var effective := RubbleyStatsBuilder.build(
		base,
		[
			_modifier(RubbleyStats.Stat.STAMINA_MAX, StatModifier.Operation.MULTIPLY, 1.5),
			_modifier(RubbleyStats.Stat.STAMINA_MAX, StatModifier.Operation.ADD, 20.0),
		],
	)
	assert_float(effective.stamina_max).is_equal_approx(180.0, 1e-6)


## Modifiers on the same Stat stack: two adds sum, two multiplies compound.
func test_modifiers_on_one_stat_stack() -> void:
	var base := RubbleyStats.new()
	base.repel_pulse_cost = 10.0
	var effective := RubbleyStatsBuilder.build(
		base,
		[
			_modifier(RubbleyStats.Stat.REPEL_PULSE_COST, StatModifier.Operation.ADD, 2.0),
			_modifier(RubbleyStats.Stat.REPEL_PULSE_COST, StatModifier.Operation.ADD, 3.0),
			_modifier(RubbleyStats.Stat.REPEL_PULSE_COST, StatModifier.Operation.MULTIPLY, 2.0),
			_modifier(RubbleyStats.Stat.REPEL_PULSE_COST, StatModifier.Operation.MULTIPLY, 0.5),
		],
	)
	assert_float(effective.repel_pulse_cost).is_equal_approx(15.0, 1e-6)


## A modifier changes only its own Stat, and the base Stats are left as they were.
func test_a_modifier_changes_only_its_stat_and_not_the_base() -> void:
	var base := RubbleyStats.new()
	base.stamina_max = 100.0
	base.spin_cost = 10.0
	var effective := RubbleyStatsBuilder.build(
		base,
		[_modifier(RubbleyStats.Stat.SPIN_COST, StatModifier.Operation.ADD, 5.0)],
	)
	assert_float(effective.spin_cost).is_equal(15.0)
	assert_float(effective.stamina_max).is_equal(100.0)
	assert_float(base.spin_cost).is_equal(10.0)
	assert_object(effective).is_not_same(base)


## A modifier never takes a Stat below zero: a max, a rate or a cost can't go negative.
func test_a_stat_never_goes_below_zero() -> void:
	var base := RubbleyStats.new()
	base.stamina_max = 100.0
	base.spin_cost = 10.0
	var effective := RubbleyStatsBuilder.build(
		base,
		[
			_modifier(RubbleyStats.Stat.STAMINA_MAX, StatModifier.Operation.ADD, -150.0),
			_modifier(RubbleyStats.Stat.SPIN_COST, StatModifier.Operation.MULTIPLY, -1.0),
		],
	)
	assert_float(effective.stamina_max).is_equal(0.0)
	assert_float(effective.spin_cost).is_equal(0.0)


## Every Stat in the enum is handled: an add on it changes exactly one exported field.
func test_every_stat_is_handled() -> void:
	var base := RubbleyStats.new()
	var fields := _float_fields(base)
	for stat: int in RubbleyStats.Stat.values():
		var effective := RubbleyStatsBuilder.build(
			base,
			[_modifier(stat, StatModifier.Operation.ADD, 1.0)],
		)
		var changed: Array[StringName] = []
		for field in fields:
			var base_value: float = base.get(field)
			var effective_value: float = effective.get(field)
			if not is_equal_approx(effective_value, base_value):
				changed.append(field)
		var message := "Stat %s changed %s" % [RubbleyStats.Stat.find_key(stat), changed]
		assert_int(changed.size()).override_failure_message(message).is_equal(1)


func _modifier(
	stat: RubbleyStats.Stat,
	operation: StatModifier.Operation,
	value: float,
) -> StatModifier:
	var modifier := StatModifier.new()
	modifier.stat = stat
	modifier.operation = operation
	modifier.value = value
	return modifier


# The script's exported float fields, read by name only here, in the test.
func _float_fields(stats: RubbleyStats) -> Array[StringName]:
	var fields: Array[StringName] = []
	for property in stats.get_property_list():
		var usage: int = property[&"usage"]
		if property[&"type"] == TYPE_FLOAT and usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(property[&"name"])
	return fields
