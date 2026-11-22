extends GdUnitTestSuite
## Pure save merge, serialization and per-device settings tests (ADRs 0017, 0019).


## Merging takes the union of completed levels and owned modifier ids, and the max of each
## best score, without mutating either input.
func test_merge_unions_sets_and_takes_max_scores() -> void:
	var local := SaveData.new()
	local.add_completed_level(&"level_1")
	local.add_completed_level(&"level_2")
	local.add_owned_modifier(&"mod_a")
	local.record_score(StoreBackend.Leaderboard.PLACEHOLDER, 250)
	local.cached_full_game = true

	var cloud := SaveData.new()
	cloud.add_completed_level(&"level_2")
	cloud.add_completed_level(&"level_3")
	cloud.add_owned_modifier(&"mod_a")
	cloud.add_owned_modifier(&"mod_b")
	cloud.record_score(StoreBackend.Leaderboard.PLACEHOLDER, 400)
	cloud.cached_full_game = false

	var merged := SaveMerger.merge(local, cloud)

	assert_array(merged.completed_levels).contains_exactly([&"level_1", &"level_2", &"level_3"])
	assert_array(merged.owned_modifier_ids).contains_exactly([&"mod_a", &"mod_b"])
	assert_int(merged.best_score(StoreBackend.Leaderboard.PLACEHOLDER)).is_equal(400)
	assert_bool(merged.cached_full_game).is_true()
	# Inputs remain untouched.
	assert_array(local.completed_levels).contains_exactly([&"level_1", &"level_2"])
	assert_array(cloud.completed_levels).contains_exactly([&"level_2", &"level_3"])
	assert_int(local.best_score(StoreBackend.Leaderboard.PLACEHOLDER)).is_equal(250)


## Merging keeps the higher local score when local beats remote.
func test_merge_keeps_higher_local_score() -> void:
	var local := SaveData.new()
	local.record_score(StoreBackend.Leaderboard.PLACEHOLDER, 900)
	var cloud := SaveData.new()
	cloud.record_score(StoreBackend.Leaderboard.PLACEHOLDER, 100)

	var merged := SaveMerger.merge(local, cloud)
	assert_int(merged.best_score(StoreBackend.Leaderboard.PLACEHOLDER)).is_equal(900)


## Merging handles null inputs cleanly.
func test_merge_handles_null_inputs() -> void:
	var only := SaveData.new()
	only.add_completed_level(&"sandbox_free")
	assert_array(SaveMerger.merge(only, null).completed_levels).contains_exactly([&"sandbox_free"])
	assert_array(SaveMerger.merge(null, only).completed_levels).contains_exactly([&"sandbox_free"])
	assert_bool(SaveMerger.merge(null, null).has_any_progress()).is_false()


## Local serialization preserves every field; cloud serialization omits cached_full_game;
## malformed payloads return null safely.
func test_save_data_serialization_round_trip() -> void:
	var original := SaveData.new()
	original.add_completed_level(&"sandbox_free")
	original.add_owned_modifier(&"stamina_plus")
	original.record_score(StoreBackend.Leaderboard.PLACEHOLDER, 1234)
	original.cached_full_game = true

	var local_copy := SaveData.from_bytes(original.to_bytes())
	assert_object(local_copy).is_not_null()
	assert_bool(local_copy.progress_equals(original)).is_true()
	assert_bool(local_copy.cached_full_game).is_true()

	var cloud_copy := SaveData.from_bytes(original.to_cloud_bytes())
	assert_object(cloud_copy).is_not_null()
	assert_bool(cloud_copy.progress_equals(original)).is_true()
	assert_bool(cloud_copy.cached_full_game).is_false()

	assert_object(SaveData.from_bytes(PackedByteArray())).is_null()
	assert_object(SaveData.from_bytes("not json".to_utf8_buffer())).is_null()
	assert_object(SaveData.from_bytes("{}".to_utf8_buffer())).is_null()
	assert_object(SaveData.from_bytes('{"version":0}'.to_utf8_buffer())).is_null()
	assert_object(SaveData.from_bytes('{"version":99}'.to_utf8_buffer())).is_null()


## Zero and negative scores are ignored by record_score.
func test_non_positive_scores_are_ignored() -> void:
	var data := SaveData.new()
	assert_bool(data.record_score(StoreBackend.Leaderboard.PLACEHOLDER, 0)).is_false()
	assert_bool(data.record_score(StoreBackend.Leaderboard.PLACEHOLDER, -50)).is_false()
	assert_int(data.best_score(StoreBackend.Leaderboard.PLACEHOLDER)).is_equal(0)


## SettingsData round-trips cleanly, clamps out-of-range/NaN volumes and rejects bad versions.
func test_settings_data_round_trip_and_clamping() -> void:
	var settings := SettingsData.new()
	settings.master_volume = 0.75
	settings.music_volume = NAN
	settings.sfx_volume = 1.5
	settings.reduced_motion = true

	var copy := settings.duplicate_data()
	assert_float(copy.music_volume).is_equal_approx(1.0, 1e-4)
	assert_float(copy.sfx_volume).is_equal_approx(1.0, 1e-4)

	var loaded := SettingsData.from_bytes(settings.to_bytes())
	assert_object(loaded).is_not_null()
	assert_float(loaded.master_volume).is_equal_approx(0.75, 1e-4)
	assert_float(loaded.music_volume).is_equal_approx(1.0, 1e-4)
	assert_float(loaded.sfx_volume).is_equal_approx(1.0, 1e-4)
	assert_bool(loaded.reduced_motion).is_true()
	assert_object(SettingsData.from_bytes("[]".to_utf8_buffer())).is_null()
	assert_object(SettingsData.from_bytes("{}".to_utf8_buffer())).is_null()
	assert_object(SettingsData.from_bytes('{"version":99}'.to_utf8_buffer())).is_null()


## SaveFileStore writes, overwrites, reads and rejects empty paths cleanly.
func test_save_file_store_write_overwrite_and_empty_path() -> void:
	var path := "user://test_file_store_probe.bin"
	assert_int(SaveFileStore.write_bytes("", PackedByteArray([1]))).is_equal(ERR_INVALID_PARAMETER)
	assert_int(SaveFileStore.write_bytes(path, PackedByteArray([1, 2, 3]))).is_equal(OK)
	assert_array(Array(SaveFileStore.read_bytes(path))).contains_exactly([1, 2, 3])
	assert_int(SaveFileStore.write_bytes(path, PackedByteArray([9, 8]))).is_equal(OK)
	assert_array(Array(SaveFileStore.read_bytes(path))).contains_exactly([9, 8])
	DirAccess.remove_absolute(path)
