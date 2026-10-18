# Godot project at the repo root; Unity moves to `unity/` until it's retired

`project.godot` lives at the repo root, so Godot's `res://` paths match repo paths and CI, `setup-godot` and agents all run `godot --path .`. The Unity 2019.4 prototype (`Assets/`, `Packages/`, `ProjectSettings/`) moves into `unity/` with `git mv`, in the same PR that creates `project.godot`, and stays there as reference only. Godot's root is permanent, so removing Unity later is a pure deletion with nothing else to move.

## Fixed top-level paths

- `project.godot` and `.godot-version` (ADR 0004) at the root. Godot's `.godot/` cache is gitignored.
- `addons/`, which Godot requires, for third-party addons.
- `unity/`, `art/` and `docs/` each hold a `.gdignore` so Godot never scans them. Godot already skips dot-folders such as `.claude/`.
- `art/` (renamed from `Art/`) holds engine-neutral source art such as `rubbley.blend`. Godot 4 would otherwise try to import `.blend` files directly. Exported `.glb` files are committed inside the Godot project. Blender's `*.blend1` backups are gitignored, not tracked.
- The Unity ignore rules in `.gitignore` are anchored to the root, so they get a `/unity/` prefix.

This ADR sets only the top level. The folder scheme inside the project, and with it the asteroid `.glb`'s path (ADR 0008), belongs to the architecture-conventions decision. The test folder belongs to the test-framework decision, because gdUnit4 and GUT expect different defaults.

## Retiring Unity

The Unity code is reference, not a spec. Much of it isn't what the game wants, and redesigning any system is fair game. Unity becomes *eligible* for removal once every behaviour it demonstrates is either covered in Godot or deliberately dropped. The live checklist is in [Retire the Unity prototype](https://github.com/snackpackgames/Rubbley/issues/69). Meeting the checklist doesn't remove Unity automatically: a human decides when. Removal works like this:

1. Push an annotated tag `unity-prototype` on the last commit that still contains `unity/`.
2. In its own PR, delete `unity/`, the Unity `.gitignore` rules and the Unity `.vscode` settings, and repoint any doc link into `unity/` at the tag.

## Considered Options

- **Godot in `godot/`, Unity left at the root**: rejected. The permanent project would sit in a subfolder forever, or move again once Unity goes.
- **Both at the root, separated by `.gdignore`**: rejected. Unity's `Assets/` would sit next to Godot's assets, and the Unity ignore rules would be mixed in with Godot's.
- **Parity as a removal gate**: rejected. The Godot build is a rewrite (ADR 0006), so "identical behaviour" isn't the goal.
- **Archive branch or separate repo for Unity**: rejected. History already keeps everything. A tag is a free, stable bookmark, while a branch can drift or be deleted by mistake.
