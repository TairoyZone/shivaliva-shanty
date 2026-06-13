## DieIcon — a procedural die-face (placeholder-first _draw art) for the New Game "roll a name" button. Draws a
## rounded square outline with the 5-pip face. Pure visual: the parent Button handles the press. The font has no
## die glyph (⚄ renders as tofu), so we draw it. See [[placeholder-first-preference]].
class_name DieIcon
extends Control


@export var color : Color = Color(0.97, 0.87, 0.55, 1.0)


func _draw() -> void:

	var s : float = minf(size.x, size.y)
	var c : Vector2 = size * 0.5
	var half : float = s * 0.30          # die square half-extent
	var pip_r : float = s * 0.058        # pip radius
	var d : float = half * 0.6           # pip offset from centre
	# The square "die" edge.
	var edge : float = maxf(1.5, s * 0.045)
	draw_rect(Rect2(c - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), color, false, edge)
	# The 5-face: four corners + centre.
	for p in [Vector2(-d, -d), Vector2(d, -d), Vector2.ZERO, Vector2(-d, d), Vector2(d, d)]:
		draw_circle(c + p, pip_r, color)
