## Persistent overworld HUD. Top-right purse (gold icon + count, with
## count-up tween + scale bounce + "+N / -N" floater on every
## [PlayerState.coins_changed]) plus a Backpack button that opens the
## [InventoryPanel] (also toggled with the I key). Autoloaded by
## project.godot at layer 10 so it sits above all gameplay scenes.
## Puzzle scenes hide this whole CanvasLayer on entry (see [PuzzleScene])
## so it doesn't crowd parlor minigame UIs — and the inventory can't be
## opened while it's hidden.
##
## Wood (and future items) live in the backpack, NOT the HUD — per Troy's
## direction. The bag button just bumps/glows when the inventory changes;
## exact counts live in the panel. The purse keeps the full count-up
## treatment because gold stay a HUD currency.
extends CanvasLayer


## Duration of the count-up tween between the previous total and the
## new total. Short enough that consecutive awards don't queue up
## visibly behind each other.
const COUNT_DURATION : float = 0.45
## Bounce scale at the peak of the change feedback.
const BOUNCE_SCALE : float = 1.18
const BOUNCE_DURATION : float = 0.32
## Floater toast (+N / -N) animation.
const FLOATER_RISE : float = 26.0
const FLOATER_LIFETIME : float = 1.1
## --- Toast origin tuning ---
## The toast spawns relative to the chip-count label's center, plus
## these offsets. Defaults are user-calibrated to land on the visual
## center of the purse panel — the label-anchor gets us within range,
## these offsets close the gap because the visible purse extends
## further right than the digits do.
## Positive X shifts the toast RIGHT, negative shifts LEFT.
## Positive Y shifts DOWN, negative shifts UP.
const FLOATER_OFFSET_X : float = 108.0
const FLOATER_OFFSET_Y : float = 22.0

const COLOR_GAIN : Color = Color(0.55, 1.0, 0.55, 1.0)
const COLOR_LOSS : Color = Color(1.0, 0.55, 0.55, 1.0)
const COLOR_NEUTRAL : Color = Color(1.0, 0.92, 0.55, 1.0)

@onready var _purse : PanelContainer = %Purse
@onready var _coin_label : Label = %CoinLabel

## What's currently rendered in the label — may lag behind
## [member PlayerState.total_coins] mid-tween. Tweens animate
## this value; [method _refresh] writes it to the label.
var _displayed : int = 0
var _count_tween : Tween
var _bounce_tween : Tween
var _shake_tween : Tween
## Most-recent total received from [signal PlayerState.coins_changed]
## while this HUD was hidden (i.e. inside a puzzle scene). -1 means
## "no deferred change." Flushed by [method flush_pending_change] when
## the player returns to an overworld scene, so the count-up + bounce
## + floater all play in front of the player instead of silently
## finishing while invisible.
var _pending_total : int = -1
## Whether the bag took an item in while the HUD was hidden (inside a puzzle) — so the backpack-tab bump
## replays on return, like the purse's _pending_total. No count, just a bump.
var _bag_pending : bool = false

