extends SimulationTestSuite
## Save/Settings autoload behaviour against [FakeStoreBackend] (ADRs 0017, 0019): local
## saves, separate unsynced settings, closed handles between writes, in-code cloud pull
## and debounced push, and the cached has_full_game() fallback.

const TEST_DIR := "user://test_save_settings"
const SAVE_PATH := "user://test_save_settings/save.json"
const SETTINGS_PATH := "user://test_save_settings/settings.json"

var _services: PlatformServicesService
var _store_node: SaveSettingsService


func before_test() -> void:
	_clean_test_files()
	_services = auto_free(PlatformServicesService.new())
	_store_node = auto_free(SaveSettingsService.new())


func after_test() -> void:
	_clean_test_files()


## Progress saves to disk, reloads cleanly, leaves the file closed between writes, and
## settings live in a separate file that never triggers cloud sync.
func test_local_save_and_separate_unsynced_settings() -> void:
	var fake := FakeStoreBackend.new(
		true,
		StoreCapabilities.from_flags(true, true, false, true),
		StoreBackend.CloudCapability.IN_CODE,
	)
	_start_pair(fake, 0.05)

	_store_node.mark_level_completed(&"sandbox_free")
	_store_node.add_owned_modifier(&"spin_boost")
	var improved := _store_node.record_best_score(StoreBackend.Leaderboard.PLACEHOLDER, 500)
	var worse := _store_node.record_best_score(StoreBackend.Leaderboard.PLACEHOLDER, 200)

	var settings := SettingsData.new()
	settings.master_volume = 0.4
	settings.reduced_motion = true
	_store_node.update_settings(settings)

	# Verify both files are closed and readable/writable immediately.
	assert_bool(FileAccess.file_exists(SAVE_PATH)).is_true()
	assert_bool(FileAccess.file_exists(SETTINGS_PATH)).is_true()
	var raw_save := SaveFileStore.read_bytes(SAVE_PATH)
	var raw_settings := SaveFileStore.read_bytes(SETTINGS_PATH)
	assert_int(raw_save.size()).is_greater(0)
	assert_int(raw_settings.size()).is_greater(0)

	# Flush the progress push, then update settings alone and confirm no cloud push runs.
	_store_node.flush_cloud_push()
	var pushes_after_progress := fake.pushed_saves.size()
	settings.sfx_volume = 0.2
	_store_node.update_settings(settings)
	await step_seconds(0.15)

	assert_bool(improved).is_true()
	assert_bool(worse).is_false()
	assert_int(fake.pushed_saves.size()).is_equal(pushes_after_progress)

	# Reloading into a fresh SaveSettingsService restores both files independently.
	var reloaded: SaveSettingsService = auto_free(SaveSettingsService.new())
	reloaded.configure(SAVE_PATH, SETTINGS_PATH, 0.05)
	assert_array(reloaded.save_data().completed_levels).contains_exactly([&"sandbox_free"])
	assert_array(reloaded.save_data().owned_modifier_ids).contains_exactly([&"spin_boost"])
	assert_int(reloaded.save_data().best_score(StoreBackend.Leaderboard.PLACEHOLDER)).is_equal(500)
	assert_float(reloaded.settings_data().master_volume).is_equal_approx(0.4, 1e-4)
	assert_float(reloaded.settings_data().sfx_volume).is_equal_approx(0.2, 1e-4)
	assert_bool(reloaded.settings_data().reduced_motion).is_true()


## On in_code backends, launch pulls and merges remote progress with local progress, then
## debounces rapid edits into a single cloud push.
func test_in_code_cloud_pull_merge_and_debounced_push() -> void:
	# Seed a local save on disk before launch.
	var local := SaveData.new()
	local.add_completed_level(&"local_level")
	local.add_owned_modifier(&"local_mod")
	local.record_score(StoreBackend.Leaderboard.PLACEHOLDER, 300)
	SaveFileStore.write_bytes(SAVE_PATH, local.to_bytes())

	# Seed a conflicting remote save on the Fake cloud backend.
	var cloud := SaveData.new()
	cloud.add_completed_level(&"remote_level")
	cloud.add_owned_modifier(&"remote_mod")
	cloud.record_score(StoreBackend.Leaderboard.PLACEHOLDER, 750)
	var fake := FakeStoreBackend.new(
		true,
		StoreCapabilities.from_flags(true, true, true, true),
		StoreBackend.CloudCapability.IN_CODE,
	)
	fake.cloud_data = cloud.to_cloud_bytes()

	_start_pair(fake, 0.1)

	assert_int(fake.pull_attempts).is_equal(1)
	assert_array(_store_node.save_data().completed_levels).contains_exactly(
		[&"local_level", &"remote_level"],
	)
	assert_array(_store_node.save_data().owned_modifier_ids).contains_exactly(
		[&"local_mod", &"remote_mod"],
	)
	assert_int(_store_node.save_data().best_score(StoreBackend.Leaderboard.PLACEHOLDER)).is_equal(
		750,
	)

	# Rapid edits coalesce with the pending post-merge push into one debounced push.
	_store_node.mark_level_completed(&"extra_level_1")
	_store_node.mark_level_completed(&"extra_level_2")
	assert_int(fake.pushed_saves.size()).is_equal(0)
	await step_seconds(0.2)

	assert_int(fake.pushed_saves.size()).is_equal(1)
	var pushed := SaveData.from_bytes(fake.pushed_saves[0])
	assert_array(pushed.completed_levels).contains_exactly(
		[&"extra_level_1", &"extra_level_2", &"local_level", &"remote_level"],
	)
	assert_int(pushed.best_score(StoreBackend.Leaderboard.PLACEHOLDER)).is_equal(750)


