class_name AimCursor
extends Node2D
## The controller's aim cursor (ADR 0012): a ring and crosshair where the controller aims,
## shown while the controller owns the aim. Move Input moves and hides it.

## How the cursor looks.
@export var tuning: AimCursorTuning

var _on_rubbley := true


func _ready() -> void:
	assert(tuning != null, "The aim cursor needs an AimCursorTuning")
	hide()


func _draw() -> void:
	var color := tuning.on_rubbley_color if _on_rubbley else tuning.color
	draw_arc(Vector2.ZERO, tuning.radius_px, 0.0, TAU, 32, color, tuning.width_px, true)
	var across := Vector2(tuning.crosshair_px, 0.0)
	var down := Vector2(0.0, tuning.crosshair_px)
	draw_line(-across, across, color, 1.0, true)
	draw_line(-down, down, color, 1.0, true)


## Shows the cursor at [param at] in the viewport, in its at-rest look when
## [param on_rubbley].
func show_at(at: Vector2, on_rubbley: bool) -> void:
	position = at
	if on_rubbley != _on_rubbley:
		_on_rubbley = on_rubbley
		queue_redraw()
	show()
