## The Skirmish weapon registry. A weapon turns a garbage BUDGET (cells) into a
## SHAPED attack — every weapon spends the SAME budget, only the SHAPE / ENTRY
## differ, so no weapon is stronger (the no-P2W lock). The DEFAULT for anyone
## with NO weapon equipped is BRAWL — bare fists (Troy).
##   • brawl (default / fists) — a blocky CLUMP slammed at a random spot.
##   • sword — a thin vertical BLADE at a random column.
##   • long_range — a blade AIMED at your weakest (lowest) column.
## Stage-3 specials (e.g. stickier "bruise" garbage, a long-range pillar) come
## later; for now all garbage clears the same way — by completing the Tetris row
## it sits in (standard line clear; the old shatter-adjacent rule was dropped).
## See [[combat-puzzle-direction]].
class_name SkirmishWeapon
extends RefCounted


const COLS : int = SkirmishBoard.COLS
const DEFAULT_WEAPON : String = "brawl"

## Decay (piece-locks a clump stays inert blockage) per weapon — the SPECIAL lever.
## Sword's "bruise" lingers longer (stickier), equal budget; the rest use the normal.
const NORMAL_DECAY : int = SkirmishBoard.DECAY_MOVES
const BRUISE_DECAY : int = NORMAL_DECAY + 2

## Telegraph tint per weapon, so you can read WHICH attack is incoming.
const COLOR_BRAWL : Color = Color(0.92, 0.44, 0.40, 0.55)
const COLOR_SWORD : Color = Color(0.95, 0.82, 0.42, 0.55)
const COLOR_LONG : Color = Color(0.50, 0.70, 0.95, 0.55)

## Every weapon (equal-budget garbage SHAPES — variety, not power). The default for
## anyone with nothing equipped is brawl/fists. Used by the inventory equip UI.
const ALL : Array[String] = ["brawl", "sword", "long_range"]
const DISPLAY_NAMES : Dictionary = {
	"brawl": "Fists", "sword": "Sword", "long_range": "Long Shot",
}
const DESCRIPTIONS : Dictionary = {
	"brawl": "Haymaker — a WIDE clump that clogs several columns (breadth).",
	"sword": "Bruise — a thin blade whose garbage is SLOW to clear; it lingers (purple).",
	"long_range": "Snipe — a thin blade AIMED at the foe's weakest column (precision).",
}


static func display_name(weapon_id: String) -> String:
	return String(DISPLAY_NAMES.get(weapon_id, weapon_id))


## Opaque colour for a weapon — the UI swatch + the roster target dot.
static func color_for(weapon_id: String) -> Color:
	var c : Color
	match weapon_id:
		"sword":
			c = COLOR_SWORD
		"long_range":
			c = COLOR_LONG
		_:
			c = COLOR_BRAWL
	c.a = 1.0
	return c


## Build a {shape, col, color, decay} attack for [param weapon_id], spending [param
## budget] garbage cells against [param target] (queried for aimed weapons). [param lines]
## = how many rows were cleared in the one go: clearing 2+ at once (a COMBO) mails cohesive
## 2×2 SQUARES instead of the weapon's own shape — the weapon then only picks the COLUMN
## (aim) + stickiness (sword bruise). A single-line clear keeps the weapon shape. (Troy.)
static func make_attack(weapon_id: String, budget: int, target: SkirmishBoard, lines: int = 1) -> Dictionary:

	var b : int = clampi(budget, 1, 12)
	if lines >= 2:
		# Combo → N solid 2×2 squares (count scales with the budget: ~1 per 4 cells).
		var blocks : int = clampi(maxi(1, roundi(float(b) / 4.0)), 1, floori(float(COLS) / 2.0))
		var span : int = blocks * 2
		var shape : Array = _squares(blocks)
		var free : int = maxi(1, COLS - span + 1)   # count of valid leftmost columns
		match weapon_id:
			"sword":
				return {"shape": shape, "col": randi() % free, "color": COLOR_SWORD, "decay": BRUISE_DECAY}
			"long_range":
				var lc : int = target.lowest_col() if target != null else randi() % free
				return {"shape": shape, "col": clampi(lc, 0, COLS - span), "color": COLOR_LONG, "decay": NORMAL_DECAY}
			_:
				return {"shape": shape, "col": randi() % free, "color": COLOR_BRAWL, "decay": NORMAL_DECAY}
	# Single line → the weapon's own shape.
	match weapon_id:
		"sword":
			# Bruise: a thin blade whose blockage decays slower (lingers).
			return {"shape": _blade(b), "col": randi() % COLS, "color": COLOR_SWORD, "decay": BRUISE_DECAY}
		"long_range":
			var col : int = target.lowest_col() if target != null else randi() % COLS
			return {"shape": _blade(b), "col": col, "color": COLOR_LONG, "decay": NORMAL_DECAY}
		_:  # "brawl" / unarmed fists = the DEFAULT — a WIDE haymaker (breadth, not depth)
			return {"shape": _clump(b, 3), "col": randi() % maxi(1, COLS - 2), "color": COLOR_BRAWL, "decay": NORMAL_DECAY}


# A 1-wide vertical blade of [param n] cells.
static func _blade(n: int) -> Array:

	var out : Array = []
	for i in n:
		out.append(Vector2i(0, i))
	return out


# [param n] cohesive 2×2 SQUARES laid side by side (a wall of solid blocks, each 4
# contiguous cells), spanning 2n columns × 2 rows. The COMBO garbage form: a 4-line clear
# mails one or two of these "attached" squares (Troy), vs the weapons' thin/wide shapes.
static func _squares(n: int) -> Array:

	var out : Array = []
	for i in n:
		var cx : int = i * 2
		out.append(Vector2i(cx, 0))
		out.append(Vector2i(cx + 1, 0))
		out.append(Vector2i(cx, 1))
		out.append(Vector2i(cx + 1, 1))
	return out


# A [param w]-wide blocky clump (a fist) of [param n] cells, filled row by row.
static func _clump(n: int, w: int) -> Array:

	var out : Array = []
	var placed : int = 0
	var row : int = 0
	while placed < n:
		for col in w:
			if placed >= n:
				break
			out.append(Vector2i(col, row))
			placed += 1
		row += 1
	return out