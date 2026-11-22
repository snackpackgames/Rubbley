extends GdUnitTestSuite
## Trailing debounce timer for [constant StoreBackend.CloudCapability.IN_CODE] cloud pushes
## (ADR 0019).


## Coalesces rapid dirty marks into a single push after the quiet window.
func test_coalesces_rapid_saves_until_quiet_window_elapses() -> void:
	var debouncer := CloudPushDebouncer.new(1.0)
	assert_bool(debouncer.tick(5.0)).is_false()

	debouncer.mark_dirty()
	assert_bool(debouncer.tick(0.6)).is_false()
	debouncer.mark_dirty()
	assert_bool(debouncer.tick(0.6)).is_false()
	assert_bool(debouncer.is_pending()).is_true()
	assert_bool(debouncer.tick(0.45)).is_true()
	assert_bool(debouncer.is_pending()).is_false()
	assert_bool(debouncer.tick(5.0)).is_false()


## Flushing fires immediately when dirty and does nothing when clean.
func test_flush_and_cancel() -> void:
	var debouncer := CloudPushDebouncer.new(2.0)
	assert_bool(debouncer.flush()).is_false()
	debouncer.mark_dirty()
	assert_bool(debouncer.flush()).is_true()
	assert_bool(debouncer.is_pending()).is_false()

	debouncer.mark_dirty()
	debouncer.cancel()
	assert_bool(debouncer.is_pending()).is_false()
	assert_bool(debouncer.tick(5.0)).is_false()
