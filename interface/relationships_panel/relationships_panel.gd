## A list of the cast and the player's rapport with each: a portrait swatch, name, the worded rapport
## TIER (no more Stardew hearts — Troy 2026-06-16), and favour history. Embedded into the [ProfileView]'s
## "Hearties" section (set [member embedded] = true before add_child so it drops its own scroll + min size
## and flows inside the Profile's scroll). Self-refreshes on rapport changes. See [[parlor-social-system]].
class_name RelationshipsView
extends Control


const COLOR_CARD : Color = Color(0.99, 0.94, 0.78, 1.0)
const COLOR_INK : Color = Color(0.30, 0.20, 0.08, 1.0)
const COLOR_INK_SOFT : Color = Color(0.42, 0.32, 0.18, 1.0)
const COLOR_FRAME : Color = Color(0.52, 0.36, 0.16, 1.0)
const COLOR_HEART : Color = Color(0.88, 0.32, 0.44, 1.0)   # romance/sweetheart note only

# (Visibility rule: ONLY hearties — genuine FRIENDS (≥ Friend tier) — show. Strangers, acquaintances and
# soured standings stay hidden; this is your friends roster, not the whole cast. See refresh() / PlayerState.is_heartie.)

## Set true before add_child to flow INSIDE another scroll (the Profile) — no own ScrollContainer, no min size.
var embedded : bool = false

var _list : VBoxContainer


func _ready() -> void:

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if embedded:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list.set_anchors_preset(Control.PRESET_TOP_WIDE)   # full width, height = its content
		add_child(_list)
		# Report the list's height up so the Profile's VBox gives this Control the room it needs.
		_list.resized.connect(func() -> void: custom_minimum_size = Vector2(0, _list.size.y))
	else:
		custom_minimum_size = Vector2(560.0, 372.0)
		var scroll : ScrollContainer = ScrollContainer.new()
		scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		add_child(scroll)
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
	# Show only HEARTIES — genuine FRIENDS (≥ Friend tier). A stranger you said hi to once, a passing
	# acquaintance, or a soured standing does NOT belong on your friends roster (Troy 2026-06-17). The
	# rule lives in PlayerState.is_heartie so multiplayer "added as a friend" can later extend it there.
	var shown : int = 0
	for profile in NpcRegistry.all():
		if not PlayerState.is_heartie(profile.npc_name):
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
	# A soured standing reads in RED — Wary/Disliked/Despised is a warning, not a friendship.
	sub.add_theme_color_override("font_color",
		Color(0.92, 0.45, 0.38, 1.0) if affinity < 0 else COLOR_INK_SOFT)
	col.add_child(sub)
	var rom : String = _romance_note(who, profile)
	if not rom.is_empty():
		var rlabel : Label = Label.new()
		rlabel.text = rom
		rlabel.add_theme_font_size_override("font_size", 14)
		rlabel.add_theme_color_override("font_color", COLOR_HEART)
		col.add_child(rlabel)
	return card


# The romance status line for a card ("" if none): a married NPC reads "Married to X"; an active courtship reads
# its stage; your Sweetheart is named. Surfaces the Sweethearts state on the Hearts page.
func _romance_note(who: String, profile: NpcPersonality) -> String:

	if not profile.partner.is_empty():
		return "Married to %s" % profile.partner
	if PlayerState.is_sweetheart(who):
		return "Your Sweetheart"
	if PlayerState.romance_stage(who) > 0:
		return "Courting — %s" % PlayerState.romance_stage_name(who)
	return ""


# Shown when you've no hearties yet — so the empty tab reads as "go make friends", not "broken".
func _make_empty_hint() -> Control:

	var hint : Label = Label.new()
	hint.text = "No hearties yet.\n\nChat and lend a hand with favours to grow close — once an islander becomes a Friend, they'll appear here as a heartie."
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
