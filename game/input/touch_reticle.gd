class_name TouchReticle
extends Node2D
## A ring at the pinch centre while two fingers aim (ADR 0012), as wide as the touch hit
## radius, so the player sees what a pinch will pick. Move Input moves and hides it.

## The ring's colour.
@export var color := Color(1.0, 1.0, 1.0, 0.7)
## The ring's line width, in pixels.
@export_range(0.5, 10.0, 0.5) var width_px := 2.0
## The centre dot's radius, in pixels.
@export_range(0.0, 10.0, 0.5) var dot_radius_px := 3.0

var _radius_px := 0.0


func _ready() -> void:
	hide()


func _draw() -> void:
	draw_arc(Vector2.ZERO, _radius_px, 0.0, TAU, 48, color, width_px, true)
	draw_circle(Vector2.ZERO, dot_radius_px, color)


## Shows the ring at [param at] in the viewport, [param radius_px] wide.
func show_at(at: Vector2, radius_px: float) -> void:
	position = at
	if not is_equal_approx(radius_px, _radius_px):
		_radius_px = radius_px
		queue_redraw()
	show()
