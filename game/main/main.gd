class_name Main
extends Node
## The persistent root scene. It owns the current level and swaps levels in and
## out as its children, so nothing calls [code]change_scene_to_file[/code] (ADR 0016).
## It owns the UI layer too, which outlives levels, and points the HUD at each level's
## Rubbley as it loads.

## The level loaded when the game starts.
@export var start_level: PackedScene
## The HUD, in the UI layer.
@export var hud: Hud

var _level: Node


func _ready() -> void:
	assert(hud != null, "%s needs a Hud" % name)
	load_level(start_level)


## Frees the current level, if any, and adds a new instance of [param level_scene] as a
## child, and points the HUD at its Rubbley. Unloading a level interrupts Move Input
## (ADR 0013).
func load_level(level_scene: PackedScene) -> void:
	assert(level_scene != null, "load_level needs a level scene")
	if _level != null:
		hud.unwatch()
		MoveInputService.instance.interrupt()
		remove_child(_level)
		_level.queue_free()
	_level = level_scene.instantiate()
	add_child(_level)
	var level := _level as Level
	if level != null and level.rubbley_mass != null:
		hud.watch(level.rubbley_mass)
