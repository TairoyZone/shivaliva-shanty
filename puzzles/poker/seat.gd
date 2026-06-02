## One player position at the poker table. Renders the portrait, name,
## chip stack, current-bet tag, dealer button, two hole-card slots, and
## an active-turn highlight. All visual updates are driven by setter
## properties so the scene controller just assigns and the node
## re-draws itself.
##
## Layout (origin at the panel's center):
##   • Brass-bordered dark-walnut panel ~PANEL_W × PANEL_H
##   • Portrait circle top-left (tinted by [member portrait_color])
##   • Name + chip stack + current-bet stacked to the right of the portrait
##   • "D" dealer badge top-right when [member is_dealer] is true
##   • Two hole-card sprites positioned just below the panel
##
## Folded seats get a grey modulate so they read as out-of-the-hand at
## a glance.
@tool
class_name PokerSeat
extends Node2D


const CARD_SCENE : PackedScene = preload("res://puzzles/poker/card_sprite.tscn")

const PANEL_W : float = 220.0
const PANEL_H : float = 108.0
const PORTRAIT_RADIUS : float = 24.0
const HOLE_CARD_Y : float = 92.0            # distance below panel center
const HOLE_CARD_SPACING : float = 30.0      # half-distance between the two card centers
const DEALER_BADGE_RADIUS : float = 11.0
# Chip icon drawn next to the chip count. Pulled from the same atlas
# the pot uses (chips.png, yellow variant 0) so the seat and pot share
# a visual vocabulary.
const CHIP_ICON_SIZE : float = 16.0
const CHIP_ICON_ATLAS_RECT : Rect2 = Rect2(184.0, 144.0, 46.0, 48.0)

# Palette (matches the gem-drop HUD)
const COLOR_PANEL_BG : Color = Color(0.18, 0.11, 0.06, 0.94)
const COLOR_BORDER : Color = Color(0.78, 0.58, 0.24, 1.0)
const COLOR_BORDER_ACTIVE : Color = Color(1.0, 0.88, 0.42, 1.0)
const COLOR_TEXT_GOLD : Color = Color(0.97, 0.87, 0.55, 1.0)
const COLOR_TEXT_DIM : Color = Color(0.78, 0.74, 0.62, 1.0)
const COLOR_BET_BRASS : Color = Color(1.0, 0.86, 0.42, 1.0)
const COLOR_DEALER_BG : Color = Color(0.55, 0.10, 0.10, 1.0)
const COLOR_OUTLINE : Color = Color(0, 0, 0, 0.85)
const FOLDED_MODULATE : Color = Color(0.45, 0.45, 0.45, 0.85)
## Milder dim used for showdown losers — they didn't fold, they stayed
## in and lost, so they still read as "in the hand" but visually defer
## to the winner's bright halo.
const LOSER_MODULATE : Color = Color(0.62, 0.58, 0.55, 0.92)


@export var seat_name : String = "Stranger" :
	set(value):
		seat_name = value
		queue_redraw()
@export var portrait_color : Color = Color(0.95, 0.74, 0.28) :
	set(value):
		portrait_color = value
		queue_redraw()
## Chip stack to display.
@export var chips : int = 0 :
	set(value):
		chips = value
		queue_redraw()
## Amount currently bet in the active betting round. Hidden when zero.
@export var current_bet : int = 0 :
	set(value):
		current_bet = value
		queue_redraw()
## Highlight the panel border in brass-bright when this seat is the one
## currently to act.
@export var is_active : bool = false :
	set(value):
		is_active = value
		queue_redraw()
## Stronger gold border + soft glow for the seat(s) that just won the hand.
## Set at showdown, cleared when the next hand starts.
@export var is_winner : bool = false :
	set(value):
		is_winner = value
		_apply_panel_tint()
		queue_redraw()
## Dimmer panel + red border for seats that stayed to showdown and lost.
## Set at hand_complete alongside the "-N" toast, cleared on next hand.
## Mutually exclusive with [member is_winner]; folded seats keep the
## stronger fold tint and don't get this treatment.
@export var is_loser : bool = false :
	set(value):
		is_loser = value
		_apply_panel_tint()
		queue_redraw()
