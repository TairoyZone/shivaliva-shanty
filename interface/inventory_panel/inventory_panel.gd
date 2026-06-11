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
const COLOR_SLOT_BG : Color = Color(0.14, 0.09, 0.05, 1.0)
const COLOR_SLOT_BORDER : Color = Color(0.55, 0.38, 0.18, 1.0)
const COLOR_SLOT_EMPTY_BORDER : Color = Color(0.34, 0.24, 0.12, 1.0)
const COLOR_TITLE : Color = Color(0.98, 0.86, 0.42, 1.0)
const COLOR_COUNT : Color = Color(1.0, 0.95, 0.78, 1.0)

## The Tutorial tab's default text when you're NOT in a puzzle (the overworld controls). In a puzzle,
## PuzzleScene.set_help_text replaces it with THAT puzzle's how-to — only ever what's relevant to where you are.
const OVERWORLD_HELP : String = ("Around the islands\n\n"
	+ "• WASD / arrow keys — move\n"
	+ "• Click a person, door, or work-site (on it, while close) to interact\n"
	+ "• E — open your pack\n"
	+ "• Esc — pause")

## The left tab rail, top→down. Each: tab id · MenuGlyph kind · hover tip.
const RAIL_TABS : Array = [
	{"tab": "ayo", "glyph": "bell", "tip": "Ayo! — claim your trophies + notices"},
	{"tab": "objectives", "glyph": "scroll", "tip": "Objectives — your current goals"},
	{"tab": "tutorial", "glyph": "book", "tip": "Tutorials — how to play"},
	{"tab": "items", "glyph": "bag", "tip": "Backpack — your items  (E)"},
	{"tab": "relationships", "glyph": "heart", "tip": "Hearties — your bonds with the cast  (R)"},
	{"tab": "profile", "glyph": "star", "tip": "Profile — your rank, trophies, and skills"},
]


var _dim : ColorRect
var _window : PanelContainer
## The "items" (Backpack) page — a Weapon equip bar above the backpack slot grid.
var _items_page : VBoxContainer
var _weapon_bar : HBoxContainer
var _grid : GridContainer
## The Hearts tab — a [RelationshipsView] (Stardew-style social page).
var _hearts_view : RelationshipsView
## The Profile tab — a [ProfileView] (rank, reputation, fleet, trophies, mastery standings).
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
## "tutorial" / "items" / "relationships" / "profile".
var _current_tab : String = "items"
var _is_open : bool = false           # is the content pane EXPANDED (the rail is always visible)


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
	# (equal left/right + top/bottom offsets at the pin point + grow directions — a shrink container).
	_window.anchor_left = 1.0
	_window.anchor_right = 1.0
	_window.anchor_top = 0.0
	_window.anchor_bottom = 0.0
	_window.offset_left = -72.0
	_window.offset_right = -72.0
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

	# Items page — a WEAPON equip bar above the backpack slot grid.
	_items_page = VBoxContainer.new()
	_items_page.add_theme_constant_override("separation", 10)
	vbox.add_child(_items_page)
	var wlabel : Label = Label.new()
	wlabel.text = "Weapon"
	wlabel.add_theme_font_size_override("font_size", 16)
	wlabel.add_theme_color_override("font_color", COLOR_TITLE)
	_items_page.add_child(wlabel)
	_weapon_bar = HBoxContainer.new()
	_weapon_bar.add_theme_constant_override("separation", int(SLOT_SEP))
	_items_page.add_child(_weapon_bar)
	var wrule : ColorRect = ColorRect.new()
	wrule.color = Color(0.40, 0.28, 0.14, 0.8)
	wrule.custom_minimum_size = Vector2(0, 2)
	_items_page.add_child(wrule)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", int(SLOT_SEP))
	_grid.add_theme_constant_override("v_separation", int(SLOT_SEP))
	_items_page.add_child(_grid)

	# Hearts + Profile pages (hidden until their tab is picked).
	_hearts_view = RelationshipsView.new()
	_hearts_view.visible = false
	vbox.add_child(_hearts_view)
	_profile_view = ProfileView.new()
	_profile_view.visible = false
	vbox.add_child(_profile_view)

	# Hint line.
	var hint : Label = Label.new()
	hint.text = "Click the tab again, or press  Esc,  to close"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.8, 0.68, 0.42, 1.0))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	# The RAIL last, so it draws on top of the dim and stays clickable while the pane is open.
	_build_rail()
	_update_rail_styles()


