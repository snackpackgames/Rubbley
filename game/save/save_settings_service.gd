class_name SaveSettingsService
extends Node
## Save/Settings, the autoload owning local saves, per-device settings, the cached
## [code]has_full_game()[/code] answer and [constant StoreBackend.CloudCapability.IN_CODE]
## cloud sync (ADRs 0016, 0017, 0019).

## Emitted when progress save data changes locally or after a cloud merge.
signal save_changed
## Emitted when device-local settings change.
signal settings_changed
## Emitted when a cloud pull merges new progress into the local save.
signal cloud_sync_merged

## Local file holding synced player progress and cached Full Game state.
const DEFAULT_SAVE_PATH := "user://save.json"
## Separate local file holding per-device settings that never syncs.
const DEFAULT_SETTINGS_PATH := "user://settings.json"
## Quiet window before pushing local save edits to an in-code cloud backend, in seconds.
const DEFAULT_PUSH_DEBOUNCE_S := 2.0

## The running Save/Settings autoload, set while in the tree.
static var instance: SaveSettingsService

var _save_path := DEFAULT_SAVE_PATH
var _settings_path := DEFAULT_SETTINGS_PATH
var _save := SaveData.new()
var _settings := SettingsData.new()
var _debouncer := CloudPushDebouncer.new(DEFAULT_PUSH_DEBOUNCE_S)
var _services: PlatformServicesService
var _cloud_pull_in_flight := false
var _cloud_pull_completed := false
var _cloud_push_in_flight := false
var _cloud_dirty := false


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if self == instance:
		_load_local_files()
		if PlatformServicesService.instance != null:
			sync_with_platform_services(PlatformServicesService.instance)


func _process(delta: float) -> void:
	if _debouncer.tick(delta):
		_push_cloud_now()


func _exit_tree() -> void:
	flush_cloud_push()
	disconnect_services()
	if instance == self:
		instance = null


func _notification(what: int) -> void:
	if (
		what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED
		or what == NOTIFICATION_APPLICATION_FOCUS_OUT
	):
		flush_cloud_push()


## Reconfigures file paths and debounce delay (used by tests to isolate disk writes),
## reloading from the configured paths.
func configure(
	save_path: String,
	settings_path: String,
	push_debounce_s: float = DEFAULT_PUSH_DEBOUNCE_S,
) -> void:
	_save_path = save_path
	_settings_path = settings_path
	_debouncer = CloudPushDebouncer.new(push_debounce_s)
	_cloud_pull_in_flight = false
	_cloud_pull_completed = false
	_cloud_push_in_flight = false
	_cloud_dirty = false
	_load_local_files()
	if _services != null:
		_reconcile_entitlement_cache()


## Connects to [param services], reconciles the cached [code]has_full_game()[/code] answer
## against the store's entitlement state, and pulls from cloud on [code]in_code[/code]
## backends.
func sync_with_platform_services(services: PlatformServicesService) -> void:
	assert(services != null, "SaveSettings requires PlatformServices")
	disconnect_services()
	_services = services
	_services.full_game_changed.connect(_on_full_game_changed)
	_services.full_game_check_finished.connect(_on_full_game_check_finished)
	_services.cloud_save_pulled.connect(_on_cloud_save_pulled)
	_services.cloud_save_pushed.connect(_on_cloud_save_pushed)
	_reconcile_entitlement_cache()
	if _services.cloud_capability() == StoreBackend.CloudCapability.IN_CODE:
		_start_cloud_pull()


## Disconnects from Platform Services and cancels any pending cloud sync state.
func disconnect_services() -> void:
	_debouncer.cancel()
	_cloud_pull_in_flight = false
	_cloud_pull_completed = false
	_cloud_push_in_flight = false
	_cloud_dirty = false
	if _services == null:
		return
	if _services.full_game_changed.is_connected(_on_full_game_changed):
		_services.full_game_changed.disconnect(_on_full_game_changed)
	if _services.full_game_check_finished.is_connected(_on_full_game_check_finished):
		_services.full_game_check_finished.disconnect(_on_full_game_check_finished)
	if _services.cloud_save_pulled.is_connected(_on_cloud_save_pulled):
		_services.cloud_save_pulled.disconnect(_on_cloud_save_pulled)
	if _services.cloud_save_pushed.is_connected(_on_cloud_save_pushed):
		_services.cloud_save_pushed.disconnect(_on_cloud_save_pushed)
	_services = null


## Returns a copy of the current progress save.
func save_data() -> SaveData:
	return _save.duplicate_data()


## Returns a copy of the current device-local settings.
func settings_data() -> SettingsData:
	return _settings.duplicate_data()


## Returns the cached [code]has_full_game()[/code] value stored on disk.
func cached_full_game() -> bool:
	return _save.cached_full_game


## Records [param level_id] as completed, saves locally, and schedules a debounced cloud
## push on [code]in_code[/code] stores.
func mark_level_completed(level_id: StringName) -> void:
	if not _save.add_completed_level(level_id):
		return
	_write_save_local()
	_schedule_cloud_push()
	save_changed.emit()


