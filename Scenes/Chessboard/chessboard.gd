extends Node2D

@export var board_size: int = 8
@export var tile_size: int = 238

@onready var light_texture = preload("res://Assets/Sprites/LightCase.png")
@onready var dark_texture = preload("res://Assets/Sprites/DarkCase.png")

func _ready():
	generate_board()
	setup_camera()

func generate_board():
	for y in range(board_size):
		for x in range(board_size):
			var tile = Sprite2D.new()
			# Alternance classique échiquier
			var is_light = (x + y) % 2 == 0
			if is_light:
				tile.texture = light_texture
			else:
				tile.texture = dark_texture
			# Positionnement
			tile.position = Vector2(
				x * tile_size,
				y * tile_size
			)
			tile.centered = false
			add_child(tile)

func setup_camera():
	var cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	# Centre approximatif de l'échiquier
	cam.position = Vector2(
		(board_size * tile_size) / 2,
		(board_size * tile_size) / 2
	)
	cam.zoom = Vector2(0.3, 0.3)
