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

@onready var _sprite     : Sprite2D = $Sprite2D
@onready var _area       : Area2D   = $Area2D
@onready var _hint_layer : Node2D   = $HintLayer

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

const HintCircle        = preload("res://Scenes/UI/HintCircle.tscn")
const MoveOverlayScene  = preload("res://Scenes/UI/MoveOverlay.tscn")
const SelectionOverlay  = preload("res://Scenes/UI/SelectionOverlay.tscn")

# overlay sombre sur la case de la pièce sélectionnée
var _selection_overlay  : Node2D = null

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
#  Setup public
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
	var target_pos := Vector2(board_position.x * tile_size,
							  board_position.y * tile_size)
	var tween      := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "position", target_pos, 0.1)

# ──────────────────────────────────────────────
#  Sélection
# ──────────────────────────────────────────────
func select_piece(moves: Array[Vector2i], board: Array) -> void:
	is_selected = true
	_show_selection_overlay()
	_show_move_hints(moves, board)

func deselect() -> void:
	is_selected = false
	_clear_selection_overlay()
	_clear_hints()

# ──────────────────────────────────────────────
#  Overlay sombre sur la case sélectionnée
# ──────────────────────────────────────────────
func _show_selection_overlay() -> void:
	_clear_selection_overlay()
	_selection_overlay          = SelectionOverlay.instantiate()
	_selection_overlay.z_index  = 1
	_selection_overlay.tile_size = tile_size
	add_child(_selection_overlay)

func _clear_selection_overlay() -> void:
	if _selection_overlay != null:
		_selection_overlay.queue_free()
		_selection_overlay = null

# ──────────────────────────────────────────────
#  Cercles et cases colorées
# ──────────────────────────────────────────────
func _show_move_hints(moves: Array[Vector2i], board: Array) -> void:
	_clear_hints()
	for move in moves:
		var hint_color : Color = GameManager.get_hint_color(board, move, self)
		var is_capture : bool  = board[move.y][move.x] != null

		if is_capture:
			# Case occupée → overlay coloré (vert capture, rouge roi)
			var overlay           := MoveOverlayScene.instantiate()
			overlay.position      = Vector2(
				(move.x - board_position.x) * tile_size,
				(move.y - board_position.y) * tile_size
			)
			overlay.z_index       = 1
			overlay.tile_size     = tile_size
			overlay.color         = hint_color
			_hint_layer.add_child(overlay)
		else:
			# Case vide → cercle vert classique
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
	hint.color    = Color(0.0, 0.85, 0.2, 0.7)
	return hint
