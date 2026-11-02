class_name Crosshair
extends Control
## Aiming reticle drawn around this node's origin. The HUD moves it to the mouse.

const RADIUS := 18.0
const GAP := 6.0
const TICK_LENGTH := 12.0
const COLOR_READY := Color(1.0, 1.0, 1.0)
const COLOR_EMPTY := Color(1.0, 0.3, 0.2)

## Turns the reticle red when the player is out of flash-pellets.
var empty := false:
	set(value):
		empty = value
		queue_redraw()


func _draw() -> void:
	var color := COLOR_EMPTY if empty else COLOR_READY
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, color, 2.0, true)
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(direction * GAP, direction * (GAP + TICK_LENGTH), color, 2.0, true)
	draw_circle(Vector2.ZERO, 2.0, color)
