class_name LeaderboardEntry
extends RefCounted
## One row returned by a store leaderboard query (ADR 0019).

## 1-based position on the leaderboard.
var rank := 0
## Display name provided by the store for the player.
var player_name := ""
## Score recorded on the leaderboard.
var score := 0


## Creates one leaderboard row.
func _init(entry_rank: int = 0, entry_player_name: String = "", entry_score: int = 0) -> void:
	rank = entry_rank
	player_name = entry_player_name
	score = entry_score
