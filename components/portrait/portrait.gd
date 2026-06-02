## A PLACEHOLDER-FIRST procedural avatar — a chunky little sky-pirate face drawn entirely
## in _draw(), so the roster reads as distinct PEOPLE instead of flat colour chips. The
## features are picked DETERMINISTICALLY from a name seed (same name → same face, every
## run) and the character's own colour tints their headwear, so each cast member is
## recognisable + consistent. Reusable anywhere a face is wanted (Skirmish roster + duel,
## the profile page, future NPC chrome). Swap the _draw for real art later, untouched
## callers ([[scene-per-component-principle]] / [[placeholder-first-preference]]).
class_name Portrait
extends Control


## Skin tones + hair colours the seed picks from (homey, varied, not realistic-precise).
const SKINS : Array[Color] = [
	Color(0.95, 0.80, 0.64), Color(0.86, 0.66, 0.48), Color(0.70, 0.50, 0.36),
	Color(0.52, 0.37, 0.28), Color(0.72, 0.82, 0.70), Color(0.80, 0.74, 0.86),
]
const HAIRS : Array[Color] = [
	Color(0.13, 0.11, 0.10), Color(0.36, 0.22, 0.11), Color(0.76, 0.64, 0.32),
	Color(0.84, 0.84, 0.88), Color(0.64, 0.22, 0.18), Color(0.30, 0.42, 0.62),
]
const EYE : Color = Color(0.08, 0.08, 0.11, 1.0)
const CHIP_BG : Color = Color(0.10, 0.11, 0.16, 1.0)


## The character's identity colour — tints their headwear (bandana/cap) so the face ties
## to the colour the roster already knows them by.
var tint : Color = Color(0.6, 0.6, 0.65, 1.0) :
	set(value):
		tint = value
		queue_redraw()

## The seed the features are derived from (the character name). Same seed → same face.
var seed_name : String = "" :
	set(value):
		seed_name = value
		queue_redraw()


## One-call setup from a caller (name + identity colour).
func setup(name_seed: String, identity: Color) -> void:

	seed_name = name_seed
	tint = identity
	queue_redraw()


func _draw() -> void:

	var s : float = minf(size.x, size.y)
	if s <= 0.0:
		s = 22.0
	# Deterministic feature picks from the name hash (different bit-slices per trait).
	# Lower-cased so the SAME character seeds the SAME face regardless of label casing
	# (e.g. "You" in the roster vs "YOU" in the duel).
	var h : int = absi(seed_name.to_lower().hash())
	# Bit-slices (shifts, not division — keeps each trait independent + no int-div warning).
	var skin : Color = SKINS[h % SKINS.size()]
	var hair : Color = HAIRS[(h >> 4) % HAIRS.size()]
	var headwear : int = (h >> 8) % 4        # 0 hair · 1 bandana(tint) · 2 cap(tint) · 3 tall hair
	var feature : int = (h >> 12) % 5        # 0 none · 1 beard · 2 'tache · 3 eyepatch · 4 specs

	# Dark backing chip so the face pops in a header row.
	draw_rect(Rect2(0.0, 0.0, s, s), CHIP_BG, true)

	# Head (a round face sitting a touch low to leave room for headwear).
	var cx : float = s * 0.5
	var head_c : Vector2 = Vector2(cx, s * 0.55)
	var head_r : float = s * 0.34
	draw_circle(head_c, head_r, skin)

	# Headwear / hair on top.
	match headwear:
		1:  # bandana in the character's tint (a band across the brow + a knot)
			draw_rect(Rect2(s * 0.16, s * 0.30, s * 0.68, s * 0.14), tint, true)
			draw_rect(Rect2(s * 0.80, s * 0.32, s * 0.12, s * 0.18), tint, true)
		2:  # a cap in the tint
			draw_rect(Rect2(s * 0.14, s * 0.20, s * 0.72, s * 0.16), tint, true)
			draw_rect(Rect2(s * 0.14, s * 0.33, s * 0.40, s * 0.05), tint.darkened(0.2), true)
		3:  # tall hair
			draw_rect(Rect2(s * 0.22, s * 0.08, s * 0.56, s * 0.26), hair, true)
		_:  # short hair (a cap of hair over the crown)
			draw_circle(Vector2(cx, s * 0.40), head_r * 0.95, hair)
			draw_circle(head_c, head_r, skin)   # re-cut the face below the hair

	# Eyes.
	var eye_y : float = s * 0.52
	draw_circle(Vector2(s * 0.40, eye_y), s * 0.055, EYE)
	draw_circle(Vector2(s * 0.60, eye_y), s * 0.055, EYE)

	# Facial feature.
	match feature:
		1:  # beard
			draw_rect(Rect2(s * 0.30, s * 0.68, s * 0.40, s * 0.16), hair, true)
		2:  # moustache
			draw_rect(Rect2(s * 0.36, s * 0.62, s * 0.28, s * 0.05), hair, true)
		3:  # eyepatch over the right eye + strap (sky-pirate!)
			draw_circle(Vector2(s * 0.60, eye_y), s * 0.085, Color(0.05, 0.05, 0.07, 1.0))
			draw_line(Vector2(s * 0.46, s * 0.36), Vector2(s * 0.86, s * 0.46), Color(0.05, 0.05, 0.07, 1.0), maxf(1.0, s * 0.05))
		4:  # specs (a bar bridging both eyes)
			draw_rect(Rect2(s * 0.32, eye_y - s * 0.02, s * 0.36, s * 0.03), Color(0.12, 0.12, 0.14, 1.0), true)

	# Frame.
	draw_rect(Rect2(0.0, 0.0, s, s), Color(0.0, 0.0, 0.0, 0.55), false, maxf(1.0, s * 0.06))