## A scrollable list of the cast and the player's rapport with each: a
## portrait swatch, name, rapport tier, a heart meter, and favour history.
## NOT a standalone window — it's embedded as the "Hearts" TAB inside the
## [InventoryPanel] (the Stardew-style unified menu), which supplies the
## surrounding window/title/close. Self-refreshes on rapport changes while
## it's the visible tab. See [[parlor-social-system]].
class_name RelationshipsView
extends Control


const COLOR_CARD : Color = Color(0.99, 0.94, 0.78, 1.0)
const COLOR_INK : Color = Color(0.30, 0.20, 0.08, 1.0)
const COLOR_INK_SOFT : Color = Color(0.42, 0.32, 0.18, 1.0)
const COLOR_FRAME : Color = Color(0.52, 0.36, 0.16, 1.0)
const COLOR_HEART : Color = Color(0.88, 0.32, 0.44, 1.0)

## Heart pips in the meter; each = MAX_AFFINITY / HEARTS rapport points.
const HEARTS : int = 10

## Min rapport for an NPC to appear here. The Hearties tab is your FRIENDS list — only islanders you've
## built positive rapport with, NOT the whole cast (Troy 2026-06-06). Talk to / help an NPC and they show
## up. 1 = any positive rapport; bump toward the "Friend" tier (50) if you want it stricter.
const FRIENDS_MIN_AFFINITY : int = 1

var _list : VBoxContainer


func _ready() -> void:

	custom_minimum_size = Vector2(560.0, 372.0)
	var scroll : ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	if not Engine.is_editor_hint():
		PlayerState.affinity_changed.connect(_on_affinity_changed)
	refresh()


func _on_affinity_changed(_npc: String, _value: int, _tier: String) -> void:

	# Only rebuild when actually on-screen (the inventory's Hearts tab is up).
	if is_visible_in_tree():
		refresh()


func refresh() -> void:

	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	# Only show islanders you've actually befriended (positive rapport) — the Hearties tab is your FRIENDS
	# list, not a roster of the whole cast. Empty until you talk to / help someone.
	var shown : int = 0
	for profile in NpcRegistry.all():
		if PlayerState.get_affinity(profile.npc_name) < FRIENDS_MIN_AFFINITY:
			continue
		_list.add_child(_make_npc_card(profile))
		shown += 1
	if shown == 0:
		_list.add_child(_make_empty_hint())


func _make_npc_card(profile: NpcPersonality) -> Control:

	var who : String = profile.npc_name
	var affinity : int = PlayerState.get_affinity(who)
	var tier : String = PlayerState.affinity_tier(who)

	var card : PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	row.add_child(_make_portrait(profile))

	var col : VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)
	var name_label : Label = Label.new()
	name_label.text = who
	name_label.add_theme_font_size_override("font_size", 21)
	name_label.add_theme_color_override("font_color", COLOR_INK)
	col.add_child(name_label)
	var sub : Label = Label.new()
	sub.text = "%s   ·   %s" % [tier, _favour_note(who)]
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", COLOR_INK_SOFT)
	col.add_child(sub)

	var hearts : Label = Label.new()
	hearts.text = _hearts_text(affinity)
	hearts.add_theme_font_size_override("font_size", 22)
	hearts.add_theme_color_override("font_color", COLOR_HEART)
	hearts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hearts)
	return card


# Shown when you've no hearties yet — so the empty tab reads as "go make friends", not "broken".
func _make_empty_hint() -> Control:

	var hint : Label = Label.new()
	hint.text = "No hearties yet.\n\nClick an islander and choose Talk — lend a hand with a favour — and they'll appear here as you befriend them."
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", COLOR_INK_SOFT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.custom_minimum_size = Vector2(0.0, 160.0)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return hint


func _make_portrait(profile: NpcPersonality) -> Control:

	var swatch : PanelContainer = PanelContainer.new()
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = profile.portrait_color
	s.border_color = COLOR_FRAME
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.corner_radius_top_left = 10
	s.corner_radius_top_right = 10
	s.corner_radius_bottom_right = 10
	s.corner_radius_bottom_left = 10
	swatch.add_theme_stylebox_override("panel", s)
	swatch.custom_minimum_size = Vector2(46, 46)
	var initial : Label = Label.new()
	initial.text = _initial(profile.npc_name)
	initial.add_theme_font_size_override("font_size", 24)
	initial.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	initial.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	initial.add_theme_constant_override("outline_size", 4)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	swatch.add_child(initial)
	return swatch


# Filled (♥) up to the rapport level, hollow (♡) for the rest — the two
# glyphs read as full vs empty even in one colour.
func _hearts_text(affinity: int) -> String:

	var per : float = float(PlayerState.MAX_AFFINITY) / float(HEARTS)
	var filled : int = clampi(int(round(float(affinity) / per)), 0, HEARTS)
	return "♥".repeat(filled) + "♡".repeat(HEARTS - filled)


func _favour_note(who: String) -> String:

	if PlayerState.has_active_favor(who):
		return "favour pending"
	var done : int = int(PlayerState.npc_favor_done.get(who, 0))
	if done > 0:
		return "helped %d time%s" % [done, "" if done == 1 else "s"]
	return "not yet helped"


# Initial of the given name (last word) — "Hearty Brian" → "B".
func _initial(who: String) -> String:

	var parts : PackedStringArray = who.split(" ")
	var given : String = parts[parts.size() - 1] if parts.size() > 0 else who
	return given.substr(0, 1).to_upper() if not given.is_empty() else "?"


func _card_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = COLOR_CARD
	s.border_color = COLOR_FRAME
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.corner_radius_bottom_right = 8
	s.corner_radius_bottom_left = 8
	s.content_margin_left = 12
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s
