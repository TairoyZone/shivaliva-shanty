## Unit tests for [HandEval]. Runs a set of named cases through the
## evaluator and asserts both the hand-rank category and the kicker
## list. Results print to the console and to the on-screen label so
## you can see at a glance whether the evaluator is sane.
##
## Run with F6 (or set as main scene). Green text = all pass, red
## means at least one case failed — look at the console for which.
extends Node2D


@onready var _label : Label = $Result


func _ready() -> void:

	var failures : Array[String] = _run_all_tests()
	if failures.is_empty():
		_label.text = "HandEval: all %d tests passed" % _TEST_CASES.size()
		_label.modulate = Color(0.55, 0.95, 0.55)
		print("HandEval: all %d tests passed" % _TEST_CASES.size())
	else:
		_label.text = "HandEval: %d / %d tests FAILED\n%s" % [
			failures.size(), _TEST_CASES.size(), "\n".join(failures),
		]
		_label.modulate = Color(1.0, 0.55, 0.55)
		printerr("HandEval failures:")
		for line in failures:
			printerr("  ", line)


# Each case: name, cards, expected rank, expected kickers (first few).
# The kicker list only has to MATCH the prefix we list — useful when
# we only care about the most-significant slots.
const _TEST_CASES : Array = [
	{
		"name": "Royal flush (A-K-Q-J-10 ♠)",
		"cards": [["S", 1], ["S", 13], ["S", 12], ["S", 11], ["S", 10]],
		"rank": HandEval.HandRank.STRAIGHT_FLUSH,
		"kickers": [14],
	},
	{
		"name": "Wheel straight flush (5-4-3-2-A ♥)",
		"cards": [["H", 1], ["H", 2], ["H", 3], ["H", 4], ["H", 5]],
		"rank": HandEval.HandRank.STRAIGHT_FLUSH,
		"kickers": [5],
	},
	{
		"name": "Four of a kind (Aces, K kicker)",
		"cards": [["S", 1], ["H", 1], ["D", 1], ["C", 1], ["S", 13]],
		"rank": HandEval.HandRank.FOUR_OF_A_KIND,
		"kickers": [14, 13],
	},
	{
		"name": "Full house (Kings over 7s)",
		"cards": [["S", 13], ["H", 13], ["D", 13], ["C", 7], ["S", 7]],
		"rank": HandEval.HandRank.FULL_HOUSE,
		"kickers": [13, 7],
	},
	{
		"name": "Flush (A-J-9-5-2 ♦)",
		"cards": [["D", 1], ["D", 11], ["D", 9], ["D", 5], ["D", 2]],
		"rank": HandEval.HandRank.FLUSH,
		"kickers": [14, 11, 9, 5, 2],
	},
	{
		"name": "Ace-high straight (broadway)",
		"cards": [["S", 1], ["H", 13], ["D", 12], ["C", 11], ["S", 10]],
		"rank": HandEval.HandRank.STRAIGHT,
		"kickers": [14],
	},
	{
		"name": "Wheel straight (5-4-3-2-A mixed)",
		"cards": [["S", 1], ["H", 2], ["D", 3], ["C", 4], ["S", 5]],
		"rank": HandEval.HandRank.STRAIGHT,
		"kickers": [5],
	},
	{
		"name": "9-high straight",
		"cards": [["S", 5], ["H", 6], ["D", 7], ["C", 8], ["S", 9]],
		"rank": HandEval.HandRank.STRAIGHT,
		"kickers": [9],
	},
	{
		"name": "Three of a kind (Queens, A-K kickers)",
		"cards": [["S", 12], ["H", 12], ["D", 12], ["C", 1], ["S", 13]],
		"rank": HandEval.HandRank.THREE_OF_A_KIND,
		"kickers": [12, 14, 13],
	},
	{
		"name": "Two pair (Aces and Kings, Q kicker)",
		"cards": [["S", 1], ["H", 1], ["D", 13], ["C", 13], ["S", 12]],
		"rank": HandEval.HandRank.TWO_PAIR,
		"kickers": [14, 13, 12],
	},
	{
		"name": "Pair (8s with A-K-Q kickers)",
		"cards": [["S", 8], ["H", 8], ["D", 1], ["C", 13], ["S", 12]],
		"rank": HandEval.HandRank.PAIR,
		"kickers": [8, 14, 13, 12],
	},
	{
		"name": "High card (A-K-Q-J-9)",
		"cards": [["S", 1], ["H", 13], ["D", 12], ["C", 11], ["S", 9]],
		"rank": HandEval.HandRank.HIGH_CARD,
		"kickers": [14, 13, 12, 11, 9],
	},
	# Best-of-7 (Texas Hold'em) tests:
	{
		"name": "Best-of-7: find flush among 7 cards",
		"cards": [["S", 1], ["S", 13], ["S", 7], ["S", 4], ["S", 2], ["H", 8], ["D", 9]],
		"rank": HandEval.HandRank.FLUSH,
		"kickers": [14, 13, 7, 4, 2],
	},
	{
		"name": "Best-of-7: full house beats trips",
		"cards": [["S", 5], ["H", 5], ["D", 5], ["C", 8], ["S", 8], ["H", 2], ["D", 1]],
		"rank": HandEval.HandRank.FULL_HOUSE,
		"kickers": [5, 8],
	},
	{
		"name": "Best-of-7: straight flush beats four of a kind",
		"cards": [["S", 7], ["S", 8], ["S", 9], ["S", 10], ["S", 11], ["H", 7], ["D", 7]],
		"rank": HandEval.HandRank.STRAIGHT_FLUSH,
		"kickers": [11],
	},
]


func _run_all_tests() -> Array[String]:

	var failures : Array[String] = []
	for case in _TEST_CASES:
		var cards : Array[Card] = _make_cards(case["cards"])
		var result : Dictionary = HandEval.best_of(cards)
		var msg : String = _check_case(case, result)
		if msg != "":
			failures.append(msg)
	return failures


func _check_case(case: Dictionary, result: Dictionary) -> String:

	var expected_rank : int = case["rank"]
	if result["rank"] != expected_rank:
		return "%s: rank was %s, expected %s (got %s)" % [
			case["name"],
			HandEval.RANK_NAMES[result["rank"]],
			HandEval.RANK_NAMES[expected_rank],
			HandEval.describe(result),
		]
	var expected_kickers : Array = case["kickers"]
	var got_kickers : Array[int] = result["kickers"]
	for i in expected_kickers.size():
		if i >= got_kickers.size() or got_kickers[i] != expected_kickers[i]:
			return "%s: kickers %s, expected prefix %s" % [
				case["name"], got_kickers, expected_kickers,
			]
	return ""


# Convert ["S", 13] → Card(SPADES, 13). Suit letters: H/D/S/C.
func _make_cards(spec: Array) -> Array[Card]:

	const SUIT_MAP : Dictionary = {
		"H": Card.Suit.HEARTS,
		"D": Card.Suit.DIAMONDS,
		"S": Card.Suit.SPADES,
		"C": Card.Suit.CLUBS,
	}
	var out : Array[Card] = []
	for entry in spec:
		out.append(Card.new(SUIT_MAP[entry[0]], entry[1]))
	return out
