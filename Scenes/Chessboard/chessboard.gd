extends Node2D

const PieceScene       = preload("res://Scenes/Pieces/Piece.tscn")
const PieceScript      = preload("res://Scenes/Pieces/Piece.gd")
const MoveOverlayScene = preload("res://Scenes/UI/MoveOverlay.tscn")

@export var board_size : int = 8
@export var tile_size  : int = 238

@onready var light_texture = preload("res://Assets/Sprites/Board/LightCase.png")
@onready var dark_texture  = preload("res://Assets/Sprites/Board/DarkCase.png")
@onready var _camera       : Camera2D = $Camera2D

var board               : Array[Array]    = []
var selected_piece      : Node2D          = null
var valid_moves         : Array[Vector2i] = []
var _last_move_overlays : Array[Node2D]   = []
var _check_overlay      : Node2D          = null

func _ready() -> void:
	_init_board()
	generate_board()
	setup_camera()
	spawn_all_pieces()
	GameManager.check_detected.connect(_on_check_detected)
	GameManager.checkmate_detected.connect(_on_checkmate_detected)
	GameManager.stalemate_detected.connect(_on_stalemate_detected)
	GameManager.move_undone.connect(_on_move_undone)

func _init_board() -> void:
	board = []
	for y in range(board_size):
		board.append(Array())
		board[y].resize(board_size)
		board[y].fill(null)

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

func spawn_all_pieces() -> void:
	var T := PieceScript.PieceType
	var C := PieceScript.PieceColor
	var back_row : Array[PieceScript.PieceType] = [
		T.ROOK, T.KNIGHT, T.BISHOP, T.QUEEN, T.KING, T.BISHOP, T.KNIGHT, T.ROOK
	]
	for x in range(8):
		spawn_piece(back_row[x], C.BLACK, Vector2i(x, 0))
		spawn_piece(T.PAWN,      C.BLACK, Vector2i(x, 1))
	for x in range(8):
		spawn_piece(back_row[x], C.WHITE, Vector2i(x, 7))
		spawn_piece(T.PAWN,      C.WHITE, Vector2i(x, 6))

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
	if not GameManager.is_turn(piece.piece_color):
		return
	if selected_piece == piece:
		selected_piece.deselect()
		selected_piece = null
		valid_moves.clear()
		return
	if selected_piece != null:
		selected_piece.deselect()
	selected_piece = piece
	valid_moves    = GameManager.get_valid_moves(board, piece)
	piece.select_piece(valid_moves, board)

# ──────────────────────────────────────────────
#  Clic sur une case vide
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
	var from    : Vector2i = selected_piece.board_position
	var is_king : bool     = selected_piece.piece_type == PieceScript.PieceType.KING

	# Variables pour MoveRecord
	var ep_captured    : Node2D   = null
	var ep_captured_pos: Vector2i = Vector2i(-1, -1)
	var is_ep          : bool     = false
	var is_castling    : bool     = false
	var rook           : Node2D   = null
	var rook_from      : Vector2i = Vector2i(-1, -1)
	var rook_to        : Vector2i = Vector2i(-1, -1)

	# 1. En passant
	var prev_ep := GameManager.en_passant_target
	ep_captured = GameManager.apply_en_passant(board, selected_piece, target)
	if ep_captured != null:
		is_ep           = true
		ep_captured_pos = Vector2i(target.x, selected_piece.board_position.y)

	# 2. Roque
	if is_king and abs(target.x - from.x) == 2:
		is_castling = true
		var castling_result : Array = GameManager.apply_castling(board, selected_piece, target)
		rook      = castling_result[0]
		rook_from = castling_result[1]
		rook_to   = castling_result[2]

	# 3. Capture normale
	var occupant : Node2D = board[target.y][target.x]
	if occupant != null:
		board[target.y][target.x] = null
		occupant.hide()  # hide au lieu de queue_free pour pouvoir annuler

	# 4. Déplacement logique
	board[from.y][from.x]     = null
	board[target.y][target.x] = selected_piece

	# 5. Enregistrement du coup AVANT move_to (board_position change après)
	var captured_for_record : Node2D   = ep_captured if is_ep else occupant
	var captured_pos_record : Vector2i = ep_captured_pos if is_ep else target
	GameManager.record_move(
		selected_piece, from, target,
		captured_for_record, captured_pos_record,
		is_castling, rook, rook_from, rook_to,
		is_ep, false
	)

	selected_piece.deselect()
	selected_piece.move_to(target)
	_highlight_last_move(from, target)

	# 6. Mise à jour en passant
	GameManager.update_en_passant(selected_piece, from, target)

	# 7. Promotion
	GameManager.check_promotion(board, selected_piece)

	# 8. Échec / mat / pat
	var opponent : int = PieceScript.PieceColor.BLACK \
		if selected_piece.piece_color == PieceScript.PieceColor.WHITE \
		else PieceScript.PieceColor.WHITE
	_clear_check_overlay()
	GameManager.check_game_state(board, opponent)
	GameManager.next_turn()

	selected_piece = null
	valid_moves.clear()

