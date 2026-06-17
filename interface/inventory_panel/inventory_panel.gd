## The player's USER PANEL — a YPP "Sunshine-widget"-style foldable, tabbed side panel docked on the LEFT.
## A vertical icon TAB RAIL (always on screen) opens a content pane: 📖 Tutorial · 🎒 Backpack · ♥ Hearts ·
## ★ Profile. Click a tab to open it; click the OPEN tab (or Esc) to fold it away — only one open at a time
## (the exact YPP fold mechanic). Researched from YPPedia (Troy 2026-06-07; YPP docks right, we dock left).
##
## Still named InventoryPanel / class InventoryPanel so the HUD's existing wiring (open / close / toggle /
## is_open / current_tab) keeps working. Lives inside the [HUD] CanvasLayer (so the rail shows in the
## overworld + hides in puzzles with the rest of the HUD; in-puzzle tutorials are handled by [PuzzleScene]).
##
## Built entirely in code — the slot grid is dynamic (rebuilds to [member PlayerState.inventory_capacity]).
@tool
class_name InventoryPanel
extends Control


const SLOT_SIZE : float = 64.0
const SLOT_SEP : float = 8.0
const COLS : int = 6   # slots per row in the grid

const COLOR_DIM : Color = Color(0, 0, 0, 0.5)

## The Tutorial tab's default text when you're NOT in a puzzle (the overworld controls). In a puzzle,
## PuzzleScene.set_help_text replaces it with THAT puzzle's how-to — only ever what's relevant to where you are.
## DESKTOP wording; touch uses [constant TOUCH_OVERWORLD_HELP] via [method _overworld_help].
const OVERWORLD_HELP : String = ("Around the islands\n\n"
	+ "• WASD / arrow keys — move\n"
	+ "• Click a person, door, or work-site (on it, while close) to interact\n"
	+ "• E — open your pack\n"
	+ "• Esc — pause")
const TOUCH_OVERWORLD_HELP : String = ("Around the islands\n\n"
	+ "• Use the stick (bottom-left) to move\n"
	+ "• Tap a person, door, or work-site (on it, while close) to interact\n"
	+ "• Pinch to zoom in, swipe with one finger to look around\n"
	+ "• Your pack + menus are on the tab rail (right edge)")

## The left tab rail, top→down. Each: tab id · MenuGlyph kind · hover tip.
const RAIL_TABS : Array = [
	{"tab": "ayo", "glyph": "bell", "tip": "Ayo! — claim your trophies + notices"},
	{"tab": "objectives", "glyph": "scroll", "tip": "Objectives — your current goals"},
	{"tab": "tutorial", "glyph": "book", "tip": "Tutorials — how to play"},
	{"tab": "items", "glyph": "bag", "tip": "Backpack — your items  (E)"},
	{"tab": "profile", "glyph": "star", "tip": "Profile — rank, trophies, skills + your hearties  (R)"},
]


var _dim : ColorRect
var _window : PanelContainer
## The "items" (Backpack) page — a Weapon equip bar above the backpack slot grid.
var _items_page : VBoxContainer
var _gold_label : Label            # gold total, shown here now (the always-on HUD purse was retired)
var _bag_row : HBoxContainer       # the Stardew-style "buy a bigger backpack" upgrade row
var _grid : GridContainer
## The Profile tab — a [ProfileView] (rank, reputation, fleet, trophies, mastery standings + your
## hearties as worded tiers — the standalone Stardew-style Hearts tab was retired 2026-06-16).
var _profile_view : ProfileView
## The Tutorial tab — the how-to for the CURRENT scene (the puzzle you're in, or the overworld controls).
var _tutorial_page : Control
## The Ayo! tab — claim earned trophies + notices (our reskin of YPP's "Ahoy").
var _ayo_page : Control
var _ayo_list : VBoxContainer
var _ayo_badge : Label
## The Objectives tab — your current goals (from PlayerState.current_quests), folded in from the journal.
var _obj_page : Control
var _obj_list : VBoxContainer
## The Tutorial tab's body label — shows the CURRENT context's how-to (the puzzle you're in, or the
## overworld controls), set via [method set_puzzle_help]. Never the whole library.
var _current_help_label : Label
var _puzzle_help_text : String = ""
var _rail_buttons : Dictionary = {}   # tab id → its rail Button (for active-state styling)
## "ayo" / "objectives" / "tutorial" / "items" / "profile".
var _current_tab : String = "items"
var _is_open : bool = false           # is the content pane EXPANDED (the rail is always visible)

# The tab rail (the icon strip) can be TUCKED off-screen right + pulled back (Troy 2026-06-12). RAIL_EDGE_MARGIN
# is how far its right edge sits from the screen edge when shown; the handle is a slim grip just left of it.
const RAIL_EDGE_MARGIN : float = 12.0
const HANDLE_W : float = 26.0
const HANDLE_GAP : float = 6.0
var _rail_holder : PanelContainer     # the icon strip (right-anchored + vertically CENTERED; slides off-screen)
var _rail_toggle : Button             # the slim handle left of the strip — tucks it away / pulls it back
var _rail_collapsed : bool = false


