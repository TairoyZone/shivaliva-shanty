## The playable Hold 'em Poker scene. Inherits ESC-return + HUD hiding +
## click-dismiss from [PuzzleScene]; owns the [PokerBoard] state
## machine plus the four [PokerSeat]s, the central [PotDisplay], the
## row of [CommunityCards], and the bottom-right [PokerActionPanel].
##
## Flow:
##   • _ready() seats 4 players (you + 3 NPCs), connects every board
##     signal to a UI updater, and deals the first hand.
##   • On AI turns the scene waits AI_THINK_TIME then asks [PokerAI]
##     for a decision and feeds it back into the board.
##   • On the human's turn the action panel becomes visible and
##     captures the player's choice via [signal PokerActionPanel.action_chosen].
##   • On hand_complete the opponents' hole cards flip face-up, a
##     status line announces winners, and a "Next Hand" button lets
##     the player deal another. ESC returns to the tavern.
extends PuzzleScene


const SEAT_SCENE : PackedScene = preload("res://puzzles/poker/seat.tscn")
const CARD_SCENE : PackedScene = preload("res://puzzles/poker/card_sprite.tscn")

# Where cards visually originate during a deal — the geometric center
# of the felt, in world coords. Both hole cards and community cards
# slide outward from this spot so the dealer "lives" at table center.
const DECK_POSITION : Vector2 = Vector2(640.0, 360.0)
## Delay between consecutive hole cards during the deal.
const HOLE_DEAL_STAGGER : float = 0.07
## How long one hole card takes to slide from deck to its seat.
const HOLE_DEAL_DURATION : float = 0.38

const STARTING_CHIPS : int = 1000
## Chip:gold conversion rate used on exit. The matching buy-in
## (deducted by [PokerTable.play_cost]) should be `STARTING_CHIPS /
## CHIPS_PER_GOLD` so that leaving with the same stack you sat
## down with is a break-even — not a free profit and not a loss.
const CHIPS_PER_GOLD : int = 10
## Seconds the AI "thinks" before acting. Just dramatic pacing.
const AI_THINK_TIME : float = 1.1
## Seconds the camera holds on the showdown (cards revealed + winner
## highlights + chip toasts) before auto-advancing to the next hand.
## Pressing "Next Hand" skips the rest of the wait.
const BETWEEN_HAND_DELAY : float = 10.0
## Beat between community streets (flop → turn → river) when an all-in
## run-out reveals more than one street in a single board emission. Keeps
## the showdown board from popping all five cards at once.
const STREET_REVEAL_GAP : float = 0.55
## After the showdown hands flip face-up, hold this long before the Next
## Hand panel slides in — long enough to actually read who won with what.
const SHOWDOWN_HOLD : float = 1.4
## Milliseconds after the ResultPanel becomes visible during which
## clicks on its Next-Hand button are IGNORED. ActionPanel and
## ResultPanel share the same screen rect, so a click on an action
## button that fires fast-forward-to-showdown can accidentally route
## its release event onto the freshly-shown ResultButton. This guard
## absorbs that phantom click without interfering with intentional
## post-grace clicks.
const RESULT_BUTTON_CLICK_GRACE_MS : int = 400
## Vertical pixels a winnings toast rises before fading out. Kept small
## so the top seat's toast doesn't fly off-screen.
const TOAST_RISE : float = 36.0
## Total seconds the toast is on-screen.
const TOAST_LIFETIME : float = 2.0

# Where each seat lives on screen. Index 0 = the human; 1-3 = NPCs
# arranged counter-clockwise around the table from the human's left.
const SEAT_POSITIONS : Array[Vector2] = [
	Vector2(640, 560),   # You — bottom center
	Vector2(220, 380),   # AI seat 1 — left
	Vector2(640, 140),   # AI seat 2 — top (raised so cards clear the community row)
	Vector2(1060, 380),  # AI seat 3 — right
]

# The human seat is fixed (always seat 0). The three AI seats are
# picked at session start from [NpcRegistry] — every visit to the
# Inn's poker table draws three random Cradle Rock NPCs from the
# eight-member cast, and each plays per their [NpcPersonality]
# resource (aggression, VPIP, PFR, etc).
const HUMAN_SEAT_COLOR : Color = Color(0.95, 0.78, 0.34, 1.0)


@onready var _board : PokerBoard = $Board
@onready var _community : CommunityCards = $Table/Community
@onready var _pot : PotDisplay = $Table/Pot
@onready var _action_panel : PokerActionPanel = $UI/ActionPanel
@onready var _result_panel : Control = %ResultPanel
@onready var _result_label : Label = %ResultLabel
@onready var _result_btn : Button = %ResultButton

var _seats : Array[PokerSeat] = []
## True while the showdown sequence (cards revealed, toasts rising,
## winner halos showing) is on-screen and the player hasn't yet
## advanced. Used so the auto-advance timer AND the manual Next-Hand
## button can't double-fire.
var _hand_pending : bool = false
## When the ResultPanel last became visible (Time.get_ticks_msec()).
## Compared against [constant RESULT_BUTTON_CLICK_GRACE_MS] inside
## [method _on_next_hand_pressed] to drop phantom click-through events
## from the just-hidden ActionPanel.
var _result_panel_shown_at_ms : int = 0

