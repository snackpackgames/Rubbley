class_name Main
extends Node
## The persistent root scene. It owns the current level and swaps levels in and
## out as its children, so nothing calls [code]change_scene_to_file[/code] (ADR 0016).
## It owns the UI layer too, which outlives levels: the HUD, the minimal level switcher
## and the Free Tier Unlock prompt (ADRs 0015, 0019).

## The level loaded when the game starts (fallback when [member level_catalog] is empty).
@export var start_level: PackedScene
## Ordered levels offered by the level switcher. The first entry loads at startup.
@export var level_catalog: LevelCatalog
## The always-free levels list checked by the [FreeTierGate] (ADR 0015).
@export var free_levels: FreeLevelsList
## The HUD, in the UI layer.
@export var hud: Hud
## The minimal level switcher, in the UI layer.
@export var level_switcher: LevelSwitcher
## The Unlock prompt shown when a gated level is picked under the Free Tier.
@export var unlock_prompt: UnlockPrompt

var _level: Node
var _current_level_id: StringName
var _pending_gated_entry: LevelEntry
var _gate: FreeTierGate


func _ready() -> void:
	assert(hud != null, "%s needs a Hud" % name)
	var free_ids: Array[StringName] = free_levels.free_level_ids if free_levels != null else []
	_gate = FreeTierGate.new(PlatformServicesService.instance.has_full_game, free_ids)
	PlatformServicesService.instance.full_game_changed.connect(_on_full_game_changed)
	PlatformServicesService.instance.unlock_purchase_finished.connect(_on_unlock_purchase_finished)
	PlatformServicesService.instance.restore_purchases_finished.connect(
		_on_restore_purchases_finished,
	)
	if unlock_prompt != null:
		unlock_prompt.purchase_requested.connect(_on_purchase_requested)
		unlock_prompt.restore_requested.connect(_on_restore_requested)
		unlock_prompt.dismissed.connect(_on_unlock_prompt_dismissed)
	if level_switcher != null:
		level_switcher.level_selected.connect(select_level)
	var entries := _catalog_entries()
	if not entries.is_empty():
		var first := entries[0]
		_current_level_id = first.id
		if level_switcher != null:
			level_switcher.setup(
				entries,
				_gate,
				_current_level_id,
				PlatformServicesService.instance.capabilities(),
			)
		load_level(first.scene)
	else:
		load_level(start_level)


func _exit_tree() -> void:
	if PlatformServicesService.instance == null:
		return
	if PlatformServicesService.instance.full_game_changed.is_connected(_on_full_game_changed):
		PlatformServicesService.instance.full_game_changed.disconnect(_on_full_game_changed)
	if PlatformServicesService.instance.unlock_purchase_finished.is_connected(
		_on_unlock_purchase_finished,
	):
		PlatformServicesService.instance.unlock_purchase_finished.disconnect(
			_on_unlock_purchase_finished,
		)
	if PlatformServicesService.instance.restore_purchases_finished.is_connected(
		_on_restore_purchases_finished,
	):
		PlatformServicesService.instance.restore_purchases_finished.disconnect(
			_on_restore_purchases_finished,
		)


## Frees the current level, if any, and adds a new instance of [param level_scene] as a
## child, and points the HUD at its Rubbley. Unloading a level interrupts Move Input
## (ADR 0013).
func load_level(level_scene: PackedScene) -> void:
	assert(level_scene != null, "load_level needs a level scene")
	if _level != null:
		hud.unwatch()
		MoveInputService.instance.interrupt()
		remove_child(_level)
		_level.queue_free()
	_level = level_scene.instantiate()
	add_child(_level)
	var level := _level as Level
	if level != null and level.rubbley_mass != null:
		hud.watch(level.rubbley_mass)


## Attempts to switch to [param entry]. Loads it when [FreeTierGate] allows it; otherwise
## interrupts Move Input and opens the Unlock prompt with the store's capabilities.
func select_level(entry: LevelEntry) -> void:
	assert(entry != null, "select_level needs a LevelEntry")
	if _gate.can_play_level(entry.id):
		_pending_gated_entry = null
		if unlock_prompt != null:
			unlock_prompt.hide_prompt()
		_current_level_id = entry.id
		load_level(entry.scene)
		_refresh_switcher()
		return
	_pending_gated_entry = entry
	MoveInputService.instance.interrupt()
	if unlock_prompt != null:
		unlock_prompt.show_for_level(
			entry.display_name,
			PlatformServicesService.instance.capabilities(),
		)


## Returns the id of the currently loaded level entry, if loaded from the catalog.
func current_level_id() -> StringName:
	return _current_level_id


## Returns the [FreeTierGate] guarding level switches.
func free_tier_gate() -> FreeTierGate:
	return _gate


func _catalog_entries() -> Array[LevelEntry]:
	if level_catalog == null:
		return []
	return level_catalog.entries


func _refresh_switcher() -> void:
	if level_switcher != null:
		level_switcher.refresh(
			_gate,
			_current_level_id,
			PlatformServicesService.instance.capabilities(),
		)


func _on_purchase_requested() -> void:
	PlatformServicesService.instance.purchase_unlock()


func _on_restore_requested() -> void:
	PlatformServicesService.instance.restore_purchases()


func _on_unlock_prompt_dismissed() -> void:
	_pending_gated_entry = null


func _on_full_game_changed(unlocked: bool) -> void:
	_refresh_switcher()
	if (
		unlocked and _pending_gated_entry != null
		and unlock_prompt != null and unlock_prompt.is_showing()
	):
		var target := _pending_gated_entry
		select_level(target)


func _on_unlock_purchase_finished(result: StoreBackend.PurchaseResult) -> void:
	if unlock_prompt != null and unlock_prompt.is_showing():
		unlock_prompt.show_purchase_result(result)


func _on_restore_purchases_finished(result: StoreBackend.RestoreResult) -> void:
	if unlock_prompt != null and unlock_prompt.is_showing():
		unlock_prompt.show_restore_result(result)
