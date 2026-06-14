## The playable Hold 'em Poker scene. Inherits ESC-return + HUD hiding +
## click-dismiss from [PuzzleScene]; owns the [PokerBoard] state
## machine plus the 2..10 [PokerSeat]s (placed on a ring), the central
## [PotDisplay], the row of [CommunityCards], and the bottom-right
## [PokerActionPanel].
##
## Flow:
##   • _ready() reads the table [PokerConfig] (stake / structure / seats), seats you (index 0) +
##     up to 8 cast NPCs, then a "Buy into the game?" dialog takes your variable buy-in and deals
##     the first hand (a free table skips the dialog). Connects every board signal to a UI updater.
##   • On AI turns the scene waits AI_THINK_TIME then asks [PokerAI]
##     for a decision and feeds it back into the board.
##   • On the human's turn the action panel becomes visible and
##     captures the player's choice via [signal PokerActionPanel.action_chosen].
##   • On hand_complete the opponents' hole cards flip face-up, a
##     status line announces winners, and a "Next Hand" button lets
##     the player deal another. ESC returns to the tavern. Extends [VersusPuzzleScene] for the
##     situational-awareness hooks (own-cards-only _own_secret_view) + the talk-influence seam.
extends VersusPuzzleScene


const SEAT_SCENE : PackedScene = preload("res://puzzles/poker/seat.tscn")
const CARD_SCENE : PackedScene = preload("res://puzzles/poker/card_sprite.tscn")

# Where cards visually originate during a deal — the geometric center
# of the felt, in world coords. Both hole cards and community cards
# slide outward from this spot so the dealer "lives" at table center.
const DECK_POSITION : Vector2 = Vector2(640.0, 360.0)
## The oval table's centre + the seat ring (an ellipse on the rim). Every seat is placed symmetrically
## around this — seat 0 (you) at bottom-centre, the rest spaced evenly all the way around. See _seat_position.
const TABLE_CENTER : Vector2 = Vector2(640.0, 336.0)
const SEAT_RX : float = 488.0
const SEAT_RY : float = 226.0
## Delay between consecutive hole cards during the deal.
const HOLE_DEAL_STAGGER : float = 0.07
## How long one hole card takes to slide from deck to its seat.
const HOLE_DEAL_DURATION : float = 0.38

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

# The human seat is fixed at index 0 (bottom-centre). The other seats are filled by the cast the
# lobby seated — up to the table size (2..10), drawn from the eight-member Cradle Rock cast — each
# playing per their [NpcPersonality] (aggression, VPIP, PFR, …). Seat screen positions are generated
# in a ring by [method _seat_position] so any 2..10-seat table fits the felt.
const HUMAN_SEAT_COLOR : Color = Color(0.95, 0.78, 0.34, 1.0)


@onready var _board : PokerBoard = $Board
@onready var _community : CommunityCards = $Table/Community
@onready var _pot : PotDisplay = $Table/Pot
@onready var _action_panel : PokerActionPanel = $UI/ActionPanel
@onready var _result_panel : Control = %ResultPanel
@onready var _result_label : Label = %ResultLabel
@onready var _result_btn : Button = %ResultButton

var _seats : Array[PokerSeat] = []
## Rolling buffer of recent table EVENTS (raises, folds, all-ins, wins, busts) fed into the seated NPCs' live
## chat context (see [method npc_chat_context]) so they react to what just happened. Cleared each new hand.
var _chat_events : Array[String] = []
const CHAT_EVENTS_MAX : int = 6
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
## The table config from the browser: {structure, min_bet, seats, turn_time}. Defaults to a No-Limit
## lowest-stake table so a standalone launch still plays. See [PokerConfig].
var _config : Dictionary = PokerConfig.make_default()
## The human's chosen buy-in (gold) this session — charged on Buy-In; cash-out + mastery key off it.
var _human_buy_in : int = 0
## True once the player actually SAT (bought in, or a free table seated them). Guards the exit side
## effects (affinity + mastery) so cancelling the buy-in dialog can't farm rapport / record a score.
var _sat_down : bool = false

