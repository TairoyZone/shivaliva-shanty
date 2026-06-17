## The Skirmish weapon registry. A weapon turns a garbage BUDGET (cells) into a
## SHAPED attack — every weapon spends the SAME budget, only the SHAPE / ENTRY
## differ, so no weapon is stronger (the no-P2W lock). The DEFAULT for anyone
## with NO weapon equipped is BRAWL — bare fists (Troy).
##   • brawl (default / fists) — a blocky CLUMP slammed at a random spot.
##   • sword — a thin vertical BLADE at a random column.
##   • long_range — a blade AIMED at your weakest (lowest) column.
##   • mystic — a SCATTER strewn across the columns (chaos; no clean line to clear).
## These double as the player's "POWER TYPES" (the gym-master class choice): Brawler=brawl, Swordsman=sword,
## Marksman=long_range, Mystic=mystic. Kerr fights sword, Ellison long_range. See [[combat-power-types]].
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
const COLOR_MYSTIC : Color = Color(0.66, 0.40, 0.92, 0.55)

## Every weapon (equal-budget garbage SHAPES — variety, not power). The default for
## anyone with nothing equipped is brawl/fists. Used by the inventory equip UI.
const ALL : Array[String] = ["brawl", "sword", "long_range", "mystic"]
const DISPLAY_NAMES : Dictionary = {
	"brawl": "Fists", "sword": "Sword", "long_range": "Long Shot", "mystic": "Mystic",
}
## The player-facing POWER-TYPE / class name for each (the gym-master choice). Display names above are the
## WEAPON flavour; these are the One-Piece-style archetype labels shown when you pick your fighter.
const POWER_TYPE_NAMES : Dictionary = {
	"brawl": "Brawler", "sword": "Swordsman", "long_range": "Marksman", "mystic": "Mystic",
}
const DESCRIPTIONS : Dictionary = {
	"brawl": "Haymaker — a WIDE clump that clogs several columns (breadth).",
	"sword": "Bruise — a thin blade whose garbage is SLOW to clear; it lingers (purple).",
	"long_range": "Snipe — a thin blade AIMED at the foe's weakest column (precision).",
	"mystic": "Hex — garbage SCATTERS across the columns; no clean line to clear (chaos).",
}
## The free CLASS weapon shows as a humble STARTER (a Swordsman wields a Twig until they buy the forge's steel
## Sword; a Marksman a Slingshot; a Mystic their Spellbook). Brawl has none — it IS fists. Used by the equip slot.
const STARTER_NAMES : Dictionary = {
	"sword": "Twig", "long_range": "Slingshot", "mystic": "Spellbook",
}


## The name to SHOW on the equip slot: the humble starter (Twig/Slingshot/Spellbook) when it's the free class
## weapon, else the real weapon name (Fists / Sword / Long Shot / Mystic).
static func equip_display_name(weapon_id: String, starter: bool) -> String:
	if starter and STARTER_NAMES.has(weapon_id):
		return String(STARTER_NAMES[weapon_id])
	return display_name(weapon_id)


static func power_type_name(weapon_id: String) -> String:
	return String(POWER_TYPE_NAMES.get(weapon_id, DISPLAY_NAMES.get(weapon_id, weapon_id)))


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
		"mystic":
			c = COLOR_MYSTIC
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
			"mystic":
				return {"shape": shape, "col": randi() % free, "color": COLOR_MYSTIC, "decay": NORMAL_DECAY}
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
		"mystic":
			# Hex: garbage SCATTERS within a BAND (chaos — no clean line to clear), dropped at a RANDOM column like
			# the others so it can still settle in a valley. Equal budget = no power edge (the variety-not-power lock).
			var band : int = mini(COLS, 6)
			return {"shape": _spread(b, band), "col": randi() % maxi(1, COLS - band + 1), "color": COLOR_MYSTIC, "decay": NORMAL_DECAY}
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


# A SCATTER of [param n] cells strewn WITHIN a [param band]-wide window (the Mystic's chaos) — stride 2 so they're
# never adjacent + never fill a clean row, staggered over a few rows. Returned at local x 0..band-1, so make_attack
# can drop it at a RANDOM column (it can settle in a valley like every other weapon — equal budget, no power edge).
static func _spread(n: int, band: int = 6) -> Array:

	var w : int = clampi(band, 1, COLS)
	var out : Array = []
	var x : int = 0
	var row : int = 0
	for i in n:
		out.append(Vector2i(x % w, row))
		x += 2   # stride 2 within the band → scattered (gaps), never a solid line
		if x >= w:
			row += 1
			x = row % 2   # offset each row's start so columns vary
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