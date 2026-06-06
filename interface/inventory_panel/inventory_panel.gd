## The player's backpack overlay — a Stardew/Minecraft-style slot grid
## that opens over the overworld. Reads [PlayerState.inventory] and
## rebuilds its slot widgets on open + whenever the inventory changes.
##
## Lives inside the [HUD] CanvasLayer (so it inherits the HUD's
## hide-in-puzzle behavior and never shows during a minigame). The HUD
## owns the open/close input (the "I" key + a bag button) and calls
## [method open] / [method close] / [method toggle]; this script just
## renders the contents and handles its own dim + close button.
##
## Built entirely in code (no .tscn layout) because the slot grid is
## dynamic — it rebuilds to match [member PlayerState.inventory_capacity],
## which grows when the player buys backpack upgrades.
@tool
class_name InventoryPanel
extends Control


const SLOT_SIZE : float = 64.0
const SLOT_SEP : float = 8.0
const COLS : int = 6   # slots per row in the grid

const COLOR_DIM : Color = Color(0, 0, 0, 0.55)
const COLOR_SLOT_BG : Color = Color(0.14, 0.09, 0.05, 1.0)
const COLOR_SLOT_BORDER : Color = Color(0.55, 0.38, 0.18, 1.0)
const COLOR_SLOT_EMPTY_BORDER : Color = Color(0.34, 0.24, 0.12, 1.0)
const COLOR_TITLE : Color = Color(0.98, 0.86, 0.42, 1.0)
const COLOR_COUNT : Color = Color(1.0, 0.95, 0.78, 1.0)


var _dim : ColorRect
var _window : PanelContainer
## The "items" (Backpack) page — a Weapon equip bar above the backpack slot grid.
var _items_page : VBoxContainer
var _weapon_bar : HBoxContainer
var _grid : GridContainer
## The Hearts tab — a [RelationshipsView] embedded as a second tab (the
## Stardew-style social page).
var _hearts_view : RelationshipsView
## The Profile tab — a [ProfileView] (character page: rank, reputation,
## fleet, avatar, trophies, and per-puzzle mastery standings).
var _profile_view : ProfileView
var _tab_items : Button
var _tab_hearts : Button
var _tab_profile : Button
## "items" (the backpack grid), "relationships" (hearts), or "profile"
## (standings).
var _current_tab : String = "items"
var _is_open : bool = false


func _ready() -> void:

	# Cover the whole screen (so the centered window's 0.5 anchors center
	# on the full viewport); start hidden.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_skeleton()
	if not Engine.is_editor_hint():
		PlayerState.inventory_changed.connect(_on_inventory_changed)


