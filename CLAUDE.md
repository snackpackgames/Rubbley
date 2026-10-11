# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rubbley is a 2.5D top-down physics action-puzzle game: the player stays centered while the level scrolls, and fights by manipulating gravity with three moves (Attract, Repel, Spin). Touch-first, with controller and mouse + keyboard schemes.

The game is **migrating from Unity to Godot**. The repo today is a Unity 2019.4 prototype (orbit/attractor physics in `Assets/Scripts/`, a toon shader, debug scenes). Treat the Unity code as reference for behaviour to port, not as architecture to preserve. Decisions about the Godot project (version, language, layout, what carries over) are open; they get settled through `/wayfinder` maps and recorded as ADRs in `docs/adr/`.

## Game design

The GDD is the source of truth for design intent. Read [`docs/gdd/rubbley-gdd.md`](docs/gdd/rubbley-gdd.md) before planning or building any gameplay feature. It is a snapshot of the Google Doc linked in its header; when the user says the GDD changed, re-export it with the command in that header and commit the refresh.

The GDD has open sections (Narrative, Visuals, level structure brainstorming). Surface those gaps as questions for the user; design answers come from them.

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

## Agent skills

### Issue tracker

Issues, specs, and wayfinder maps live in GitHub Issues for `snackpackgames/Rubbley`, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default canonical labels (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` at the repo root plus `docs/adr/`, both created lazily by `/domain-modeling`. See `docs/agents/domain.md`.
