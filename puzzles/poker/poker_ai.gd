## Heuristic AI for poker opponents. Not minimax, not Monte Carlo —
## just a hand-strength + pot-odds + personality-knob mix that produces
## believable, distinct play across the 8 NPCs in [[cradle-rock-cast]].
##
## Entry point: [method decide]. Returns a Dictionary
##   { "action": PokerBoard.Action, "amount": int }
## that the scene controller can pass straight to
## [method PokerBoard.apply_action].
##
## Hand-strength scale (0..1):
##   • Preflop: from a pocket-pair / suited-high-card / connector table.
##   • Post-flop: from [HandEval]'s ranked category of the best 5-card
##     hand achievable so far. We DON'T do draw outs / equity sims —
##     so the AI plays a bit "made-hand-greedy", which is fine for v1.
##
## Personality knobs read from [member PokerPlayer.personality]:
##   • [member NpcPersonality.vpip_target] — looser players' fold
##     thresholds drop, so they enter more pots
##   • [member NpcPersonality.pfr_target] — aggressive players raise
##     more often when entering pots
##   • [member NpcPersonality.aggression] — global multiplier on the
##     raise-vs-call coin flip with strong hands
##   • [member NpcPersonality.bluff_rate] — chance to turn a marginal
##     hand into a raise
##   • [member NpcPersonality.patience] — tightens fold thresholds on
##     weak hands; patient players wait for better spots
class_name PokerAI
extends RefCounted


## Minimum samples before perception-based adjustments kick in. Below
## this, the player profile is too noisy to exploit, so the AI plays
## pure personality.
const PERCEPTION_SAMPLE_FLOOR : int = 5
## Cap on how much perception can shift the AI's thresholds. Caps
## prevent perception=1.0 NPCs from becoming purely-reactive monsters
## that lose all their own personality.
const PERCEPTION_MAX_SHIFT : float = 0.20


