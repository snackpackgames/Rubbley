# Testing and headless tooling for agent-built Godot work

Research for [#31](https://github.com/snackpackgames/Rubbley/issues/31) (map [#20](https://github.com/snackpackgames/Rubbley/issues/20)). Gathered 2026-10-11. Language (GDScript vs C#) is undecided, so both are covered.

## Question

What are the options for automated testing and headless runs in Godot 4 (GUT, gdUnit4, others; GDScript and C# support), for CLI/headless execution, and for CI (e.g. GitHub Actions with export templates)? Which fit best when agents write most of the code?

## Short answer

- **Test framework: gdUnit4.** It is the only maintained framework that covers GDScript and C# under one name. It runs from the CLI with distinct exit codes and JUnit XML output, ships an official GitHub Action, and has a scene runner that simulates mouse, keyboard and **touch** input. Choosing it doesn't block the language decision.
- **If the project goes GDScript-only, GUT is an equally good choice.** Its CLI is simpler, it runs under plain `--headless`, it exits 0/1, and it writes JUnit XML. The deciding factor is input-driven scene tests, which are a gdUnit4 strength.
- **If the project goes C#,** the gdUnit4 C# side (gdUnit4Net) has lagged on stable releases. Its last stable release, 5.0.0, targets Godot 4.4, and 5.1 has only reached release candidates. Chickensoft GoDotTest plus GodotTestDriver is the main alternative. Pure-logic C# can also be tested with plain `dotnet test`.
- **CI: GitHub Actions on `ubuntu-latest`.** Install Godot and export templates with `chickensoft-games/setup-godot` (cached; Linux, macOS and Windows; .NET or standard builds). Run `godot --headless --import` first, then the test runner. Wrap anything that needs real input events in `xvfb-run`. Export with `godot --headless --export-release <preset> <path>`, or with `firebelley/godot-export`.
- **Agent loop:** every option can run as one shell command with a pass/fail exit code, so an agent can run red-green loops without the editor. `godot --headless --check-only -s <script>` adds a cheap parse check for GDScript.

## Godot's own command line (Godot 4.7 docs)

Source: [Command line tutorial](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html). The stable docs are 4.7; the latest engine release is [4.7.2-stable, 2026-08-18](https://github.com/godotengine/godot/releases).

| Flag | What the docs say | Use for us |
|---|---|---|
| `--headless` | "Enable headless mode (`--display-driver headless --audio-driver Dummy`)". Required for export on hosts without a GPU, such as CI. | Every CI invocation |
| `-s, --script <script>` | "Run a script." The script "must inherit from `SceneTree` or `MainLoop`". Extended (editor) builds only. | How GUT and gdUnit4 runners start |
| `--check-only` | "Only parse for errors and quit (use with `--script`)." | Cheap GDScript syntax gate |
| `--import` | "Starts the editor, waits for any resources to be imported, and then quits." | Run before tests on a fresh checkout so the `.godot/` cache and `class_name` registry exist |
| `--export-release / --export-debug / --export-pack <preset> <path>` | Export with a preset from `export_presets.cfg`. Relative paths resolve against the folder that holds `project.godot`. | Build artifacts |
| `--build-solutions` | "Build the scripting solutions (e.g. for C# projects)." | C# only |
| `--quit`, `--quit-after N` | Quit after 1 or N iterations. | Smoke-boot a scene |
| `--log-file` | Writes stdout/stderr to a file. | CI artifacts |

Pitfalls the docs call out:

- "Unknown command line arguments have no effect whatsoever." A typo in a flag fails silently, so CI scripts should be checked in, not retyped by agents.
- Export paths are relative to `project.godot`, not the current directory.

## Test frameworks

### GUT (Godot Unit Test), GDScript only

- Repo: [bitwes/Gut](https://github.com/bitwes/Gut). About 2.75k stars, MIT. Last push 2026-08-18. Releases: 9.6.1 for Godot 4.6 on the Asset Library, and 9.7.1 for Godot 4.7 on the `godot_4_7` branch ([README version table](https://github.com/bitwes/Gut#version-links)).
- GUT pins each release to one Godot minor version, so Godot upgrades mean GUT upgrades.
- Features ([README](https://github.com/bitwes/Gut)): asserts, inner test classes, full and partial doubles, stubs, spies, parameterized tests, CLI, JUnit XML export, and a VS Code extension.
- CLI ([Command-Line docs](https://gut.readthedocs.io/en/latest/Command-Line.html)):
  ```
  godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit -gjunit_xml_file=reports/gut.xml
  ```
  - Options can live in `res://.gutconfig.json`. Command-line flags override it.
  - Single-file and single-test runs use `-gtest=`, `-gselect`, `-ginner_class` and `-gunit_test_name`.
  - Exit code: "`0` will be returned if all tests pass and `1` will be returned if any fail (`pending` doesn't affect the return value)."
  - Watch out: without `-gexit`, the process does not quit. An agent would hang on it.
- No official GitHub Action. In CI it is a plain `godot --headless ...` call.

### gdUnit4, GDScript and C#

- Repo: [godot-gdunit-labs/gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4). About 1.26k stars. v6.2.2 was released 2026-10-07 and supports Godot 4.5 to 4.7.1 plus a 4.8 dev build ([compatibility table](https://github.com/godot-gdunit-labs/gdUnit4#readme)). Very active.
- Features ([README](https://github.com/godot-gdunit-labs/gdUnit4#features)):
  - fluent asserts
  - mocks and spies, including on scenes
  - parameterized and fuzz tests
  - session hooks
  - flaky-test retry
  - orphan-node detection
  - a **Scene Runner** that simulates "Mouse clicks and movements, Keyboard inputs, Touch screen interactions, Custom input actions" and can wait for signals or return values
  - HTML and JUnit XML reports
  - an official GitHub Action
- CLI ([cmd docs](https://godot-gdunit-labs.github.io/gdUnit4/latest/advanced_testing/cmd/)): `addons/gdUnit4/runtest.sh -a res://test` (or `runtest.cmd`). It needs `GODOT_BIN` or `--godot_binary`.
  - `-a` adds paths and `-i` ignores suites or `Suite:test` names.
  - It is fail-fast by default; `-c` makes it continue after failures.
  - Exit codes: `0` success, `100` failures, `101` warnings.
  - Reports go to `res://reports/` (`index.htm`, `results.xml`).
  - The [`runtest.sh` source](https://github.com/godot-gdunit-labs/gdUnit4/blob/master/addons/gdUnit4/runtest.sh) runs `dotnet build` automatically when it detects a .NET Godot build. It also passes `--remote-debug tcp://127.0.0.1:0` so a parse error can't drop Godot into its interactive `debug>` prompt, which would otherwise hang an unattended agent.
- **Headless caveat** ([`GdUnitTestCIRunner.gd`](https://github.com/godot-gdunit-labs/gdUnit4/blob/master/addons/gdUnit4/src/core/runners/GdUnitTestCIRunner.gd)): "By default, running GdUnit4 in headless mode is not allowed." `--ignoreHeadlessMode` overrides this, with the warning: "Godot 'InputEvents' are not transported by the Godot engine in headless mode and therefore have no effect in the test!"
  - Logic tests can run with `--headless --ignoreHeadlessMode`.
  - Input and scene-runner tests need a real display server. On Linux CI that means `xvfb-run`. The official action already does this for C#: `xvfb-run ... --display-driver x11 --rendering-driver opengl3` ([action.yml](https://github.com/godot-gdunit-labs/gdUnit4-action/blob/master/action.yml)).

### gdUnit4Net, the C# side of gdUnit4

- Repo: [godot-gdunit-labs/gdUnit4Net](https://github.com/godot-gdunit-labs/gdUnit4Net). Commits are active (last push 2026-10-06).
- **Stable releases lag.** The latest stable release is v5.0.0 (2025-06-21), which the README says is "based on Godot v4.4" and supports Godot 4.3 to 4.4.1. NuGet `gdUnit4.api` has 5.1.0-alpha1 through [5.1.0-rc5](https://www.nuget.org/packages/gdUnit4.api) but no 5.1.0 stable yet. Supported .NET versions are 8 and 9.
- Design (v5): it is a VSTest adapter, so tests run with `dotnet test --settings .runsettings` and in VS, VS Code and Rider. Tests run **without** the Godot runtime by default, which the README claims is "up to 10x faster". The `[RequireGodotRuntime]` attribute opts a test into the engine.
  - `.runsettings` sets `GODOT_BIN` and extra Godot parameters such as `--headless` ([TestAdapter README](https://github.com/godot-gdunit-labs/gdUnit4Net/blob/master/TestAdapter/README.md)).
  - Roslyn analyzers validate test attributes at compile time, which helps agents catch mistakes early.

### Chickensoft GoDotTest (+ GodotTestDriver), C# only

- Repos: [chickensoft-games/GoDotTest](https://github.com/chickensoft-games/GoDotTest) (about 150 stars; NuGet 2.0.47) and [GodotTestDriver](https://github.com/chickensoft-games/GodotTestDriver) for input and UI drivers. Both had pushes in September 2026.
- It runs inside the game. The main scene checks for `--run-tests[=Suite[.Method]]` and `--quit-on-finish` and hands control to the test runner. These flags "mean nothing to Godot itself".
- Tests run sequentially by design ("Tests do not run in parallel"). It supports coverage through coverlet.
- Notable gotcha from its README: "Godot's `SceneTree.Quit(int exitCode)` method does not actually set the exit code". GoDotTest force-exits from .NET to report the exit code correctly. Any C# test harness needs to handle this to give CI a real pass/fail.
- No JUnit reporter is mentioned in the README. Integration is more hand-built than with gdUnit4Net.

### Supporting tools

- **gdtoolkit** ([Scony/godot-gdscript-toolkit](https://github.com/Scony/godot-gdscript-toolkit)) provides `gdlint` and `gdformat` for GDScript. Latest release 4.5.0 (2025-10-09). It may lag newer GDScript syntax, so check it against our Godot version before adopting it.
- **Pure .NET tests.** If C# game logic is kept free of `Godot.*` types, plain xUnit or NUnit with `dotnet test` works with no engine at all. That is the fastest loop for agents. (This is an inference from the gdUnit4Net "no runtime by default" design, not a separate source.)

## CI on GitHub Actions

| Option | What it does | Notes |
|---|---|---|
| [`chickensoft-games/setup-godot@v2`](https://github.com/chickensoft-games/setup-godot) | Installs Godot 4.x (.NET or standard), optionally with export templates. Caches them and puts `godot` on `PATH`. | Runs on Linux, macOS and Windows runners. Can read the version from `global.json`. The README pattern for C# is `godot --headless --build-solutions --quit` then `dotnet build`. Last push 2026-10-01. |
| [`godot-gdunit-labs/gdUnit4-action@v1`](https://github.com/godot-gdunit-labs/gdUnit4-action) | Downloads Godot and gdUnit4, imports the project (`-e --headless --quit-after 2000`), runs the tests, and publishes and uploads a JUnit report. | Inputs include `godot-version`, `godot-net`, `paths`, `timeout`, `retries` and `warnings-as-errors`. v1.3.2 (2026-06). README examples show `.NET 7/8`. |
| [`firebelley/godot-export`](https://github.com/firebelley/godot-export) | Reads `export_presets.cfg` and exports every preset (or a chosen subset). Can archive and cache builds. | Needs download URLs for the Linux Godot binary and the `.tpz` templates. Supports Mono builds. v8.0.0 in the README. |
| [`abarichello/godot-ci`](https://github.com/abarichello/godot-ci) | Docker image (`barichello/godot-ci[:mono-X]`) with Godot and templates, plus deploy templates for GitHub Pages and itch.io (butler). | Also works on GitLab. Useful later for itch.io deploys. iOS is "Not available yet". |
| Plain shell | `godot --headless --import`, then the test runner command, then `godot --headless --export-release ...` | The fewest moving parts. The same commands work locally for agents. |

General CI facts:

- `export_presets.cfg` must be committed ([godot-ci troubleshooting](https://github.com/abarichello/godot-ci#troubleshoot)).
- C# has export limits: desktop is supported, Android and iOS are "experimental", and C# "currently cannot be exported to the web platform". Godot 4.5+ requires .NET 8, and Android export requires .NET 9 ([C# basics](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_basics.html)). This matters for a touch-first game that may want web or mobile builds.

## Fit for agent-written code

What matters when agents write most of the code:

1. **A single command with a trustworthy exit code.**
   - GUT gives 0/1, but only with `-gexit`.
   - gdUnit4 gives 0/100/101.
   - gdUnit4Net goes through `dotnet test`.
   - GoDotTest needs `--quit-on-finish` plus its force-exit workaround.
2. **No interactive hangs.** Risks are GUT without `-gexit`, Godot's `debug>` prompt on parse errors (gdUnit4's script defends against it), and gdUnit4 refusing to run under `--headless` without `--ignoreHeadlessMode`. Wrap the chosen invocation in a checked-in script (for example `scripts/test.sh`) so agents never assemble flags by hand. Unknown flags are silently ignored.
3. **Fast, targeted runs** for red-green loops. All four frameworks can run a single suite or test.
4. **Machine-readable results.** GUT and gdUnit4 write JUnit XML, and gdUnit4Net writes TRX or JUnit through VSTest loggers.
5. **Input simulation for a touch-first game.** gdUnit4's scene runner simulates touch directly; GodotTestDriver covers C#. These tests need xvfb in CI, not `--headless`.

## Open points that may need decisions

- **Language choice (existing ticket).** Two facts from this research feed into it:
  - C#'s web export is unsupported and its mobile support is experimental.
  - gdUnit4Net's stable releases lag the engine.
- **Godot version pin.** GUT pins a release per Godot minor version, gdUnit4 supports a range, and gdUnit4Net's stable release targets 4.4. The engine version decision constrains the test framework choice.
- **Test layout and runner script.** We need to decide where tests live (`res://test/`), what the checked-in `test` script looks like, and whether CI runs a headless logic pass plus an xvfb input pass.
- **Physics determinism in tests.** Rubbley's core is gravity physics. Tests that step physics frames (for example, through gdUnit4's scene runner) need a fixed physics tick, and we need a policy on tolerance-based asserts. Not researched here.
- **Export targets in CI.** Which platforms to build per PR versus per tag, and whether to deploy to itch.io.
