class_name SaveMerger
extends RefCounted
## Pure automatic conflict merge between two [SaveData] snapshots (ADR 0019): union of
## completed levels, union of owned Stat Modifier ids, and max of each best score. Neither
## input is mutated.


## Returns a new [SaveData] merging [param local] and [param remote] without losing
## progress. Preserves [param local]'s device-local [member SaveData.cached_full_game].
static func merge(local: SaveData, remote: SaveData) -> SaveData:
	var merged := SaveData.new()
	if local != null:
		merged.cached_full_game = local.cached_full_game
		_merge_into(merged, local)
	if remote != null:
		_merge_into(merged, remote)
	merged.completed_levels.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b),
	)
	merged.owned_modifier_ids.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b),
	)
	return merged


static func _merge_into(target: SaveData, source: SaveData) -> void:
	for level_id in source.completed_levels:
		target.add_completed_level(level_id)
	for modifier_id in source.owned_modifier_ids:
		target.add_owned_modifier(modifier_id)
	for board in source.best_scores:
		target.record_score(board, source.best_scores[board])
