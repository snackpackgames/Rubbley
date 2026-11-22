extends GdUnitTestSuite
## Invariants on shipped export presets in [code]export_presets.cfg[/code] (ADRs 0010,
## 0011, 0015, 0019, 0020): every store/platform pair exists, sets one [code]store_*[/code]
## feature tag, excludes tests and other stores' code/addons, and meets platform floors.

const PRESETS_PATH := "res://export_presets.cfg"

const EXPECTED_PRESETS: Dictionary[String, Dictionary] = {
	"web-playtest": { "platform": "Web", "store": "store_none" },
	"steam-windows": { "platform": "Windows Desktop", "store": "store_steam" },
	"steam-macos": { "platform": "macOS", "store": "store_steam" },
	"steam-linux": { "platform": "Linux", "store": "store_steam" },
	"epic-windows": { "platform": "Windows Desktop", "store": "store_epic" },
	"epic-macos": { "platform": "macOS", "store": "store_epic" },
	"itch-windows": { "platform": "Windows Desktop", "store": "store_itch" },
	"itch-macos": { "platform": "macOS", "store": "store_itch" },
	"itch-linux": { "platform": "Linux", "store": "store_itch" },
	"itch-web": { "platform": "Web", "store": "store_itch" },
	"ios": { "platform": "iOS", "store": "store_apple" },
	"android": { "platform": "Android", "store": "store_play" },
}

const STORE_EXCLUSIONS: Dictionary[String, Array] = {
	"store_steam": ["game/store/steam/*", "addons/godotsteam/*"],
	"store_epic": ["game/store/epic/*", "addons/epic-online-services-godot/*"],
	"store_apple": ["game/store/apple/*", "addons/GodotApplePlugins*/*"],
	"store_play": [
		"game/store/play/*",
		"addons/GodotGooglePlayBilling/*",
		"addons/GodotPlayGameServices/*",
	],
}

const BASE_EXCLUSIONS: Array[String] = ["test/*", "addons/gdUnit4/*", "reports/*"]


## Every store/platform preset exists (with no unexpected extras), uses all_resources,
## sets exactly one store_* feature tag, and excludes tests plus every other store.
func test_all_presets_exist_with_single_store_tag_and_exclusions() -> void:
	var cfg := _load_presets()
	var by_name := _index_presets(cfg)

	assert_int(by_name.size()).is_equal(EXPECTED_PRESETS.size())
	for preset_name: String in EXPECTED_PRESETS:
		var has_preset := by_name.has(preset_name)
		assert_bool(has_preset) \
				.override_failure_message("Missing preset: %s" % preset_name) \
				.is_true()
		if not has_preset:
			continue
		var section: String = by_name[preset_name]
		var expected: Dictionary = EXPECTED_PRESETS[preset_name]
		assert_str(str(cfg.get_value(section, "platform", ""))).is_equal(str(expected["platform"]))
		assert_str(str(cfg.get_value(section, "export_filter", ""))).is_equal("all_resources")

		var features := _split_csv(str(cfg.get_value(section, "custom_features", "")))
		var store_tags: Array[String] = []
		for tag in features:
			if tag.begins_with("store_"):
				store_tags.append(tag)
		assert_array(store_tags).contains_exactly([str(expected["store"])])

		var excluded := _split_csv(str(cfg.get_value(section, "exclude_filter", "")))
		for pattern in BASE_EXCLUSIONS:
			var msg := "%s must exclude %s" % [preset_name, pattern]
			assert_bool(excluded.has(pattern)).override_failure_message(msg).is_true()

		var own_store: String = str(expected["store"])
		for store_tag: String in STORE_EXCLUSIONS:
			var patterns: Array = STORE_EXCLUSIONS[store_tag]
			for raw_pattern: Variant in patterns:
				var pattern := str(raw_pattern)
				if store_tag == own_store:
					var msg := "%s must not exclude its own %s" % [preset_name, pattern]
					assert_bool(excluded.has(pattern)).override_failure_message(msg).is_false()
				else:
					var msg := "%s must exclude %s" % [preset_name, pattern]
					assert_bool(excluded.has(pattern)).override_failure_message(msg).is_true()


