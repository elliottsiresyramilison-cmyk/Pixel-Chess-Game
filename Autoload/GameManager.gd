# GameManager.gd
extends Node

const PieceScript = preload("res://Scenes/Pieces/Piece.gd")

# ──────────────────────────────────────────────
#  Signaux
# ──────────────────────────────────────────────
signal turn_changed(color)
signal check_detected(color)
signal checkmate_detected(color)
signal stalemate_detected()
signal promotion_needed(pawn)

# ──────────────────────────────────────────────
#  État de la partie
# ──────────────────────────────────────────────
var current_turn      : int     = PieceScript.PieceColor.WHITE
var en_passant_target : Vector2i = Vector2i(-1, -1)
var is_game_over      : bool    = false

# ──────────────────────────────────────────────
#  Gestion du tour
# ──────────────────────────────────────────────
func next_turn() -> void:
	current_turn = PieceScript.PieceColor.BLACK if current_turn == PieceScript.PieceColor.WHITE \
				 else PieceScript.PieceColor.WHITE
	turn_changed.emit(current_turn)

func is_turn(color: int) -> bool:
	return current_turn == color

# ──────────────────────────────────────────────
#  Utilitaires plateau
# ──────────────────────────────────────────────
func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8

func is_empty(board: Array, pos: Vector2i) -> bool:
	return board[pos.y][pos.x] == null

func is_enemy(board: Array, pos: Vector2i, color: int) -> bool:
	var cell = board[pos.y][pos.x]
	return cell != null and cell.piece_color != color

func is_ally(board: Array, pos: Vector2i, color: int) -> bool:
	var cell = board[pos.y][pos.x]
	return cell != null and cell.piece_color == color

# ──────────────────────────────────────────────
#  Calcul des mouvements bruts
# ──────────────────────────────────────────────
func get_raw_moves(board: Array, piece) -> Array[Vector2i]:
	var moves : Array[Vector2i] = []
	var T     := PieceScript.PieceType
	match piece.piece_type:
		T.PAWN:   moves = _pawn_moves(board, piece)
		T.ROOK:   moves = _sliding_moves(board, piece, [Vector2i(1,0),  Vector2i(-1,0),
														 Vector2i(0,1),  Vector2i(0,-1)])
		T.KNIGHT: moves = _knight_moves(board, piece)
		T.BISHOP: moves = _sliding_moves(board, piece, [Vector2i(1,1),  Vector2i(-1,1),
														 Vector2i(1,-1), Vector2i(-1,-1)])
		T.QUEEN:  moves = _sliding_moves(board, piece, [Vector2i(1,0),  Vector2i(-1,0),
														 Vector2i(0,1),  Vector2i(0,-1),
														 Vector2i(1,1),  Vector2i(-1,1),
														 Vector2i(1,-1), Vector2i(-1,-1)])
		T.KING:   moves = _king_moves(board, piece)
	return moves

# ──────────────────────────────────────────────
#  Mouvements légaux (filtrés)
# ──────────────────────────────────────────────
func get_valid_moves(board: Array, piece) -> Array[Vector2i]:
	var raw   := get_raw_moves(board, piece)
	var legal : Array[Vector2i] = []
	for move in raw:
		if not _move_leaves_king_in_check(board, piece, move):
			legal.append(move)
	if piece.piece_type == PieceScript.PieceType.KING:
		legal.append_array(_castling_moves(board, piece))
	return legal

# ──────────────────────────────────────────────
#  Simulation — le mouvement laisse-t-il le roi en échec ?
# ──────────────────────────────────────────────
func _move_leaves_king_in_check(board: Array, piece, target: Vector2i) -> bool:
	var sim       := _copy_board(board)
	var from_pos  : Vector2i = piece.board_position
	sim[target.y][target.x]    = sim[from_pos.y][from_pos.x]
	sim[from_pos.y][from_pos.x] = null
	return is_in_check(sim, piece.piece_color as int)

func _copy_board(board: Array) -> Array:
	var copy : Array = []
	for y in range(8):
		var row : Array = []
		for x in range(8):
			row.append(board[y][x])
		copy.append(row)
	return copy

# ──────────────────────────────────────────────
#  Détection de l'échec
# ──────────────────────────────────────────────
func is_in_check(board: Array, color: int) -> bool:
	var king_pos : Vector2i = _find_king(board, color)
	if king_pos == Vector2i(-1, -1):
		return false
	return _is_square_attacked(board, king_pos, color)

