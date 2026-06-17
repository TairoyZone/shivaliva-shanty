## Game-wide color palette. Single source of truth for the iso
## sky-pirate-adventure look — warm woods, sky blues, parchment + brass,
## and saturated gem accents. Centralizing here means buildings, the
## gem-drop board, HUD banners and future UI all stay in tune; tweak
## one constant and every screen follows.
##
## Used as a static class — reference values directly, e.g.
## `Palette.WOOD_FRAME`. No autoload needed.
class_name Palette
extends RefCounted


# --- Wood family --------------------------------------------------------
## Frame outlines, building beams, switch beams. Tuned for the warm
## parlor-game-table look (aged oak interior, dark walnut trim,
## brass-inlaid outer rim).
const WOOD_PLANK : Color = Color(0.42, 0.29, 0.16, 1.0)        # board interior (aged oak)
const WOOD_PLANK_DARK : Color = Color(0.30, 0.20, 0.10, 1.0)   # plank shadow lines
const WOOD_FRAME : Color = Color(0.65, 0.48, 0.26, 1.0)        # building beams / mid-tone trim
const WOOD_FRAME_DARK : Color = Color(0.20, 0.12, 0.06, 1.0)   # outer rim / deep shadow
const WOOD_BEAM : Color = Color(0.36, 0.24, 0.13, 1.0)         # switch beams (dark wood)
const WOOD_BEAM_DARK : Color = Color(0.22, 0.14, 0.07, 1.0)
const WOOD_PIVOT : Color = Color(0.12, 0.07, 0.03, 1.0)

# --- Sky / depth --------------------------------------------------------
## Backgrounds in order of darkest → lightest (the night sky → the void below).
const SKY_VOID : Color = Color(0.05, 0.08, 0.12, 1.0)
const SKY_DEEP : Color = Color(0.09, 0.13, 0.19, 1.0)
const SKY_BOARD : Color = Color(0.13, 0.18, 0.25, 1.0)
const SKY_SLOT : Color = Color(0.20, 0.27, 0.36, 1.0)
const SKY_CHUTE : Color = Color(0.34, 0.50, 0.64, 1.0)

# --- Brass / gold (pads, score text, glow highlights, ornate frame) ----
const BRASS_PAD : Color = Color(0.95, 0.74, 0.34, 1.0)
const BRASS_BRIGHT : Color = Color(1.0, 0.88, 0.46, 1.0)
const BRASS_FRAME : Color = Color(0.78, 0.58, 0.24, 1.0)       # ornate outer rim
const BRASS_INLAY : Color = Color(0.92, 0.76, 0.36, 1.0)       # thin inlay highlight
const GOLD_TEXT : Color = Color(0.97, 0.87, 0.55, 1.0)
const GOLD_GLOW : Color = Color(1.0, 0.96, 0.65, 1.0)

# --- Scoring slot grading (low parchment-tan → high ruby) --------------
const SCORE_LOW : Color = Color(0.62, 0.48, 0.30, 1.0)         # safe / low-value
const SCORE_HIGH : Color = Color(0.66, 0.20, 0.16, 1.0)        # high-risk reward

# --- Parchment / cream (secondary text, soft highlights) ---------------
const PARCHMENT : Color = Color(0.96, 0.91, 0.76, 1.0)
const PARCHMENT_DIM : Color = Color(0.78, 0.74, 0.62, 1.0)

# --- Gem accents (player identity + high-value emphasis) ---------------
const GEM_RUBY : Color = Color(0.78, 0.22, 0.20, 1.0)
const GEM_RUBY_LIGHT : Color = Color(1.0, 0.55, 0.55, 1.0)
const GEM_EMERALD : Color = Color(0.30, 0.62, 0.36, 1.0)
const GEM_SAPPHIRE : Color = Color(0.30, 0.55, 0.82, 1.0)
const GEM_TOPAZ : Color = Color(1.0, 0.80, 0.30, 1.0)

# --- Cool UI panels (the ship-deck "sky-at-altitude" HUD family) -------
## DELIBERATELY distinct from the warm brass/wood chrome (Troy 2026-06-07): the deck reads as a vessel
## adrift in the night sky, so its status troughs + voyage chart use a cool navy + sky-blue frame instead
## of brass. Centralized here so the deck blues can't drift (status bars + the chart shared this navy as
## two copy-pasted literals before). The overworld HUD + every menu stay BRASS_* — see [[cool-deck-hud]].
const PANEL_TROUGH : Color = Color(0.07, 0.10, 0.17, 0.92)    # dark navy status-trough / sky-panel backing
const SKY_FRAME : Color = Color(0.50, 0.62, 0.85, 0.92)       # cool sky-blue panel border (chart, deck cards)