# --- In-scene seating: the YPP create → PICK A SEAT → INVITE flow ------------------------------------
## The table starts EMPTY; board players are added as they SIT (the human FIRST, on Sit Here + buy-in,
## so they're always board player 0; each guest on Invite). The board player index is the source of
## truth — these map it onto the felt's ring seats:
var _table_seats : int = 2                 # the table's capacity (open chairs)
var _display_of_player : Array[int] = []   # board player i sits at ring seat _display_of_player[i]
var _occupant : Array[int] = []            # ring seat k holds board player _occupant[k] (-1 = open)
var _human_seated : bool = false
var _seating : bool = true                 # true until Deal starts the first hand
var _between_hands : bool = false          # a hand just ended — open chairs are invite-able again
var _seat_layer : Node2D                   # holds the open-seat Sit Here / Invite + Deal buttons. A WORLD-space
                                           # child of $Table (not a CanvasLayer) so it ZOOMS + stays aligned with
                                           # the felt seats under the touch pinch-zoom (Troy 2026-06-13)
var _pending_seat : int = -1               # the seat being bought into (held across the buy-in dialog)
var _returning : bool = false              # leaving the table — pay out / record mastery ONCE


func _leave_at_top_left() -> bool:
	return true   # poker's chat bar owns the bottom-left, so the Leave button sits top-left here


## Pinch to zoom the felt/cards on a phone — the table reads small there. The $Table subtree (felt-drawn chrome,
## cards, pot, seated players AND the open-seat buttons) is world-space so it all zooms together; the betting
## controls + banner sit on the UI CanvasLayer, so they stay put. See [[touch-input-foundation]] (Troy 2026-06-13).
func _touch_pinch_zoom() -> bool:
	return true


func _ready() -> void:

	super._ready()
	add_to_group("chat_scene")   # opt this puzzle into the chat bar (normally HUD-hidden) so you can banter at the table
	var controls : String
	if TouchEnv.is_touch():
		controls = ("• Tap the action buttons (Fold / Check / Call / Bet / Raise / All-In)\n"
			+ "• Drag the bet slider on raises  ·  pinch to zoom the table, drag to pan\n")
	else:
		controls = ("• Click action buttons (Fold / Check / Call / Bet / Raise / All-In)\n"
			+ "• Slide the bet amount on raises\n")
	set_help_text("Hold 'em Poker — Texas Hold'em\n\n"
		+ controls
		+ "• Best 5-card hand from your 2 hole cards + 5 community cards wins\n\n"
		+ "• Your chips ARE gold (1:1) — buy in, then Cash Out your whole stack when you Leave\n"
		+ "• Bust and you forfeit your buy-in. Free tables risk no gold (rapport only)")
	var setup : Dictionary = PlayerState.consume_lobby_setup()
	_free_table = bool(setup.get("free", false))
	_config = PokerConfig.normalize(setup.get("table_config", _config))
	if _free_table:
		_config = PokerConfig.free_config(int(_config.get("seats", 6)))   # free = standard poker, fixed stake/blinds
	_table_seats = clampi(int(_config["seats"]), 2, 10)
	_occupant.resize(_table_seats)
	_occupant.fill(-1)
	_stamp_board_config()
	_set_stake_banner()
	_wire_signals()
	_action_panel.visible = false
	_result_panel.visible = false
	# OPEN SEATING (YPP): the table starts EMPTY — take a chair (buy in), invite folk into the rest, Deal.
	_begin_seating()


# The OVAL (racetrack) poker table — a stadium shape (a central rectangle capped by a semicircle at
# each end), layered walnut rail → brass inlay → green felt → inner shade, so players sit symmetrically
# around its rim (see _seat_position). Drawn here so we don't need a separate felt node.
func _draw() -> void:

	_draw_stadium(TABLE_CENTER, Vector2(1016.0, 482.0), Color(0.30, 0.20, 0.10, 1.0))   # walnut rail
	_draw_stadium(TABLE_CENTER, Vector2(1000.0, 466.0), Color(0.78, 0.58, 0.24, 1.0))   # brass inlay
	_draw_stadium(TABLE_CENTER, Vector2(972.0, 438.0), Color(0.14, 0.36, 0.22, 1.0))    # green felt
	_draw_stadium(TABLE_CENTER, Vector2(872.0, 350.0), Color(0.12, 0.31, 0.19, 1.0))    # inner shade