## True while a card-dealing tween is on-screen. The turn-changed
## handler awaits [signal animation_done] before showing the action
## panel or kicking off an AI think — so the player isn't asked to
## act mid-deal.
var _animating : bool = false
signal animation_done

## Set from the lobby on entry. A FREE table plays for rapport only — no
## buy-in was charged and chips are NOT cashed out to gold on exit.
var _free_table : bool = false
## The opponents the lobby seated (loaded from their profile paths). Empty
## ⇒ launched without a lobby, so [method _seat_players] rolls a fresh set.
var _lobby_opponents : Array[NpcPersonality] = []


func _ready() -> void:

	super._ready()
	set_help_text("Hold 'em Poker — Texas Hold'em\n\n"
		+ "• Click action buttons (Fold / Check / Call / Bet / Raise / All-In)\n"
		+ "• Slide the bet amount on raises\n"
		+ "• Best 5-card hand from your 2 hole cards + 5 community cards wins")
	var setup : Dictionary = PlayerState.consume_lobby_setup()
	_free_table = bool(setup.get("free", false))
	_lobby_opponents = LobbyModal.profiles_from_paths(setup.get("seated_paths", []))
	_seat_players()
	_build_seat_widgets()
	_wire_signals()
	_action_panel.visible = false
	_result_panel.visible = false
	_board.start_new_hand()


# Brass-rim green felt covering the table area. Drawn here so we don't
# need an extra felt-drawer node.
func _draw() -> void:

	var center : Vector2 = Vector2(640.0, 360.0)
	var size : Vector2 = Vector2(1120.0, 560.0)
	var outer : Rect2 = Rect2(center - size * 0.5, size)
	# Walnut frame.
	draw_rect(outer, Color(0.30, 0.20, 0.10, 1.0), true)
	# Brass inlay between frame and felt.
	var brass_inset : Rect2 = outer.grow(-6.0)
	draw_rect(brass_inset, Color(0.78, 0.58, 0.24, 1.0), true)
	# Green felt interior.
	var felt : Rect2 = outer.grow(-14.0)
	draw_rect(felt, Color(0.14, 0.36, 0.22, 1.0), true)
	# Crisp outer outline.
	draw_rect(outer, Color(0.18, 0.10, 0.05, 1.0), false, 2.0)


# --- Setup -------------------------------------------------------------

func _seat_players() -> void:

	# Seat 0 — the human.
	var human : PokerPlayer = PokerPlayer.new("You", STARTING_CHIPS, true)
	human.portrait_color = HUMAN_SEAT_COLOR
	_board.add_player(human)
	# Seats 1-3 — the NPCs the lobby seated (affinity-weighted), each
	# carrying their personality resource so the AI plays per their
	# identity. Fallback to a fresh roll if launched without a lobby.
	var opponents : Array[NpcPersonality] = _lobby_opponents
	if opponents.is_empty():
		opponents = NpcRegistry.pick_for_lobby(3, PlayerState.get_affinity)
	for profile in opponents:
		var ai : PokerPlayer = PokerPlayer.new(profile.npc_name, STARTING_CHIPS, false)
		ai.portrait_color = profile.portrait_color
		ai.personality = profile
		_board.add_player(ai)


func _build_seat_widgets() -> void:

	for i in _board.players.size():
		var seat : PokerSeat = SEAT_SCENE.instantiate()
		$Table.add_child(seat)
		seat.position = SEAT_POSITIONS[i]
		seat.bind_to(_board.players[i])
		seat.hole_cards_face_up = _board.players[i].is_human
		_seats.append(seat)


func _wire_signals() -> void:

	_board.phase_changed.connect(_on_phase_changed)
	_board.hole_cards_dealt.connect(_on_hole_cards_dealt)
	_board.community_dealt.connect(_on_community_dealt)
	_board.player_acted.connect(_on_player_acted)
	_board.blinds_posted.connect(_on_blinds_posted)
	_board.pot_changed.connect(_on_pot_changed)
	_board.turn_changed.connect(_on_turn_changed)
	_board.hand_complete.connect(_on_hand_complete)
	_action_panel.action_chosen.connect(_on_action_chosen)
	_result_btn.pressed.connect(_on_next_hand_pressed)


# --- Board signal handlers --------------------------------------------

func _on_phase_changed(phase: PokerBoard.Phase) -> void:

	# Phase is visually obvious from the number of community cards
	# revealed. PREFLOP wipes the community row; nothing else to do.
	if phase == PokerBoard.Phase.PREFLOP:
		_community.clear()
	# On each new betting round (FLOP/TURN/RIVER), every player's
	# current_bet has been reset to 0 by the board — rebind so the seat
	# panels reflect that. Last-action labels intentionally persist
	# across rounds: the player wants to see what the AI just did even
	# if a round flipped right after, and each label is overwritten the
	# moment that player acts again.
	if phase in [PokerBoard.Phase.FLOP, PokerBoard.Phase.TURN, PokerBoard.Phase.RIVER]:
		for i in _seats.size():
			_seats[i].bind_to(_board.players[i])


