class_name StoreBackendSelector
extends RefCounted
## Picks which [StoreBackend] to load from the build's [code]store_*[/code] feature tag
## (ADR 0019) and checks whether editor/debug builds requested forced Free Tier on the
## command line. Loads backends by path so export presets excluding other stores' folders
## never parse them.

## Feature tag for Steam builds.
const FEATURE_STEAM := "store_steam"
## Feature tag for Epic Games Store builds.
const FEATURE_EPIC := "store_epic"
## Feature tag for Apple App Store builds.
const FEATURE_APPLE := "store_apple"
## Feature tag for Google Play builds.
const FEATURE_PLAY := "store_play"
## Feature tag for itch.io Free Tier builds.
const FEATURE_ITCH := "store_itch"
## Feature tag for Full Game builds with no store (Playtest Build).
const FEATURE_NONE := "store_none"

## Script path for the Steam backend.
const PATH_STEAM := "res://game/store/steam/steam_store_backend.gd"
## Script path for the Epic backend.
const PATH_EPIC := "res://game/store/epic/epic_store_backend.gd"
## Script path for the Apple backend.
const PATH_APPLE := "res://game/store/apple/apple_store_backend.gd"
## Script path for the Google Play backend.
const PATH_PLAY := "res://game/store/play/play_store_backend.gd"
## Script path for the Null backend.
const PATH_NULL := "res://game/store/null_store_backend.gd"

## Command-line switch forcing Free Tier in editor and debug builds (ADR 0019).
const FORCE_FREE_TIER_ARG := "--free-tier"


## Returns true only in editor or debug builds when [constant FORCE_FREE_TIER_ARG] is
## present among [param cmdline_args]. Release builds always ignore it.
static func is_force_free_tier_requested(
	cmdline_args: PackedStringArray,
	is_debug_or_editor: bool,
) -> bool:
	if not is_debug_or_editor:
		return false
	for arg in cmdline_args:
		if arg == FORCE_FREE_TIER_ARG:
			return true
	return false


## Returns the [StoreBackend] script path matching the first set [code]store_*[/code]
## feature tag, falling back to [constant PATH_NULL].
static func backend_path_for_features(has_feature: Callable) -> String:
	if has_feature.call(FEATURE_STEAM) == true:
		return PATH_STEAM
	if has_feature.call(FEATURE_EPIC) == true:
		return PATH_EPIC
	if has_feature.call(FEATURE_APPLE) == true:
		return PATH_APPLE
	if has_feature.call(FEATURE_PLAY) == true:
		return PATH_PLAY
	return PATH_NULL


## Returns true when the feature tags select the Free Tier Null backend
## ([constant FEATURE_ITCH] without a real store tag).
static func is_free_tier_null(has_feature: Callable) -> bool:
	return (
		backend_path_for_features(has_feature) == PATH_NULL
		and has_feature.call(FEATURE_ITCH) == true
	)


## Loads and instantiates the matching [StoreBackend] by path via [param load_script], so
## no store script is preloaded at compile time.
static func create_backend(has_feature: Callable, load_script: Callable) -> StoreBackend:
	var path := backend_path_for_features(has_feature)
	var loaded: Variant = load_script.call(path)
	assert(loaded is GDScript, "StoreBackend script missing at %s" % path)
	@warning_ignore("unsafe_cast") # Dynamic path loading avoids preloading other stores.
	var script := loaded as GDScript
	if path == PATH_NULL:
		var full_game := not is_free_tier_null(has_feature)
		var null_instance: Variant = script.new(full_game)
		assert(null_instance is StoreBackend, "Null backend must extend StoreBackend")
		@warning_ignore("unsafe_cast") # Dynamic script instantiation returns Variant.
		return null_instance as StoreBackend
	var instance: Variant = script.new()
	assert(instance is StoreBackend, "Backend at %s must extend StoreBackend" % path)
	@warning_ignore("unsafe_cast") # Dynamic script instantiation returns Variant.
	return instance as StoreBackend
