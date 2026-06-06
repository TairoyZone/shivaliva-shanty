## HullGauge — the ship's HULL-condition readout: a little hull ICON + "Hull: sound / N holes",
## colour-coded green -> amber -> red. This is the ONE ship condition (open holes): they flood the
## [[loft-spec]] LOFT faster and are mended at the [[patchworks-spec]] PATCHWORKS — NOT a Loft-only thing.
## Call set_holes(n). Drawn procedurally (placeholder-first); reusable on the deck + voyage stations.
class_name HullGauge
extends Control

const SOUND : Color = Color(0.58, 0.88, 0.62, 1.0)
const WARN : Color = Color(0.98, 0.82, 0.50, 1.0)
const BAD : Color = Color(1.0, 0.55, 0.50, 1.0)
const HULL_WOOD : Color = Color(0.46, 0.31, 0.16, 1.0)
const HOLE : Color = Color(0.06, 0.04, 0.05, 1.0)
const TEXT_SHADOW : Color = Color(0.0, 0.0, 0.0, 0.85)

var _holes : int = 0


func _ready() -> void:

	custom_minimum_size = Vector2(160.0, 32.0)
	mouse_filter = Control.MOUSE_FILTER_PASS   # PASS so the hover tooltip works but clicks fall through
	tooltip_text = "The ship's hull condition. Holes flood the Loft faster — mend them at the Patchworks."


func set_holes(holes: int) -> void:

	if holes == _holes:
		return
	_holes = holes
	queue_redraw()


func _draw() -> void:

	var col : Color = SOUND if _holes <= 0 else (WARN if _holes <= 2 else BAD)
	# Hull icon — a little boat hull, outlined in the state colour.
	var cx : float = 14.0
	var cy : float = 16.0
	var hull : PackedVector2Array = PackedVector2Array([
		Vector2(cx - 12.0, cy - 6.0), Vector2(cx + 12.0, cy - 6.0),
		Vector2(cx + 8.0, cy + 7.0), Vector2(cx - 8.0, cy + 7.0)])
	draw_colored_polygon(hull, HULL_WOOD)
	draw_polyline(hull + PackedVector2Array([hull[0]]), col, 1.6)
	# Holes (dark punctures) per open hole — or a calm ring when sound.
	if _holes <= 0:
		draw_arc(Vector2(cx, cy + 0.5), 3.2, 0.0, TAU, 12, col, 1.4)
	else:
		for i in mini(_holes, 4):
			draw_circle(Vector2(cx - 7.0 + float(i) * 5.0, cy + 1.0), 2.2, HOLE)
	# Label (1px shadow for readability over the deck).
	var font : Font = get_theme_default_font()
	if font != null:
		var txt : String = "Hull: sound" if _holes <= 0 else ("Hull: %d hole%s" % [_holes, "" if _holes == 1 else "s"])
		var p : Vector2 = Vector2(32.0, 21.0)
		draw_string(font, p + Vector2(1.0, 1.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT_SHADOW)
		draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