## Top-level decision. Always returns a legal action. Players without
## a [member PokerPlayer.personality] fall back to a balanced default
## profile so the AI never crashes on missing knobs.
static func decide(board: PokerBoard, player: PokerPlayer) -> Dictionary:

	var p : NpcPersonality = player.personality
	# Defaults if the player wasn't given a personality (shouldn't
	# happen at runtime, but unit tests construct bare players).
	var vpip : float = p.vpip_target if p != null else 0.25
	var pfr : float = p.pfr_target if p != null else 0.15
	var aggr : float = p.aggression if p != null else 0.5
	var bluff : float = p.bluff_rate if p != null else 0.25
	var patience : float = p.patience if p != null else 0.5
	var perception : float = p.perception if p != null else 0.0

	# Read the human's observed profile and compute how much we should
	# exploit it. Effective_perception scales with sample size so early
	# in the session the AI plays pure personality; only after ~10+
	# observed hands does the perception fully kick in.
	var human_stats : Dictionary = board.get_player_stats(0)
	var sample_confidence : float = clampf(
		float(human_stats["sample_hands"]) / 10.0, 0.0, 1.0)
	var effective_perception : float = perception * sample_confidence
	# Apply exploitative shifts to our knobs. Magnitudes are capped so
	# even a perception=1.0 NPC retains their personality identity.
	#   • If human plays loose (high VPIP) → bluff less, value-bet wider
	#   • If human plays tight (low VPIP) → bluff more, fold less
	#   • If human is aggressive (high AF) → call thinner (their bets aren't real)
	#   • If human is passive (low AF) → fold more to their bets (when they bet, they mean it)
	if effective_perception > 0.0 and human_stats["sample_hands"] >= PERCEPTION_SAMPLE_FLOOR:
		var vpip_delta : float = 0.5 - human_stats["vpip"]  # +ve = human is tight
		var agg_delta : float = human_stats["aggression"] - 0.5  # +ve = human is aggressive
		bluff += vpip_delta * effective_perception * PERCEPTION_MAX_SHIFT * 2.0
		bluff = clampf(bluff, 0.0, 0.9)
		# Tight human → AI calls more (their fold equity is real to us).
		# Aggressive human → AI folds less (their bets are likely bluffs).
		patience -= agg_delta * effective_perception * PERCEPTION_MAX_SHIFT
		patience = clampf(patience, 0.0, 1.0)

	var strength : float = _estimate_strength(player, board.community_cards)
	var to_call : int = board.get_amount_to_call()
	var pot : int = board.get_total_pot()
	var pot_odds : float = 0.0
	if to_call > 0:
		pot_odds = float(to_call) / float(pot + to_call)
	var roll : float = randf()
	var preflop : bool = board.community_cards.is_empty()

	# Fold threshold slides with VPIP — a loose player (high VPIP) folds
	# fewer hands; a tight player (low VPIP) folds more. Patience pulls
	# it tighter still: a patient NPC waits for premium spots even if
	# their VPIP target is moderate.
	var fold_threshold : float = lerpf(0.45, 0.15, vpip) + (patience - 0.5) * 0.15
	fold_threshold = clampf(fold_threshold, 0.10, 0.65)

	# Premium hand — raise, scaled by aggression. Tight-passive NPCs
	# raise small here (min raise); maniacs go pot-sized.
	if strength >= 0.85:
		var raise_to : int = (
			_pot_sized_raise(board) if aggr >= 0.6
			else board.get_min_raise_to())
		return _make_raise_or_bet(board, player, raise_to)

	# Strong hand — raise chance scales with personality's PFR target
	# (preflop) or aggression (postflop). Otherwise call/check.
	if strength >= 0.55:
		var raise_chance : float = pfr if preflop else aggr * 0.6
		if roll < raise_chance and (board.current_bet > 0 or preflop):
			return _make_raise_or_bet(board, player, board.get_min_raise_to())
		if board.can_check():
			return {"action": PokerBoard.Action.CHECK, "amount": 0}
		return {"action": PokerBoard.Action.CALL, "amount": 0}

	# Marginal hand — preflop VPIP gates entry; postflop pot-odds + bluff.
	if strength >= fold_threshold:
		if preflop:
			# Personality VPIP scales how often we voluntarily play this
			# zone. Loose players call here; tight players fold.
			if to_call == 0:
				return {"action": PokerBoard.Action.CHECK, "amount": 0}
			if roll < vpip + 0.1 and to_call <= player.chips:
				return {"action": PokerBoard.Action.CALL, "amount": 0}
			return {"action": PokerBoard.Action.FOLD, "amount": 0}
		# Postflop marginal — bluff chance, otherwise pot-odds decide.
		if board.can_check() and roll < bluff:
			return _make_raise_or_bet(board, player, board.get_min_raise_to())
		if board.can_check():
			return {"action": PokerBoard.Action.CHECK, "amount": 0}
		var pot_odds_tolerance : float = 0.20 + risk_bonus(p)
		if pot_odds < pot_odds_tolerance and to_call <= player.chips:
			return {"action": PokerBoard.Action.CALL, "amount": 0}
		return {"action": PokerBoard.Action.FOLD, "amount": 0}

	# Weak — bluff sometimes, otherwise check/fold.
	if board.can_check() and roll < bluff * 0.5:
		return _make_raise_or_bet(board, player, board.get_min_raise_to())
	if board.can_check():
		return {"action": PokerBoard.Action.CHECK, "amount": 0}
	return {"action": PokerBoard.Action.FOLD, "amount": 0}


# Risk-tolerance bonus to pot-odds tolerance — high-risk NPCs call
# slightly worse odds, low-risk NPCs need tighter odds to call.
static func risk_bonus(p: NpcPersonality) -> float:

	if p == null:
		return 0.0
	return (p.risk_tolerance - 0.5) * 0.15


# --- Internals ---------------------------------------------------------

