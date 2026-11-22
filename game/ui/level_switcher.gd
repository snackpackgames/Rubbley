class_name LevelSwitcher
extends CanvasLayer
## Minimal level switcher in Main's UI layer (ADR 0016, 0019). Lists the available
## sandbox levels, marks gated levels while under the Free Tier, and hides store buttons
## that the active store's capabilities do not offer.

## Emitted when the player picks a level button.
signal level_selected(entry: LevelEntry)

## Container holding the level buttons.
@export var level_buttons_container: HBoxContainer
## Placeholder button for the store leaderboard, hidden when
## [member StoreCapabilities.leaderboards] is false.
@export var leaderboard_button: Button
## Placeholder button for store achievements, hidden when
## [member StoreCapabilities.achievements] is false.
@export var achievements_button: Button

var _entries: Array[LevelEntry] = []
var _buttons_by_id: Dictionary[StringName, Button] = { }


func _ready() -> void:
	assert(level_buttons_container != null, "%s needs a level_buttons_container" % name)
	assert(leaderboard_button != null, "%s needs a leaderboard_button" % name)
	assert(achievements_button != null, "%s needs an achievements_button" % name)


## Populates the switcher with [param entries] and applies [param gate],
## [param active_level_id] and [param capabilities].
func setup(
	entries: Array[LevelEntry],
	gate: FreeTierGate,
	active_level_id: StringName,
	capabilities: StoreCapabilities,
) -> void:
	_entries = entries.duplicate()
	_rebuild_buttons()
	refresh(gate, active_level_id, capabilities)


## Updates button labels, active state and store-capability visibility without rebuilding
## the buttons.
func refresh(
	gate: FreeTierGate,
	active_level_id: StringName,
	capabilities: StoreCapabilities,
) -> void:
	for entry in _entries:
		var button: Button = _buttons_by_id.get(entry.id)
		if button == null:
			continue
		var allowed := gate.can_play_level(entry.id)
		var label := entry.display_name if allowed else "%s (Locked)" % entry.display_name
		button.text = label
		button.disabled = entry.id == active_level_id
	leaderboard_button.visible = capabilities.leaderboards
	achievements_button.visible = capabilities.achievements


## Returns the button created for [param level_id], or null if not present.
func button_for_level(level_id: StringName) -> Button:
	return _buttons_by_id.get(level_id)


func _rebuild_buttons() -> void:
	for child in level_buttons_container.get_children():
		level_buttons_container.remove_child(child)
		child.queue_free()
	_buttons_by_id.clear()
	for entry in _entries:
		var button := Button.new()
		button.name = String(entry.id)
		button.text = entry.display_name
		button.pressed.connect(_on_level_button_pressed.bind(entry))
		level_buttons_container.add_child(button)
		_buttons_by_id[entry.id] = button


func _on_level_button_pressed(entry: LevelEntry) -> void:
	level_selected.emit(entry)
