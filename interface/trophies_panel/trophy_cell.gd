## TrophyCell — THE one trophy medallion cell (gold disc + ★ + name), shared by the profile shelf AND the
## dedicated [TrophiesPanel] page so they never drift (inheritance-over-duplication). Earned = gold + bright
## ink; locked = dim grey. Designed for a CREAM card background (both callers use one). Static factory.
class_name TrophyCell


const GOLD : Color = Color(0.95, 0.78, 0.30, 1.0)
const INK : Color = Color(0.30, 0.20, 0.08, 1.0)
const INK_SOFT : Color = Color(0.42, 0.32, 0.18, 1.0)
const LOCKED : Color = Color(0.62, 0.56, 0.46, 1.0)


## [param on_dark] = the cell sits on the bare DARK window (the Profile shelf), so the caption uses the light
## text tiers; default false = on a CREAM card (the TrophiesPanel page), where dark INK is correct.
static func make(t: Dictionary, on_dark: bool = false) -> Control:

	var earned : bool = Trophies.is_earned(String(t["id"]))
	var cell : VBoxContainer = VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	cell.custom_minimum_size = Vector2(64, 0)
	cell.tooltip_text = "%s\n%s%s" % [
		String(t["name"]), String(t["desc"]), "" if earned else "\n(locked)"]

	# Medallion — a gold disc when earned, dim grey when locked.
	var disc : PanelContainer = PanelContainer.new()
	var ds : StyleBoxFlat = StyleBoxFlat.new()
	ds.bg_color = GOLD if earned else Color(0.30, 0.27, 0.22, 1.0)
	ds.border_color = GOLD.lightened(0.2) if earned else Color(0.42, 0.38, 0.30, 1.0)
	ds.set_border_width_all(2)
	ds.set_corner_radius_all(22)
	disc.add_theme_stylebox_override("panel", ds)
	disc.custom_minimum_size = Vector2(46, 46)
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var star : Label = Label.new()
	star.text = "★"
	star.add_theme_font_size_override("font_size", 24)
	star.add_theme_color_override("font_color",
		Color(0.32, 0.20, 0.05, 1.0) if earned else LOCKED)
	star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	disc.add_child(star)
	cell.add_child(disc)

	var cap : Label = Label.new()
	cap.text = String(t["name"])
	cap.add_theme_font_size_override("font_size", 10)
	if on_dark:
		cap.add_theme_color_override("font_color", Palette.TEXT_PRIMARY if earned else Palette.TEXT_MUTED)
		cap.add_theme_color_override("font_outline_color", Palette.OUTLINE_HARD)
		cap.add_theme_constant_override("outline_size", 3)
	else:
		cap.add_theme_color_override("font_color", Palette.INK_ON_LIGHT if earned else Palette.INK_ON_LIGHT_SOFT)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD
	cap.custom_minimum_size = Vector2(64, 0)
	cell.add_child(cap)
	return cell
