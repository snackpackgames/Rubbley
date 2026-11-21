class_name HudBar
extends Control
## A flat bar the HUD fills from the left to show a share, such as Stamina left.

## How full the bar is, from 0 to 1.
@export_range(0.0, 1.0, 0.001) var value := 1.0:
	set(new_value):
		value = clampf(new_value, 0.0, 1.0)
		queue_redraw()
## The filled part's colour.
@export var fill_color := Color.WHITE:
	set(new_color):
		fill_color = new_color
		queue_redraw()
## The empty part's colour.
@export var back_color := Color(0.0, 0.0, 0.0, 0.5):
	set(new_color):
		back_color = new_color
		queue_redraw()
## The outline's colour.
@export var outline_color := Color(1.0, 1.0, 1.0, 0.6):
	set(new_color):
		outline_color = new_color
		queue_redraw()


func _draw() -> void:
	var whole := Rect2(Vector2.ZERO, size)
	draw_rect(whole, back_color)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * value, size.y)), fill_color)
	draw_rect(whole, outline_color, false, 1.0)
