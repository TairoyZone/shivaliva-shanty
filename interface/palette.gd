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
