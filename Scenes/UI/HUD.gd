extends CanvasLayer

const PieceScript = preload("res://Scenes/Pieces/Piece.gd")

# ──────────────────────────────────────────────
#  Constantes
# ──────────────────────────────────────────────
const TOTAL_TIME     : float = 15.0 * 60.0  # 15 minutes en secondes
const PIECE_VALUES   : Dictionary = {
	PieceScript.PieceType.PAWN:   1,
	PieceScript.PieceType.KNIGHT: 3,
	PieceScript.PieceType.BISHOP: 3,
	PieceScript.PieceType.ROOK:   5,
	PieceScript.PieceType.QUEEN:  9,
	PieceScript.PieceType.KING:   0,
}
const PIECE_SYMBOLS  : Dictionary = {
	PieceScript.PieceType.PAWN:   "♟",
	PieceScript.PieceType.KNIGHT: "♞",
	PieceScript.PieceType.BISHOP: "♝",
	PieceScript.PieceType.ROOK:   "♜",
	PieceScript.PieceType.QUEEN:  "♛",
	PieceScript.PieceType.KING:   "♚",
}

# ──────────────────────────────────────────────
#  État
# ──────────────────────────────────────────────
var time_white       : float = TOTAL_TIME
var time_black       : float = TOTAL_TIME
var active_timer     : int   = PieceScript.PieceColor.WHITE
var timer_running    : bool  = false
var move_number      : int   = 1
var captured_white   : Array = []  # pièces capturées des blancs (par les noirs)
var captured_black   : Array = []  # pièces capturées des noirs (par les blancs)

# ──────────────────────────────────────────────
#  Références UI
# ──────────────────────────────────────────────
var _timer_black_label    : Label
var _timer_white_label    : Label
var _advantage_label      : Label
var _move_list            : VBoxContainer
var _captured_black_label : Label
var _captured_white_label : Label
var _undo_button          : Button
var _draw_button          : Button
var _resign_button        : Button

# Référence à Chessboard pour l'annulation
@onready var _chessboard = get_tree().get_root().find_child("Chessboard", true, false)

func _ready() -> void:
	_build_ui()
	_connect_signals()
	timer_running = true

# ──────────────────────────────────────────────
#  Construction du UI par code
# ──────────────────────────────────────────────
func _build_ui() -> void:
	# Panel principal à gauche
	var panel                          := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.custom_minimum_size         = Vector2(280, 0)
	add_child(panel)

	var vbox                           := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# ── Minuteur noir ──
	var timer_black_container          := _make_section("⏱ Noirs")
	_timer_black_label                 = Label.new()
	_timer_black_label.text            = "15:00"
	_timer_black_label.add_theme_font_size_override("font_size", 28)
	_timer_black_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_black_container.add_child(_timer_black_label)
	vbox.add_child(timer_black_container)

	# ── Pièces capturées par les noirs ──
	var cap_black_container            := _make_section("Capturées par les noirs")
	_captured_black_label              = Label.new()
	_captured_black_label.text         = ""
	_captured_black_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	cap_black_container.add_child(_captured_black_label)
	vbox.add_child(cap_black_container)

	# ── Avantage matériel ──
	var advantage_container            := _make_section("Avantage matériel")
	_advantage_label                   = Label.new()
	_advantage_label.text              = "Égalité"
	_advantage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	advantage_container.add_child(_advantage_label)
	vbox.add_child(advantage_container)

	# ── Historique des coups ──
	var history_container              := _make_section("Historique des coups")
	var scroll                         := ScrollContainer.new()
	scroll.custom_minimum_size         = Vector2(0, 200)
	scroll.vertical_scroll_mode        = ScrollContainer.SCROLL_MODE_AUTO
	_move_list                         = VBoxContainer.new()
	_move_list.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
	scroll.add_child(_move_list)
	history_container.add_child(scroll)
	vbox.add_child(history_container)

	# ── Pièces capturées par les blancs ──
	var cap_white_container            := _make_section("Capturées par les blancs")
	_captured_white_label              = Label.new()
	_captured_white_label.text         = ""
	_captured_white_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	cap_white_container.add_child(_captured_white_label)
	vbox.add_child(cap_white_container)

	# ── Minuteur blanc ──
	var timer_white_container          := _make_section("⏱ Blancs")
	_timer_white_label                 = Label.new()
	_timer_white_label.text            = "15:00"
	_timer_white_label.add_theme_font_size_override("font_size", 28)
	_timer_white_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_white_container.add_child(_timer_white_label)
	vbox.add_child(timer_white_container)

	# ── Boutons ──
	var buttons_container              := HBoxContainer.new()
	buttons_container.add_theme_constant_override("separation", 6)

	_undo_button                       = _make_button("↩ Annuler")
	_draw_button                       = _make_button("🤝 Nulle")
	_resign_button                     = _make_button("🏳 Abandonner")

	buttons_container.add_child(_undo_button)
	buttons_container.add_child(_draw_button)
	buttons_container.add_child(_resign_button)
	vbox.add_child(buttons_container)