func _ready() -> void:

	# Cover the whole screen so the right-docked rail/pane + the dim anchor to the real screen edges.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_skeleton()
	_fit_viewport()   # MUST force the size: a Control .new()'d under a CanvasLayer (our autoload) is NOT
	if not Engine.is_editor_hint():   # auto-laid-out to the viewport the way a scene-placed one is → it'd
		var vp : Viewport = get_viewport()   # stay (0,0) and the right-anchored rail would sit off-screen.
		if vp != null:
			vp.size_changed.connect(_fit_viewport)
		PlayerState.inventory_changed.connect(_on_inventory_changed)
		PlayerState.trophy_earned.connect(_on_trophies_changed)
		PlayerState.trophy_claimed.connect(_on_trophies_changed)
		PlayerState.challenges_changed.connect(_on_trophies_changed)
		PlayerState.objective_changed.connect(_on_objectives_changed)
		PlayerState.coins_changed.connect(_on_objectives_changed)
		PlayerState.coins_changed.connect(_refresh_gold)   # keep the Backpack's gold total live
		_update_ayo_badge()


# Fill the viewport (and keep filling it on resize) so the right-edge rail + pane land at the screen edge.
func _fit_viewport() -> void:

	var vp : Viewport = get_viewport()
	if vp == null:
		return
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = vp.get_visible_rect().size


func _build_skeleton() -> void:

	# Dim backdrop — only while the pane is OPEN; a click on it folds the panel.
	_dim = ColorRect.new()
	_dim.color = COLOR_DIM
	_dim.anchor_right = 1.0
	_dim.anchor_bottom = 1.0
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)

	# Left-docked content window (hidden until a tab opens). Anchored top-left, just right of the rail,
	# grows to fit its page (so the wide Hearts/Profile views still fit).
	_window = PanelContainer.new()
	_window.add_theme_stylebox_override("panel", _window_style())
	# Corner-pin the window just LEFT of the rail + BELOW the top HUD, growing left + down to fit its page
	# (equal left/right + top/bottom offsets at the pin point + grow directions — a shrink container). The right
	# edge must clear the WHOLE rail apparatus (the icon strip ~84px + its tuck HANDLE ~26px + margins), else the
	# window's right-edge content slides under the rail — RAIL_CLEARANCE is that gap (fixes the side-panel overlap).
	const RAIL_CLEARANCE : float = 140.0
	_window.anchor_left = 1.0
	_window.anchor_right = 1.0
	_window.anchor_top = 0.0
	_window.anchor_bottom = 0.0
	_window.offset_left = -RAIL_CLEARANCE
	_window.offset_right = -RAIL_CLEARANCE
	_window.offset_top = 150.0
	_window.offset_bottom = 150.0
	_window.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_window.grow_vertical = Control.GROW_DIRECTION_END
	_window.visible = false
	add_child(_window)

	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_window.add_child(vbox)

	# Tutorial page — a scrollable how-to library (the "?" replacement).
	_tutorial_page = _build_tutorial_page()
	vbox.add_child(_tutorial_page)

	# Ayo! page — claim earned trophies + notices.
	_ayo_page = _build_ayo_page()
	vbox.add_child(_ayo_page)

	# Objectives page — your current goals (folded in from the journal).
	_obj_page = _build_objectives_page()
	vbox.add_child(_obj_page)

	# Items page — the backpack slot grid (weapons are items in it; double-click a weapon to equip) + a
	# Stardew-style "bigger bag" upgrade row beneath.
	_items_page = VBoxContainer.new()
	_items_page.add_theme_constant_override("separation", 10)
	vbox.add_child(_items_page)
	# GOLD — moved here off the always-on top-right HUD purse (Troy 2026-06-16). A coin + the total,
	# refreshed live on coins_changed (see _refresh_gold).
	var gold_row : HBoxContainer = HBoxContainer.new()
	gold_row.add_theme_constant_override("separation", 8)
	_items_page.add_child(gold_row)
	var coin : Label = Label.new()
	coin.text = "◉"
	coin.add_theme_font_size_override("font_size", 24)
	coin.add_theme_color_override("font_color", Color(0.98, 0.80, 0.30, 1.0))
	coin.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	coin.add_theme_constant_override("outline_size", 3)
	gold_row.add_child(coin)
	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 22)
	UiStyle.apply_primary(_gold_label)   # the gold NUMBER reads as body text now (the coin icon stays gold)
	_gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold_row.add_child(_gold_label)
	_refresh_gold()
	var whint : Label = Label.new()
	whint.text = "Double-click a weapon to equip it"
	whint.add_theme_font_size_override("font_size", 13)
	whint.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	_items_page.add_child(whint)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", int(SLOT_SEP))
	_grid.add_theme_constant_override("v_separation", int(SLOT_SEP))
	_items_page.add_child(_grid)
	_bag_row = HBoxContainer.new()
	_bag_row.add_theme_constant_override("separation", 8)
	_items_page.add_child(_bag_row)
	# TRASH drop-target — drag any item here to throw it away (e.g. a redundant door key). Right-aligned row.
	var trash_row : HBoxContainer = HBoxContainer.new()
	trash_row.add_theme_constant_override("separation", 8)
	trash_row.alignment = BoxContainer.ALIGNMENT_END
	var trash_hint : Label = Label.new()
	trash_hint.text = "Drag an item here to discard  →"
	trash_hint.add_theme_font_size_override("font_size", 12)
	trash_hint.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	trash_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	trash_row.add_child(trash_hint)
	trash_row.add_child(InventoryTrash.new())
	_items_page.add_child(trash_row)

	# Profile page (hidden until its tab is picked) — it now also hosts the hearties list.
	_profile_view = ProfileView.new()
	_profile_view.visible = false
	vbox.add_child(_profile_view)

	# Hint line.
	var hint : Label = Label.new()
	hint.text = "Click the tab again, or press  Esc,  to close"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	# The RAIL last, so it draws on top of the dim and stays clickable while the pane is open.
	_build_rail()
	_update_rail_styles()