## On NONE and FILE_SYNC backends, Save/Settings never calls pull_save() or push_save().
func test_non_in_code_backends_never_pull_or_push() -> void:
	var file_sync_fake := FakeStoreBackend.new(
		true,
		StoreCapabilities.from_flags(true, true, false, true),
		StoreBackend.CloudCapability.FILE_SYNC,
	)
	_start_pair(file_sync_fake, 0.05)
	_store_node.mark_level_completed(&"sandbox_free")
	await step_seconds(0.15)

	assert_int(file_sync_fake.pull_attempts).is_equal(0)
	assert_int(file_sync_fake.pushed_saves.size()).is_equal(0)


## The cached has_full_game() covers an offline failed check, while a verified store
## answer always replaces the cache (even back to false).
func test_cached_full_game_covers_offline_and_store_answer_replaces_cache() -> void:
	# Session 1: online, player buys Unlock -> cache persists true.
	var online_purchase := FakeStoreBackend.new(
		false,
		StoreCapabilities.from_flags(true, true, true, true),
		StoreBackend.CloudCapability.IN_CODE,
	)
	_start_pair(online_purchase, 0.1)
	assert_bool(_store_node.cached_full_game()).is_false()
	online_purchase.next_purchase_result = StoreBackend.PurchaseResult.SUCCEEDED
	_services.purchase_unlock()
	assert_bool(_store_node.cached_full_game()).is_true()

	# Session 2: offline failed check -> PlatformServices falls back to cached true.
	var offline_services: PlatformServicesService = auto_free(PlatformServicesService.new())
	var offline_fake := FakeStoreBackend.new(
		false,
		StoreCapabilities.from_flags(true, true, true, true),
		StoreBackend.CloudCapability.IN_CODE,
	)
	offline_fake.offline = true
	offline_services.set_backend(offline_fake)
	add_child(offline_services)

	var offline_save: SaveSettingsService = auto_free(SaveSettingsService.new())
	offline_save.configure(SAVE_PATH, SETTINGS_PATH, 0.1)
	offline_save.sync_with_platform_services(offline_services)

	assert_bool(offline_services.is_entitlement_verified()).is_false()
	assert_bool(offline_services.has_full_game()).is_true()
	assert_bool(offline_save.cached_full_game()).is_true()

	# Session 3: back online and the store explicitly answers false -> replaces cache.
	var revoked_services: PlatformServicesService = auto_free(PlatformServicesService.new())
	var revoked_fake := FakeStoreBackend.new(
		false,
		StoreCapabilities.from_flags(true, true, true, true),
		StoreBackend.CloudCapability.IN_CODE,
	)
	revoked_services.set_backend(revoked_fake)
	add_child(revoked_services)

	var revoked_save: SaveSettingsService = auto_free(SaveSettingsService.new())
	revoked_save.configure(SAVE_PATH, SETTINGS_PATH, 0.1)
	revoked_save.sync_with_platform_services(revoked_services)

	assert_bool(revoked_services.is_entitlement_verified()).is_true()
	assert_bool(revoked_services.has_full_game()).is_false()
	assert_bool(revoked_save.cached_full_game()).is_false()


## Debug forced Free Tier must not overwrite the cached Full Game state on disk.
func test_debug_force_free_tier_does_not_corrupt_cached_full_game() -> void:
	var full_fake := FakeStoreBackend.new(
		true,
		StoreCapabilities.from_flags(true, true, true, true),
	)
	_start_pair(full_fake, 0.1)
	assert_bool(_store_node.cached_full_game()).is_true()

	_services.set_force_free_tier(true)
	assert_bool(_services.has_full_game()).is_false()
	assert_bool(_store_node.cached_full_game()).is_true()


