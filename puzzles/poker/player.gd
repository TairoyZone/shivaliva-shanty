## A single seat at the poker table. Holds chips, hole cards, and the
## per-hand / per-round flags the [PokerBoard] state machine consults
## while resolving betting action.
##
## Two layers of state:
##   • Per-hand (cleared on every new deal): hole_cards, folded, all_in,
##     total_bet_in_hand — used for the side-pot calculation at showdown.
##   • Per-round (cleared between preflop/flop/turn/river): current_bet,
##     has_acted_this_round — used to decide when a betting round ends.
class_name PokerPlayer
extends RefCounted


var player_name : String = ""
var chips : int = 0
var hole_cards : Array[Card] = []
## Identity tint applied to the seat's portrait sprite (cosmetic only).
var portrait_color : Color = Color(0.95, 0.74, 0.28)
## True for the seated human; false for AI opponents.
var is_human : bool = false
## [NpcPersonality] resource driving the AI's decisions for this seat.
## Human players leave this null. The AI reads VPIP, PFR, aggression,
## bluff_rate, and patience from here so the same NPC plays consistently
## across mini-games.
var personality : NpcPersonality = null

# --- Per-hand state -----------------------------------------------------
## Cumulative chips this player has contributed to the pot during the
## current hand. Used by [PokerPot] to split into side pots when all-ins
## create different stake levels.
var total_bet_in_hand : int = 0
var folded : bool = false
var all_in : bool = false

# --- Per-betting-round state -------------------------------------------
## Chips the player has put in during the current betting round
## (preflop / flop / turn / river). Reset each round.
var current_bet : int = 0
## True once the player has voluntarily acted in this round (call, raise,
## check, or fold). The board uses this to know when the action has
## completed a full circle.
var has_acted_this_round : bool = false


func _init(p_name: String = "", p_chips: int = 0, p_human: bool = false) -> void:

	player_name = p_name
	chips = p_chips
	is_human = p_human


## Wipe per-hand state — called by the board at the start of every new deal.
func reset_for_new_hand() -> void:

	hole_cards.clear()
	total_bet_in_hand = 0
	folded = false
	all_in = false
	current_bet = 0
	has_acted_this_round = false


## Wipe per-round state — called when the board moves between betting
## phases (preflop → flop, flop → turn, etc).
func reset_for_new_round() -> void:

	current_bet = 0
	has_acted_this_round = false


## Move `amount` chips from the stack into the current bet. If the
## player can't cover, takes whatever's left and flips [member all_in].
## Returns the amount actually staked.
func stake(amount: int) -> int:

	var taken : int = mini(amount, chips)
	chips -= taken
	current_bet += taken
	total_bet_in_hand += taken
	if chips == 0:
		all_in = true
	return taken


## Add chips to the stack (used when awarding pots at showdown).
func receive(amount: int) -> void:

	chips += amount


## Can this player still take a voluntary action this round?
func can_act() -> bool:

	return not folded and not all_in