# The always-visible tab rail — a slim brass strip of icon buttons, vertically CENTERED on the RIGHT edge
# (between the top purse and the bottom Chat button). A slim handle just left of it TUCKS the strip off-screen
# to the right (animated) + pulls it back, so it never crowds the play area. Two separately-anchored nodes (NOT
# an HBox — a zero-width grown anchor fails to lay a multi-child container out), Troy 2026-06-12.
func _build_rail() -> void:

	# The strip — right-anchored, vertically centered, grows LEFT to fit its icons (the proven _window pattern).
	_rail_holder = PanelContainer.new()
	_rail_holder.add_theme_stylebox_override("panel", _rail_bg_style())
	_rail_holder.anchor_left = 1.0
	_rail_holder.anchor_right = 1.0
	_rail_holder.anchor_top = 0.5
	_rail_holder.anchor_bottom = 0.5
	_rail_holder.offset_left = -RAIL_EDGE_MARGIN
	_rail_holder.offset_right = -RAIL_EDGE_MARGIN
	_rail_holder.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_rail_holder.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_rail_holder)
	var col : VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	_rail_holder.add_child(col)
	for def in RAIL_TABS:
		var btn : Button = _make_rail_button(String(def["glyph"]), String(def["tab"]), String(def["tip"]))
		_rail_buttons[String(def["tab"])] = btn
		col.add_child(btn)
	# Jobs — a LAUNCHER (opens the Shoppe Jobs board), not a pane tab. Absorbed from the old quick-menu so
	# Mining/Woodcutting jobs stay reachable from the consolidated rail.
	var jobs_btn : Button = _make_rail_button("jobs", "", "Shoppe Jobs — Mining & Woodcutting", _open_jobs)
	_style_rail_button(jobs_btn, false)
	col.add_child(jobs_btn)

	# The tuck handle — a separate right-anchored, vertically-centered grip parked just LEFT of the strip. It
	# animates in tandem with the strip (toggle_rail). Added LAST so it draws above the dim + pane.
	_rail_toggle = _make_rail_handle()
	_rail_toggle.anchor_left = 1.0
	_rail_toggle.anchor_right = 1.0
	_rail_toggle.anchor_top = 0.5
	_rail_toggle.anchor_bottom = 0.5
	add_child(_rail_toggle)
	_rail_holder.resized.connect(_layout_handle)   # re-park once the strip measures its width
	_layout_handle()


# A slim vertical handle that TUCKS the rail off-screen right / pulls it back.
func _make_rail_handle() -> Button:

	var b : Button = Button.new()
	var h : float = 84.0 if TouchEnv.is_touch() else 64.0
	b.custom_minimum_size = Vector2(HANDLE_W, h)
	b.text = "›"   # › = tuck away to the right (shown); flips to ‹ (pull back) when tucked
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.tooltip_text = "Hide / show the side tabs"
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Palette.ACCENT)
	for state in ["normal", "hover", "pressed"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		s.bg_color = Palette.CARD_BG if state == "pressed" else Color(Palette.PANEL_BG_DARK.r, Palette.PANEL_BG_DARK.g, Palette.PANEL_BG_DARK.b, 0.92)
		s.border_color = Color(Palette.BORDER.r, Palette.BORDER.g, Palette.BORDER.b, 0.6)
		s.set_border_width_all(2)
		s.corner_radius_top_left = 11
		s.corner_radius_bottom_left = 11
		s.corner_radius_top_right = 0
		s.corner_radius_bottom_right = 0
		b.add_theme_stylebox_override(state, s)
	b.pressed.connect(toggle_rail)
	return b


# Width of the icon strip once laid out (a sensible fallback before it measures).
func _strip_width() -> float:

	var w : float = _rail_holder.size.x if _rail_holder != null else 0.0
	return w if w > 1.0 else 84.0


# Park the handle: vertically centered, and horizontally just LEFT of the strip (shown) or at the edge (tucked).
func _layout_handle() -> void:

	if _rail_toggle == null:
		return
	var hh : float = _rail_toggle.custom_minimum_size.y
	_rail_toggle.offset_top = -hh * 0.5
	_rail_toggle.offset_bottom = hh * 0.5
	var right_off : float = -RAIL_EDGE_MARGIN if _rail_collapsed else -(RAIL_EDGE_MARGIN + _strip_width() + HANDLE_GAP)
	_rail_toggle.offset_right = right_off
	_rail_toggle.offset_left = right_off - HANDLE_W


## Tuck the tab rail off-screen to the right (or pull it back), animated — the handle stays at the edge while
## tucked, so you can pull it back. The toggle the player taps to declutter the play area (Troy 2026-06-12).
func toggle_rail() -> void:

	if _rail_holder == null or _rail_toggle == null:
		return
	_rail_collapsed = not _rail_collapsed
	if _rail_collapsed and _is_open:
		close()   # don't strand an open pane behind a tucked rail
	var strip_w : float = _strip_width()
	var strip_off : float = (strip_w + RAIL_EDGE_MARGIN) if _rail_collapsed else -RAIL_EDGE_MARGIN
	var handle_off : float = -RAIL_EDGE_MARGIN if _rail_collapsed else -(RAIL_EDGE_MARGIN + strip_w + HANDLE_GAP)
	_rail_toggle.text = "‹" if _rail_collapsed else "›"
	var tw : Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_rail_holder, "offset_left", strip_off, 0.24)
	tw.tween_property(_rail_holder, "offset_right", strip_off, 0.24)
	tw.tween_property(_rail_toggle, "offset_right", handle_off, 0.24)
	tw.tween_property(_rail_toggle, "offset_left", handle_off - HANDLE_W, 0.24)