# Draw a filled STADIUM (racetrack) — a central rectangle capped by a semicircle at each end — centred
# at `c`, overall size `sz` (the caps' radius is sz.y/2). Layered, these compose the oval table.
func _draw_stadium(c: Vector2, sz: Vector2, color: Color) -> void:

	var r : float = sz.y * 0.5
	var mid : float = maxf(sz.x * 0.5 - r, 0.0)
	if mid > 0.0:
		draw_rect(Rect2(c.x - mid, c.y - r, mid * 2.0, r * 2.0), color, true)
	draw_circle(Vector2(c.x - mid, c.y), r, color)
	draw_circle(Vector2(c.x + mid, c.y), r, color)


# --- Setup: open seating (pick a chair → invite folk → deal) -----------

func _begin_seating() -> void:

	_seating = true
	# A WORLD-space holder under $Table (the felt's parent) so the open-seat buttons zoom + stay aligned with the
	# seats when the table is pinch-zoomed — the seated PokerSeat widgets already live under $Table the same way.
	_seat_layer = Node2D.new()
	_seat_layer.z_index = 10   # above the felt + seated widgets
	$Table.add_child(_seat_layer)
	_refresh_seating()


# Rebuild the OPEN-seat buttons (Sit Here before you sit · + Invite after) + the Deal control. Occupied
# chairs already carry their PokerSeat widget (built when that player sat), so we leave those alone.
func _refresh_seating() -> void:

	if _seat_layer == null:
		return
	for c in _seat_layer.get_children():
		c.queue_free()
	# Open chairs take a Sit Here / Invite button — while SEATING (before Deal) and again BETWEEN HANDS
	# (folk can pull up a stool as the game goes). Guests come from the 8-member cast (one each).
	if not _seating and not _between_hands:
		return
	var guests_left : int = NpcRegistry.all().size() - maxi(_board.players.size() - 1, 0)
	for k in _table_seats:
		if _occupant[k] >= 0:
			continue
		var pos : Vector2 = _seat_position(k, _table_seats)
		if _seating and not _human_seated:
			_seat_layer.add_child(_seat_button("✦  Sit Here", Color(0.82, 1.0, 0.6, 1.0), pos, _on_sit_here.bind(k)))
		elif guests_left > 0:
			_seat_layer.add_child(_seat_button("+  Invite", Color(0.86, 0.92, 1.0, 1.0), pos, _on_invite.bind(k)))
		elif _seating:
			# Whole cast already seated — a dead "full" chip (only worth showing while setting up).
			var full : Button = _seat_button("✕  full", Color(0.62, 0.56, 0.46, 1.0), pos, Callable())
			full.disabled = true
			_seat_layer.add_child(full)
	# Deal lights up once you + at least one guest are seated (seating only).
	if _seating and _human_seated and _board.players.size() >= 2:
		var deal : Button = _seat_button("Deal  ▸", Color(0.99, 0.88, 0.5, 1.0), Vector2(TABLE_CENTER.x, 432.0), _on_deal)
		deal.add_theme_font_size_override("font_size", 24)
		_seat_layer.add_child(deal)


func _seat_button(text: String, color: Color, center: Vector2, cb: Callable) -> Button:

	var b : Button = _dlg_button(text, color)
	var sz : Vector2 = Vector2(152.0, 50.0)
	b.size = sz
	b.position = center - sz * 0.5
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


# Take an open chair → buy in (a free table seats you straight away).
func _on_sit_here(k: int) -> void:

	_pending_seat = k
	if _free_table:
		_seat_human(k, PokerConfig.FREE_TABLE_STACK)   # free = standard 1000 chips for everyone
	else:
		_show_buy_in_dialog()


func _seat_human(k: int, chips: int) -> void:

	var human : PokerPlayer = PokerPlayer.new("You", chips, true)
	human.portrait_color = HUMAN_SEAT_COLOR
	_board.add_player(human)             # the human is ALWAYS board player 0 (sits before any guest)
	_display_of_player.append(k)
	_occupant[k] = 0
	_human_seated = true
	_sat_down = true
	_human_buy_in = chips
	_make_seat_widget(0)
	_refresh_seating()


# Click an open chair (after you've sat) → pick a guest from the cast to fill it.
func _on_invite(k: int) -> void:

	_show_npc_picker(k)


func _seat_npc(k: int, profile: NpcPersonality) -> void:

	var ai_chips : int = PokerConfig.FREE_TABLE_STACK if _free_table else _roll_buy_in(int(_config["min_bet"]))
	var ai : PokerPlayer = PokerPlayer.new(profile.npc_name, ai_chips, false)
	ai.portrait_color = profile.portrait_color
	ai.personality = profile
	_board.add_player(ai)
	var m : int = _board.players.size() - 1
	_display_of_player.append(k)
	_occupant[k] = m
	_make_seat_widget(m)
	_refresh_seating()