func _on_hole_cards_dealt() -> void:

	# Configure non-card state first: portrait, name, chips, dealer
	# button — but DON'T flash the hole cards yet; the deal animation
	# below will spawn temp sprites that slide from the deck to each
	# seat, and only then do we restore the real hole-card display.
	for i in _seats.size():
		# A player who busted out (0 chips, so not dealt in this hand) leaves
		# the table — hide their seat. (An all-in player has 0 chips but DOES
		# hold cards, so they stay.)
		var dealt_in : bool = not _board.players[i].hole_cards.is_empty()
		_seats[i].visible = dealt_in
		if not dealt_in:
			continue
		_seats[i].hole_cards_face_up = _board.players[i].is_human
		_seats[i].is_dealer = (i == _board.dealer_button)
		_seats[i].bind_to(_board.players[i], false)
		_seats[i].hole_cards = []
		_seats[i].hand_label = ""
		_seats[i].last_action_label = ""
	await _animate_deal_hole_cards()
	if not is_instance_valid(self):
		return  # left the table mid-deal — scene is freed
	# Show the player's starting-hand readout the moment the cards land.
	_refresh_human_hand_label()


# Slides 8 temp cards from [const DECK_POSITION] to each seat's two
# hole-card slots, dealing alternately around the table starting left
# of the dealer button (2 rounds). After the last card lands, each
# seat takes over rendering its real hole cards.
func _animate_deal_hole_cards() -> void:

	_animating = true
	var n : int = _seats.size()
	var start_idx : int = (_board.dealer_button + 1) % n
	# Build the alternating deal order: 2 rounds of cards, one per
	# seat. Skip seats that the board didn't deal to this hand
	# (eliminated players whose chips reached 0 last hand) — their
	# `hole_cards` is empty, and indexing it would crash.
	var deal_order : Array[Dictionary] = []
	for round_num in 2:
		for offset in n:
			var seat_idx : int = (start_idx + offset) % n
			if _board.players[seat_idx].hole_cards.size() <= round_num:
				continue
			deal_order.append({
				"seat_idx": seat_idx,
				"card_slot": round_num,
			})

	var temps : Array[CardSprite] = []
	var master_tween : Tween = create_tween().set_parallel(true)
	for i in deal_order.size():
		var info : Dictionary = deal_order[i]
		var seat_idx : int = info["seat_idx"]
		var card_slot : int = info["card_slot"]
		var card : Card = _board.players[seat_idx].hole_cards[card_slot]

		var temp : CardSprite = CARD_SCENE.instantiate()
		$Table.add_child(temp)
		temp.position = DECK_POSITION
		temp.face_up = false
		temp.set_card(card, false)
		temps.append(temp)

		var dest : Vector2 = _seats[seat_idx].hole_card_world_position(card_slot)
		var delay : float = i * HOLE_DEAL_STAGGER
		master_tween.tween_property(temp, "position", dest, HOLE_DEAL_DURATION) \
			.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await master_tween.finished
	if not is_instance_valid(self):
		return  # left the table mid-deal — scene is freed

	# Hand off to the seats first (so the slot positions are filled
	# in the same frame the temps disappear — no visual gap), then
	# free the temps.
	for i in _seats.size():
		_seats[i].hole_cards = _board.players[i].hole_cards
	for temp in temps:
		temp.queue_free()

	_animating = false
	animation_done.emit()


func _on_community_dealt(all_community: Array[Card]) -> void:

	# Reveal the board one poker street at a time — flop (3), turn (4),
	# river (5) — with a beat between streets. A normal hand brings a single
	# new street per call, so this resolves to one stage. But an all-in
	# run-out fast-forwards the WHOLE remaining board in one emission;
	# staging it here keeps that reveal paced instead of popping every card
	# at once (and _on_hand_complete waits on `animation_done` so the result
	# panel can't jump the gun mid-reveal).
	_animating = true
	var first_stage : bool = true
	for n in [3, 4, 5]:
		if all_community.size() < n:
			break
		# Beat between streets, taken BEFORE revealing the next one. This order
		# is load-bearing: a tween started before a longer `await` finishes
		# DURING that wait, so a subsequent `await tw.finished` would block on a
		# signal that already fired — hanging the run-out on the turn card. We
		# therefore wait first, then start the reveal we actually await. (Single-
		# street hands never hit this branch — first_stage stays true.)
		if not first_stage:
			await get_tree().create_timer(STREET_REVEAL_GAP).timeout
			if not is_instance_valid(self):
				return  # left the table mid-reveal — scene is freed
		var subset : Array[Card] = all_community.slice(0, n)
		var tw : Tween = _community.set_cards(subset)
		if tw == null:
			continue  # nothing new at this stage — already on the felt
		await tw.finished
		if not is_instance_valid(self):
			return  # left the table mid-reveal — scene is freed
		first_stage = false
		# Update the human's best-hand readout (Pair of 7s, Flush, …) as
		# each street lands.
		_refresh_human_hand_label()
	_animating = false
	animation_done.emit()
	_refresh_human_hand_label()


