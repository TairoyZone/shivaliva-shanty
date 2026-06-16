## Gem Drop — the playable parlor-game scene launched by the
## [GemDropTable] prop at the Inn. Inherits HUD-hiding, ESC return,
## click-to-dismiss, and the winnings helper from [PuzzleScene]; this
## script only owns puzzle-specific UI label bindings + signal wiring. Extends [VersusPuzzleScene] so the
## NPC opponent inherits situational awareness + the talk-influence seam (open board → no _own_secret_view).
class_name GemDropScene
extends VersusPuzzleScene


## Active player's score label glows in their identity color; the
## inactive player is dimmed but still tinted so identity reads at a
## glance. Turn indicator labels (under each panel) carry their colors
## in the .tscn — only visibility is toggled here.
const HUMAN_COLOR : Color = Palette.GOLD_TEXT
const AI_COLOR : Color = Palette.GEM_RUBY_LIGHT
const INACTIVE_DIM : float = 0.45  # multiplier on the identity color
const WINNINGS_ON_VICTORY := 10
## Gold taken on the way OUT if the human didn't win this session. Covers both completed losses and
## mid-match Leaves — winners exit free. This is the STAKE: [GemDropTable] reads it for the lobby's
## affordability gate + note, so the gate, the label, and the billing never disagree.
const PLAY_COST_ON_EXIT : int = 5
## Rapport gained with the opponent for finishing a match, plus a bonus
## for beating them.
const PLAY_AFFINITY : int = 1
const WIN_AFFINITY_BONUS : int = 2

@onready var _board: GemDropBoard = $Board
@onready var _round_label: Label = $UI/TopBar/CenterBanner/CenterColumn/RoundLabel
@onready var _rounds_label: Label = $UI/TopBar/CenterBanner/CenterColumn/RoundsLabel
@onready var _you_label: Label = $UI/TopBar/YouColumn/YouPanel/YouLabel
@onready var _ai_label: Label = $UI/TopBar/AiColumn/AiPanel/AiLabel
@onready var _you_turn_label: Label = $UI/TopBar/YouColumn/YouTurnIndicator
@onready var _ai_turn_label: Label = $UI/TopBar/AiColumn/AiTurnIndicator

## NPC opponent for this match — picked randomly from [NpcRegistry] in
## [method _ready]. Their personality drives the board's minimax weights
## + search depth, and their name + color appear on the AI panel.
var _opponent : NpcPersonality

## Flips true the moment [method _on_game_complete] sees a human win.
## [method _return_to_launching_scene] checks this to skip the
## play-cost charge on a victorious exit.
var _human_won_match : bool = false

## Match-over state for the chatting opponent's GROUND TRUTH (Troy 2026-06-14: Kerr denied a loss because the
## prompt still framed the match as live). Set in [method _on_game_complete]; read by [method _public_frame].
var _match_over : bool = false
var _match_winner : int = -1          # the winning seat (GemDropBoard.HUMAN_PLAYER or the AI seat); -1 = unsettled
var _final_human_rounds : int = 0
var _final_ai_rounds : int = 0

## Set from the lobby on entry — a FREE table plays for rapport only, no gold won or lost. Parlor play is
## cash-only now (the "free table" option was retired 2026-06-16); only the TOURNAMENT still flags this
## (via PlayerState.free_table). Read in [method _on_game_complete] + [method _return_to_launching_scene]
## to suppress every gold change.
var _free_table : bool = false


## Pinch to zoom the table on a phone — it reads small there. The board's drop input is camera-aware
## (get_global_mouse_position), so taps still land on the right column when zoomed. See [[touch-input-foundation]].
func _touch_pinch_zoom() -> bool:
	return true


