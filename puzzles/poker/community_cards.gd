## The 5-card community-card row in the middle of the table. Revealed
## progressively as the board phase advances:
##   • PREFLOP: nothing shown.
##   • FLOP: first 3 cards revealed.
##   • TURN: 4th card revealed.
##   • RIVER: 5th card revealed.
##
## Call [method set_cards] with the full community list (1..5 entries)
## and the row updates — anything past the list size hides its slot.
@tool
class_name CommunityCards
extends Node2D


const CARD_SCENE : PackedScene = preload("res://puzzles/poker/card_sprite.tscn")

## Pixel pitch between card centers — slightly wider than a card so the
## row reads as separated cards, not a stacked deck.
@export var card_spacing : float = 56.0
## Where new community cards slide IN from, in this node's local coords.
## Default sits BELOW this row, at the felt's geometric center — matches
## the scene's table-center dealer position (so flop/turn/river cards
## slide UP and OUT of the dealer hub onto the row).
@export var deck_position : Vector2 = Vector2(0.0, 40.0)
## Per-card slide duration during a phase reveal.
@export var deal_duration : float = 0.35
## Stagger between consecutive cards in the same phase (e.g. the flop's 3).
@export var deal_stagger : float = 0.13

var _slots : Array[CardSprite] = []
var _slot_home : Array[Vector2] = []
## How many slots are currently revealed. Increments per phase; reset by [method clear].
var _revealed_count : int = 0


func _ready() -> void:

	if _slots.is_empty():
		_build_slots()


# Reveal the cards in `cards` (size 1..5). Cards past the previously-
# revealed count slide in from [member deck_position] with a stagger.
# Returns the master Tween for the new animations (null if nothing new
# to animate — caller can safely just ignore the return).
func set_cards(cards: Array[Card]) -> Tween:

	if _slots.is_empty():
		_build_slots()
	var n : int = mini(cards.size(), _slots.size())
	var newly_revealed : Array[int] = []
	for i in n:
		var slot : CardSprite = _slots[i]
		slot.set_card(cards[i], true)
		if i < _revealed_count:
			# Already on the table — make sure it's at its home position.
			slot.position = _slot_home[i]
			slot.visible = true
		else:
			# Brand new — drop it at the deck, mark for tween-in.
			slot.position = deck_position
			slot.visible = true
			newly_revealed.append(i)
	for i in range(n, _slots.size()):
		_slots[i].visible = false
	_revealed_count = n
	if newly_revealed.is_empty():
		return null
	var tw : Tween = create_tween().set_parallel(true)
	for k in newly_revealed.size():
		var slot_idx : int = newly_revealed[k]
		var delay : float = k * deal_stagger
		tw.tween_property(_slots[slot_idx], "position", _slot_home[slot_idx], deal_duration) \
			.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tw


# Hide every slot — used at the start of a hand.
func clear() -> void:

	for slot in _slots:
		slot.visible = false
		slot.highlighted = false
		slot.dimmed = false
	# Snap any slots back to their resting position in case clear() runs
	# while a previous tween was still in flight.
	for i in _slots.size():
		_slots[i].position = _slot_home[i]
	_revealed_count = 0


## At showdown, highlight community cards that are part of the winning
## hand; dim the others. Pass an empty array to reset to normal display.
func mark_showdown(winning_cards: Array[Card]) -> void:

	for slot in _slots:
		if slot.card == null or not slot.visible:
			continue
		if winning_cards.is_empty():
			slot.highlighted = false
			slot.dimmed = false
			continue
		var in_winning : bool = false
		for wc in winning_cards:
			if wc.equals(slot.card):
				in_winning = true
				break
		slot.highlighted = in_winning
		slot.dimmed = not in_winning


func _build_slots() -> void:

	_slots.clear()
	_slot_home.clear()
	# Centered: 5 cards spanning ±2 card_spacing from origin.
	for i in 5:
		var slot : CardSprite = CARD_SCENE.instantiate()
		add_child(slot)
		var home : Vector2 = Vector2((i - 2) * card_spacing, 0.0)
		slot.position = home
		slot.visible = false
		_slots.append(slot)
		_slot_home.append(home)