## Platform options and project settings match ADRs 0010, 0015 and 0020: Compatibility
## renderer, single-threaded web (itch-web desktop only), x86_64 Windows/Linux, universal
## macOS 14+, portrait iOS 17+, and Godot's default Android min SDK.
func test_platform_options_match_adrs() -> void:
	var cfg := _load_presets()
	var by_name := _index_presets(cfg)

	# Project-level renderer, mobile texture compression and handheld portrait lock.
	var desktop_renderer := str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	var mobile_key := "rendering/renderer/rendering_method.mobile"
	var mobile_renderer := str(ProjectSettings.get_setting(mobile_key))
	var etc2_key := "rendering/textures/vram_compression/import_etc2_astc"
	var etc2_astc: bool = ProjectSettings.get_setting(etc2_key) == true
	var portrait_locked: bool = (
		ProjectSettings.get_setting("display/window/handheld/orientation") == 1
	)
	assert_str(desktop_renderer).is_equal("gl_compatibility")
	assert_str(mobile_renderer).is_equal("gl_compatibility")
	assert_bool(etc2_astc).is_true()
	assert_bool(portrait_locked).is_true()

	# Web presets: single-threaded, no PWA; itch-web desktop only, web-playtest both.
	var itch_web := by_name["itch-web"] + ".options"
	_assert_opt_bool(cfg, itch_web, "variant/thread_support", false)
	_assert_opt_bool(cfg, itch_web, "progressive_web_app/enabled", false)
	_assert_opt_bool(cfg, itch_web, "vram_texture_compression/for_desktop", true)
	_assert_opt_bool(cfg, itch_web, "vram_texture_compression/for_mobile", false)

	var playtest := by_name["web-playtest"] + ".options"
	_assert_opt_bool(cfg, playtest, "variant/thread_support", false)
	_assert_opt_bool(cfg, playtest, "progressive_web_app/enabled", false)
	_assert_opt_bool(cfg, playtest, "vram_texture_compression/for_desktop", true)
	_assert_opt_bool(cfg, playtest, "vram_texture_compression/for_mobile", true)

	# Windows and Linux: x86_64 with embedded PCK.
	for name_key: String in [
		"steam-windows",
		"epic-windows",
		"itch-windows",
		"steam-linux",
		"itch-linux",
	]:
		var opts := by_name[name_key] + ".options"
		assert_str(str(cfg.get_value(opts, "binary_format/architecture", ""))).is_equal("x86_64")
		_assert_opt_bool(cfg, opts, "binary_format/embed_pck", true)

	# macOS: universal, min macOS 14.0.
	for name_key: String in ["steam-macos", "epic-macos", "itch-macos"]:
		var opts := by_name[name_key] + ".options"
		assert_str(str(cfg.get_value(opts, "binary_format/architecture", ""))).is_equal("universal")
		assert_str(str(cfg.get_value(opts, "application/min_macos_version_x86_64", ""))).is_equal(
			"14.0",
		)
		assert_str(str(cfg.get_value(opts, "application/min_macos_version_arm64", ""))).is_equal(
			"14.0",
		)

	# iOS: min iOS 17.0, arm64, project-only unsigned export with non-empty Team ID placeholder.
	var ios_opts := by_name["ios"] + ".options"
	assert_str(str(cfg.get_value(ios_opts, "application/min_ios_version", ""))).is_equal("17.0")
	assert_str(str(cfg.get_value(ios_opts, "application/app_store_team_id", ""))).is_not_empty()
	_assert_opt_bool(cfg, ios_opts, "application/export_project_only", true)
	_assert_opt_bool(cfg, ios_opts, "architectures/arm64", true)

	# Android: arm64-v8a and Godot's default min SDK (empty override).
	var android_opts := by_name["android"] + ".options"
	assert_str(str(cfg.get_value(android_opts, "gradle_build/min_sdk", "unset"))).is_empty()
	_assert_opt_bool(cfg, android_opts, "architectures/arm64-v8a", true)


func _assert_opt_bool(cfg: ConfigFile, opts: String, key: String, expected: bool) -> void:
	var fallback := not expected
	var actual: bool = cfg.get_value(opts, key, fallback) == true
	var msg := "%s %s expected %s" % [opts, key, expected]
	assert_bool(actual).override_failure_message(msg).is_equal(expected)


func _load_presets() -> ConfigFile:
	var cfg := ConfigFile.new()
	assert_int(cfg.load(PRESETS_PATH)).is_equal(OK)
	return cfg


func _index_presets(cfg: ConfigFile) -> Dictionary[String, String]:
	var index: Dictionary[String, String] = { }
	for section in cfg.get_sections():
		if section.ends_with(".options") or not section.begins_with("preset."):
			continue
		var preset_name := str(cfg.get_value(section, "name", ""))
		if not preset_name.is_empty():
			index[preset_name] = section
	return index


func _split_csv(text: String) -> Array[String]:
	var items: Array[String] = []
	for part in text.split(","):
		var trimmed := part.strip_edges()
		if not trimmed.is_empty():
			items.append(trimmed)
	return items