func _ready() -> void:

	super._ready()
	var controls : String
	if TouchEnv.is_touch():
		controls = ("• Tap an entry slot at the top to drop a gem (your turn only)\n"
			+ "• Pinch to zoom the table in, drag with one finger to pan around\n")
	else:
		controls = "• Click an entry slot at the top to drop a gem (your turn only)\n"
	set_help_text("How to play\n\n"
		+ controls
		+ "• A gem RESTS on an empty pad, BOUNCES off an occupied pad, and FLIPS a switch when it crosses the lever side\n"
		+ "• Odd flips drop the resting gem off the pad — bumped gems can merge with falling ones into multi-coins (xN score)\n"
		+ "• First to the round target wins the round\n"
		+ "• Best of 4 rounds wins the game (cumulative score tiebreaker)")
	# Opponent + stakes come from the lobby the player just sat at; fall
	# back to a fresh roll if launched without one. Their personality is
	# handed to the board so the minimax eval reads from it.
	var setup : Dictionary = PlayerState.consume_lobby_setup()
	# Cash-only parlor play (only the tournament sets "free" now). A broke player can still play — a loss
	# only ever takes the gold you HAVE (capped in _return_to_launching_scene), and a win still pays out.
	_free_table = bool(setup.get("free", false))
	var seated : Array[NpcPersonality] = NpcRegistry.profiles_from_paths(setup.get("seated_paths", []))
	_opponent = seated[0] if not seated.is_empty() else NpcRegistry.pick_one()
	if _opponent != null:
		_board.ai_personality = _opponent
		# Personalize the turn indicator — "GODFREY THINKING…" rather
		# than the generic "AI THINKING…".
		_ai_turn_label.text = "▲  %s THINKING…" % _opponent_short_name().to_upper()
		# Make the opponent CHAT-REACHABLE + situationally aware — the poker hook, now on the gem table (Troy
		# 2026-06-10). In the "npc" group so the chat scope menu + RoomChat find them; the SCENE feeds the live
		# board via npc_chat_context below. Replies float near their score panel; the chat log carries the talk.
		var chat : OpponentChat = OpponentChat.new()
		add_child(chat)
		chat.setup(_opponent)
		chat.position = Vector2(1100.0, 120.0)   # near the opponent's top-right score panel
	_board.scores_changed.connect(_on_scores_changed)
	_board.round_advanced.connect(_on_round_advanced)
	_board.round_clearing.connect(_on_round_clearing)
	_board.rounds_won_changed.connect(_on_rounds_won_changed)
	_board.turn_changed.connect(_on_turn_changed)
	_board.game_complete.connect(_on_game_complete)
	_on_round_advanced(_board.round_number, _board.round_target)
	_on_scores_changed(_board.player_scores[0], _board.player_scores[1], _board.round_target)
	_on_rounds_won_changed(_board.rounds_won[0], _board.rounds_won[1])
	_on_turn_changed(_board.current_player)


func _on_scores_changed(human_score: int, ai_score: int, target: int) -> void:

	_you_label.text = "YOU  %d / %d" % [human_score, target]
	_ai_label.text = "%s  %d / %d" % [_opponent_short_name(), ai_score, target]


# Just the given name (no adjective prefix) so the score panel fits.
# Full "Cogwise Godfrey" goes in the game-complete and round-clear
# banners where there's room to read.
func _opponent_short_name() -> String:

	if _opponent == null:
		return "Rival"
	var parts : PackedStringArray = _opponent.npc_name.split(" ")
	return parts[parts.size() - 1] if parts.size() > 0 else "Rival"


# Full adjective + given name for headline banners.
func _opponent_full_name() -> String:

	return _opponent.npc_name if _opponent != null else "Rival"


# Live GEM DROP state for a chatting opponent — situational awareness via the [VersusPuzzleScene] hooks (Troy
# 2026-06-10). OPEN board, so nothing's hidden: _own_secret_view stays the base's "" (no secret to show).
# `you` = the AI seat asking; the human is the traveller. See [[npc-situational-awareness]].
func _versus_ready() -> bool:
	return _board != null


func _rules_brief() -> String:

	return ("THE RULES OF GEM DROP (so your banter is accurate): a turn-based duel on a shared OPEN board, you take "
		+ "turns dropping a gem into a top slot. A gem rests on an empty pad, bounces off an occupied one, and flips "
		+ "a switch when it crosses the lever side; odd flips knock a resting gem loose, and bumped gems can merge "
		+ "with falling ones into multi-coins worth extra points. First to the round's target score wins THE ROUND. "
		+ "The MATCH is BEST OF 4 ROUNDS (first to 3 round-wins; 2-2 forces a sudden-death Holes tiebreaker). So a "
		+ "lead of a round or two is NOT the whole match, and once someone has clinched 3 the match is genuinely over.")


