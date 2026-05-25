# Piece.gd
extends Node2D

enum PieceType  { PAWN, ROOK, KNIGHT, BISHOP, QUEEN, KING }
enum PieceColor { WHITE, BLACK }

@export var piece_type:  PieceType  = PieceType.PAWN
@export var piece_color: PieceColor = PieceColor.WHITE
@export var tile_size:   int        = 238

var board_position : Vector2i = Vector2i.ZERO
var is_selected    : bool     = false
var has_moved      : bool     = false

signal piece_clicked(piece: Node2D)

# ──────────────────────────────────────────────
#  Références aux noeuds enfants (définis dans Piece.tscn)
# ──────────────────────────────────────────────
@onready var _sprite     : Sprite2D  = $Sprite2D
@onready var _area       : Area2D    = $Area2D
@onready var _hint_layer : Node2D    = $HintLayer

# ──────────────────────────────────────────────
#  Textures préchargées — plus de load() au runtime
# ──────────────────────────────────────────────
const TEXTURES : Dictionary = {
	"w_Pawn":   preload("res://Assets/Sprites/Pieces/White/w_Pawn.png"),
	"w_Rook":   preload("res://Assets/Sprites/Pieces/White/w_Rook.png"),
	"w_Knight": preload("res://Assets/Sprites/Pieces/White/w_Knight.png"),
	"w_Bishop": preload("res://Assets/Sprites/Pieces/White/w_Bishop.png"),
	"w_Queen":  preload("res://Assets/Sprites/Pieces/White/w_Queen.png"),
	"w_King":   preload("res://Assets/Sprites/Pieces/White/w_King.png"),
	"b_Pawn":   preload("res://Assets/Sprites/Pieces/Black/b_Pawn.png"),
	"b_Rook":   preload("res://Assets/Sprites/Pieces/Black/b_Rook.png"),
	"b_Knight": preload("res://Assets/Sprites/Pieces/Black/b_Knight.png"),
	"b_Bishop": preload("res://Assets/Sprites/Pieces/Black/b_Bishop.png"),
	"b_Queen":  preload("res://Assets/Sprites/Pieces/Black/b_Queen.png"),
	"b_King":   preload("res://Assets/Sprites/Pieces/Black/b_King.png"),
}

const TYPE_NAMES : Dictionary = {
	PieceType.PAWN:   "Pawn",
	PieceType.ROOK:   "Rook",
	PieceType.KNIGHT: "Knight",
	PieceType.BISHOP: "Bishop",
	PieceType.QUEEN:  "Queen",
	PieceType.KING:   "King",
}

const HintCircle = preload("res://Scenes/UI/HintCircle.tscn")

# ──────────────────────────────────────────────
#  Initialisation
# ──────────────────────────────────────────────
func _ready() -> void:
	_area.input_event.connect(_on_area_input)

func _apply_texture() -> void:
	var key          : String = "%s_%s" % ["w" if piece_color == PieceColor.WHITE else "b", TYPE_NAMES[piece_type]]
	_sprite.texture  = TEXTURES[key]
	_sprite.centered = false
	var tex_size     := _sprite.texture.get_size()
	_sprite.scale    = Vector2(float(tile_size) / tex_size.x, float(tile_size) / tex_size.y)

# ──────────────────────────────────────────────
#  Détection du clic
# ──────────────────────────────────────────────
func _on_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			get_viewport().set_input_as_handled()
			piece_clicked.emit(self)

# ──────────────────────────────────────────────
#  Setup public — appelé par Chessboard.gd
# ──────────────────────────────────────────────
func setup(type: PieceType, color: PieceColor, board_pos: Vector2i) -> void:
	piece_type     = type
	piece_color    = color
	board_position = board_pos
	_apply_texture()
	_sync_visual_position()

# ──────────────────────────────────────────────
#  Position
# ──────────────────────────────────────────────
func _sync_visual_position() -> void:
	position = Vector2(board_position.x * tile_size,
					   board_position.y * tile_size)

func move_to(new_board_pos: Vector2i) -> void:
	board_position = new_board_pos
	has_moved      = true
	_sync_visual_position()

# ──────────────────────────────────────────────
#  Sélection
# ──────────────────────────────────────────────
func select_piece(valid_moves: Array[Vector2i]) -> void:
	is_selected = true
	_show_move_hints(valid_moves)

