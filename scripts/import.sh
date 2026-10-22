#!/usr/bin/env bash
# Runs Godot's headless import: rebuilds the .godot/ cache, the global class
# cache and the .uid files. Run it after adding a scene, script or class_name.
#
#   scripts/import.sh

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/env.sh
source "$root/scripts/env.sh"
if [ -z "${GODOT_BIN:-}" ]; then
	exit 1
fi

"$GODOT_BIN" --headless --path "$root" --import
