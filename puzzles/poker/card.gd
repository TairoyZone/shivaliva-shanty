## A single playing card. Immutable data class — suit + rank only.
## Face-up/down is rendering state and lives on [CardSprite], not here.
##
## Rank uses 1..13 where 1 = Ace. The hand evaluator promotes Ace to
## 14 internally for high-card comparisons and handles the A-2-3-4-5
## "wheel" straight as a special case.
class_name Card
extends RefCounted


enum Suit {
	HEARTS,    ## ♥ red
	DIAMONDS,  ## ♦ red
	SPADES,    ## ♠ black
	CLUBS,     ## ♣ black
}

const ACE : int = 1
const JACK : int = 11
const QUEEN : int = 12
const KING : int = 13

const RANK_GLYPHS : Array[String] = [
	"", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K",
]
const SUIT_GLYPHS : Array[String] = ["♥", "♦", "♠", "♣"]

var suit : Suit
var rank : int


func _init(p_suit: Suit = Suit.HEARTS, p_rank: int = ACE) -> void:

	suit = p_suit
	rank = p_rank


## "A♥", "10♣", "Q♠". For debug print + the hand-result UI line.
func short_name() -> String:

	return RANK_GLYPHS[rank] + SUIT_GLYPHS[suit]


## Hearts and Diamonds are red. Convenience for any future text-color logic.
func is_red() -> bool:

	return suit == Suit.HEARTS or suit == Suit.DIAMONDS


## Suit + rank equality. Useful for "card already dealt?" checks.
func equals(other: Card) -> bool:

	return other != null and other.suit == suit and other.rank == rank