func _make_rail_button(glyph: String, tab: String, tip: String, launcher: Callable = Callable()) -> Button:

	var btn : Button = Button.new()
	var rs : float = 60.0 if TouchEnv.is_touch() else 46.0   # bigger touch targets on a phone (Troy 2026-06-12)
	btn.custom_minimum_size = Vector2(rs, rs)
	btn.tooltip_text = tip
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var icon : MenuGlyph = MenuGlyph.new()
	icon.kind = glyph
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	if tab == "ayo":
		_ayo_badge = _make_badge()
		btn.add_child(_ayo_badge)
	if launcher.is_valid():
		btn.pressed.connect(launcher)
	else:
		btn.pressed.connect(_on_rail_pressed.bind(tab))
	return btn


# Jobs rail launcher — fold the pane, then open the Shoppe Jobs board (Mining / Woodcutting).
func _open_jobs() -> void:

	ChatBox.drop_focus()
	close()
	ShoppeJobsBoard.open(self)


## BUMP the Backpack rail tab (you took an item in) — the feedback the old HUD bag button gave. Called by
## the HUD on inventory_changed (deferred + replayed if it happened while the HUD was hidden in a puzzle).
func bump_backpack() -> void:

	var btn : Variant = _rail_buttons.get("items", null)
	if btn != null and is_instance_valid(btn):
		btn.scale = Vector2.ONE
		Juice.bump(btn, 1.22, 0.26)


# Click a rail tab: open it — or FOLD if it's already the open one (the YPP "click the open tab" mechanic).
func _on_rail_pressed(tab: String) -> void:

	ChatBox.drop_focus()
	if _is_open and _current_tab == tab:
		close()
	else:
		open(tab)


# --- Ayo! tab (claim earned trophies + notices) ----------------------

func _build_ayo_page() -> Control:

	var scroll : ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(480.0, 392.0)
	scroll.visible = false
	_ayo_list = VBoxContainer.new()
	_ayo_list.add_theme_constant_override("separation", 10)
	_ayo_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_ayo_list)
	return scroll


# Rebuild the Ayo! list: pending duel challenges (Accept / Reject) + earned-but-unclaimed trophies as Claim
# cards (or an all-caught-up line). Challenges show FIRST — someone's waiting on your answer.
func _refresh_ayo() -> void:

	if _ayo_list == null:
		return
	for c in _ayo_list.get_children():
		c.queue_free()
	var head : Label = Label.new()
	head.text = "Ayo!"
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", Palette.ACCENT)
	_ayo_list.add_child(head)
	var challenges : Array = PlayerState.pending_challenges
	var ids : Array = PlayerState.unclaimed_trophy_ids()
	if challenges.is_empty() and ids.is_empty():
		var none : Label = Label.new()
		none.text = "No new tidings — you're all caught up."
		none.add_theme_font_size_override("font_size", 14)
		none.add_theme_color_override("font_color", Palette.TEXT_MUTED)
		_ayo_list.add_child(none)
		return
	if not challenges.is_empty():
		_ayo_list.add_child(_ayo_subhead("You've been challenged to a duel!", Palette.ACCENT))
		for nm in challenges.duplicate():   # duplicate — Reject mutates the live array mid-loop
			_ayo_list.add_child(_make_challenge_card(String(nm)))
	if not ids.is_empty():
		_ayo_list.add_child(_ayo_subhead("New trophies earned — claim them!", Palette.ACCENT))
		for id in ids:
			_ayo_list.add_child(_make_claim_card(String(id)))


func _ayo_subhead(text: String, col: Color) -> Label:

	var sub : Label = Label.new()
	sub.text = text
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", col)
	return sub