# ──────────────────────────────────────────────
#  Annulation du dernier coup
# ──────────────────────────────────────────────
func undo_last_move() -> void:
	if GameManager.move_history.is_empty():
		return
	# Réaffiche la pièce capturée si elle existe avant l'annulation
	var last : MoveRecord = GameManager.move_history.back()
	if last.captured_piece != null:
		last.captured_piece.show()
	GameManager.undo_move(board)
	_clear_check_overlay()
	_clear_last_move_overlay()

func _on_move_undone() -> void:
	# Rafraîchit l'état visuel après annulation
	_clear_check_overlay()
	_clear_last_move_overlay()
	# Vérifie si le roi est en échec dans la position restaurée
	var color : int = GameManager.current_turn
	if GameManager.is_in_check(board, color):
		_on_check_detected(color)

# ──────────────────────────────────────────────
#  Mise en évidence du dernier coup
# ──────────────────────────────────────────────
func _highlight_last_move(from: Vector2i, to: Vector2i) -> void:
	_clear_last_move_overlay()
	for cell in [from, to]:
		var overlay       := MoveOverlayScene.instantiate()
		overlay.position  = Vector2(cell.x * tile_size, cell.y * tile_size)
		overlay.z_index   = 1
		overlay.tile_size = tile_size
		add_child(overlay)
		_last_move_overlays.append(overlay)

func _clear_last_move_overlay() -> void:
	for overlay in _last_move_overlays:
		overlay.queue_free()
	_last_move_overlays.clear()

# ──────────────────────────────────────────────
#  Overlay rouge — échec
# ──────────────────────────────────────────────
func _on_check_detected(color: int) -> void:
	_clear_check_overlay()
	for y in range(board_size):
		for x in range(board_size):
			var cell = board[y][x]
			if cell != null \
			and cell.piece_type  == PieceScript.PieceType.KING \
			and cell.piece_color == color:
				var overlay       := MoveOverlayScene.instantiate()
				overlay.position  = Vector2(x * tile_size, y * tile_size)
				overlay.z_index   = 1
				overlay.tile_size = tile_size
				overlay.color     = Color(0.9, 0.1, 0.1, 0.5)
				add_child(overlay)
				_check_overlay = overlay
				return

func _clear_check_overlay() -> void:
	if _check_overlay != null:
		_check_overlay.queue_free()
		_check_overlay = null

func _on_checkmate_detected(color: int) -> void:
	_on_check_detected(color)
	print("Échec et mat ! Les %s ont perdu." % \
		["Blancs" if color == PieceScript.PieceColor.WHITE else "Noirs"])

func _on_stalemate_detected() -> void:
	print("Pat ! Partie nulle.")

func _is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < board_size and pos.y >= 0 and pos.y < board_size