## Display the rotating dealer-button badge in this seat.
@export var is_dealer : bool = false :
	set(value):
		is_dealer = value
		_refresh_dealer_tooltip()
		queue_redraw()
## Grey out the whole seat once the player folds the hand.
@export var folded : bool = false :
	set(value):
		folded = value
		_apply_panel_tint()
		_refresh_folded_label()
		queue_redraw()
## Optional hand-rank line ("Pair of Aces", "Two Pair", "Royal Flush"…)
## drawn beneath the chip stack. Set continuously for the human as
## the board reveals community cards, set for every non-folded seat
## at showdown so the player can read exactly what beat them. Empty
## string hides the line.
@export var hand_label : String = "" :
	set(value):
		hand_label = value
		queue_redraw()
## What this seat did in the current betting round ("Check", "Call 20",
## "Raise to 80", "Fold", "All-In 240"…). Replaces the floating toast —
## persisted in-panel so the player can always read who-did-what without
## having to catch it mid-flight. Scene clears this between rounds.
@export var last_action_label : String = "" :
	set(value):
		last_action_label = value
		queue_redraw()
## Color used to draw [member last_action_label]. Set per-action so fold
## reads grey, all-in reads red, bet/raise reads brass-bright.
@export var last_action_color : Color = Color(1.0, 0.86, 0.42, 1.0) :
	set(value):
		last_action_color = value
		queue_redraw()
## When false, hole cards show their backs (opponents). When true, faces
## are revealed (you, or any player at showdown).
@export var hole_cards_face_up : bool = false :
	set(value):
		hole_cards_face_up = value
		_refresh_hole_cards()


var hole_cards : Array[Card] = [] :
	set(value):
		hole_cards = value
		_refresh_hole_cards()


var _card_a : CardSprite
var _card_b : CardSprite
var _folded_label : Label
## Invisible Control overlay sized to the dealer badge, present so the
## badge has hover-detection for the tooltip. Shown only when
## [member is_dealer] is true; otherwise hidden so non-dealer seats
## don't intercept clicks in that corner.
var _dealer_tooltip_area : Control


func _ready() -> void:

	# Build the two hole-card slots once.
	_card_a = CARD_SCENE.instantiate()
	_card_b = CARD_SCENE.instantiate()
	add_child(_card_a)
	add_child(_card_b)
	_card_a.position = Vector2(-HOLE_CARD_SPACING, HOLE_CARD_Y)
	_card_b.position = Vector2(HOLE_CARD_SPACING, HOLE_CARD_Y)
	_card_a.visible = false
	_card_b.visible = false

	# "FOLDED" overlay — sits on top of the hole-card sprites, only
	# shown for folded seats that still have cards down. Added AFTER
	# the card sprites so it renders above them in tree order.
	_folded_label = Label.new()
	_folded_label.text = "FOLDED"
	_folded_label.add_theme_font_size_override("font_size", 18)
	_folded_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55, 1.0))
	_folded_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_folded_label.add_theme_constant_override("outline_size", 4)
	_folded_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_folded_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_folded_label.size = Vector2(140.0, 28.0)
	_folded_label.position = Vector2(-_folded_label.size.x * 0.5, HOLE_CARD_Y - _folded_label.size.y * 0.5)
	_folded_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_folded_label.visible = false
	add_child(_folded_label)

	# Invisible Control over the dealer badge — its sole job is to be a
	# Control with a tooltip_text + mouse_filter STOP so hovering the
	# badge surfaces a "Dealer button" explanation. Sized to match the
	# badge circle.
	_dealer_tooltip_area = Control.new()
	_dealer_tooltip_area.tooltip_text = "Dealer button — rotates each hand. Acts last in every betting round except preflop."
	_dealer_tooltip_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_dealer_tooltip_area.size = Vector2(DEALER_BADGE_RADIUS * 2.0, DEALER_BADGE_RADIUS * 2.0)
	_dealer_tooltip_area.position = Vector2(
		PANEL_W * 0.5 - DEALER_BADGE_RADIUS * 2.0 - 6.0,
		-PANEL_H * 0.5 + 6.0)
	_dealer_tooltip_area.visible = false
	add_child(_dealer_tooltip_area)

	_apply_panel_tint()
	_refresh_hole_cards()
	_refresh_folded_label()
	_refresh_dealer_tooltip()