# A duel-challenge notice: "<NPC> wants to spar" with Accept (launch the Skirmish duel) + Reject (decline).
func _make_challenge_card(npc_name: String) -> Control:

	var prof : NpcPersonality = NpcRegistry.by_name(npc_name)
	var tint : Color = prof.portrait_color if prof != null else Color(0.8, 0.5, 0.4, 1.0)
	var card : PanelContainer = PanelContainer.new()
	var s : StyleBoxFlat = UiStyle.card()
	s.border_color = tint.lerp(Palette.BORDER, 0.4)   # keep the per-NPC tint in the rim, on the themed card
	s.set_border_width_all(2)
	s.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", s)
	var hb : HBoxContainer = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	card.add_child(hb)
	var swords : MenuGlyph = MenuGlyph.new()
	swords.kind = "swords"
	swords.custom_minimum_size = Vector2(34.0, 34.0)
	swords.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(swords)
	var col : VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(col)
	var nm : Label = Label.new()
	nm.text = "%s wants to spar!" % npc_name
	nm.add_theme_font_size_override("font_size", 16)
	nm.add_theme_color_override("font_color", Palette.ACCENT)
	col.add_child(nm)
	var ds : Label = Label.new()
	ds.text = "A friendly Skirmish bout — your board against theirs."
	ds.add_theme_font_size_override("font_size", 13)
	ds.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD
	ds.custom_minimum_size = Vector2(220.0, 0.0)
	col.add_child(ds)
	var btns : VBoxContainer = VBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	btns.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(btns)
	var accept : Button = _challenge_button("Accept", Color(0.20, 0.30, 0.14, 0.95), Color(0.55, 0.82, 0.42, 0.8))
	accept.pressed.connect(_on_accept_challenge.bind(npc_name))
	btns.add_child(accept)
	var reject : Button = _challenge_button("Reject", Color(0.30, 0.16, 0.14, 0.95), Color(0.78, 0.45, 0.40, 0.8))
	reject.pressed.connect(_on_reject_challenge.bind(npc_name))
	btns.add_child(reject)
	return card


# A small pill button for the challenge card (Accept / Reject), tinted by bg/border.
func _challenge_button(text: String, bg: Color, border: Color) -> Button:

	var b : Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", border.lightened(0.35))
	for st in ["normal", "hover", "pressed"]:
		var bs : StyleBoxFlat = StyleBoxFlat.new()
		var c : Color = bg
		if st == "hover":
			c = c.lightened(0.12)
		elif st == "pressed":
			c = c.darkened(0.10)
		bs.bg_color = c
		bs.border_color = border
		bs.set_border_width_all(1)
		bs.set_corner_radius_all(7)
		bs.content_margin_left = 16.0
		bs.content_margin_right = 16.0
		bs.content_margin_top = 5.0
		bs.content_margin_bottom = 5.0
		b.add_theme_stylebox_override(st, bs)
	return b


# Accept → seat this NPC as the Skirmish opponent + launch the duel (mirrors the radial "Spar" / Spar post).
func _on_accept_challenge(npc_name: String) -> void:

	var prof : NpcPersonality = NpcRegistry.by_name(npc_name)
	PlayerState.clear_challenge(npc_name)   # consume the notice either way
	if prof == null:
		return   # unknown name (renamed cast?) — just drop the stale challenge
	PlayerState.skirmish_opponent = prof.resource_path
	Audio.play_sfx("whoosh")
	close()   # fold the panel before the scene cut (the duel returns to the launching scene)
	get_tree().change_scene_to_file("res://puzzles/skirmish/skirmish_duel.tscn")


# Reject → decline the bout (clears the notice; a small rapport ding — turning down a duel stings a little).
func _on_reject_challenge(npc_name: String) -> void:

	PlayerState.add_affinity(npc_name, -3)
	PlayerState.clear_challenge(npc_name)   # challenges_changed → _on_trophies_changed refreshes the list + badge
	Audio.play_sfx("click")


func _make_claim_card(id: String) -> Control:

	var info : Dictionary = _trophy_info(id)
	var card : PanelContainer = PanelContainer.new()
	var s : StyleBoxFlat = UiStyle.card()
	s.set_border_width_all(2)
	s.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", s)
	var hb : HBoxContainer = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	card.add_child(hb)
	var star : MenuGlyph = MenuGlyph.new()
	star.kind = "star"
	star.custom_minimum_size = Vector2(34.0, 34.0)
	hb.add_child(star)
	var col : VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(col)
	var nm : Label = Label.new()
	nm.text = String(info.get("name", id))
	nm.add_theme_font_size_override("font_size", 16)
	nm.add_theme_color_override("font_color", Palette.ACCENT)
	col.add_child(nm)
	var ds : Label = Label.new()
	ds.text = String(info.get("desc", ""))
	ds.add_theme_font_size_override("font_size", 13)
	ds.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD
	ds.custom_minimum_size = Vector2(300.0, 0.0)
	col.add_child(ds)
	var claim : Button = Button.new()
	claim.text = "Claim"
	claim.focus_mode = Control.FOCUS_NONE
	claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	claim.add_theme_font_size_override("font_size", 15)
	claim.add_theme_color_override("font_color", Color(0.86, 1.0, 0.72, 1.0))
	for st in ["normal", "hover", "pressed"]:
		var bs : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.20, 0.30, 0.14, 0.95)
		if st == "hover":
			bg = bg.lightened(0.12)
		elif st == "pressed":
			bg = bg.darkened(0.10)
		bs.bg_color = bg
		bs.border_color = Color(0.55, 0.82, 0.42, 0.8)
		bs.set_border_width_all(1)
		bs.set_corner_radius_all(7)
		bs.content_margin_left = 14.0
		bs.content_margin_right = 14.0
		bs.content_margin_top = 6.0
		bs.content_margin_bottom = 6.0
		claim.add_theme_stylebox_override(st, bs)
	claim.pressed.connect(_on_claim.bind(id))
	hb.add_child(claim)
	return card


