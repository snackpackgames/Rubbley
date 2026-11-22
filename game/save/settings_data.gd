class_name SettingsData
extends RefCounted
## Per-device player settings stored in a separate local file that never syncs to cloud
## saves (ADR 0019).

## Current serialized settings format version.
const FORMAT_VERSION := 1

## Master audio volume, from 0 to 1.
var master_volume := 1.0
## Music audio volume, from 0 to 1.
var music_volume := 1.0
## Sound effects audio volume, from 0 to 1.
var sfx_volume := 1.0
## Whether reduced-motion presentation is enabled on this device.
var reduced_motion := false


## Parses UTF-8 JSON bytes into a [SettingsData], or returns null if empty, malformed or
## from an unsupported future format version.
static func from_bytes(bytes: PackedByteArray) -> SettingsData:
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
	var data := SettingsData.new()
	data.master_volume = _read_unit_float(root.get("master_volume"), data.master_volume)
	data.music_volume = _read_unit_float(root.get("music_volume"), data.music_volume)
	data.sfx_volume = _read_unit_float(root.get("sfx_volume"), data.sfx_volume)
	var reduced: Variant = root.get("reduced_motion")
	if reduced is bool:
		data.reduced_motion = reduced
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


static func _read_unit_float(raw: Variant, fallback: float) -> float:
	if raw is float or raw is int:
		@warning_ignore("unsafe_cast") # Guarded by `is float or is int` immediately above.
		var value := raw as float
		if is_finite(value):
			return clampf(value, 0.0, 1.0)
	return fallback


static func _clamp_unit(value: float, fallback: float) -> float:
	if not is_finite(value):
		return fallback
	return clampf(value, 0.0, 1.0)


## Returns a deep copy of this [SettingsData] with volume fields normalized to [0, 1].
func duplicate_data() -> SettingsData:
	var copy := SettingsData.new()
	copy.master_volume = _clamp_unit(master_volume, 1.0)
	copy.music_volume = _clamp_unit(music_volume, 1.0)
	copy.sfx_volume = _clamp_unit(sfx_volume, 1.0)
	copy.reduced_motion = reduced_motion
	return copy


## Serializes settings to UTF-8 JSON bytes.
func to_bytes() -> PackedByteArray:
	var normalized := duplicate_data()
	return (JSON.stringify({
			"version": FORMAT_VERSION,
			"master_volume": normalized.master_volume,
			"music_volume": normalized.music_volume,
			"sfx_volume": normalized.sfx_volume,
			"reduced_motion": normalized.reduced_motion,
		}).to_utf8_buffer())
