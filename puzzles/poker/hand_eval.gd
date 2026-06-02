## Poker hand evaluator. Given any 5..7 cards, returns the best 5-card
## hand as a Dictionary suitable for [method compare].
##
## Result shape:
##   {
##     "rank": HandRank,           # category (HIGH_CARD .. STRAIGHT_FLUSH)
##     "kickers": Array[int],      # rank values, descending, used for tiebreaks
##     "cards": Array[Card],       # the 5 cards that made the hand
##   }
##
## Comparison order: `rank` first (higher wins), then `kickers` element
## by element. Kickers are always ordered so the most significant value
## comes first (e.g. for a Pair the pair-rank, then the 3 high kickers).
##
## Ace handling: rank 1 = Ace. The evaluator promotes Ace to 14 for
## kicker / high-straight comparison, and handles the A-2-3-4-5 "wheel"
## straight as a separate case (top rank = 5).
class_name HandEval
extends RefCounted


enum HandRank {
	HIGH_CARD,
	PAIR,
	TWO_PAIR,
	THREE_OF_A_KIND,
	STRAIGHT,
	FLUSH,
	FULL_HOUSE,
	FOUR_OF_A_KIND,
	STRAIGHT_FLUSH,
}

const RANK_NAMES : Array[String] = [
	"High Card", "Pair", "Two Pair", "Three of a Kind",
	"Straight", "Flush", "Full House", "Four of a Kind", "Straight Flush",
]


## Returns the best 5-card hand from `cards` (size ≥ 5).
static func best_of(cards: Array[Card]) -> Dictionary:

	assert(cards.size() >= 5, "best_of needs at least 5 cards")
	var best : Dictionary = {}
	for combo in _combinations(cards, 5):
		var result : Dictionary = _eval_five(combo)
		if best.is_empty() or _compare(result, best) > 0:
			best = result
	return best


## Compare two evaluated hands. >0 if a wins, <0 if b wins, 0 = tie.
static func compare(a: Dictionary, b: Dictionary) -> int:

	return _compare(a, b)


## Compact version of [method describe] suitable for the limited width
## of a seat panel. Drops the "and 7s", "over 7s" tails so every label
## fits in ~14 characters: "Pair of Aces", "Two Pair", "Full House",
## "Royal Flush", etc.
static func short_describe(eval: Dictionary) -> String:

	var rank : int = eval["rank"]
	var k : Array[int] = eval["kickers"]
	match rank:
		HandRank.HIGH_CARD:
			return "%s high" % _rank_word(k[0])
		HandRank.PAIR:
			return "Pair of %ss" % _rank_word_plural(k[0])
		HandRank.TWO_PAIR:
			return "Two Pair"
		HandRank.THREE_OF_A_KIND:
			return "Three %ss" % _rank_word_plural(k[0])
		HandRank.STRAIGHT:
			return "Straight"
		HandRank.FLUSH:
			return "Flush"
		HandRank.FULL_HOUSE:
			return "Full House"
		HandRank.FOUR_OF_A_KIND:
			return "Four %ss" % _rank_word_plural(k[0])
		HandRank.STRAIGHT_FLUSH:
			if k[0] == 14:
				return "Royal Flush"
			return "Straight Flush"
	return RANK_NAMES[rank]


## Showdown-flavored description that includes kicker ranks so a
## tiebreak ("both players had Three Kings, who won?") is readable
## from the label alone. Format: rank category, then the side-kickers
## in parentheses for hands where kickers can decide it — e.g.
## "Three Kings (A 5)", "Pair of 9s (A K J)", "Ace high (K Q J 10)".
## Hands where the rank alone determines the winner (straight, flush
## top, full house, quads, straight flush) skip the kicker tail.
static func describe_showdown(eval: Dictionary) -> String:

	var rank : int = eval["rank"]
	var k : Array[int] = eval["kickers"]
	match rank:
		HandRank.HIGH_CARD:
			return "%s high (%s)" % [_rank_word(k[0]), _kickers_short(k, 1, 4)]
		HandRank.PAIR:
			return "Pair of %ss (%s)" % [_rank_word_plural(k[0]), _kickers_short(k, 1, 3)]
		HandRank.TWO_PAIR:
			return "Two pair %ss & %ss (%s)" % [
				_rank_word_plural(k[0]), _rank_word_plural(k[1]), _kickers_short(k, 2, 1)]
		HandRank.THREE_OF_A_KIND:
			return "Three %ss (%s)" % [_rank_word_plural(k[0]), _kickers_short(k, 1, 2)]
		HandRank.STRAIGHT:
			return "Straight, %s high" % _rank_word(k[0])
		HandRank.FLUSH:
			return "Flush, %s high (%s)" % [_rank_word(k[0]), _kickers_short(k, 1, 4)]
		HandRank.FULL_HOUSE:
			return "%ss full of %ss" % [_rank_word_plural(k[0]), _rank_word_plural(k[1])]
		HandRank.FOUR_OF_A_KIND:
			return "Four %ss" % _rank_word_plural(k[0])
		HandRank.STRAIGHT_FLUSH:
			if k[0] == 14:
				return "Royal Flush"
			return "Straight Flush, %s high" % _rank_word(k[0])
	return RANK_NAMES[rank]