# Build the PokerSeat widget for board player `i` at the ring seat they took. _seats stays index-aligned
# to the board players (added in order), so the deal/turn/toast code keeps using _seats[i] unchanged.
func _make_seat_widget(i: int) -> void:

	var seat : PokerSeat = SEAT_SCENE.instantiate()
	$Table.add_child(seat)
	var s : float = _seat_scale(_table_seats)
	seat.scale = Vector2(s, s)
	seat.position = _seat_position(_display_of_player[i], _table_seats)
	seat.bind_to(_board.players[i])
	seat.hole_cards_face_up = _board.players[i].is_human
	if _board.players[i].personality != null:
		seat.enable_table_chat(_board.players[i].personality)   # a cast member → chat-able at the table
	_seats.append(seat)


# Start the game: lock seating, clear the open-seat buttons, deal the first hand.
func _on_deal() -> void:

	if _board.players.size() < 2:
		return
	_seating = false
	_refresh_seating()   # clears the seating buttons; the layer PERSISTS for between-hands invites
	_board.start_new_hand()


# Pick a guest for seat `k` from the cast (those not already at the table) — a small modal of named
# buttons, like the rest of the parlor chrome.
func _show_npc_picker(k: int) -> void:

	var seated : Array = []
	for p in _board.players:
		if p.personality != null:
			seated.append(p.personality)
	var available : Array[NpcPersonality] = []
	for profile in NpcRegistry.all():
		if not (profile in seated):
			available.append(profile)
	if available.is_empty():
		return   # the whole cast is already seated

	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 31
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_picker_dim_input.bind(layer))
	layer.add_child(dim)
	var panel : PanelContainer = PanelContainer.new()
	var sb : StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.10, 0.05, 0.98)
	sb.border_color = Color(0.96, 0.78, 0.34, 0.95)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.add_child(panel)
	var col : VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(300.0, 0.0)
	panel.add_child(col)
	_dlg_label(col, "Invite to the table", 22, Color(0.98, 0.88, 0.5, 1.0))
	for profile in available:
		var b : Button = _dlg_button(profile.npc_name, profile.portrait_color.lightened(0.3))
		b.pressed.connect(_on_npc_picked.bind(k, profile, layer))
		col.add_child(b)
	add_child(layer)


func _on_npc_picked(k: int, profile: NpcPersonality, layer: CanvasLayer) -> void:

	if is_instance_valid(layer):
		layer.queue_free()
	_seat_npc(k, profile)


func _on_picker_dim_input(event: InputEvent, layer: CanvasLayer) -> void:

	if event is InputEventMouseButton and event.pressed and is_instance_valid(layer):
		layer.queue_free()


# A random in-range starting stack for an AI seat (10×..100× the min-bet, à la a real player's buy-in).
func _roll_buy_in(min_bet: int) -> int:

	return randi_range(PokerConfig.buy_in_min(min_bet), PokerConfig.buy_in_max(min_bet))


# Stamp the chosen stake + structure onto the board before the first hand: blinds from the min-bet,
# the bet structure, and the house rake (cash tables only — free tables and the default take none).
func _stamp_board_config() -> void:

	var min_bet : int = int(_config["min_bet"])
	_board.bet_structure = int(_config["structure"])
	_board.small_blind_amount = PokerConfig.small_blind(min_bet)
	_board.big_blind_amount = PokerConfig.big_blind(min_bet)
	_board.pot_calculator.rake_fraction = 0.0 if _free_table else PokerConfig.RAKE_FRACTION


# Show the structure + blinds in the top banner so the stakes aren't a mystery once you're seated.
func _set_stake_banner() -> void:

	var min_bet : int = int(_config["min_bet"])
	var banner : Label = $UI/TopBanner/TitleLabel
	banner.text = "Hold 'em  ·  %s  ·  blinds %d/%d" % [
		PokerConfig.structure_name(int(_config["structure"])),
		PokerConfig.small_blind(min_bet), PokerConfig.big_blind(min_bet)]
	var _banner : Control = $UI/TopBanner as Control
	_banner.anchor_left = 1.0      # TOP-RIGHT: clears the top-left Leave button; the right-edge rail starts at x1222
	_banner.anchor_right = 1.0
	_banner.offset_left = -498.0
	_banner.offset_right = -88.0


