## Texas Hold'em board state machine. Drives a single hand from
## blinds-posting through showdown. Pure logic — no UI, no audio, no
## animations. The scene layer listens to the signals it emits and
## drives both AI decisions and human input by calling [method
## apply_action] back into the board.
##
## Round flow:
##   BETWEEN_HANDS → start_new_hand() → PREFLOP
##     → all betting complete → FLOP (3 community cards)
##     → all betting complete → TURN (1 more community card)
##     → all betting complete → RIVER (1 more community card)
##     → all betting complete → SHOWDOWN (evaluate + award)
##     → BETWEEN_HANDS
##
## Early-exit cases handled automatically:
##   • Everyone folds except one → hand ends, lone player takes pots.
##   • Everyone left is all-in → remaining community cards dealt
##     immediately, jump to showdown.
##
## Heads-up (2-player) quirk: dealer is the small blind and acts first
## preflop, but acts last post-flop. Code handles this branch where
## relevant.
class_name PokerBoard
extends Node


enum Phase {
	BETWEEN_HANDS,
	PREFLOP,
	FLOP,
	TURN,
	RIVER,
	SHOWDOWN,
}

enum Action {
	FOLD,
	CHECK,
	CALL,
	BET,
	RAISE,
	ALL_IN,
}

const PHASE_NAMES : Array[String] = [
	"Between hands", "Preflop", "Flop", "Turn", "River", "Showdown",
]
const ACTION_NAMES : Array[String] = [
	"Fold", "Check", "Call", "Bet", "Raise", "All-in",
]

# --- Signals (UI hooks) -----------------------------------------------
signal phase_changed(new_phase: Phase)
signal hole_cards_dealt()
signal community_dealt(all_community: Array[Card])
signal player_acted(player_index: int, action: Action, amount: int)
## Fires when the SB / BB are auto-staked at the start of a hand. The
## scene listens so it can animate chips flying from the blind seats
## into the pot — blinds aren't routed through [signal player_acted]
## (they aren't voluntary), so this gives the UI a separate hook.
signal blinds_posted(sb_index: int, sb_amount: int, bb_index: int, bb_amount: int)
signal pot_changed(total: int)
signal turn_changed(player_index: int)
signal hand_complete(awards: Array)

# --- Tunables ----------------------------------------------------------
@export var small_blind_amount : int = 5
@export var big_blind_amount : int = 10

# --- State -------------------------------------------------------------
var players : Array[PokerPlayer] = []
var deck : Deck = Deck.new()
var pot_calculator : PokerPot = PokerPot.new()
var community_cards : Array[Card] = []
var dealer_button : int = -1     # incremented at the start of each hand
var current_player_index : int = -1
var phase : Phase = Phase.BETWEEN_HANDS
## Highest amount a player has put in this betting round. Everyone
## must match this to stay in (or fold / go all-in).
var current_bet : int = 0
## Minimum legal raise increment over [member current_bet]. Updated to
## the size of the last full raise.
var min_raise : int = 0

# --- Player profile tracking (for AI "perception") ----------------------
# Per-session stats for the human (player index 0). AI opponents read
# these via [method get_player_stats] and shift their decisions toward
# exploiting observed patterns, scaled by their
# [member NpcPersonality.perception]. Resets implicitly each scene load
# (the board is freshly instantiated when entering the poker scene).
var _human_hands_dealt : int = 0
var _human_vpip_entries : int = 0
var _human_aggressive_actions : int = 0  # bets + raises postflop
var _human_passive_actions : int = 0     # checks + calls postflop
var _human_entered_this_hand : bool = false


# --- Setup -------------------------------------------------------------

func add_player(player: PokerPlayer) -> void:

	players.append(player)


# --- Hand lifecycle ----------------------------------------------------