# The always-visible left tab rail — a slim brass strip of icon buttons.
func _build_rail() -> void:

	var holder : PanelContainer = PanelContainer.new()
	holder.add_theme_stylebox_override("panel", _rail_bg_style())
	holder.anchor_left = 1.0
	holder.anchor_right = 1.0
	holder.anchor_top = 0.0
	holder.offset_left = -58.0
	holder.offset_right = -12.0
	holder.offset_top = 150.0   # below the top-right purse + journal "!"
	holder.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	holder.grow_vertical = Control.GROW_DIRECTION_END
	add_child(holder)
	var col : VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	holder.add_child(col)
	for def in RAIL_TABS:
		var btn : Button = _make_rail_button(String(def["glyph"]), String(def["tab"]), String(def["tip"]))
		_rail_buttons[String(def["tab"])] = btn
		col.add_child(btn)
	# Jobs — a LAUNCHER (opens the Shoppe Jobs board), not a pane tab. Absorbed from the old quick-menu so
	# Mining/Woodcutting jobs stay reachable from the consolidated rail.
	var jobs_btn : Button = _make_rail_button("jobs", "", "Shoppe Jobs — Mining & Woodcutting", _open_jobs)
	_style_rail_button(jobs_btn, false)
	col.add_child(jobs_btn)


func _make_rail_button(glyph: String, tab: String, tip: String, launcher: Callable = Callable()) -> Button:

	var btn : Button = Button.new()
	btn.custom_minimum_size = Vector2(46.0, 46.0)
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
	head.add_theme_color_override("font_color", COLOR_TITLE)
	_ayo_list.add_child(head)
	var challenges : Array = PlayerState.pending_challenges
	var ids : Array = PlayerState.unclaimed_trophy_ids()
	if challenges.is_empty() and ids.is_empty():
		var none : Label = Label.new()
		none.text = "No new tidings — you're all caught up."
		none.add_theme_font_size_override("font_size", 14)
		none.add_theme_color_override("font_color", Color(0.8, 0.72, 0.56, 1.0))
		_ayo_list.add_child(none)
		return
	if not challenges.is_empty():
		_ayo_list.add_child(_ayo_subhead("You've been challenged to a duel!", Color(1.0, 0.74, 0.55, 1.0)))
		for nm in challenges.duplicate():   # duplicate — Reject mutates the live array mid-loop
			_ayo_list.add_child(_make_challenge_card(String(nm)))
	if not ids.is_empty():
		_ayo_list.add_child(_ayo_subhead("New trophies earned — claim them!", Color(0.86, 0.78, 0.6, 1.0)))
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
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.24, 0.12, 0.10, 0.96)   # a warm combat tint, distinct from the trophy card
	s.border_color = tint.lerp(Palette.BRASS_FRAME, 0.4)
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
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
	nm.add_theme_color_override("font_color", tint.lightened(0.35))
	col.add_child(nm)
	var ds : Label = Label.new()
	ds.text = "A friendly Skirmish bout — your board against theirs."
	ds.add_theme_font_size_override("font_size", 13)
	ds.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62, 1.0))
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
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.22, 0.15, 0.08, 0.95)
	s.border_color = Palette.BRASS_FRAME
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
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
	nm.add_theme_color_override("font_color", COLOR_TITLE)
	col.add_child(nm)
	var ds : Label = Label.new()
	ds.text = String(info.get("desc", ""))
	ds.add_theme_font_size_override("font_size", 13)
	ds.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62, 1.0))
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
	head.add_theme_color_override("font_color", COLOR_TITLE)
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
		none.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62, 1.0))
		none.autowrap_mode = TextServer.AUTOWRAP_WORD
		none.custom_minimum_size = Vector2(440.0, 0.0)
		_obj_list.add_child(none)


func _make_quest_card(quest: Dictionary) -> Control:

	var card : PanelContainer = PanelContainer.new()
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.22, 0.15, 0.08, 0.95)
	s.border_color = Palette.BRASS_FRAME
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
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
	title.add_theme_color_override("font_color", COLOR_TITLE)
	col.add_child(title)
	var detail : Label = Label.new()
	detail.text = String(quest.get("detail", ""))
	detail.add_theme_font_size_override("font_size", 13)
	detail.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62, 1.0))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail.custom_minimum_size = Vector2(380.0, 0.0)
	col.add_child(detail)
	return card


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
	head.add_theme_color_override("font_color", COLOR_TITLE)
	col.add_child(head)
	# ONLY the current context's how-to — the puzzle you're in (PuzzleScene.set_help_text) or the overworld
	# controls by default. Never a list of every puzzle.
	_current_help_label = Label.new()
	_current_help_label.text = OVERWORLD_HELP
	_current_help_label.add_theme_font_size_override("font_size", 15)
	_current_help_label.add_theme_color_override("font_color", Color(0.93, 0.88, 0.74, 1.0))
	_current_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_current_help_label.custom_minimum_size = Vector2(460.0, 0.0)
	col.add_child(_current_help_label)
	return scroll