# One UNIFORM scale for EVERY seat — the human is never bigger than the opponents (they're equals).
# Full size up to a 6-handed table; past that everyone shrinks TOGETHER so a packed oval never overlaps.
func _seat_scale(total: int) -> float:

	if total <= 6:
		return 1.0
	if total == 7:
		return 0.92
	if total == 8:
		return 0.85
	if total == 9:
		return 0.80
	return 0.72   # 10 (only reachable with future filler NPCs — the 8-cast tops out at 9)


# Place seat `i` of `total` SYMMETRICALLY around the oval's rim. Seat 0 (the human) sits bottom-centre;
# the rest are spaced EVENLY all the way around the ellipse (PI/2, screen y-down, is the bottom), so the
# table reads like a real poker oval with every player seated around it — no top-clustering, no gap.
func _seat_position(i: int, total: int) -> Vector2:

	var angle : float = PI * 0.5 + float(i) / float(maxi(total, 1)) * TAU
	return TABLE_CENTER + Vector2(cos(angle) * SEAT_RX, sin(angle) * SEAT_RY)


# --- Buy-in ------------------------------------------------------------

# Pop the YPP-style "Buy into the game?" dialog before the first deal: a slider over the stake's
# 10×..100× buy-in range (capped at the gold you actually have). Buy In charges the gold + seats you;
# Cancel / leaving the table charges nothing.
func _show_buy_in_dialog() -> void:

	var min_bet : int = int(_config["min_bet"])
	var lo : int = PokerConfig.buy_in_min(min_bet)
	var hi : int = mini(PokerConfig.buy_in_max(min_bet), PlayerState.total_coins)
	if PlayerState.total_coins < lo:
		_return_to_launching_scene()   # can't cover the min buy-in (the browser should have gated this)
		return

	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 30   # above the help "?" (21) + Leave button so it's a true modal
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)

	var panel : PanelContainer = PanelContainer.new()
	var sb : StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.10, 0.05, 0.98)
	sb.border_color = Color(0.96, 0.78, 0.34, 0.95)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.add_child(panel)
	var col : VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(420.0, 0.0)
	panel.add_child(col)

	_dlg_label(col, "Buy into the game?", 26, Color(0.98, 0.88, 0.5, 1.0))
	_dlg_label(col, "%s  ·  %d–%d gold" % [
		PokerConfig.structure_name(int(_config["structure"])), lo, hi], 15, Color(0.80, 0.84, 0.92, 1.0))
	var amount_lbl : Label = _dlg_label(col, "%d gold" % hi, 30, Color(0.99, 0.84, 0.36, 1.0))
	var slider : HSlider = HSlider.new()
	slider.min_value = lo
	slider.max_value = maxi(hi, lo)
	slider.step = 1
	slider.value = hi
	slider.custom_minimum_size = Vector2(360.0, 18.0)
	slider.editable = hi > lo
	slider.value_changed.connect(func(v: float) -> void: amount_lbl.text = "%d gold" % int(v))
	col.add_child(slider)
	_dlg_label(col, "You have %d gold" % PlayerState.total_coins, 14, Color(0.74, 0.80, 0.92, 1.0))

	var row : HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	var buy : Button = _dlg_button("Buy In", Color(0.80, 1.0, 0.62, 1.0))
	buy.pressed.connect(func() -> void: _on_buy_in_confirmed(int(slider.value), layer))
	row.add_child(buy)
	var cancel : Button = _dlg_button("Cancel", Color(0.95, 0.84, 0.56, 1.0))
	cancel.pressed.connect(func() -> void: _on_buy_in_cancelled(layer))
	row.add_child(cancel)

	add_child(layer)


func _on_buy_in_confirmed(amount: int, dialog: CanvasLayer) -> void:

	var buy_in : int = clampi(amount, PokerConfig.buy_in_min(int(_config["min_bet"])), PlayerState.total_coins)
	PlayerState.add_coins(-buy_in, "Card-table buy-in")   # charge the chosen buy-in (gold) now
	dialog.queue_free()
	_seat_human(_pending_seat, buy_in)   # seat you at the chosen chair — Deal (after a guest) starts play


func _on_buy_in_cancelled(dialog: CanvasLayer) -> void:

	dialog.queue_free()
	_pending_seat = -1   # back to picking a chair (the persistent Leave button exits the table)