## Human-readable description: "Pair of Aces", "Full house, Kings over 7s",
## "Royal flush", etc.
static func describe(eval: Dictionary) -> String:

	var rank : int = eval["rank"]
	var k : Array[int] = eval["kickers"]
	match rank:
		HandRank.HIGH_CARD:
			return "%s high" % _rank_word(k[0])
		HandRank.PAIR:
			return "Pair of %ss" % _rank_word_plural(k[0])
		HandRank.TWO_PAIR:
			return "Two pair, %ss and %ss" % [_rank_word_plural(k[0]), _rank_word_plural(k[1])]
		HandRank.THREE_OF_A_KIND:
			return "Three %ss" % _rank_word_plural(k[0])
		HandRank.STRAIGHT:
			return "Straight, %s high" % _rank_word(k[0])
		HandRank.FLUSH:
			return "Flush, %s high" % _rank_word(k[0])
		HandRank.FULL_HOUSE:
			return "Full house, %ss over %ss" % [_rank_word_plural(k[0]), _rank_word_plural(k[1])]
		HandRank.FOUR_OF_A_KIND:
			return "Four %ss" % _rank_word_plural(k[0])
		HandRank.STRAIGHT_FLUSH:
			if k[0] == 14:
				return "Royal flush"
			return "Straight flush, %s high" % _rank_word(k[0])
	return RANK_NAMES[rank]


# --- Internals ---------------------------------------------------------


static func _eval_five(cards: Array[Card]) -> Dictionary:

	# High ranks: Ace promoted to 14 so flush/high-card kickers sort right.
	# Original ranks are kept around for the A-low wheel-straight check.
	var high_ranks : Array[int] = []
	for c in cards:
		high_ranks.append(14 if c.rank == Card.ACE else c.rank)
	high_ranks.sort()
	high_ranks.reverse()

	var is_flush : bool = _is_flush(cards)
	var straight_high : int = _straight_high(high_ranks)
	var counts : Dictionary = _rank_counts(high_ranks)

	if is_flush and straight_high > 0:
		return _result(HandRank.STRAIGHT_FLUSH, [straight_high], cards)
	if _has_count(counts, 4):
		var four_rank : int = _rank_with_count(counts, 4)
		var kicker : int = _highest_other(high_ranks, [four_rank])
		return _result(HandRank.FOUR_OF_A_KIND, [four_rank, kicker], cards)
	if _has_count(counts, 3) and _has_count(counts, 2):
		return _result(HandRank.FULL_HOUSE,
			[_rank_with_count(counts, 3), _rank_with_count(counts, 2)], cards)
	if is_flush:
		return _result(HandRank.FLUSH, high_ranks, cards)
	if straight_high > 0:
		return _result(HandRank.STRAIGHT, [straight_high], cards)
	if _has_count(counts, 3):
		var trip_rank : int = _rank_with_count(counts, 3)
		var trip_kickers : Array[int] = _highest_n_other(high_ranks, [trip_rank], 2)
		return _result(HandRank.THREE_OF_A_KIND, [trip_rank] + trip_kickers, cards)
	if _count_of_kind(counts, 2) == 2:
		var pairs : Array[int] = _ranks_with_count(counts, 2)
		pairs.sort()
		pairs.reverse()
		var two_pair_kicker : int = _highest_other(high_ranks, pairs)
		return _result(HandRank.TWO_PAIR, [pairs[0], pairs[1], two_pair_kicker], cards)
	if _has_count(counts, 2):
		var pair_rank : int = _rank_with_count(counts, 2)
		var pair_kickers : Array[int] = _highest_n_other(high_ranks, [pair_rank], 3)
		return _result(HandRank.PAIR, [pair_rank] + pair_kickers, cards)
	return _result(HandRank.HIGH_CARD, high_ranks, cards)


static func _result(rank: HandRank, kickers: Array, source_cards: Array[Card]) -> Dictionary:

	var typed : Array[int] = []
	for k in kickers:
		typed.append(k)
	return {
		"rank": rank,
		"kickers": typed,
		"cards": source_cards.duplicate(),
	}


