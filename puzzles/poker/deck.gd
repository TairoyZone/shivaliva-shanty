## A 52-card playing deck. Builds itself, shuffles, deals from the top.
##
## Cards are popped off [member _cards] from the back (top of deck) so
## dealing is O(1). Between hands call [method reset] then [method shuffle].
class_name Deck
extends RefCounted


var _cards : Array[Card] = []


func _init() -> void:

	reset()


## Rebuild a fresh 52-card deck in canonical order (Hearts A→K, Diamonds
## A→K, Spades A→K, Clubs A→K). Caller normally follows with `shuffle()`.
func reset() -> void:

	_cards.clear()
	for suit_idx in 4:
		for rank in range(Card.ACE, Card.KING + 1):
			_cards.append(Card.new(suit_idx, rank))


## In-place Fisher-Yates shuffle (Godot's Array.shuffle).
func shuffle() -> void:

	_cards.shuffle()


## Deal one card off the top. Returns null if the deck is empty.
func deal_one() -> Card:

	if _cards.is_empty():
		return null
	return _cards.pop_back()


## Deal `count` cards. Returns fewer than requested if the deck dries up.
func deal(count: int) -> Array[Card]:

	var out : Array[Card] = []
	for i in count:
		var c : Card = deal_one()
		if c == null:
			break
		out.append(c)
	return out


func cards_left() -> int:

	return _cards.size()
