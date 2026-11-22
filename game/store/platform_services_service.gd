class_name PlatformServicesService
extends Node
## Platform Services, the autoload every store call goes through (ADRs 0016, 0019).
## Wraps one [StoreBackend] picked by the build's [code]store_*[/code] feature tag and
## re-emits its async signals so callers talk only to this seam. Editor and debug builds
## accept [constant StoreBackendSelector.FORCE_FREE_TIER_ARG] to force Free Tier without
## an itch.io export.

## Emitted when [method has_full_game] changes.
signal full_game_changed(unlocked: bool)
## Emitted when the backend finishes checking the Full Game entitlement.
signal full_game_check_finished(ok: bool, unlocked: bool)
## Emitted when [method purchase_unlock] finishes.
signal unlock_purchase_finished(result: StoreBackend.PurchaseResult)
## Emitted when [method restore_purchases] finishes.
signal restore_purchases_finished(result: StoreBackend.RestoreResult)
## Emitted when [method load_leaderboard] finishes.
signal leaderboard_loaded(board: StoreBackend.Leaderboard, entries: Array[LeaderboardEntry])
## Emitted when [method pull_save] finishes.
signal cloud_save_pulled(ok: bool, data: PackedByteArray)
## Emitted when [method push_save] finishes.
signal cloud_save_pushed(ok: bool)

## The running Platform Services autoload, set while in the tree.
static var instance: PlatformServicesService

var _backend: StoreBackend
var _force_free_tier := false


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	if _backend == null:
		var args := PackedStringArray()
		args.append_array(OS.get_cmdline_args())
		args.append_array(OS.get_cmdline_user_args())
		var is_debug_or_editor := OS.is_debug_build() or OS.has_feature("editor")
		_force_free_tier = StoreBackendSelector.is_force_free_tier_requested(
			args,
			is_debug_or_editor,
		)
		var selected := StoreBackendSelector.create_backend(OS.has_feature, ResourceLoader.load)
		_attach_backend(selected)


func _process(delta: float) -> void:
	if _backend != null:
		_backend.poll(delta)


func _exit_tree() -> void:
	_disconnect_backend()
	if instance == self:
		instance = null


## Replaces the active backend (used by tests to inject [FakeStoreBackend]). Clears any
## forced Free Tier override so the injected backend controls [method has_full_game].
func set_backend(new_backend: StoreBackend) -> void:
	assert(new_backend != null, "PlatformServices requires a non-null StoreBackend")
	var previous_full_game := has_full_game() if _backend != null else false
	var had_backend := _backend != null
	_force_free_tier = false
	_attach_backend(new_backend)
	if had_backend and has_full_game() != previous_full_game:
		full_game_changed.emit(has_full_game())


## Forces [method has_full_game] to return false when [param enabled] is true, emitting
## [signal full_game_changed] if the effective answer changed.
func set_force_free_tier(enabled: bool) -> void:
	var previous := has_full_game()
	_force_free_tier = enabled
	var current := has_full_game()
	if current != previous:
		full_game_changed.emit(current)


## Returns whether the forced Free Tier override is currently active.
func is_force_free_tier() -> bool:
	return _force_free_tier


## Returns the currently attached [StoreBackend].
func backend() -> StoreBackend:
	return _backend


## Returns the active store's capabilities for UI hiding.
func capabilities() -> StoreCapabilities:
	return _backend.capabilities()


## Returns the active store's cloud save capability.
func cloud_capability() -> StoreBackend.CloudCapability:
	return _backend.cloud_capability()


## Returns whether the player has the Full Game.
func has_full_game() -> bool:
	if _force_free_tier:
		return false
	return _backend.has_full_game()


## Returns whether [method has_full_game] came from a verified store answer.
func is_entitlement_verified() -> bool:
	if _force_free_tier:
		return true
	return _backend.is_entitlement_verified()


## Starts purchasing the single one-time Unlock.
func purchase_unlock() -> void:
	_backend.purchase_unlock()


