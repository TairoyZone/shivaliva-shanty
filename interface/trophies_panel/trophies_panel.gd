## TrophiesPanel — the dedicated TROPHY ROOM page (Troy 2026-06-10): EVERY trophy in one scrollable grid
## (earned ones gleam gold, the rest sit dim + locked), so the profile shelf can stay a small preview and a
## big collection never floods the profile. Opened from the profile's "See all" button. A CREAM [Modal]
## (matches the profile card so the [TrophyCell]s read), scrollable, ESC/dim-click to close (from the base).
class_name TrophiesPanel
extends Modal


const GROUP : StringName = &"trophies_panel"


static func open(host: Node) -> void:

	if host == null or host.get_tree() == null:
		return
	if host.get_tree().get_first_node_in_group(GROUP) != null:
		return
	host.get_tree().root.add_child(TrophiesPanel.new())


# --- Modal config -----------------------------------------------------

func _modal_group() -> StringName:
	return GROUP

func _modal_size() -> Vector2:
	return Vector2(560.0, 520.0)

func _modal_scrollable() -> bool:
	return true

func _modal_panel_style() -> StyleBoxFlat:
	# The INTENTIONAL cream outlier — themed cream card (so the TrophyCells read as dark ink on gold), kept at
	# the larger modal scale (border 3 / radius 14 / margin 20). Routes through the factory so it retunes.
	var s : StyleBoxFlat = UiStyle.cream_card()
	s.set_border_width_all(3)
	s.set_corner_radius_all(14)
	s.set_content_margin_all(20)
	return s


func _build_content() -> void:

	var earned : int = 0
	for t in Trophies.ALL:
		if Trophies.is_earned(String(t["id"])):
			earned += 1

	var title : Label = Label.new()
	title.text = "TROPHY ROOM   %d / %d" % [earned, Trophies.ALL.size()]
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Palette.INK_ON_LIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	var sub : Label = Label.new()
	sub.text = "Every honour on the rock — earned ones gleam, the rest await."
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Palette.INK_ON_LIGHT_SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	_content.add_child(sub)

	var grid : HFlowContainer = HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(grid)
	for t in Trophies.ALL:
		grid.add_child(TrophyCell.make(t))