func _make_section(title: String) -> VBoxContainer:
	var container  := VBoxContainer.new()
	var label      := Label.new()
	label.text     = title
	label.add_theme_font_size_override("font_size", 11)
	label.modulate = Color(0.7, 0.7, 0.7)
	container.add_child(label)
	var separator  := HSeparator.new()
	container.add_child(separator)
	return container

func _make_button(text: String) -> Button:
	var btn                      := Button.new()
	btn.text                     = text
	btn.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	return btn

# ──────────────────────────────────────────────
#  Connexion des signaux
# ──────────────────────────────────────────────
func _connect_signals() -> void:
	GameManager.turn_changed.connect(_on_turn_changed)
	GameManager.move_made.connect(_on_move_made)
	GameManager.move_undone.connect(_on_move_undone)
	GameManager.checkmate_detected.connect(_on_game_over)
	GameManager.stalemate_detected.connect(_on_game_over_stalemate)
	_undo_button.pressed.connect(_on_undo_pressed)
	_draw_button.pressed.connect(_on_draw_pressed)
	_resign_button.pressed.connect(_on_resign_pressed)

# ──────────────────────────────────────────────
#  Minuterie — _process
# ──────────────────────────────────────────────
func _process(delta: float) -> void:
	if not timer_running or GameManager.is_game_over:
		return

	if active_timer == PieceScript.PieceColor.WHITE:
		time_white = max(0.0, time_white - delta)
		_timer_white_label.text = _format_time(time_white)
		if time_white <= 0.0:
			_on_timeout(PieceScript.PieceColor.WHITE)
	else:
		time_black = max(0.0, time_black - delta)
		_timer_black_label.text = _format_time(time_black)
		if time_black <= 0.0:
			_on_timeout(PieceScript.PieceColor.BLACK)

func _format_time(seconds: float) -> String:
	if seconds <= 10.0:
		# Affiche dixièmes et centièmes sous 10 secondes
		return "%02d:%05.2f" % [0, seconds]
	var mins : int   = int(seconds) / 60
	var secs : int   = int(seconds) % 60
	return "%02d:%02d" % [mins, secs]

func _on_timeout(color: int) -> void:
	timer_running = false
	var winner    := "Noirs" if color == PieceScript.PieceColor.WHITE else "Blancs"
	print("Temps écoulé ! Les %s gagnent." % winner)

# ──────────────────────────────────────────────
#  Changement de tour
# ──────────────────────────────────────────────
func _on_turn_changed(color: int) -> void:
	active_timer = color

# ──────────────────────────────────────────────
#  Nouveau coup
# ──────────────────────────────────────────────
func _on_move_made(record: MoveRecord) -> void:
	_update_move_history(record)
	if record.captured_piece != null:
		_update_captured(record)
	_update_advantage()