## Restores a previous Unlock purchase.
func restore_purchases() -> void:
	_backend.restore_purchases()


## Fire-and-forget achievement unlock.
func unlock_achievement(achievement: StoreBackend.Achievement) -> void:
	_backend.unlock_achievement(achievement)


## Fire-and-forget leaderboard score submission.
func submit_score(board: StoreBackend.Leaderboard, score: int) -> void:
	_backend.submit_score(board, score)


## Requests entries for [param board].
func load_leaderboard(board: StoreBackend.Leaderboard) -> void:
	_backend.load_leaderboard(board)


## Pushes save bytes on [enum StoreBackend.CloudCapability].IN_CODE stores.
func push_save(bytes: PackedByteArray) -> void:
	_backend.push_save(bytes)


## Pulls save bytes on [enum StoreBackend.CloudCapability].IN_CODE stores.
func pull_save() -> void:
	_backend.pull_save()


func _attach_backend(new_backend: StoreBackend) -> void:
	_disconnect_backend()
	_backend = new_backend
	_backend.full_game_changed.connect(_on_backend_full_game_changed)
	_backend.full_game_check_finished.connect(_on_backend_full_game_check_finished)
	_backend.unlock_purchase_finished.connect(_on_backend_unlock_purchase_finished)
	_backend.restore_purchases_finished.connect(_on_backend_restore_purchases_finished)
	_backend.leaderboard_loaded.connect(_on_backend_leaderboard_loaded)
	_backend.cloud_save_pulled.connect(_on_backend_cloud_save_pulled)
	_backend.cloud_save_pushed.connect(_on_backend_cloud_save_pushed)
	_backend.start()


func _disconnect_backend() -> void:
	if _backend == null:
		return
	if _backend.full_game_changed.is_connected(_on_backend_full_game_changed):
		_backend.full_game_changed.disconnect(_on_backend_full_game_changed)
	if _backend.full_game_check_finished.is_connected(_on_backend_full_game_check_finished):
		_backend.full_game_check_finished.disconnect(_on_backend_full_game_check_finished)
	if _backend.unlock_purchase_finished.is_connected(_on_backend_unlock_purchase_finished):
		_backend.unlock_purchase_finished.disconnect(_on_backend_unlock_purchase_finished)
	if _backend.restore_purchases_finished.is_connected(_on_backend_restore_purchases_finished):
		_backend.restore_purchases_finished.disconnect(_on_backend_restore_purchases_finished)
	if _backend.leaderboard_loaded.is_connected(_on_backend_leaderboard_loaded):
		_backend.leaderboard_loaded.disconnect(_on_backend_leaderboard_loaded)
	if _backend.cloud_save_pulled.is_connected(_on_backend_cloud_save_pulled):
		_backend.cloud_save_pulled.disconnect(_on_backend_cloud_save_pulled)
	if _backend.cloud_save_pushed.is_connected(_on_backend_cloud_save_pushed):
		_backend.cloud_save_pushed.disconnect(_on_backend_cloud_save_pushed)


func _on_backend_full_game_changed(_unlocked: bool) -> void:
	full_game_changed.emit(has_full_game())


func _on_backend_full_game_check_finished(ok: bool, _unlocked: bool) -> void:
	full_game_check_finished.emit(ok, has_full_game())


func _on_backend_unlock_purchase_finished(result: StoreBackend.PurchaseResult) -> void:
	unlock_purchase_finished.emit(result)


func _on_backend_restore_purchases_finished(result: StoreBackend.RestoreResult) -> void:
	restore_purchases_finished.emit(result)


func _on_backend_leaderboard_loaded(
	board: StoreBackend.Leaderboard,
	entries: Array[LeaderboardEntry],
) -> void:
	leaderboard_loaded.emit(board, entries)


func _on_backend_cloud_save_pulled(ok: bool, data: PackedByteArray) -> void:
	cloud_save_pulled.emit(ok, data)


func _on_backend_cloud_save_pushed(ok: bool) -> void:
	cloud_save_pushed.emit(ok)