# --- Utility -----------------------------------------------------------
const SHADOW_SOFT : Color = Color(0, 0, 0, 0.55)
const OUTLINE_HARD : Color = Color(0, 0, 0, 0.9)


# === HUD THEME — the global UI look (swappable scheme) =====================
# Single source of truth for panels / buttons / TEXT + an outer GLOW, paired with [UiStyle] (the stylebox
# factory). The ROLE TOKENS below are SET by [method use_scheme] from one of the [method _schemes]; flip
# [constant DEFAULT_SCHEME] (or call Palette.use_scheme at runtime) to retune the WHOLE HUD in one place.
#
# Color-theory basis (Troy 2026-06-17, replacing the muddy walnut-on-walnut that failed contrast — the Profile
# name read 1.39:1): a DEEP COOL base + WARM CREAM text (a temperature-complement = high contrast, >=12:1) +
# ONE luminous accent used sparingly for glow / borders / headings. The warm WOOD/BRASS/SKY board family and
# the cool-deck PANEL_TROUGH/SKY_FRAME family ABOVE are deliberate and stay UNCHANGED — these tokens are for
# the menu/HUD chrome only.

const DEFAULT_SCHEME : String = "pirateology"

# Role tokens — read directly as Palette.PANEL_BG, Palette.TEXT_PRIMARY, … Initialized from the default scheme
# at load (robust, no _static_init dependency); reassigned by use_scheme() to retheme live.
static var _ACTIVE : Dictionary = _schemes()[DEFAULT_SCHEME]
static var SCHEME_NAME : String = DEFAULT_SCHEME
static var IS_DARK : bool = _ACTIVE["is_dark"]   # light schemes drop the glow/outlines (a YPP-flat page, not dark-mode)
static var PANEL_BG : Color = _ACTIVE["panel_bg"]          # modal / window surface
static var PANEL_BG_DARK : Color = _ACTIVE["panel_bg_dark"] # app backdrop / inset / rail
static var CARD_BG : Color = _ACTIVE["card_bg"]            # raised list-row / button idle
static var SLOT_BG : Color = _ACTIVE["slot_bg"]            # inset slot
static var BORDER : Color = _ACTIVE["border"]             # panel / button rim (the new UI-chrome rim)
static var GLOW : Color = _ACTIVE["glow"]                 # accent-tinted halo hue (alpha applied in UiStyle)
static var ACCENT : Color = _ACTIVE["accent"]            # headings / active / highlight
static var TEXT_PRIMARY : Color = _ACTIVE["text_primary"]  # cream body text on dark (>=12:1)
static var TEXT_MUTED : Color = _ACTIVE["text_muted"]     # secondary labels on dark (>=7:1)
static var INK_ON_LIGHT : Color = _ACTIVE["ink_on_light"]  # DARK text for CREAM cards — NEVER on a dark bg
static var INK_ON_LIGHT_SOFT : Color = _ACTIVE["ink_on_light_soft"]
static var CARD_LIGHT : Color = _ACTIVE["card_light"]     # the intentional cream/parchment card surface
static var DANGER : Color = _ACTIVE["danger"]            # warnings / soured / destructive
static var POSITIVE : Color = _ACTIVE["positive"]         # confirms / friend / success


## Retune the whole HUD to a named scheme (see [method _schemes]). Any UI rebuilt afterwards picks it up — so
## reopen the panel / re-enter the scene to see it. Unknown name falls back to the default.
static func use_scheme(name: String) -> void:

	var all : Dictionary = _schemes()
	_ACTIVE = all.get(name, all[DEFAULT_SCHEME])
	SCHEME_NAME = name if all.has(name) else DEFAULT_SCHEME
	IS_DARK = _ACTIVE["is_dark"]
	PANEL_BG = _ACTIVE["panel_bg"]
	PANEL_BG_DARK = _ACTIVE["panel_bg_dark"]
	CARD_BG = _ACTIVE["card_bg"]
	SLOT_BG = _ACTIVE["slot_bg"]
	BORDER = _ACTIVE["border"]
	GLOW = _ACTIVE["glow"]
	ACCENT = _ACTIVE["accent"]
	TEXT_PRIMARY = _ACTIVE["text_primary"]
	TEXT_MUTED = _ACTIVE["text_muted"]
	INK_ON_LIGHT = _ACTIVE["ink_on_light"]
	INK_ON_LIGHT_SOFT = _ACTIVE["ink_on_light_soft"]
	CARD_LIGHT = _ACTIVE["card_light"]
	DANGER = _ACTIVE["danger"]
	POSITIVE = _ACTIVE["positive"]


static func scheme_names() -> Array:

	return _schemes().keys()