func deselect() -> void:
	is_selected = false
	_clear_hints()

# ──────────────────────────────────────────────
#  Cercles verts
# ──────────────────────────────────────────────
func _show_move_hints(moves: Array[Vector2i]) -> void:
	_clear_hints()
	for move in moves:
		_hint_layer.add_child(_make_hint_circle(move))

func _clear_hints() -> void:
	for child in _hint_layer.get_children():
		child.queue_free()

func _make_hint_circle(target_board_pos: Vector2i) -> Node2D:
	var hint      := HintCircle.instantiate()
	hint.position = Vector2(
		(target_board_pos.x - board_position.x) * tile_size + tile_size / 2.0,
		(target_board_pos.y - board_position.y) * tile_size + tile_size / 2.0
	)
	hint.radius   = tile_size * 0.18
	return hint

# ──────────────────────────────────────────────
#  Mouvements légaux
# ──────────────────────────────────────────────
func get_valid_moves(board: Array) -> Array[Vector2i]:
	var moves : Array[Vector2i] = []
	match piece_type:
		PieceType.PAWN:   moves = _pawn_moves(board)
		PieceType.ROOK:   moves = _sliding_moves(board, [Vector2i(1,0),  Vector2i(-1,0),
														  Vector2i(0,1),  Vector2i(0,-1)])
		PieceType.KNIGHT: moves = _knight_moves(board)
		PieceType.BISHOP: moves = _sliding_moves(board, [Vector2i(1,1),  Vector2i(-1,1),
														  Vector2i(1,-1), Vector2i(-1,-1)])
		PieceType.QUEEN:  moves = _sliding_moves(board, [Vector2i(1,0),  Vector2i(-1,0),
														  Vector2i(0,1),  Vector2i(0,-1),
														  Vector2i(1,1),  Vector2i(-1,1),
														  Vector2i(1,-1), Vector2i(-1,-1)])
		PieceType.KING:   moves = _king_moves(board)
	return moves

func _in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8

func _is_enemy(board: Array, pos: Vector2i) -> bool:
	var cell = board[pos.y][pos.x]
	return cell != null and cell.piece_color != piece_color

func _is_empty(board: Array, pos: Vector2i) -> bool:
	return board[pos.y][pos.x] == null

func _pawn_moves(board: Array) -> Array[Vector2i]:
	var moves     : Array[Vector2i] = []
	var dir       : int = -1 if piece_color == PieceColor.WHITE else 1
	var start_row : int =  6 if piece_color == PieceColor.WHITE else 1

	var one_forward := Vector2i(board_position.x, board_position.y + dir)
	if _in_bounds(one_forward) and _is_empty(board, one_forward):
		moves.append(one_forward)
		if board_position.y == start_row:
			var two_forward := Vector2i(board_position.x, board_position.y + dir * 2)
			if _is_empty(board, two_forward):
				moves.append(two_forward)

	for dx in [-1, 1]:
		var cap := Vector2i(board_position.x + dx, board_position.y + dir)
		if _in_bounds(cap) and _is_enemy(board, cap):
			moves.append(cap)
	return moves

func _sliding_moves(board: Array, directions: Array[Vector2i]) -> Array[Vector2i]:
	var moves : Array[Vector2i] = []
	for d : Vector2i in directions:
		var cur : Vector2i = board_position + d
		while _in_bounds(cur):
			if _is_empty(board, cur):
				moves.append(cur)
			elif _is_enemy(board, cur):
				moves.append(cur)
				break
			else:
				break
			cur += d
	return moves

func _knight_moves(board: Array) -> Array[Vector2i]:
	var moves : Array[Vector2i] = []
	var jumps : Array[Vector2i] = [
		Vector2i(2,1),  Vector2i(2,-1),  Vector2i(-2,1),  Vector2i(-2,-1),
		Vector2i(1,2),  Vector2i(1,-2),  Vector2i(-1,2),  Vector2i(-1,-2)
	]
	for j in jumps:
		var target := board_position + j
		if _in_bounds(target) and (_is_empty(board, target) or _is_enemy(board, target)):
			moves.append(target)
	return moves

func _king_moves(board: Array) -> Array[Vector2i]:
	var moves : Array[Vector2i] = []
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var target := board_position + Vector2i(dx, dy)
			if _in_bounds(target) and (_is_empty(board, target) or _is_enemy(board, target)):
				moves.append(target)
	return moves