# Compute the human's best 5-card hand from their hole cards + visible
# community and write it into their seat panel. Cleared between hands
# in [method _advance_or_leave].
func _refresh_human_hand_label() -> void:

	if _seats.is_empty() or _board == null:
		return
	var human : PokerPlayer = _board.players[0]
	var all_cards : Array[Card] = []
	all_cards.append_array(human.hole_cards)
	all_cards.append_array(_board.community_cards)
	if all_cards.size() < 5:
		# Not a 5-card hand yet — describe the 2 hole cards HONESTLY so the
		# player can read their start (never a misleading "Pair").
		_seats[0].hand_label = _preflop_label(human.hole_cards)
		return
	var eval : Dictionary = HandEval.best_of(all_cards)
	_seats[0].hand_label = HandEval.short_describe(eval)


## Friendly word per card rank (1 = Ace … 13 = King) for the preflop readout.
const PREFLOP_RANK_WORDS : Array[String] = [
	"", "Ace", "Two", "Three", "Four", "Five", "Six", "Seven",
	"Eight", "Nine", "Ten", "Jack", "Queen", "King",
]


# An honest description of the 2 hole cards preflop: a pocket pair ("Pocket
# Eights"), else the ranks high-low with a suited flag ("Ace-King suited",
# "Queen-Seven"). NOT a 5-card rank — there's no made hand yet.
func _preflop_label(cards: Array[Card]) -> String:

	if cards.size() < 2:
		return ""
	var a : Card = cards[0]
	var b : Card = cards[1]
	if a.rank == b.rank:
		return "Pocket %s" % _rank_plural(a.rank)
	# Ace (rank 1) plays HIGH preflop.
	var va : int = 14 if a.rank == Card.ACE else a.rank
	var vb : int = 14 if b.rank == Card.ACE else b.rank
	var hi : Card = a if va >= vb else b
	var lo : Card = b if va >= vb else a
	var suited : String = "  suited" if a.suit == b.suit else ""
	return "%s-%s%s" % [PREFLOP_RANK_WORDS[hi.rank], PREFLOP_RANK_WORDS[lo.rank], suited]


func _rank_plural(rank: int) -> String:

	var word : String = PREFLOP_RANK_WORDS[rank]
	return word + ("es" if word == "Six" else "s")


func _on_player_acted(player_index: int, action: PokerBoard.Action, amount: int) -> void:

	# Re-sync this seat's chip / bet / fold display, then pin the action
	# label into the panel so it persists for the rest of the round
	# (cleared on phase change). The chip-fly handles the "something just
	# happened" feedback the toast used to do.
	_seats[player_index].bind_to(_board.players[player_index])
	_apply_action_label(player_index, action, amount)
	# Any action that put chips into play gets a fly-to-pot animation.
	if amount > 0:
		_spawn_chip_fly_to_pot(player_index, amount)


# Write "Fold" / "Call 20" / "Raise to 80" / "All-In 240" etc. into the
# acting seat's panel, with a color chosen per action so it reads at a
# glance: fold = dim grey, bet/raise = brass, all-in = red, the rest =
# default brass-bright. For RAISE / ALL-IN the running total comes from
# the board (post-action [member PokerPlayer.current_bet]) so the label
# reads like the action panel button ("Raise to 80").
func _apply_action_label(player_index: int, action: PokerBoard.Action, amount: int) -> void:

	var p : PokerPlayer = _board.players[player_index]
	var text : String = ""
	var color : Color = Color(1.0, 0.86, 0.42, 1.0)  # brass default
	match action:
		PokerBoard.Action.FOLD:
			text = "Fold"
			color = Color(0.78, 0.78, 0.82, 1.0)
		PokerBoard.Action.CHECK:
			text = "Check"
		PokerBoard.Action.CALL:
			text = "Call %d" % amount if amount > 0 else "Call"
		PokerBoard.Action.BET:
			text = "Bet %d" % amount
		PokerBoard.Action.RAISE:
			text = "Raise to %d" % p.current_bet
		PokerBoard.Action.ALL_IN:
			text = "All-In %d" % p.current_bet if p.current_bet > 0 else "All-In"
			color = Color(1.0, 0.55, 0.55, 1.0)
	_seats[player_index].last_action_color = color
	_seats[player_index].last_action_label = text


