extends Node
## The persistent root scene. It owns the current level and swaps levels in and
## out as its children, so nothing calls [code]change_scene_to_file[/code] (ADR 0016).

## The level loaded when the game starts.
@export var start_level: PackedScene

var _level: Node


func _ready() -> void:
	load_level(start_level)


## Frees the current level, if any, and adds a new instance of [param level_scene] as a child.
func load_level(level_scene: PackedScene) -> void:
	assert(level_scene != null, "load_level needs a level scene")
	if _level != null:
		remove_child(_level)
		_level.queue_free()
	_level = level_scene.instantiate()
	add_child(_level)