func _ready() -> void:

	_displayed = PlayerState.total_coins
	_refresh()
	# Pivot at the panel's visual center so the bounce scales evenly.
	_purse.pivot_offset = _purse.size * 0.5
	# Hover tooltip on the whole purse — the panel's mouse_filter is
	# PASS by default for PanelContainer; force STOP so the tooltip
	# actually fires on hover.
	_purse.mouse_filter = Control.MOUSE_FILTER_STOP
	_purse.tooltip_text = "Gold — your in-world currency. Earned from puzzles, parlor games, and treasures."
	# Gold moved INTO the Backpack panel — no more always-on top-right purse (Troy 2026-06-16). The node
	# stays (its count-up + signal wiring still run) so a re-show is trivial, it's just hidden.
	_purse.visible = false
	_purse.resized.connect(_on_purse_resized)
	PlayerState.coins_changed.connect(_on_coins_changed)
	# A trophy earned anywhere (even mid-puzzle, while this HUD is hidden) pops a TrophyToast
	# on the tree ROOT — not this hideable HUD — so it shows over whatever scene is up.
	PlayerState.trophy_earned.connect(_on_trophy_earned)
	# The bag BUMPS when the inventory changes (you picked up wood/ore). If that happened while hidden
	# (inside a puzzle), replay it on return so the gain isn't silent (see flush_pending_wood_change).
	PlayerState.inventory_changed.connect(_on_inventory_changed)
	# (The old right-side quick-menu + the "!" journal popup were retired — their functions live in the user
	# panel's tab rail now: Ayo! · Objectives · Tutorials · Backpack · Hearts · Profile + a Jobs launcher.)
	# Self-heal: if coins changed while hidden (inside a puzzle), replay
	# the purse animation the moment the HUD becomes visible again —
	# rather than depending on a caller remembering to flush. (Audit
	# minor: covers any future hide/show path, not just PuzzleScene.)
	# Guarded because CanvasLayer extends Node, not CanvasItem, so the
	# signal isn't guaranteed across engine versions; PuzzleScene's
	# explicit flush remains the primary path either way.
	if has_signal("visibility_changed"):
		visibility_changed.connect(_on_visibility_changed)
	_build_touch_menu_button()   # mobile: an on-screen way to open the pause menu (no Esc on a phone)
	_build_clock()               # the persistent Stardew-style in-game clock (top-left, by the pause button)


# A persistent in-game CLOCK widget so the player can always check the hour (pairs with the day/night cycle).
# TOP-RIGHT corner (Stardew-style) — above the vertically-centred UserPanel rail. On the ship deck the
# vessel/condition card tucks in just LEFT of it (ship_deck makes room) so the two read as one top-right row,
# the clock furthest right. Hides with the HUD inside puzzles.
func _build_clock() -> void:

	var clock : ClockWidget = ClockWidget.new()
	add_child(clock)
	clock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	clock.offset_top = 12.0
	clock.offset_bottom = 12.0 + ClockWidget.H
	clock.offset_right = -14.0
	clock.offset_left = -14.0 - ClockWidget.W


func _on_purse_resized() -> void:

	_purse.pivot_offset = _purse.size * 0.5


# R opens the backpack straight to the Profile — your standings with the cast now live there as worded
# tiers (the standalone Stardew-style Hearts tab was retired 2026-06-16).
func _open_profile() -> void:

	_open_inventory_tab("profile")


# Open the backpack straight to [param tab] ("items" / "profile" / …), or
# CLOSE it if it's already showing that page (so a button toggles its own
# page). Shared by the quick-access menu + the R key.
func _open_inventory_tab(tab: String) -> void:

	ChatBox.drop_focus()   # a mouse click on a HUD button leaves the chat bar (no stuck focus / world-freeze)
	if not visible:
		return
	if Overlay.is_active and not UserPanel.is_open():
		return
	if UserPanel.is_open() and UserPanel.current_tab() == tab:
		UserPanel.close()
	else:
		UserPanel.open(tab)




# --- Inventory open/close --------------------------------------------

## True while the backpack overlay is open. Read by [BaseLocation] +
## [Player] so the world freezes and ESC stays owned by the bag.
func is_inventory_open() -> bool:

	return UserPanel != null and UserPanel.is_open()


# The backpack is NOT a HUD element — it lives off-screen and is summoned
# with ESC (per Troy: no bag in the HUD). Won't OPEN on top of an active
# NPC/lore dialog, but a bag that's somehow already open can always close.
func _toggle_inventory() -> void:

	ChatBox.drop_focus()   # a mouse click on a HUD button leaves the chat bar (no stuck focus / world-freeze)
	if not visible:
		return
	if Overlay.is_active and not UserPanel.is_open():
		return
	UserPanel.toggle()