func _on_claim(id: String) -> void:

	PlayerState.claim_trophy(id)
	Audio.play_sfx("powerup")   # the "accept" fanfare; trophy_claimed → _on_trophies_changed refreshes the list


func _trophy_info(id: String) -> Dictionary:

	for t in Trophies.ALL:
		if String(t["id"]) == id:
			return t
	return {}


# Refresh the Ayo! badge + (if open) the list when a trophy is earned or claimed. Optional args absorb the
# differing signal signatures (trophy_earned(id, name) vs trophy_claimed(id)).
func _on_trophies_changed(_a = null, _b = null) -> void:

	_update_ayo_badge()
	if _current_tab == "ayo":
		_refresh_ayo()


func _update_ayo_badge() -> void:

	if _ayo_badge == null:
		return
	var n : int = PlayerState.unclaimed_trophy_ids().size() + PlayerState.pending_challenges.size()
	_ayo_badge.text = str(n)
	_ayo_badge.visible = n > 0


# A small red count badge for the Ayo! rail tab (top-right corner), hidden at zero.
func _make_badge() -> Label:

	var b : Label = Label.new()
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(18.0, 18.0)
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.offset_left = -16.0
	b.offset_top = -4.0
	b.offset_right = 4.0
	b.offset_bottom = 14.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb : StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.85, 0.22, 0.22, 1.0)
	sb.set_corner_radius_all(9)
	b.add_theme_stylebox_override("normal", sb)
	b.visible = false
	return b


# --- Objectives tab (your current goals; folded in from the journal) --

func _build_objectives_page() -> Control:

	var scroll : ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(480.0, 392.0)
	scroll.visible = false
	_obj_list = VBoxContainer.new()
	_obj_list.add_theme_constant_override("separation", 10)
	_obj_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_obj_list)
	return scroll


func _refresh_objectives() -> void:

	if _obj_list == null:
		return
	for c in _obj_list.get_children():
		c.queue_free()
	var head : Label = Label.new()
	head.text = "Objectives"
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", Palette.ACCENT)
	_obj_list.add_child(head)
	var shown : int = 0
	for quest in PlayerState.current_quests():
		if bool(quest.get("done", false)):   # only what's still open, like the journal
			continue
		_obj_list.add_child(_make_quest_card(quest))
		shown += 1
	if shown == 0:
		var none : Label = Label.new()
		none.text = "All caught up! Wander Cradle Rock and talk to the folk — some may ask a small favour."
		none.add_theme_font_size_override("font_size", 14)
		none.add_theme_color_override("font_color", Palette.TEXT_MUTED)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD
		none.custom_minimum_size = Vector2(440.0, 0.0)
		_obj_list.add_child(none)


func _make_quest_card(quest: Dictionary) -> Control:

	var card : PanelContainer = PanelContainer.new()
	var s : StyleBoxFlat = UiStyle.card()
	s.set_border_width_all(2)
	s.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", s)
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var marker : Label = Label.new()
	marker.text = "!"
	marker.add_theme_font_size_override("font_size", 22)
	marker.add_theme_color_override("font_color", Color(0.96, 0.74, 0.24, 1.0))
	marker.custom_minimum_size = Vector2(20.0, 0.0)
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(marker)
	var col : VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var title : Label = Label.new()
	title.text = String(quest.get("title", ""))
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Palette.ACCENT)
	col.add_child(title)
	var detail : Label = Label.new()
	detail.text = String(quest.get("detail", ""))
	detail.add_theme_font_size_override("font_size", 13)
	detail.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail.custom_minimum_size = Vector2(380.0, 0.0)
	col.add_child(detail)
	return card


## The Backpack's gold readout (gold lives here now, not an always-on HUD purse).
func _refresh_gold(_a = null) -> void:

	if _gold_label != null:
		_gold_label.text = "%d  gold" % PlayerState.total_coins


func _on_objectives_changed(_a = null) -> void:

	if _current_tab == "objectives":
		_refresh_objectives()
	# A New Game (clear_save) emits objective_changed — recompute the trophy badge so a prior run's unclaimed
	# count doesn't linger on the fresh save (it only refreshed on trophy_earned/claimed before). Also keeps it
	# honest as gold changes (which can newly earn a coin-trophy).
	_update_ayo_badge()
	if _current_tab == "ayo":
		_refresh_ayo()


func _build_tutorial_page() -> Control:

	var scroll : ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(540.0, 392.0)
	scroll.visible = false
	var col : VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	var head : Label = Label.new()
	head.text = "How to play"
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", Palette.ACCENT)
	col.add_child(head)
	# ONLY the current context's how-to — the puzzle you're in (PuzzleScene.set_help_text) or the overworld
	# controls by default. Never a list of every puzzle.
	_current_help_label = Label.new()
	_current_help_label.text = _overworld_help()
	_current_help_label.add_theme_font_size_override("font_size", 15)
	_current_help_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_current_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_current_help_label.custom_minimum_size = Vector2(460.0, 0.0)
	col.add_child(_current_help_label)
	return scroll