func _public_frame() -> String:

	var human : int = GemDropBoard.HUMAN_PLAYER
	var you : int = 1 - human   # the opponent asking = the AI seat
	var lines : PackedStringArray = PackedStringArray()
	# GAME OVER: state it first + plainly, so the opponent never denies the result or acts like it's still going.
	if _match_over:
		if _match_winner == human:
			lines.append("THE MATCH IS OVER. The traveller WON it, %d rounds to %d — you LOST. This is final: don't claim it's still going or deny their win. Be sore, gracious, or whatever fits you, but the result stands." % [_final_human_rounds, _final_ai_rounds])
		else:
			lines.append("THE MATCH IS OVER. YOU WON it, %d rounds to %d — the traveller lost. This is final: own the win however fits you, don't pretend there's more to play." % [_final_ai_rounds, _final_human_rounds])
		return "\n".join(lines)
	lines.append("GEM DROP — you're mid-match against the traveller right now, a turn-based duel on an OPEN board (you both see everything). React like a player at the game.")
	lines.append("Round %d, best of 4 — first to %d points takes the round." % [_board.round_number, _board.round_target])
	lines.append("This round: you %d, the traveller %d." % [_board.player_scores[you], _board.player_scores[human]])
	lines.append("Rounds won so far: you %d, the traveller %d (first to 3 wins the match)." % [_board.rounds_won[you], _board.rounds_won[human]])
	lines.append("It's YOUR turn to drop a gem." if _board.current_player == you else "It's the traveller's turn — you're waiting on them.")
	return "\n".join(lines)


func _lead_phrase(_asker: String) -> String:

	if _match_over:
		return ""   # the match-over frame already says who won; no live lead to call
	var human : int = GemDropBoard.HUMAN_PLAYER
	var you : int = 1 - human
	var yt : int = _board.total_scores[you]
	var tt : int = _board.total_scores[human]
	if yt > tt:
		return "You're ahead on total points (%d to %d)." % [yt, tt]
	elif tt > yt:
		return "You're behind on total points (%d to %d) — they've got the edge." % [yt, tt]
	return "You're level on total points (%d each)." % yt


func _on_round_advanced(new_round: int, new_target: int) -> void:

	if new_round == GemDropBoard.TIEBREAKER_ROUND:
		_round_label.text = "TIEBREAKER · HOLES   ·   Target %d" % new_target
	else:
		_round_label.text = "Round %d   ·   Target %d" % [new_round, new_target]


func _on_round_clearing(winner: int) -> void:

	Audio.play_sfx("bop")
	# Hide both turn indicators while the inter-round pause plays out;
	# the active-state will be re-asserted by _on_turn_changed when the
	# next round starts.
	_you_turn_label.visible = false
	_ai_turn_label.visible = false
	# Special-case the round 4 → 5 transition (always at 2-2): the next
	# round is the sudden-death Holes tiebreaker, not a normal round.
	var going_to_tiebreaker : bool = (
		_board.round_number == GemDropBoard.FINAL_ROUND
		and _board.rounds_won[0] == _board.rounds_won[1])
	if going_to_tiebreaker:
		_rounds_label.text = "TIED 2-2 — Sudden-death Holes round incoming!"
		return
	if winner == GemDropBoard.HUMAN_PLAYER:
		_rounds_label.text = "ROUND CLEAR — next round in a moment…"
	else:
		_rounds_label.text = "%s cleared the round — next round in a moment…" % _opponent_full_name()


func _on_rounds_won_changed(human_rounds: int, ai_rounds: int) -> void:

	# Tiebreaker round reframes the format — drop the "Best of 4" once
	# we're in the sudden-death overtime. The opponent's given name
	# stands in for the old generic "AI".
	var rival : String = _opponent_short_name()
	if _board.round_number == GemDropBoard.TIEBREAKER_ROUND:
		_rounds_label.text = "SUDDEN DEATH   ·   YOU %d   ★   %s %d" % [human_rounds, rival, ai_rounds]
	else:
		_rounds_label.text = "Best of 4   ·   YOU %d   ★   %s %d" % [human_rounds, rival, ai_rounds]