static func _compare(a: Dictionary, b: Dictionary) -> int:

	if a["rank"] != b["rank"]:
		return a["rank"] - b["rank"]
	var ka : Array[int] = a["kickers"]
	var kb : Array[int] = b["kickers"]
	for i in mini(ka.size(), kb.size()):
		if ka[i] != kb[i]:
			return ka[i] - kb[i]
	return 0


static func _is_flush(cards: Array[Card]) -> bool:

	var first_suit : int = cards[0].suit
	for c in cards:
		if c.suit != first_suit:
			return false
	return true


# Returns the top rank of the straight, or 0 if no straight.
# `high_ranks_desc` is sorted descending with Ace = 14.
# A-2-3-4-5 ("wheel") returns 5.
static func _straight_high(high_ranks_desc: Array[int]) -> int:

	if high_ranks_desc.size() != 5:
		return 0
	# Standard descending-sequential check.
	var sequential : bool = true
	for i in range(1, 5):
		if high_ranks_desc[i] != high_ranks_desc[i - 1] - 1:
			sequential = false
			break
	if sequential:
		return high_ranks_desc[0]
	# Wheel: [14, 5, 4, 3, 2]
	if high_ranks_desc == [14, 5, 4, 3, 2]:
		return 5
	return 0


static func _rank_counts(ranks: Array[int]) -> Dictionary:

	var d : Dictionary = {}
	for r in ranks:
		d[r] = d.get(r, 0) + 1
	return d


static func _has_count(counts: Dictionary, n: int) -> bool:

	for k in counts:
		if counts[k] == n:
			return true
	return false


# Returns the highest-ranked card that appears exactly n times.
static func _rank_with_count(counts: Dictionary, n: int) -> int:

	var best : int = 0
	for k in counts:
		if counts[k] == n and k > best:
			best = k
	return best


static func _ranks_with_count(counts: Dictionary, n: int) -> Array[int]:

	var out : Array[int] = []
	for k in counts:
		if counts[k] == n:
			out.append(k)
	return out


# How many distinct ranks appear exactly n times.
static func _count_of_kind(counts: Dictionary, n: int) -> int:

	var c : int = 0
	for k in counts:
		if counts[k] == n:
			c += 1
	return c


static func _highest_other(high_ranks_desc: Array[int], exclude: Array[int]) -> int:

	for r in high_ranks_desc:
		if r not in exclude:
			return r
	return 0


static func _highest_n_other(high_ranks_desc: Array[int], exclude: Array[int], n: int) -> Array[int]:

	var out : Array[int] = []
	for r in high_ranks_desc:
		if r not in exclude:
			out.append(r)
			if out.size() >= n:
				break
	return out


# Generate all C(n, k) k-card combinations from `cards`.
# For 7 cards choose 5 that's 21 combos — fine.
static func _combinations(cards: Array[Card], k: int) -> Array:

	var result : Array = []
	_combo_recurse(cards, k, 0, [], result)
	return result


static func _combo_recurse(cards: Array[Card], k: int, start: int, current: Array, result: Array) -> void:

	if current.size() == k:
		var combo : Array[Card] = []
		for i in current:
			combo.append(cards[i])
		result.append(combo)
		return
	for i in range(start, cards.size()):
		current.append(i)
		_combo_recurse(cards, k, i + 1, current, result)
		current.pop_back()


static func _rank_word(high_rank: int) -> String:

	match high_rank:
		14: return "Ace"
		13: return "King"
		12: return "Queen"
		11: return "Jack"
	return str(high_rank)


static func _rank_word_plural(high_rank: int) -> String:

	match high_rank:
		14: return "Ace"
		13: return "King"
		12: return "Queen"
		11: return "Jack"
	return str(high_rank)


# Compact single-glyph rank for kicker tails — face cards become a
# letter, tens are "T", everything else stays numeric. Lets us pack
# 3–4 kickers into the parenthetical without blowing the panel width.
static func _rank_short(high_rank: int) -> String:

	match high_rank:
		14: return "A"
		13: return "K"
		12: return "Q"
		11: return "J"
		10: return "T"
	return str(high_rank)


# Joins a slice of [param kickers] from [param start] for [param count]
# entries, each rendered via [method _rank_short], space-separated.
# Stops early if the array is shorter than expected.
static func _kickers_short(kickers: Array[int], start: int, count: int) -> String:

	var parts : PackedStringArray = []
	for i in count:
		var idx : int = start + i
		if idx >= kickers.size():
			break
		parts.append(_rank_short(kickers[idx]))
	return " ".join(parts)
