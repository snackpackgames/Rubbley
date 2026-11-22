extends GdUnitTestSuite
## Platform Services autoload driven by [FakeStoreBackend] (ADR 0019): purchase success,
## cancel, failure, Restore, offline, forced Free Tier and signal re-emission.

var _original_backend: StoreBackend
var _original_force_free: bool
var _fake: FakeStoreBackend


func before_test() -> void:
	if SaveSettingsService.instance != null:
		SaveSettingsService.instance.disconnect_services()
	_original_backend = PlatformServicesService.instance.backend()
	_original_force_free = PlatformServicesService.instance.is_force_free_tier()
	_fake = FakeStoreBackend.new(
		false,
		StoreCapabilities.from_flags(true, true, true, true),
		StoreBackend.CloudCapability.IN_CODE,
	)
	PlatformServicesService.instance.set_backend(_fake)


func after_test() -> void:
	PlatformServicesService.instance.set_backend(_original_backend)
	PlatformServicesService.instance.set_force_free_tier(_original_force_free)
	if SaveSettingsService.instance != null:
		SaveSettingsService.instance.sync_with_platform_services(PlatformServicesService.instance)


## A successful Unlock purchase turns has_full_game() true and re-emits both signals.
func test_purchase_success_unlocks_full_game() -> void:
	var tier_events: Array[bool] = []
	var purchase_results: Array[StoreBackend.PurchaseResult] = []
	var on_tier := func(unlocked: bool) -> void:
		tier_events.append(unlocked)
	var on_purchase := func(result: StoreBackend.PurchaseResult) -> void:
		purchase_results.append(result)
	PlatformServicesService.instance.full_game_changed.connect(on_tier)
	PlatformServicesService.instance.unlock_purchase_finished.connect(on_purchase)

	_fake.next_purchase_result = StoreBackend.PurchaseResult.SUCCEEDED
	PlatformServicesService.instance.purchase_unlock()

	PlatformServicesService.instance.full_game_changed.disconnect(on_tier)
	PlatformServicesService.instance.unlock_purchase_finished.disconnect(on_purchase)

	assert_bool(PlatformServicesService.instance.has_full_game()).is_true()
	assert_array(tier_events).contains_exactly([true])
	assert_array(purchase_results).contains_exactly([StoreBackend.PurchaseResult.SUCCEEDED])


## A cancelled purchase leaves the player on Free Tier and emits CANCELLED.
func test_purchase_cancel_keeps_free_tier() -> void:
	var tier_events: Array[bool] = []
	var purchase_results: Array[StoreBackend.PurchaseResult] = []
	var on_tier := func(unlocked: bool) -> void:
		tier_events.append(unlocked)
	var on_purchase := func(result: StoreBackend.PurchaseResult) -> void:
		purchase_results.append(result)
	PlatformServicesService.instance.full_game_changed.connect(on_tier)
	PlatformServicesService.instance.unlock_purchase_finished.connect(on_purchase)

	_fake.next_purchase_result = StoreBackend.PurchaseResult.CANCELLED
	PlatformServicesService.instance.purchase_unlock()

	PlatformServicesService.instance.full_game_changed.disconnect(on_tier)
	PlatformServicesService.instance.unlock_purchase_finished.disconnect(on_purchase)

	assert_bool(PlatformServicesService.instance.has_full_game()).is_false()
	assert_array(tier_events).is_empty()
	assert_array(purchase_results).contains_exactly([StoreBackend.PurchaseResult.CANCELLED])


## A failed purchase leaves the player on Free Tier and emits FAILED.
func test_purchase_failure_keeps_free_tier() -> void:
	var purchase_results: Array[StoreBackend.PurchaseResult] = []
	var on_purchase := func(result: StoreBackend.PurchaseResult) -> void:
		purchase_results.append(result)
	PlatformServicesService.instance.unlock_purchase_finished.connect(on_purchase)

	_fake.next_purchase_result = StoreBackend.PurchaseResult.FAILED
	PlatformServicesService.instance.purchase_unlock()

	PlatformServicesService.instance.unlock_purchase_finished.disconnect(on_purchase)

	assert_bool(PlatformServicesService.instance.has_full_game()).is_false()
	assert_array(purchase_results).contains_exactly([StoreBackend.PurchaseResult.FAILED])


## Restore Purchases unlocks the Full Game when an earlier purchase exists, and leaves
## Free Tier intact when nothing is found.
func test_restore_purchases_restores_or_reports_nothing() -> void:
	var restore_results: Array[StoreBackend.RestoreResult] = []
	var on_restore := func(result: StoreBackend.RestoreResult) -> void:
		restore_results.append(result)
	PlatformServicesService.instance.restore_purchases_finished.connect(on_restore)

	_fake.next_restore_result = StoreBackend.RestoreResult.NOTHING_TO_RESTORE
	PlatformServicesService.instance.restore_purchases()
	var after_empty := PlatformServicesService.instance.has_full_game()

	_fake.next_restore_result = StoreBackend.RestoreResult.RESTORED
	PlatformServicesService.instance.restore_purchases()

	PlatformServicesService.instance.restore_purchases_finished.disconnect(on_restore)

	assert_bool(after_empty).is_false()
	assert_bool(PlatformServicesService.instance.has_full_game()).is_true()
	assert_array(restore_results).contains_exactly(
		[StoreBackend.RestoreResult.NOTHING_TO_RESTORE, StoreBackend.RestoreResult.RESTORED],
	)


