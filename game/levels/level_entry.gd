class_name LevelEntry
extends Resource
## Metadata for one playable level in the level catalog (ADR 0015, 0016). Read-only at
## runtime.

## Stable level id checked against [FreeLevelsList] and saves.
@export var id: StringName
## Player-facing name shown in the level switcher and Unlock prompt.
@export var display_name := ""
## The level scene Main instantiates when this entry is selected.
@export var scene: PackedScene
