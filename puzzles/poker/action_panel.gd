## The player's action UI. Sits in the bottom-right of the table screen
## and offers the four context-aware actions (Fold, Check/Call,
## Bet/Raise, All-In) plus a slider for bet sizing.
##
## The scene controller calls [method refresh] with the current
## [PokerBoard] and acting player to update button labels, enable/disable
## states, and the slider range. When the player clicks a button the
## panel emits [signal action_chosen] with the [enum PokerBoard.Action]
## and the chip amount the controller should pass to
## [method PokerBoard.apply_action].
##
## When it's not the human's turn, the controller hides this panel
## entirely so AI play happens without UI clutter.
class_name PokerActionPanel
extends Control


signal action_chosen(action: PokerBoard.Action, amount: int)


@onready var _fold_btn : Button = %FoldButton
@onready var _check_call_btn : Button = %CheckCallButton
@onready var _bet_raise_btn : Button = %BetRaiseButton
@onready var _all_in_btn : Button = %AllInButton
@onready var _bet_slider : HSlider = %BetSlider
@onready var _bet_label : Label = %BetAmountLabel
@onready var _high_bet_label : Label = %HighBetLabel

# Cached state from the last refresh() so the slider's `value_changed`
# can update labels without re-resolving via the board.
var _is_raise_context : bool = false
var _bet_min : int = 0
var _bet_max : int = 0
## Whether the current context is a free Check (vs a Call). Cached from
## refresh() so [method _on_check_call] branches on game state, not on
## the button's display text (which a future relabel/locale would break).
var _can_check : bool = false


func _ready() -> void:

	_fold_btn.pressed.connect(_on_fold)
	_check_call_btn.pressed.connect(_on_check_call)
	_bet_raise_btn.pressed.connect(_on_bet_raise)
	_all_in_btn.pressed.connect(_on_all_in)
	_bet_slider.value_changed.connect(_on_slider_changed)


## Wire all the buttons / slider to the current board + acting player.
## Call once at every turn change while it's the human's turn.
func refresh(board: PokerBoard, player: PokerPlayer) -> void:

	var to_call : int = board.get_amount_to_call()
	var can_check : bool = board.can_check()
	var min_raise_to : int = board.get_min_raise_to()
	var max_raise_to : int = board.get_max_raise_to()   # structure-aware cap (Fixed/Pot/No Limit)

	# Fold — always legal unless the player can simply check for free,
	# but enabling it anyway is harmless and matches YPP's UX.
	_fold_btn.disabled = false
	_fold_btn.text = "Fold"

	# Check vs Call.
	_can_check = can_check
	if can_check:
		_check_call_btn.text = "Check"
		_check_call_btn.disabled = false
	else:
		var afford_call : int = mini(to_call, player.chips)
		_check_call_btn.text = "Call %d" % afford_call
		_check_call_btn.disabled = player.chips == 0

	# Bet vs Raise — bounds come from the board structure-aware: FIXED LIMIT collapses min==max to a
	# single fixed size (the slider locks), POT LIMIT caps at the pot, NO LIMIT goes to the stack.
	# board.can_raise() also enforces the Fixed-Limit per-street raise cap. If the player can't cover
	# the minimum (or is capped), the button disables and All-In handles any raise-for-less.
	_is_raise_context = board.current_bet > 0
	var raise_floor : int = min_raise_to
	# A raise must strictly exceed the standing bet. If the structured raise-to is stack-capped at or
	# below the current bet (a short stack), there's no legal raise — only All-In makes the shove.
	var can_structured_raise : bool = board.current_bet == 0 or min_raise_to > board.current_bet
	if board.can_raise() and can_structured_raise and max_raise_to >= raise_floor:
		_bet_min = raise_floor
		_bet_max = max_raise_to
		_bet_slider.min_value = _bet_min
		_bet_slider.max_value = maxi(_bet_max, _bet_min)
		_bet_slider.step = 1
		_bet_slider.value = _bet_min
		_bet_slider.editable = _bet_max > _bet_min
		_bet_raise_btn.text = ("Raise to %d" if _is_raise_context else "Bet %d") % int(_bet_slider.value)
		_bet_raise_btn.disabled = false
	else:
		_bet_min = 0
		_bet_max = 0
		_bet_slider.min_value = 0
		_bet_slider.max_value = 1
		_bet_slider.value = 0
		_bet_slider.editable = false
		_bet_raise_btn.text = "Raise" if _is_raise_context else "Bet"
		_bet_raise_btn.disabled = true

	# All-In — legal as long as the player has chips.
	_all_in_btn.disabled = player.chips == 0
	_all_in_btn.text = "All-In (%d)" % (player.chips + player.current_bet)

	# High-bet header line (matches the YPP-style "High Bet: N" indicator).
	_high_bet_label.text = "High Bet: %d" % board.current_bet
	_update_bet_label()


func _update_bet_label() -> void:

	_bet_label.text = "%d" % int(_bet_slider.value)
	if _bet_max > _bet_min:
		_bet_raise_btn.text = ("Raise to %d" if _is_raise_context else "Bet %d") % int(_bet_slider.value)


func _on_slider_changed(_v: float) -> void:

	_update_bet_label()


func _on_fold() -> void:

	action_chosen.emit(PokerBoard.Action.FOLD, 0)


func _on_check_call() -> void:

	# Branch on the cached game state (not the button text) — Check has no
	# amount, Call deducts whatever's needed (board handles "all-in for less").
	if _can_check:
		action_chosen.emit(PokerBoard.Action.CHECK, 0)
	else:
		action_chosen.emit(PokerBoard.Action.CALL, 0)


func _on_bet_raise() -> void:

	var amount : int = int(_bet_slider.value)
	var action : PokerBoard.Action = (
		PokerBoard.Action.RAISE if _is_raise_context else PokerBoard.Action.BET
	)
	action_chosen.emit(action, amount)


func _on_all_in() -> void:

	action_chosen.emit(PokerBoard.Action.ALL_IN, 0)
