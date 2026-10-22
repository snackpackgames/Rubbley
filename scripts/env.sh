#!/usr/bin/env bash
# Sets the environment Rubbley's scripts need. Source it, don't run it:
#
#   source scripts/env.sh            # find Godot and export GODOT_BIN
#   source scripts/env.sh --install  # download the pinned Godot first if it's missing
#
# GODOT_BIN must point at the exact Godot version in .godot-version (ADR 0004).
# Lookup order: an existing GODOT_BIN, `godot` on PATH, then .tools/godot/<version>/.
# On Windows the console build is preferred, so headless runs print to the terminal.

_rubbley_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_rubbley_version="$(tr -d '[:space:]' 2>/dev/null < "$_rubbley_root/.godot-version")"
if [ -z "$_rubbley_version" ]; then
	echo "Missing $_rubbley_root/.godot-version" >&2
	unset _rubbley_root _rubbley_version
	return 1
fi
_rubbley_tools="$_rubbley_root/.tools/godot/$_rubbley_version"

_rubbley_matches() {
	[ -n "$1" ] && [ -x "$1" ] && "$1" --version 2>/dev/null | grep -q "^${_rubbley_version}\.stable"
}

_rubbley_find_in_tools() {
	find "$_rubbley_tools" -maxdepth 4 -type f \
		\( -name "*_console.exe" -o -name "*.x86_64" -o -name "Godot" \) 2>/dev/null \
		| sort | head -n 1
}

_rubbley_install() {
	local asset
	case "$(uname -s)" in
		MINGW* | MSYS* | CYGWIN*) asset="Godot_v${_rubbley_version}-stable_win64.exe.zip" ;;
		Darwin) asset="Godot_v${_rubbley_version}-stable_macos.universal.zip" ;;
		*) asset="Godot_v${_rubbley_version}-stable_linux.x86_64.zip" ;;
	esac
	local url="https://github.com/godotengine/godot/releases/download/${_rubbley_version}-stable/${asset}"
	echo "Downloading Godot ${_rubbley_version} from ${url}" >&2
	mkdir -p "$_rubbley_tools" &&
		curl -fL --progress-bar -o "$_rubbley_tools/$asset" "$url" &&
		unzip -q -o "$_rubbley_tools/$asset" -d "$_rubbley_tools" &&
		rm -f "$_rubbley_tools/$asset"
}

_rubbley_candidate=""
for _rubbley_c in "${GODOT_BIN:-}" "$(command -v godot 2>/dev/null)" "$(_rubbley_find_in_tools)"; do
	if _rubbley_matches "$_rubbley_c"; then
		_rubbley_candidate="$_rubbley_c"
		break
	fi
done

if [ -z "$_rubbley_candidate" ] && [ "${1:-}" = "--install" ]; then
	_rubbley_install && _rubbley_candidate="$(_rubbley_find_in_tools)"
	_rubbley_matches "$_rubbley_candidate" || _rubbley_candidate=""
fi

if [ -n "$_rubbley_candidate" ]; then
	export GODOT_BIN="$_rubbley_candidate"
	echo "GODOT_BIN=$GODOT_BIN" >&2
else
	unset GODOT_BIN
	echo "No Godot ${_rubbley_version} found. Run: source scripts/env.sh --install" >&2
fi

unset _rubbley_root _rubbley_version _rubbley_tools _rubbley_candidate _rubbley_c
unset -f _rubbley_matches _rubbley_find_in_tools _rubbley_install
