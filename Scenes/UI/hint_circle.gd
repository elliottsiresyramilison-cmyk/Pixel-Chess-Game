#hint_circle.gd
extends Node2D
var radius : float = 40.0
var color  : Color = Color(0.0, 0.85, 0.2, 0.7)
func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