func _update_move_history(record: MoveRecord) -> void:
	var color      : int    = record.piece.piece_color
	var is_white   : bool   = color == PieceScript.PieceColor.WHITE
	var symbol     : String = PIECE_SYMBOLS.get(record.piece.piece_type, "?")
	var col_letter : String = "abcdefgh"[record.to.x]
	var row_number : int    = 8 - record.to.y
	var move_text  : String = "%s%s%d" % [symbol, col_letter, row_number]

	if is_white:
		# Nouveau coup blanc — nouvelle ligne
		var line_label        := Label.new()
		line_label.name       = "Move_%d" % move_number
		line_label.text       = "%d. %s" % [move_number, move_text]
		line_label.add_theme_font_size_override("font_size", 13)
		_move_list.add_child(line_label)
	else:
		# Coup noir — on complète la ligne existante
		var last_label        := _move_list.get_child(_move_list.get_child_count() - 1) as Label
		if last_label != null:
			last_label.text   += "   %s" % move_text
		move_number           += 1

	# Auto-scroll vers le bas
	await get_tree().process_frame
	var scroll := _move_list.get_parent() as ScrollContainer
	if scroll:
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

func _update_captured(record: MoveRecord) -> void:
	var captured_type : int  = record.captured_piece.piece_type
	var attacker_color: int  = record.piece.piece_color

	if attacker_color == PieceScript.PieceColor.WHITE:
		captured_black.append(captured_type)
		_captured_black_label.text = _format_captured(captured_black)
	else:
		captured_white.append(captured_type)
		_captured_white_label.text = _format_captured(captured_white)

func _format_captured(types: Array) -> String:
	var result : String = ""
	for t in types:
		result += PIECE_SYMBOLS.get(t, "?")
	return result

func _update_advantage() -> void:
	var score_white : int = 0
	var score_black : int = 0
	for t in captured_black:
		score_white += PIECE_VALUES.get(t, 0)
	for t in captured_white:
		score_black += PIECE_VALUES.get(t, 0)

	var diff : int = score_white - score_black
	if diff > 0:
		_advantage_label.text = "Blancs +%d" % diff
	elif diff < 0:
		_advantage_label.text = "Noirs +%d" % abs(diff)
	else:
		_advantage_label.text = "Égalité"

# ──────────────────────────────────────────────
#  Annulation
# ──────────────────────────────────────────────
func _on_undo_pressed() -> void:
	if _chessboard:
		_chessboard.undo_last_move()

func _on_move_undone() -> void:
	# Retire la dernière entrée de l'historique visuel
	if _move_list.get_child_count() == 0:
		return

	var last_label := _move_list.get_child(_move_list.get_child_count() - 1) as Label
	if last_label == null:
		return

	var parts := last_label.text.split("   ")
	if parts.size() > 1:
		# Le coup noir existait — on le retire
		last_label.text = parts[0]
		move_number    -= 0  # le numéro ne change pas
	else:
		# Coup blanc — on retire toute la ligne
		last_label.queue_free()
		move_number -= 1

	# Retire la dernière capture si applicable
	var history := GameManager.move_history
	# On remet à jour captures et avantage depuis l'historique
	captured_white.clear()
	captured_black.clear()
	for rec in history:
		if rec.captured_piece != null:
			if rec.piece.piece_color == PieceScript.PieceColor.WHITE:
				captured_black.append(rec.captured_piece.piece_type)
			else:
				captured_white.append(rec.captured_piece.piece_type)
	_captured_white_label.text = _format_captured(captured_white)
	_captured_black_label.text = _format_captured(captured_black)
	_update_advantage()

# ──────────────────────────────────────────────
#  Boutons
# ──────────────────────────────────────────────
func _on_draw_pressed() -> void:
	timer_running        = false
	GameManager.is_game_over = true
	print("Match nul proposé et accepté.")

func _on_resign_pressed() -> void:
	timer_running        = false
	GameManager.is_game_over = true
	var loser  := GameManager.current_turn
	var winner := "Noirs" if loser == PieceScript.PieceColor.WHITE else "Blancs"
	print("Abandon ! Les %s gagnent." % winner)

# ──────────────────────────────────────────────
#  Fin de partie
# ──────────────────────────────────────────────
func _on_game_over(_color: int) -> void:
	timer_running = false

func _on_game_over_stalemate() -> void:
	timer_running = false