func _build_skeleton() -> void:

	# Dim backdrop — eats mouse so clicks don't fall through to the world.
	_dim = ColorRect.new()
	_dim.color = COLOR_DIM
	_dim.anchor_right = 1.0
	_dim.anchor_bottom = 1.0
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	# Centered walnut/brass window.
	_window = PanelContainer.new()
	_window.add_theme_stylebox_override("panel", _window_style())
	_window.anchor_left = 0.5
	_window.anchor_top = 0.5
	_window.anchor_right = 0.5
	_window.anchor_bottom = 0.5
	_window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_window.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_window)
	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_window.add_child(vbox)
	# Tab bar — Backpack / Hearts (the Stardew unified-menu pages).
	var tabs : HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(tabs)
	_tab_items = _make_tab_button("Backpack")
	_tab_items.pressed.connect(_switch_tab.bind("items"))
	tabs.add_child(_tab_items)
	_tab_hearts = _make_tab_button("♥  Hearts")
	_tab_hearts.pressed.connect(_switch_tab.bind("relationships"))
	tabs.add_child(_tab_hearts)
	_tab_profile = _make_tab_button("★  Profile")
	_tab_profile.pressed.connect(_switch_tab.bind("profile"))
	tabs.add_child(_tab_profile)
	# Divider.
	var rule : ColorRect = ColorRect.new()
	rule.color = Color(0.55, 0.38, 0.18, 1.0)
	rule.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(rule)
	# Items page — a WEAPON equip bar (your boarding weapon, YPP-style) above the
	# backpack slot grid. Both toggle together with the "items" tab.
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
	# The backpack slot grid.
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", int(SLOT_SEP))
	_grid.add_theme_constant_override("v_separation", int(SLOT_SEP))
	_items_page.add_child(_grid)
	# Hearts page — the relationships view (hidden until its tab is picked).
	_hearts_view = RelationshipsView.new()
	_hearts_view.visible = false
	vbox.add_child(_hearts_view)
	# Profile page — the character/standings view (hidden until its tab is picked).
	_profile_view = ProfileView.new()
	_profile_view.visible = false
	vbox.add_child(_profile_view)
	# Hint line.
	var hint : Label = Label.new()
	hint.text = "Press  Esc  to close"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.8, 0.68, 0.42, 1.0))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)
	# Quit to title — the discoverable clean save-and-quit from the overworld (ESC opens this bag, so
	# this is the way out). PlayerState autosaves on every change, so we just return to the title.
	var quit_row : HBoxContainer = HBoxContainer.new()
	quit_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(quit_row)
	var quit_btn : Button = Button.new()
	quit_btn.text = "⏻  Quit to Title"
	quit_btn.focus_mode = Control.FOCUS_NONE
	quit_btn.add_theme_font_size_override("font_size", 15)
	quit_btn.add_theme_color_override("font_color", Color(0.92, 0.72, 0.52, 1.0))
	quit_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	quit_btn.add_theme_constant_override("outline_size", 3)
	var qs : StyleBoxFlat = StyleBoxFlat.new()
	qs.bg_color = Color(0.20, 0.12, 0.07, 0.92)
	qs.border_color = Color(0.55, 0.38, 0.18, 1.0)
	qs.set_border_width_all(2)
	qs.set_corner_radius_all(8)
	qs.content_margin_left = 16
	qs.content_margin_right = 16
	qs.content_margin_top = 7
	qs.content_margin_bottom = 7
	quit_btn.add_theme_stylebox_override("normal", qs)
	quit_btn.pressed.connect(_on_quit_to_title)
	quit_row.add_child(quit_btn)
	_update_tab_styles()


func _window_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.11, 0.06, 0.98)
	s.border_color = Color(0.78, 0.58, 0.24, 1.0)
	s.border_width_left = 3
	s.border_width_top = 3
	s.border_width_right = 3
	s.border_width_bottom = 3
	s.corner_radius_top_left = 14
	s.corner_radius_top_right = 14
	s.corner_radius_bottom_right = 14
	s.corner_radius_bottom_left = 14
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 22
	s.content_margin_bottom = 22
	return s


# --- Tabs ------------------------------------------------------------

func _make_tab_button(text: String) -> Button:

	var btn : Button = Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	btn.add_theme_constant_override("outline_size", 3)
	return btn


func _update_tab_styles() -> void:

	_style_tab(_tab_items, _current_tab == "items")
	_style_tab(_tab_hearts, _current_tab == "relationships")
	_style_tab(_tab_profile, _current_tab == "profile")


