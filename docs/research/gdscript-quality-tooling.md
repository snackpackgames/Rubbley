# GDScript linting, formatting and static-analysis tooling (Godot 4.7)

Research for [#41](https://github.com/snackpackgames/Rubbley/issues/41), part of the Godot migration map [#20](https://github.com/snackpackgames/Rubbley/issues/20). Gathered 2026-10-14. Godot 4.7.2-stable (2026-08-18) is the latest 4.x release ([godotengine/godot releases](https://github.com/godotengine/godot/releases)).

## Summary

- **Godot's own compiler is the strongest checker, and it can fail CI.** Every GDScript warning is a project setting `debug/gdscript/warnings/<name>` with levels Ignore/Warn/Error. A warning set to Error becomes a parse error. `godot --headless --check-only --script res://file.gd` exits non-zero when the script fails to compile. It checks one script per call, so CI has to loop over files.
- **Static typing is enforced through warnings, not a mode.** Set `untyped_declaration` (and optionally the `unsafe_*` family) to Error. They are all Ignore by default.
- **gdtoolkit (gdlint/gdformat) is mature but stalled.** The latest release is 4.5.0 (2025-10-09), and nothing has been committed since. Godot 4.6 and 4.7 added no GDScript syntax, so it still parses current code, but bugs from 2026 sit unfixed, including formatter output that Godot rejects.
- **GDQuest's GDScript-formatter is the active alternative.** It is written in Rust on tree-sitter, ships a formatter and a linter, and has a pre-commit hook. It is pre-1.0 (0.27.0, 2026-09-25) with frequent releases.
- **Style guide:** use the official GDScript style guide (4.7 docs). GDQuest's older guidelines target Godot 3.1.

## 1. Godot's built-in warnings and static typing

### Setting names (verified against 4.7-stable source)

Godot registers these in `GDScriptLanguage` ([`modules/gdscript/gdscript.cpp` @ 4.7-stable](https://github.com/godotengine/godot/blob/4.7-stable/modules/gdscript/gdscript.cpp)):

| Setting | Type / default | Notes |
|---|---|---|
| `debug/gdscript/warnings/enable` | bool, `true` | Master switch. When off, the parser drops all warnings ([`gdscript_parser.cpp` `push_warning`](https://github.com/godotengine/godot/blob/4.7-stable/modules/gdscript/gdscript_parser.cpp)). |
| `debug/gdscript/warnings/directory_rules` | Dictionary path → Exclude/Include, default `{"res://addons": Exclude}` | New in 4.6. Replaces the 4.5 bool `debug/gdscript/warnings/exclude_addons` ([4.5-stable source](https://github.com/godotengine/godot/blob/4.5-stable/modules/gdscript/gdscript.cpp) vs [4.6-stable source](https://github.com/godotengine/godot/blob/4.6-stable/modules/gdscript/gdscript.cpp)). |
| `debug/gdscript/warnings/<warning_name>` | enum `Ignore,Warn,Error` (0/1/2) | One per warning. The path is `"debug/gdscript/warnings/" + name.to_lower()` ([`gdscript_warning.cpp`](https://github.com/godotengine/godot/blob/4.7-stable/modules/gdscript/gdscript_warning.cpp)). |
| `debug/gdscript/warnings/renamed_in_godot_4_hint` | bool, `true` | Not a warning level, despite the path (source comment says so). |

Godot 4 has **no global "treat warnings as errors" switch**. You escalate each warning on its own. The 4.7 docs say: "Warnings won't prevent the game from running, but you can turn them into errors if you'd like." The GDScript section only appears in Project Settings once Advanced Settings is on ([GDScript warning system, 4.7 docs](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/warning_system.html)).

### Warnings relevant to static typing

Defaults come from `default_warning_levels` in [`gdscript_warning.h` @ 4.7-stable](https://github.com/godotengine/godot/blob/4.7-stable/modules/gdscript/gdscript_warning.h):

| Warning (setting suffix) | Default | What it catches (source comment) |
|---|---|---|
| `untyped_declaration` | Ignore | "Variable/parameter/function has no static type, explicitly specified or implicitly inferred." |
| `inferred_declaration` | Ignore | "Variable/constant/parameter has an implicitly inferred static type" (bans `:=`; conflicts with the style guide, see section 5). |
| `unsafe_property_access` | Ignore | Property not found in the detected type. |
| `unsafe_method_access` | Ignore | Method not found in the detected type. |
| `unsafe_cast` | Ignore | Casting a `Variant` to non-`Variant`. |
| `unsafe_call_argument` | Ignore | Argument is a supertype of the required type. |
| `unsafe_void_return` | Warn | |
| `return_value_discarded` | Ignore | "Too spammy by default on common cases (connect, Tween, etc.)." |
| `missing_await` | Ignore | |
| `inference_on_variant` | Error | `:=` inferring `Variant`. |

Three more default to Error: `native_method_override`, `get_node_default_without_onready` and `onready_with_export` ("May not work as expected"). The rest (unused_*, shadowed_*, unreachable_*, integer_division, narrowing_conversion, confusable_*, and so on) default to Warn. The full list of 46 active names, plus 3 deprecated internal ones, is in [`gdscript_warning.cpp`](https://github.com/godotengine/godot/blob/4.7-stable/modules/gdscript/gdscript_warning.cpp). The static typing docs say "By default, these warnings are disabled", suggest `UNTYPED_DECLARATION` "if you want to always use static types", and warn that "`UNSAFE_*` warnings do not cover all cases that unsafe lines cover" ([Static typing, 4.7 docs](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html)).

A strict `project.godot` would look like this (the keys come from the table above, and `2` means Error):

```ini
[debug]
gdscript/warnings/untyped_declaration=2
gdscript/warnings/unsafe_property_access=2
gdscript/warnings/unsafe_method_access=2
gdscript/warnings/unsafe_cast=2
gdscript/warnings/unsafe_call_argument=2
```

Per-line opt-outs: `@warning_ignore("name")` for the next line, and `@warning_ignore_start` / `@warning_ignore_restore` for a region ([warning system docs](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/warning_system.html)).

### How a warning becomes a failure

- When a warning's level is Error, `push_warning` marks it `treated_as_error`. `apply_pending_warnings` then calls `push_error(message + " (Warning treated as error.)")`, so the script fails to compile ([`gdscript_parser.cpp` @ 4.7-stable](https://github.com/godotengine/godot/blob/4.7-stable/modules/gdscript/gdscript_parser.cpp)).
- Warnings only exist in `DEBUG_ENABLED` builds. The setting registration sits inside `#ifdef DEBUG_ENABLED` ([`gdscript.cpp`](https://github.com/godotengine/godot/blob/4.7-stable/modules/gdscript/gdscript.cpp)). The editor binary is such a build, so CI should use the editor binary, not a release export template.

### Headless CI check

- `--check-only` is documented as "Only parse for errors and quit (use with --script)." It works in editor builds and in templates built with `disable_path_overrides=false`. `--headless` is "Useful for servers and with --script." ([Command line tutorial, 4.7 docs](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)).
- In [`main/main.cpp` @ 4.7-stable](https://github.com/godotengine/godot/blob/4.7-stable/main/main.cpp), `--check-only` loads the one script given by `--script` and returns `script_res->is_valid() ? EXIT_SUCCESS : EXIT_FAILURE`. One process per script, so a CI job loops over `**/*.gd`.
- The same docs warn that unknown command-line arguments "have no effect whatsoever", so a typo in a flag won't make the job fail. A CI job should also check the exit code on a script it knows is broken.
- **Local test (Godot 4.5.1, the only build on this machine; the 4.7 code path is the one quoted above).** The test used a throwaway project with `untyped_declaration=2`, ran `--headless --import`, then `--headless --path <proj> --check-only --script res://x.gd`:
  - a fully typed script exited 0.
  - `var speed = 3` exited 1 with `SCRIPT ERROR: Parse Error: Variable "speed" has no static type. (Warning treated as error.)`
  - an undeclared identifier exited 1 with `Parse Error: Identifier "undefined_thing" not declared in the current scope.`
- Running `--import` first is our own precaution so the `class_name` cache exists before scripts that reference global classes get checked. The docs don't say it is required, so the Godot-project prototype should confirm it.
- Warnings left at Warn print but never change the exit code. CI only fails on warnings set to Error.

## 2. gdtoolkit (gdlint, gdformat, gdparse, gdradon)

- **Repo:** [Scony/godot-gdscript-toolkit](https://github.com/Scony/godot-gdscript-toolkit), MIT, about 1.6k stars. It provides a parser, linter, formatter, and cyclomatic-complexity tool (README). Install with `pip3 install "gdtoolkit==4.*"`.
- **Release cadence:** 4.0.0 shipped 2023-03-01. Releases ran regularly through 4.3.4 (2025-06-29) and then 4.5.0 (2025-10-09). No release or commit to `master` has landed since 2025-10-09 ([PyPI](https://pypi.org/project/gdtoolkit/), [commits](https://github.com/Scony/godot-gdscript-toolkit/commits/master)).
- **Syntax coverage:** 4.5.0 "Added support for @abstract functions" and "variadic functions", plus `@warning_ignore_start/restore` formatting fixes ([CHANGELOG](https://github.com/Scony/godot-gdscript-toolkit/blob/master/CHANGELOG.md)). 4.3.x added typed dictionaries, multi-statement lambdas, `is not`, and guarded `match` branches. The [4.6](https://godotengine.org/releases/4.6/) and [4.7](https://godotengine.org/releases/4.7/) release pages and the [4.7 upgrade guide](https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html) list no new GDScript syntax. The 4.7 guide's GDScript notes are behaviour changes only (packed-array setters, inherited typed returns). So 4.5.0 should parse 4.7 code.
- **Local probe (gdtoolkit 4.5.0, Python 3.12):** one script used `@abstract` class and func, a variadic `...values`, `Dictionary[String, float]`, `static var`, a typed `for`, `is not`, a guarded `match`, a multi-line lambda, `%Unique` and `@warning_ignore`. `gdlint` reported "no problems found". `gdformat --check` exited 1 because it wanted to join `@abstract` onto the `class_name` line and drop one of the two blank lines before an `@abstract func`. That second change goes against the style guide's two blank lines around functions.
- **Known open bugs, all unanswered upstream** ([issues](https://github.com/Scony/godot-gdscript-toolkit/issues)):
  - [#424](https://github.com/Scony/godot-gdscript-toolkit/issues/424): gdformat emits indentation Godot rejects after multi-line lambdas.
  - [#394](https://github.com/Scony/godot-gdscript-toolkit/issues/394): gdformat breaks `@warning_ignore_start`.
  - [#374](https://github.com/Scony/godot-gdscript-toolkit/issues/374): formatting causes compiler errors.
  - [#425](https://github.com/Scony/godot-gdscript-toolkit/issues/425): gdlint skips `static func` for some checks.
  - [#430](https://github.com/Scony/godot-gdscript-toolkit/issues/430): `@abstract` func with a semicolon is rejected.
  - [#428](https://github.com/Scony/godot-gdscript-toolkit/issues/428): concurrent runs collide on the grammar cache.
  - Community PRs with fixes (#433, #431, #413) are open and unmerged.
- **CI and hooks:** the README shows a GitHub Action (`uses: Scony/godot-gdscript-toolkit@master`, then `gdformat --check` and `gdlint`) and a pre-commit config. The repo's [`.pre-commit-hooks.yaml`](https://github.com/Scony/godot-gdscript-toolkit/blob/master/.pre-commit-hooks.yaml) defines `gdlint` and `gdformat` hooks (`language: python`, `types: [gdscript]`). pre-commit's `identify` maps `.gd` to the `gdscript` type ([identify/extensions.py](https://github.com/pre-commit/identify/blob/main/identify/extensions.py)).
- **Config files:** `gdlintrc` for the linter, and `gdformatrc` since 4.3.0 (CHANGELOG).

## 3. Other linters and formatters

- **GDQuest GDScript-formatter** ([repo](https://github.com/GDQuest/GDScript-formatter)): MIT, about 470 stars, last pushed 2026-10-08. 43 releases between 0.1.0 (2025-08-21) and 0.27.0 (2026-09-25). Rust, built on [tree-sitter-gdscript](https://github.com/PrestonKnopp/tree-sitter-gdscript). The README says it:
  - "aims to follow the official GDScript style guide"
  - has `--check` ("exit code 1 if changes needed")
  - has `--verify-structure`, which reparses the output and rejects it if the structure changed. The README calls this "an imperfect check".
  - reads `.editorconfig`
  - supports `# fmt: off/on`
  - can reorder members into style-guide order
  - includes a linter: `gdscript-formatter lint`, `--list-rules`, `--disable`, `# gdlint-ignore-next-line`
  - is distributed as prebuilt binaries, WinGet (`GDQuest.GDScript.Formatter`) and Scoop
  - has a community GitHub Action, setup-gdscript-formatter
  - has [`.pre-commit-hooks.yaml`](https://github.com/GDQuest/GDScript-formatter/blob/main/.pre-commit-hooks.yaml) with `gdscript-formatter` and `gdscript-linter` hooks (`language: rust`)

  The README also cautions to use version control because "there can always be edge cases or less common syntax that may not be handled correctly yet."
- **Godot's GDScript language server:** the editor serves LSP on `--lsp-port` (editor-only flag, [command line docs](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)) and pushes `textDocument/publishDiagnostics` ([`gdscript_workspace.cpp`](https://github.com/godotengine/godot/blob/4.7-stable/modules/gdscript/language_server/gdscript_workspace.cpp)). The official VS Code extension can launch a windowless editor as the server (`godotTools.lsp.headless`, Godot >4.2) ([godot-vscode-plugin README](https://github.com/godotengine/godot-vscode-plugin)). That helps editor feedback. The diagnostics come from the same compiler as `--check-only`, so the LSP adds nothing for CI.
- **Smaller projects, not recommended for now:** [graydwarf/godot-gdscript-linter](https://github.com/graydwarf/godot-gdscript-linter) (editor plugin, about 65 stars) and [TkTech/gdeye](https://github.com/TkTech/gdeye) (linter/formatter/LSP, created 2026-01, 9 stars).

## 4. Pre-commit hook options

1. The [pre-commit](https://github.com/pre-commit/pre-commit) framework with gdtoolkit hooks (needs Python) or GDQuest hooks (`language: rust`, which pre-commit builds through cargo). Both configs are linked above.
2. A plain git hook or CI step that runs the formatter's `--check` mode and `gdlint` / `gdscript-formatter lint`.
3. Godot `--check-only` is too slow for a per-commit hook, since each script starts an engine process. It fits CI better (our judgement, not measured).

## 5. Style guides for agents

- **Official: [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html) (4.7 docs).**
  - Format: tabs, a hard limit of 100 columns (aim for 80), two blank lines around functions and classes, trailing commas in multi-line collections, double quotes by default, UTF-8 with LF line endings.
  - Naming: snake_case for files, functions, variables and signals; PascalCase for classes, nodes and enums; CONSTANT_CASE for constants and enum members. Signals in the past tense. A `_` prefix marks private and virtual members.
  - Member order: annotations, `class_name`, `extends`, doc comment, signals, enums, constants, static vars, `@export`, other vars, `@onready`, `_static_init`, static methods, built-in virtuals, custom overrides, other methods, inner classes. Public members come before private ones.
  - Typing: explicit types where the type is ambiguous. `:=` is fine when the type is clear from the same line, which means `inferred_declaration` should stay off if we follow the guide.
  - The guide names no tool.
- **GDQuest guidelines** ([GDScript guidelines](https://gdquest.com/tutorial/godot/learning-paths/new-features-godot-3.1/chapter/22-gdscript-guidelines/)) target Godot 3.1 (2019). Their formatter now enforces the official guide instead.

## Open points for the decision ticket

- Which formatter to adopt: gdtoolkit (stalled, has known breaking bugs) or GDQuest (active, pre-1.0, pin a version).
- Which warnings go to Error. Proposed minimum: `untyped_declaration` plus the four `unsafe_*` access, cast and argument warnings.
- Confirm the `--import` then loop `--check-only` CI recipe on Godot 4.7 itself in the project prototype.
