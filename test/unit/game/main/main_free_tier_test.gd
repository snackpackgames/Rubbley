extends SimulationTestSuite
## End-to-end Free Tier gate, level switching, Unlock prompt and capability hiding in Main
## driven by [FakeStoreBackend] (ADRs 0015, 0019).

const MAIN_SCENE := preload("res://game/main/main.tscn")

var _original_backend: StoreBackend
var _original_force_free: bool


func before_test() -> void:
	_original_backend = PlatformServicesService.instance.backend()
	_original_force_free = PlatformServicesService.instance.is_force_free_tier()


func after_test() -> void:
	PlatformServicesService.instance.set_backend(_original_backend)
	PlatformServicesService.instance.set_force_free_tier(_original_force_free)


## Under Free Tier on a mobile store (unlock_purchase = true), picking the gated level
## opens the Unlock prompt with Purchase and Restore visible, and buying unlocks and loads it.
func test_gated_level_shows_unlock_prompt_and_purchase_loads_it() -> void:
	var fake := FakeStoreBackend.new(
		false,
		StoreCapabilities.from_flags(true, true, true, true),
		StoreBackend.CloudCapability.IN_CODE,
	)
	fake.next_purchase_result = StoreBackend.PurchaseResult.SUCCEEDED
	PlatformServicesService.instance.set_backend(fake)

	var main: Main = auto_free(MAIN_SCENE.instantiate())
	add_child(main)
	await get_tree().process_frame

	assert_str(String(main.current_level_id())).is_equal("sandbox_free")
	assert_bool(main.unlock_prompt.is_showing()).is_false()

	var gated_button := main.level_switcher.button_for_level(&"sandbox_gated")
	gated_button.pressed.emit()
	await get_tree().process_frame

	assert_str(String(main.current_level_id())).is_equal("sandbox_free")
	assert_bool(main.unlock_prompt.is_showing()).is_true()
	assert_bool(main.unlock_prompt.purchase_button.visible).is_true()
	assert_bool(main.unlock_prompt.restore_button.visible).is_true()

	main.unlock_prompt.purchase_button.pressed.emit()
	await get_tree().process_frame

	assert_bool(PlatformServicesService.instance.has_full_game()).is_true()
	assert_bool(main.unlock_prompt.is_showing()).is_false()
	assert_str(String(main.current_level_id())).is_equal("sandbox_gated")
	assert_bool(main.hud.is_watching()).is_true()


## Restore Purchases from the Unlock prompt restores the Full Game and loads the gated level.
func test_restore_from_unlock_prompt_loads_gated_level() -> void:
	var fake := FakeStoreBackend.new(false, StoreCapabilities.from_flags(false, false, true, false))
	fake.next_restore_result = StoreBackend.RestoreResult.RESTORED
	PlatformServicesService.instance.set_backend(fake)

	var main: Main = auto_free(MAIN_SCENE.instantiate())
	add_child(main)
	await get_tree().process_frame

	main.level_switcher.button_for_level(&"sandbox_gated").pressed.emit()
	await get_tree().process_frame
	main.unlock_prompt.restore_button.pressed.emit()
	await get_tree().process_frame

	assert_bool(main.unlock_prompt.is_showing()).is_false()
	assert_str(String(main.current_level_id())).is_equal("sandbox_gated")


## Cancelled, failed or offline purchase keeps the Unlock prompt open with status text and
## stays on the free level.
func test_cancel_failure_and_offline_keep_prompt_open_with_status() -> void:
	var fake := FakeStoreBackend.new(false, StoreCapabilities.from_flags(false, false, true, false))
	PlatformServicesService.instance.set_backend(fake)

	var main: Main = auto_free(MAIN_SCENE.instantiate())
	add_child(main)
	await get_tree().process_frame

	main.level_switcher.button_for_level(&"sandbox_gated").pressed.emit()
	await get_tree().process_frame

	fake.next_purchase_result = StoreBackend.PurchaseResult.CANCELLED
	main.unlock_prompt.purchase_button.pressed.emit()
	var cancel_text := main.unlock_prompt.status_label.text

	fake.next_purchase_result = StoreBackend.PurchaseResult.FAILED
	main.unlock_prompt.purchase_button.pressed.emit()
	var fail_text := main.unlock_prompt.status_label.text

	fake.offline = true
	main.unlock_prompt.purchase_button.pressed.emit()
	var offline_text := main.unlock_prompt.status_label.text

	assert_bool(main.unlock_prompt.is_showing()).is_true()
	assert_str(String(main.current_level_id())).is_equal("sandbox_free")
	assert_str(cancel_text).is_not_empty()
	assert_str(fail_text).is_not_empty()
	assert_str(offline_text).is_not_empty()


## Capability hiding: on itch.io/web (all capabilities false), Purchase, Restore,
## Leaderboard and Achievements controls are all hidden; when capabilities are enabled,
## the corresponding controls appear.
func test_ui_hides_controls_the_store_does_not_offer() -> void:
	var itch_like := NullStoreBackend.new(false)
	PlatformServicesService.instance.set_backend(itch_like)

	var main: Main = auto_free(MAIN_SCENE.instantiate())
	add_child(main)
	await get_tree().process_frame

	assert_bool(main.level_switcher.leaderboard_button.visible).is_false()
	assert_bool(main.level_switcher.achievements_button.visible).is_false()

	main.level_switcher.button_for_level(&"sandbox_gated").pressed.emit()
	await get_tree().process_frame

	assert_bool(main.unlock_prompt.is_showing()).is_true()
	assert_bool(main.unlock_prompt.purchase_button.visible).is_false()
	assert_bool(main.unlock_prompt.restore_button.visible).is_false()

	var rich_store := FakeStoreBackend.new(
		true,
		StoreCapabilities.from_flags(true, true, false, true),
		StoreBackend.CloudCapability.FILE_SYNC,
	)
	PlatformServicesService.instance.set_backend(rich_store)
	await get_tree().process_frame

	assert_bool(main.level_switcher.leaderboard_button.visible).is_true()
	assert_bool(main.level_switcher.achievements_button.visible).is_true()


## Under Full Game, switching to the gated sandbox loads it immediately without showing the prompt.
func test_full_game_switches_directly_to_gated_sandbox() -> void:
	PlatformServicesService.instance.set_backend(NullStoreBackend.new(true))

	var main: Main = auto_free(MAIN_SCENE.instantiate())
	add_child(main)
	await get_tree().process_frame

	main.level_switcher.button_for_level(&"sandbox_gated").pressed.emit()
	await get_tree().process_frame

	assert_bool(main.unlock_prompt.is_showing()).is_false()
	assert_str(String(main.current_level_id())).is_equal("sandbox_gated")
	assert_bool(main.hud.is_watching()).is_true()
