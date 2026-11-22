extends GdUnitTestSuite
## The Free Tier gate plain class (ADRs 0015, 0019): reads only has_full_game() and the
## always-free levels list.


## Under Free Tier, only levels in the free list are playable.
func test_free_tier_allows_free_levels_and_blocks_gated_levels() -> void:
	var gate := FreeTierGate.new(
		func() -> bool:
			return false,
		[&"sandbox_free"],
	)
	assert_bool(gate.is_level_free(&"sandbox_free")).is_true()
	assert_bool(gate.is_level_free(&"sandbox_gated")).is_false()
	assert_bool(gate.can_play_level(&"sandbox_free")).is_true()
	assert_bool(gate.can_play_level(&"sandbox_gated")).is_false()


## Under Full Game, every level is playable regardless of the free list.
func test_full_game_allows_every_level() -> void:
	var gate := FreeTierGate.new(
		func() -> bool:
			return true,
		[&"sandbox_free"],
	)
	assert_bool(gate.can_play_level(&"sandbox_free")).is_true()
	assert_bool(gate.can_play_level(&"sandbox_gated")).is_true()
	assert_bool(gate.can_play_level(&"any_future_level")).is_true()


## Unlocking mid-session immediately opens gated levels because the gate queries live state.
func test_unlocking_opens_gated_levels_immediately() -> void:
	var unlocked := [false]
	var gate := FreeTierGate.new(
		func() -> bool:
			return unlocked[0],
		[&"sandbox_free"],
	)
	assert_bool(gate.can_play_level(&"sandbox_gated")).is_false()
	unlocked[0] = true
	assert_bool(gate.can_play_level(&"sandbox_gated")).is_true()
