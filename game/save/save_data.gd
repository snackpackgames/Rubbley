class_name SaveData
extends RefCounted
## Player progress stored in the local save file and synced to cloud saves (ADRs 0017,
## 0019). Stores owned Stat Modifier ids (never folded numbers), completed level ids,
## best scores per leaderboard and the cached [code]has_full_game()[/code] answer.

## Current serialized save format version.
const FORMAT_VERSION := 1

## Ids of levels the player has completed.
var completed_levels: Array[StringName] = []
## Ids of owned Stat Modifiers (ADR 0017).
var owned_modifier_ids: Array[StringName] = []
## Highest recorded score for each leaderboard.
var best_scores: Dictionary[StoreBackend.Leaderboard, int] = { }
## Cached [code]has_full_game()[/code] answer used only when the store cannot be reached.
var cached_full_game := false


## Parses UTF-8 JSON bytes into a [SaveData], or returns null if the payload is empty,
## malformed or from an unsupported future format version.
static func from_bytes(bytes: PackedByteArray) -> SaveData:
	if bytes.is_empty():
		return null
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK:
		return null
	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		return null
	@warning_ignore("unsafe_cast") # Guarded by `is Dictionary` immediately above.
	var root := parsed as Dictionary
	if not _is_supported_version(root.get("version")):
		return null
	var data := SaveData.new()
	_read_string_name_list(root.get("completed_levels"), data.completed_levels)
	_read_string_name_list(root.get("owned_modifier_ids"), data.owned_modifier_ids)
	_read_best_scores(root.get("best_scores"), data)
	var cached_val: Variant = root.get("cached_full_game", false)
	if cached_val is bool:
		data.cached_full_game = cached_val
	return data


static func _is_supported_version(raw: Variant) -> bool:
	if raw is int:
		@warning_ignore("unsafe_cast") # Guarded by `is int` immediately above.
		var ver_int := raw as int
		return ver_int >= 1 and ver_int <= FORMAT_VERSION
	if raw is float:
		@warning_ignore("unsafe_cast") # Guarded by `is float` immediately above.
		var ver_float := raw as float
		if not is_finite(ver_float) or floorf(ver_float) != ver_float:
			return false
		var ver := int(ver_float)
		return ver >= 1 and ver <= FORMAT_VERSION
	return false


static func _read_string_name_list(raw: Variant, target: Array[StringName]) -> void:
	if not (raw is Array):
		return
	@warning_ignore("unsafe_cast") # Guarded by `is Array` immediately above.
	var items := raw as Array
	for item: Variant in items:
		if item is String:
			@warning_ignore("unsafe_cast") # Guarded by `is String` immediately above.
			var id := StringName(item as String)
			if id != &"" and not target.has(id):
				target.append(id)


static func _read_best_scores(raw: Variant, target: SaveData) -> void:
	if not (raw is Dictionary):
		return
	@warning_ignore("unsafe_cast") # Guarded by `is Dictionary` immediately above.
	var dict := raw as Dictionary
	for key: Variant in dict:
		if not (key is String):
			continue
		var board_value: Variant = StoreBackend.Leaderboard.get(key)
		if not (board_value is int):
			continue
		@warning_ignore("unsafe_cast") # Guarded by `is int` from enum lookup above.
		var board := board_value as StoreBackend.Leaderboard
		var raw_score: Variant = dict[key]
		if raw_score is int:
			@warning_ignore("unsafe_cast") # Guarded by `is int` immediately above.
			target.record_score(board, raw_score as int)
		elif raw_score is float:
			@warning_ignore("unsafe_cast") # Guarded by `is float` immediately above.
			var score_float := raw_score as float
			if is_finite(score_float):
				target.record_score(board, int(score_float))


## Returns a deep copy of this [SaveData].
func duplicate_data() -> SaveData:
	var copy := SaveData.new()
	copy.completed_levels.assign(completed_levels)
	copy.owned_modifier_ids.assign(owned_modifier_ids)
	for board in best_scores:
		copy.best_scores[board] = best_scores[board]
	copy.cached_full_game = cached_full_game
	return copy


## Returns whether [param level_id] is recorded as completed.
func has_completed_level(level_id: StringName) -> bool:
	return completed_levels.has(level_id)


## Marks [param level_id] completed. Returns true if it was newly added.
func add_completed_level(level_id: StringName) -> bool:
	if level_id == &"" or completed_levels.has(level_id):
		return false
	completed_levels.append(level_id)
	return true


## Returns whether [param modifier_id] is owned.
func has_owned_modifier(modifier_id: StringName) -> bool:
	return owned_modifier_ids.has(modifier_id)


## Records [param modifier_id] as owned. Returns true if it was newly added.
func add_owned_modifier(modifier_id: StringName) -> bool:
	if modifier_id == &"" or owned_modifier_ids.has(modifier_id):
		return false
	owned_modifier_ids.append(modifier_id)
	return true


## Returns the best score recorded for [param board], or 0 if none is recorded.
func best_score(board: StoreBackend.Leaderboard) -> int:
	return best_scores.get(board, 0)


## Updates the best score for [param board] if [param score] is positive and strictly
## higher than the current best. Returns true when the best score improved.
func record_score(board: StoreBackend.Leaderboard, score: int) -> bool:
	if score <= 0 or score <= best_score(board):
		return false
	best_scores[board] = score
	return true


## Returns whether this save contains any player progress beyond an empty default save.
func has_any_progress() -> bool:
	return (
		not completed_levels.is_empty()
		or not owned_modifier_ids.is_empty() or not best_scores.is_empty()
	)


## Returns true if synced progress fields (levels, modifiers, best scores) match
## [param other], ignoring device-local [member cached_full_game].
func progress_equals(other: SaveData) -> bool:
	if other == null:
		return false
	if _sorted_strings(completed_levels) != _sorted_strings(other.completed_levels):
		return false
	if _sorted_strings(owned_modifier_ids) != _sorted_strings(other.owned_modifier_ids):
		return false
	if best_scores.size() != other.best_scores.size():
		return false
	for board in best_scores:
		if not other.best_scores.has(board) or other.best_scores[board] != best_scores[board]:
			return false
	return true


## Serializes the full local save (including [member cached_full_game]) to UTF-8 JSON
## bytes.
func to_bytes() -> PackedByteArray:
	var payload := _progress_dict()
	payload["cached_full_game"] = cached_full_game
	return JSON.stringify(payload).to_utf8_buffer()


## Serializes only the synced progress fields (excluding device-local
## [member cached_full_game]) to UTF-8 JSON bytes for cloud upload.
func to_cloud_bytes() -> PackedByteArray:
	return JSON.stringify(_progress_dict()).to_utf8_buffer()


func _progress_dict() -> Dictionary:
	var scores_dict: Dictionary = { }
	for board in best_scores:
		var board_name: Variant = StoreBackend.Leaderboard.find_key(board)
		if board_name is String:
			scores_dict[board_name] = best_scores[board]
	return {
		"version": FORMAT_VERSION,
		"completed_levels": _sorted_strings(completed_levels),
		"owned_modifier_ids": _sorted_strings(owned_modifier_ids),
		"best_scores": scores_dict,
	}


func _sorted_strings(ids: Array[StringName]) -> Array[String]:
	var unique: Dictionary[String, bool] = { }
	for id in ids:
		var text := String(id)
		if not text.is_empty():
			unique[text] = true
	var result: Array[String] = []
	for key: String in unique.keys():
		result.append(key)
	result.sort()
	return result