func _draw() -> void:

	_draw_panel()
	_draw_portrait()
	_draw_text_block()
	if is_dealer:
		_draw_dealer_badge()


# --- Apply seat state from a [PokerPlayer] in one call. The scene
# controller uses this to sync the visual to the logical seat without
# touching every property individually. Pass with_cards=false when an
# external animation owns the hole-card display (e.g. the dealing tween).
func bind_to(player: PokerPlayer, with_cards: bool = true) -> void:

	seat_name = player.player_name
	chips = player.chips
	portrait_color = player.portrait_color
	current_bet = player.current_bet
	folded = player.folded
	if with_cards:
		hole_cards = player.hole_cards


## World-space position of one of the two hole-card slots, relative to
## this seat's parent. Used by the scene controller to compute where
## animated cards should land.
func hole_card_world_position(card_slot: int) -> Vector2:

	var dx : float = -HOLE_CARD_SPACING if card_slot == 0 else HOLE_CARD_SPACING
	return position + Vector2(dx, HOLE_CARD_Y)


## At showdown, mark each hole card as part of the winning hand
## (highlighted) or not (dimmed). Pass an empty array to clear back to
## normal display.
func mark_showdown(winning_cards: Array[Card]) -> void:

	if _card_a == null or _card_b == null:
		return
	if winning_cards.is_empty():
		_card_a.highlighted = false
		_card_a.dimmed = false
		_card_b.highlighted = false
		_card_b.dimmed = false
		return
	for slot in [_card_a, _card_b]:
		if slot.card == null or not slot.visible:
			continue
		var in_winning : bool = false
		for wc in winning_cards:
			if wc.equals(slot.card):
				in_winning = true
				break
		slot.highlighted = in_winning
		slot.dimmed = not in_winning


# --- Drawing helpers --------------------------------------------------

func _draw_panel() -> void:

	var rect : Rect2 = Rect2(-PANEL_W * 0.5, -PANEL_H * 0.5, PANEL_W, PANEL_H)
	# Winner halo — slightly larger ghost rect underneath, semi-transparent
	# gold. Reads as a glow without needing a real shader.
	if is_winner:
		var halo : Rect2 = rect.grow(6.0)
		draw_rect(halo, Color(1.0, 0.92, 0.50, 0.35), true)
	draw_rect(rect, COLOR_PANEL_BG, true)
	var border_color : Color = COLOR_BORDER
	var border_width : float = 2.0
	if is_winner:
		border_color = Color(1.0, 0.95, 0.55, 1.0)
		border_width = 4.0
	elif is_active:
		border_color = COLOR_BORDER_ACTIVE
		border_width = 3.0
	draw_rect(rect, border_color, false, border_width)


func _draw_portrait() -> void:

	var center : Vector2 = Vector2(
		-PANEL_W * 0.5 + PORTRAIT_RADIUS + 12.0,
		0.0)
	draw_circle(center, PORTRAIT_RADIUS, portrait_color)
	draw_arc(center, PORTRAIT_RADIUS, 0.0, TAU, 32, COLOR_BORDER.darkened(0.25), 2.0)
	# Initial in the middle of the portrait.
	var initial : String = seat_name.substr(0, 1).to_upper() if seat_name.length() > 0 else "?"
	_draw_text_centered(initial, center, 22, Color.WHITE)


