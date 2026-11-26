extends GdUnitTestSuite
## Contract suite over every [StoreBackend] that builds headless: Null (Full Game and
## Free Tier) and Fake (ADR 0019). Verifies that every contract method settles cleanly
## and emits its expected signal.


## Every backend returns a non-null [StoreCapabilities] and a valid [CloudCapability].
func test_capabilities_and_cloud_mode_are_valid() -> void:
	for backend in _backends():
		assert_object(backend.capabilities()).is_not_null()
		var cloud := backend.cloud_capability()
		assert_bool(
			cloud
			in [
				StoreBackend.CloudCapability.NONE,
				StoreBackend.CloudCapability.FILE_SYNC,
				StoreBackend.CloudCapability.IN_CODE,
			],
		).is_true()


## Calling [method StoreBackend.start] emits [signal StoreBackend.full_game_check_finished].
func test_start_emits_full_game_check_finished() -> void:
	for backend in _backends():
		var checked := [false]
		backend.full_game_check_finished.connect(
			func(_ok: bool, _unlocked: bool) -> void:
				checked[0] = true,
		)
		backend.start()
		assert_bool(checked[0]).is_true()


## Calling [method StoreBackend.purchase_unlock] emits
## [signal StoreBackend.unlock_purchase_finished].
func test_purchase_unlock_emits_finished() -> void:
	for backend in _backends():
		var finished := [false]
		backend.unlock_purchase_finished.connect(
			func(_result: StoreBackend.PurchaseResult) -> void:
				finished[0] = true,
		)
		backend.purchase_unlock()
		assert_bool(finished[0]).is_true()


## Calling [method StoreBackend.restore_purchases] emits
## [signal StoreBackend.restore_purchases_finished].
func test_restore_purchases_emits_finished() -> void:
	for backend in _backends():
		var finished := [false]
		backend.restore_purchases_finished.connect(
			func(_result: StoreBackend.RestoreResult) -> void:
				finished[0] = true,
		)
		backend.restore_purchases()
		assert_bool(finished[0]).is_true()


## Achievements, score submission, leaderboard loads and polling settle safely on every backend.
func test_achievements_leaderboards_and_poll_settle() -> void:
	for backend in _backends():
		backend.poll(0.016)
		backend.unlock_achievement(StoreBackend.Achievement.PLACEHOLDER)
		backend.submit_score(StoreBackend.Leaderboard.PLACEHOLDER, 420)
		var loaded_board := [-1]
		backend.leaderboard_loaded.connect(
			func(board: StoreBackend.Leaderboard, _entries: Array[LeaderboardEntry]) -> void:
				loaded_board[0] = board,
		)
		backend.load_leaderboard(StoreBackend.Leaderboard.PLACEHOLDER)
		assert_int(loaded_board[0]).is_equal(StoreBackend.Leaderboard.PLACEHOLDER)


## Cloud save push and pull emit their completion signals on every backend.
func test_cloud_save_push_and_pull_emit_signals() -> void:
	for backend in _backends():
		var pushed := [false]
		var pulled := [false]
		backend.cloud_save_pushed.connect(
			func(_ok: bool) -> void:
				pushed[0] = true,
		)
		backend.cloud_save_pulled.connect(
			func(_ok: bool, _data: PackedByteArray) -> void:
				pulled[0] = true,
		)
		backend.push_save(PackedByteArray([1, 2, 3]))
		backend.pull_save()
		assert_bool(pushed[0]).is_true()
		assert_bool(pulled[0]).is_true()


## The Null backend has all capabilities off, local-only saves, and honours its Full Game flag.
func test_null_backend_capabilities_and_tier() -> void:
	var full := NullStoreBackend.new(true)
	var free := NullStoreBackend.new(false)

	assert_bool(full.has_full_game()).is_true()
	assert_bool(free.has_full_game()).is_false()
	assert_bool(full.is_entitlement_verified()).is_true()
	assert_bool(free.is_entitlement_verified()).is_true()
	assert_int(full.cloud_capability()).is_equal(StoreBackend.CloudCapability.NONE)
	assert_bool(full.capabilities().leaderboards).is_false()
	assert_bool(full.capabilities().achievements).is_false()
	assert_bool(full.capabilities().unlock_purchase).is_false()
	assert_bool(full.capabilities().cloud_saves).is_false()


func _backends() -> Array[StoreBackend]:
	var fake_mobile := FakeStoreBackend.new(
		false,
		StoreCapabilities.from_flags(true, true, true, true),
		StoreBackend.CloudCapability.IN_CODE,
	)
	return [
		NullStoreBackend.new(true),
		NullStoreBackend.new(false),
		FakeStoreBackend.new(),
		fake_mobile,
	]
