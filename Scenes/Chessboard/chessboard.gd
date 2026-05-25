extends Node2D

const PieceScene  = preload("res://Scenes/Pieces/Piece.tscn")
const PieceScript = preload("res://Scenes/Pieces/Piece.gd")

@export var board_size : int = 8
@export var tile_size  : int = 238

@onready var light_texture = preload("res://Assets/Sprites/Board/LightCase.png")
@onready var dark_texture  = preload("res://Assets/Sprites/Board/DarkCase.png")
@onready var _camera       : Camera2D = $Camera2D

var board          : Array[Array]    = []
var selected_piece : Node2D          = null
var valid_moves    : Array[Vector2i] = []

# Mise en évidence du dernier coup
var _last_move_overlays : Array[Node2D] = []

func _ready() -> void:
	_init_board()
	generate_board()
	setup_camera()
	spawn_piece(PieceScript.PieceType.QUEEN, PieceScript.PieceColor.WHITE, Vector2i(3, 7))

# ──────────────────────────────────────────────
#  Initialisation du tableau logique
# ──────────────────────────────────────────────
func _init_board() -> void:
	board = []
	for y in range(board_size):
		board.append(Array())
		board[y].resize(board_size)
		board[y].fill(null)

# ──────────────────────────────────────────────
#  Génération visuelle de l'échiquier
# ──────────────────────────────────────────────
func generate_board() -> void:
	for y in range(board_size):
		for x in range(board_size):
			var tile      := Sprite2D.new()
			var is_light  := (x + y) % 2 == 0
			tile.texture  = light_texture if is_light else dark_texture
			tile.position = Vector2(x * tile_size, y * tile_size)
			tile.centered = false
			add_child(tile)

func setup_camera() -> void:
	_camera.make_current()
	_camera.position = Vector2(
		(board_size * tile_size) / 2.0,
		(board_size * tile_size) / 2.0
	)
	_camera.zoom = Vector2(0.3, 0.3)

# ──────────────────────────────────────────────
#  Spawn d'une pièce
# ──────────────────────────────────────────────
func spawn_piece(type: PieceScript.PieceType, color: PieceScript.PieceColor, board_pos: Vector2i) -> void:
	var piece = PieceScene.instantiate()
	add_child(piece)
	piece.z_index = 2
	piece.setup(type, color, board_pos)
	board[board_pos.y][board_pos.x] = piece
	piece.piece_clicked.connect(_on_piece_clicked)

# ──────────────────────────────────────────────
#  Clic sur une pièce
# ──────────────────────────────────────────────
func _on_piece_clicked(piece: Node2D) -> void:
	if selected_piece != null and selected_piece != piece:
		if piece.board_position in valid_moves:
			_move_selected_to(piece.board_position)
			return

	if selected_piece == piece:
		selected_piece.deselect()
		selected_piece = null
		valid_moves.clear()
		return

	if selected_piece != null:
		selected_piece.deselect()

	selected_piece = piece
	valid_moves    = piece.get_valid_moves(board)
	piece.select_piece(valid_moves)

# ──────────────────────────────────────────────
#  Clic sur une case vide (destination)
# ──────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if selected_piece == null:
				return
			var world_pos : Vector2  = get_global_mouse_position()
			var board_pos : Vector2i = Vector2i(
				int(world_pos.x / tile_size),
				int(world_pos.y / tile_size)
			)
			if _is_in_bounds(board_pos) and board_pos in valid_moves:
				if board[board_pos.y][board_pos.x] == null:
					_move_selected_to(board_pos)
					get_viewport().set_input_as_handled()

# ──────────────────────────────────────────────
#  Déplacement effectif
# ──────────────────────────────────────────────
func _move_selected_to(target: Vector2i) -> void:
	var from : Vector2i = selected_piece.board_position

	var occupant = board[target.y][target.x]
	if occupant != null:
		board[target.y][target.x] = null
		occupant.queue_free()

	board[from.y][from.x]       = null
	board[target.y][target.x]   = selected_piece

	selected_piece.deselect()
	selected_piece.move_to(target)

	# Mise en évidence du dernier coup
	_highlight_last_move(from, target)

	selected_piece = null
	valid_moves.clear()

# ──────────────────────────────────────────────
#  Mise en évidence du dernier coup
# ──────────────────────────────────────────────
func _highlight_last_move(from: Vector2i, to: Vector2i) -> void:
	# Supprime les overlays du coup précédent
	for overlay in _last_move_overlays:
		overlay.queue_free()
	_last_move_overlays.clear()

	# Crée un overlay pour la case de départ et la case d'arrivée
	for cell in [from, to]:
		var overlay := _make_move_overlay(cell)
		add_child(overlay)
		_last_move_overlays.append(overlay)

func _make_move_overlay(cell: Vector2i) -> Node2D:
	var overlay        := Node2D.new()
	overlay.position   = Vector2(cell.x * tile_size, cell.y * tile_size)
	overlay.z_index    = 0  # Au dessus des cases, en dessous des pièces

	# Script de dessin inline — simple rectangle semi-transparent vert
	var src            := GDScript.new()
	src.source_code    = """
extends Node2D
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2({s}, {s})), Color(0.2, 0.7, 0.2, 0.4))
""".format({"s": tile_size})
	src.reload()
	overlay.set_script(src)
	return overlay

func _is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < board_size and pos.y >= 0 and pos.y < board_size