# Blinds are auto-staked at the start of the hand — they don't pass
# through [signal player_acted], so the board emits a dedicated signal
# for them. Wait out the hole-card deal first so the chip flies don't
# fight the card sprites for the player's eye, then write the blind
# into the seat panel (so it reads "Small Blind 5" / "Big Blind 10"
# until that player makes a voluntary action and overwrites it).
func _on_blinds_posted(sb_index: int, sb_amount: int, bb_index: int, bb_amount: int) -> void:

	if _animating:
		await animation_done
		if not is_instance_valid(self):
			return  # left the table mid-deal — scene is freed
	var brass : Color = Color(1.0, 0.86, 0.42, 1.0)
	_seats[sb_index].bind_to(_board.players[sb_index])
	_seats[sb_index].last_action_color = brass
	_seats[sb_index].last_action_label = "Small Blind %d" % sb_amount
	_seats[bb_index].bind_to(_board.players[bb_index])
	_seats[bb_index].last_action_color = brass
	_seats[bb_index].last_action_label = "Big Blind %d" % bb_amount
	_spawn_chip_fly_to_pot(sb_index, sb_amount)
	_spawn_chip_fly_to_pot(bb_index, bb_amount)


func _on_pot_changed(total: int) -> void:

	_pot.amount = total


func _on_turn_changed(player_index: int) -> void:

	# Highlight only the active seat. Safe to do immediately — it's
	# just a border swap.
	for i in _seats.size():
		_seats[i].is_active = (i == player_index)

	# Don't surface the action UI or fire AI logic until any in-flight
	# deal animation has finished. Otherwise the player would be asked
	# to act mid-deal and an AI might bet before the flop visually appears.
	if _animating:
		await animation_done

	# State may have moved while we were awaiting — bail if it has (or the
	# whole table scene was freed because the player left mid-await).
	if not is_instance_valid(self):
		return
	if _board.phase == PokerBoard.Phase.BETWEEN_HANDS:
		return
	if _board.current_player_index != player_index:
		return

	var player : PokerPlayer = _board.players[player_index]
	if player.is_human:
		_action_panel.refresh(_board, player)
		_action_panel.visible = true
		return
	_action_panel.visible = false
	# AI think pause, then act.
	if AI_THINK_TIME > 0.0:
		await get_tree().create_timer(AI_THINK_TIME).timeout
	if not is_instance_valid(self):
		return  # left the table during the AI's think pause — scene is freed
	if _board.phase == PokerBoard.Phase.BETWEEN_HANDS:
		return
	if _board.current_player_index != player_index:
		return
	var decision : Dictionary = PokerAI.decide(_board, player)
	_board.apply_action(decision["action"], decision["amount"])


