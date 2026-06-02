## End-to-end smoke test of the poker logic layer. Spins up a 4-seat
## table (you + 3 AI), seats with starting chips, runs a configurable
## number of hands with [PokerAI] driving every action, and prints the
## full action log + final chip stacks to the on-screen Label.
##
## Use this to verify:
##   • Hand lifecycle: blinds → preflop → flop → turn → river → showdown
##   • Pot accounting: total in == total out (chip conservation)
##   • Side-pot logic: when AIs go all-in for different amounts
##   • Fold-out short-circuit: hand ends when only one player remains
##
## Hit F6 to run. If the chip-conservation check fails the label turns
## red and notes which hand broke it.
extends Node


@onready var _label : Label = $ScrollContainer/Result

const STARTING_STACK : int = 1000
const HANDS_TO_PLAY : int = 5
## Pause between AI actions, in seconds. 0 = run as fast as possible.
## Bump to ~0.1 if you want to scroll through the log mid-game.
const AI_DELAY : float = 0.0

var _board : PokerBoard
var _log_lines : Array[String] = []
var _starting_total : int = 0
var _hands_played : int = 0


func _ready() -> void:

	_board = PokerBoard.new()
	add_child(_board)
	_board.small_blind_amount = 5
	_board.big_blind_amount = 10
	# Seat order: dealer button rotates clockwise from index 0.
	_board.add_player(PokerPlayer.new("You", STARTING_STACK, true))
	_board.add_player(PokerPlayer.new("Flint Kerr", STARTING_STACK, false))
	_board.add_player(PokerPlayer.new("Cogwise Godfrey", STARTING_STACK, false))
	_board.add_player(PokerPlayer.new("Mossy Jade", STARTING_STACK, false))
	_starting_total = _total_chips()
	# Hook signals.
	_board.phase_changed.connect(_on_phase_changed)
	_board.hole_cards_dealt.connect(_on_hole_cards_dealt)
	_board.community_dealt.connect(_on_community_dealt)
	_board.player_acted.connect(_on_player_acted)
	_board.turn_changed.connect(_on_turn_changed)
	_board.hand_complete.connect(_on_hand_complete)
	# Start the first hand.
	_log("=== Starting %d-hand simulation ===" % HANDS_TO_PLAY)
	_board.start_new_hand()


# --- Signal handlers ---------------------------------------------------

func _on_phase_changed(new_phase: PokerBoard.Phase) -> void:

	_log("--- Phase: %s ---" % PokerBoard.PHASE_NAMES[new_phase])


func _on_hole_cards_dealt() -> void:

	for p in _board.players:
		if p.chips > 0 or p.hole_cards.size() > 0:
			var names : Array[String] = []
			for c in p.hole_cards:
				names.append(c.short_name())
			_log("  %s dealt %s (stack: %d)" % [p.player_name, "  ".join(names), p.chips])


func _on_community_dealt(all_community: Array[Card]) -> void:

	var names : Array[String] = []
	for c in all_community:
		names.append(c.short_name())
	_log("  Board: %s" % "  ".join(names))


func _on_player_acted(player_index: int, action: PokerBoard.Action, amount: int) -> void:

	var p : PokerPlayer = _board.players[player_index]
	var line : String = "  %s %s" % [p.player_name, PokerBoard.ACTION_NAMES[action]]
	if amount > 0:
		line += " %d" % amount
	if p.all_in:
		line += " (ALL-IN)"
	line += "    [stack: %d, this round: %d, pot: %d]" % [p.chips, p.current_bet, _board.get_total_pot()]
	_log(line)


func _on_turn_changed(_player_index: int) -> void:

	# AI plays automatically. Human seat (index 0) — in the real game
	# the UI would wait for input here; this test just lets the AI play
	# for the "human" seat too so the hand can resolve.
	if AI_DELAY > 0.0:
		await get_tree().create_timer(AI_DELAY).timeout
	if _board.phase == PokerBoard.Phase.BETWEEN_HANDS:
		return
	var p : PokerPlayer = _board.get_current_player()
	if p == null:
		return
	var decision : Dictionary = PokerAI.decide(_board, p)
	_board.apply_action(decision["action"], decision["amount"])


func _on_hand_complete(awards: Array) -> void:

	_log("--- Hand complete ---")
	for a in awards:
		var names : Array[String] = []
		for w in a["winners"]:
			names.append(w.player_name)
		var line : String = "  Pot %d: %d chips → %s (%d each)" % [
			a["pot_index"], a["per_winner"] * a["winners"].size() + a["remainder"],
			"  ".join(names), a["per_winner"],
		]
		_log(line)
	# Conservation check.
	var total_now : int = _total_chips()
	if total_now != _starting_total:
		_log("!! CHIP CONSERVATION FAILED: started %d, now %d (diff %d)" % [
			_starting_total, total_now, total_now - _starting_total,
		])
		_finish(false)
		return
	_log("  (chip total still %d ✓)" % total_now)
	_log("  stacks: " + _stack_string())
	_hands_played += 1
	if _hands_played >= HANDS_TO_PLAY:
		_finish(true)
		return
	# Need at least 2 players with chips to continue.
	var alive : int = 0
	for p in _board.players:
		if p.chips > 0:
			alive += 1
	if alive < 2:
		_log("Only %d player with chips — stopping early." % alive)
		_finish(true)
		return
	_log("")
	_log("=== Hand %d ===" % (_hands_played + 1))
	_board.start_new_hand()


# --- Helpers -----------------------------------------------------------

func _total_chips() -> int:

	# Called from _on_hand_complete, AFTER pot.award() has paid the pot
	# back into the winners' stacks. So conservation is simply sum of
	# stacks — adding total_bet_in_hand here would double-count the pot.
	var n : int = 0
	for p in _board.players:
		n += p.chips
	return n


func _stack_string() -> String:

	var parts : Array[String] = []
	for p in _board.players:
		parts.append("%s=%d" % [p.player_name, p.chips])
	return ", ".join(parts)


func _log(line: String) -> void:

	_log_lines.append(line)
	print(line)


func _finish(passed: bool) -> void:

	_label.text = "\n".join(_log_lines)
	_label.modulate = Color(0.55, 0.95, 0.55) if passed else Color(1.0, 0.55, 0.55)