func _window_style() -> StyleBoxFlat:

	return UiStyle.window(true)   # central theme: deep surface + accent rim + outer glow halo


func _rail_bg_style() -> StyleBoxFlat:

	return UiStyle.rail_bg()


# --- Rail styling ----------------------------------------------------

func _update_rail_styles() -> void:

	for tab in _rail_buttons:
		var active : bool = _is_open and _current_tab == tab
		_style_rail_button(_rail_buttons[tab], active)


func _style_rail_button(btn: Button, active: bool) -> void:

	if btn == null:
		return
	var styles : Dictionary = UiStyle.rail_button(active)   # central theme (active = accent rim + glow)
	for state in styles:
		btn.add_theme_stylebox_override(state, styles[state])


# --- Open / close (fold) ---------------------------------------------

func is_open() -> bool:

	return _is_open


func open(tab : String = "items") -> void:

	var was_open : bool = _is_open
	_is_open = true
	_switch_tab(tab)
	_dim.visible = true
	_window.visible = true
	if not was_open:
		# Fade the pane in (animate-everything; the rail itself never blinks).
		_dim.modulate.a = 0.0
		_window.modulate.a = 0.0
		var tw : Tween = create_tween().set_parallel(true)
		tw.tween_property(_dim, "modulate:a", 1.0, 0.12)
		tw.tween_property(_window, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func close() -> void:

	if not _is_open:
		return
	_is_open = false
	_update_rail_styles()
	var tw : Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_dim, "modulate:a", 0.0, 0.10)
	tw.tween_property(_window, "modulate:a", 0.0, 0.12)
	tw.set_parallel(false)
	tw.tween_callback(_hide_pane_if_closed)


func _hide_pane_if_closed() -> void:

	if not _is_open:
		_dim.visible = false
		_window.visible = false


func toggle() -> void:

	if _is_open:
		close()
	else:
		open("items")


func current_tab() -> String:

	return _current_tab


## Set the CURRENT puzzle's how-to (PuzzleScene calls this while playing; "" clears it). Surfaces at the top
## of the Tutorial tab so help sits right beside the board.
func set_puzzle_help(text: String) -> void:

	_puzzle_help_text = text
	if _current_help_label != null:
		_current_help_label.text = text if not text.strip_edges().is_empty() else _overworld_help()


# The default overworld help, worded for the platform (touch shows the stick / tap / pinch, not WASD / click / E).
func _overworld_help() -> String:

	return TOUCH_OVERWORLD_HELP if TouchEnv.is_touch() else OVERWORLD_HELP


# Switch page: show it, restyle the rail, refresh.
func _switch_tab(tab: String) -> void:

	_current_tab = tab
	if _tutorial_page != null:
		_tutorial_page.visible = (tab == "tutorial")
	if _ayo_page != null:
		_ayo_page.visible = (tab == "ayo")
	if _obj_page != null:
		_obj_page.visible = (tab == "objectives")
	if _items_page != null:
		_items_page.visible = (tab == "items")
	if _profile_view != null:
		_profile_view.visible = (tab == "profile")
	_update_rail_styles()
	_refresh()


func _on_dim_input(event: InputEvent) -> void:

	if event is InputEventMouseButton and event.pressed:
		close()


# --- Contents --------------------------------------------------------

func _on_inventory_changed() -> void:

	if _is_open and _current_tab == "items":
		_refresh()


# Refresh the active page — the slot grid, the hearts view, the standings (tutorial is static).
func _refresh() -> void:

	if _current_tab == "tutorial":
		return
	if _current_tab == "ayo":
		_refresh_ayo()
		return
	if _current_tab == "objectives":
		_refresh_objectives()
		return
	if _current_tab == "profile":
		if _profile_view != null:
			_profile_view.refresh()
		return
	if _grid == null:
		return
	# POSITIONAL grid: ONE cell per inventory slot. Weapons are ITEMS in here too (the equipped one shows a
	# gold border); double-click a weapon to equip/unequip, drag to rearrange — all the same InventorySlot.
	for child in _grid.get_children():
		child.queue_free()
	for i in PlayerState.inventory.size():
		_grid.add_child(_make_slot(PlayerState.inventory[i], i))
	_refresh_bag_row()