func _on_hand_complete(awards: Array) -> void:

	_action_panel.visible = false
	# Wait out any in-flight board reveal first. An all-in run-out stages the
	# flop/turn/river through _on_community_dealt; flipping hole cards or
	# raising the result panel mid-reveal is exactly what made all-in
	# showdowns "skip" before the player ever saw the board.
	if _animating:
		await animation_done
		if not is_instance_valid(self):
			return  # left the table mid-reveal — scene is freed
	# Reveal every non-folded player's hole cards so you can read the
	# showdown. Fold-out hands skip the reveal — only one player has
	# cards in play anyway.
	for i in _seats.size():
		if not _board.players[i].folded:
			_seats[i].hole_cards_face_up = true
		_seats[i].is_active = false
		_seats[i].bind_to(_board.players[i])

	# Evaluate each non-folded player's best 5-card hand so we can show
	# "Pair of Aces" etc. on the toast. (Skipped when nobody showed
	# down — fold-out gives no hand description.)
	var descriptions : Dictionary = {}
	if _board.community_cards.size() >= 3:
		for p in _board.players:
			if p.folded:
				continue
			var seven : Array[Card] = []
			seven.append_array(p.hole_cards)
			seven.append_array(_board.community_cards)
			if seven.size() >= 5:
				descriptions[p] = HandEval.describe(HandEval.best_of(seven))

	# A single hand can produce multiple pots (main + side pots from
	# all-in stack disparities, OR even just a fold-out with blinds —
	# SB-level and BB-level become separate rings). Aggregate winnings
	# per player across every pot so each winner gets exactly ONE toast
	# showing their total take.
	var totals : Dictionary = {}              # PokerPlayer → total chips
	var order : Array[PokerPlayer] = []       # preserve first-seen order
	for a in awards:
		var per : int = a["per_winner"]
		var remainder : int = a["remainder"]
		for i in a["winners"].size():
			var w : PokerPlayer = a["winners"][i]
			var won : int = per + (remainder if i == 0 else 0)
			if not (w in totals):
				totals[w] = 0
				order.append(w)
			totals[w] += won
	for w in order:
		var seat_idx : int = _board.players.find(w)
		if seat_idx < 0:
			continue
		_seats[seat_idx].is_winner = true
		_spawn_winnings_toast(seat_idx, totals[w])
		_spawn_chip_fly_pot_to_seat(seat_idx, totals[w])
	# Mark every non-folded, non-winner who put chips in this hand as a
	# loser — dim panel + "-N" toast — so the player can read at a
	# glance who got beaten at showdown. Folded seats already carry the
	# FOLDED overlay and a stronger grey tint, so they're skipped here.
	for i in _board.players.size():
		var p : PokerPlayer = _board.players[i]
		if p in totals:
			continue
		if p.folded:
			continue
		if p.total_bet_in_hand <= 0:
			continue
		_seats[i].is_loser = true
		_spawn_loss_toast(i, p.total_bet_in_hand)
	# Empty the pot display the moment the chips fly out — the board
	# doesn't emit pot_changed(0) until the next hand starts, but the
	# transfer should read as "chips leaving the center going TO the
	# winner" rather than "chips spawn from the center and the center
	# still holds the same total".
	if not totals.is_empty():
		_pot.amount = 0

	# Showdown highlight: collect every winner's best-5 cards, then
	# highlight those across community + non-folded seats. Cards that
	# weren't part of the winning hand dim back. Also write each
	# non-folded seat's hand description into its panel so the player
	# can read exactly what beat them. Skip this for fold-out hands —
	# no community cards / no real showdown.
	var did_showdown : bool = _board.community_cards.size() == 5 and _count_nonfolded() >= 2
	if did_showdown:
		var winning_cards : Array[Card] = []
		for w in order:
			var seven : Array[Card] = []
			seven.append_array(w.hole_cards)
			seven.append_array(_board.community_cards)
			var eval : Dictionary = HandEval.best_of(seven)
			for c in eval["cards"]:
				if not _card_already_in(c, winning_cards):
					winning_cards.append(c)
		_community.mark_showdown(winning_cards)
		for i in _seats.size():
			if _board.players[i].folded:
				continue
			_seats[i].mark_showdown(winning_cards)
			# Write the player's hand into their seat panel using the
			# showdown variant — includes kickers so the tiebreak is
			# readable ("Three Kings (A 5)" vs "Three Kings (A 9)" tells
			# you the 9 kicker won it).
			var seven : Array[Card] = []
			seven.append_array(_board.players[i].hole_cards)
			seven.append_array(_board.community_cards)
			if seven.size() >= 5:
				_seats[i].hand_label = HandEval.describe_showdown(HandEval.best_of(seven))

	# Populate the bottom-right result panel — same footprint as the
	# action panel during play — with the player's outcome and a Next
	# Hand / Leave button. Busted, won, or just a quiet loss each get a
	# different label color so the player can tell at a glance.
	var busted : bool = not _can_play_another_hand()
	var human : PokerPlayer = _board.players[0]
	var human_won : int = int(totals.get(human, 0))
	# "Busted" means no further hand is possible — but that splits two ways:
	# the human is broke (a real loss) OR the human cleaned everyone ELSE
	# out (a decisive win, common after a big all-in). Reading the same
	# "OUT OF CHIPS" for both made an all-in sweep look like a non-event.
	if busted and human.chips <= 0:
		_result_label.text = "OUT OF CHIPS"
		_result_label.modulate = Color(1.0, 0.55, 0.55, 1.0)
		_result_btn.text = "Leave the table"
	elif busted:
		_result_label.text = ("You cleaned out the table!  +%d" % human_won
			if human_won > 0 else "You cleaned out the table!")
		_result_label.modulate = Color(1.0, 0.88, 0.46, 1.0)
		_result_btn.text = "Cash out  ▸"
	elif human_won > 0:
		_result_label.text = "You won %d chips" % human_won
		_result_label.modulate = Color(1.0, 0.88, 0.46, 1.0)
		_result_btn.text = "Next Hand  ▸"
	elif human.total_bet_in_hand > 0:
		_result_label.text = "You lost %d chips" % human.total_bet_in_hand
		_result_label.modulate = Color(1.0, 0.55, 0.55, 1.0)
		_result_btn.text = "Next Hand  ▸"
	else:
		_result_label.text = "Hand complete"
		_result_label.modulate = Color(0.97, 0.87, 0.55, 1.0)
		_result_btn.text = "Next Hand  ▸"
	# On a real showdown, let the revealed hands + winner highlights breathe
	# before the Next Hand panel slides in over them.
	if did_showdown:
		await get_tree().create_timer(SHOWDOWN_HOLD).timeout
		if not is_instance_valid(self):
			return  # left the table during the showdown hold — scene is freed
	_result_panel.visible = true
	_result_panel_shown_at_ms = Time.get_ticks_msec()
	_hand_pending = true
	if busted:
		return  # no auto-advance — player must click out manually
	await get_tree().create_timer(BETWEEN_HAND_DELAY).timeout
	if not is_instance_valid(self):
		return  # left the table during the between-hand wait — scene is freed
	if _hand_pending:
		_advance_or_leave()


func _on_action_chosen(action: PokerBoard.Action, amount: int) -> void:

	_action_panel.visible = false
	var accepted : bool = _board.apply_action(action, amount)
	if not accepted:
		# Board rejected the action (e.g. raise below min). Re-surface
		# the panel so the player isn't stranded with no UI to act.
		var player : PokerPlayer = _board.get_current_player()
		if player != null and player.is_human:
			_action_panel.refresh(_board, player)
			_action_panel.visible = true


