class_name FreeLevelsList
extends Resource
## The set of always-free level ids playable under the Free Tier (ADRs 0015, 0019).
## Read-only at runtime.

## Ids of levels that anyone can play without the Full Game.
@export var free_level_ids: Array[StringName] = []
