class_name AimCursor
extends Node2D
## The controller's aim cursor (ADR 0012): a ring and crosshair where the controller aims,
## shown while the controller owns the aim and fading out when idle. Move Input moves,
## fades and hides it.

## How the cursor looks and fades.
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
## [param on_rubbley], at [param opacity] (0 hides it).
func show_at(at: Vector2, on_rubbley: bool, opacity: float = 1.0) -> void:
	if opacity <= 0.0:
		hide()
		return
	position = at
	modulate.a = clampf(opacity, 0.0, 1.0)
	if on_rubbley != _on_rubbley:
		_on_rubbley = on_rubbley
		queue_redraw()
	show()
