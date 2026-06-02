## Visual smoke test for [PokerSeat]. Lays out 4 seats in a row with
## varied state — different colors, dealer button on one, active turn
## highlight on another, one folded — so we can eyeball that all the
## render paths look right at once.
##
## F6 to run.
extends Node2D


const SEAT_SCENE : PackedScene = preload("res://puzzles/poker/seat.tscn")


func _ready() -> void:

	# Seat 1: You — active, face-up cards (pair of aces).
	var you : PokerSeat = SEAT_SCENE.instantiate()
	add_child(you)
	you.position = Vector2(180, 200)
	you.seat_name = "You"
	you.portrait_color = Color(0.95, 0.74, 0.28)
	you.chips = 985
	you.current_bet = 15
	you.is_active = true
	you.hole_cards_face_up = true
	you.hole_cards = [
		Card.new(Card.Suit.SPADES, Card.ACE),
		Card.new(Card.Suit.HEARTS, Card.ACE),
	]

	# Seat 2: Flint Kerr — dealer, face-down cards.
	var kerr : PokerSeat = SEAT_SCENE.instantiate()
	add_child(kerr)
	kerr.position = Vector2(460, 200)
	kerr.seat_name = "Flint Kerr"
	kerr.portrait_color = Color(0.78, 0.32, 0.32)
	kerr.chips = 1230
	kerr.is_dealer = true
	kerr.hole_cards_face_up = false
	kerr.hole_cards = [
		Card.new(Card.Suit.CLUBS, 7),
		Card.new(Card.Suit.DIAMONDS, 9),
	]

	# Seat 3: Cogwise Godfrey — folded.
	var godfrey : PokerSeat = SEAT_SCENE.instantiate()
	add_child(godfrey)
	godfrey.position = Vector2(740, 200)
	godfrey.seat_name = "Cogwise Godfrey"
	godfrey.portrait_color = Color(0.30, 0.55, 0.82)
	godfrey.chips = 760
	godfrey.folded = true
	godfrey.hole_cards_face_up = false
	godfrey.hole_cards = [
		Card.new(Card.Suit.HEARTS, 4),
		Card.new(Card.Suit.SPADES, 2),
	]

	# Seat 4: Mossy Jade — short stack, all-in style current bet.
	var jade : PokerSeat = SEAT_SCENE.instantiate()
	add_child(jade)
	jade.position = Vector2(1020, 200)
	jade.seat_name = "Mossy Jade"
	jade.portrait_color = Color(0.30, 0.62, 0.36)
	jade.chips = 0
	jade.current_bet = 240
	jade.hole_cards_face_up = false
	jade.hole_cards = [
		Card.new(Card.Suit.DIAMONDS, Card.KING),
		Card.new(Card.Suit.CLUBS, Card.KING),
	]