func _draw_text_block() -> void:

	var text_x : float = -PANEL_W * 0.5 + 2.0 * PORTRAIT_RADIUS + 24.0
	var font : Font = ThemeDB.fallback_font
	# Name on top.
	_draw_text(font, seat_name, Vector2(text_x, -18.0), 16, COLOR_TEXT_GOLD, true)
	# Chip stack: real chip icon hugging the count, both centered on a
	# common baseline. Icon centered vertically on the digits' visual
	# midline (ascent-based, not the full line height) so it doesn't
	# look like it's floating above the number.
	var chip_text : String = "%d" % chips
	var chip_size : int = 14
	var chip_ascent : float = font.get_ascent(chip_size)
	var baseline_y : float = 2.0
	var icon_y : float = baseline_y - chip_ascent * 0.5 - CHIP_ICON_SIZE * 0.5
	var icon_rect : Rect2 = Rect2(
		Vector2(text_x, icon_y),
		Vector2(CHIP_ICON_SIZE, CHIP_ICON_SIZE))
	draw_texture_rect_region(PotDisplay.CHIPS_TEX, icon_rect, CHIP_ICON_ATLAS_RECT)
	_draw_text(font, chip_text,
		Vector2(text_x + CHIP_ICON_SIZE + 2.0, baseline_y),
		chip_size, COLOR_TEXT_GOLD.darkened(0.10), true)
	# Last action takes priority over the running bet line. Falls back to
	# "Bet N" so the BB still reads correctly before they've acted preflop.
	if last_action_label != "":
		_draw_text(font, last_action_label, Vector2(text_x, 20.0), 12, last_action_color, true)
	elif current_bet > 0:
		_draw_text(font, "Bet %d" % current_bet, Vector2(text_x, 20.0), 12, COLOR_BET_BRASS, true)
	# Hand-rank line (set continuously for the human, on showdown for everyone).
	if hand_label != "":
		_draw_text(font, hand_label, Vector2(text_x, 40.0), 12, Color(1.0, 0.95, 0.55, 1.0), true)


func _draw_dealer_badge() -> void:

	var pos : Vector2 = Vector2(PANEL_W * 0.5 - DEALER_BADGE_RADIUS - 6.0,
		-PANEL_H * 0.5 + DEALER_BADGE_RADIUS + 6.0)
	draw_circle(pos, DEALER_BADGE_RADIUS, COLOR_DEALER_BG)
	draw_arc(pos, DEALER_BADGE_RADIUS, 0.0, TAU, 24, COLOR_BORDER, 1.5)
	_draw_text_centered("D", pos, 14, Color.WHITE)


func _draw_text(font: Font, text: String, baseline_pos: Vector2, size: int, color: Color, with_outline: bool) -> void:

	if with_outline:
		font.draw_string_outline(get_canvas_item(), baseline_pos, text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, COLOR_OUTLINE)
	font.draw_string(get_canvas_item(), baseline_pos, text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_text_centered(text: String, center: Vector2, size: int, color: Color) -> void:

	var font : Font = ThemeDB.fallback_font
	var dim : Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
	var baseline : Vector2 = center + Vector2(-dim.x * 0.5, dim.y * 0.3)
	font.draw_string_outline(get_canvas_item(), baseline, text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, size, 3, COLOR_OUTLINE)
	font.draw_string(get_canvas_item(), baseline, text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, size, color)


# --- State sync helpers -----------------------------------------------

func _refresh_hole_cards() -> void:

	if _card_a == null or _card_b == null:
		return
	_card_a.visible = hole_cards.size() > 0
	_card_b.visible = hole_cards.size() > 1
	if _card_a.visible:
		_card_a.set_card(hole_cards[0], hole_cards_face_up)
	if _card_b.visible:
		_card_b.set_card(hole_cards[1], hole_cards_face_up)
	_refresh_folded_label()


func _apply_panel_tint() -> void:

	# Folded takes precedence (strongest dim). Then loser (mild dim).
	# Winners and active in-hand seats use full brightness — the winner
	# halo + brighter border carry the highlight in [method _draw_panel].
	if folded:
		modulate = FOLDED_MODULATE
	elif is_loser and not is_winner:
		modulate = LOSER_MODULATE
	else:
		modulate = Color.WHITE


# Show the "FOLDED" overlay only when this seat is folded AND still
# has hole cards down (between-hand state has no cards, no overlay).
func _refresh_folded_label() -> void:

	if _folded_label == null:
		return
	_folded_label.visible = folded and hole_cards.size() > 0


# Sync the invisible tooltip hover area's visibility to [member is_dealer]
# so non-dealer seats don't intercept clicks in that corner.
func _refresh_dealer_tooltip() -> void:

	if _dealer_tooltip_area == null:
		return
	_dealer_tooltip_area.visible = is_dealer
