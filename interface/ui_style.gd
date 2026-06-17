## UiStyle — the HUD STYLEBOX FACTORY, paired with [Palette]'s role tokens. One place builds every panel,
## window, card, slot and button so no surface re-types a StyleBoxFlat or re-implements the hover/pressed
## loop, and the OUTER GLOW (a colored, even halo — faked with StyleBoxFlat's shadow since GL Compatibility
## has no post-process bloom) is applied from a single seam. Recoloring the whole HUD is then a one-line
## Palette.use_scheme() swap. Static class — call `UiStyle.panel()` etc. directly. (Troy 2026-06-17.)
##
## GLOW = shadow_color tinted to the accent at low alpha + shadow_size + shadow_offset ZERO (so it spreads
## evenly on all four sides like a halo, NOT down-right like a drop-shadow). See [method glow_shadow].
class_name UiStyle
extends RefCounted


const RADIUS : int = 14
const BORDER_W : int = 3
const GLOW_SIZE : int = 12
const GLOW_ALPHA : float = 0.34


## DARK schemes: turn the drop-shadow into an even accent-tinted HALO (the outer glow), offset ZERO.
## LIGHT schemes (the YPP-flat page): a gentle neutral drop-shadow for depth instead — no neon halo.
static func glow_shadow(sb: StyleBoxFlat, hue: Color = Palette.GLOW, size: int = GLOW_SIZE) -> void:

	if Palette.IS_DARK:
		sb.shadow_color = Color(hue.r, hue.g, hue.b, GLOW_ALPHA)
		sb.shadow_size = size
		sb.shadow_offset = Vector2.ZERO
	else:
		sb.shadow_color = Color(0, 0, 0, 0.18)
		sb.shadow_size = 5
		sb.shadow_offset = Vector2(0, 2)


## A centered modal / pop-up surface — deep panel bg + accent rim + soft glow halo.
static func panel(glow: bool = true) -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Palette.PANEL_BG
	s.border_color = Palette.BORDER
	s.set_border_width_all(BORDER_W)
	s.set_corner_radius_all(RADIUS)
	s.set_content_margin_all(22)
	if glow:
		glow_shadow(s)
	return s


## The docked window chrome (Sunshine widget) — like panel() but the inventory's margins.
static func window(glow: bool = true) -> StyleBoxFlat:

	var s : StyleBoxFlat = panel(glow)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 20
	s.content_margin_bottom = 20
	return s


## A raised dark list-row / sub-panel (text on it uses TEXT_PRIMARY / TEXT_MUTED).
static func card() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Palette.CARD_BG
	s.border_color = Color(Palette.BORDER.r, Palette.BORDER.g, Palette.BORDER.b, 0.75)
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 7
	s.content_margin_bottom = 7
	return s


## The intentional CREAM / parchment card (trophy / skill / lore) — text on it uses INK_ON_LIGHT (dark).
static func cream_card() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Palette.CARD_LIGHT
	s.border_color = Palette.BORDER
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 7
	s.content_margin_bottom = 7
	return s


## An inventory / equip cell. equipped → accent rim (+ glow); filled → solid rim; empty → faint rim.
static func slot(filled: bool, equipped: bool = false) -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Palette.CARD_BG if equipped else Palette.SLOT_BG
	if equipped:
		s.border_color = Palette.ACCENT
	elif filled:
		s.border_color = Palette.BORDER
	else:
		s.border_color = Color(Palette.BORDER.r, Palette.BORDER.g, Palette.BORDER.b, 0.45)
	s.set_border_width_all(2 if equipped else 1)
	s.set_corner_radius_all(8)
	if equipped:
		glow_shadow(s, Palette.GLOW, 7)
	return s