func start_new_hand() -> void:

	if _seats_with_chips() < 2:
		push_warning("Need at least 2 players with chips to start a hand")
		return
	# Profile tracking: count the human as dealt-in if they have chips
	# this hand. Their per-hand "entered voluntarily" flag resets.
	if not players.is_empty() and players[0].chips > 0:
		_human_hands_dealt += 1
		_human_entered_this_hand = false
	for p in players:
		p.reset_for_new_hand()
		# Busted players (no chips) sit the hand out entirely: not dealt,
		# never counted as "active", never eligible for the pot. Folding them
		# here is the single source of truth the rest of the engine reads —
		# without it a broke seat keeps the hand alive after everyone folds to
		# the blind, so you'd be asked to act on a pot you'd already won.
		if p.chips <= 0:
			p.folded = true
	community_cards.clear()
	deck.reset()
	deck.shuffle()
	# Rotate dealer button to next seated-with-chips player.
	dealer_button = _next_player_with_chips(dealer_button if dealer_button >= 0 else players.size() - 1)
	# Deal 2 hole cards, one at a time around the table starting left of dealer.
	for _round in 2:
		var idx : int = _next_player_with_chips(dealer_button)
		var dealt : int = 0
		while dealt < _seats_with_chips():
			players[idx].hole_cards.append(deck.deal_one())
			dealt += 1
			idx = _next_player_with_chips(idx)
	hole_cards_dealt.emit()
	# Post blinds. Heads-up: dealer is SB.
	var sb_index : int
	var bb_index : int
	if _seats_with_chips() == 2:
		sb_index = dealer_button
		bb_index = _next_player_with_chips(dealer_button)
	else:
		sb_index = _next_player_with_chips(dealer_button)
		bb_index = _next_player_with_chips(sb_index)
	players[sb_index].stake(small_blind_amount)
	players[bb_index].stake(big_blind_amount)
	blinds_posted.emit(sb_index, small_blind_amount, bb_index, big_blind_amount)
	# Blinds don't count as "voluntary action" — they still need to act preflop.
	players[sb_index].has_acted_this_round = false
	players[bb_index].has_acted_this_round = false
	current_bet = big_blind_amount
	min_raise = big_blind_amount
	# Preflop first to act: heads-up → SB (dealer). Otherwise → UTG (left of BB).
	if _seats_with_chips() == 2:
		current_player_index = sb_index
	else:
		current_player_index = _next_player_with_chips(bb_index)
	phase = Phase.PREFLOP
	phase_changed.emit(phase)
	pot_changed.emit(pot_calculator.total_pot(players))
	turn_changed.emit(current_player_index)


# --- Action input ------------------------------------------------------

func apply_action(action: Action, amount: int = 0) -> bool:

	var player : PokerPlayer = get_current_player()
	if player == null or not player.can_act():
		return false
	var actual : int = 0
	# Snapshot the table bet BEFORE this action mutates it, so we can tell
	# afterwards whether the action actually RAISED (used to classify an
	# all-in as aggressive vs a passive call-for-less — current_bet has
	# already moved by the time we record the profile stat).
	var bet_before : int = current_bet
	match action:
		Action.FOLD:
			player.folded = true
		Action.CHECK:
			if player.current_bet < current_bet:
				push_warning("Cannot check with %d to call" % (current_bet - player.current_bet))
				return false
		Action.CALL:
			actual = player.stake(current_bet - player.current_bet)
		Action.BET:
			if current_bet > 0:
				push_warning("Cannot bet — already a bet on the table; use RAISE")
				return false
			if amount < big_blind_amount:
				push_warning("Bet must be at least the big blind")
				return false
			actual = player.stake(amount)
			current_bet = player.current_bet
			min_raise = player.current_bet
			_reset_others_acted()
		Action.RAISE:
			# `amount` is the new TOTAL bet (raise-to), not the delta.
			if amount < current_bet + min_raise:
				push_warning("Raise to %d, minimum is %d" % [amount, current_bet + min_raise])
				return false
			actual = player.stake(amount - player.current_bet)
			min_raise = player.current_bet - current_bet
			current_bet = player.current_bet
			_reset_others_acted()
		Action.ALL_IN:
			actual = player.stake(player.chips)
			# An all-in that puts the player above the current bet acts as a raise.
			if player.current_bet > current_bet:
				if player.current_bet - current_bet >= min_raise:
					min_raise = player.current_bet - current_bet
				current_bet = player.current_bet
				_reset_others_acted()
	player.has_acted_this_round = true
	# Profile observation — only track seat 0 (the human). Voluntary
	# preflop action ⇒ VPIP entry; postflop bet/raise/call/check
	# contributes to aggression factor.
	if current_player_index == 0:
		_record_human_action(action, phase == Phase.PREFLOP, player.current_bet > bet_before)
	player_acted.emit(current_player_index, action, actual)
	pot_changed.emit(pot_calculator.total_pot(players))
	_advance_action()
	return true


