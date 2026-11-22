class_name StoreCapabilities
extends RefCounted
## What the active store offers (ADR 0019). The UI reads these flags to hide anything the
## store lacks, such as the online board on itch.io and web, or Unlock and Restore on
## desktop.

## Whether the store provides online leaderboards.
var leaderboards := false
## Whether the store provides achievements.
var achievements := false
## Whether the store sells the one-time Unlock (with Restore Purchases).
var unlock_purchase := false
## Whether the store provides cloud saves (either launcher-synced or in-code).
var cloud_saves := false


## Builds a [StoreCapabilities] with every flag set explicitly.
static func from_flags(
	has_leaderboards: bool,
	has_achievements: bool,
	has_unlock_purchase: bool,
	has_cloud_saves: bool,
) -> StoreCapabilities:
	var caps := StoreCapabilities.new()
	caps.leaderboards = has_leaderboards
	caps.achievements = has_achievements
	caps.unlock_purchase = has_unlock_purchase
	caps.cloud_saves = has_cloud_saves
	return caps