# Builds either a RAISE or a BET depending on whether there's already a
# bet to raise. Clamps to the player's stack — going all-in if needed.
static func _make_raise_or_bet(board: PokerBoard, player: PokerPlayer, target_total: int) -> Dictionary:

	var stack_total : int = player.current_bet + player.chips  # max possible total bet
	# Can't raise above your stack.
	target_total = mini(target_total, stack_total)
	if board.current_bet == 0:
		# No bet yet — this is a BET, amount is the chip amount put in.
		var bet_amount : int = target_total - player.current_bet
		# Bet must be at least the BB.
		bet_amount = maxi(bet_amount, board.big_blind_amount)
		bet_amount = mini(bet_amount, player.chips)
		if bet_amount == player.chips:
			return {"action": PokerBoard.Action.ALL_IN, "amount": 0}
		return {"action": PokerBoard.Action.BET, "amount": bet_amount}
	# RAISE — `amount` is the new total bet.
	# If we can't make a full min-raise, just shove all-in (legal).
	if target_total < board.current_bet + board.min_raise:
		return {"action": PokerBoard.Action.ALL_IN, "amount": 0}
	if target_total == stack_total and player.chips > 0:
		return {"action": PokerBoard.Action.ALL_IN, "amount": 0}
	return {"action": PokerBoard.Action.RAISE, "amount": target_total}


# A pot-sized raise: aim for total bet ≈ current_bet + pot. Capped at stack.
static func _pot_sized_raise(board: PokerBoard) -> int:

	return board.current_bet + maxi(board.big_blind_amount, board.get_total_pot())


static func _estimate_strength(player: PokerPlayer, community: Array[Card]) -> float:

	if community.is_empty():
		return _preflop_strength(player.hole_cards)
	var all_cards : Array[Card] = []
	all_cards.append_array(player.hole_cards)
	all_cards.append_array(community)
	if all_cards.size() < 5:
		return 0.30
	var eval : Dictionary = HandEval.best_of(all_cards)
	match int(eval["rank"]):
		HandEval.HandRank.HIGH_CARD: return 0.15
		HandEval.HandRank.PAIR: return _pair_strength(eval, player.hole_cards)
		HandEval.HandRank.TWO_PAIR: return 0.58
		HandEval.HandRank.THREE_OF_A_KIND: return 0.72
		HandEval.HandRank.STRAIGHT: return 0.80
		HandEval.HandRank.FLUSH: return 0.86
		HandEval.HandRank.FULL_HOUSE: return 0.93
		HandEval.HandRank.FOUR_OF_A_KIND: return 0.97
		HandEval.HandRank.STRAIGHT_FLUSH: return 1.0
	return 0.30


# Lift the AI's view of a pair if it includes one of our hole cards
# AND is a high pair — top pair plays much stronger than bottom pair.
static func _pair_strength(eval: Dictionary, hole: Array[Card]) -> float:

	var pair_rank : int = eval["kickers"][0]  # already promoted (A=14)
	var hole_ranks : Array[int] = []
	for c in hole:
		hole_ranks.append(14 if c.rank == Card.ACE else c.rank)
	if pair_rank in hole_ranks:
		# Pocket pair OR top-pair-with-hole — strong.
		if pair_rank >= 11:
			return 0.55
		return 0.40
	return 0.28


static func _preflop_strength(hole: Array[Card]) -> float:

	if hole.size() != 2:
		return 0.30
	var r1 : int = 14 if hole[0].rank == Card.ACE else hole[0].rank
	var r2 : int = 14 if hole[1].rank == Card.ACE else hole[1].rank
	var hi : int = maxi(r1, r2)
	var lo : int = mini(r1, r2)
	var suited : bool = hole[0].suit == hole[1].suit
	var gap : int = hi - lo
	# Pocket pair.
	if r1 == r2:
		if r1 >= 13:        return 0.95  # KK, AA
		if r1 >= 11:        return 0.88  # JJ, QQ
		if r1 >= 7:         return 0.72  # 77 - TT
		return 0.55                       # 22 - 66
	# AK / AQ / AJ / KQ / KJ / QJ
	if hi == 14 and lo >= 11:
		return 0.80 if suited else 0.70
	if hi == 13 and lo >= 11:
		return 0.65 if suited else 0.55
	if hi == 12 and lo == 11:
		return 0.55 if suited else 0.45
	# Suited connectors (J-10, 10-9, 9-8 …)
	if suited and gap <= 2 and lo >= 7:
		return 0.45
	# Big-ace junk (A2..A10)
	if hi == 14:
		return 0.40 if suited else 0.30
	# Two paint cards
	if lo >= 11:
		return 0.35
	# Everything else — tend to fold.
	return 0.18
