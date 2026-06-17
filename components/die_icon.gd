## DieIcon — a procedural die-face (placeholder-first _draw art) for the New Game "roll a name" button. Draws a
## rounded square outline with the 5-pip face. Pure visual: the parent Button handles the press. The font has no
## die glyph (⚄ renders as tofu), so we draw it. See [[placeholder-first-preference]].
class_name DieIcon
extends Control


# A sentinel default — leave it and the die draws in the active theme's body-text ink (dark on the light
# name-prompt, light on a dark scheme) via [member _ink]. Set color explicitly to override per-instance.
@export var color : Color = Color(0, 0, 0, 0)


# The face/pip ink: the explicit override if one was set, else the theme's primary text (so the die reads
# DARK on the light name-prompt, and adapts if the scheme is dark) — never a fixed gold-on-light.
func _ink() -> Color:

	return color if color.a > 0.0 else Palette.TEXT_PRIMARY


func _draw() -> void:

	var ink : Color = _ink()
	var s : float = minf(size.x, size.y)
	var c : Vector2 = size * 0.5
	var half : float = s * 0.30          # die square half-extent
	var pip_r : float = s * 0.058        # pip radius
	var d : float = half * 0.6           # pip offset from centre
	# The square "die" edge.
	var edge : float = maxf(1.5, s * 0.045)
	draw_rect(Rect2(c - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), ink, false, edge)
	# The 5-face: four corners + centre.
	for p in [Vector2(-d, -d), Vector2(d, -d), Vector2.ZERO, Vector2(-d, d), Vector2(d, d)]:
		draw_circle(c + p, pip_r, ink)