func _dlg_label(parent: VBoxContainer, text: String, size: int, color: Color) -> Label:

	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _dlg_button(text: String, color: Color) -> Button:

	var b : Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	b.add_theme_constant_override("outline_size", 3)
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.22, 0.14, 0.08, 0.95)
	s.border_color = Color(0.78, 0.58, 0.24, 1.0)
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(10)
	b.add_theme_stylebox_override("normal", s)
	return b


func _wire_signals() -> void:

	_board.phase_changed.connect(_on_phase_changed)
	_board.hole_cards_dealt.connect(_on_hole_cards_dealt)
	_board.community_dealt.connect(_on_community_dealt)
	_board.player_acted.connect(_on_player_acted)
	_board.blinds_posted.connect(_on_blinds_posted)
	_board.pot_changed.connect(_on_pot_changed)
	_board.turn_changed.connect(_on_turn_changed)
	_board.hand_complete.connect(_on_hand_complete)
	_board.all_in_runout.connect(_on_all_in_runout)
	_action_panel.action_chosen.connect(_on_action_chosen)
	_result_btn.pressed.connect(_on_next_hand_pressed)


# --- Board signal handlers --------------------------------------------

func _on_phase_changed(phase: PokerBoard.Phase) -> void:

	# Phase is visually obvious from the number of community cards
	# revealed. PREFLOP wipes the community row; nothing else to do.
	if phase == PokerBoard.Phase.PREFLOP:
		_community.clear()
		_chat_events.clear()   # a fresh hand — drop last hand's action from the NPC chat context
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
		temp.scale = _seats[seat_idx].scale   # land matching the (possibly shrunk) destination seat
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
	var already : int = _community.revealed_count()   # streets already on the felt — don't re-reveal them
	var first_stage : bool = true
	for n in [3, 4, 5]:
		if all_community.size() < n:
			break
		if n <= already:
			continue   # already shown — skip it. (Calling set_cards(3) at the river would hide slots 3+4 and
			# reset _revealed_count, so the next set_cards(4) re-deals the TURN before the river. The bug.)
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
	_push_chat_event(_action_phrase(_board.players[player_index], action, amount))
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


# --- NPC chat context: live table awareness for the seated cast ------------------------------------------
# The seated NPCs chat via the shared ChatBox/RoomChat; [VersusPuzzleScene]'s default npc_chat_context
# assembles their prompt from the hooks below (duck-typed by NpcBrain.compose_system) so each reacts like a
# real player. HIDDEN-INFO SAFE BY CONSTRUCTION: only _own_secret_view sees a secret, and the base only ever
# passes the ASKER's own name — a player sees ONLY their OWN hole cards + the shared board + showdown-revealed
# results, never a rival's. See [[npc-situational-awareness]].
func _versus_ready() -> bool:
	return _board != null and not _board.players.is_empty()


func _rules_brief() -> String:
	return ("THE RULES OF POKER HERE (so your table talk is accurate): standard Texas Hold'em. Each player gets 2 "
		+ "private hole cards; five shared community cards come out in stages (flop, then turn, then river), with a "
		+ "betting round between each — check, call, raise, or fold. The best five-card hand at showdown wins the "
		+ "pot, and if everyone else folds the last player standing takes it. Ranking high to low: straight flush, "
		+ "four of a kind, full house, flush, straight, three of a kind, two pair, one pair, high card. This is an "
		+ "ongoing cash game of separate hands, NOT a best-of-N match — there's no overall winner until someone "
		+ "busts or leaves, so talk about THIS hand and the chip stacks, never about 'winning the game'.")


