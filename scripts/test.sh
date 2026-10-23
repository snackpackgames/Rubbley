#!/usr/bin/env bash
# Runs the gdUnit4 test suites (ADR 0011). Agents and CI run tests only through
# it, never by assembling Godot flags by hand: Godot ignores unknown flags.
#
#   scripts/test.sh          # both suites
#   scripts/test.sh unit     # test/unit/, headless
#   scripts/test.sh input    # test/input/, under a display (xvfb in CI)
#   scripts/test.sh <path>   # one test file or directory under test/unit/ or test/input/
#
# Godot must match .godot-version. It imports the project first, then runs
# each suite with --fixed-fps equal to the physics tick rate, so physics ticks
# have a fixed delta and headless runs go as fast as the CPU allows (ADR 0018).
# Exits non-zero on any failure, and on gdUnit4's warnings exit code (101), so
# warnings can't pile up. Reports go to reports/<suite>/.

set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root" || exit 1

usage() {
	echo "Usage: scripts/test.sh [unit | input | <path under test/unit/ or test/input/>]" >&2
	exit 2
}

# Each run is a suite name and the res:// path gdUnit4 adds to the run.
runs=()
case "${1:-}" in
	"") runs=("unit res://test/unit" "input res://test/input") ;;
	unit | input) runs=("$1 res://test/$1") ;;
	-h | --help) usage ;;
	*)
		path="${1#res://}"
		path="${path%/}"
		if [ ! -e "$path" ]; then
			echo "No such test path: $path" >&2
			exit 2
		fi
		case "$path" in
			test/unit | test/unit/*) runs=("unit res://$path") ;;
			test/input | test/input/*) runs=("input res://$path") ;;
			*) usage ;;
		esac
		;;
esac
[ $# -le 1 ] || usage

# --- Godot -------------------------------------------------------------------

# shellcheck source=scripts/env.sh
source "$root/scripts/env.sh"
if [ -z "${GODOT_BIN:-}" ]; then
	exit 1
fi

echo "== Import" >&2
"$GODOT_BIN" --headless --path "$root" --import >/dev/null || exit 1

# Godot's default when project.godot doesn't set it.
tick_rate="$(sed -n 's|^common/physics_ticks_per_second=\([0-9][0-9]*\)$|\1|p' project.godot)"
tick_rate="${tick_rate:-60}"

# --- Suites ------------------------------------------------------------------

failed=()
for run in "${runs[@]}"; do
	suite="${run%% *}"
	path="${run#* }"
	# Godot doesn't deliver InputEvents under --headless, so only unit runs there.
	if [ "$suite" = "unit" ]; then
		mode_args=(--headless --ignoreHeadlessMode)
	else
		mode_args=(--audio-driver Dummy)
	fi

	echo "== Test $suite: $path (--fixed-fps $tick_rate)" >&2
	bash addons/gdUnit4/runtest.sh --godot_binary "$GODOT_BIN" \
		"${mode_args[@]}" --fixed-fps "$tick_rate" \
		-a "$path" -c -rd "res://reports/$suite"
	status=$?
	case "$status" in
		0) ;;
		101) failed+=("$suite (warnings)") ;;
		*) failed+=("$suite (exit $status)") ;;
	esac
done

# --- Result ------------------------------------------------------------------

if [ "${#failed[@]}" -gt 0 ]; then
	echo "Tests failed: ${failed[*]}" >&2
	exit 1
fi
echo "All tests passed" >&2
