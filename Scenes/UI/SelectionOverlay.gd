# SelectionOverlay.gd
extends Node2D

var tile_size : int   = 238
var color     : Color = Color(0.0, 0.0, 0.0, 0.25)  # sombre semi-transparent

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(tile_size, tile_size)), color)
