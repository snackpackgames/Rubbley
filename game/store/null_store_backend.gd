class_name NullStoreBackend
extends StoreBackend
## The no-store backend used on itch.io ([code]store_itch[/code], Free Tier), the Playtest
## Build ([code]store_none[/code], Full Game) and the editor (Full Game) (ADR 0019).
## Every store capability is off, and every request settles cleanly without touching a
## store SDK.

var _full_game: bool
var _capabilities := StoreCapabilities.new()


## Creates a Null backend configured as either the Full Game or the Free Tier.
func _init(full_game: bool = true) -> void:
	_full_game = full_game


## Reports the build's fixed tier immediately as verified.
func start() -> void:
	full_game_check_finished.emit(true, _full_game)


## Returns all-false capabilities: itch.io, web and the editor have no store services.
func capabilities() -> StoreCapabilities:
	return _capabilities


## Returns [constant StoreBackend.CloudCapability.NONE]; saves stay local.
func cloud_capability() -> CloudCapability:
	return CloudCapability.NONE


## Returns whether this Null build is the Full Game (true for editor/Playtest, false for
## itch.io).
func has_full_game() -> bool:
	return _full_game


## Always verified: the build itself defines whether it is Full Game or Free Tier.
func is_entitlement_verified() -> bool:
	return true


## Fails cleanly: the Null backend has no store to buy the Unlock from.
func purchase_unlock() -> void:
	unlock_purchase_finished.emit(PurchaseResult.FAILED)


## Finishes cleanly with nothing to restore.
func restore_purchases() -> void:
	restore_purchases_finished.emit(RestoreResult.NOTHING_TO_RESTORE)


## Fire-and-forget no-op.
func unlock_achievement(_achievement: Achievement) -> void:
	pass


## Fire-and-forget no-op.
func submit_score(_board: Leaderboard, _score: int) -> void:
	pass


## Finishes cleanly with an empty leaderboard.
func load_leaderboard(board: Leaderboard) -> void:
	var empty: Array[LeaderboardEntry] = []
	leaderboard_loaded.emit(board, empty)


## Finishes cleanly reporting no cloud save support.
func push_save(_bytes: PackedByteArray) -> void:
	cloud_save_pushed.emit(false)


## Finishes cleanly reporting no cloud save support.
func pull_save() -> void:
	cloud_save_pulled.emit(false, PackedByteArray())