## An async store entitlement check answering false after cached_full_game=true emits
## full_game_changed(false) and replaces the cache on disk.
func test_async_entitlement_check_overrides_cache_and_signals_change() -> void:
	var cached := SaveData.new()
	cached.cached_full_game = true
	SaveFileStore.write_bytes(SAVE_PATH, cached.to_bytes())

	var async_backend := _DeferredFakeBackend.new()
	_start_pair(async_backend, 0.1)
	assert_bool(_services.is_entitlement_verified()).is_false()
	assert_bool(_services.has_full_game()).is_true()

	var tier_events: Array[bool] = []
	_services.full_game_changed.connect(
		func(unlocked: bool) -> void:
			tier_events.append(unlocked),
	)
	async_backend.finish_entitlement_check(true, false)

	assert_bool(_services.has_full_game()).is_false()
	assert_bool(_store_node.cached_full_game()).is_false()
	assert_array(tier_events).contains_exactly([false])


## Local edits made while an initial cloud pull is in flight wait for the pull and merge
## before pushing, so remote progress is never clobbered.
func test_local_save_during_in_flight_pull_merges_before_pushing() -> void:
	var async_backend := _DeferredFakeBackend.new()
	_start_pair(async_backend, 0.05)
	assert_int(async_backend.pull_attempts).is_equal(1)

	_store_node.mark_level_completed(&"local_during_pull")
	_store_node.flush_cloud_push()
	assert_int(async_backend.pushed_saves.size()).is_equal(0)

	var cloud := SaveData.new()
	cloud.add_completed_level(&"remote_before_pull")
	async_backend.finish_pull(true, cloud.to_cloud_bytes())
	await step_seconds(0.15)

	assert_int(async_backend.pushed_saves.size()).is_equal(1)
	var pushed := SaveData.from_bytes(async_backend.pushed_saves[0])
	assert_array(pushed.completed_levels).contains_exactly(
		[&"local_during_pull", &"remote_before_pull"],
	)


## A failed cloud push stays dirty and retries when connectivity returns and flushes.
func test_failed_cloud_push_retries_when_back_online() -> void:
	var fake := FakeStoreBackend.new(
		true,
		StoreCapabilities.from_flags(true, true, true, true),
		StoreBackend.CloudCapability.IN_CODE,
	)
	_start_pair(fake, 0.05)

	fake.offline = true
	_store_node.mark_level_completed(&"offline_level")
	await step_seconds(0.15)
	assert_int(fake.pushed_saves.size()).is_equal(0)
	assert_bool(_store_node.is_cloud_push_pending()).is_true()

	fake.offline = false
	_store_node.flush_cloud_push()
	assert_int(fake.pushed_saves.size()).is_equal(1)
	assert_bool(_store_node.is_cloud_push_pending()).is_false()


## A newer unsupported cloud schema version is never blindly overwritten by an older client.
func test_newer_version_cloud_save_is_not_clobbered() -> void:
	var fake := FakeStoreBackend.new(
		true,
		StoreCapabilities.from_flags(true, true, true, true),
		StoreBackend.CloudCapability.IN_CODE,
	)
	fake.cloud_data = '{"version":99,"completed_levels":["future"]}'.to_utf8_buffer()
	_start_pair(fake, 0.05)

	_store_node.mark_level_completed(&"local_level")
	_store_node.flush_cloud_push()
	assert_int(fake.pushed_saves.size()).is_equal(0)


func _start_pair(backend: StoreBackend, debounce_s: float) -> void:
	_services.set_backend(backend)
	add_child(_services)
	add_child(_store_node)
	_store_node.configure(SAVE_PATH, SETTINGS_PATH, debounce_s)
	_store_node.sync_with_platform_services(_services)


func _clean_test_files() -> void:
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp", SETTINGS_PATH, SETTINGS_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR)


class _DeferredFakeBackend:
	extends FakeStoreBackend

	func _init() -> void:
		super._init(
			false,
			StoreCapabilities.from_flags(true, true, true, true),
			StoreBackend.CloudCapability.IN_CODE,
		)
		entitlement_verified = false


	func start() -> void:
		entitlement_verified = false


	func pull_save() -> void:
		pull_attempts += 1


	func finish_entitlement_check(ok: bool, unlocked: bool) -> void:
		entitlement_verified = ok
		full_game = unlocked
		full_game_check_finished.emit(ok, unlocked)


	func finish_pull(ok: bool, data: PackedByteArray) -> void:
		cloud_save_pulled.emit(ok, data)
