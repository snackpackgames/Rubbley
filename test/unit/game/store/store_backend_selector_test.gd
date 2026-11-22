extends GdUnitTestSuite
## Feature-tag backend selection and the forced Free Tier command-line switch (ADR 0019).


## Each store_* feature tag maps to its own backend script path under game/store/<store>/.
func test_store_feature_tags_select_matching_paths() -> void:
	assert_str(StoreBackendSelector.backend_path_for_features(_features(["store_steam"]))).is_equal(
		StoreBackendSelector.PATH_STEAM,
	)
	assert_str(StoreBackendSelector.backend_path_for_features(_features(["store_epic"]))).is_equal(
		StoreBackendSelector.PATH_EPIC,
	)
	assert_str(StoreBackendSelector.backend_path_for_features(_features(["store_apple"]))).is_equal(
		StoreBackendSelector.PATH_APPLE,
	)
	assert_str(StoreBackendSelector.backend_path_for_features(_features(["store_play"]))).is_equal(
		StoreBackendSelector.PATH_PLAY,
	)
	assert_str(StoreBackendSelector.backend_path_for_features(_features(["store_itch"]))).is_equal(
		StoreBackendSelector.PATH_NULL,
	)
	assert_str(StoreBackendSelector.backend_path_for_features(_features(["store_none"]))).is_equal(
		StoreBackendSelector.PATH_NULL,
	)
	assert_str(StoreBackendSelector.backend_path_for_features(_features([]))).is_equal(
		StoreBackendSelector.PATH_NULL,
	)


## store_itch builds a Free Tier Null backend; store_none and no tag build a Full Game Null backend.
func test_create_backend_loads_null_with_expected_tier() -> void:
	var loaded_paths: Array[String] = []
	var loader := func(path: String) -> Variant:
		loaded_paths.append(path)
		return ResourceLoader.load(path)

	var itch := StoreBackendSelector.create_backend(_features(["store_itch"]), loader)
	var playtest := StoreBackendSelector.create_backend(_features(["store_none"]), loader)
	var editor := StoreBackendSelector.create_backend(_features([]), loader)

	assert_bool(itch is NullStoreBackend).is_true()
	assert_bool(itch.has_full_game()).is_false()
	assert_bool(playtest is NullStoreBackend).is_true()
	assert_bool(playtest.has_full_game()).is_true()
	assert_bool(editor is NullStoreBackend).is_true()
	assert_bool(editor.has_full_game()).is_true()
	assert_int(loaded_paths.size()).is_equal(3)


## The --free-tier command-line switch works in editor/debug builds and is ignored in release.
func test_force_free_tier_switch_honoured_only_in_debug_or_editor() -> void:
	var with_flag := PackedStringArray(["--verbose", StoreBackendSelector.FORCE_FREE_TIER_ARG])
	var without_flag := PackedStringArray(["--verbose"])

	assert_bool(StoreBackendSelector.is_force_free_tier_requested(with_flag, true)).is_true()
	assert_bool(StoreBackendSelector.is_force_free_tier_requested(without_flag, true)).is_false()
	assert_bool(StoreBackendSelector.is_force_free_tier_requested(with_flag, false)).is_false()


func _features(tags: Array[String]) -> Callable:
	return func(tag: String) -> bool:
		return tags.has(tag)