func _style_tab(btn: Button, active: bool) -> void:

	if btn == null:
		return
	btn.add_theme_color_override("font_color",
		COLOR_TITLE if active else Color(0.72, 0.60, 0.42, 1.0))
	for state in ["normal", "hover", "pressed"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		s.bg_color = Color(0.27, 0.17, 0.09, 1.0) if active else Color(0.15, 0.10, 0.05, 0.85)
		s.border_color = Color(0.78, 0.58, 0.24, 1.0) if active else Color(0.40, 0.30, 0.16, 0.8)
		s.border_width_left = 2
		s.border_width_top = 2
		s.border_width_right = 2
		s.border_width_bottom = 2
		s.corner_radius_top_left = 8
		s.corner_radius_top_right = 8
		s.corner_radius_bottom_right = 8
		s.corner_radius_bottom_left = 8
		s.content_margin_left = 18
		s.content_margin_right = 18
		s.content_margin_top = 6
		s.content_margin_bottom = 6
		btn.add_theme_stylebox_override(state, s)


# --- Open / close ----------------------------------------------------

func is_open() -> bool:

	return _is_open


func open(tab : String = "items") -> void:

	_is_open = true
	visible = true
	_switch_tab(tab)


func close() -> void:

	if not _is_open:
		return
	_is_open = false
	visible = false


func toggle() -> void:

	if _is_open:
		close()
	else:
		open("items")


# Return to the title screen. PlayerState autosaves on every change + records last_scene, so main.tscn
# resumes the player right back here on next launch — a clean save-and-quit.
func _on_quit_to_title() -> void:

	close()
	if get_tree() == null:
		return
	get_tree().paused = false
	# Abandon any in-flight pillage entirely (NOT just the melee): the voyage fields are transient + not
	# saved, so leaving voyage_active / open_holes / the board snapshot live would bleed into the next run
	# (a phantom resume on Continue, or a fresh voyage starting already-holed). clear_voyage clears the
	# boarding melee too.
	PlayerState.clear_voyage()
	get_tree().change_scene_to_file("res://main.tscn")


func current_tab() -> String:

	return _current_tab


# Switch page ("items" / "relationships" / "profile"): show it, restyle the
# tabs, refresh.
func _switch_tab(tab: String) -> void:

	_current_tab = tab
	if _items_page != null:
		_items_page.visible = (tab == "items")
	if _hearts_view != null:
		_hearts_view.visible = (tab == "relationships")
	if _profile_view != null:
		_profile_view.visible = (tab == "profile")
	_update_tab_styles()
	_refresh()


# --- Contents --------------------------------------------------------

func _on_inventory_changed() -> void:

	if _is_open and _current_tab == "items":
		_refresh()


# Refresh the active page — the slot grid, the hearts view, or the standings.
func _refresh() -> void:

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
	# Icon — FULL_RECT-anchored inside the slot with a small inset so it
	# tracks the panel's actual rect (the GridContainer sizes the panel to
	# SLOT_SIZE). WoodIcon._draw centers its disc within whatever rect it
	# gets, so this yields a centered icon. Manual position() doesn't work
	# here because the panel has no size until the grid lays it out.
	var icon : Control = _make_item_icon(String(slot["id"]))
	if icon != null:
		# Symmetric inset → the icon is CENTERED in the slot. The count
		# overlays the bottom-right corner on top of it (overlap is fine).
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 8.0
		icon.offset_top = 8.0
		icon.offset_right = -8.0
		icon.offset_bottom = -8.0
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
	# Count — also FULL_RECT-anchored, text aligned to the bottom-right.
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


# A Minecraft-style weapon equip slot: a SQUARE icon slot + a name below. The EQUIPPED
# one is lit (gold border + brighter fill + ✓), like a selected hotbar slot. Click to
# equip (what your boarding/duel attacks send). Switched here only, never mid-fight.
func _make_weapon_slot(weapon_id: String) -> Control:

	var is_default : bool = weapon_id == SkirmishWeapon.DEFAULT_WEAPON   # fists = unarmed → an EMPTY slot
	var equipped : bool = PlayerState.equipped_weapon == weapon_id
	var cell : VBoxContainer = VBoxContainer.new()
	cell.add_theme_constant_override("separation", 3)
	# Square slot.
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
	# Name below — gold + ✓ when equipped.
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


# Per-item icon. Wood reuses the procedural [WoodIcon] (same art as the
# old HUD pouch). The icon is sized by FULL_RECT anchors in _make_slot,
# so we don't set a fixed size here — WoodIcon draws centered in whatever
# rect it's given.
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
	var border : Color = COLOR_SLOT_BORDER if filled else COLOR_SLOT_EMPTY_BORDER
	s.border_color = border
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	s.corner_radius_bottom_right = 6
	s.corner_radius_bottom_left = 6
	return s