func _find_king(board: Array, color: int) -> Vector2i:
	for y in range(8):
		for x in range(8):
			var cell = board[y][x]
			if cell != null and cell.piece_type == PieceScript.PieceType.KING \
			and cell.piece_color == color:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _is_square_attacked(board: Array, pos: Vector2i, defender_color: int) -> bool:
	var attacker_color : int = PieceScript.PieceColor.BLACK \
						if defender_color == PieceScript.PieceColor.WHITE \
						else PieceScript.PieceColor.WHITE
	for y in range(8):
		for x in range(8):
			var cell = board[y][x]
			if cell != null and cell.piece_color == attacker_color:
				var raw := get_raw_moves(board, cell)
				if pos in raw:
					return true
	return false

# ──────────────────────────────────────────────
#  Détection échec et mat / pat
# ──────────────────────────────────────────────
func get_all_valid_moves(board: Array, color: int) -> Array[Vector2i]:
	var all_moves : Array[Vector2i] = []
	for y in range(8):
		for x in range(8):
			var cell = board[y][x]
			if cell != null and cell.piece_color == color:
				all_moves.append_array(get_valid_moves(board, cell))
	return all_moves

func check_game_state(board: Array, color: int) -> void:
	if is_game_over:
		return
	var moves := get_all_valid_moves(board, color)
	if moves.is_empty():
		if is_in_check(board, color):
			is_game_over = true
			checkmate_detected.emit(color)
		else:
			is_game_over = true
			stalemate_detected.emit()
	elif is_in_check(board, color):
		check_detected.emit(color)

# ──────────────────────────────────────────────
#  Mouvements par type de pièce
# ──────────────────────────────────────────────
func _pawn_moves(board: Array, piece) -> Array[Vector2i]:
	var moves     : Array[Vector2i] = []
	var color     : int     = piece.piece_color
	var pos       : Vector2i = piece.board_position
	var dir       : int = -1 if color == PieceScript.PieceColor.WHITE else 1
	var start_row : int =  6 if color == PieceScript.PieceColor.WHITE else 1

	var one_fwd : Vector2i = Vector2i(pos.x, pos.y + dir)
	if in_bounds(one_fwd) and is_empty(board, one_fwd):
		moves.append(one_fwd)
		if pos.y == start_row:
			var two_fwd : Vector2i = Vector2i(pos.x, pos.y + dir * 2)
			if is_empty(board, two_fwd):
				moves.append(two_fwd)

	for dx in [-1, 1]:
		var cap : Vector2i = Vector2i(pos.x + dx, pos.y + dir)
		if in_bounds(cap) and is_enemy(board, cap, color):
			moves.append(cap)

	if en_passant_target != Vector2i(-1, -1):
		for dx in [-1, 1]:
			var ep : Vector2i = Vector2i(pos.x + dx, pos.y + dir)
			if ep == en_passant_target:
				moves.append(ep)

	return moves

func _sliding_moves(board: Array, piece, directions: Array[Vector2i]) -> Array[Vector2i]:
	var moves : Array[Vector2i] = []
	var color : int      = piece.piece_color
	var pos   : Vector2i = piece.board_position
	for d : Vector2i in directions:
		var cur : Vector2i = pos + d
		while in_bounds(cur):
			if is_empty(board, cur):
				moves.append(cur)
			elif is_enemy(board, cur, color):
				moves.append(cur)
				break
			else:
				break
			cur += d
	return moves

func _knight_moves(board: Array, piece) -> Array[Vector2i]:
	var moves : Array[Vector2i] = []
	var color : int      = piece.piece_color
	var pos   : Vector2i = piece.board_position
	var jumps : Array[Vector2i] = [
		Vector2i(2,1),  Vector2i(2,-1),  Vector2i(-2,1),  Vector2i(-2,-1),
		Vector2i(1,2),  Vector2i(1,-2),  Vector2i(-1,2),  Vector2i(-1,-2)
	]
	for j in jumps:
		var target : Vector2i = pos + j
		if in_bounds(target) and not is_ally(board, target, color):
			moves.append(target)
	return moves

