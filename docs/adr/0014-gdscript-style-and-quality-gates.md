# The official GDScript style guide, enforced by compiler, formatter and lint gates that block CI

Rubbley is GDScript-only and mostly agent-built, so nothing like a type checker or C# compiler catches mistakes before runtime unless we turn Godot's own warnings into one. Agents follow the official Godot 4.7 GDScript style guide, and every rule we can check mechanically is a gate in `scripts/check.sh` that blocks merging.

## The standard

- The official GDScript style guide is the standard. Rubbley's rules live in `docs/agents/gdscript-style.md`, linked from `CLAUDE.md`, and only list additions to the guide, never restate it. Code structure (scenes, autoloads, signals) is the architecture-conventions decision, not this page.
- The page starts with three additions; more are added only when a review finds a real problem:
  - Glossary terms are used verbatim in names (`CelestialBody`, `celestial_body.gd`), and a glossary _Avoid_ term never appears in a name.
  - Every `class_name` script and every public method has a `##` doc comment.
  - Every `@warning_ignore` has a comment on the same line saying why.

## The gates

- **Static typing is required.** `untyped_declaration`, `unsafe_property_access`, `unsafe_method_access`, `unsafe_cast` and `unsafe_call_argument` are set to Error in `project.godot`. `inferred_declaration` stays off, so `:=` is allowed.
- **No warnings.** Every warning that defaults to Warn is raised to Error. An exception is allowed only with a one-line reason in the style page.
- **Format.** The GDQuest GDScript-formatter, pinned to the exact version in `.gdscript-formatter-version`, runs with `--check`.
- **Lint.** The same binary's lint subcommand checks naming and member order. Rules that contradict the official guide are switched off in its config.
- **Scope.** Game code and `test/` are both checked. `addons/` (vendored gdUnit4 and later addons) is excluded from every gate.

## One check script

`scripts/check.sh` is the only way agents and CI run the gates, matching `scripts/test.sh` from ADR 0011. It:

1. finds Godot and checks it against `.godot-version`, then runs `godot --headless --import`;
2. runs `godot --headless --check-only --script` on every `.gd` outside `addons/`, using the editor binary, since warnings exist only in debug builds;
3. downloads the pinned formatter release into a gitignored `.tools/` on first use, then runs the format check and lint;
4. exits non-zero if any gate fails. `--fix` applies the formatter instead of checking.

Agents run it before every commit. In CI it runs before `scripts/test.sh` in the required PR check, and every gate blocks.

## Considered Options

- **gdtoolkit (gdlint/gdformat)**: rejected. It has had no commits since 4.5.0 (2025-10), and open bugs have gdformat emitting code Godot rejects.
- **Compiler only, no formatter or lint**: rejected. The compiler doesn't check naming or layout, and agents drift on both.
- **Gates that warn without blocking**: rejected. Warnings that don't fail the build pile up, which is the same reason ADR 0011 fails on gdUnit4 warnings.
- **Pre-commit hooks**: rejected. The pre-commit framework adds a Python dependency, hooks are easy to skip, and CI is the gate anyway. A plain git hook calling `scripts/check.sh` can be added later if needed.
- **Installing the formatter through WinGet, Scoop or cargo**: rejected. The script installs the pinned binary itself, so every machine and CI run gets the same version with no setup.

## Consequences

- The formatter is pre-1.0. Pinning protects us from breaking releases, and if it ever writes invalid code the compiler gate catches it.
- Raising every warning to Error means a Godot patch bump that adds a warning can fail CI; that's handled when `.godot-version` changes.