func _on_next_hand_pressed() -> void:

	# Drop phantom clicks landing immediately after the panel appears —
	# they're almost always click-through from the just-hidden action
	# button (same screen rect). Real "I want to skip the wait" clicks
	# arrive comfortably after this grace window.
	if Time.get_ticks_msec() - _result_panel_shown_at_ms < RESULT_BUTTON_CLICK_GRACE_MS:
		return
	# Skip the auto-advance timer.
	if _hand_pending:
		_advance_or_leave()


func _advance_or_leave() -> void:

	_hand_pending = false
	_result_panel.visible = false
	# Clear winner halos, loser dims, showdown card highlights, and hand
	# labels before the next deal.
	for seat in _seats:
		seat.is_winner = false
		seat.is_loser = false
		seat.mark_showdown([])
		seat.hand_label = ""
	_community.mark_showdown([])
	if not _can_play_another_hand():
		# Button click is itself the dismiss action — go straight back to
		# the launching scene rather than arming click-to-dismiss.
		_return_to_launching_scene()
		return
	_community.clear()
	for i in _seats.size():
		_seats[i].hole_cards_face_up = _board.players[i].is_human
	_board.start_new_hand()


# Returns the number of players still in the hand (not folded).
func _count_nonfolded() -> int:

	var n : int = 0
	for p in _board.players:
		if not p.folded:
			n += 1
	return n


# Cards equality is suit+rank, not reference — use [method Card.equals]
# to dedupe a list.
func _card_already_in(c: Card, list: Array[Card]) -> bool:

	for other in list:
		if other.equals(c):
			return true
	return false


# Rapport gained with each opponent for sharing the table this session,
# plus a bonus if the player walked away up.
const PLAY_AFFINITY : int = 1
const WINNING_SESSION_BONUS : int = 1

# Override the inherited "leave the puzzle" entry point so we cash the
# human player's remaining chips back into gold before the scene
# change. This runs for BOTH paths out of the table — the Leave/Next
# Hand button (via _advance_or_leave) and the ESC key (handled by
# PuzzleScene._unhandled_input).
func _return_to_launching_scene() -> void:

	_grant_opponent_affinity()
	_payout_chips()
	super._return_to_launching_scene()


# Credit rapport to every NPC the player sat with this session. Sharing
# a table builds a bit of rapport regardless of outcome; finishing the
# session up adds a little more (they respect a winner). Granted once
# on exit, not per hand, so it can't be farmed by playing single hands.
func _grant_opponent_affinity() -> void:

	if _board == null or _board.players.size() < 2:
		return
	var human : PokerPlayer = _board.players[0]
	var won_session : bool = human.chips > STARTING_CHIPS
	var gain : int = PLAY_AFFINITY + (WINNING_SESSION_BONUS if won_session else 0)
	for i in range(1, _board.players.size()):
		PlayerState.add_affinity(_board.players[i].player_name, gain)


# Convert the human seat's chip stack into gold at the configured
# ratio and credit PlayerState. Truncates (10 chips = 1 gold, 9
# chips = 0 gold) — small remainders are absorbed by the house.
func _payout_chips() -> void:

	# Free table — nothing was bought in, nothing cashes out.
	if _free_table:
		return
	if _board == null or _board.players.is_empty():
		return
	var human : PokerPlayer = _board.players[0]
	# Integer truncation is intentional — remainder under one
	# gold's worth of chips is house edge.
	@warning_ignore("integer_division")
	var gold : int = human.chips / CHIPS_PER_GOLD
	if gold > 0:
		award_winnings(gold)


# Spawn a small flock of chip sprites that arc from a seat into the
# center pot. Called for every voluntary stake (call, bet, raise,
# all-in) and for the auto-posted blinds. Chip count + color tier are
# derived from the amount so a tiny call shows 2 red chips and a fat
# raise shows 6 black chips. The chips are purely decorative — the
# logical pot total is already updated by [signal PokerBoard.pot_changed]
# in the same frame, so the visual lag is fine.
const CHIP_FLY_DURATION : float = 0.55
const CHIP_FLY_STAGGER : float = 0.05
const CHIP_FLY_JITTER : float = 14.0

func _spawn_chip_fly_to_pot(seat_index: int, amount: int) -> void:

	if seat_index < 0 or seat_index >= _seats.size():
		return
	_spawn_chip_fly(
		_seats[seat_index].position + Vector2(0.0, -10.0),
		_pot.position + Vector2(0.0, -6.0),
		amount)


# Mirror of [method _spawn_chip_fly_to_pot] — runs at hand_complete to
# show the pot emptying out to each winner. Same visual vocabulary so
# the player intuits "chips leaving the center went TO that seat".
func _spawn_chip_fly_pot_to_seat(seat_index: int, amount: int) -> void:

	if seat_index < 0 or seat_index >= _seats.size():
		return
	_spawn_chip_fly(
		_pot.position + Vector2(0.0, -6.0),
		_seats[seat_index].position + Vector2(0.0, -10.0),
		amount)