func _window_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.11, 0.06, 0.98)
	s.border_color = Palette.BRASS_FRAME
	s.set_border_width_all(3)
	s.set_corner_radius_all(14)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 20
	s.content_margin_bottom = 20
	return s


func _rail_bg_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.16, 0.11, 0.06, 0.90)
	s.border_color = Color(Palette.BRASS_FRAME.r, Palette.BRASS_FRAME.g, Palette.BRASS_FRAME.b, 0.6)
	s.set_border_width_all(2)
	s.set_corner_radius_all(12)
	s.set_content_margin_all(6)
	return s


# --- Rail styling ----------------------------------------------------

func _update_rail_styles() -> void:

	for tab in _rail_buttons:
		var active : bool = _is_open and _current_tab == tab
		_style_rail_button(_rail_buttons[tab], active)


func _style_rail_button(btn: Button, active: bool) -> void:

	if btn == null:
		return
	for state in ["normal", "hover", "pressed"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.27, 0.17, 0.09, 1.0) if active else Color(0.15, 0.10, 0.05, 0.85)
		if state == "hover":
			bg = bg.lightened(0.10)
		elif state == "pressed":
			bg = bg.darkened(0.10)
		s.bg_color = bg
		s.border_color = Palette.BRASS_FRAME if active else Color(0.40, 0.30, 0.16, 0.85)
		s.set_border_width_all(2)
		s.set_corner_radius_all(9)
		btn.add_theme_stylebox_override(state, s)


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
		_current_help_label.text = text if not text.strip_edges().is_empty() else OVERWORLD_HELP


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
	if _hearts_view != null:
		_hearts_view.visible = (tab == "relationships")
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
	if _current_tab == "relationships":
		if _hearts_view != null:
			_hearts_view.refresh()
		return
	if _current_tab == "profile":
		if _profile_view != null:
			_profile_view.refresh()
		return
	if _grid == null:
		return
	# ONE equip slot = the weapon in hand (empty = bare fists). Owned-but-unequipped weapons live in the
	# BACKPACK below; equipping pulls one up here, unequipping (click it again) drops it back. (Troy 2026-06-10)
	if _weapon_bar != null:
		for child in _weapon_bar.get_children():
			child.queue_free()
		_weapon_bar.add_child(_make_weapon_slot(PlayerState.equipped_weapon))
	# Backpack grid = your real items PLUS every owned weapon you're NOT holding (each fills a slot), padded
	# to capacity. A bought weapon sits here until equipped; unequipping returns it here.
	for child in _grid.get_children():
		child.queue_free()
	# POSITIONAL grid: ONE cell per inventory slot (empties shown as gaps), each carrying its slot index — so
	# you can drag an item to ANY slot and arrange your bag, the Minecraft/Stardew way (Troy 2026-06-11).
	for i in PlayerState.inventory.size():
		_grid.add_child(_make_slot(PlayerState.inventory[i], i))
	# Owned-but-unequipped weapons sit AFTER the item grid (each its own cell). Click to equip (drag: TODO).
	for wid in PlayerState.owned_weapons:
		var w : String = String(wid)
		if w != SkirmishWeapon.DEFAULT_WEAPON and w != PlayerState.equipped_weapon:
			_grid.add_child(_make_backpack_weapon(w))


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
	panel.add_theme_stylebox_override("panel", _slot_style(filled))
	if not filled:
		return panel
	var icon : Control = _make_item_icon(String(slot["id"]))
	if icon != null:
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 8.0
		icon.offset_top = 8.0
		icon.offset_right = -8.0
		icon.offset_bottom = -8.0
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
	var count : Label = Label.new()
	count.text = str(int(slot["count"]))
	count.add_theme_font_size_override("font_size", 15)
	count.add_theme_color_override("font_color", COLOR_COUNT)
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