## The tab-rail icon button states {normal, hover, pressed}. Active = accent rim + glow.
static func rail_button(active: bool) -> Dictionary:

	var out : Dictionary = {}
	for state in ["normal", "hover", "pressed"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Palette.CARD_BG if active else Palette.PANEL_BG_DARK
		if state == "hover":
			bg = bg.lightened(0.10)
		elif state == "pressed":
			bg = bg.darkened(0.10)
		s.bg_color = bg
		s.border_color = Palette.ACCENT if active else Color(Palette.BORDER.r, Palette.BORDER.g, Palette.BORDER.b, 0.7)
		s.set_border_width_all(2)
		s.set_corner_radius_all(9)
		if active:
			glow_shadow(s, Palette.GLOW, 7)
		out[state] = s
	return out


## The rail-background panel behind the icon strip.
static func rail_bg() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(Palette.PANEL_BG_DARK.r, Palette.PANEL_BG_DARK.g, Palette.PANEL_BG_DARK.b, 0.92)
	s.border_color = Color(Palette.BORDER.r, Palette.BORDER.g, Palette.BORDER.b, 0.6)
	s.set_border_width_all(2)
	s.set_corner_radius_all(12)
	s.set_content_margin_all(6)
	return s


## A general button: stylebox states {normal, hover, pressed, disabled}. Pair with [method style_button] to
## also set the label color. glow → an accent halo on the idle/hover/pressed states.
static func button_styles(bg: Color, border: Color, glow: bool = false) -> Dictionary:

	var out : Dictionary = {}
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		var c : Color = bg
		var b : Color = border
		match state:
			"hover":
				# A COLORED highlight (accent rim) — NOT a wash to white, which is invisible on the light page
				# (Troy 2026-06-17). On light, darken slightly so the fill reads as "lit"; on dark, lighten.
				c = bg.lightened(0.10) if Palette.IS_DARK else bg.darkened(0.06)
				b = Palette.ACCENT
			"pressed":
				c = bg.darkened(0.12)
				b = Palette.ACCENT
			"disabled":
				c = bg.darkened(0.10) if Palette.IS_DARK else bg.lightened(0.05)
		s.bg_color = c
		s.border_color = b
		s.set_border_width_all(2)
		s.set_corner_radius_all(9)
		s.content_margin_left = 16
		s.content_margin_right = 16
		s.content_margin_top = 8
		s.content_margin_bottom = 8
		if glow and state != "disabled":
			glow_shadow(s, b, 7)
		out[state] = s
	return out


## Apply a full themed button look to [param btn] in one call: states + label color + a hard ink outline.
## fg defaults to the accent; bg/border default to the card + accent. glow adds a halo.
static func style_button(btn: Button, fg: Color = Palette.ACCENT, bg: Color = Palette.CARD_BG, border: Color = Palette.BORDER, glow: bool = false) -> void:

	btn.focus_mode = Control.FOCUS_NONE
	# Pin EVERY font state to fg — else hover/pressed/focus fall back to the theme default (white) and vanish
	# on the light page (Troy 2026-06-17). Disabled reads as muted, not invisible.
	for slot in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(slot, fg)
	btn.add_theme_color_override("font_disabled_color", Palette.TEXT_MUTED)
	# A hard ink outline keeps text crisp on a DARK scheme; on the light page it just reads as too-bold, so skip.
	if Palette.IS_DARK:
		btn.add_theme_color_override("font_outline_color", Palette.OUTLINE_HARD)
		btn.add_theme_constant_override("outline_size", 3)
	var styles : Dictionary = button_styles(bg, border, glow)
	for state in styles:
		btn.add_theme_stylebox_override(state, styles[state])


# --- Text tiers — set font_color + the standard hard ink outline; titles get a soft accent GLOW outline ----

static func apply_primary(l: Label) -> void:

	l.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	# Dark schemes: a hard ink outline keeps light text crisp on busy worlds. Light schemes (dark text on a
	# light page) need NO outline — a black halo around dark text just looks heavy/muddy.
	if Palette.IS_DARK:
		l.add_theme_color_override("font_outline_color", Palette.OUTLINE_HARD)
		l.add_theme_constant_override("outline_size", 3)


static func apply_muted(l: Label) -> void:

	l.add_theme_color_override("font_color", Palette.TEXT_MUTED)


static func apply_title(l: Label) -> void:

	l.add_theme_color_override("font_color", Palette.ACCENT)
	# Dark schemes: a soft accent glow makes headings read as lit. Light schemes: clean blue headers (YPP), no glow.
	if Palette.IS_DARK:
		l.add_theme_color_override("font_outline_color", Color(Palette.GLOW.r, Palette.GLOW.g, Palette.GLOW.b, 0.5))
		l.add_theme_constant_override("outline_size", 4)
