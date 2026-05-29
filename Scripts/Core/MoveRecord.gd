extends RefCounted
class_name MoveRecord

# ──────────────────────────────────────────────
#  Données d'un coup pour l'annulation
# ──────────────────────────────────────────────
var piece               : Node2D    # la pièce déplacée
var from                : Vector2i  # position de départ
var to                  : Vector2i  # position d'arrivée
var captured_piece      : Node2D    # pièce capturée (null si aucune)
var captured_pos        : Vector2i  # position de la pièce capturée
var was_first_move      : bool      # état de has_moved avant ce coup
var is_castling         : bool      # était-ce un roque ?
var castling_rook       : Node2D    # la tour du roque (null sinon)
var rook_from           : Vector2i  # position initiale de la tour
var rook_to             : Vector2i  # position après roque
var rook_was_first_move : bool      # état has_moved de la tour avant roque
var is_en_passant       : bool      # était-ce un en passant ?
var is_promotion        : bool      # était-ce une promotion ?
var promotion_type_before : int     # type avant promotion (toujours PAWN)
var prev_en_passant_target : Vector2i  # état de en_passant_target avant ce coup

func _init(
	p_piece          : Node2D,
	p_from           : Vector2i,
	p_to             : Vector2i,
	p_captured       : Node2D,
	p_captured_pos   : Vector2i,
	p_first_move     : bool,
	p_castling       : bool,
	p_rook           : Node2D,
	p_rook_from      : Vector2i,
	p_rook_to        : Vector2i,
	p_rook_first     : bool,
	p_en_passant     : bool,
	p_promotion      : bool,
	p_promo_before   : int,
	p_prev_ep        : Vector2i
) -> void:
	piece                    = p_piece
	from                     = p_from
	to                       = p_to
	captured_piece           = p_captured
	captured_pos             = p_captured_pos
	was_first_move           = p_first_move
	is_castling              = p_castling
	castling_rook            = p_rook
	rook_from                = p_rook_from
	rook_to                  = p_rook_to
	rook_was_first_move      = p_rook_first
	is_en_passant            = p_en_passant
	is_promotion             = p_promotion
	promotion_type_before    = p_promo_before
	prev_en_passant_target   = p_prev_ep
