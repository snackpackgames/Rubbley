extends GdUnitTestSuite
## Invariants on the shipped level catalog and Free Tier list (ADR 0015), ensuring both a
## free level and a gated level exist so the Free Tier gate is always exercised.

const CATALOG := preload("res://game/levels/sandbox_levels.tres")
const FREE_LEVELS := preload("res://game/store/free_levels.tres")


## The shipped level catalog has unique ids, valid scenes, at least one free level and at
## least one gated level.
func test_catalog_has_free_and_gated_levels() -> void:
	assert_int(CATALOG.entries.size()).is_greater_equal(2)
	var seen: Dictionary = { }
	var free_count := 0
	var gated_count := 0
	for entry in CATALOG.entries:
		assert_object(entry).is_not_null()
		assert_str(String(entry.id)).is_not_empty()
		assert_str(entry.display_name).is_not_empty()
		assert_object(entry.scene).is_not_null()
		assert_bool(seen.has(entry.id)).is_false()
		seen[entry.id] = true
		if FREE_LEVELS.free_level_ids.has(entry.id):
			free_count += 1
		else:
			gated_count += 1
	assert_int(free_count).is_greater_equal(1)
	assert_int(gated_count).is_greater_equal(1)
