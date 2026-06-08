## The player's character page — a YPP info-page-style PROFILE: name + a rank
## that grows with the jobbing→captain arc, a reputation + fleet summary, a
## placeholder avatar, a trophy shelf, and the puzzle/parlor SKILLS grouped by
## category with their mastery rank. Embedded as the "★ Profile" TAB inside
## [InventoryPanel]; the panel supplies the surrounding window / title / close.
## Reads only live [PlayerState] (mastery, affinity, ships, coins) + [Trophies].
## See [[profile-standings-tab]] / [[ypp-template]].
class_name ProfileView
extends Control


const COLOR_CARD : Color = Color(0.99, 0.94, 0.78, 1.0)
const COLOR_INK : Color = Color(0.30, 0.20, 0.08, 1.0)
const COLOR_INK_SOFT : Color = Color(0.42, 0.32, 0.18, 1.0)
const COLOR_FRAME : Color = Color(0.52, 0.36, 0.16, 1.0)
const COLOR_HEADER : Color = Color(0.58, 0.40, 0.18, 1.0)
const COLOR_BAR_BG : Color = Color(0.82, 0.72, 0.52, 1.0)
const COLOR_BAR_FILL : Color = Color(0.86, 0.58, 0.20, 1.0)
const COLOR_GOLD : Color = Color(0.95, 0.78, 0.30, 1.0)
const COLOR_LOCKED : Color = Color(0.62, 0.56, 0.46, 1.0)

## Tier badge colours — index-aligned to [constant PlayerState.MASTERY_TIERS].
const TIER_COLORS : Array[Color] = [
	Color(0.55, 0.50, 0.44), Color(0.50, 0.62, 0.40), Color(0.38, 0.60, 0.74),
	Color(0.58, 0.42, 0.74), Color(0.88, 0.56, 0.22), Color(0.90, 0.32, 0.36),
]

## Puzzle/parlor games grouped into skill categories (YPP Piracy/Carousing/…).
const SKILL_GROUPS : Array = [
	{"label": "Labor", "puzzles": ["lumberjacking", "mining"]},
	{"label": "Parlor", "puzzles": ["poker", "gem_drop"]},
	{"label": "Combat", "puzzles": ["skirmish"]},
]

var _root : VBoxContainer


func _ready() -> void:

	# Never run the live-state build at edit time. This is non-@tool so its
	# _ready shouldn't fire in the editor, but @tool InventoryPanel constructs
	# us, and refresh() reads PlayerState / Trophies / NpcRegistry — guard so
	# none of that can execute against editor state.
	if Engine.is_editor_hint():
		return
	custom_minimum_size = Vector2(668.0, 440.0)
	var scroll : ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 10)
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_root)
	refresh()


func refresh() -> void:

	if _root == null:
		return
	for child in _root.get_children():
		child.queue_free()
	_root.add_child(_make_header())
	var rule : ColorRect = ColorRect.new()
	rule.color = COLOR_FRAME
	rule.custom_minimum_size = Vector2(0, 2)
	_root.add_child(rule)
	var cols : HBoxContainer = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_child(cols)
	cols.add_child(_make_left_column())
	cols.add_child(_make_center_column())
	cols.add_child(_make_skills_column())


# --- Header (name + rank) --------------------------------------------

func _make_header() -> Control:

	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label : Label = Label.new()
	name_label.text = "You"
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", COLOR_INK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var rank_label : Label = Label.new()
	rank_label.text = "%s of Cradle Rock" % _player_rank()
	rank_label.add_theme_font_size_override("font_size", 15)
	rank_label.add_theme_color_override("font_color", COLOR_INK_SOFT)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rank_label)
	return box


# Rank in the jobbing→captain arc, from live milestones. (A "Jobber" rung
# slots between Deckhand and Skipper once the jobbing loop exists.)
func _player_rank() -> String:

	if PlayerState.has_ship() and PlayerState.frontier_unlocked:
		return "Captain"
	if PlayerState.has_ship():
		return "Skipper"
	if PlayerState.hired_at_workshop or PlayerState.hired_at_forge:
		return "Deckhand"
	return "Stowaway"


# --- Left column: Reputation + Fleet ---------------------------------

