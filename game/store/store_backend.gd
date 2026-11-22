class_name StoreBackend
extends RefCounted
## The single contract every store backend implements behind Platform Services (ADR 0019).
## Real backends live in [code]game/store/<store>/[/code] and are loaded by path from the
## export preset's [code]store_*[/code] feature tag so other stores' code and addons are
## never parsed in a build.

## Emitted when whether this build has the Full Game changes (for example after an Unlock
## purchase, Restore Purchases or entitlement refresh).
@warning_ignore("unused_signal") # Emitted by StoreBackend implementations.
signal full_game_changed(unlocked: bool)
## Emitted when an entitlement check finishes. [param ok] is false when the store could
## not be reached, so Save/Settings knows whether to trust [param unlocked] over its cache.
@warning_ignore("unused_signal") # Emitted by StoreBackend implementations.
signal full_game_check_finished(ok: bool, unlocked: bool)
## Emitted when [method purchase_unlock] finishes.
@warning_ignore("unused_signal") # Emitted by StoreBackend implementations.
signal unlock_purchase_finished(result: PurchaseResult)
## Emitted when [method restore_purchases] finishes.
@warning_ignore("unused_signal") # Emitted by StoreBackend implementations.
signal restore_purchases_finished(result: RestoreResult)
## Emitted when [method load_leaderboard] finishes.
@warning_ignore("unused_signal") # Emitted by StoreBackend implementations.
signal leaderboard_loaded(board: Leaderboard, entries: Array[LeaderboardEntry])
## Emitted when [method pull_save] finishes. [param ok] is false when the pull failed or
## cloud saves are unavailable.
@warning_ignore("unused_signal") # Emitted by StoreBackend implementations.
signal cloud_save_pulled(ok: bool, data: PackedByteArray)
## Emitted when [method push_save] finishes.
@warning_ignore("unused_signal") # Emitted by StoreBackend implementations.
signal cloud_save_pushed(ok: bool)

## Typed achievement ids. Each store maps these to its own string ids in a mapping
## resource. Real achievements come from later gameplay maps; this placeholder exercises
## the pipeline end to end.
enum Achievement {
	PLACEHOLDER,
}

## Typed leaderboard ids. Each store maps these to its own string ids in a mapping
## resource. Real boards come from later gameplay maps; this placeholder exercises the
## pipeline end to end.
enum Leaderboard {
	PLACEHOLDER,
}

## How the store syncs save files (ADR 0019).
enum CloudCapability {
	## Saves stay local only (itch.io, web, editor).
	NONE,
	## The store launcher syncs save files in [code]user://[/code] (Steam, Epic).
	FILE_SYNC,
	## Save/Settings pushes and pulls save bytes through this backend (Apple, Google Play).
	IN_CODE,
}

## Outcome of an Unlock purchase attempt.
enum PurchaseResult {
	SUCCEEDED,
	CANCELLED,
	FAILED,
	OFFLINE,
}

## Outcome of a Restore Purchases attempt.
enum RestoreResult {
	RESTORED,
	NOTHING_TO_RESTORE,
	FAILED,
	OFFLINE,
}


## Called once by Platform Services after attaching this backend. Backends that need SDK
## setup or an initial entitlement query do it here.
func start() -> void:
	pass


## Called every frame by Platform Services for SDKs that pump callbacks.
func poll(_delta: float) -> void:
	pass


## Returns the feature flags supported by this backend.
func capabilities() -> StoreCapabilities:
	return StoreCapabilities.new()


## Returns how this backend handles cloud saves.
func cloud_capability() -> CloudCapability:
	return CloudCapability.NONE


## Whether the player currently has the Full Game according to this store.
func has_full_game() -> bool:
	return false


## Whether [method has_full_game] reflects an answer from the store rather than a fallback
## while offline or still starting up.
func is_entitlement_verified() -> bool:
	return false


## Starts buying the single one-time Unlock. Finishes with
## [signal unlock_purchase_finished], and emits [signal full_game_changed] if unlocked.
func purchase_unlock() -> void:
	pass


## Asks the store to restore an earlier Unlock purchase. Finishes with
## [signal restore_purchases_finished], and emits [signal full_game_changed] if restored.
func restore_purchases() -> void:
	pass


## Fire-and-forget achievement unlock. No-op when the store has no achievements.
func unlock_achievement(_achievement: Achievement) -> void:
	pass


## Fire-and-forget leaderboard score submission. No-op when the store has no leaderboards.
func submit_score(_board: Leaderboard, _score: int) -> void:
	pass


## Requests entries for [param board]. Finishes with [signal leaderboard_loaded].
func load_leaderboard(_board: Leaderboard) -> void:
	pass


## Uploads save bytes on [enum CloudCapability].IN_CODE stores. Finishes with
## [signal cloud_save_pushed].
func push_save(_bytes: PackedByteArray) -> void:
	pass


## Downloads save bytes on [enum CloudCapability].IN_CODE stores. Finishes with
## [signal cloud_save_pulled].
func pull_save() -> void:
	pass