# The shared, PUBLIC frame — intro, the revealed board (clamped to what's on-screen), pot, all stacks.
func _public_frame() -> String:

	var lines : PackedStringArray = PackedStringArray()
	lines.append("POKER — you're at the table playing this hand right now; react to it naturally, like a player at the felt:")
	var phase_name : String = PokerBoard.PHASE_NAMES[_board.phase]
	# Clamp the board to what's actually been revealed ON-SCREEN: an all-in run-out fills community_cards
	# logically a beat before the cards animate onto the felt, so reading the raw array would let an NPC "see"
	# the river early. revealed_count() is the visible truth.
	var shown : int = _community.revealed_count()
	var board_str : String = _cards_str(_board.community_cards.slice(0, shown))
	lines.append("Hold'em, blinds %d/%d. %s. Board: %s." % [
		_board.small_blind_amount, _board.big_blind_amount, phase_name,
		board_str if not board_str.is_empty() else "none yet (preflop)"])
	# Pot + bet-to-call ONLY while a hand is actually live. Between hands the pot's already been awarded, but
	# total_pot still sums the old contributions until the next deal — the "<who> won N" event covers the result.
	if _board.phase >= PokerBoard.Phase.PREFLOP and _board.phase <= PokerBoard.Phase.RIVER:
		var potline : String = "Pot: %d." % _board.pot_calculator.total_pot(_board.players)
		if _board.current_bet > 0:
			potline += " Bet to call this round: %d." % _board.current_bet
		lines.append(potline)
	# Public stacks + status for everyone (chips, folded/all-in/in-for — all visible to the whole table).
	var stacks : PackedStringArray = PackedStringArray()
	for p in _board.players:
		var s : String = "%s %d" % [_who_name(p), p.chips]
		if p.folded:
			s += " (folded)"
		elif p.all_in:
			s += " (all-in)"
		elif p.current_bet > 0:
			s += " (in %d)" % p.current_bet
		stacks.append(s)
	lines.append("Stacks (chips) — " + ", ".join(stacks) + ".")
	return "\n".join(lines)


# A PRE-COMPUTED chip-leader callout: the small chat model is bad at numeric comparison (it once boasted
# "more chips than you" while holding fewer), so name who's actually ahead instead of trusting it to compare.
func _lead_phrase(_asker: String) -> String:

	var leader : PokerPlayer = _board.players[0]
	for p in _board.players:
		if p.chips > leader.chips:
			leader = p
	return "Chip leader right now: %s with %d." % [_who_name(leader), leader.chips]


# The asker's OWN private view — ONLY their own hole cards (never a rival's), PLUS how their stack compares to
# the traveller's, stated plainly. Returns "" if the asker isn't seated (a spectator gets no secret).
func _own_secret_view(asker: String) -> String:

	var me : PokerPlayer = _player_named(asker)
	if me == null:
		return ""
	var pv : String = "You are %s with %d chips" % [asker, me.chips]
	if not me.hole_cards.is_empty():
		pv += ", holding %s" % _cards_str(me.hole_cards)
	if me.folded:
		pv += " (you've folded this hand)"
	elif me.all_in:
		pv += " (you're all-in)"
	pv += "."
	var human : PokerPlayer = _board.players[0]
	if me != human:
		if me.chips > human.chips:
			pv += " You're ahead of the traveller on chips (%d to %d)." % [me.chips, human.chips]
		elif me.chips < human.chips:
			pv += " The traveller is ahead of you on chips (%d to %d)." % [human.chips, me.chips]
		else:
			pv += " You and the traveller are dead even on chips (%d each)." % me.chips
	return pv


# Recent action this hand (the rolling event buffer).
func _pressure_phrase(_asker: String) -> String:
	return ("Just happened: " + " ".join(_chat_events)) if not _chat_events.is_empty() else ""


func _push_chat_event(text: String) -> void:

	if text.is_empty():
		return
	_chat_events.append(text)
	while _chat_events.size() > CHAT_EVENTS_MAX:
		_chat_events.remove_at(0)
	PlayerState.log_event(text)   # also surface to the player's scrollable chat Log — announcer/gold (YPP-style)


# A poker action as a readable past-tense line for the chat context. Raise/all-in use post-action current_bet
# for the to-total (mirrors the seat label). The human reads as "the traveller".
func _action_phrase(p: PokerPlayer, action: PokerBoard.Action, amount: int) -> String:

	var who : String = _who_name(p)
	match action:
		PokerBoard.Action.FOLD:
			return "%s folded." % who
		PokerBoard.Action.CHECK:
			return "%s checked." % who
		PokerBoard.Action.CALL:
			return ("%s called %d." % [who, amount]) if amount > 0 else ("%s called." % who)
		PokerBoard.Action.BET:
			return "%s bet %d." % [who, amount]
		PokerBoard.Action.RAISE:
			return "%s raised to %d." % [who, p.current_bet]
		PokerBoard.Action.ALL_IN:
			return ("%s shoved all-in for %d." % [who, p.current_bet]) if p.current_bet > 0 else ("%s shoved all-in." % who)
	return ""


