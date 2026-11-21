class_name TouchReticle
extends Node2D
## A ring at the pinch centre while a pinch-in Attracts (ADR 0012), as wide as the touch
## hit radius, so the player sees what the pinch picked. Move Input moves and hides it.

## How the ring looks.
@export var tuning: TouchReticleTuning

var _radius_px := 0.0


func _ready() -> void:
	assert(tuning != null, "The touch reticle needs a TouchReticleTuning")
	hide()


func _draw() -> void:
	draw_arc(Vector2.ZERO, _radius_px, 0.0, TAU, 48, tuning.color, tuning.width_px, true)
	draw_circle(Vector2.ZERO, tuning.dot_radius_px, tuning.color)


## Shows the ring at [param at] in the viewport, [param radius_px] wide.
func show_at(at: Vector2, radius_px: float) -> void:
	position = at
	if not is_equal_approx(radius_px, _radius_px):
		_radius_px = radius_px
		queue_redraw()
	show()