# Generic chip-flock animator. Spawns 2–6 small chip sprites that arc
# from [param from_pos] to [param to_pos] (Table-local coords) over
# ~CHIP_FLY_DURATION, with a tiny stagger and random jitter at both
# endpoints so the flock has body. Chip color tier comes from
# [param amount].
func _spawn_chip_fly(from_pos: Vector2, to_pos: Vector2, amount: int) -> void:

	if amount <= 0:
		return
	var color_key : String
	if amount < 25:
		color_key = "red"
	elif amount < 100:
		color_key = "blue"
	elif amount < 500:
		color_key = "green"
	else:
		color_key = "black"
	var atlas_coord : Vector2 = PotDisplay.CHIP_COORDS[color_key]
	var src : Rect2 = Rect2(atlas_coord, Vector2(PotDisplay.CHIP_CELL_W, PotDisplay.CHIP_CELL_H))
	@warning_ignore("integer_division")
	var chip_count : int = clampi(2 + amount / 50, 2, 6)
	var scale_factor : float = PotDisplay.CHIP_DISPLAY_W / PotDisplay.CHIP_CELL_W
	for i in chip_count:
		var chip : Sprite2D = Sprite2D.new()
		chip.texture = PotDisplay.CHIPS_TEX
		chip.region_enabled = true
		chip.region_rect = src
		chip.scale = Vector2(scale_factor, scale_factor)
		chip.position = from_pos + Vector2(
			randf_range(-6.0, 6.0),
			randf_range(-4.0, 4.0))
		chip.z_index = 5
		$Table.add_child(chip)
		var landing : Vector2 = to_pos + Vector2(
			randf_range(-CHIP_FLY_JITTER, CHIP_FLY_JITTER),
			randf_range(-CHIP_FLY_JITTER * 0.4, CHIP_FLY_JITTER * 0.4))
		var delay : float = i * CHIP_FLY_STAGGER
		var tw : Tween = create_tween()
		tw.tween_interval(delay)
		tw.tween_property(chip, "position", landing, CHIP_FLY_DURATION) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(chip.queue_free)


# Floating "+N chips" label above the winner's seat. Short and tight
# so it doesn't fly off-screen for the top seat — the full hand
# description ("Pair of Aces") lives in the seat panel itself.
func _spawn_winnings_toast(seat_index: int, amount: int) -> void:

	var seat : PokerSeat = _seats[seat_index]
	var player : PokerPlayer = _board.players[seat_index]
	var label : Label = Label.new()
	label.text = "+%d" % amount
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", player.portrait_color.lightened(0.30))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	label.add_theme_constant_override("outline_size", 5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(180.0, 50.0)
	# Start just above the seat panel and rise a short way — clamped
	# so even the top seat's toast stays on screen.
	var start_y : float = seat.position.y - 78.0
	# If the seat is near the top of the screen, clamp the start so the
	# toast doesn't go negative.
	var min_start_y : float = TOAST_RISE + label.size.y * 0.5 + 16.0
	start_y = maxf(start_y, min_start_y)
	label.position = Vector2(seat.position.x - label.size.x * 0.5, start_y - label.size.y * 0.5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(label)
	var tw : Tween = create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - TOAST_RISE, TOAST_LIFETIME) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, TOAST_LIFETIME * 0.45) \
		.set_delay(TOAST_LIFETIME * 0.55)
	tw.chain().tween_callback(label.queue_free)


# Mirror of [method _spawn_winnings_toast] for losers. Floats a "-N"
# above the seat in muted red so the loss reads as clearly as the win.
func _spawn_loss_toast(seat_index: int, amount: int) -> void:

	var seat : PokerSeat = _seats[seat_index]
	var label : Label = Label.new()
	label.text = "-%d" % amount
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	label.add_theme_constant_override("outline_size", 5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(160.0, 44.0)
	var start_y : float = seat.position.y - 78.0
	var min_start_y : float = TOAST_RISE + label.size.y * 0.5 + 16.0
	start_y = maxf(start_y, min_start_y)
	label.position = Vector2(seat.position.x - label.size.x * 0.5, start_y - label.size.y * 0.5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(label)
	var tw : Tween = create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - TOAST_RISE, TOAST_LIFETIME) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, TOAST_LIFETIME * 0.45) \
		.set_delay(TOAST_LIFETIME * 0.55)
	tw.chain().tween_callback(label.queue_free)


# --- Helpers -----------------------------------------------------------

func _can_play_another_hand() -> bool:

	# Need ≥ 2 players with chips, AND the human is one of them (we don't
	# auto-play AI-only hands).
	var human : PokerPlayer = _board.players[0]
	if human.chips <= 0:
		return false
	var seats_with_chips : int = 0
	for p in _board.players:
		if p.chips > 0:
			seats_with_chips += 1
	return seats_with_chips >= 2