func _king_moves(board: Array, piece) -> Array[Vector2i]:
	var moves : Array[Vector2i] = []
	var color : int      = piece.piece_color
	var pos   : Vector2i = piece.board_position
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var target : Vector2i = pos + Vector2i(dx, dy)
			if in_bounds(target) and not is_ally(board, target, color):
				moves.append(target)
	return moves

# ──────────────────────────────────────────────
#  Roque
# ──────────────────────────────────────────────
func _castling_moves(board: Array, king) -> Array[Vector2i]:
	var moves : Array[Vector2i] = []
	var color : int      = king.piece_color
	var pos   : Vector2i = king.board_position

	if king.has_moved or is_in_check(board, color):
		return moves

	var row : int = 7 if color == PieceScript.PieceColor.WHITE else 0

	var rook_k = board[row][7]
	if rook_k != null and rook_k.piece_type == PieceScript.PieceType.ROOK \
	and not rook_k.has_moved:
		if is_empty(board, Vector2i(5, row)) and is_empty(board, Vector2i(6, row)):
			if not _is_square_attacked(board, Vector2i(5, row), color) \
			and not _is_square_attacked(board, Vector2i(6, row), color):
				moves.append(Vector2i(6, row))

	var rook_q = board[row][0]
	if rook_q != null and rook_q.piece_type == PieceScript.PieceType.ROOK \
	and not rook_q.has_moved:
		if is_empty(board, Vector2i(1, row)) and is_empty(board, Vector2i(2, row)) \
		and is_empty(board, Vector2i(3, row)):
			if not _is_square_attacked(board, Vector2i(3, row), color) \
			and not _is_square_attacked(board, Vector2i(2, row), color):
				moves.append(Vector2i(2, row))

	return moves

func apply_castling(board: Array, king, target: Vector2i) -> void:
	var row : int = king.board_position.y
	if target.x == 6:
		var rook = board[row][7]
		board[row][7] = null
		board[row][5] = rook
		rook.move_to(Vector2i(5, row))
	elif target.x == 2:
		var rook = board[row][0]
		board[row][0] = null
		board[row][3] = rook
		rook.move_to(Vector2i(3, row))

# ──────────────────────────────────────────────
#  En passant
# ──────────────────────────────────────────────
func update_en_passant(piece, from: Vector2i, to: Vector2i) -> void:
	if piece.piece_type == PieceScript.PieceType.PAWN and abs(to.y - from.y) == 2:
		var dir : int = -1 if piece.piece_color == PieceScript.PieceColor.WHITE else 1
		en_passant_target = Vector2i(to.x, to.y - dir)
	else:
		en_passant_target = Vector2i(-1, -1)

func apply_en_passant(board: Array, piece, target: Vector2i) -> void:
	if piece.piece_type != PieceScript.PieceType.PAWN:
		return
	if target != en_passant_target:
		return
	var captured_pos : Vector2i = Vector2i(target.x, piece.board_position.y)
	var captured     = board[captured_pos.y][captured_pos.x]
	if captured != null:
		board[captured_pos.y][captured_pos.x] = null
		captured.queue_free()

# ──────────────────────────────────────────────
#  Promotion
# ──────────────────────────────────────────────
func check_promotion(board: Array, piece) -> void:
	if piece.piece_type != PieceScript.PieceType.PAWN:
		return
	var last_row : int = 0 if piece.piece_color == PieceScript.PieceColor.WHITE else 7
	if piece.board_position.y == last_row:
		promotion_needed.emit(piece)

func apply_promotion(board: Array, pawn, new_type: int) -> void:
	pawn.piece_type = new_type
	pawn._apply_texture()
	board[pawn.board_position.y][pawn.board_position.x] = pawn

# ──────────────────────────────────────────────
#  Mise en évidence visuelle
# ──────────────────────────────────────────────
func get_hint_color(board: Array, target: Vector2i, moving_piece) -> Color:
	var cell = board[target.y][target.x]
	if cell != null and cell.piece_type == PieceScript.PieceType.KING:
		return Color(0.9, 0.1, 0.1, 0.7)
	if is_enemy(board, target, moving_piece.piece_color as int):
		return Color(0.1, 0.8, 0.1, 0.7)
	return Color(0.0, 0.85, 0.2, 0.7)

# ──────────────────────────────────────────────
#  Reset
# ──────────────────────────────────────────────
func reset() -> void:
	current_turn      = PieceScript.PieceColor.WHITE
	en_passant_target = Vector2i(-1, -1)
	is_game_over      = false