# ESC priority: close whatever's open first (backpack → chat log); if nothing is, open the PAUSE MENU
# (Resume / Options / Quit). The Journal owns its own ESC (it pauses + processes-always, so the HUD
# doesn't get the key while it's up). Troy 2026-06-07: ESC = pause menu; Options/Quit moved out of the bag.
func _on_escape() -> void:

	if UserPanel.is_open():
		UserPanel.close()
		return
	if ChatBox != null and ChatBox.is_log_open():
		ChatBox.close_log()
		return
	PauseMenu.open(self)


# Mobile: an on-screen menu button (top-left CORNER — the purse is top-right) runs the Esc chain — no Esc on a
# phone. Closes an open panel/log first, else opens the pause menu (Resume / Options / Save & Quit).
# Gated on TouchEnv so the desktop HUD is unchanged (Troy 2026-06-12).
func _build_touch_menu_button() -> void:

	if not TouchEnv.is_touch():
		return
	var btn : Button = Button.new()
	btn.text = "≡"
	btn.custom_minimum_size = Vector2(54.0, 54.0)
	btn.add_theme_font_size_override("font_size", 30)
	# Themed chrome (adapts light/dark) — accent label on a card surface with the gold-tan rim.
	UiStyle.style_button(btn, Palette.ACCENT, Palette.CARD_BG, Palette.BORDER)
	btn.anchor_left = 0.0
	btn.anchor_top = 0.0
	btn.offset_left = 16.0
	btn.offset_top = 16.0
	btn.offset_right = 16.0 + 54.0
	btn.offset_bottom = 16.0 + 54.0
	btn.pressed.connect(_on_escape)
	add_child(btn)


func _unhandled_input(event: InputEvent) -> void:

	# ESC summons / dismisses the backpack in the overworld. The HUD owns
	# ESC here (consumes it) so it never falls through to a leave-to-title.
	if not visible:
		return
	if ChatBox.is_typing():
		return   # typing in chat — keys go to the text, not the backpack/journal
	if event.is_action_pressed("interact"):
		_toggle_inventory()   # E opens/closes the backpack (E no longer interacts — Troy: click-based world)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_on_escape()          # ESC: close whatever's open, else open the pause menu (Troy 2026-06-07)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J:
		UserPanel.open("objectives")   # J → the Objectives tab (the "!" journal popup was retired)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I:
		_toggle_inventory()   # the backpack key the docs have always promised (alongside ESC)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_open_profile()
		get_viewport().set_input_as_handled()


# Self-heal on becoming visible: replay any deferred purse change that
# landed while we were hidden inside a puzzle.
func _on_visibility_changed() -> void:

	if not visible:
		# Safety: never leave the panel open while the HUD is hidden (e.g. entering a puzzle).
		if is_instance_valid(UserPanel) and UserPanel.is_open():
			UserPanel.close()
		return
	flush_pending_change()
	flush_pending_wood_change()


## A trophy was just earned — pop the notification on the tree ROOT so it shows even while
## this HUD is hidden (e.g. earning Skirmisher mid-boarding). Self-frees after its animation.
func _on_trophy_earned(_id: String, trophy_name: String) -> void:

	if is_inside_tree():
		get_tree().root.add_child(TrophyToast.create(trophy_name))


func _on_coins_changed(new_total: int) -> void:

	# Defer everything if we're inside a puzzle (HUD hidden) — the
	# count-up tween, bounce, and floater would all play invisibly
	# and finish before the player ever sees them. Stash the new
	# total; [method flush_pending_change] replays it on the way out.
	if not visible:
		_pending_total = new_total
		return
	var delta : int = new_total - _displayed
	if delta == 0:
		return
	_start_count_tween(new_total)
	_play_bounce(delta)
	_spawn_floater(delta)


## Called by [PuzzleScene._exit_tree] right after the HUD is made
## visible again. If coin changes happened while we were hidden,
## replays the full count-up + bounce + floater animation so the
## player sees the net gain/loss they earned from the puzzle.
# The bag took an item in — BUMP the Backpack button (no count, just the bounce, per Troy's rule). If
# the HUD is hidden (inside a puzzle), defer it; flush_pending_wood_change replays it on return.
func _on_inventory_changed() -> void:

	if visible:
		UserPanel.bump_backpack()
	else:
		_bag_pending = true


