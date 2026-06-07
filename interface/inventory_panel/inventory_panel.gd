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

## The left tab rail, top→down. Each: tab id · MenuGlyph kind · hover tip.
const RAIL_TABS : Array = [
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
## The Tutorial tab — a help library (every puzzle's how-to, from [PuzzleHelp]).
var _tutorial_page : Control
var _rail_buttons : Dictionary = {}   # tab id → its rail Button (for active-state styling)
## "tutorial" / "items" / "relationships" / "profile".
var _current_tab : String = "items"
var _is_open : bool = false           # is the content pane EXPANDED (the rail is always visible)


func _ready() -> void:

	# Cover the whole screen (the dim + the left-docked window anchor within it); the rail shows always
	# (the panel node rides the HUD's visibility), the pane stays folded until a tab is clicked.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_skeleton()
	if not Engine.is_editor_hint():
		PlayerState.inventory_changed.connect(_on_inventory_changed)


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
	_window.anchor_left = 0.0
	_window.anchor_top = 0.0
	_window.offset_left = 78.0
	_window.offset_top = 60.0
	_window.grow_horizontal = Control.GROW_DIRECTION_END
	_window.grow_vertical = Control.GROW_DIRECTION_END
	_window.visible = false
	add_child(_window)

	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_window.add_child(vbox)

	# Tutorial page — a scrollable how-to library (the "?" replacement).
	_tutorial_page = _build_tutorial_page()
	vbox.add_child(_tutorial_page)

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
	holder.anchor_left = 0.0
	holder.anchor_top = 0.0
	holder.offset_left = 12.0
	holder.offset_top = 116.0
	holder.grow_horizontal = Control.GROW_DIRECTION_END
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


func _build_tutorial_page() -> Control:

	var scroll : ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(540.0, 392.0)
	scroll.visible = false
	var col : VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	var head : Label = Label.new()
	head.text = "How to play"
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", COLOR_TITLE)
	col.add_child(head)
	for entry in PuzzleHelp.TUTORIALS:
		var title : Label = Label.new()
		title.text = String(entry["title"])
		title.add_theme_font_size_override("font_size", 17)
		title.add_theme_color_override("font_color", Color(0.96, 0.80, 0.46, 1.0))
		col.add_child(title)
		var body : Label = Label.new()
		body.text = String(entry["body"])
		body.add_theme_font_size_override("font_size", 14)
		body.add_theme_color_override("font_color", Color(0.92, 0.86, 0.74, 1.0))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD
		body.custom_minimum_size = Vector2(500.0, 0.0)
		col.add_child(body)
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


# Switch page: show it, restyle the rail, refresh.
func _switch_tab(tab: String) -> void:

	_current_tab = tab
	if _tutorial_page != null:
		_tutorial_page.visible = (tab == "tutorial")
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
	# Weapon equip slots — click one to equip it for your boarding/duel attacks.
	if _weapon_bar != null:
		for child in _weapon_bar.get_children():
			child.queue_free()
		for wid in PlayerState.owned_weapons:
			_weapon_bar.add_child(_make_weapon_slot(String(wid)))
	# Backpack grid.
	for child in _grid.get_children():
		child.queue_free()
	var inv : Array = PlayerState.inventory
	for slot in inv:
		_grid.add_child(_make_slot(slot))


func _make_slot(slot: Dictionary) -> Control:

	var panel : Panel = Panel.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
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
	panel.tooltip_text = "Unarmed — just your fists" if is_default else "%s\n%s" % [
		SkirmishWeapon.display_name(weapon_id), String(SkirmishWeapon.DESCRIPTIONS.get(weapon_id, ""))]
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
	var name_l : Label = Label.new()
	name_l.text = "" if is_default else (("✓ %s" % SkirmishWeapon.display_name(weapon_id)) if equipped \
		else SkirmishWeapon.display_name(weapon_id))
	name_l.add_theme_font_size_override("font_size", 12)
	name_l.add_theme_color_override("font_color",
		COLOR_TITLE if equipped else Color(0.80, 0.72, 0.56, 1.0))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.custom_minimum_size = Vector2(SLOT_SIZE, 0.0)
	cell.add_child(name_l)
	return cell


func _on_weapon_input(event: InputEvent, weapon_id: String) -> void:

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
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


func _slot_style(filled: bool) -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = COLOR_SLOT_BG
	s.border_color = COLOR_SLOT_BORDER if filled else COLOR_SLOT_EMPTY_BORDER
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	return s
