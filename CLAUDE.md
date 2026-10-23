# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rubbley is a 2.5D top-down physics action-puzzle game: the player stays centered while the level scrolls, and fights by manipulating gravity with three moves (Attract, Repel, Spin). Touch-first, with controller and mouse + keyboard schemes.

Rubbley is built in **Godot 4.7, GDScript only**. The project lives at the repo root (`project.godot`, game code under `game/`), pinned to the version in `.godot-version`; all new work goes there. The Unity 2019.4 prototype (orbit/attractor physics in `unity/Assets/Scripts/`, a toon shader, debug scenes) sits in `unity/` as frozen reference until it's retired. Treat the Unity code as reference for behaviour to port, not as architecture to preserve. Godot project decisions are recorded as ADRs in `docs/adr/`; new ones get settled through `/wayfinder` maps.

## Godot tooling

`source scripts/env.sh` finds the pinned Godot and exports `GODOT_BIN` (`--install` downloads it into `.tools/`). Run `scripts/import.sh` after adding a scene, script or `class_name`, so the `.godot/` cache and `.uid` files are up to date. New `.tscn` files need a `uid=` in their header; the editor writes one on save, and a headless import does not.

Run `scripts/check.sh` before every commit: it runs the compiler, formatter and lint gates that CI requires on every PR, and `--fix` applies the formatter. Run tests only through `scripts/test.sh`: with no argument it runs both gdUnit4 suites, or pass `unit` (headless, for the red-green loop), `input` (opens a window) or a path under `test/`. Physics tests extend `SimulationTestSuite` and step with `await step_seconds(s)`. GDScript follows the official style guide plus the additions in [`docs/agents/gdscript-style.md`](docs/agents/gdscript-style.md); read it before writing GDScript.

## Game design

The GDD is the source of truth for design intent. Read [`docs/gdd/rubbley-gdd.md`](docs/gdd/rubbley-gdd.md) before planning or building any gameplay feature. It is a snapshot of the Google Doc linked in its header; when the user says the GDD changed, re-export it with the command in that header and commit the refresh.

The GDD has open sections (Concept Art, level structure brainstorming), and its Narrative and Visuals sections are early sketches. Surface those gaps as questions for the user; design answers come from them.

## Planning workflow

Big features and the Godot migration are planned with `/wayfinder`: a map issue labelled `wayfinder:map` on GitHub, with decision tickets as sub-issues. One ticket per session. Tracker mechanics live in `docs/agents/issue-tracker.md`.

## Claude Code setup

Skills from `mattpocock/skills` and `theclaymethod/unslop` are vendored in `.claude/skills/` and pinned in `skills-lock.json`. Update them with `npx skills update -p`; add more with `npx skills add <repo> -a claude-code --copy -s <skill>`.

Two plugins are enabled in `.claude/settings.json`: `superpowers` and `snackpackgames-claude-plugins` (Godot 4 skills such as `godot-2d-physics`, `godot-input-handling`, `godot-camera-systems`). If they are missing from the session's skill list, have the user run:

```
/plugin marketplace add snackpackgames/snackpackgames-claude-plugins
/plugin install superpowers@claude-plugins-official
/plugin install snackpackgames-claude-plugins@snackpackgames
```

## Pull requests

Before opening or updating a PR, follow the metadata checklist in [`CONTRIBUTING.md`](CONTRIBUTING.md): assignee, labels, linked issues, milestone.

## Agent skills

### Issue tracker

Issues, specs, and wayfinder maps live in GitHub Issues for `snackpackgames/Rubbley`, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default canonical labels (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` at the repo root plus `docs/adr/`, both created lazily by `/domain-modeling`. See `docs/agents/domain.md`.