## While offline, purchase and restore emit OFFLINE, cloud saves fail and entitlement
## stays unverified.
func test_offline_store_reports_offline_outcomes() -> void:
	var offline_fake := FakeStoreBackend.new(
		false,
		StoreCapabilities.from_flags(true, true, true, true),
		StoreBackend.CloudCapability.IN_CODE,
	)
	offline_fake.offline = true
	var check_ok := [true]
	var on_check := func(ok: bool, _unlocked: bool) -> void:
		check_ok[0] = ok
	PlatformServicesService.instance.full_game_check_finished.connect(on_check)
	PlatformServicesService.instance.set_backend(offline_fake)
	PlatformServicesService.instance.full_game_check_finished.disconnect(on_check)

	var purchase_result := [-1]
	var restore_result := [-1]
	var pushed_ok := [true]
	var pulled_ok := [true]
	var on_purchase := func(result: StoreBackend.PurchaseResult) -> void:
		purchase_result[0] = result
	var on_restore := func(result: StoreBackend.RestoreResult) -> void:
		restore_result[0] = result
	var on_push := func(ok: bool) -> void:
		pushed_ok[0] = ok
	var on_pull := func(ok: bool, _data: PackedByteArray) -> void:
		pulled_ok[0] = ok
	PlatformServicesService.instance.unlock_purchase_finished.connect(on_purchase)
	PlatformServicesService.instance.restore_purchases_finished.connect(on_restore)
	PlatformServicesService.instance.cloud_save_pushed.connect(on_push)
	PlatformServicesService.instance.cloud_save_pulled.connect(on_pull)

	PlatformServicesService.instance.purchase_unlock()
	PlatformServicesService.instance.restore_purchases()
	PlatformServicesService.instance.push_save(PackedByteArray([9]))
	PlatformServicesService.instance.pull_save()

	PlatformServicesService.instance.unlock_purchase_finished.disconnect(on_purchase)
	PlatformServicesService.instance.restore_purchases_finished.disconnect(on_restore)
	PlatformServicesService.instance.cloud_save_pushed.disconnect(on_push)
	PlatformServicesService.instance.cloud_save_pulled.disconnect(on_pull)

	assert_bool(check_ok[0]).is_false()
	assert_bool(PlatformServicesService.instance.is_entitlement_verified()).is_false()
	assert_int(purchase_result[0]).is_equal(StoreBackend.PurchaseResult.OFFLINE)
	assert_int(restore_result[0]).is_equal(StoreBackend.RestoreResult.OFFLINE)
	assert_bool(pushed_ok[0]).is_false()
	assert_bool(pulled_ok[0]).is_false()


## Achievements, leaderboards and cloud save push/pull forward through Platform Services.
func test_achievements_leaderboards_and_cloud_saves_forward() -> void:
	_fake.set_leaderboard_entries(
		StoreBackend.Leaderboard.PLACEHOLDER,
		[LeaderboardEntry.new(1, "Rubbley", 999)],
	)
	var loaded_entries: Array[LeaderboardEntry] = []
	var pulled_bytes: Array[PackedByteArray] = [PackedByteArray()]
	var on_board := func(_b: StoreBackend.Leaderboard, rows: Array[LeaderboardEntry]) -> void:
		loaded_entries.assign(rows)
	var on_pull := func(_ok: bool, data: PackedByteArray) -> void:
		pulled_bytes[0] = data
	PlatformServicesService.instance.leaderboard_loaded.connect(on_board)
	PlatformServicesService.instance.cloud_save_pulled.connect(on_pull)

	PlatformServicesService.instance.unlock_achievement(StoreBackend.Achievement.PLACEHOLDER)
	PlatformServicesService.instance.submit_score(StoreBackend.Leaderboard.PLACEHOLDER, 999)
	PlatformServicesService.instance.load_leaderboard(StoreBackend.Leaderboard.PLACEHOLDER)
	PlatformServicesService.instance.push_save(PackedByteArray([4, 5, 6]))
	PlatformServicesService.instance.pull_save()

	PlatformServicesService.instance.leaderboard_loaded.disconnect(on_board)
	PlatformServicesService.instance.cloud_save_pulled.disconnect(on_pull)

	assert_array(_fake.unlocked_achievements).contains_exactly(
		[StoreBackend.Achievement.PLACEHOLDER],
	)
	assert_int(_fake.submitted_scores.size()).is_equal(1)
	assert_int(loaded_entries.size()).is_equal(1)
	assert_int(loaded_entries[0].score).is_equal(999)
	assert_array(Array(pulled_bytes[0])).contains_exactly([4, 5, 6])


## Forcing Free Tier overrides a Full Game backend to false and signals the change.
func test_force_free_tier_overrides_full_game_backend() -> void:
	PlatformServicesService.instance.set_backend(NullStoreBackend.new(true))
	var tier_events: Array[bool] = []
	var on_tier := func(unlocked: bool) -> void:
		tier_events.append(unlocked)
	PlatformServicesService.instance.full_game_changed.connect(on_tier)

	PlatformServicesService.instance.set_force_free_tier(true)
	var forced := PlatformServicesService.instance.has_full_game()
	PlatformServicesService.instance.set_force_free_tier(false)

	PlatformServicesService.instance.full_game_changed.disconnect(on_tier)

	assert_bool(forced).is_false()
	assert_bool(PlatformServicesService.instance.has_full_game()).is_true()
	assert_array(tier_events).contains_exactly([false, true])
