class_name LevelCatalog
extends Resource
## Ordered list of levels available to Main's level switcher. Read-only at runtime.

## The levels, in switcher order. The first entry is the starting level.
@export var entries: Array[LevelEntry] = []