# Replay a deferred backpack bump on the way back to the overworld (a puzzle banked wood/ore while hidden).
# Called by PuzzleScene._exit_tree + the visibility self-heal — mirrors flush_pending_change for gold.
func flush_pending_wood_change() -> void:

	if not _bag_pending:
		return
	_bag_pending = false
	UserPanel.bump_backpack()


func flush_pending_change() -> void:

	if _pending_total < 0:
		return
	var new_total : int = _pending_total
	_pending_total = -1
	var delta : int = new_total - _displayed
	if delta == 0:
		return
	_start_count_tween(new_total)
	_play_bounce(delta)
	_spawn_floater(delta)


# --- Animation helpers -----------------------------------------------

# Tween the integer _displayed value up or down to the new total,
# refreshing the label on each step. Cancels any in-flight tween so
# rapid consecutive awards don't fight each other — the new tween
# picks up from wherever the old one stopped.
func _start_count_tween(target: int) -> void:

	if _count_tween != null and _count_tween.is_valid():
		_count_tween.kill()
	_count_tween = create_tween()
	_count_tween.tween_method(_set_displayed, _displayed, target, COUNT_DURATION) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


# tween_method requires a settable callback — Variant int is fine.
func _set_displayed(value: int) -> void:

	_displayed = value
	_refresh()


func _refresh() -> void:

	_coin_label.text = _format_amount(_displayed)


# 1234567 → "1,234,567". Big numbers are unlikely in MVP scope but
# this future-proofs the panel and keeps the rendering tidy.
func _format_amount(n: int) -> String:

	var s : String = str(absi(n))
	var out : String = ""
	var c : int = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c == 3 and i > 0:
			out = "," + out
			c = 0
	if n < 0:
		out = "-" + out
	return out


# Visual feedback on every value change. Gains and losses get visually
# distinct animations so the player feels the difference, not just a
# colored bounce in both directions:
#   • gain → upward scale bounce + green flash (celebratory)
#   • loss → squish-and-shake + sustained red flash (the purse "took a hit")
func _play_bounce(delta: int) -> void:

	if _bounce_tween != null and _bounce_tween.is_valid():
		_bounce_tween.kill()
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	# Animate ONLY scale + rotation, NEVER position — the purse is a
	# MarginContainer child, so the container owns its layout position
	# (right-aligned via size-flags, not (0,0)). Writing position here
	# stranded the purse off its anchor after a loss-shake. Scale and
	# rotation are not container-managed, so they're safe to tween.
	_purse.pivot_offset = _purse.size * 0.5
	_purse.scale = Vector2.ONE
	_purse.rotation = 0.0
	if delta > 0:
		_play_gain_bounce()
	else:
		_play_loss_shake()


