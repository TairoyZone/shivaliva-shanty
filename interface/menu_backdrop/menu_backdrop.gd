## THE TITLE BACKDROP — a living procedural sky for the main menu: a twilight gradient, a
## scatter of twinkling STARDUST, and a few floating isles that drift + bob on the wind (so the
## title screen reads as the world it is, not a flat panel). Placeholder-first _draw() art, all
## animated ([[animate-everything-principle]], [[sky-canon]]). Self-contained — main.gd drops it
## in behind the title.
class_name MenuBackdrop
extends Control


const SKY_TOP : Color = Color(0.05, 0.07, 0.13, 1.0)     # deep twilight overhead
const SKY_BOT : Color = Color(0.12, 0.13, 0.22, 1.0)     # a touch warmer toward the horizon
const GLOW : Color = Color(0.40, 0.46, 0.66, 0.16)       # soft ambient light, upper-right
const STAR_COL : Color = Color(0.86, 0.92, 1.0, 1.0)

const ISLE : Color = Color(0.30, 0.42, 0.34, 1.0)
const ISLE_LIT : Color = Color(0.46, 0.60, 0.48, 1.0)
const ISLE_EDGE : Color = Color(0.10, 0.16, 0.14, 1.0)
const ISLE_UNDER : Color = Color(0.16, 0.22, 0.30, 0.5)  # the buoyant under-glow (it floats)

const STAR_COUNT : int = 70

var _t : float = 0.0
var _stars : Array = []   # {pos:Vector2(0..1), r:float, phase:float, speed:float}
var _isles : Array = []   # {pos:Vector2(0..1), scale:float, phase:float, drift:float}


func _ready() -> void:

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(queue_redraw)
	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for i in STAR_COUNT:
		_stars.append({
			"pos": Vector2(rng.randf(), rng.randf() * 0.86),
			"r": rng.randf_range(0.7, 2.1),
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(0.6, 2.2),
		})
	# A handful of isles drifting at the edges + lower horizon (kept clear of the centre text).
	_isles = [
		{"pos": Vector2(0.14, 0.30), "scale": 1.5, "phase": 0.0, "drift": 0.7},
		{"pos": Vector2(0.86, 0.24), "scale": 1.1, "phase": 1.7, "drift": 0.5},
		{"pos": Vector2(0.30, 0.86), "scale": 2.1, "phase": 3.1, "drift": 0.4},
		{"pos": Vector2(0.74, 0.88), "scale": 1.7, "phase": 4.2, "drift": 0.6},
		{"pos": Vector2(0.50, 0.94), "scale": 1.2, "phase": 5.0, "drift": 0.5},
	]


func _process(delta: float) -> void:

	_t += delta
	queue_redraw()


func _draw() -> void:

	# Draw against the VIEWPORT size, not our own rect — our anchored size may not have resolved
	# on the first frame (which would bunch everything into the top-left corner).
	var vp : Vector2 = get_viewport_rect().size
	var w : float = vp.x
	var h : float = vp.y
	# Twilight gradient (per-vertex colours).
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOT, SKY_BOT]))
	# Soft ambient glow (a far light source upper-right).
	var gc : Vector2 = Vector2(w * 0.80, h * 0.18)
	for i in 4:
		draw_circle(gc, (220.0 - i * 36.0), Color(GLOW.r, GLOW.g, GLOW.b, GLOW.a * (0.5 + i * 0.18)))
	# Twinkling stardust.
	for s in _stars:
		var a : float = 0.35 + 0.45 * (0.5 + 0.5 * sin(_t * float(s["speed"]) + float(s["phase"])))
		var p : Vector2 = Vector2(float(s["pos"].x) * w, float(s["pos"].y) * h)
		draw_circle(p, float(s["r"]), Color(STAR_COL.r, STAR_COL.g, STAR_COL.b, a))
	# Drifting floating isles.
	for isle in _isles:
		var base : Vector2 = Vector2(float(isle["pos"].x) * w, float(isle["pos"].y) * h)
		var bob : float = sin(_t * float(isle["drift"]) + float(isle["phase"])) * 7.0
		var sway : float = cos(_t * float(isle["drift"]) * 0.6 + float(isle["phase"])) * 5.0
		_draw_isle(base + Vector2(sway, bob), float(isle["scale"]))


# A little floating landmass — a rounded top, a peak, and a soft buoyant under-glow.
func _draw_isle(c: Vector2, s: float) -> void:

	var rad : float = 18.0 * s
	# Under-glow (the breath that keeps her aloft).
	draw_circle(c + Vector2(0.0, rad * 0.7), rad * 1.3, ISLE_UNDER)
	# Landmass + peak.
	draw_circle(c + Vector2(0.0, rad * 0.25), rad, ISLE)
	draw_arc(c + Vector2(0.0, rad * 0.25), rad, 0.0, TAU, 28, ISLE_EDGE, 1.6)
	var peak : PackedVector2Array = PackedVector2Array([
		c + Vector2(-rad * 0.62, 0.0), c + Vector2(0.0, -rad * 1.1), c + Vector2(rad * 0.62, 0.0)])
	draw_colored_polygon(peak, ISLE_LIT)
	draw_polyline(peak, ISLE_EDGE, 1.4)
