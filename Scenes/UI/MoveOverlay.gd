extends Node2D

var tile_size : int   = 238
var color     : Color = Color(0.2, 0.7, 0.2, 0.4)  # vert par défaut, rouge si échec

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(tile_size, tile_size)), color)
