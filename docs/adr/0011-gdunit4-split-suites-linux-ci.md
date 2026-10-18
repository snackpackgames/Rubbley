# gdUnit4 with headless and input suites, run by one script on Linux CI

Tests use gdUnit4, vendored in `addons/gdUnit4/` and pinned to the release that supports our `.godot-version` patch. We picked it over GUT because Rubbley is touch-first and almost every gesture is a custom recogniser. gdUnit4's scene runner simulates touch, mouse and keyboard and can wait for signals. GUT's simpler CLI and plain headless runs didn't outweigh that.

## Layout

- Tests live in `test/` at the repo root, mirroring the source tree, one `*_test.gd` per script under test.
- `test/unit/` holds everything that runs under `--headless --ignoreHeadlessMode`. This is the fast suite agents run in their red-green loop.
- `test/input/` holds every test that injects InputEvents or uses the scene runner's input simulation. Godot doesn't deliver input events under `--headless`, so this suite needs a display server: xvfb in CI, the desktop locally.
- Export presets exclude `test/*`, `addons/gdUnit4/*` and `reports/`. `reports/` is gitignored.

## One runner script

`scripts/test.sh` (Bash, so it runs under Git Bash on Windows as well as Linux and macOS) is the only way agents and CI run tests. Agents never assemble Godot flags by hand, because Godot silently ignores unknown flags. The script:

1. finds Godot from `$GODOT_BIN`, falling back to `godot` on PATH, and fails if its version doesn't match `.godot-version`;
2. runs `godot --headless --import`;
3. calls gdUnit4's `runtest.sh` for both suites by default, or for one suite or a path when asked;
4. exits non-zero on any failure, and also on gdUnit4's warnings exit code (101), so warnings can't pile up.

## CI (GitHub Actions)

- **Every PR**: on `ubuntu-latest`, `chickensoft-games/setup-godot` installs the `.godot-version` patch with export templates. CI runs the GDScript quality gates (set by the style-standards decision), then `scripts/test.sh` under `xvfb-run`, then a web export uploaded as a workflow artifact so a reviewer can play the PR. This is a required status check on `main`. PRs don't build native platform exports.
- **Merge to `main`**: CI reruns the PR checks and publishes the web build to a stable playtest location.
- **Release tag**: CI exports Linux, Windows and Android on `ubuntu-latest`, macOS and iOS on a `macos` runner, and web.
- Tests run on Linux only. GDScript and physics logic don't differ meaningfully between desktop OSes, and phone performance is measured by the device benchmark, not CI.

Where the playtest build is hosted, signing, and store uploads aren't decided here. They belong to the release and submission pipeline, which depends on the storefront decision.

## Considered Options

- **GUT**: rejected. It's a good fit for GDScript-only projects, but its input simulation is weaker than gdUnit4's scene runner, and each GUT release is tied to one Godot minor version.
- **One suite run on a display**: rejected. Every local run would open a Godot window on the developer's desktop, and the agent loop would get slower.
- **Tests next to the code they cover**: rejected. Test files would be scattered through the project, and the export filter that keeps them out of builds would be harder to write.
- **Windows/macOS test matrix**: rejected. It triples CI minutes for almost no signal.
