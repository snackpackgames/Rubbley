class_name FakeStoreBackend
extends StoreBackend
## Controllable [StoreBackend] for headless unit tests (ADR 0019). Tests configure its
## capabilities, tier, offline state and next purchase or restore outcome, then assert on
## emitted signals and recorded calls.

## Current Full Game state reported by [method has_full_game].
var full_game := false
## Whether the store was able to verify [member full_game].
var entitlement_verified := true
## Capabilities reported by [method capabilities].
var store_capabilities := StoreCapabilities.new()
## Cloud save mode reported by [method cloud_capability].
var cloud := CloudCapability.NONE
## Result emitted by [method purchase_unlock] when online.
var next_purchase_result := PurchaseResult.SUCCEEDED
## Result emitted by [method restore_purchases] when online.
var next_restore_result := RestoreResult.RESTORED
## When true, network-bound store operations fail with offline/unverified outcomes.
var offline := false
## Stored cloud save payload returned by [method pull_save] when online.
var cloud_data := PackedByteArray()
## Achievements passed to [method unlock_achievement], in call order.
var unlocked_achievements: Array[Achievement] = []
## Score submissions passed to [method submit_score], each {board, score}.
var submitted_scores: Array[Dictionary] = []
## Number of times [method purchase_unlock] was called.
var purchase_attempts := 0
## Number of times [method restore_purchases] was called.
var restore_attempts := 0
## Payloads successfully pushed via [method push_save], in call order.
var pushed_saves: Array[PackedByteArray] = []
## Number of times [method pull_save] was called.
var pull_attempts := 0

var _leaderboard_boards: Array[Leaderboard] = []
var _leaderboard_rows: Array[Array] = []


## Creates a Fake backend with configurable initial Full Game state, capabilities and
## cloud save mode.
func _init(
	initial_full_game: bool = false,
	initial_capabilities: StoreCapabilities = null,
	initial_cloud: CloudCapability = CloudCapability.NONE,
) -> void:
	full_game = initial_full_game
	if initial_capabilities != null:
		store_capabilities = initial_capabilities
	cloud = initial_cloud


## Emits [signal StoreBackend.full_game_check_finished] reflecting [member offline].
func start() -> void:
	entitlement_verified = not offline
	full_game_check_finished.emit(entitlement_verified, full_game)


## Returns [member store_capabilities].
func capabilities() -> StoreCapabilities:
	return store_capabilities


## Returns [member cloud].
func cloud_capability() -> CloudCapability:
	return cloud


## Returns [member full_game].
func has_full_game() -> bool:
	return full_game


## Returns [member entitlement_verified].
func is_entitlement_verified() -> bool:
	return entitlement_verified


## Sets [member full_game] and emits [signal StoreBackend.full_game_changed] if it changed.
func set_full_game(unlocked: bool) -> void:
	if full_game == unlocked:
		return
	full_game = unlocked
	full_game_changed.emit(full_game)


## Configures the entries [method load_leaderboard] emits for [param board].
func set_leaderboard_entries(board: Leaderboard, entries: Array[LeaderboardEntry]) -> void:
	var index := _leaderboard_boards.find(board)
	if index >= 0:
		_leaderboard_rows[index] = entries.duplicate()
		return
	_leaderboard_boards.append(board)
	_leaderboard_rows.append(entries.duplicate())


## Simulates an Unlock purchase according to [member offline] and
## [member next_purchase_result].
func purchase_unlock() -> void:
	purchase_attempts += 1
	if offline:
		unlock_purchase_finished.emit(PurchaseResult.OFFLINE)
		return
	var result := next_purchase_result
	if result == PurchaseResult.SUCCEEDED:
		entitlement_verified = true
		set_full_game(true)
	unlock_purchase_finished.emit(result)


## Simulates Restore Purchases according to [member offline] and
## [member next_restore_result].
func restore_purchases() -> void:
	restore_attempts += 1
	if offline:
		restore_purchases_finished.emit(RestoreResult.OFFLINE)
		return
	var result := next_restore_result
	if result == RestoreResult.RESTORED:
		entitlement_verified = true
		set_full_game(true)
	restore_purchases_finished.emit(result)


## Records the unlocked achievement.
func unlock_achievement(achievement: Achievement) -> void:
	unlocked_achievements.append(achievement)


## Records the submitted score.
func submit_score(board: Leaderboard, score: int) -> void:
	submitted_scores.append({ "board": board, "score": score })


## Emits the configured entries for [param board], or an empty array when offline or unset.
func load_leaderboard(board: Leaderboard) -> void:
	var entries: Array[LeaderboardEntry] = []
	var index := _leaderboard_boards.find(board)
	if not offline and index >= 0:
		entries.assign(_leaderboard_rows[index])
	leaderboard_loaded.emit(board, entries)


## Stores [param bytes] when online and configured for [enum CloudCapability].IN_CODE.
func push_save(bytes: PackedByteArray) -> void:
	if offline or cloud != CloudCapability.IN_CODE:
		cloud_save_pushed.emit(false)
		return
	cloud_data = bytes.duplicate()
	pushed_saves.append(bytes.duplicate())
	cloud_save_pushed.emit(true)


## Emits [member cloud_data] when online and configured for [enum CloudCapability].IN_CODE.
func pull_save() -> void:
	pull_attempts += 1
	if offline or cloud != CloudCapability.IN_CODE:
		cloud_save_pulled.emit(false, PackedByteArray())
		return
	cloud_save_pulled.emit(true, cloud_data.duplicate())
