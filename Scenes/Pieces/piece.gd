extends Node2D

enum PieceType  { PAWN, ROOK, KNIGHT, BISHOP, QUEEN, KING }
enum PieceColor { WHITE, BLACK }

@export var piece_type:  PieceType  = PieceType.PAWN
@export var piece_color: PieceColor = PieceColor.WHITE
@export var tile_size:   int        = 238

var board_position : Vector2i = Vector2i.ZERO
var is_selected    : bool     = false
var has_moved      : bool     = false

var _sprite        : Sprite2D
var _hint_layer    : Node2D

# Signal émis quand on clique sur la pièce
signal piece_clicked(piece: Node2D)

const TYPE_NAMES : Dictionary = {
	PieceType.PAWN:   "Pawn",
	PieceType.ROOK:   "Rook",
	PieceType.KNIGHT: "Knight",
	PieceType.BISHOP: "Bishop",
	PieceType.QUEEN:  "Queen",
	PieceType.KING:   "King",
}

func _get_texture_path() -> String:
	var prefix : String = "w" if piece_color == PieceColor.WHITE else "b"
	var folder : String = "White" if piece_color == PieceColor.WHITE else "Black"
	@warning_ignore("shadowed_variable_base_class")
	var name   : String = TYPE_NAMES[piece_type]
	return "res://Assets/Sprites/Pieces/%s/%s_%s.png" % [folder, prefix, name]

# ──────────────────────────────────────────────
#  Initialisation
# ──────────────────────────────────────────────
func _ready() -> void:
	_build_hint_layer()

func _build_sprite() -> void:
	if _sprite:
		_sprite.queue_free()

	_sprite = Sprite2D.new()
	_sprite.texture  = load(_get_texture_path())
	_sprite.centered = false

	var tex_size : Vector2 = _sprite.texture.get_size()
	_sprite.scale = Vector2(
		float(tile_size) / tex_size.x,
		float(tile_size) / tex_size.y
	)

	# Zone de clic via un Area2D + CollisionShape2D
	var area  := Area2D.new()
	var shape := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()
	rect.size          = Vector2(tile_size, tile_size)
	shape.shape        = rect
	shape.position     = Vector2(tile_size / 2.0, tile_size / 2.0)
	area.add_child(shape)
	area.input_pickable = true
	area.connect("input_event", _on_area_input)
	add_child(area)
	add_child(_sprite)

func _build_hint_layer() -> void:
	_hint_layer = Node2D.new()
	_hint_layer.name = "HintLayer"
	add_child(_hint_layer)

# ──────────────────────────────────────────────
#  Détection du clic
# ──────────────────────────────────────────────
func _on_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			get_viewport().set_input_as_handled()
			piece_clicked.emit(self)

# ──────────────────────────────────────────────
#  Setup public
# ──────────────────────────────────────────────
func setup(type: PieceType, color: PieceColor, board_pos: Vector2i) -> void:
	piece_type     = type
	piece_color    = color
	board_position = board_pos
	_build_sprite()
	_sync_visual_position()

# ──────────────────────────────────────────────
#  Position
# ──────────────────────────────────────────────
func _sync_visual_position() -> void:
	position = Vector2(board_position.x * tile_size,
					   board_position.y * tile_size)

func move_to(new_board_pos: Vector2i) -> void:
	board_position = new_board_pos
	has_moved = true
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
	var relative : Vector2 = Vector2(
		(target_board_pos.x - board_position.x) * tile_size + tile_size / 2.0,
		(target_board_pos.y - board_position.y) * tile_size + tile_size / 2.0
	)
	var hint := Node2D.new()
	hint.position = relative
	hint.set_script(_circle_draw_script(tile_size * 0.18, Color(0.0, 0.85, 0.2, 0.7)))
	return hint

func _circle_draw_script(radius: float, color: Color) -> GDScript:
	var src := GDScript.new()
	src.source_code = """
extends Node2D
var _r : float = {r}
var _c : Color  = Color({cr}, {cg}, {cb}, {ca})
func _draw() -> void:
	draw_circle(Vector2.ZERO, _r, _c)
""".format({"r": radius, "cr": color.r, "cg": color.g, "cb": color.b, "ca": color.a})
	src.reload()
	return src

# ──────────────────────────────────────────────
#  Mouvements légaux
# ──────────────────────────────────────────────
func get_valid_moves(board: Array) -> Array[Vector2i]:
	var moves : Array[Vector2i] = []
	match piece_type:
		PieceType.PAWN:   moves = _pawn_moves(board)
		PieceType.ROOK:   moves = _sliding_moves(board, [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)])
		PieceType.KNIGHT: moves = _knight_moves(board)
		PieceType.BISHOP: moves = _sliding_moves(board, [Vector2i(1,1), Vector2i(-1,1), Vector2i(1,-1), Vector2i(-1,-1)])
		PieceType.QUEEN:  moves = _sliding_moves(board, [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1),
														  Vector2i(1,1), Vector2i(-1,1), Vector2i(1,-1), Vector2i(-1,-1)])
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
		Vector2i(2,1), Vector2i(2,-1), Vector2i(-2,1), Vector2i(-2,-1),
		Vector2i(1,2), Vector2i(1,-2), Vector2i(-1,2), Vector2i(-1,-2)
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
