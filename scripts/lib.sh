#!/usr/bin/env bash
# Helpers shared by Rubbley's scripts. Source it; it only defines functions.
#
#   source scripts/lib.sh

# Prints the version pinned in a version file, such as .godot-version.
rubbley_read_pin() {
	local pin
	pin="$(tr -d '[:space:]' 2>/dev/null < "$1")"
	if [ -z "$pin" ]; then
		echo "Missing $1" >&2
		return 1
	fi
	echo "$pin"
}

# Prints the host OS: windows, macos or linux.
rubbley_os() {
	case "$(uname -s)" in
		MINGW* | MSYS* | CYGWIN*) echo "windows" ;;
		Darwin) echo "macos" ;;
		*) echo "linux" ;;
	esac
}

# Prints the host CPU: x86_64 or aarch64.
rubbley_arch() {
	case "$(uname -m)" in
		arm64 | aarch64) echo "aarch64" ;;
		*) echo "x86_64" ;;
	esac
}

# Downloads the zip at a URL and unpacks it into a directory.
rubbley_fetch_zip() {
	local url="$1" dir="$2"
	local zip="$dir/${url##*/}"
	echo "Downloading ${url}" >&2
	mkdir -p "$dir" &&
		curl -fL --progress-bar -o "$zip" "$url" &&
		unzip -q -o "$zip" -d "$dir" &&
		rm -f "$zip"
}