func _make_left_column() -> Control:

	var col : VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.custom_minimum_size = Vector2(156, 0)

	col.add_child(_section_label("Reputation"))
	var cast : Array[NpcPersonality] = NpcRegistry.all()
	var friends : int = 0
	var acquaintances : int = 0
	var closest_name : String = ""
	var closest_aff : int = -1
	for profile in cast:
		var aff : int = PlayerState.get_affinity(profile.npc_name)
		if aff >= 50:
			friends += 1
		if aff >= 20:
			acquaintances += 1
		if aff > closest_aff:
			closest_aff = aff
			closest_name = profile.npc_name
	col.add_child(_kv_line("Renown", _renown_word(friends, acquaintances, cast.size())))
	col.add_child(_kv_line("Friends", "%d of %d" % [friends, cast.size()]))
	if closest_aff > 0:
		col.add_child(_kv_line("Closest", "%s (%s)" % [
			_given_name(closest_name), PlayerState.affinity_tier(closest_name)]))

	var gap : Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	col.add_child(gap)

	col.add_child(_section_label("Fleet"))
	if PlayerState.has_ship():
		col.add_child(_muted_line("Flying the %s." % PlayerState.FIRST_SHIP_NAME))
	else:
		col.add_child(_muted_line("No ship yet — earn your wings."))
	return col


func _renown_word(friends: int, acquaintances: int, total: int) -> String:

	if total > 0 and friends >= total:
		return "Renowned"
	if friends > 0:
		return "Known"
	if acquaintances > 0:
		return "Aspiring"
	return "Unknown"


# --- Center column: avatar + trophies --------------------------------

func _make_center_column() -> Control:

	var col : VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(180, 0)

	# Framed avatar.
	var frame : PanelContainer = PanelContainer.new()
	var fs : StyleBoxFlat = StyleBoxFlat.new()
	fs.bg_color = Color(0.12, 0.10, 0.07, 1.0)
	fs.border_color = COLOR_FRAME
	fs.set_border_width_all(3)
	fs.set_corner_radius_all(100)   # circular frame ring around the round avatar (clamped to half-size)
	fs.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", fs)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# A circular avatar via clip_children masking (borrow) — the procedural bust clipped to a circle.
	var avatar : ProfileAvatar = ProfileAvatar.new()
	frame.add_child(CircleClip.wrap(avatar, 168.0))
	col.add_child(frame)

	# Trophy COLLECTION — only trophies you've CLAIMED in the Ayo! tab show here (Troy 2026-06-08). An
	# earned-but-unclaimed trophy waits in Ayo! until you accept it, THEN it lands on this shelf.
	var claimed_list : Array = []
	for t in Trophies.ALL:
		if PlayerState.trophies_claimed.has(String(t["id"])):
			claimed_list.append(t)
	col.add_child(_section_label("Trophies   %d" % claimed_list.size()))
	if claimed_list.is_empty():
		var none : Label = Label.new()
		none.text = "No trophies yet — earn them, then claim them in the Ayo! tab."
		none.add_theme_font_size_override("font_size", 12)
		none.add_theme_color_override("font_color", COLOR_INK_SOFT)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(none)
		return col
	var grid : HFlowContainer = HFlowContainer.new()   # wraps the trophy shelf responsively as more are claimed
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for t in claimed_list:
		grid.add_child(_make_trophy(t))
	col.add_child(grid)
	return col


func _make_trophy(t: Dictionary) -> Control:

	var earned : bool = Trophies.is_earned(String(t["id"]))
	var cell : VBoxContainer = VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	cell.custom_minimum_size = Vector2(64, 0)
	cell.tooltip_text = "%s\n%s%s" % [
		String(t["name"]), String(t["desc"]), "" if earned else "\n(locked)"]

	# Medallion — a gold disc when earned, dim grey when locked.
	var disc : PanelContainer = PanelContainer.new()
	var ds : StyleBoxFlat = StyleBoxFlat.new()
	ds.bg_color = COLOR_GOLD if earned else Color(0.30, 0.27, 0.22, 1.0)
	ds.border_color = COLOR_GOLD.lightened(0.2) if earned else Color(0.42, 0.38, 0.30, 1.0)
	ds.set_border_width_all(2)
	ds.set_corner_radius_all(22)
	disc.add_theme_stylebox_override("panel", ds)
	disc.custom_minimum_size = Vector2(46, 46)
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var star : Label = Label.new()
	star.text = "★"
	star.add_theme_font_size_override("font_size", 24)
	star.add_theme_color_override("font_color",
		Color(0.32, 0.20, 0.05, 1.0) if earned else COLOR_LOCKED)
	star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	disc.add_child(star)
	cell.add_child(disc)

	var cap : Label = Label.new()
	cap.text = String(t["name"])
	cap.add_theme_font_size_override("font_size", 10)
	cap.add_theme_color_override("font_color", COLOR_INK if earned else COLOR_INK_SOFT)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD
	cap.custom_minimum_size = Vector2(64, 0)
	cell.add_child(cap)
	return cell


