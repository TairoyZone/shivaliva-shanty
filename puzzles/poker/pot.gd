## Pot accounting with side-pot math. The pot is a flat counter during
## a hand; at showdown (or when all-in interactions force it), we split
## the players' contributions into a main pot + zero-or-more side pots
## based on each player's [member PokerPlayer.total_bet_in_hand].
##
## Side-pot algorithm:
##   • Collect distinct bet levels (each player's total contribution).
##   • Sort ascending. Each level becomes a "ring" of the pot.
##   • For ring at level L (previous L_prev): every player whose total
##     contribution is ≥ L pays (L - L_prev) into this ring.
##   • Players who haven't folded and contributed ≥ L are eligible
##     to win that ring at showdown.
##
## Example — A all-in 100, B all-in 200, C calls 300:
##   Ring 1 (level 100): A, B, C each contribute 100 → pot 300, all eligible
##   Ring 2 (level 200): B, C each contribute 100 → pot 200, B & C eligible
##   Ring 3 (level 300): C contributes 100 → pot 100, C only eligible
class_name PokerPot
extends RefCounted


## Sum of every chip every player has staked in the current hand.
## Includes folded players' dead money. Useful for the headline pot
## display before showdown.
func total_pot(players: Array[PokerPlayer]) -> int:

	var sum : int = 0
	for p in players:
		sum += p.total_bet_in_hand
	return sum


## Build the ordered list of pots (main pot first, then side pots) from
## each player's cumulative contribution to the hand.
##
## Returns Array of:
##   { "amount": int, "eligible": Array[PokerPlayer] }
##
## Pots with amount == 0 (e.g. when only one player contributed at a
## stake level) are omitted.
func build_pots(players: Array[PokerPlayer]) -> Array[Dictionary]:

	# Distinct stake levels in ascending order.
	var levels : Array[int] = []
	for p in players:
		if p.total_bet_in_hand > 0 and not (p.total_bet_in_hand in levels):
			levels.append(p.total_bet_in_hand)
	levels.sort()

	var pots : Array[Dictionary] = []
	var prev_level : int = 0
	for level in levels:
		var stake_at_ring : int = level - prev_level
		var amount : int = 0
		var eligible : Array[PokerPlayer] = []
		for p in players:
			if p.total_bet_in_hand >= level:
				amount += stake_at_ring
				if not p.folded:
					eligible.append(p)
		if amount > 0:
			pots.append({"amount": amount, "eligible": eligible})
		prev_level = level
	return pots


## Award each pot to the eligible player(s) with the best hand. Hands
## must already be evaluated; pass a parallel dict mapping player → eval
## result (the dict returned by [method HandEval.best_of]).
##
## Ties split the pot evenly; any leftover odd chip(s) go to the first
## eligible player clockwise from the dealer button — but for MVP we just
## give the remainder to the first winner in the eligible list. Easy to
## refine later.
##
## Returns a list of award descriptions for UI:
##   [{ "pot_index": int, "winners": Array[PokerPlayer], "per_winner": int, "remainder": int }]
func award(players: Array[PokerPlayer], hand_evals: Dictionary) -> Array[Dictionary]:

	var awards : Array[Dictionary] = []
	var pots : Array[Dictionary] = build_pots(players)
	for i in pots.size():
		var pot : Dictionary = pots[i]
		var eligible : Array[PokerPlayer] = pot["eligible"]
		if eligible.is_empty():
			continue
		# Find best hand among eligible players. eligible may have only
		# one player (e.g. everyone else folded — no showdown needed).
		var winners : Array[PokerPlayer] = []
		if eligible.size() == 1:
			winners = [eligible[0]]
		else:
			var best_eval : Dictionary = {}
			for p in eligible:
				var ev : Dictionary = hand_evals.get(p, {})
				if best_eval.is_empty() or HandEval.compare(ev, best_eval) > 0:
					best_eval = ev
					winners = [p]
				elif HandEval.compare(ev, best_eval) == 0:
					winners.append(p)
		var per : int = pot["amount"] / winners.size()
		var remainder : int = pot["amount"] - per * winners.size()
		for w in winners:
			w.receive(per)
		# Drop the odd-chip remainder on the first winner.
		if remainder > 0:
			winners[0].receive(remainder)
		awards.append({
			"pot_index": i,
			"winners": winners,
			"per_winner": per,
			"remainder": remainder,
		})
	return awards
