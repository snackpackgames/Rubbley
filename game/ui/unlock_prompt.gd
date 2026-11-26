class_name UnlockPrompt
extends CanvasLayer
## Modal prompt in Main's UI layer shown when a Free Tier player tries to load a gated
## level (ADRs 0015, 0019). Explains how to get the Full Game and shows Purchase Unlock
## and Restore Purchases only on stores whose [member StoreCapabilities.unlock_purchase]
## flag is true.

## Emitted when the player presses the Purchase Unlock button.
signal purchase_requested
## Emitted when the player presses the Restore Purchases button.
signal restore_requested
## Emitted when the player dismisses the prompt.
signal dismissed

## Root panel toggled when the prompt opens or closes.
@export var backdrop: Control
## Heading label naming the gated level.
@export var title_label: Label
## Body label explaining how to get the Full Game.
@export var message_label: Label
## Status label showing purchase or restore feedback.
@export var status_label: Label
## Button starting the single one-time Unlock purchase; hidden when the store lacks it.
@export var purchase_button: Button
## Button restoring an earlier Unlock purchase; hidden when the store lacks it.
@export var restore_button: Button
## Button closing the prompt.
@export var close_button: Button


func _ready() -> void:
	assert(backdrop != null, "%s needs a backdrop" % name)
	assert(
		title_label != null and message_label != null,
		"%s needs title and message labels" % name,
	)
	assert(status_label != null, "%s needs a status_label" % name)
	assert(
		purchase_button != null and restore_button != null and close_button != null,
		"%s needs purchase, restore and close buttons" % name,
	)
	purchase_button.pressed.connect(_on_purchase_pressed)
	restore_button.pressed.connect(_on_restore_pressed)
	close_button.pressed.connect(_on_close_pressed)
	backdrop.visible = false


## Opens the prompt for [param level_name], showing Purchase and Restore buttons only
## when [param capabilities] supports [member StoreCapabilities.unlock_purchase].
func show_for_level(level_name: String, capabilities: StoreCapabilities) -> void:
	title_label.text = "%s — Full Game" % level_name
	if capabilities.unlock_purchase:
		message_label.text = (
			"%s is part of the Full Game.\nBuy the one-time Unlock or restore a previous purchase."
			% level_name
		)
	else:
		message_label.text = (
			"%s is part of the Full Game.\nGet the Full Game on Steam or Epic to play every level."
			% level_name
		)
	status_label.text = ""
	purchase_button.visible = capabilities.unlock_purchase
	restore_button.visible = capabilities.unlock_purchase
	backdrop.visible = true


## Hides the prompt without emitting [signal dismissed].
func hide_prompt() -> void:
	backdrop.visible = false


## Returns whether the prompt is currently visible.
func is_showing() -> bool:
	return backdrop.visible


## Shows player-facing feedback for an Unlock purchase outcome.
func show_purchase_result(result: StoreBackend.PurchaseResult) -> void:
	match result:
		StoreBackend.PurchaseResult.SUCCEEDED:
			status_label.text = "Full Game unlocked."
		StoreBackend.PurchaseResult.CANCELLED:
			status_label.text = "Purchase cancelled."
		StoreBackend.PurchaseResult.OFFLINE:
			status_label.text = "Store unavailable while offline."
		StoreBackend.PurchaseResult.FAILED:
			status_label.text = "Purchase failed. Please try again."


## Shows player-facing feedback for a Restore Purchases outcome.
func show_restore_result(result: StoreBackend.RestoreResult) -> void:
	match result:
		StoreBackend.RestoreResult.RESTORED:
			status_label.text = "Full Game restored."
		StoreBackend.RestoreResult.NOTHING_TO_RESTORE:
			status_label.text = "No previous Unlock found."
		StoreBackend.RestoreResult.OFFLINE:
			status_label.text = "Store unavailable while offline."
		StoreBackend.RestoreResult.FAILED:
			status_label.text = "Restore failed. Please try again."


func _on_purchase_pressed() -> void:
	status_label.text = ""
	purchase_requested.emit()


func _on_restore_pressed() -> void:
	status_label.text = ""
	restore_requested.emit()


func _on_close_pressed() -> void:
	backdrop.visible = false
	dismissed.emit()