func _on_turn_changed(player: int) -> void:

	var human_active : bool = (player == GemDropBoard.HUMAN_PLAYER)
	_you_turn_label.visible = human_active
	_ai_turn_label.visible = not human_active
	_you_label.modulate = HUMAN_COLOR if human_active else HUMAN_COLOR * INACTIVE_DIM
	_ai_label.modulate = AI_COLOR if not human_active else AI_COLOR * INACTIVE_DIM
	if not human_active and _opponent != null:
		# The AI's turn — fold the talk-influence mood into the board's next search. Set on the MAIN thread here;
		# _begin_ai_search reads it before the worker thread starts (safe). Tick ages it one step per AI move.
		_board.mood_bias = mood_bias(_opponent.npc_name)
		tick_opponent_mood(_opponent.npc_name)


func _on_game_complete(winner: int, human_rounds: int, ai_rounds: int) -> void:

	# Settle the GROUND TRUTH so a chatting opponent KNOWS the match ended + who won (never denies it).
	_match_over = true
	_match_winner = winner
	_final_human_rounds = human_rounds
	_final_ai_rounds = ai_rounds
	_you_turn_label.visible = false
	_ai_turn_label.visible = false
	# Rapport — playing a full match builds a little rapport with the opponent; winning earns a bit more.
	var gain : int = PLAY_AFFINITY + (WIN_AFFINITY_BONUS if winner == GemDropBoard.HUMAN_PLAYER else 0)
	var tail : String = "tap anywhere to return" if TouchEnv.is_touch() else "click anywhere or ESC to return"
	if winner == GemDropBoard.HUMAN_PLAYER:
		_rounds_label.text = "YOU WIN!   %d rounds to %d   ·   %s" % [human_rounds, ai_rounds, tail]
		if not _free_table:
			award_winnings(WINNINGS_ON_VICTORY, "Gem Drop winnings")
		_human_won_match = true
	else:
		_rounds_label.text = "%s WINS!   %d rounds to %d   ·   %s" % [_opponent_full_name(), ai_rounds, human_rounds, tail]
	if _opponent != null:
		PlayerState.add_affinity(_opponent.npc_name, gain)
	# Final-line context reflects whether a tiebreaker was needed.
	if _board.round_number >= GemDropBoard.TIEBREAKER_ROUND:
		_round_label.text = "Match settled in sudden death"
	else:
		_round_label.text = "All four rounds complete"
	# Mastery — your high-water-mark is your TOTAL points scored this match (win or lose), so
	# the Profile/Standings tier rises with skill. (Was missing — Gem Drop never ranked up.)
	var mastery : Dictionary = PlayerState.record_puzzle_result(
		"gem_drop", int(_board.total_scores[GemDropBoard.HUMAN_PLAYER]))
	if mastery["ranked_up"]:
		add_child(MasteryToast.create(String(mastery["tier_name"])))
	_set_awaiting_dismiss(true)


# Charge the play_cost on the way out — but only if the player didn't
# win. Winners walk away with their full +10 winnings; losers and
# mid-match leavers pay the entry fee here. Either way, the deduction
# fires while the HUD is still hidden, so it gets folded into the
# pending-change flush and the player sees a clean toast on the
# overworld instead of a flashed-by deduction at entry.
func _return_to_launching_scene() -> void:

	# Record the result for any caller that launched this as a graded match
	# (a tournament bracket reads it to advance).
	PlayerState.last_gem_drop_won = _human_won_match
	if not _human_won_match and not _free_table and PLAY_COST_ON_EXIT > 0:
		# Only ever lose what you actually HAVE — a broke player loses nothing and sees no phantom "-5" toast
		# (the clamp used to take 0 but still logged the intended -5). Earn loop stays open at zero gold.
		var loss : int = mini(PLAY_COST_ON_EXIT, PlayerState.total_coins)
		if loss > 0:
			PlayerState.add_coins(-loss, "Gem Drop stake")
	super._return_to_launching_scene()