# Original celebratory bounce — scale up 1.18× then settle, with a
# brief green label flash.
func _play_gain_bounce() -> void:

	_bounce_tween = create_tween().set_parallel(true)
	_bounce_tween.tween_property(_purse, "scale",
		Vector2(BOUNCE_SCALE, BOUNCE_SCALE), BOUNCE_DURATION * 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bounce_tween.chain().tween_property(_purse, "scale",
		Vector2.ONE, BOUNCE_DURATION * 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_coin_label.modulate = COLOR_GAIN
	_bounce_tween.chain().tween_property(_coin_label, "modulate",
		Color.WHITE, BOUNCE_DURATION * 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# Loss feedback — the purse compresses vertically (a coin pressed flat),
# shakes left-right a few pixels, holds a deeper red flash longer, then
# settles. Reads as "you got hit", not "you got rewarded in red".
func _play_loss_shake() -> void:

	_bounce_tween = create_tween().set_parallel(true)
	# Squish — taller compression than horizontal so it reads as
	# weight/loss rather than the upward bounce of a gain.
	_bounce_tween.tween_property(_purse, "scale",
		Vector2(1.06, 0.82), BOUNCE_DURATION * 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bounce_tween.chain().tween_property(_purse, "scale",
		Vector2.ONE, BOUNCE_DURATION * 0.65) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Lateral wobble — a quick rotation jitter (NOT position: the purse is
	# container-managed, so a position write would strand it off-anchor).
	# Rotates around the centre pivot, runs parallel to the squish.
	_shake_tween = create_tween()
	_shake_tween.tween_property(_purse, "rotation", deg_to_rad(-5.0), 0.05)
	_shake_tween.tween_property(_purse, "rotation", deg_to_rad(5.0), 0.07)
	_shake_tween.tween_property(_purse, "rotation", deg_to_rad(-3.0), 0.06)
	_shake_tween.tween_property(_purse, "rotation", 0.0, 0.06)
	# Red flash held nearly twice as long as a gain — losses get a
	# beat of "yeah, that hurt" before fading.
	_coin_label.modulate = COLOR_LOSS
	_bounce_tween.parallel().tween_property(_coin_label, "modulate",
		Color.WHITE, BOUNCE_DURATION * 1.2) \
		.set_delay(BOUNCE_DURATION * 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# Floats a "+N" / "-N" label below the purse panel as cosmetic feedback
# alongside the count-up tween. Both directions get a slow, readable
# drift so the player can actually parse the number — earlier "fast
# accelerating drop" for losses ended up blink-and-miss invisible.
# Gains read brass-bright; losses read deeper red and linger ~40%
# longer for the "yeah, that hurt" beat.
const FLOATER_BOX_W : float = 160.0
const FLOATER_BOX_H : float = 42.0

func _spawn_floater(delta: int) -> void:

	var label : Label = Label.new()
	label.text = ("+%d" if delta > 0 else "-%d") % absi(delta)
	label.add_theme_font_size_override("font_size", 24 if delta > 0 else 28)
	label.add_theme_color_override("font_color", COLOR_GAIN if delta > 0 else COLOR_LOSS)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Lock the box dimensions so the centered text doesn't get pulled
	# off-axis when the Label autosizes to its content.
	label.custom_minimum_size = Vector2(FLOATER_BOX_W, FLOATER_BOX_H)
	label.size = Vector2(FLOATER_BOX_W, FLOATER_BOX_H)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anchor on the chip-count label's center + the user-calibrated
	# FLOATER_OFFSET_X/Y. The label tracks panel layout as the chip
	# count grows (HBox + PanelContainer shrink-to-fit), so this anchor
	# stays consistent at any stack size. Tries to derive the panel's
	# visible center mathematically were unreliable — the rect/size
	# values disagree with the actual drawn area. The offsets close
	# the gap empirically.
	var label_center_x : float = _coin_label.global_position.x + _coin_label.size.x * 0.5
	var label_center_y : float = _coin_label.global_position.y + _coin_label.size.y * 0.5
	label.position = Vector2(
		label_center_x - FLOATER_BOX_W * 0.5 + FLOATER_OFFSET_X,
		label_center_y - FLOATER_BOX_H * 0.5 + FLOATER_OFFSET_Y)
	add_child(label)
	# Distinct timing per direction:
	#   • gain: 1.1s, quart ease-out — drifts in, settles.
	#   • loss: 1.55s, quad ease-out — slower drop, longer linger.
	var rise : float
	var lifetime : float
	var trans : int
	if delta > 0:
		rise = FLOATER_RISE
		lifetime = FLOATER_LIFETIME
		trans = Tween.TRANS_QUART
	else:
		rise = FLOATER_RISE * 1.3
		lifetime = FLOATER_LIFETIME * 1.4
		trans = Tween.TRANS_QUAD
	var tw : Tween = create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y + rise, lifetime) \
		.set_trans(trans).set_ease(Tween.EASE_OUT)
	# Hold the value visible for ~60% of the lifetime before fading,
	# so the player has time to read it.
	tw.tween_property(label, "modulate:a", 0.0, lifetime * 0.4) \
		.set_delay(lifetime * 0.6)
	tw.chain().tween_callback(label.queue_free)
