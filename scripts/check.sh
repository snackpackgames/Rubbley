#!/usr/bin/env bash
# Runs every GDScript quality gate (ADR 0014). Agents run it before every
# commit, and CI runs it in the required PR check.
#
#   scripts/check.sh        # compile, format check and lint
#   scripts/check.sh --fix  # apply the formatter instead of checking format
#
# Gates: Godot's --check-only with warnings as errors, then the GDQuest
# formatter (pinned in .gdscript-formatter-version) and its lint, which runs
# every rule: none contradicts the official style guide at 0.27.0. Every .gd
# in the Godot project is checked except vendored addons/. Exits non-zero if
# any gate fails.

set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root" || exit 1

fix=false
case "${1:-}" in
	"") ;;
	--fix) fix=true ;;
	*)
		echo "Usage: scripts/check.sh [--fix]" >&2
		exit 2
		;;
esac

failed=()

# --- Godot -------------------------------------------------------------------

# env.sh also sources scripts/lib.sh.
# shellcheck source=scripts/env.sh
source "$root/scripts/env.sh"
if [ -z "${GODOT_BIN:-}" ]; then
	exit 1
fi

echo "== Import" >&2
"$GODOT_BIN" --headless --path "$root" --import >/dev/null || failed+=("import")

# unity/ and prototypes/ hold other projects; addons/ is vendored code.
scripts=()
while IFS= read -r script; do
	scripts+=("$script")
done < <(
	find . \( -path ./addons -o -path ./unity -o -path ./prototypes -o -path ./.godot \
		-o -path ./.tools -o -path ./.git -o -path ./.claude \) -prune \
		-o -type f -name "*.gd" -print | sed 's|^\./||' | sort
)
if [ "${#scripts[@]}" -eq 0 ]; then
	echo "No .gd files found" >&2
	exit 1
fi

echo "== Compile (${#scripts[@]} scripts)" >&2
compile_failed=false
for script in "${scripts[@]}"; do
	if ! "$GODOT_BIN" --headless --path "$root" --check-only --script "res://$script" >/dev/null; then
		echo "Compile failed: $script" >&2
		compile_failed=true
	fi
done
$compile_failed && failed+=("compile")

# --- Formatter ---------------------------------------------------------------

formatter_version="$(rubbley_read_pin "$root/.gdscript-formatter-version")" || exit 1
formatter_dir="$root/.tools/gdscript-formatter/$formatter_version"

# Release assets are named by rubbley_os and rubbley_arch, plus .exe on Windows.
os="$(rubbley_os)"
formatter_name="gdscript-formatter-${formatter_version}-${os}-$(rubbley_arch)"
[ "$os" = "windows" ] && formatter_name+=".exe"
formatter="$formatter_dir/$formatter_name"

if [ ! -x "$formatter" ]; then
	rubbley_fetch_zip \
		"https://github.com/GDQuest/GDScript-formatter/releases/download/${formatter_version}/${formatter_name}.zip" \
		"$formatter_dir" &&
		chmod +x "$formatter"
fi
if ! "$formatter" --version 2>/dev/null | grep -qx "gdscript-formatter ${formatter_version}"; then
	echo "No GDScript formatter ${formatter_version} at $formatter" >&2
	exit 1
fi

if $fix; then
	echo "== Format (fix)" >&2
	"$formatter" --reorder-code "${scripts[@]}" || failed+=("format")
else
	echo "== Format" >&2
	"$formatter" --check --reorder-code "${scripts[@]}" || failed+=("format")
fi

echo "== Lint" >&2
"$formatter" lint "${scripts[@]}" || failed+=("lint")

# --- Result ------------------------------------------------------------------

if [ "${#failed[@]}" -gt 0 ]; then
	echo "Check failed: ${failed[*]}" >&2
	exit 1
fi
echo "All checks passed" >&2