# Update the human's per-session profile based on the action they just
# took. Called inline from [method apply_action]. CHECK from the BB in
# an unraised preflop doesn't count as VPIP (it's a free play on the
# forced blind); CALL/RAISE/ALL_IN preflop do.
func _record_human_action(action: Action, is_preflop: bool, all_in_raised: bool) -> void:

	match action:
		Action.CALL, Action.RAISE, Action.ALL_IN:
			if is_preflop and not _human_entered_this_hand:
				_human_vpip_entries += 1
				_human_entered_this_hand = true
		_:
			pass
	# Aggression factor only counts postflop streets.
	if is_preflop:
		return
	match action:
		Action.BET, Action.RAISE:
			_human_aggressive_actions += 1
		Action.ALL_IN:
			# Aggressive only if the all-in actually RAISED the table bet
			# (computed in apply_action BEFORE current_bet was mutated) —
			# an all-in call-for-less is passive.
			if all_in_raised:
				_human_aggressive_actions += 1
			else:
				_human_passive_actions += 1
		Action.CALL, Action.CHECK:
			_human_passive_actions += 1
		_:
			pass


## Returns the human's observed playing-style stats over this session.
## Used by [PokerAI] when an opponent's
## [member NpcPersonality.perception] is non-zero. The returned dict
## includes:
##   • [code]vpip[/code] — fraction of hands they entered voluntarily preflop
##   • [code]aggression[/code] — bets+raises / (bets+raises+checks+calls), postflop
##   • [code]sample_hands[/code] — number of hands observed so far
##   • [code]sample_actions[/code] — postflop actions observed so far
func get_player_stats(player_index: int) -> Dictionary:

	if player_index != 0:
		return {"vpip": 0.5, "aggression": 0.5, "sample_hands": 0, "sample_actions": 0}
	var actions : int = _human_aggressive_actions + _human_passive_actions
	var vpip : float = 0.5
	if _human_hands_dealt > 0:
		vpip = float(_human_vpip_entries) / float(_human_hands_dealt)
	var aggression : float = 0.5
	if actions > 0:
		aggression = float(_human_aggressive_actions) / float(actions)
	return {
		"vpip": vpip,
		"aggression": aggression,
		"sample_hands": _human_hands_dealt,
		"sample_actions": actions,
	}


# --- Convenience for UI / AI ------------------------------------------

func get_current_player() -> PokerPlayer:

	if current_player_index < 0 or current_player_index >= players.size():
		return null
	return players[current_player_index]


## Chips the current player needs to put in to call.
func get_amount_to_call() -> int:

	var p : PokerPlayer = get_current_player()
	if p == null:
		return 0
	return maxi(0, current_bet - p.current_bet)


## Smallest legal "raise-to" amount for the current player.
func get_min_raise_to() -> int:

	return current_bet + min_raise


## Sum of every chip everybody has put in this hand. Pre-side-pot.
func get_total_pot() -> int:

	return pot_calculator.total_pot(players)