# A Minecraft-style weapon equip slot: a SQUARE icon slot + a name below. The EQUIPPED one is lit (gold
# border + brighter fill + ✓). Click to equip (what your boarding/duel attacks send). Switched here only.
func _make_weapon_slot(weapon_id: String) -> Control:

	var is_default : bool = weapon_id == SkirmishWeapon.DEFAULT_WEAPON   # fists = unarmed → an EMPTY slot
	var equipped : bool = PlayerState.equipped_weapon == weapon_id
	var cell : VBoxContainer = VBoxContainer.new()
	cell.add_theme_constant_override("separation", 3)
	var panel : Panel = Panel.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.24, 0.17, 0.08, 1.0) if equipped else COLOR_SLOT_BG
	s.border_color = COLOR_TITLE if equipped else COLOR_SLOT_BORDER
	s.set_border_width_all(3 if equipped else 2)
	s.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", s)
	panel.tooltip_text = "Unarmed — just your fists\nClick to fight bare-knuckle" if is_default else "%s\n%s\n%s" % [
		SkirmishWeapon.display_name(weapon_id), String(SkirmishWeapon.DESCRIPTIONS.get(weapon_id, "")),
		"Click again to unarm" if equipped else "Click to equip"]
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_weapon_input.bind(weapon_id))
	if not is_default:   # the unarmed/fists slot stays EMPTY — no icon
		var icon : WeaponIcon = WeaponIcon.new()
		icon.weapon_id = weapon_id
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 8.0
		icon.offset_top = 8.0
		icon.offset_right = -8.0
		icon.offset_bottom = -8.0
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
	cell.add_child(panel)
	# No ✓ and no name label: it's the ONE equipped slot now, so the checkmark says nothing and the name just
	# duplicates the icon + the "Weapon" header. Icon + hover tooltip carry it (Troy 2026-06-10). Matches the
	# icon-only backpack cells.
	return cell


# A backpack cell holding an UNEQUIPPED weapon (icon only, like an item). Click to equip it — it moves up
# to the Weapon slot above (and whatever was equipped drops back down here). Same square look as an item slot.
func _make_backpack_weapon(weapon_id: String) -> Control:

	var panel : Panel = Panel.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.add_theme_stylebox_override("panel", _slot_style(true))
	panel.tooltip_text = "%s\n%s\nClick to equip" % [SkirmishWeapon.display_name(weapon_id),
		String(SkirmishWeapon.DESCRIPTIONS.get(weapon_id, ""))]
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_weapon_input.bind(weapon_id))   # click → equip (it's not the held one)
	var icon : WeaponIcon = WeaponIcon.new()
	icon.weapon_id = weapon_id
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 8.0
	icon.offset_top = 8.0
	icon.offset_right = -8.0
	icon.offset_bottom = -8.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	return panel


func _on_weapon_input(event: InputEvent, weapon_id: String) -> void:

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Click to EQUIP; click the EQUIPPED one again to UNEQUIP — back to bare fists (Troy 2026-06-10:
		# gear is a choice made here in the bag, never forced).
		if PlayerState.equipped_weapon == weapon_id and weapon_id != SkirmishWeapon.DEFAULT_WEAPON:
			PlayerState.equip_weapon(SkirmishWeapon.DEFAULT_WEAPON)
		else:
			PlayerState.equip_weapon(weapon_id)
		_refresh()


# Per-item icon. Wood/ore reuse the procedural icons; unknown items get a placeholder swatch.
func _make_item_icon(item_id: String) -> Control:

	if item_id == PlayerState.ITEM_WOOD:
		return WoodIcon.new()
	if item_id == PlayerState.ITEM_ORE:
		return OreIcon.new()
	var placeholder : ColorRect = ColorRect.new()
	placeholder.color = Color(0.5, 0.5, 0.55, 1.0)
	return placeholder


# A translucent slot that rides centered under the cursor while dragging. Public — InventorySlot._get_drag_data
# builds the drag and calls this for the preview.
func make_drag_preview(item_id: String, count: int) -> Control:

	var root : Control = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel : Panel = Panel.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.position = Vector2(-SLOT_SIZE * 0.5, -SLOT_SIZE * 0.5)
	panel.modulate = Color(1.0, 1.0, 1.0, 0.85)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _slot_style(true))
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
		lbl.add_theme_color_override("font_color", COLOR_COUNT)
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


func _slot_style(filled: bool) -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = COLOR_SLOT_BG
	s.border_color = COLOR_SLOT_BORDER if filled else COLOR_SLOT_EMPTY_BORDER
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	return s