# --- Right column: skills by category --------------------------------

func _make_skills_column() -> Control:

	var col : VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.custom_minimum_size = Vector2(272, 0)
	col.add_child(_section_label("Skills"))
	for group in SKILL_GROUPS:
		col.add_child(_category_label(String(group["label"])))
		for pid in group["puzzles"]:
			if PlayerState.MASTERY_PUZZLES.has(pid):
				col.add_child(_make_skill_row(String(pid)))
	return col


func _make_skill_row(puzzle_id: String) -> Control:

	var cfg : Dictionary = PlayerState.MASTERY_PUZZLES[puzzle_id]
	var display_name : String = String(cfg.get("name", puzzle_id))
	var thresholds : Array = cfg.get("thresholds", [0])
	var best : int = PlayerState.mastery_best(puzzle_id)
	var tier : Dictionary = PlayerState.mastery_tier(puzzle_id)
	var tier_idx : int = int(tier["index"])
	var max_idx : int = thresholds.size() - 1

	var ratio : float = 1.0
	if best <= 0:
		ratio = 0.0
	elif tier_idx < max_idx:
		var here : int = int(thresholds[tier_idx])
		var next_t : int = int(thresholds[tier_idx + 1])
		ratio = clampf(float(best - here) / float(maxi(1, next_t - here)), 0.0, 1.0)

	var card : PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	var col : VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)
	var name_label : Label = Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", COLOR_INK)
	name_label.clip_text = true   # never let a long skill name force the card wider than its column (overflow → clip)
	col.add_child(name_label)
	col.add_child(_make_progress_bar(ratio))

	row.add_child(_make_tier_badge(String(tier["name"]), tier_idx))
	var best_label : Label = Label.new()
	best_label.text = "—" if best <= 0 else str(best)
	best_label.add_theme_font_size_override("font_size", 16)
	best_label.add_theme_color_override("font_color", COLOR_INK_SOFT)
	best_label.custom_minimum_size = Vector2(30, 0)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	best_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(best_label)
	return card


# --- Shared little builders -------------------------------------------

func _section_label(text: String) -> Control:

	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", COLOR_HEADER)
	return l


func _category_label(text: String) -> Control:

	var l : Label = Label.new()
	l.text = "— %s —" % text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", COLOR_INK_SOFT)
	return l


func _kv_line(key: String, value: String) -> Control:

	var l : Label = Label.new()
	l.text = "%s:  %s" % [key, value]
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", COLOR_INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l


func _muted_line(text: String) -> Control:

	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", COLOR_INK_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l


func _make_tier_badge(tier_name: String, tier_idx: int) -> Control:

	var badge : PanelContainer = PanelContainer.new()
	var c : Color = TIER_COLORS[clampi(tier_idx, 0, TIER_COLORS.size() - 1)]
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = c
	s.border_color = c.lightened(0.22)
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	badge.add_theme_stylebox_override("panel", s)
	badge.custom_minimum_size = Vector2(72, 0)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label : Label = Label.new()
	label.text = tier_name
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.96))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(label)
	return badge


func _make_progress_bar(ratio: float) -> Control:

	var bar : ProgressBar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = clampf(ratio, 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg : StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = COLOR_BAR_BG
	bg.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", bg)
	var fill : StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = COLOR_BAR_FILL
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _card_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = COLOR_CARD
	s.border_color = COLOR_FRAME
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 7
	s.content_margin_bottom = 7
	return s


func _given_name(full: String) -> String:

	var parts : PackedStringArray = full.split(" ")
	return parts[parts.size() - 1] if parts.size() > 0 else full