## True if the current player can check (i.e., they're already at the
## current bet level — typically only true post-flop or when BB has
## not yet acted preflop with no raise).
func can_check() -> bool:

	var p : PokerPlayer = get_current_player()
	if p == null:
		return false
	return p.current_bet >= current_bet


# --- Internals ---------------------------------------------------------

func _advance_action() -> void:

	# Only one player still in the hand → award immediately.
	var active : Array[int] = _active_indices()
	if active.size() <= 1:
		_finish_hand()
		return
	# Everyone left is all-in or alone with chips → fast-forward to showdown.
	var actionable : int = 0
	for i in active:
		if players[i].can_act():
			actionable += 1
	if actionable <= 1 and _is_round_complete():
		_fast_forward_to_showdown()
		return
	# Round complete → next phase.
	if _is_round_complete():
		_advance_phase()
		return
	# Otherwise, hand action to next actionable player.
	current_player_index = _next_actionable_player(current_player_index)
	turn_changed.emit(current_player_index)


func _is_round_complete() -> bool:

	for p in players:
		if p.folded or p.all_in:
			continue
		if not p.has_acted_this_round:
			return false
		if p.current_bet < current_bet:
			return false
	return true


func _advance_phase() -> void:

	for p in players:
		p.reset_for_new_round()
	current_bet = 0
	min_raise = big_blind_amount
	match phase:
		Phase.PREFLOP:
			community_cards.append_array(deck.deal(3))
			phase = Phase.FLOP
		Phase.FLOP:
			community_cards.append(deck.deal_one())
			phase = Phase.TURN
		Phase.TURN:
			community_cards.append(deck.deal_one())
			phase = Phase.RIVER
		Phase.RIVER:
			_showdown()
			return
	community_dealt.emit(community_cards.duplicate())
	phase_changed.emit(phase)
	# Post-flop: first to act is first non-folded/non-all-in player after dealer.
	current_player_index = _next_actionable_player(dealer_button)
	if current_player_index < 0:
		# Everyone's all-in — fast forward.
		_fast_forward_to_showdown()
		return
	turn_changed.emit(current_player_index)


func _fast_forward_to_showdown() -> void:

	# Deal any community cards we haven't yet.
	if community_cards.is_empty():
		community_cards.append_array(deck.deal(3))
	while community_cards.size() < 5:
		community_cards.append(deck.deal_one())
	community_dealt.emit(community_cards.duplicate())
	_showdown()


func _showdown() -> void:

	phase = Phase.SHOWDOWN
	phase_changed.emit(phase)
	var evals : Dictionary = {}
	for p in players:
		if not p.folded:
			var all_cards : Array[Card] = []
			all_cards.append_array(p.hole_cards)
			all_cards.append_array(community_cards)
			evals[p] = HandEval.best_of(all_cards)
	var awards : Array = pot_calculator.award(players, evals)
	phase = Phase.BETWEEN_HANDS
	hand_complete.emit(awards)


func _finish_hand() -> void:

	# Only one non-folded player left — they take everything, no showdown.
	var awards : Array = pot_calculator.award(players, {})
	phase = Phase.BETWEEN_HANDS
	hand_complete.emit(awards)


func _reset_others_acted() -> void:

	for i in players.size():
		if i != current_player_index:
			players[i].has_acted_this_round = false


func _next_player_with_chips(from_index: int) -> int:

	var idx : int = (from_index + 1) % players.size()
	for _i in players.size():
		if players[idx].chips > 0:
			return idx
		idx = (idx + 1) % players.size()
	return -1


func _next_actionable_player(from_index: int) -> int:

	var idx : int = (from_index + 1) % players.size()
	for _i in players.size():
		if players[idx].can_act():
			return idx
		idx = (idx + 1) % players.size()
	return -1


func _active_indices() -> Array[int]:

	var out : Array[int] = []
	for i in players.size():
		if not players[i].folded:
			out.append(i)
	return out


func _seats_with_chips() -> int:

	var n : int = 0
	for p in players:
		if p.chips > 0:
			n += 1
	return n