# The human reads as "the traveller" (the prompt addresses the NPC as "you"); NPCs go by name.
func _who_name(p: PokerPlayer) -> String:

	return "the traveller" if p.is_human else p.player_name


func _player_named(nm: String) -> PokerPlayer:

	for p in _board.players:
		if not p.is_human and p.player_name == nm:
			return p
	return null


func _cards_str(cards: Array) -> String:

	var parts : PackedStringArray = PackedStringArray()
	for c in cards:
		if c != null:
			parts.append(c.short_name())
	return " ".join(parts)


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
	# Table talk in this NPC's head nudges their decision (0.0 when no mood is live); tick ages it a step.
	var mb : float = mood_bias(player.player_name)
	tick_opponent_mood(player.player_name)
	var decision : Dictionary = PokerAI.decide(_board, player, mb)
	_board.apply_action(decision["action"], decision["amount"])


# Everyone's all-in (or one caller) and the board is about to run out — table every LIVE hand face-up NOW, so the
# player watches the cards come out with all hands visible, not hidden until the end (Troy 2026-06-12). Mirrors the
# non-folded reveal in _on_hand_complete; the final showdown still runs its full reveal + result panel.
func _on_all_in_runout() -> void:

	for i in _seats.size():
		if i < _board.players.size() and not _board.players[i].folded:
			_seats[i].hole_cards_face_up = true


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

	# Chat context: log the showdown result + any bust so the seated NPCs can react to it ("nice hand", "ouch").
	# Hand descriptions are only added on a real showdown (public info); fold-out wins just say "won N".
	for w in order:
		var ev : String = "%s won %d" % [_who_name(w), int(totals[w])]
		if did_showdown and descriptions.has(w):
			ev += " with %s" % String(descriptions[w])
		_push_chat_event(ev + ".")
	for bp in _board.players:
		if bp.chips <= 0 and bp.total_bet_in_hand > 0 and not (bp in totals):
			_push_chat_event("%s busted out of the game." % _who_name(bp))

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
	_between_hands = not busted   # open chairs are invite-able between hands (not after a bust-out)
	_refresh_seating()
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
	_between_hands = false   # the next hand begins — no inviting mid-hand
	_refresh_seating()
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

	if _returning:
		return   # Leave + the result button can fire the same frame — pay out / record only once
	_returning = true
	_grant_opponent_affinity()
	_record_poker_mastery()
	_payout_chips()
	super._return_to_launching_scene()


# Mastery — high-water-mark is your final stack in GOLD (1:1), matching the "poker" thresholds, so
# Standings rise with how well you played. No toast: we're leaving the table, so the scene changes
# right after; the rank still records.
func _record_poker_mastery() -> void:

	# Only a REAL (cash) session that was actually PLAYED counts — never a cancelled buy-in, a free table
	# (house chips → unearned Standings), or a sit left BEFORE Dealing (chips would still equal the buy-in).
	if not _sat_down or _free_table or _seating:
		return
	if _board == null or _board.players.is_empty():
		return
	var human : PokerPlayer = _board.players[0]
	# Stacks ARE gold now (1:1), so the mastery score is the final stack directly.
	PlayerState.record_puzzle_result("poker", human.chips)


# Credit rapport to every NPC the player sat with this session. Sharing
# a table builds a bit of rapport regardless of outcome; finishing the
# session up adds a little more (they respect a winner). Granted once
# on exit, not per hand, so it can't be farmed by playing single hands.
func _grant_opponent_affinity() -> void:

	# No rapport for a session you never sat to, or left before Dealing (no hand was actually shared).
	if not _sat_down or _seating:
		return
	if _board == null or _board.players.size() < 2:
		return
	var human : PokerPlayer = _board.players[0]
	var won_session : bool = human.chips > _human_buy_in
	var gain : int = PLAY_AFFINITY + (WINNING_SESSION_BONUS if won_session else 0)
	for i in range(1, _board.players.size()):
		PlayerState.add_affinity(_board.players[i].player_name, gain)


# Cash out the human's chip stack as gold (1:1 — your stack IS gold, à la YPP's PoE). The buy-in was
# already charged at the buy-in dialog, so handing back the full stack nets you (final − buy-in).
func _payout_chips() -> void:

	# Free table — nothing was bought in, nothing cashes out.
	if _free_table:
		return
	if _board == null or _board.players.is_empty():
		return
	var gold : int = _board.players[0].chips
	if gold > 0:
		award_winnings(gold, "Card-table winnings")


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