func _make_slot(slot: Dictionary, index: int = -1) -> Control:

	# Indexed cells are InventorySlot (native drag-drop via its _get_drag_data/_can_drop_data/_drop_data — the
	# old set_drag_forwarding silently never started a drag). Non-indexed → a plain Panel.
	var panel : Panel
	if index >= 0:
		var dslot : InventorySlot = InventorySlot.new()
		dslot.slot_index = index
		dslot.inv_panel = self
		panel = dslot
	else:
		panel = Panel.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var filled : bool = not slot.is_empty()
	# A weapon ITEM that's currently equipped gets a gold border — the only "equipped" marker now.
	var equipped : bool = filled and String(slot["id"]) == PlayerState.equipped_weapon and PlayerState.is_weapon(String(slot["id"]))
	panel.add_theme_stylebox_override("panel", _slot_style(filled, equipped))
	if not filled:
		return panel
	if PlayerState.is_weapon(String(slot["id"])):
		var wname : String = SkirmishWeapon.display_name(String(slot["id"]))
		if equipped:
			panel.tooltip_text = "%s — equipped\nDouble-click to unarm" % wname
		else:
			panel.tooltip_text = "%s\n%s\nDouble-click to equip" % [wname, String(SkirmishWeapon.DESCRIPTIONS.get(String(slot["id"]), ""))]
	var icon : Control = _make_item_icon(String(slot["id"]))
	if icon != null:
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 8.0
		icon.offset_top = 8.0
		icon.offset_right = -8.0
		icon.offset_bottom = -8.0
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
	if int(slot["count"]) > 1:   # never paint a "1" on a single item / weapon
		var count : Label = Label.new()
		count.text = str(int(slot["count"]))
		count.add_theme_font_size_override("font_size", 15)
		count.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
		count.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		count.add_theme_constant_override("outline_size", 4)
		count.set_anchors_preset(Control.PRESET_FULL_RECT)
		count.offset_left = 4.0
		count.offset_top = 4.0
		count.offset_right = -5.0
		count.offset_bottom = -3.0
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(count)
	return panel


# Per-item icon. Wood/ore reuse the procedural icons; unknown items get a placeholder swatch.
## Per-key metal hue so the three door keys read apart in the backpack (the [KeyIcon] tint).
const KEY_TINTS : Dictionary = {
	"key_mine": Color(0.66, 0.70, 0.76, 1.0),    # iron grey — the Mine
	"key_grove": Color(0.55, 0.78, 0.42, 1.0),   # mossy green — the Grove
	"key_jungle": Color(0.95, 0.78, 0.32, 1.0),  # gold — the Jungle Ordeal
}

func _make_item_icon(item_id: String) -> Control:

	if item_id == PlayerState.ITEM_WOOD:
		return WoodIcon.new()
	if item_id == PlayerState.ITEM_ORE:
		return OreIcon.new()
	if item_id.begins_with("key_"):   # door keys — one icon, tinted per key so they read apart
		var k : KeyIcon = KeyIcon.new()
		k.key_tint = KEY_TINTS.get(item_id, Color(0.95, 0.82, 0.32, 1.0))
		return k
	if PlayerState.is_weapon(item_id):   # weapons are items now — draw their weapon icon
		var w : WeaponIcon = WeaponIcon.new()
		w.weapon_id = item_id
		return w
	var placeholder : ColorRect = ColorRect.new()
	placeholder.color = Color(0.5, 0.5, 0.55, 1.0)
	return placeholder


# A translucent slot that rides centered under the cursor while dragging. Public — InventorySlot._get_drag_data
# builds the drag and calls this for the preview.
func make_drag_preview(item_id: String, count: int) -> Control:

	var root : Control = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Just the ITEM (icon + count) rides the cursor — NO slot frame (the Minecraft/Stardew look: you hold the
	# thing, not the box). A plain Control draws nothing behind the icon.
	var panel : Control = Control.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.position = Vector2(-SLOT_SIZE * 0.5, -SLOT_SIZE * 0.5)
	panel.modulate = Color(1.0, 1.0, 1.0, 0.9)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon : Control = _make_item_icon(item_id)
	if icon != null:
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 8.0
		icon.offset_top = 8.0
		icon.offset_right = -8.0
		icon.offset_bottom = -8.0
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
	if count > 1:
		var lbl : Label = Label.new()
		lbl.text = str(count)
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.offset_right = -5.0
		lbl.offset_bottom = -3.0
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(lbl)
	root.add_child(panel)
	return root


func _slot_style(filled: bool, equipped: bool = false) -> StyleBoxFlat:

	return UiStyle.slot(filled, equipped)   # central theme (equipped = accent rim + glow)


# The Stardew-style backpack-upgrade row beneath the grid: the next tier's slots + cost, or "fully upgraded".
func _refresh_bag_row() -> void:

	if _bag_row == null:
		return
	for child in _bag_row.get_children():
		child.queue_free()
	var up : Dictionary = PlayerState.next_bag_upgrade()
	if up.is_empty():
		var done : Label = Label.new()
		done.text = "Backpack fully upgraded"
		done.add_theme_font_size_override("font_size", 13)
		done.add_theme_color_override("font_color", Palette.TEXT_MUTED)
		_bag_row.add_child(done)
		return
	var cost : int = int(up["cost"])
	var lbl : Label = Label.new()
	lbl.text = "Bigger Backpack — %d slots" % int(up["slots"])
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bag_row.add_child(lbl)
	var buy : Button = Button.new()
	buy.text = "%d g" % cost
	buy.focus_mode = Control.FOCUS_NONE
	buy.disabled = PlayerState.total_coins < cost
	buy.pressed.connect(_on_buy_bag)
	_bag_row.add_child(buy)


func _on_buy_bag() -> void:

	if PlayerState.buy_bag_upgrade():
		Audio.play_sfx("thunk")   # bag bought → expand_inventory → inventory_changed → _refresh rebuilds the row