## Records [param modifier_id] as owned, saves locally, and schedules a debounced cloud
## push on [code]in_code[/code] stores.
func add_owned_modifier(modifier_id: StringName) -> void:
	if not _save.add_owned_modifier(modifier_id):
		return
	_write_save_local()
	_schedule_cloud_push()
	save_changed.emit()


## Records [param score] for [param board] if it beats the stored best. Returns true when
## a new best score was saved.
func record_best_score(board: StoreBackend.Leaderboard, score: int) -> bool:
	if not _save.record_score(board, score):
		return false
	_write_save_local()
	_schedule_cloud_push()
	save_changed.emit()
	return true


## Saves [param new_settings] to the separate per-device settings file. Never syncs to
## cloud saves.
func update_settings(new_settings: SettingsData) -> void:
	assert(new_settings != null, "update_settings requires a SettingsData")
	_settings = new_settings.duplicate_data()
	var err := SaveFileStore.write_bytes(_settings_path, _settings.to_bytes())
	if err != OK:
		push_error("Failed to write settings to %s: %s" % [_settings_path, error_string(err)])
	settings_changed.emit()


## Immediately pushes any pending or unsynced cloud save, if the backend supports in-code
## cloud saves.
func flush_cloud_push() -> void:
	var had_pending := _debouncer.flush()
	if had_pending or _cloud_dirty:
		_push_cloud_now()


## Returns whether a cloud push is currently scheduled or waiting to retry.
func is_cloud_push_pending() -> bool:
	return _debouncer.is_pending() or _cloud_dirty


func _load_local_files() -> void:
	var loaded_save := SaveData.from_bytes(SaveFileStore.read_bytes(_save_path))
	_save = loaded_save if loaded_save != null else SaveData.new()
	var loaded_settings := SettingsData.from_bytes(SaveFileStore.read_bytes(_settings_path))
	_settings = loaded_settings if loaded_settings != null else SettingsData.new()


func _write_save_local() -> void:
	var err := SaveFileStore.write_bytes(_save_path, _save.to_bytes())
	if err != OK:
		push_error("Failed to write save to %s: %s" % [_save_path, error_string(err)])


func _reconcile_entitlement_cache() -> void:
	_services.set_cached_full_game(_save.cached_full_game)
	if _services.is_store_entitlement_verified():
		_replace_cached_full_game(_services.store_has_full_game())


func _start_cloud_pull() -> void:
	if _cloud_pull_in_flight:
		return
	_cloud_pull_in_flight = true
	_services.pull_save()


func _schedule_cloud_push() -> void:
	if _services == null:
		return
	if _services.cloud_capability() != StoreBackend.CloudCapability.IN_CODE:
		return
	_cloud_dirty = true
	if not _cloud_pull_in_flight and not _cloud_push_in_flight:
		_debouncer.mark_dirty()


func _push_cloud_now() -> void:
	if _services == null:
		return
	if _services.cloud_capability() != StoreBackend.CloudCapability.IN_CODE:
		return
	if _cloud_pull_in_flight or _cloud_push_in_flight:
		_cloud_dirty = true
		return
	# Never overwrite remote cloud progress before an initial pull and merge has succeeded.
	if not _cloud_pull_completed:
		_cloud_dirty = true
		_start_cloud_pull()
		return
	_cloud_push_in_flight = true
	_cloud_dirty = false
	_services.push_save(_save.to_cloud_bytes())


func _replace_cached_full_game(unlocked: bool) -> void:
	if _services != null:
		_services.set_cached_full_game(unlocked)
	if _save.cached_full_game == unlocked:
		return
	_save.cached_full_game = unlocked
	_write_save_local()


func _on_full_game_check_finished(ok: bool, _unlocked: bool) -> void:
	if not ok or _services == null or not _services.is_store_entitlement_verified():
		return
	_replace_cached_full_game(_services.store_has_full_game())
	if _cloud_dirty and _services.cloud_capability() == StoreBackend.CloudCapability.IN_CODE:
		_schedule_cloud_push()


func _on_full_game_changed(_unlocked: bool) -> void:
	if _services == null or not _services.is_store_entitlement_verified():
		return
	_replace_cached_full_game(_services.store_has_full_game())


func _on_cloud_save_pulled(ok: bool, data: PackedByteArray) -> void:
	_cloud_pull_in_flight = false
	if not ok:
		return
	if data.is_empty():
		_cloud_pull_completed = true
		if _save.has_any_progress() or _cloud_dirty:
			_schedule_cloud_push()
		return
	var remote_save := SaveData.from_bytes(data)
	if remote_save == null:
		push_warning("Ignored unreadable or newer-version cloud save payload.")
		return
	_cloud_pull_completed = true
	var merged := SaveMerger.merge(_save, remote_save)
	var local_changed := not merged.progress_equals(_save)
	var remote_changed := not merged.progress_equals(remote_save)
	if local_changed:
		_save = merged
		_write_save_local()
		save_changed.emit()
		cloud_sync_merged.emit()
	if remote_changed or _cloud_dirty:
		_schedule_cloud_push()


func _on_cloud_save_pushed(ok: bool) -> void:
	_cloud_push_in_flight = false
	if not ok:
		_cloud_dirty = true
		return
	if _cloud_dirty:
		_schedule_cloud_push()