# The candidate looks. Hex via Color.html (a call → can't be const), so built on demand. Each is high-contrast
# by construction: warm cream text on a deep cool/charcoal base, one luminous accent for the glow + rims.
static func _schemes() -> Dictionary:

	return {
		# THE DEFAULT — a faithful Puzzle Pirates "Pirateology" look (Troy 2026-06-17: "learn from puzzle pirates,
		# its that simple but very effective"). A LIGHT parchment page, near-black body text, BLUE section
		# headers / links, gold-tan ornate frames, gold trophies. Flat + high-contrast (dark-on-light); no glow.
		"pirateology": {
			"is_dark": false,
			"panel_bg": Color.html("#E4DFD0"), "panel_bg_dark": Color.html("#D2CCB8"),
			"card_bg": Color.html("#F0EBDC"), "slot_bg": Color.html("#CFC8B2"),
			"border": Color.html("#B7995A"), "glow": Color.html("#C9A24B"), "accent": Color.html("#3F6FB5"),
			"text_primary": Color.html("#221E16"), "text_muted": Color.html("#5B5340"),
			"ink_on_light": Color.html("#221E16"), "ink_on_light_soft": Color.html("#5B5340"),
			"card_light": Color.html("#F2EDDE"), "danger": Color.html("#B23A48"), "positive": Color.html("#3E7D4F"),
		},
		# Navy + treasure-GOLD ("celestial luxury") — keeps the pirate-gold brand (coins/trophies), on deep
		# stardust-navy instead of mud. Cream text. (A dark alternate.)
		"stardust_gold": {
			"is_dark": true,
			"panel_bg": Color.html("#131A30"), "panel_bg_dark": Color.html("#0A0E1E"),
			"card_bg": Color.html("#1E2742"), "slot_bg": Color.html("#0E1426"),
			"border": Color.html("#C39B45"), "glow": Color.html("#E8B85C"), "accent": Color.html("#FFD479"),
			"text_primary": Color.html("#F4ECD8"), "text_muted": Color.html("#AEB8D2"),
			"ink_on_light": Color.html("#241A0A"), "ink_on_light_soft": Color.html("#4A3A1E"),
			"card_light": Color.html("#F3EAD0"), "danger": Color.html("#FF6B6B"), "positive": Color.html("#7FE6A4"),
		},
		# Cool deep-space midnight-blue with an ice-blue glow — the most "new" / on-fiction read of the Stardust.
		"stardust_indigo": {
			"is_dark": true,
			"panel_bg": Color.html("#141B30"), "panel_bg_dark": Color.html("#0B1020"),
			"card_bg": Color.html("#1E2842"), "slot_bg": Color.html("#0C1124"),
			"border": Color.html("#3C4E7A"), "glow": Color.html("#5E8BE0"), "accent": Color.html("#7FB2FF"),
			"text_primary": Color.html("#F2ECDC"), "text_muted": Color.html("#A9B4CE"),
			"ink_on_light": Color.html("#1A1B26"), "ink_on_light_soft": Color.html("#3A3E52"),
			"card_light": Color.html("#ECEEF6"), "danger": Color.html("#FF6B6B"), "positive": Color.html("#7FE6A4"),
		},
		# Warm BRASS on a near-black charcoal-aubergine hull — most continuous with the current gold art, safest.
		"skyforge_brass": {
			"is_dark": true,
			"panel_bg": Color.html("#1E1822"), "panel_bg_dark": Color.html("#141017"),
			"card_bg": Color.html("#2B222E"), "slot_bg": Color.html("#171019"),
			"border": Color.html("#C08A3E"), "glow": Color.html("#E8A23C"), "accent": Color.html("#FFC964"),
			"text_primary": Color.html("#FBF1DC"), "text_muted": Color.html("#C8B79A"),
			"ink_on_light": Color.html("#2A1D0C"), "ink_on_light_soft": Color.html("#54401F"),
			"card_light": Color.html("#F5EBD6"), "danger": Color.html("#FF7A66"), "positive": Color.html("#9BE08A"),
		},
		# Royal violet-plum dusk with an orchid glow — the boldest, "magic-hour nebula" (ties to the Mystic).
		"nebula_plum": {
			"is_dark": true,
			"panel_bg": Color.html("#21172F"), "panel_bg_dark": Color.html("#160E22"),
			"card_bg": Color.html("#2E2140"), "slot_bg": Color.html("#190F26"),
			"border": Color.html("#5A3E78"), "glow": Color.html("#B070E0"), "accent": Color.html("#E0A0FF"),
			"text_primary": Color.html("#F5EEDF"), "text_muted": Color.html("#BBA6C8"),
			"ink_on_light": Color.html("#241632"), "ink_on_light_soft": Color.html("#473459"),
			"card_light": Color.html("#F1EADF"), "danger": Color.html("#FF6E8A"), "positive": Color.html("#8FE0B0"),
		},
	}
